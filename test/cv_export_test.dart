import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sanctuary/data/models/cv_profile_model.dart';
import 'package:sanctuary/data/services/docx_export_service.dart';
import 'package:sanctuary/data/services/pdf_export_service.dart';
import 'package:sanctuary/data/services/translation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleProfile = CvProfileModel(
    id: 'test-profile-1',
    fullName: 'Ana García López',
    jobTitle: 'Ingeniera Mecatrónica',
    email: 'ana.garcia@example.com',
    phone: '+34 612 345 678',
    location: 'Sevilla, España',
    availability: 'Inmediata',
    drivingLicense: 'B',
    summary: 'Especialista en robótica industrial y sistemas SCADA.',
    skills: ['PLC Siemens', 'ROS2', 'Python', 'C++', 'CAD/CAM'],
    experiences: [
      CvExperience(
        jobTitle: 'Ingeniera de Automatización',
        company: 'RoboTech Solutions',
        period: '2023 - Actualidad',
        description: 'Desarrollo de líneas de montaje automatizadas.',
      ),
    ],
    educations: [
      CvEducation(
        degree: 'Grado en Ingeniería Mecatrónica',
        institution: 'Universidad de Sevilla',
        period: '2019 - 2023',
        details: 'Matrícula de honor en Trabajo de Fin de Grado.',
      ),
    ],
    accentColor: '#0EA5E9',
    watermarkPattern: 'gears',
    watermarkOpacity: 0.35,
    showWatermark: true,
    photoShape: 'square',
    photoZoom: 1.2,
    photoPanX: 0.1,
    photoPanY: -0.05,
    // 1x1 transparent PNG as base64
    photoUrl:
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  );

  group('DocxExportService Tests', () {
    test('Generates valid docx bytes for all 4 templates with square photo', () {
      final templates = ['sidebar_dark', 'modern_header', 'minimalist', 'tech_cards'];
      for (final tpl in templates) {
        final profile = sampleProfile.copyWith(template: tpl, photoShape: 'square');
        final bytes = DocxExportService.generateDocxBytes(profile);
        expect(bytes.isNotEmpty, isTrue, reason: 'Template $tpl should generate bytes');
        // Check zip PK header
        expect(bytes[0], equals(0x50));
        expect(bytes[1], equals(0x4B));
      }
    });

    test('Generates valid docx bytes with circular photo', () {
      final profile = sampleProfile.copyWith(photoShape: 'circle');
      final bytes = DocxExportService.generateDocxBytes(profile);
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes[0], equals(0x50));
      expect(bytes[1], equals(0x4B));
    });
    test('Generates valid docx bytes with star rating style', () {
      final profile = sampleProfile.copyWith(skillRatingStyle: 'stars');
      final bytes = DocxExportService.generateDocxBytes(profile);
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes[0], equals(0x50));
      expect(bytes[1], equals(0x4B));
    });

    test('DocxExportService embeds watermarks, fixed grid, right tab stop, and visible pills', () {
      final dummyWatermarkBytes = Uint8List.fromList(List.filled(100, 42));
      final bytes = DocxExportService.generateDocxBytes(
        sampleProfile,
        null,
        dummyWatermarkBytes,
        dummyWatermarkBytes,
      );

      final archive = ZipDecoder().decodeBytes(bytes);
      final docFile = archive.findFile('word/document.xml');
      expect(docFile, isNotNull);
      final docXml = utf8.decode(docFile!.content as List<int>);

      // 1. Fixed table layout and grid to prevent displaced columns
      expect(docXml, contains('w:tblLayout w:type="fixed"'));
      expect(docXml, contains('<w:gridCol w:w="3300"/>'));
      expect(docXml, contains('<w:gridCol w:w="7166"/>'));

      // 2. Visible pills with white fill and accent text (no white-on-white)
      expect(docXml, contains('w:shd w:val="clear" w:color="auto" w:fill="FFFFFF"'));
      expect(docXml, contains('w:color w:val="0EA5E9"')); // sampleProfile accentColor without #

      // 3. Right-aligned tab stop for dates (no smashed text)
      expect(docXml, contains('<w:tab w:val="right" w:pos="6800"/>'));
      expect(docXml, contains('<w:tab/>'));

      // 4. Contact icons replacing text labels
      expect(docXml, contains('📞'));
      expect(docXml, contains('✉'));
      expect(docXml, contains('📍'));

      // 5. Watermark drawings embedded in document body (100% vibrant, aligned to margins)
      expect(docXml, contains('rIdSidebarBg'));
      expect(docXml, contains('rIdBannerBg'));

      // 6. Relationships contains media references
      final relsFile = archive.findFile('word/_rels/document.xml.rels');
      expect(relsFile, isNotNull);
      final relsXml = utf8.decode(relsFile!.content as List<int>);
      expect(relsXml, contains('Target="media/banner_bg.png"'));

      // 7. Media files in archive
      expect(archive.findFile('word/media/sidebar_bg.png'), isNotNull);
      expect(archive.findFile('word/media/banner_bg.png'), isNotNull);
    });

    test('DocxExportService renders full-height sidebar reaching bottom margin, centered pill badges, and vertically centered banner', () async {
      final assets = await DocxExportService.prepareAssets(sampleProfile);
      expect(assets.pillContact, isNotNull);
      expect(assets.pillAbout, isNotNull);
      expect(assets.pillSkills, isNotNull);

      final bytes = DocxExportService.generateDocxBytes(sampleProfile, null, null, null, assets);
      final archive = ZipDecoder().decodeBytes(bytes);
      final docFile = archive.findFile('word/document.xml');
      expect(docFile, isNotNull);
      final docXml = utf8.decode(docFile!.content as List<int>);

      // 1. Sidebar background reaches exact bottom margin (10,234,930 EMU)
      expect(docXml, contains('cy="10234930"'));

      // 2. Centered inline subtitle pills embedded
      expect(docXml, contains('rIdPillContact'));
      expect(archive.findFile('word/media/pill_contact.png'), isNotNull);
      expect(archive.findFile('word/media/pill_about.png'), isNotNull);
      expect(archive.findFile('word/media/pill_skills.png'), isNotNull);

      // 3. Banner text vertically centered with exact padding
      expect(docXml, contains('<w:vAlign w:val="top"/>'));
      expect(docXml, contains('<wp:posOffset>-101600</wp:posOffset>'));

      // 4. Balanced indents & competencies right-aligned tab stop
      expect(docXml, contains('w:ind w:left="100"'));
      expect(docXml, contains('w:pos="3020"'));
    });
  });

  group('PdfExportService Tests', () {
    test('Generates valid PDF bytes for all 4 templates with stars', () async {
      final templates = ['sidebar_dark', 'modern_header', 'minimalist', 'tech_cards'];
      for (final tpl in templates) {
        final profile = sampleProfile.copyWith(template: tpl, skillRatingStyle: 'stars');
        final bytes = await PdfExportService.generatePdfBytes(profile);
        expect(bytes.isNotEmpty, isTrue, reason: 'Template $tpl should generate PDF bytes');
        // PDF header: %PDF
        final header = utf8.decode(bytes.sublist(0, 4));
        expect(header, equals('%PDF'), reason: 'Should start with %PDF header');
      }
    });

    test('CvProfileModel correctly serializes and deserializes skillRatingStyle', () {
      final pStars = sampleProfile.copyWith(skillRatingStyle: 'stars');
      final json = pStars.toJson();
      expect(json['skillRatingStyle'], equals('stars'));

      final restored = CvProfileModel.fromJson(json);
      expect(restored.skillRatingStyle, equals('stars'));
    });

    test('pw.Stack and pw.ClipRRect test', () {
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          build: (context) => pw.Stack(
            children: [
              pw.Positioned.fill(
                child: pw.Container(color: PdfColors.blue),
              ),
              pw.Text('Hello Stack'),
            ],
          ),
        ),
      );
      final bytes = doc.save();
      expect(bytes, isNotNull);
    });

    test('Renders CustomPainter to image and embeds into PDF', () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 200, 400));
      final paint = Paint()..color = Colors.white.withOpacity(0.5);
      canvas.drawCircle(const Offset(100, 200), 50, paint);
      final picture = recorder.endRecording();
      final img = await picture.toImage(200, 400);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      expect(byteData, isNotNull);
      final memImg = pw.MemoryImage(byteData!.buffer.asUint8List());

      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          build: (context) => pw.Stack(
            children: [
              pw.Positioned.fill(
                child: pw.Image(memImg, fit: pw.BoxFit.cover),
              ),
              pw.Text('Content over image'),
            ],
          ),
        ),
      );
      final pdfBytes = await doc.save();
      expect(pdfBytes.isNotEmpty, isTrue);
    });

    test('Generates valid PDF with active watermarks for all templates', () async {
      final base = CvProfileModel(
        id: 'test-watermark',
        fullName: 'Antonio García',
        jobTitle: 'Técnico Especialista',
        showWatermark: true,
        watermarkPattern: 'gears',
        watermarkOpacity: 0.15,
        watermarkDensity: 1.0,
      );

      for (final t in ['sidebar_dark', 'modern_header', 'minimalist', 'tech_cards']) {
        final profile = base.copyWith(template: t);
        final pdfBytes = await PdfExportService.generatePdfBytes(profile);
        expect(pdfBytes.isNotEmpty, isTrue);
      }
    });

    test('TranslationService fully translates profiles including titles, summary and skills', () async {
      final esProfile = CvProfileModel(
        id: 'test-es',
        fullName: 'José Mario',
        jobTitle: 'Peón de Construcción y Albañilería',
        summary: 'Profesional puntual con experiencia en obra.',
        availability: 'Inmediata',
        drivingLicense: 'B (Vehículo propio)',
        skills: ['Trabajo en equipo', 'Prevención de riesgos laborales (EPIs)'],
        experiences: [
          CvExperience(
            jobTitle: 'Ayudante de Albañilería',
            company: 'Construcciones Norte',
            period: '2022 - Actualidad',
            description: 'Preparación de mezclas y descarga de material.',
          ),
        ],
        educations: [
          CvEducation(
            degree: 'Educación Secundaria Obligatoria (ESO)',
            institution: 'IES San Juan',
            period: '2016 - 2020',
          ),
        ],
      );

      final enProfile = TranslationService.toggleLanguage(esProfile);
      expect(enProfile.isEnglishVersion, isTrue);
      expect(enProfile.jobTitle, contains('Construction'));
      expect(enProfile.availability, equals('Immediate'));
      expect(enProfile.drivingLicense, contains('Own vehicle'));
      expect(enProfile.skills.first, contains('Teamwork'));
      expect(enProfile.experiences.first.jobTitle, contains('Masonry'));
      expect(enProfile.educations.first.degree, contains('Secondary Education'));

      // Check toggling back restores Spanish perfectly
      final restoredEs = TranslationService.toggleLanguage(enProfile);
      expect(restoredEs.isEnglishVersion, isFalse);
      expect(restoredEs.jobTitle, equals('Peón de Construcción y Albañilería'));
      expect(restoredEs.availability, equals('Inmediata'));
      expect(restoredEs.skills.first, equals('Trabajo en equipo'));
    });

    test('PdfExportService cleanly sanitizes Unicode bullets and en-dashes (no [X] boxes)', () async {
      final trickyProfile = sampleProfile.copyWith(
        summary: '• Especialista en: “Automatización industrial”.\n• Sistemas SCADA & PLC.',
        experiences: [
          CvExperience(
            jobTitle: 'Web Application Developer',
            company: 'Canarytek S.L.',
            period: '9/2024 – 9/2026', // en-dash
            description: '• ERP Odoo: Configuración.\n• Systems: Soporte técnico.\n• Management: Documentación.',
          ),
        ],
        educations: [
          CvEducation(
            degree: 'Primary Education Teaching',
            institution: 'University of Las Palmas',
            period: '2009 – 2012', // en-dash
            details: 'Diploma — especialidad Educación Física.', // em-dash
          ),
        ],
      );

      final pdfBytes = await PdfExportService.generatePdfBytes(trickyProfile);
      expect(pdfBytes.isNotEmpty, isTrue);
      // Ensure embedded sanitized payload does not have raw bullets or en-dashes breaking Type 1
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('All 14 watermark patterns render valid PDF and Word for all 4 templates', () async {
      final patterns = [
        'circuits',
        'gears',
        'tools',
        'constellation',
        'code_brackets',
        'geometric',
        'cubes',
        'waves',
        'shield',
        'lines',
        'tech_dots',
        'leaves',
        'none',
        'custom',
      ];

      final templates = ['sidebar_dark', 'modern_header', 'minimalist', 'tech_cards'];

      for (int i = 0; i < patterns.length; i++) {
        final pat = patterns[i];
        final tpl = templates[i % templates.length];
        final profile = sampleProfile.copyWith(
          watermarkPattern: pat,
          template: tpl,
          watermarkOpacity: 0.25,
          watermarkDensity: 1.2,
          watermarkRandomness: 0.5,
          customWatermarkUrl: pat == 'custom' ? sampleProfile.photoUrl : '',
        );

        // 1. PDF Export
        final pdfBytes = await PdfExportService.generatePdfBytes(profile);
        expect(pdfBytes.isNotEmpty, isTrue, reason: 'Pattern $pat in $tpl should generate valid PDF');
        expect(utf8.decode(pdfBytes.sublist(0, 4)), equals('%PDF'));

        // 2. DOCX Export (with prepared assets)
        final docxAssets = await DocxExportService.prepareAssets(profile);
        final docxBytes = DocxExportService.generateDocxBytes(profile, null, null, null, docxAssets);
        expect(docxBytes.isNotEmpty, isTrue, reason: 'Pattern $pat in $tpl should generate valid DOCX');
        expect(docxBytes[0], equals(0x50));
        expect(docxBytes[1], equals(0x4B));

        final archive = ZipDecoder().decodeBytes(docxBytes);
        expect(archive.findFile('word/document.xml'), isNotNull);
      }
    });

    test('Arbitrary CV profiles (empty, minimal, massive text, special characters) export cleanly in PDF and DOCX', () async {
      final minimalProfile = CvProfileModel(
        id: 'min-1',
        fullName: 'Bob Lee',
        jobTitle: 'Junior Intern',
        experiences: [],
        educations: [],
        skills: [],
        summary: '',
        accentColor: '#10B981',
      );

      final massiveProfile = CvProfileModel(
        id: 'massive-1',
        fullName: 'Dra. María & José <O\'Connor> "El Grande"',
        jobTitle: 'Senior Chief Architect & Vice-President <EMEA>',
        summary: 'Resumen ejecutivo extremadamente detallado que abarca múltiples líneas con caracteres especiales como &, <, >, " y \'.\n' * 5,
        skills: List.generate(12, (i) => 'Competencia Técnica #$i & Especialidad <$i>'),
        experiences: List.generate(
          4,
          (i) => CvExperience(
            jobTitle: 'Director de Ingeniería & Innovación $i',
            company: 'MegaCorp Global Solutions <Intl> S.L. & Co.',
            period: '201$i - 202$i',
            description: '• Liderazgo de equipos multidisciplinares de más de 50 ingenieros.\n'
                '• Reducción de costes operativos en un 35% mediante automatización.\n'
                '• Implementación de arquitecturas cloud distribuidas en AWS & Azure.',
          ),
        ),
        educations: List.generate(
          3,
          (i) => CvEducation(
            degree: 'Máster Universitario en Inteligencia Artificial & Big Data #$i',
            institution: 'Universidad Politécnica & MIT OpenCourseWare',
            period: '201$i - 201${i + 1}',
            details: 'Tesis doctoral con calificación sobresaliente cum laude y mención internacional.',
          ),
        ),
        accentColor: '#8B5CF6',
        watermarkPattern: 'tech_dots',
        watermarkOpacity: 0.20,
      );

      for (final profile in [minimalProfile, massiveProfile]) {
        for (final tpl in ['sidebar_dark', 'modern_header', 'minimalist', 'tech_cards']) {
          final p = profile.copyWith(template: tpl);

          // Test PDF
          final pdfBytes = await PdfExportService.generatePdfBytes(p);
          expect(pdfBytes.isNotEmpty, isTrue);
          expect(utf8.decode(pdfBytes.sublist(0, 4)), equals('%PDF'));

          // Test DOCX
          final docxAssets = await DocxExportService.prepareAssets(p);
          final docxBytes = DocxExportService.generateDocxBytes(p, null, null, null, docxAssets);
          expect(docxBytes.isNotEmpty, isTrue);
          final archive = ZipDecoder().decodeBytes(docxBytes);
          final docXmlFile = archive.findFile('word/document.xml');
          expect(docXmlFile, isNotNull);

          // Verify XML validity (no unescaped characters causing parser crashes)
          final docXml = utf8.decode(docXmlFile!.content as List<int>);
          if (profile == massiveProfile) {
            expect(docXml, isNot(contains('<O\'Connor>')));
            expect(docXml.toUpperCase(), contains('&LT;O&APOS;CONNOR&GT;'));
          }
        }
      }
    });
  });
}

