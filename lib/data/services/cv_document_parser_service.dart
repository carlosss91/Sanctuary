import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/cv_profile_model.dart';
import '../../core/theme/app_theme.dart';
import 'pdf_extractor_stub.dart'
    if (dart.library.html) 'pdf_extractor_web.dart';

class CvDocumentParserService {
  /// Prompts user to select a .pdf or .docx document, extracts its text, and parses into a CvProfileModel
  static Future<CvProfileModel?> pickAndParseCvDocument(BuildContext context, CvProfileModel baseProfile) async {
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

        // 2. High-fidelity extraction via Mozilla pdf.js (decodes subsetted font glyphs & CMaps on Web / GitHub Pages)
        try {
          final webPdfText = await extractTextWithPdfJsWeb(bytes);
          if (webPdfText.trim().isNotEmpty) {
            extractedText = webPdfText;
          }
        } catch (e) {
          debugPrint('[CvDocumentParserService] extractTextWithPdfJsWeb aviso: $e');
        }

        // 3. Fallback to native Dart PDF extraction (with CMap stream decoding & TJ array parsing)
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

      final parsed = _parseCvText(extractedText, baseProfile);

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

  /// Robust heuristic semantic parser for CV contents
  static CvProfileModel _parseCvText(String rawText, CvProfileModel baseProfile) {
    final cleanText = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = cleanText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
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
    String summary = (isPlaceholderBase || baseProfile.summary.startsWith('Persona responsable y motivada')) ? '' : baseProfile.summary;
    List<CvExperience> experiences = isPlaceholderBase ? [] : List.from(baseProfile.experiences);
    List<CvEducation> educations = isPlaceholderBase ? [] : List.from(baseProfile.educations);
    List<CvSkillItem> skillItems = isPlaceholderBase ? [] : List.from(baseProfile.skillItems);

    // 1. Regex search for email
    final emailRegex = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
    final emailMatch = emailRegex.firstMatch(cleanText);
    if (emailMatch != null) {
      email = emailMatch.group(0)!.replaceAll(RegExp(r'[.,;:]+$'), '');
    }

    // 2. Regex search for phone number (strictly rejecting PDF timestamps like 20260916...)
    final phoneRegex = RegExp(r'(?:\+?34[-.\s]?)?[6789]\d{2}[-.\s]?\d{2,3}[-.\s]?\d{2,3}[-.\s]?\d{2,3}|(?:\+?\d{1,3}[-.\s]?)?\(?\d{2,4}\)?[-.\s]?\d{3,4}[-.\s]?\d{3,4}');
    for (final m in phoneRegex.allMatches(cleanText)) {
      final cand = m.group(0)!.trim().replaceAll(RegExp(r'[.,;:]+$'), '');
      final digits = cand.replaceAll(RegExp(r'\D'), '');
      // Strict rejection of PDF timestamps and metadata numbers (e.g. 20260916164141, 1999..., /CreationDate)
      if (digits.length > 14) continue;
      if (digits.startsWith('202') && digits.length >= 8 && !cand.contains('+')) continue;
      if (digits.startsWith('199') && digits.length >= 8 && !cand.contains('+')) continue;
      if (digits.length < 9) continue;
      phone = cand.replaceAll(RegExp(r'\s+'), ' ');
      break;
    }

    // 3. Location detection
    final locationPatterns = [
      'gran canaria', 'las palmas', 'tenerife', 'canarias', 'arucas', 'telde', 'gáldar', 'vecindario', 'maspalomas',
      'madrid', 'barcelona', 'valencia', 'sevilla', 'bilbao', 'zaragoza', 'málaga', 'malaga', 'alicante', 'murcia',
      'valladolid', 'vigo', 'gijón', 'oviedo', 'españa', 'spain'
    ];
    for (final line in lines) {
      final lower = line.toLowerCase();
      // Check explicit label
      final labelMatch = RegExp(r'^(?:ubicación|ubicacion|dirección|direccion|ciudad|localidad|residencia|domicilio|address|location)\s*[:\-]\s*(.+)$', caseSensitive: false).firstMatch(line);
      if (labelMatch != null && labelMatch.group(1)!.trim().isNotEmpty) {
        location = labelMatch.group(1)!.trim();
        break;
      }
      if (locationPatterns.any((pat) => lower.contains(pat)) && line.length < 65 && !line.contains('@')) {
        location = line;
        break;
      }
    }

    // 4. Name & Job title detection from header lines
    // First, check explicit label matches
    for (final line in lines) {
      if (fullName.isEmpty) {
        final nameMatch = RegExp(r'^(?:nombre(?:\s+completo|\s+y\s+apellidos)?|candidato|datos\s+personales)\s*[:\-]\s*(.+)$', caseSensitive: false).firstMatch(line);
        if (nameMatch != null && nameMatch.group(1)!.trim().length >= 3) {
          fullName = nameMatch.group(1)!.trim();
        }
      }
      if (jobTitle.isEmpty) {
        final jobMatch = RegExp(r'^(?:puesto|cargo|profesión|profesion|titular|perfil|especialidad|ocupación|ocupacion)\s*[:\-]\s*(.+)$', caseSensitive: false).firstMatch(line);
        if (jobMatch != null && jobMatch.group(1)!.trim().length >= 3) {
          jobTitle = jobMatch.group(1)!.trim();
        }
      }
    }

    // Candidate lines for header if not found via labels
    final candidateLines = lines.where((line) {
      final up = line.toUpperCase().trim();
      return up != 'CURRICULUM' &&
          up != 'CURRICULUM VITAE' &&
          up != 'CURRÍCULUM VITAE' &&
          up != 'CV' &&
          up != 'HOJA DE VIDA' &&
          up != 'RESUME' &&
          up != 'DATOS PERSONALES' &&
          up != 'CONTACTO' &&
          up != 'PORTFOLIO' &&
          !up.startsWith('PAGE ') &&
          !up.startsWith('PÁGINA ') &&
          !up.contains('CREATIONDATE') &&
          !up.contains('PRODUCER') &&
          !line.contains('http') &&
          !line.contains('@') &&
          !RegExp(r'^\d+$').hasMatch(line);
    }).toList();

    final professionKeywords = [
      'desarrollador', 'developer', 'ingeniero', 'engineer', 'arquitecto', 'técnico', 'tecnico',
      'diseñador', 'designer', 'administrativo', 'operario', 'auxiliar', 'profesor', 'docente',
      'consultor', 'responsable', 'encargado', 'director', 'analista', 'comercial', 'enfermero',
      'médico', 'psicólogo', 'coordinador', 'especialista', 'camarero', 'cocinero', 'electricista',
      'fontanero', 'mecánico', 'conductor', 'almacenero', 'soldador', 'jardinero', 'dependiente'
    ];

    for (int i = 0; i < candidateLines.length && i < 10; i++) {
      final line = candidateLines[i].trim();
      if (line.isEmpty || line.contains(':')) continue;

      if (fullName.isEmpty) {
        // Name usually has 2-5 words, no digits, proper length
        final words = line.split(RegExp(r'\s+'));
        if (line.length >= 4 && line.length <= 48 && words.length >= 2 && words.length <= 5 && !RegExp(r'\d').hasMatch(line)) {
          fullName = line;
          continue;
        }
      } else if (jobTitle.isEmpty && line != fullName) {
        final lower = line.toLowerCase();
        if (professionKeywords.any((pk) => lower.contains(pk)) || (line.length >= 3 && line.length <= 55 && !RegExp(r'\d').hasMatch(line))) {
          jobTitle = line;
          break;
        }
      }
    }

    // 5. Section parsing
    String currentSection = '';
    final summaryBuffer = StringBuffer();
    final List<String> rawExpBlocks = [];
    final List<String> rawEduBlocks = [];
    final List<String> rawSkillTokens = [];

    final sectionHeaders = {
      'summary': [
        'perfil', 'resumen', 'sobre mí', 'sobre mi', 'summary', 'about me', 'acerca de',
        'perfil profesional', 'resumen profesional', 'presentación', 'bio', 'extracto',
        'objetivo profesional', 'objetivo', 'perfil laboral'
      ],
      'experience': [
        'experiencia', 'experiencia laboral', 'experiencia profesional', 'historial laboral',
        'historial profesional', 'trayectoria', 'trayectoria laboral', 'work experience', 'experience',
        'empleo', 'cargos', 'puestos desempeñados', 'vida laboral', 'actividad profesional'
      ],
      'education': [
        'educación', 'educacion', 'formación', 'formacion', 'formación académica', 'formacion academica',
        'estudios', 'estudios realizados', 'education', 'certificaciones', 'titulación', 'titulaciones',
        'titulacion', 'cursos y certificaciones', 'diplomas', 'cursos', 'formación complementaria',
        'formacion complementaria', 'grados'
      ],
      'skills': [
        'habilidades', 'competencias', 'competencias clave', 'competencias profesionales', 'skills',
        'conocimientos', 'conocimientos técnicos', 'aptitudes', 'tecnologías', 'tecnologias',
        'herramientas', 'destrezas', 'habilidades técnicas', 'habilidades blandas'
      ],
      'contact': ['contacto', 'datos personales', 'contact', 'datos de contacto', 'información de contacto'],
    };

    for (final line in lines) {
      final cleanLine = line.replaceAll(RegExp(r'^[0-9.\-–—\s*•|]+'), '').trim();
      final lower = cleanLine.toLowerCase().replaceAll(RegExp(r'[^\w\sáéíóúñ]'), '').trim();

      String? matchedSection;
      for (final entry in sectionHeaders.entries) {
        if (entry.value.any((kw) => lower == kw || lower.startsWith('$kw ') || lower.endsWith(' $kw'))) {
          matchedSection = entry.key;
          break;
        }
      }

      if (matchedSection != null) {
        currentSection = matchedSection;
        continue;
      }

      switch (currentSection) {
        case 'summary':
          if (summaryBuffer.length < 800) {
            summaryBuffer.writeln(line);
          }
          break;
        case 'experience':
          rawExpBlocks.add(line);
          break;
        case 'education':
          rawEduBlocks.add(line);
          break;
        case 'skills':
          if (line.contains(',') || line.contains('•') || line.contains('-') || line.contains('|') || line.contains('/')) {
            rawSkillTokens.addAll(line.split(RegExp(r'[,•|/\-]')).map((s) => s.trim()).where((s) => s.length >= 2));
          } else if (line.length < 40) {
            rawSkillTokens.add(line);
          }
          break;
        case 'contact':
          if (locationPatterns.any((pat) => line.toLowerCase().contains(pat))) {
            location = line;
          }
          break;
      }
    }

    if (summaryBuffer.isNotEmpty) {
      summary = summaryBuffer.toString().trim();
    }

    // 6. Robust Parse Experience Items from blocks
    if (rawExpBlocks.isNotEmpty) {
      final parsedExperiences = <CvExperience>[];
      for (int i = 0; i < rawExpBlocks.length; i++) {
        final line = rawExpBlocks[i];
        final isDateLine = RegExp(r'\b(19\d\d|20\d\d)\b').hasMatch(line) ||
            line.toLowerCase().contains('actualidad') ||
            line.toLowerCase().contains('presente');

        if (isDateLine && parsedExperiences.length < 8) {
          String title = '';
          String company = '';
          String period = line;

          if (i >= 2 && rawExpBlocks[i - 2].length < 80 && rawExpBlocks[i - 1].length < 80) {
            title = rawExpBlocks[i - 2];
            company = rawExpBlocks[i - 1];
          } else if (i >= 1 && rawExpBlocks[i - 1].length < 80) {
            title = rawExpBlocks[i - 1];
            if (i + 1 < rawExpBlocks.length && rawExpBlocks[i + 1].length < 80) {
              company = rawExpBlocks[i + 1];
            }
          }

          if (line.contains('|') || line.contains(' - ')) {
            final parts = line.split(RegExp(r'[|–—\-]')).map((s) => s.trim()).toList();
            if (parts.length >= 2) {
              if (title.isEmpty) title = parts[0];
              period = parts.last;
            }
          }

          if (title.isEmpty) title = 'Puesto / Responsabilidad';
          if (company.isEmpty) company = 'Empresa / Entidad';

          final descLines = <String>[];
          int d = (company == (i + 1 < rawExpBlocks.length ? rawExpBlocks[i + 1] : '')) ? i + 2 : i + 1;
          while (d < rawExpBlocks.length && !RegExp(r'\b(19\d\d|20\d\d)\b').hasMatch(rawExpBlocks[d]) && descLines.length < 4) {
            descLines.add(rawExpBlocks[d]);
            d++;
          }

          parsedExperiences.add(CvExperience(
            jobTitle: title,
            company: company,
            period: period,
            description: descLines.join('\n'),
          ));
        }
      }
      if (parsedExperiences.isNotEmpty) {
        experiences = parsedExperiences;
      }
    }

    // 7. Robust Parse Education Items from blocks
    if (rawEduBlocks.isNotEmpty) {
      final parsedEducation = <CvEducation>[];
      for (int i = 0; i < rawEduBlocks.length; i++) {
        final line = rawEduBlocks[i];
        final isDateLine = RegExp(r'\b(19\d\d|20\d\d)\b').hasMatch(line) ||
            line.toLowerCase().contains('actualidad') ||
            line.toLowerCase().contains('curso');

        if (isDateLine && parsedEducation.length < 6) {
          String degree = '';
          String institution = '';
          String period = line;

          if (i >= 2 && rawEduBlocks[i - 2].length < 90 && rawEduBlocks[i - 1].length < 90) {
            degree = rawEduBlocks[i - 2];
            institution = rawEduBlocks[i - 1];
          } else if (i >= 1 && rawEduBlocks[i - 1].length < 90) {
            degree = rawEduBlocks[i - 1];
            if (i + 1 < rawEduBlocks.length && rawEduBlocks[i + 1].length < 90) {
              institution = rawEduBlocks[i + 1];
            }
          }

          if (line.contains('|') || line.contains(' - ')) {
            final parts = line.split(RegExp(r'[|–—\-]')).map((s) => s.trim()).toList();
            if (parts.length >= 2) {
              if (degree.isEmpty) degree = parts[0];
              period = parts.last;
            }
          }

          if (degree.isEmpty) degree = 'Certificado / Titulación';
          if (institution.isEmpty) institution = 'Centro Formativo';

          final detailLines = <String>[];
          int d = (institution == (i + 1 < rawEduBlocks.length ? rawEduBlocks[i + 1] : '')) ? i + 2 : i + 1;
          while (d < rawEduBlocks.length && !RegExp(r'\b(19\d\d|20\d\d)\b').hasMatch(rawEduBlocks[d]) && detailLines.length < 3) {
            detailLines.add(rawEduBlocks[d]);
            d++;
          }

          parsedEducation.add(CvEducation(
            degree: degree,
            institution: institution,
            period: period,
            details: detailLines.isNotEmpty ? detailLines.join('. ') : '',
          ));
        }
      }
      if (parsedEducation.isNotEmpty) {
        educations = parsedEducation;
      }
    }

    // 8. Parse Skills
    if (rawSkillTokens.isNotEmpty) {
      final uniqueSkills = rawSkillTokens
          .map((s) => s.trim())
          .where((s) => s.length >= 2 && s.length <= 40 && !s.contains(':') && !s.toLowerCase().startsWith('http'))
          .toSet()
          .take(15)
          .map((name) => CvSkillItem(name: name, level: 5, description: 'Competencia técnica o profesional'))
          .toList();

      if (uniqueSkills.isNotEmpty) {
        skillItems = uniqueSkills;
      }
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
            width: 500,
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
                    ...parsed.experiences.take(3).map((exp) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, size: 13, color: AppTheme.emerald),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${exp.jobTitle} · ${exp.company} (${exp.period})',
                              style: const TextStyle(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                    ...parsed.educations.take(3).map((edu) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, size: 13, color: AppTheme.emerald),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${edu.degree} · ${edu.institution} (${edu.period})',
                              style: const TextStyle(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                      children: parsed.skillItems.take(10).map((sk) => Container(
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
