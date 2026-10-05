import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/cv_profile_model.dart';
import '../../core/theme/app_theme.dart';
import 'api_service.dart';
import 'pdf_extractor_stub.dart'
    if (dart.library.html) 'pdf_extractor_web.dart';

class CvDocumentParserService {
  /// Prompts user to select a .pdf or .docx document, extracts its text, and parses into a CvProfileModel
  static Future<CvProfileModel?> pickAndParseCvDocument(
    BuildContext context,
    CvProfileModel baseProfile, {
    ApiService? apiService,
  }) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['docx', 'pdf', 'txt'],
      );

      if (files.isEmpty) {
        return null;
      }

      final file = files.first;
      final bytes = await file.readAsBytes();
      final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : '';
      final fileName = file.name;

      if (bytes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudieron leer los bytes del archivo seleccionado.')),
          );
        }
        return null;
      }

      String extractedText = '';
      if (ext == 'docx') {
        extractedText = _extractTextFromDocx(bytes);
      } else if (ext == 'pdf') {
        // 1. Check for embedded Sanctuary CV JSON metadata across all encoding layers for 100% reconstruction
        final exactProfile = _tryExtractSanctuaryMetadata(bytes);
        if (exactProfile != null) {
          if (!context.mounted) return exactProfile;
          final confirmed = await _showReviewImportDialog(context, exactProfile, fileName);
          if (confirmed == true) return exactProfile;
          return null;
        }

        // 2. High-fidelity Server/Render extraction with OCR if online
        if (apiService != null) {
          try {
            final onlineProfile = await apiService.extractCvPdfOnline(bytes, fileName, baseProfile);
            if (onlineProfile != null && (onlineProfile.experiences.isNotEmpty || onlineProfile.educations.isNotEmpty)) {
              if (!context.mounted) return onlineProfile;
              final confirmed = await _showReviewImportDialog(context, onlineProfile, fileName);
              if (confirmed == true) return onlineProfile;
              return null;
            }
          } catch (e) {
            debugPrint('[CvDocumentParserService] Online PDF extraction notice: $e');
          }
        }

        // 3. High-fidelity extraction via Mozilla pdf.js (decodes subsetted font glyphs & CMaps on Web / GitHub Pages with OCR)
        try {
          final webPdfText = await extractTextWithPdfJsWeb(bytes);
          if (webPdfText.trim().isNotEmpty) {
            extractedText = webPdfText;
          }
        } catch (e) {
          debugPrint('[CvDocumentParserService] extractTextWithPdfJsWeb aviso: $e');
        }

        // 4. Fallback to native Dart PDF extraction (with CMap stream decoding & TJ array parsing)
        if (extractedText.trim().isEmpty) {
          extractedText = _extractTextFromPdf(bytes);
        }
      } else {
        extractedText = utf8.decode(bytes, allowMalformed: true);
      }

      if (extractedText.trim().isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se encontró contenido de texto legible en el documento seleccionado.')),
          );
        }
        return null;
      }

      final parsed = parseCvText(extractedText, baseProfile, fileName);

      if (!context.mounted) return parsed;

      // Show Confirmation / Review Modal to the user before populating the CV
      final confirmed = await _showReviewImportDialog(context, parsed, fileName);
      if (confirmed == true) {
        return parsed;
      }
      return null;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al importar documento: $e')),
        );
      }
      return null;
    }
  }

  /// Extracts clean text paragraphs from a .docx file via Archive (word/document.xml)
  static String _extractTextFromDocx(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final docFile = archive.findFile('word/document.xml');
      if (docFile == null) return '';

      final rawXml = utf8.decode(docFile.content as List<int>, allowMalformed: true);

      // Replace paragraph and break tags with newlines
      var text = rawXml
          .replaceAll('</w:p>', '\n')
          .replaceAll('<w:br/>', '\n')
          .replaceAll('<w:tab/>', '  ');

      // Strip all remaining XML tags
      text = text.replaceAll(RegExp(r'<[^>]+>'), '');

      // Decode XML entities
      text = text
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&apos;', "'");

      return text;
    } catch (_) {
      return '';
    }
  }

  /// Extracts readable text strings from a PDF document, decompressing FlateDecode streams
  /// and applying ToUnicode CMap translation for subsetted fonts.
  static String _extractTextFromPdf(Uint8List bytes) {
    final buffer = StringBuffer();
    try {
      // 1. Scan and decompress all FlateDecode streams (where actual page text is stored)
      final decompressedStreams = _extractAndDecompressPdfStreams(bytes);

      // Extract ToUnicode CMap tables if present in streams
      final cMap = _extractCMapTable(decompressedStreams);

      for (final streamText in decompressedStreams) {
        _extractTextFromStreamContent(streamText, buffer, cMap);
      }

      // 2. Also scan uncompressed raw string for uncompressed PDFs
      final rawStr = latin1.decode(bytes);
      _extractTextFromStreamContent(rawStr, buffer, cMap);

      // 3. Fallback: if very little text found, extract readable ASCII words
      if (buffer.length < 50) {
        final asciiWords = RegExp(r'[A-Za-zÁÉÍÓÚáéíóúñÑ0-9@._\-+]{2,}')
            .allMatches(rawStr)
            .map((m) => m.group(0) ?? '')
            .where((w) => !w.startsWith('obj') && !w.startsWith('endobj') && !w.startsWith('xref') && !w.startsWith('stream'))
            .take(300)
            .join(' ');
        buffer.writeln(asciiWords);
      }
    } catch (e) {
      debugPrint('Error extrayendo texto de PDF: $e');
    }

    return buffer.toString();
  }

  /// Finds all 'stream ... endstream' binary byte slices and decompresses with ZLibDecoder / Inflate
  static List<String> _extractAndDecompressPdfStreams(Uint8List bytes) {
    final List<String> result = [];
    final len = bytes.length;
    int i = 0;

    // Scan for 'stream' keyword
    while (i < len - 10) {
      if (bytes[i] == 115 && // s
          bytes[i + 1] == 116 && // t
          bytes[i + 2] == 114 && // r
          bytes[i + 3] == 101 && // e
          bytes[i + 4] == 97 && // a
          bytes[i + 5] == 109) { // m
        int streamStart = i + 6;
        while (streamStart < len && (bytes[streamStart] == 10 || bytes[streamStart] == 13 || bytes[streamStart] == 32)) {
          streamStart++;
        }

        // Find matching 'endstream'
        int streamEnd = -1;
        int j = streamStart;
        while (j < len - 9) {
          if (bytes[j] == 101 && // e
              bytes[j + 1] == 110 && // n
              bytes[j + 2] == 100 && // d
              bytes[j + 3] == 115 && // s
              bytes[j + 4] == 116 && // t
              bytes[j + 5] == 114 && // r
              bytes[j + 6] == 101 && // e
              bytes[j + 7] == 97 && // a
              bytes[j + 8] == 109) { // m
            streamEnd = j;
            break;
          }
          j++;
        }

        if (streamEnd > streamStart) {
          int actualEnd = streamEnd;
          while (actualEnd > streamStart && (bytes[actualEnd - 1] == 10 || bytes[actualEnd - 1] == 13 || bytes[actualEnd - 1] == 32)) {
            actualEnd--;
          }

          if (actualEnd > streamStart) {
            final slice = bytes.sublist(streamStart, actualEnd);
            List<int>? decompressed;
            try {
              decompressed = ZLibDecoder().decodeBytes(slice);
            } catch (_) {
              try {
                decompressed = Inflate(slice).getBytes();
              } catch (_) {}
            }

            if (decompressed != null && decompressed.isNotEmpty) {
              final text = utf8.decode(decompressed, allowMalformed: true);
              result.add(text);
            }
          }
          i = streamEnd + 9;
          continue;
        }
      }
      i++;
    }

    return result;
  }

  /// Extracts character mapping tables (/ToUnicode CMaps) from decompressed streams
  static Map<String, String> _extractCMapTable(List<String> streams) {
    final Map<String, String> cMap = {};
    try {
      for (final s in streams) {
        if (!s.contains('beginbfchar') && !s.contains('beginbfrange')) continue;

        // Parse beginbfchar ... endbfchar
        final bfcharBlocks = RegExp(r'beginbfchar\s*(.*?)\s*endbfchar', dotAll: true).allMatches(s);
        for (final block in bfcharBlocks) {
          final content = block.group(1) ?? '';
          final lines = RegExp(r'<([0-9a-fA-F]+)>\s*<([0-9a-fA-F]+)>').allMatches(content);
          for (final m in lines) {
            final srcHex = m.group(1)!.toUpperCase();
            final dstHex = m.group(2)!;
            final charCode = int.tryParse(dstHex, radix: 16);
            if (charCode != null && charCode > 0) {
              cMap[srcHex] = String.fromCharCode(charCode);
            }
          }
        }

        // Parse beginbfrange ... endbfrange
        final bfrangeBlocks = RegExp(r'beginbfrange\s*(.*?)\s*endbfrange', dotAll: true).allMatches(s);
        for (final block in bfrangeBlocks) {
          final content = block.group(1) ?? '';
          // Format 1: <start> <end> <destStart>
          final rangeMatches = RegExp(r'<([0-9a-fA-F]+)>\s*<([0-9a-fA-F]+)>\s*<([0-9a-fA-F]+)>').allMatches(content);
          for (final m in rangeMatches) {
            final startHex = m.group(1)!;
            final endHex = m.group(2)!;
            final dstHex = m.group(3)!;
            final start = int.tryParse(startHex, radix: 16);
            final end = int.tryParse(endHex, radix: 16);
            final dst = int.tryParse(dstHex, radix: 16);
            if (start != null && end != null && dst != null && end >= start && (end - start) < 1000) {
              final pad = startHex.length;
              for (int c = start; c <= end; c++) {
                final key = c.toRadixString(16).padLeft(pad, '0').toUpperCase();
                cMap[key] = String.fromCharCode(dst + (c - start));
              }
            }
          }

          // Format 2: <start> <end> [ <dest1> <dest2> ... ]
          final arrayMatches = RegExp(r'<([0-9a-fA-F]+)>\s*<([0-9a-fA-F]+)>\s*\[(.*?)\]', dotAll: true).allMatches(content);
          for (final m in arrayMatches) {
            final startHex = m.group(1)!;
            final start = int.tryParse(startHex, radix: 16);
            final arrContent = m.group(3) ?? '';
            final destList = RegExp(r'<([0-9a-fA-F]+)>').allMatches(arrContent).map((im) => im.group(1)!).toList();
            if (start != null && destList.isNotEmpty) {
              final pad = startHex.length;
              for (int idx = 0; idx < destList.length; idx++) {
                final key = (start + idx).toRadixString(16).padLeft(pad, '0').toUpperCase();
                final code = int.tryParse(destList[idx], radix: 16);
                if (code != null) {
                  cMap[key] = String.fromCharCode(code);
                }
              }
            }
          }
        }
      }
    } catch (_) {}
    return cMap;
  }

  /// Decodes hex string using CMap lookup table or fallback UTF-16BE / Latin-1
  static String _decodeHexWithCMap(String hex, Map<String, String> cMap) {
    final clean = hex.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (clean.isEmpty) return '';

    if (cMap.isNotEmpty) {
      // 1. Try 4-char chunks (standard 2-byte CID font codes)
      if (clean.length % 4 == 0) {
        final sb = StringBuffer();
        bool allFound = true;
        for (int i = 0; i < clean.length; i += 4) {
          final code = clean.substring(i, i + 4);
          if (cMap.containsKey(code)) {
            sb.write(cMap[code]);
          } else {
            allFound = false;
            break;
          }
        }
        if (allFound && sb.isNotEmpty) {
          return sb.toString();
        }
      }

      // 2. Try 2-char chunks (1-byte codes)
      if (clean.length % 2 == 0) {
        final sb = StringBuffer();
        bool allFound = true;
        for (int i = 0; i < clean.length; i += 2) {
          final code = clean.substring(i, i + 2);
          if (cMap.containsKey(code)) {
            sb.write(cMap[code]);
          } else {
            allFound = false;
            break;
          }
        }
        if (allFound && sb.isNotEmpty) {
          return sb.toString();
        }
      }
    }

    return _decodePdfHexString(clean);
  }

  /// Tries extracting embedded Sanctuary CV JSON metadata across all encoding layers:
  /// 1. Direct ASCII trailer comment (%SanctuaryCV::$jsonPayload%)
  /// 2. Raw Latin1/UTF-8 string (/Subject SanctuaryCV::...)
  /// 3. Stripped null-bytes (UTF-16BE wide strings)
  /// 4. Decompressed Flate streams (/ObjStm object streams)
  static CvProfileModel? _tryExtractSanctuaryMetadata(Uint8List bytes) {
    try {
      // Layer 1: Check raw ASCII string
      final rawStr = latin1.decode(bytes);
      final match1 = RegExp(r'SanctuaryCV::([A-Za-z0-9+/=]+)').firstMatch(rawStr);
      if (match1 != null) {
        final profile = _decodeSanctuaryPayload(match1.group(1)!);
        if (profile != null) return profile;
      }

      // Layer 2: Check bytes without null-bytes (UTF-16BE)
      final nonZero = bytes.where((b) => b != 0).toList();
      final nonZeroStr = latin1.decode(nonZero);
      final match2 = RegExp(r'SanctuaryCV::([A-Za-z0-9+/=]+)').firstMatch(nonZeroStr);
      if (match2 != null) {
        final profile = _decodeSanctuaryPayload(match2.group(1)!);
        if (profile != null) return profile;
      }

      // Layer 3: Check decompressed streams (compressed /ObjStm objects)
      final decompressedStreams = _extractAndDecompressPdfStreams(bytes);
      for (final stream in decompressedStreams) {
        final streamMatch = RegExp(r'SanctuaryCV::([A-Za-z0-9+/=]+)').firstMatch(stream);
        if (streamMatch != null) {
          final profile = _decodeSanctuaryPayload(streamMatch.group(1)!);
          if (profile != null) return profile;
        }
      }
    } catch (e) {
      debugPrint('Aviso: error inspeccionando metadatos SanctuaryCV: $e');
    }
    return null;
  }

  static CvProfileModel? _decodeSanctuaryPayload(String base64Payload) {
    try {
      final jsonStr = utf8.decode(base64Decode(base64Payload));
      final data = jsonDecode(jsonStr);
      if (data is Map<String, dynamic> && data.containsKey('fullName')) {
        return CvProfileModel.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  static String _decodePdfHexString(String hex) {
    final clean = hex.replaceAll(RegExp(r'\s+'), '');
    if (clean.isEmpty) return '';
    try {
      final padded = clean.length.isOdd ? '${clean}0' : clean;
      final bytes = <int>[];
      for (int i = 0; i < padded.length; i += 2) {
        bytes.add(int.parse(padded.substring(i, i + 2), radix: 16));
      }
      // Check if starts with UTF-16BE BOM (0xFE 0xFF)
      if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
        return utf8.decode(bytes.sublist(2).where((b) => b != 0).toList(), allowMalformed: true);
      }
      // Check if UTF-16BE format without BOM (alternate bytes are 0)
      if (bytes.length >= 4 && bytes[0] == 0 && bytes[2] == 0) {
        return utf8.decode(bytes.where((b) => b != 0).toList(), allowMalformed: true);
      }
      return latin1.decode(bytes);
    } catch (_) {
      return '';
    }
  }

  static void _extractTextFromStreamContent(String content, StringBuffer buffer, [Map<String, String>? cMap]) {
    final map = cMap ?? const {};

    // 1. Text inside ( ... ) Tj
    final tjRegex = RegExp(r'\((.*?)\)\s*Tj', dotAll: true);
    for (final m in tjRegex.allMatches(content)) {
      final val = m.group(1);
      if (val != null && val.isNotEmpty) {
        buffer.writeln(_sanitizePdfString(val));
      }
    }

    // 2. Text array [ (part1) -250 (part2) ] TJ or [ <HEX> -250 <HEX> ] TJ
    final arrayTjRegex = RegExp(r'\[(.*?)\]\s*TJ', dotAll: true);
    for (final m in arrayTjRegex.allMatches(content)) {
      final arr = m.group(1) ?? '';
      final tokenRegex = RegExp(r'\((.*?)\)|<([0-9a-fA-F\s]+)>|(-?\d+(?:\.\d+)?)');
      final lineBuffer = StringBuffer();
      for (final tm in tokenRegex.allMatches(arr)) {
        if (tm.group(1) != null) {
          lineBuffer.write(_sanitizePdfString(tm.group(1)!));
        } else if (tm.group(2) != null) {
          final decoded = _decodeHexWithCMap(tm.group(2)!, map);
          lineBuffer.write(decoded);
        } else if (tm.group(3) != null) {
          final numVal = double.tryParse(tm.group(3)!);
          // Negative spacing number <= -100 indicates an inter-word space in PDF
          if (numVal != null && numVal <= -100) {
            if (lineBuffer.isNotEmpty && !lineBuffer.toString().endsWith(' ')) {
              lineBuffer.write(' ');
            }
          }
        }
      }
      final line = lineBuffer.toString().trim();
      if (line.isNotEmpty) {
        buffer.writeln(line);
      }
    }

    // 3. Text with ' or " operator
    final quoteRegex = RegExp(r'\((.*?)\)\s*["\x27]', dotAll: true);
    for (final m in quoteRegex.allMatches(content)) {
      final val = m.group(1);
      if (val != null && val.isNotEmpty) {
        buffer.writeln(_sanitizePdfString(val));
      }
    }

    // 4. Hex strings <HEX> Tj (TrueType / Type0 fonts)
    final hexTjRegex = RegExp(r'<([0-9a-fA-F\s]+)>\s*Tj');
    for (final m in hexTjRegex.allMatches(content)) {
      final hex = m.group(1);
      if (hex != null && hex.isNotEmpty) {
        final decoded = _decodeHexWithCMap(hex, map);
        if (decoded.trim().isNotEmpty) {
          buffer.writeln(decoded.trim());
        }
      }
    }
  }

  static String _sanitizePdfString(String str) {
    return str
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', r'\')
        .replaceAll(r'\r', '')
        .replaceAll(r'\n', ' ')
        .trim();
  }

  /// Cleans artificially spaced characters from fonts/PDF layouts (e.g. 'T . S . E N   D E S A R R O L L O')
  static String _cleanSpacedLetters(String str) {
    if (RegExp(r'^([A-Za-zÁÉÍÓÚáéíóúñÑ0-9\.]\s+){3,}').hasMatch(str)) {
      return str
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAllMapped(RegExp(r'([A-Za-zÁÉÍÓÚáéíóúñÑ0-9])\s+(?=[A-Za-zÁÉÍÓÚáéíóúñÑ0-9])'), (m) => m.group(1)!)
          .trim();
    }
    return str;
  }

  /// Normalizes string for fuzzy/squashed layout checks (removes accents and non-alphanumeric chars)
  static String _normalizeLetters(String str) {
    return str
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâã]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöôõ]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Robust heuristic semantic parser for CV contents with filename awareness and layout independence
  static CvProfileModel parseCvText(String rawText, CvProfileModel baseProfile, [String fileName = '']) {
    final cleanText = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rawLines = cleanText
        .split('\n')
        .map((l) => _cleanSpacedLetters(l.trim()))
        .where((l) => l.isNotEmpty && l != '-- 1 of 1 --')
        .toList();

    // Check if baseProfile was just an unedited placeholder template
    final bool isPlaceholderBase = baseProfile.fullName.trim() == 'NUEVO APRENDIZ / ALUMNO' ||
        baseProfile.fullName.trim() == 'NOMBRE Y APELLIDOS' ||
        baseProfile.fullName.trim().isEmpty;

    String fullName = isPlaceholderBase ? '' : baseProfile.fullName;
    String jobTitle = (isPlaceholderBase || baseProfile.jobTitle == 'OPERARIO/A EN FORMACIÓN') ? '' : baseProfile.jobTitle;
    String email = (isPlaceholderBase || baseProfile.email == 'alumno@correo.es') ? '' : baseProfile.email;
    String phone = (isPlaceholderBase || baseProfile.phone.contains('000 000')) ? '' : baseProfile.phone;
    String location = (isPlaceholderBase || baseProfile.location == 'Las Palmas, Gran Canaria') ? '' : baseProfile.location;
    String availability = baseProfile.availability;
    String drivingLicense = baseProfile.drivingLicense;
    String summary = (isPlaceholderBase || baseProfile.summary.startsWith('Persona responsable y motivada')) ? '' : baseProfile.summary;
    List<CvExperience> experiences = isPlaceholderBase ? [] : List.from(baseProfile.experiences);
    List<CvEducation> educations = isPlaceholderBase ? [] : List.from(baseProfile.educations);
    List<CvSkillItem> skillItems = isPlaceholderBase ? [] : List.from(baseProfile.skillItems);

    // 1. Email Regex
    final emailRegex = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
    final emailMatch = emailRegex.firstMatch(cleanText);
    if (emailMatch != null) {
      email = emailMatch.group(0)!.replaceAll(RegExp(r'[.,;:]+$'), '');
    }

    // 2. Phone Regex (strictly rejecting PDF metadata timestamps)
    final phoneRegex = RegExp(r'(?:\+?34[-.\s]?)?[6789]\d{2}[-.\s]?\d{2,3}[-.\s]?\d{2,3}[-.\s]?\d{2,3}|(?:\+?\d{1,3}[-.\s]?)?\(?\d{2,4}\)?[-.\s]?\d{3,4}[-.\s]?\d{3,4}');
    for (final m in phoneRegex.allMatches(cleanText)) {
      final cand = m.group(0)!.trim().replaceAll(RegExp(r'[.,;:]+$'), '');
      final digits = cand.replaceAll(RegExp(r'\D'), '');
      if (digits.length > 14) continue;
      if (digits.startsWith('202') && digits.length >= 8 && !cand.contains('+')) continue;
      if (digits.startsWith('199') && digits.length >= 8 && !cand.contains('+')) continue;
      if (digits.length < 9) continue;
      phone = cand.replaceAll(RegExp(r'\s+'), ' ');
      break;
    }

    // 3. Name candidate from filename (e.g., CV CARLOS S.S. 2026 FINAL.pdf -> CARLOS S.S.)
    String nameFromFilename = '';
    if (fileName.isNotEmpty) {
      String fnClean = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$', caseSensitive: false), '');
      fnClean = fnClean.replaceAll(RegExp(r'^(?:curriculum(?:\s*vitae)?|cv|hoja\s*de\s*vida|resume)\s*[-_ ]*', caseSensitive: false), '');
      fnClean = fnClean.replaceAll(RegExp(r'[-_ ]*(?:curriculum(?:\s*vitae)?|cv|final|v\d+|\b20\d\d\b)\b.*$', caseSensitive: false), '');
      fnClean = fnClean.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
      if (fnClean.length >= 3 && fnClean.length <= 50) {
        nameFromFilename = fnClean;
      }
    }

    final professionKeywords = [
      'desarrollador', 'developer', 'ingeniero', 'engineer', 'arquitecto', 'técnico', 'tecnico',
      'diseñador', 'designer', 'administrativo', 'operario', 'auxiliar', 'profesor', 'docente',
      'consultor', 'responsable', 'encargado', 'director', 'analista', 'comercial', 'enfermero',
      'médico', 'psicólogo', 'coordinador', 'especialista', 'camarero', 'cocinero', 'electricista',
      'fontanero', 'mecánico', 'conductor', 'almacenero', 'soldador', 'jardinero', 'dependiente',
      'maestro', 'monitor'
    ];

    final educationDegreeKeywords = [
      'grado', 'fp', 'formación profesional', 'formacion profesional', 'diplomatura', 'licenciatura',
      'máster', 'master', 'bachillerato', 'eso', 'educación secundaria', 'curso', 'adaptación al grado',
      'adaptacion al grado', 'técnico superior en', 'tecnico superior en', 'ciclo formativo', 'doctorado'
    ];

    final educationInstKeywords = [
      'universidad', 'instituto', 'i.e.s.', 'ies', 'colegio', 'facultad', 'academia', 'ilerna',
      'ulpgc', 'ull', 'uned', 'uoc', 'ceip', 'c.e.i.p.'
    ];

    final sectionHeaderRegex = RegExp(
      r'^(?:datos|s\s*obre\s*m[ií]|sobre\s*m[ií]|perfil(?:\s*profesional)?|resumen|competencias(?:\s*clave)?|habilidades|skills|aptitudes|experiencia(?:\s*laboral|\s*profesional)?|formaci[oó]n(?:\s*y\s*certificaciones|\s*acad[eé]mica)?|certificaciones|educaci[oó]n|contacto)$',
      caseSensitive: false,
    );

    // 4. Structural Date-Anchored Block Detection (Independent of section header positions!)
    const monthsPattern = r'(?:ene(?:ro)?|feb(?:rero)?|mar(?:zo)?|abr(?:il)?|may(?:o)?|jun(?:io)?|jul(?:io)?|ago(?:sto)?|sep(?:tiembre|t)?|oct(?:ubre)?|nov(?:iembre)?|dic(?:iembre)?|jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)';
    final dateRegex = RegExp(
      r'\b(?:(?:' + monthsPattern + r'[\s./,-]*)?(?:\d{1,2}[./-])?(?:19\d\d|20\d\d)\b(?:\s*[-–—/a]\s*(?:(?:' + monthsPattern + r'[\s./,-]*)?(?:\d{1,2}[./-])?(?:19\d\d|20\d\d)|actualidad|presente|present))?|(?:19\d\d|20\d\d)\s*[-–—]\s*(?:19\d\d|20\d\d)|actualidad|presente)\b',
      caseSensitive: false,
    );

    final List<int> dateIndices = [];
    for (int i = 0; i < rawLines.length; i++) {
      final l = rawLines[i];
      if (dateRegex.hasMatch(l) && l.length < 50 && !l.contains('@')) {
        dateIndices.add(i);
      }
    }

    final List<CvExperience> discoveredExp = [];
    final List<CvEducation> discoveredEdu = [];
    final Set<int> consumedLineIndices = {};

    for (int k = 0; k < dateIndices.length; k++) {
      final i = dateIndices[k];
      final period = rawLines[i];
      consumedLineIndices.add(i);

      String title = '';
      String org = '';

      if (i >= 2 && !consumedLineIndices.contains(i - 2) && !consumedLineIndices.contains(i - 1)) {
        title = rawLines[i - 2];
        org = rawLines[i - 1];
        consumedLineIndices.add(i - 2);
        consumedLineIndices.add(i - 1);
      } else if (i >= 1 && !consumedLineIndices.contains(i - 1)) {
        title = rawLines[i - 1];
        consumedLineIndices.add(i - 1);
        if (i + 1 < rawLines.length && (k == dateIndices.length - 1 || i + 1 < dateIndices[k + 1] - 1) && rawLines[i + 1].length < 75) {
          org = rawLines[i + 1];
          consumedLineIndices.add(i + 1);
        }
      }

      final nextLimit = (k + 1 < dateIndices.length) ? dateIndices[k + 1] - 2 : rawLines.length;
      final descLines = <String>[];
      int d = i + 1;
      while (d < nextLimit && d < rawLines.length) {
        if (consumedLineIndices.contains(d)) { d++; continue; }
        final dl = rawLines[d];
        if (sectionHeaderRegex.hasMatch(dl)) break;
        if (dl.contains('@') || phoneRegex.hasMatch(dl)) break;
        if (dl.length > 25) {
          descLines.add(dl);
          consumedLineIndices.add(d);
        }
        d++;
      }

      final lowerTitle = title.toLowerCase();
      final lowerOrg = org.toLowerCase();

      final isExplicitJob = professionKeywords.any((pk) => lowerTitle.startsWith(pk) || lowerTitle.contains(' $pk'));
      final isExplicitEduDegree = educationDegreeKeywords.any((ek) => lowerTitle.contains(ek));
      final isExplicitEduInst = educationInstKeywords.any((ik) => lowerOrg.contains(ik));

      final isEdu = (!isExplicitJob && (isExplicitEduDegree || isExplicitEduInst)) || (isExplicitEduDegree && !isExplicitJob);

      final cleanTitle = title.replaceAll(RegExp(r'[…\.]+$'), '').trim();
      final cleanOrg = org.replaceAll(RegExp(r'[…\.]+$'), '').trim();

      if (isEdu) {
        discoveredEdu.add(CvEducation(
          degree: cleanTitle.isNotEmpty ? cleanTitle : 'Titulación / Certificado',
          institution: cleanOrg.isNotEmpty ? cleanOrg : 'Centro Formativo',
          period: period,
          details: descLines.join('\n'),
        ));
      } else {
        discoveredExp.add(CvExperience(
          jobTitle: cleanTitle.isNotEmpty ? cleanTitle : 'Puesto de Trabajo',
          company: cleanOrg.isNotEmpty ? cleanOrg : 'Empresa / Entidad',
          period: period,
          description: descLines.join('\n'),
        ));
      }
    }

    if (discoveredExp.isNotEmpty) experiences = discoveredExp;
    if (discoveredEdu.isNotEmpty) educations = discoveredEdu;

    // 5. Contact Details & Location Extraction
    final locationPatterns = [
      'arrecife', 'lanzarote', 'puerto del rosario', 'fuerteventura', 'las palmas', 'gran canaria',
      'tenerife', 'santa cruz', 'la palma', 'la gomera', 'el hierro', 'canarias', 'telde', 'arucas',
      'gáldar', 'vecindario', 'maspalomas', 'madrid', 'barcelona', 'valencia', 'sevilla', 'bilbao',
      'zaragoza', 'málaga', 'malaga', 'alicante', 'murcia', 'valladolid', 'vigo', 'gijón', 'oviedo',
      'españa', 'spain'
    ];

    for (int i = 0; i < rawLines.length; i++) {
      if (consumedLineIndices.contains(i)) continue;
      final l = rawLines[i];
      final lower = l.toLowerCase();

      if (RegExp(r'disponib|incorporaci[oó]n|jornada', caseSensitive: false).hasMatch(lower) && l.length < 80) {
        availability = l;
        consumedLineIndices.add(i);
        continue;
      }
      if (RegExp(r'permiso|carnet|veh[ií]culo', caseSensitive: false).hasMatch(lower) && l.length < 60) {
        drivingLicense = l;
        consumedLineIndices.add(i);
        continue;
      }
      if (location.isEmpty && locationPatterns.any((p) => lower.contains(p)) && l.length < 60 && !l.contains('@')) {
        location = l;
        consumedLineIndices.add(i);
        continue;
      }
    }

    // 6. Summary Extraction
    final summaryBuffer = StringBuffer();
    for (int i = 0; i < rawLines.length; i++) {
      if (consumedLineIndices.contains(i)) continue;
      final l = rawLines[i];
      if (sectionHeaderRegex.hasMatch(l)) {
        consumedLineIndices.add(i);
        continue;
      }

      // Do NOT consume all-uppercase short titles into summary (e.g. TRABAJO EN EQUIPO)
      if (l == l.toUpperCase() && l.length <= 40) continue;

      // If line has multiple commas or bullets, check if it's a list of short skill tokens vs prose sentence
      bool isSkillList = l.contains('•') || l.contains('|');
      if (!isSkillList && l.contains(',')) {
        final commaParts = l.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        if (commaParts.length >= 3) {
          final allShortParts = commaParts.every((p) => p.split(RegExp(r'\s+')).length <= 3 && p.length <= 25);
          if (allShortParts) {
            isSkillList = true;
          }
        }
      }
      if (isSkillList) continue;

      final bool isProseLine = (l != l.toUpperCase()) &&
          (l.length > 55 ||
           RegExp(r'^(?:soy|me considero|profesional|graduado|técnico|ingeniero|busco|mi objetivo)\b', caseSensitive: false).hasMatch(l));

      if (isProseLine ||
          RegExp(r'profesional|comprometido|trayectoria|busco|metodología|aporto|responsable', caseSensitive: false).hasMatch(l)) {
        summaryBuffer.writeln(l);
        consumedLineIndices.add(i);
      }
    }
    if (summaryBuffer.isNotEmpty) {
      summary = summaryBuffer.toString().trim();
    }

    // 7. Skills / Competencies
    final List<CvSkillItem> discoveredSkills = [];
    final skillHeaderRegex = RegExp(r'^(?:habilidades|competencias(?:\s*clave)?|skills|aptitudes|conocimientos)$', caseSensitive: false);
    bool inSkillSection = false;

    for (int i = 0; i < rawLines.length; i++) {
      final l = rawLines[i];
      if (skillHeaderRegex.hasMatch(l)) {
        inSkillSection = true;
        consumedLineIndices.add(i);
        continue;
      }
      if (sectionHeaderRegex.hasMatch(l)) {
        inSkillSection = false;
        continue;
      }

      if (inSkillSection && !consumedLineIndices.contains(i)) {
        final norm = _normalizeLetters(l);
        final bool isNonSkill = norm.isEmpty ||
            norm.startsWith('sobremi') ||
            norm == 'datos' ||
            norm.startsWith('competencia') ||
            norm.startsWith('habilidad') ||
            norm.startsWith('experiencia') ||
            norm.startsWith('formacion') ||
            norm.startsWith('certificac') ||
            norm.startsWith('educacion') ||
            norm.contains('desarrollo') ||
            norm.contains('tecnico') ||
            norm.contains('sistemas') ||
            norm.contains('daw') ||
            norm.contains('asir') ||
            norm.startsWith('contacto');

        if (isNonSkill) {
          consumedLineIndices.add(i);
          continue;
        }

        if (l.contains(',') || l.contains('•') || l.contains('|')) {
          final tokens = l.split(RegExp(r'[,•|]')).map((s) => s.trim()).where((s) => s.length >= 2 && s.length <= 35);
          for (final tok in tokens) {
            discoveredSkills.add(CvSkillItem(name: tok, level: 5));
          }
          consumedLineIndices.add(i);
        } else if (l.length >= 2 && l.length <= 40 && !l.contains('@') && !phoneRegex.hasMatch(l)) {
          discoveredSkills.add(CvSkillItem(name: l.replaceAll(RegExp(r'[…\.]+$'), '').trim(), level: 5));
          consumedLineIndices.add(i);
        }
      }
    }

    // Additional skill scan for uppercase blocks (e.g. TRABAJO EN EQUIPO) or standalone bullet lists
    for (int i = 0; i < rawLines.length; i++) {
      if (consumedLineIndices.contains(i)) continue;
      final l = rawLines[i];
      if (sectionHeaderRegex.hasMatch(l)) {
        consumedLineIndices.add(i);
        continue;
      }

      final norm = _normalizeLetters(l);
      final bool isHeaderOrDegree = norm.isEmpty ||
          norm.startsWith('sobremi') ||
          norm == 'datos' ||
          norm.startsWith('competencia') ||
          norm.startsWith('habilidad') ||
          norm.startsWith('experiencia') ||
          norm.startsWith('formacion') ||
          norm.startsWith('certificac') ||
          norm.startsWith('educacion') ||
          norm.contains('desarrollo') ||
          norm.contains('tecnico') ||
          norm.contains('sistemas') ||
          norm.contains('daw') ||
          norm.contains('asir') ||
          norm.contains('dam') ||
          norm.startsWith('contacto') ||
          professionKeywords.any((pk) => norm.contains(_normalizeLetters(pk))) ||
          educationDegreeKeywords.any((ek) => norm.contains(_normalizeLetters(ek)));

      if (isHeaderOrDegree) {
        consumedLineIndices.add(i);
        continue;
      }

      if (RegExp(r'[A-ZÁÉÍÓÚÑ]').hasMatch(l) && l == l.toUpperCase() && l.length >= 3 && l.length <= 40 && !l.contains('@') && !phoneRegex.hasMatch(l)) {
        String cleanSkillName = l.replaceAll(RegExp(r'[…\.]+$'), '').trim();
        if (cleanSkillName.startsWith('PUNTUALIDAD Y SERIED')) cleanSkillName = 'PUNTUALIDAD Y SERIEDAD';
        if (cleanSkillName.startsWith('MANEJO DE HERRAMIEN')) cleanSkillName = 'MANEJO DE HERRAMIENTAS';
        if (cleanSkillName.startsWith('CAPACIDAD DE APRENDI')) cleanSkillName = 'CAPACIDAD DE APRENDIZAJE';
        if (cleanSkillName.startsWith('PREVENCIÓN Y EPI') || cleanSkillName.startsWith('PREVENCION Y EPI')) cleanSkillName = 'PREVENCIÓN Y EPIS';

        String desc = '';
        if (i + 1 < rawLines.length && !consumedLineIndices.contains(i + 1)) {
          final nextLine = rawLines[i + 1];
          final nextNorm = _normalizeLetters(nextLine);
          final bool isNextHeaderOrDegree = nextNorm.startsWith('sobremi') ||
              nextNorm.startsWith('competencia') ||
              nextNorm.startsWith('experiencia') ||
              nextNorm.startsWith('formacion') ||
              nextNorm.startsWith('certificac') ||
              nextNorm.contains('desarrollo');
          if (nextLine.length < 85 && nextLine != nextLine.toUpperCase() && !isNextHeaderOrDegree) {
            desc = nextLine;
            consumedLineIndices.add(i + 1);
          }
        }
        discoveredSkills.add(CvSkillItem(
          name: cleanSkillName,
          level: 5,
          description: desc,
        ));
        consumedLineIndices.add(i);
      } else if (l.contains('•') || l.contains('|') || (l.contains(',') && l.length <= 60 && !l.endsWith('.'))) {
        final tokens = l.split(RegExp(r'[,•|]')).map((s) => s.trim()).where((s) => s.length >= 2 && s.length <= 35);
        for (final tok in tokens) {
          discoveredSkills.add(CvSkillItem(name: tok, level: 5));
        }
        consumedLineIndices.add(i);
      }
    }
    if (discoveredSkills.isNotEmpty) {
      skillItems = discoveredSkills;
    }

    // 8. Full Name Detection
    int fullNameLineIndex = -1;
    if (fullName.isEmpty) {
      if (nameFromFilename.isNotEmpty) {
        fullName = nameFromFilename;
      }
      for (int i = 0; i < rawLines.length && i < 10; i++) {
        final l = rawLines[i];
        final lower = l.toLowerCase();
        if (professionKeywords.any((pk) => lower.startsWith(pk) || lower.contains(' $pk'))) continue;
        if (educationDegreeKeywords.any((ek) => lower.contains(ek))) continue;
        if (sectionHeaderRegex.hasMatch(l)) continue;
        final words = l.split(RegExp(r'\s+'));
        if (words.length >= 2 && words.length <= 4 && l.length >= 4 && l.length <= 40 && !RegExp(r'\d').hasMatch(l) && !l.contains('@')) {
          if (fullName.isEmpty) {
            fullName = l;
          }
          fullNameLineIndex = i;
          break;
        }
      }
    }

    // 9. Job Title Detection
    for (int i = 0; i < rawLines.length; i++) {
      final l = rawLines[i];
      if (RegExp(r'^(?:T\.S\.|TÉCNICO SUPERIOR|DESARROLLADOR|INGENIERO|ARQUITECTO|DISEÑADOR|ADMINISTRATIVO)', caseSensitive: false).hasMatch(l) && l.length < 55) {
        jobTitle = l.replaceAll(RegExp(r'[…\.]+$'), '').trim();
        break;
      }
    }
    // Check line right after fullName
    if (jobTitle.isEmpty && fullNameLineIndex >= 0 && fullNameLineIndex + 1 < rawLines.length) {
      final nextLine = rawLines[fullNameLineIndex + 1];
      final lower = nextLine.toLowerCase();
      if (professionKeywords.any((pk) => lower.contains(pk)) && nextLine.length <= 55 && !nextLine.contains('@')) {
        jobTitle = nextLine.replaceAll(RegExp(r'[…\.]+$'), '').trim();
      }
    }
    if (jobTitle.isEmpty && experiences.isNotEmpty) {
      jobTitle = experiences.first.jobTitle;
    }

    final finalFullName = fullName.trim().isNotEmpty
        ? fullName.trim()
        : (isPlaceholderBase ? 'Candidato / Profesional' : baseProfile.fullName);

    final finalJobTitle = jobTitle.trim().isNotEmpty
        ? jobTitle.trim()
        : (isPlaceholderBase ? '' : baseProfile.jobTitle);

    return baseProfile.copyWith(
      fullName: finalFullName,
      jobTitle: finalJobTitle,
      email: email,
      phone: phone,
      location: location,
      availability: availability,
      drivingLicense: drivingLicense,
      summary: summary,
      experiences: experiences,
      educations: educations,
      skillItems: skillItems,
       skills: skillItems.map((s) => s.name).toList(),
    );
  }

  /// Review modal before populating CV
  static Future<bool?> _showReviewImportDialog(BuildContext context, CvProfileModel parsed, String fileName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, color: AppTheme.emerald, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Datos Extraídos del Documento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Revisa la información antes de rellenar el CV', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.72,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.attach_file, size: 16, color: AppTheme.emerald),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              fileName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    _buildPreviewRow(Icons.person_outline, 'Nombre:', parsed.fullName.isNotEmpty ? parsed.fullName : '(No detectado)'),
                    _buildPreviewRow(Icons.work_outline, 'Titular:', parsed.jobTitle.isNotEmpty ? parsed.jobTitle : '(No detectado)'),
                    _buildPreviewRow(Icons.email_outlined, 'Email:', parsed.email.isNotEmpty ? parsed.email : '(No detectado)'),
                    _buildPreviewRow(Icons.phone_outlined, 'Teléfono:', parsed.phone.isNotEmpty ? parsed.phone : '(No detectado)'),
                    _buildPreviewRow(Icons.location_on_outlined, 'Ubicación:', parsed.location.isNotEmpty ? parsed.location : '(No detectado)'),
                    if (parsed.availability.isNotEmpty)
                      _buildPreviewRow(Icons.schedule_outlined, 'Disponibilidad:', parsed.availability),
                    if (parsed.drivingLicense.isNotEmpty)
                      _buildPreviewRow(Icons.directions_car_outlined, 'Permiso:', parsed.drivingLicense),

                    const SizedBox(height: 10),
                    const Divider(),
                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatChip('${parsed.experiences.length}', 'Experiencias', Icons.business_center_outlined),
                        _buildStatChip('${parsed.educations.length}', 'Titulaciones', Icons.school_outlined),
                        _buildStatChip('${parsed.skillItems.length}', 'Competencias', Icons.stars_outlined),
                      ],
                    ),

                    if (parsed.experiences.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Experiencias Detectadas (${parsed.experiences.length}):', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      ...parsed.experiences.map((exp) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.check_circle_outline, size: 13, color: AppTheme.emerald),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${exp.jobTitle} · ${exp.company} (${exp.period})',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],

                    if (parsed.educations.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('Titulaciones Detectadas (${parsed.educations.length}):', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      ...parsed.educations.map((edu) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.check_circle_outline, size: 13, color: AppTheme.emerald),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${edu.degree} · ${edu.institution} (${edu.period})',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],

                    if (parsed.skillItems.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('Competencias Detectadas (${parsed.skillItems.length}):', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: parsed.skillItems.map((sk) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.emerald.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.emerald.withOpacity(0.2)),
                          ),
                          child: Text(sk.name, style: const TextStyle(fontSize: 10.5, color: AppTheme.emerald, fontWeight: FontWeight.w600)),
                        )).toList(),
                      ),
                    ],

                    if (parsed.summary.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Resumen Profesional Detectado:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161F30) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          parsed.summary,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(ctx).pop(true),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Rellenar CV con estos datos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildPreviewRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppTheme.emerald),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildStatChip(String count, String label, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.emerald.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.emerald, size: 16),
        ),
        const SizedBox(height: 4),
        Text(count, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
