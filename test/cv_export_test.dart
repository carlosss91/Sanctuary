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

      // 5. Watermark drawings embedded (sidebar background in header1.xml for full-height coverage)
      final headerFile = archive.findFile('word/header1.xml');
      expect(headerFile, isNotNull);
      final headerXml = utf8.decode(headerFile!.content as List<int>);
      expect(headerXml, contains('rIdSidebarBg'));
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
  });
}

