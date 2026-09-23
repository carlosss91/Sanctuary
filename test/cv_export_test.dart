import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanctuary/data/models/cv_profile_model.dart';
import 'package:sanctuary/data/services/docx_export_service.dart';
import 'package:sanctuary/data/services/pdf_export_service.dart';

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
  });
}
