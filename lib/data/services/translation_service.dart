import '../models/cv_profile_model.dart';

class TranslationService {
  // Snapshot cache to guarantee 100% reversible restoration of user's exact Spanish texts
  static final Map<String, CvProfileModel> _spanishProfilesCache = {};

  static final Map<String, String> _dictionaryEsToEn = {
    // Badges & Titles
    'MÓDULO FC0003 · Inserción y Orientación Laboral':
        'MODULE FC0003 · Employment Integration & Career Guidance',
    'Taller de Curriculum Vitae · Gestión Docente':
        'Curriculum Vitae Workshop · Teaching Management',
    'DATOS': 'PERSONAL DETAILS',
    'SOBRE MÍ': 'ABOUT ME',
    'EXPERIENCIA LABORAL': 'WORK EXPERIENCE',
    'FORMACIÓN Y CERTIFICACIONES': 'EDUCATION & CERTIFICATIONS',
    'COMPETENCIAS': 'KEY COMPETENCIES',

    // Job Titles
    'OPERARIO/A DE MANTENIMIENTO URBANO': 'URBAN MAINTENANCE OPERATOR',
    'Operario/a de mantenimiento urbano': 'Urban Maintenance Operator',
    'PEÓN DE MANTENIMIENTO URBANO': 'URBAN MAINTENANCE WORKER',
    'Peón de mantenimiento urbano': 'Urban Maintenance Worker',
    'OPERARIO/A DE MANTENIMIENTO Y SERVICIOS': 'FACILITIES & SERVICES MAINTENANCE OPERATOR',
    'APRENDIZ TRABAJADOR/A - OPERARIO/A DE MANTENIMIENTO URBANO':
        'APPRENTICE WORKER - URBAN MAINTENANCE OPERATOR',

    // Availability & Licenses
    'Disponibilidad horaria e incorporación inmediata':
        'Immediate availability and flexible working hours',
    'Disponibilidad completa e incorporación inmediata':
        'Full availability and immediate start',
    'Incorporación inmediata en turnos rotativos':
        'Immediate start available for rotating shifts',
    'Permiso B y vehículo propio': 'Driving License (Class B) & own vehicle',
    'Permiso B': 'Driving License (Class B)',

    // Summaries / Sobre Mí (Paso 2 / 3)
    'Soy un profesional comprometido y responsable, con vocación práctica, puntualidad y constante disposición para el trabajo en equipo.\n\nDomino con solvencia las herramientas y métodos de oficio, priorizando siempre la prevención de riesgos laborales y el uso correcto de EPIs.':
        'I am a committed and responsible professional with a practical vocation, punctuality, and constant willingness to work in a team.\n\nI handle trade tools and methods with technical proficiency, always prioritizing occupational hazard prevention and the use of PPE.',
    'Persona dinámica con gran capacidad de adaptación y aprendizaje rápido en labores de conservación de espacios públicos, mantenimiento de instalaciones e infraestructuras municipales.':
        'Dynamic individual with strong adaptability and quick learning skills in the upkeep of public spaces, facilities, and municipal infrastructures.',

    // Skills
    'Albañilería básica': 'Basic Masonry',
    'Fontanería básica': 'Basic Plumbing',
    'Pintura y acabados': 'Painting & Surface Finishing',
    'Uso de maquinaria ligera': 'Light Machinery Operation',
    'Prevención de riesgos (EPIs)': 'Occupational Safety & PPE Compliance',
    'Trabajo en equipo': 'Teamwork & Collaboration',
    'Resolución de incidencias': 'Incident & Problem Resolution',
    'Mantenimiento preventivo': 'Preventive Maintenance',
    'Jardinería básica': 'Basic Landscaping & Gardening',
    'Reparaciones rápidas': 'Facility Repairs',
    'Manejo de herramienta manual': 'Manual Hand Tool Handling',
    'Electricidad básica': 'Basic Electrical Work',
    'Soldadura ligera': 'Light Welding',
    'Pintura industrial': 'Industrial Coating & Painting',

    // Degrees & Certifications
    'CERTIFICADO DE PROFESIONALIDAD (EN CURSO)': 'PROFESSIONAL CERTIFICATE (IN PROGRESS)',
    'COMPETENCIAS CLAVE Y HABILIDADES LABORALES': 'CORE COMPETENCIES & WORKPLACE SKILLS',
    'GRADUADO EN EDUCACIÓN SECUNDARIA OBLIGATORIA': 'COMPULSORY SECONDARY EDUCATION GRADUATE',
    'Servicio Canario de Empleo / Ayuntamiento de Arucas':
        'Canary Islands Employment Service / Arucas City Council',
    'Programa de Empleo y Formación Trayectoria Arucas':
        'Arucas Employment & Training Program "Trayectoria"',
    'Ayuntamiento de Arucas (Programa de Empleo y Formación Trayectoria)':
        'Arucas City Council (Employment & Training Program "Trayectoria")',
    'Servicios Urbanos Integrados': 'Integrated Urban Services Ltd.',

    // Common Descriptions
    'Tareas prácticas en obras y servicios públicos municipales, conservación y manejo de herramientas y maquinaria ligera, y aplicación estricta de medidas de seguridad y EPIs.':
        'Practical duties in municipal public works and community services, conservation and operation of light tools and machinery, with strict application of safety protocols and PPE.',
    'Limpieza y acondicionamiento de viales públicos, mantenimiento de mobiliario y apoyo a cuadrillas de especialistas.':
        'Cleaning and conditioning of public roadways, maintenance of municipal street furniture, and supporting specialized technical teams.',
    'Formación teórico-práctica acreditada con módulos de Competencias Clave y PRL.':
        'Accredited theoretical-practical vocational training including Core Competencies and Occupational Health & Safety modules.',
    'Módulos transversales de Matemáticas, Lengua Castellana, Competencias Digitales y Orientación Laboral.':
        'Cross-disciplinary coursework in Applied Mathematics, Spanish Language, Digital Competencies, and Career Development.',
    'Graduado con mención en tecnología aplicada.':
        'Graduated with honors in applied vocational technology.',
  };

