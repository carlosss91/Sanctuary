import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanctuary/data/models/cv_profile_model.dart';
import 'package:sanctuary/features/cv_maker/widgets/cv_editor_tabs.dart';

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
    skills: ['PLC Siemens', 'ROS2', 'Python'],
    accentColor: '#0EA5E9',
    fontFamily: 'Segoe UI',
    isEnglishVersion: false,
  );

  testWidgets('CvEditorTabs renders tabs in Spanish by default', (tester) async {
    // Provide a wide viewport so all 7 tabs are laid out
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CvEditorTabs(
            profile: sampleProfile,
            onProfileChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('1. Identidad'), findsOneWidget);
    expect(find.text('2. Contacto'), findsOneWidget);
    expect(find.text('3. Sobre Mí'), findsOneWidget);
    expect(find.text('4. Competencias'), findsOneWidget);
    expect(find.text('5. Experiencia'), findsOneWidget);
    expect(find.text('6. Formación'), findsOneWidget);
    expect(find.text('7. Diseño'), findsOneWidget);
  });

  testWidgets('CvEditorTabs keeps tab headers in Spanish even if profile isEnglishVersion is true', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final englishProfile = sampleProfile.copyWith(isEnglishVersion: true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CvEditorTabs(
            profile: englishProfile,
            onProfileChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // The editor controls and tabs should remain in Spanish
    expect(find.text('1. Identidad'), findsOneWidget);
    expect(find.text('7. Diseño'), findsOneWidget);
    expect(find.text('1. Identity'), findsNothing);
    expect(find.text('7. Design'), findsNothing);
  });

  testWidgets('CvEditorTabs Design tab renders system fonts (Segoe UI, Calibri, Arial) without exceptions', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    for (final font in ['Segoe UI', 'Calibri', 'Century Gothic', 'Arial', 'Inter']) {
      final fontProfile = sampleProfile.copyWith(fontFamily: font);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CvEditorTabs(
              profile: fontProfile,
              onProfileChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Tab 7 (Diseño)
      final disenoTab = find.text('7. Diseño');
      expect(disenoTab, findsOneWidget);
      await tester.tap(disenoTab);
      await tester.pumpAndSettle();

      // Verify that the design tab rendered without crashing
      expect(find.text('Familia Tipográfica (Coherente en Web, PDF y Word)'), findsOneWidget);
    }
  });
}
