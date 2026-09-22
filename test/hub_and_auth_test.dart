import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanctuary/core/widgets/cosmic_background.dart';
import 'package:sanctuary/core/widgets/trayectoria_sidebar.dart';
import 'package:sanctuary/data/models/cv_profile_model.dart';
import 'package:sanctuary/data/models/user_model.dart';
import 'package:sanctuary/data/services/translation_service.dart';
import 'package:sanctuary/features/cv_builder/widgets/image_crop_dialog.dart';

void main() {
  group('UserModel Profile Enhancements', () {
    test('Serializes and deserializes profile fields accurately', () {
      final user = UserModel(
        id: 42,
        username: 'carlos_docente',
        role: 'docente',
        fullName: 'Carlos Maestro',
        email: 'carlos@sanctuary.local',
        avatarUrl: 'https://example.com/photo.png',
        bio: 'Tutor de inserción laboral y coordinador de proyectos.',
      );

      final json = user.toJson();
      expect(json['id'], equals(42));
      expect(json['username'], equals('carlos_docente'));
      expect(json['full_name'], equals('Carlos Maestro'));
      expect(json['email'], equals('carlos@sanctuary.local'));
      expect(json['avatar_url'], equals('https://example.com/photo.png'));
      expect(json['bio'], equals('Tutor de inserción laboral y coordinador de proyectos.'));

      final reconstructed = UserModel.fromJson(json);
      expect(reconstructed.fullName, equals('Carlos Maestro'));
      expect(reconstructed.email, equals('carlos@sanctuary.local'));
      expect(reconstructed.role, equals('docente'));
    });

    test('copyWith properly updates specific fields', () {
      const initial = UserModel(username: 'admin', role: 'admin');
      final updated = initial.copyWith(
        fullName: 'Super Admin',
        email: 'admin@sanctuary.dev',
      );

      expect(updated.username, equals('admin'));
      expect(updated.fullName, equals('Super Admin'));
      expect(updated.email, equals('admin@sanctuary.dev'));
      expect(updated.role, equals('admin'));
    });
  });

  group('ImageCropResult Models', () {
    test('Stores crop shape, zoom and pan coordinates', () {
      const crop = ImageCropResult(
        shape: 'square',
        zoom: 1.4,
        panX: 0.5,
        panY: -0.2,
      );

      expect(crop.shape, equals('square'));
      expect(crop.zoom, equals(1.4));
      expect(crop.panX, equals(0.5));
      expect(crop.panY, equals(-0.2));
    });
  });

  group('TrayectoriaSidebar Tests', () {
    testWidgets('Toggles collapse callback when header button is tapped', (tester) async {
      bool toggleCalled = false;
      String? selectedItem;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrayectoriaSidebar(
              isDark: true,
              isCollapsed: false,
              onSelect: (item) => selectedItem = item,
              onToggleCollapse: () => toggleCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('SANCTUARY'), findsOneWidget);
      expect(find.byTooltip('Plegar barra lateral'), findsOneWidget);

      await tester.tap(find.byTooltip('Plegar barra lateral'));
      await tester.pumpAndSettle();

      expect(toggleCalled, isTrue);

      await tester.tap(find.text('Gestión de Alumnos'));
      await tester.pumpAndSettle();
      expect(selectedItem, equals('Alumnos'));

      // Now test in collapsed mode
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrayectoriaSidebar(
              isDark: true,
              isCollapsed: true,
              onSelect: (item) => selectedItem = item,
              onToggleCollapse: () => toggleCalled = true,
            ),
          ),
        ),
      );

      expect(find.byTooltip('Desplegar barra lateral'), findsOneWidget);
    });
  });

  group('TranslationService Reversibility Tests', () {
    test('Translates summary and fields to English and cleanly restores to Spanish reversibly', () {
      final spanishProfile = CvProfileModel(
        id: 'test-1',
        fullName: 'Carlos Maestro',
        jobTitle: 'OPERARIO/A DE MANTENIMIENTO URBANO',
        moduleBadge: 'MÓDULO FC0003 · Inserción y Orientación Laboral',
        summary: 'Soy un profesional comprometido y responsable, con vocación práctica, puntualidad y constante disposición para el trabajo en equipo.\n\nDomino con solvencia las herramientas y métodos de oficio, priorizando siempre la prevención de riesgos laborales y el uso correcto de EPIs.',
      );

      // 1. Toggle to English
      final englishProfile = TranslationService.toggleLanguage(spanishProfile);
      expect(englishProfile.isEnglishVersion, isTrue);
      expect(englishProfile.moduleBadge, contains('MODULE FC0003'));
      expect(englishProfile.summary, contains('I am a committed and responsible professional'));
      expect(englishProfile.jobTitle, contains('URBAN MAINTENANCE OPERATOR'));

      // 2. Toggle back to Spanish
      final restoredProfile = TranslationService.toggleLanguage(englishProfile);
      expect(restoredProfile.isEnglishVersion, isFalse);
      expect(restoredProfile.moduleBadge, contains('MÓDULO FC0003'));
      expect(restoredProfile.summary, contains('Soy un profesional comprometido y responsable'));
      expect(restoredProfile.jobTitle, contains('OPERARIO/A DE MANTENIMIENTO URBANO'));
    });
  });

  group('CosmicBackground Widget Tests', () {
    testWidgets('Renders CosmicBackground with child widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CosmicBackground(
              isDark: true,
              child: Text('Cosmic Sanctuary'),
            ),
          ),
        ),
      );

      expect(find.text('Cosmic Sanctuary'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
