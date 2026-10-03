import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/cv_profile_model.dart';
import '../../core/theme/app_theme.dart';

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
        // 1. Check for embedded Sanctuary CV JSON metadata for 100% perfect reconstruction
        final rawStr = latin1.decode(bytes);
        final metaMatch = RegExp(r'SanctuaryCV::([A-Za-z0-9+/=]+)').firstMatch(rawStr);
        if (metaMatch != null) {
          try {
            final jsonStr = utf8.decode(base64Decode(metaMatch.group(1)!));
            final data = jsonDecode(jsonStr);
            if (data is Map<String, dynamic> && data.containsKey('fullName')) {
              final exactProfile = CvProfileModel.fromJson(data);
              if (!context.mounted) return exactProfile;
              final confirmed = await _showReviewImportDialog(context, exactProfile, fileName);
              if (confirmed == true) return exactProfile;
              return null;
            }
          } catch (e) {
            debugPrint('Aviso: no se pudo decodificar metadata SanctuaryCV: $e');
          }
        }

        extractedText = _extractTextFromPdf(bytes);
      } else {
        extractedText = utf8.decode(bytes, allowMalformed: true);
      }

      if (extractedText.trim().isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se encontró contenido de texto legible en el documento.')),
          );
        }
        return null;
      }

      final parsed = _parseCvText(extractedText, baseProfile);

      if (!context.mounted) return parsed;

      // Show Confirmation / Review Modal to the user before overwriting
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
  static String _extractTextFromPdf(Uint8List bytes) {
    final buffer = StringBuffer();
    try {
      // 1. Scan and decompress all FlateDecode streams (where actual page text is stored)
      final decompressedStreams = _extractAndDecompressPdfStreams(bytes);
      for (final streamText in decompressedStreams) {
        _extractTextFromStreamContent(streamText, buffer);
      }

      // 2. Also scan uncompressed raw string for uncompressed PDFs
      final rawStr = latin1.decode(bytes);
      _extractTextFromStreamContent(rawStr, buffer);

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

  static void _extractTextFromStreamContent(String content, StringBuffer buffer) {
    // 1. Text inside ( ... ) Tj
    final tjRegex = RegExp(r'\((.*?)\)\s*Tj', dotAll: true);
    for (final m in tjRegex.allMatches(content)) {
      final val = m.group(1);
      if (val != null && val.isNotEmpty) {
        buffer.writeln(_sanitizePdfString(val));
      }
    }

    // 2. Text array [ (part1) 120 (part2) ] TJ
    final arrayTjRegex = RegExp(r'\[(.*?)\]\s*TJ', dotAll: true);
    for (final m in arrayTjRegex.allMatches(content)) {
      final arr = m.group(1) ?? '';
      final innerStrings = RegExp(r'\((.*?)\)').allMatches(arr);
      final line = innerStrings.map((im) => im.group(1) ?? '').join(' ');
      if (line.trim().isNotEmpty) {
        buffer.writeln(_sanitizePdfString(line));
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

  /// Heuristic semantic parser for CV contents
  static CvProfileModel _parseCvText(String rawText, CvProfileModel baseProfile) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String fullName = baseProfile.fullName;
    String jobTitle = baseProfile.jobTitle;
    String email = baseProfile.email;
    String phone = baseProfile.phone;
    String location = baseProfile.location;
    String summary = baseProfile.summary;
    List<CvExperience> experiences = List.from(baseProfile.experiences);
    List<CvEducation> educations = List.from(baseProfile.educations);
    List<CvSkillItem> skillItems = List.from(baseProfile.skillItems);

    // 1. Regex search for email
    final emailRegex = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
    final emailMatch = emailRegex.firstMatch(rawText);
    if (emailMatch != null) {
      email = emailMatch.group(0)!;
    }

    // 2. Regex search for phone number
    final phoneRegex = RegExp(r'(?:\+?34[-.\s]?)?[6789]\d{2}[-.\s]?\d{3}[-.\s]?\d{3}|(?:\+?\d{1,3}[-.\s]?)?\(?\d{2,4}\)?[-.\s]?\d{3,4}[-.\s]?\d{3,4}');
    final phoneMatch = phoneRegex.firstMatch(rawText);
    if (phoneMatch != null) {
      phone = phoneMatch.group(0)!.replaceAll(RegExp(r'\s+'), ' ');
    }

    // 3. Location detection
    final locationPatterns = [
      'gran canaria', 'canarias', 'arucas', 'las palmas', 'tenerife',
      'madrid', 'barcelona', 'valencia', 'sevilla', 'bilbao', 'zaragoza',
      'málaga', 'malaga', 'españa', 'spain'
    ];
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (locationPatterns.any((pat) => lower.contains(pat)) && line.length < 60 && !line.contains('@')) {
        location = line;
        break;
      }
    }

    // 4. Name & Job title detection from header lines
    for (int i = 0; i < lines.length && i < 6; i++) {
      final line = lines[i];
      if (line.contains('@') || line.contains('+') || RegExp(r'\d{5,}').hasMatch(line)) {
        continue;
      }
      if (fullName.isEmpty || fullName == 'NOMBRE Y APELLIDOS') {
        if (line.length >= 3 && line.length <= 45 && !line.contains(':') && !line.contains('http')) {
          fullName = line;
          continue;
        }
      } else if (jobTitle.isEmpty) {
        if (line.length >= 3 && line.length <= 55 && !line.contains(':')) {
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
        'perfil profesional', 'resumen profesional', 'presentación', 'bio'
      ],
      'experience': [
        'experiencia', 'experiencia laboral', 'experiencia profesional', 'historial laboral',
        'trayectoria', 'trayectoria laboral', 'work experience', 'experience', 'empleo',
        'cargos', 'puestos desempeñados'
      ],
      'education': [
        'educación', 'educacion', 'formación', 'formacion', 'formación académica',
        'estudios', 'education', 'certificaciones', 'titulación', 'titulaciones',
        'titulacion', 'cursos y certificaciones', 'diplomas'
      ],
      'skills': [
        'habilidades', 'competencias', 'competencias clave', 'skills', 'conocimientos',
        'aptitudes', 'tecnologías', 'herramientas', 'destrezas'
      ],
      'contact': ['contacto', 'datos personales', 'contact', 'datos de contacto'],
    };

    for (final line in lines) {
      final lower = line.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();

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
          if (line.contains(',') || line.contains('•') || line.contains('-') || line.contains('|')) {
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
          final title = (i > 0 && rawExpBlocks[i - 1].length < 75) ? rawExpBlocks[i - 1] : 'Operario / Especialista';
          final company = (i + 1 < rawExpBlocks.length && rawExpBlocks[i + 1].length < 75) ? rawExpBlocks[i + 1] : 'Empresa / Entidad';
          final descLines = <String>[];
          int d = i + 2;
          while (d < rawExpBlocks.length && !RegExp(r'\b(19\d\d|20\d\d)\b').hasMatch(rawExpBlocks[d]) && descLines.length < 4) {
            descLines.add(rawExpBlocks[d]);
            d++;
          }

          parsedExperiences.add(CvExperience(
            jobTitle: title,
            company: company,
            period: line,
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
          final degree = (i > 0 && rawEduBlocks[i - 1].length < 85) ? rawEduBlocks[i - 1] : 'Certificado de Profesionalidad / Titulación';
          final institution = (i + 1 < rawEduBlocks.length && rawEduBlocks[i + 1].length < 85) ? rawEduBlocks[i + 1] : 'Centro Formativo';
          final detailLines = <String>[];
          int d = i + 2;
          while (d < rawEduBlocks.length && !RegExp(r'\b(19\d\d|20\d\d)\b').hasMatch(rawEduBlocks[d]) && detailLines.length < 3) {
            detailLines.add(rawEduBlocks[d]);
            d++;
          }

          parsedEducation.add(CvEducation(
            degree: degree,
            institution: institution,
            period: line,
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
          .take(12)
          .map((name) => CvSkillItem(name: name, level: 5, description: 'Competencia técnica o profesional'))
          .toList();

      if (uniqueSkills.isNotEmpty) {
        skillItems = uniqueSkills;
      }
    }

    return baseProfile.copyWith(
      fullName: fullName,
      jobTitle: jobTitle,
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
            width: 480,
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