  static String translateText(String input, bool toEnglish) {
    if (input.trim().isEmpty) return input;

    if (toEnglish) {
      if (_dictionaryEsToEn.containsKey(input)) {
        return _dictionaryEsToEn[input]!;
      }
      for (final entry in _dictionaryEsToEn.entries) {
        if (entry.key.toLowerCase() == input.toLowerCase()) {
          return entry.value;
        }
      }
      // Substring matching for summaries
      if (input.contains('comprometido y responsable') || input.contains('Soy un profesional comprometido')) {
        return 'I am a committed and responsible professional with a practical vocation, punctuality, and constant willingness to work in a team.\n\nI handle trade tools and methods with technical proficiency, always prioritizing occupational hazard prevention and the use of PPE.';
      }
      if (input.contains('dinámica con gran capacidad') || input.contains('Persona dinámica')) {
        return 'Dynamic individual with strong adaptability and quick learning skills in the upkeep of public spaces, facilities, and municipal infrastructures.';
      }
      return input;
    } else {
      // Reversible Spanish restoration
      for (final entry in _dictionaryEsToEn.entries) {
        if (entry.value.toLowerCase() == input.toLowerCase()) {
          return entry.key;
        }
      }
      // Substring matching for summaries returning to Spanish
      if (input.contains('committed and responsible') || input.contains('practical vocation')) {
        return 'Soy un profesional comprometido y responsable, con vocación práctica, puntualidad y constante disposición para el trabajo en equipo.\n\nDomino con solvencia las herramientas y métodos de oficio, priorizando siempre la prevención de riesgos laborales y el uso correcto de EPIs.';
      }
      if (input.contains('Dynamic individual') || input.contains('adaptability and quick learning')) {
        return 'Persona dinámica con gran capacidad de adaptación y aprendizaje rápido en labores de conservación de espacios públicos, mantenimiento de instalaciones e infraestructuras municipales.';
      }
      return input;
    }
  }

  /// Clones a CV profile and toggles language reversibly (ES ⇄ EN)
  static CvProfileModel toggleLanguage(CvProfileModel profile) {
    final targetToEnglish = !profile.isEnglishVersion;

    if (targetToEnglish) {
      // 1. Cache the original Spanish profile to guarantee 100% reversible restoration
      _spanishProfilesCache[profile.id] = profile;

      return profile.copyWith(
        isEnglishVersion: true,
        moduleBadge: 'MODULE FC0003 · Employment Integration & Career Guidance',
        workshopTitle: 'Curriculum Vitae Workshop · Teaching Management',
        jobTitle: translateText(profile.jobTitle, true),
        availability: translateText(profile.availability, true),
        drivingLicense: translateText(profile.drivingLicense, true),
        summary: translateText(profile.summary, true),
        skills: profile.skills.map((s) => translateText(s, true)).toList(),
        experiences: profile.experiences
            .map((e) => e.copyWith(
                  jobTitle: translateText(e.jobTitle, true),
                  company: translateText(e.company, true),
                  description: translateText(e.description, true),
                ))
            .toList(),
        educations: profile.educations
            .map((ed) => ed.copyWith(
                  degree: translateText(ed.degree, true),
                  institution: translateText(ed.institution, true),
                  details: translateText(ed.details, true),
                ))
            .toList(),
      );
    } else {
      // 2. Return to Spanish: restore cached Spanish texts if present
      final cached = _spanishProfilesCache[profile.id];
      if (cached != null) {
        return cached.copyWith(
          isEnglishVersion: false,
          photoUrl: profile.photoUrl,
          photoShape: profile.photoShape,
          photoZoom: profile.photoZoom,
          photoPanX: profile.photoPanX,
          photoPanY: profile.photoPanY,
          accentColor: profile.accentColor,
          template: profile.template,
          showWatermark: profile.showWatermark,
          watermarkPattern: profile.watermarkPattern,
          watermarkOpacity: profile.watermarkOpacity,
        );
      }

      // Fallback: reverse dictionary translation
      return profile.copyWith(
        isEnglishVersion: false,
        moduleBadge: 'MÓDULO FC0003 · Inserción y Orientación Laboral',
        workshopTitle: 'Taller de Curriculum Vitae · Gestión Docente',
        jobTitle: translateText(profile.jobTitle, false),
        availability: translateText(profile.availability, false),
        drivingLicense: translateText(profile.drivingLicense, false),
        summary: translateText(profile.summary, false),
        skills: profile.skills.map((s) => translateText(s, false)).toList(),
        experiences: profile.experiences
            .map((e) => e.copyWith(
                  jobTitle: translateText(e.jobTitle, false),
                  company: translateText(e.company, false),
                  description: translateText(e.description, false),
                ))
            .toList(),
        educations: profile.educations
            .map((ed) => ed.copyWith(
                  degree: translateText(ed.degree, false),
                  institution: translateText(ed.institution, false),
                  details: translateText(ed.details, false),
                ))
            .toList(),
      );
    }
  }
}
