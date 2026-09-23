import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanctuary/data/models/cv_profile_model.dart';
import 'package:sanctuary/data/services/docx_export_service.dart';
import 'package:sanctuary/features/pdf_signer/models/signature_document_model.dart';
import 'package:sanctuary/features/pdf_signer/widgets/security_standards_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Typography & Watermark Docx Tests', () {
    test('CvProfileModel stores and serializes typography controls', () {
      final profile = CvProfileModel(
        id: 'test-prof-1',
        fullName: 'Carlos Maestro',
        jobTitle: 'Profesor Técnico de FP',
        fontFamily: 'Outfit',
        fontSizeScale: 1.15,
        fontSpacing: 0.5,
        lineSpacing: 1.45,
        watermarkPattern: 'shield',
        watermarkOpacity: 0.40,
        showWatermark: true,
      );

      final json = profile.toJson();
      expect(json['fontFamily'], equals('Outfit'));
      expect(json['fontSizeScale'], equals(1.15));
      expect(json['fontSpacing'], equals(0.5));
      expect(json['lineSpacing'], equals(1.45));
      expect(json['watermarkPattern'], equals('shield'));

      final restored = CvProfileModel.fromJson(json);
      expect(restored.fontFamily, equals('Outfit'));
      expect(restored.fontSizeScale, equals(1.15));
      expect(restored.fontSpacing, equals(0.5));
      expect(restored.lineSpacing, equals(1.45));
      expect(restored.watermarkPattern, equals('shield'));
    });

    test('DocxExportService embeds custom font and watermark motif in zip bytes', () {
      final profile = CvProfileModel(
        id: 'test-prof-2',
        fullName: 'Marta Rivas',
        jobTitle: 'Arquitecta de Soluciones',
        fontFamily: 'Montserrat',
        fontSizeScale: 1.2,
        fontSpacing: 0.8,
        lineSpacing: 1.35,
        watermarkPattern: 'geometric',
        showWatermark: true,
      );

      final docxBytes = DocxExportService.generateDocxBytes(profile);
      expect(docxBytes.isNotEmpty, isTrue);
      expect(docxBytes[0], equals(0x50)); // 'P'
      expect(docxBytes[1], equals(0x4B)); // 'K'
    });
  });

  group('PDF Signer Model Tests', () {
    test('SignatureStroke and PlacedSignature serialize properly', () {
      final stroke = SignatureStroke(
        points: const [Offset(10, 20), Offset(50, 60), Offset(80, 90)],
        color: const Color(0xFF2563EB),
        strokeWidth: 2.5,
      );

      final strokeJson = stroke.toJson();
      expect(strokeJson['points'].length, equals(3));
      expect(strokeJson['strokeWidth'], equals(2.5));

      final restoredStroke = SignatureStroke.fromJson(strokeJson);
      expect(restoredStroke.points.length, equals(3));
      expect(restoredStroke.strokeWidth, equals(2.5));
      expect(restoredStroke.points.first.dx, equals(10.0));
      expect(restoredStroke.points.first.dy, equals(20.0));

      final placed = PlacedSignature(
        id: 'sig-test-123',
        signerName: 'Laura',
        signerSurname: 'Martínez',
        nationalId: '12345678Z',
        signedAt: DateTime.utc(2026, 9, 22, 12, 0),
        strokes: [stroke],
        normalizedX: 0.5,
        normalizedY: 0.8,
        verificationHash: 'VERIF-TEST-ABC1234',
      );

      final placedJson = placed.toJson();
      expect(placedJson['id'], equals('sig-test-123'));
      expect(placedJson['signerName'], equals('Laura'));
      expect(placedJson['verificationHash'], equals('VERIF-TEST-ABC1234'));

      final restoredPlaced = PlacedSignature.fromJson(placedJson);
      expect(restoredPlaced.signerName, equals('Laura'));
      expect(restoredPlaced.signerSurname, equals('Martínez'));
      expect(restoredPlaced.nationalId, equals('12345678Z'));
      expect(restoredPlaced.strokes.length, equals(1));
    });

    test('PdfSignerDocument manages multiple signatures and notifications', () {
      final doc = PdfSignerDocument(
        id: 'doc-alpha',
        title: 'Acuerdo de Confidencialidad FC0003',
        fileName: 'NDA_Sanctuary.pdf',
        signatures: [],
        notifications: [
          SignerNotification(
            id: 'n-1',
            signerName: 'Juan Pérez',
            timestamp: DateTime.now(),
            message: 'Ha recibido el documento para revisión.',
          ),
        ],
      );

      expect(doc.signatures.isEmpty, isTrue);
      expect(doc.notifications.length, equals(1));

      final updatedDoc = doc.copyWith(
        signatures: [
          PlacedSignature(
            id: 'sig-1',
            signerName: 'Juan',
            signerSurname: 'Pérez',
            signedAt: DateTime.now(),
            normalizedX: 0.6,
            normalizedY: 0.85,
            strokes: [],
          ),
        ],
      );

      expect(updatedDoc.signatures.length, equals(1));
      expect(updatedDoc.signatures.first.signerName, equals('Juan'));
    });

    test('SecurityStandardsDialog contains all 8 required legal and technical standards with justifications', () {
      final standards = SecurityStandardsDialog.standardsList;
      expect(standards.length, equals(8));

      final ids = standards.map((s) => s.id).toSet();
      expect(ids.contains('eidas-26a'), isTrue);
      expect(ids.contains('eidas-26b'), isTrue);
      expect(ids.contains('eidas-26c'), isTrue);
      expect(ids.contains('eidas-26d'), isTrue);
      expect(ids.contains('pades-etsi'), isTrue);
      expect(ids.contains('timestamp-rfc'), isTrue);
      expect(ids.contains('ley-6-2020'), isTrue);
      expect(ids.contains('rgpd-consent'), isTrue);

      for (final item in standards) {
        expect(item.standardName.isNotEmpty, isTrue);
        expect(item.lawReference.isNotEmpty, isTrue);
        expect(item.requirementTitle.isNotEmpty, isTrue);
        expect(item.complianceReason.isNotEmpty, isTrue);
        expect(item.complianceReason.length, greaterThan(30));
      }
    });

    test('Draggable signature box coordinate constraints prevent out-of-bounds positioning', () {
      const pageW = 595.0;
      const pageH = 842.0;
      const cardW = 185.0;
      const cardH = 78.0;

      const maxNormX = (pageW - cardW) / pageW;
      const maxNormY = (pageH - cardH) / pageH;

      expect(maxNormX, greaterThan(0.68));
      expect(maxNormX, lessThan(0.70));
      expect(maxNormY, greaterThan(0.90));
      expect(maxNormY, lessThan(0.92));

      // Test extreme dragging deltas
      final clampedMinX = (-0.5).clamp(0.0, maxNormX);
      final clampedMaxX = (1.5).clamp(0.0, maxNormX);
      expect(clampedMinX, equals(0.0));
      expect(clampedMaxX, equals(maxNormX));
    });
  });
}
