import 'package:flutter_test/flutter_test.dart';
import 'package:sanctuary/data/models/cv_profile_model.dart';
import 'package:sanctuary/data/services/cv_document_parser_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CvDocumentParserService Semantic Parsing Tests', () {
    test('Correctly extracts personal details, experience, education and skills from standard CV text', () {
      const sampleCvText = '''
Carlos Santana Sánchez
Desarrollador Full Stack & Diseñador UI/UX
carlos.santana@example.com · +34 612 34 56 78
Las Palmas de Gran Canaria, España

RESUMEN PROFESIONAL
Desarrollador con más de 6 años de experiencia creando aplicaciones web y móviles de alto rendimiento con Flutter y Node.js.

EXPERIENCIA LABORAL
Técnico de Software Senior
Google Cloud Partners
2021 - Actualidad
Liderazgo del desarrollo de microservicios y frontend responsive.

Desarrollador Web Frontend
Tech Canary Solutions
2018 - 2021
Desarrollo de interfaces accesibles en HTML5, CSS3 y TypeScript.

EDUCACIÓN
Grado en Ingeniería Informática
Universidad de Las Palmas de Gran Canaria (ULPGC)
2014 - 2018
Mención en Tecnologías de la Información.

HABILIDADES
Flutter, Dart, Node.js, TypeScript, PostgreSQL, Git, Figma, Docker
''';

      const base = CvProfileModel(id: 'test-base');
      final parsed = CvDocumentParserService.parseCvText(sampleCvText, base);

      expect(parsed.fullName, equals('Carlos Santana Sánchez'));
      expect(parsed.jobTitle, contains('Desarrollador'));
      expect(parsed.email, equals('carlos.santana@example.com'));
      expect(parsed.phone, contains('612 34 56 78'));
      expect(parsed.location, contains('Las Palmas'));
      expect(parsed.summary, contains('Desarrollador con más de 6 años'));

      expect(parsed.experiences.length, greaterThanOrEqualTo(2));
      expect(parsed.experiences.first.jobTitle, contains('Técnico'));
      expect(parsed.experiences.first.company, contains('Google'));
      expect(parsed.experiences.first.period, contains('2021'));

      expect(parsed.educations.length, greaterThanOrEqualTo(1));
      expect(parsed.educations.first.degree, contains('Ingeniería'));
      expect(parsed.educations.first.institution, contains('Universidad'));

      expect(parsed.skillItems.length, greaterThanOrEqualTo(5));
      expect(parsed.skills.contains('Flutter'), isTrue);
    });

    test('Rejects PDF metadata timestamps from being confused with phone numbers', () {
      const sampleTextWithTimestamps = '''
Juan Pérez Gómez
Administrativo Contable
juan@empresa.com
CreationDate: 20260916164141
Producer: Adobe PDF Library 15.0
Teléfono: 928 45 67 89
''';

      const base = CvProfileModel(id: 'test-base-2');
      final parsed = CvDocumentParserService.parseCvText(sampleTextWithTimestamps, base);

      expect(parsed.fullName, equals('Juan Pérez Gómez'));
      expect(parsed.jobTitle, equals('Administrativo Contable'));
      expect(parsed.phone, equals('928 45 67 89'));
      expect(parsed.phone.contains('20260916164141'), isFalse);
    });

    test('Correctly parses real-world Sanctuary PDF export with sections at bottom and title banner', () {
      const realCarlosCvText = '''
DESARROLLADOR DE APLICACIONES WEB
Canarytek S.L.,
9/2024 - 9/2026
Desarrollo Web y Software: Continuidad y evolución de la plataforma Etiketia, colaboración en el diseño de la web corporativa de Canarytek y participación en diversos proyectos de desarrollo. • ERP Odoo: Configuración, soporte y adaptación de módulos a nuestros flujos internos. • Sistemas: Diagnóstico/soporte técnico de hardware. • Gestión: Apoyo administrativo y documentación técnica.

DOCENTE DE SISTEMAS MICROINFORMÁTICOS PFAE
Servicio Canario de Empleo & Cabildo de Lanzarote
3/2024 - 3/2025
Docente PFAE de Sistemas Microinformáticos..

PROFESOR DE INGLÉS EXTRACURRICULAR
C.E.I.P. Antonio Zerolo
9/2023 - 1/2024
Profesor de clases particulares de inglés en un centro educativo.

MONITOR DE GIMNASIA ARTÍSTICA
Club de Gimnasia de Art. Abora Tigotán
2021- 2023
Monitor de Gimnasia Artística Club de Gimnasia Artística Ábora Tigotán

MAESTRO DE INGLÉS
Consejería de Educación, Gobierno de Canarias
2018 - 2021
Maestro de Educación Primaria, especialidad de Inglés en diferentes centros públicos: E.E.I. José Melián, C.E.I.P. Dr. Juan Espino, C.E.I.P. Policarpo Baez, C.E.I.P. Los Llanetes, C.E.I.P. Nieves Toledo.

GRADO SUPERIOR FP EN DESARROLLO DE APLICACIONES WEB (DAW)
iLerna
2022-2025
Técnico Superior en Desarrollo de Aplicaciones Web

GRADO SUPERIOR FP EN ADMINISTRACIÓN DE SISTEMAS INFORMÁTICOS EN REDES (ASIR)
I.E.S. El Rincón
2015- 2017
Técnico Superior en Administración de Sistemas Informáticos en Red

ADAPTACIÓN AL GRADO EUROPEO EN EDUCACIÓN PRIMARIA
UNIVERSIDAD DE LAS PALMAS DE GRAN CANARIA ULPGC
2013
Adaptación al Grado del Plan Bolonia Europeo

MAGISTERIO DE EDUCACIÓN PRIMARIA, ESPECIALIDAD EDUCACIÓN FÍSICA
UNIVERSIDAD DE LAS PALMAS DE GRAN CANARIA ULPGC
2009 – 2012
Diplomatura en Magisterio de Educación Primaria, especialidad Educación Física

CURSO PYTHON
Academia Edutin
2022
Curso de Lenguaje Python de 96 horas

+34 645935532
carsan91@hotmail.com
Arrecife, Lanzarote
Disponibilidad horaria completa e incorporación inmediata
Permiso B y vehículo propio

Soy un profesional comprometido y responsable, con vocación práctica, puntualidad y constante disposición para trabajar en equipo.
Manejo herramientas y métodos del oficio con destreza técnica y organizativa, priorizando las tareas mediante metodología Kanban o Agile.
Aporto iniciativa, rápida adaptación y ganas de superación. Busco un entorno profesional donde aportar valor y consolidar mi trayectoria.

TRABAJO EN EQUIPO
Compañerismo y coordinación en cuadrilla
TRABAJO INDIVIDUAL
Seguridad y prevención de riesgos en obra
PUNTUALIDAD Y SERIED…
Compromiso riguroso con horarios y tareas
MANEJO DE HERRAMIEN…
Destreza con útiles manuales y eléctricos
CAPACIDAD DE APRENDI…
Asimilación rápida de nuevas técnicas

DATOS
S OBRE MÍ
COMPETENCIAS
T . S . E N D E S A R R O L L O D E A P L I C C I O N E S W E B
EXPERIENCIA LABORAL
FORMACIÓN Y CERTIFICACIONES
''';

      const base = CvProfileModel(id: 'test-carlos');
      final parsed = CvDocumentParserService.parseCvText(
        realCarlosCvText,
        base,
        'CV CARLOS S.S. 2026 FINAL.pdf',
      );

      // Name must be CARLOS S.S. from filename, NOT the profession!
      expect(parsed.fullName, equals('CARLOS S.S.'));
      expect(parsed.fullName.contains('DESARROLLADOR'), isFalse);

      // Job title should be Developer / T.S.
      expect(parsed.jobTitle, contains('DESARROLL'));

      // Contact details
      expect(parsed.phone, equals('+34 645935532'));
      expect(parsed.email, equals('carsan91@hotmail.com'));
      expect(parsed.location, contains('Arrecife'));
      expect(parsed.availability, contains('Disponibilidad'));
      expect(parsed.drivingLicense, contains('Permiso B'));

      // Experiences: 5 distinct work experiences
      expect(parsed.experiences.length, equals(5));
      expect(parsed.experiences[0].company, contains('Canarytek'));
      expect(parsed.experiences[0].period, contains('9/2024'));
      expect(parsed.experiences[1].company, contains('Servicio Canario de Empleo'));
      expect(parsed.experiences[4].company, contains('Consejería de Educación'));

      // Educations: 5 distinct educational records
      expect(parsed.educations.length, equals(5));
      expect(parsed.educations[0].degree, contains('DAW'));
      expect(parsed.educations[0].institution, equals('iLerna'));
      expect(parsed.educations[1].degree, contains('ASIR'));
      expect(parsed.educations[1].institution, equals('I.E.S. El Rincón'));

      // Skills: 5 competency items with descriptions
      expect(parsed.skillItems.length, equals(5));
      expect(parsed.skillItems.any((s) => s.name.contains('TRABAJO EN EQUIPO')), isTrue);
      expect(parsed.skillItems.any((s) => s.name.contains('TRABAJO INDIVIDUAL')), isTrue);
      expect(parsed.skillItems.any((s) => s.name.contains('PUNTUALIDAD')), isTrue);
      expect(parsed.skillItems.any((s) => s.name.contains('MANEJO DE HERRAMIENTAS')), isTrue);
      expect(parsed.skillItems.any((s) => s.name.contains('CAPACIDAD DE APRENDIZAJE')), isTrue);

      // Summary
      expect(parsed.summary, contains('Soy un profesional comprometido'));
      expect(parsed.summary, contains('trayectoria'));
    });

    test('Correctly parses experience and education dates containing Spanish month names', () {
      const monthCvText = '''
María Gómez Santana
Ingeniera de Software
maria.gomez@gmail.com
+34 612 345 678
Madrid, España

EXPERIENCIA LABORAL
Desarrolladora Full Stack
Tech Solutions SL
Enero 2021 - Actualidad
Desarrollo de arquitecturas microservicios y APIs REST.

Programadora Frontend
Innova Web Studio
Marzo 2018 - Diciembre 2020
Diseño y maquetación de interfaces web interactivas.

FORMACIÓN ACADÉMICA
Grado en Ingeniería Informática
Universidad Politécnica de Madrid
Septiembre 2014 - Junio 2018
Mención en Computación y Sistemas Inteligentes.
''';

      const base = CvProfileModel(id: 'test-maria');
      final parsed = CvDocumentParserService.parseCvText(monthCvText, base);

      expect(parsed.fullName, equals('María Gómez Santana'));
      expect(parsed.experiences.length, equals(2));
      expect(parsed.experiences[0].period, contains('Enero 2021 - Actualidad'));
      expect(parsed.experiences[1].period, contains('Marzo 2018 - Diciembre 2020'));
      expect(parsed.educations.length, equals(1));
      expect(parsed.educations[0].period, contains('Septiembre 2014 - Junio 2018'));
    });
  });
}
