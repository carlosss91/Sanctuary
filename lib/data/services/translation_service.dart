import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/cv_profile_model.dart';

/// Service responsible for complete, high-fidelity bidirectional translation (Spanish ⇄ English)
/// of CV profiles in CV Maker Studio.
class TranslationService {
  // Snapshot cache to guarantee 100% reversible, lossless restoration of user's exact Spanish texts
  static final Map<String, CvProfileModel> _spanishProfilesCache = {};

  // ==============================================================================
  // COMPREHENSIVE VOCATIONAL & CV DICTIONARY (SPANISH -> ENGLISH)
  // ==============================================================================
  static final Map<String, String> _dictionaryEsToEn = {
    // --- 1. BADGES, HEADERS & SECTIONS ---
    'MÓDULO FC0003 · Inserción y Orientación Laboral':
        'MODULE FC0003 · Employment Integration & Career Guidance',
    'Taller de Curriculum Vitae · Gestión Docente':
        'Curriculum Vitae Workshop · Teaching Management',
    'DATOS': 'PERSONAL DETAILS',
    'DATOS PERSONALES': 'PERSONAL DETAILS',
    'DATOS DE CONTACTO': 'CONTACT DETAILS',
    'CONTACT DETAILS': 'CONTACT DETAILS',
    'DATOS DE INTERÉS': 'ADDITIONAL INFORMATION',
    'DATOS ADICIONALES': 'ADDITIONAL INFORMATION',
    'SOBRE MÍ': 'ABOUT ME',
    'PERFIL': 'PROFESSIONAL PROFILE',
    'PERFIL PROFESIONAL': 'PROFESSIONAL PROFILE',
    'EXPERIENCIA': 'WORK EXPERIENCE',
    'EXPERIENCIA LABORAL': 'WORK EXPERIENCE',
    'FORMACIÓN': 'EDUCATION & QUALIFICATIONS',
    'FORMACIÓN ACADÉMICA': 'EDUCATION',
    'FORMACIÓN Y ESTUDIOS': 'EDUCATION & STUDIES',
    'FORMACIÓN Y CERTIFICACIONES': 'EDUCATION & CERTIFICATIONS',
    'COMPETENCIAS': 'KEY COMPETENCIES',
    'COMPETENCIAS CLAVE': 'KEY COMPETENCIES',
    'HABILIDADES': 'KEY SKILLS',
    'HABILIDADES Y COMPETENCIAS': 'SKILLS & COMPETENCIES',
    'DISEÑO': 'DESIGN & STYLING',
    'DISEÑO Y COLOR': 'DESIGN & COLOR',

    // --- 2. VOCATIONAL & TRADES JOB TITLES ---
    'OPERARIO/A EN FORMACIÓN': 'TRAINEE OPERATOR',
    'Operario/a en formación': 'Trainee Operator',
    'OPERARIO/A DE MANTENIMIENTO URBANO': 'URBAN MAINTENANCE OPERATOR',
    'Operario/a de mantenimiento urbano': 'Urban Maintenance Operator',
    'PEÓN DE MANTENIMIENTO URBANO': 'URBAN MAINTENANCE WORKER',
    'Peón de mantenimiento urbano': 'Urban Maintenance Worker',
    'APRENDIZ TRABAJADOR/A - OPERARIO/A DE MANTENIMIENTO URBANO':
        'APPRENTICE WORKER - URBAN MAINTENANCE OPERATOR',
    'OPERARIO/A DE MANTENIMIENTO Y SERVICIOS': 'FACILITIES & SERVICES MAINTENANCE OPERATOR',
    'Operario/a de mantenimiento y servicios': 'Facilities & Services Maintenance Operator',
    'OPERARIO/A DE LIMPIEZA': 'CLEANING OPERATOR',
    'Operario/a de limpieza': 'Cleaning Operator',
    'OPERARIO/A DE LIMPIEZA VIARIA': 'STREET CLEANING OPERATOR',
    'Operario/a de limpieza viaria': 'Street Cleaning Operator',
    'PEÓN DE ALBAÑILERÍA': 'MASONRY ASSISTANT / LABORER',
    'Peón de albañilería': 'Masonry Assistant / Laborer',
    'PEÓN DE CONSTRUCCIÓN Y ALBAÑILERÍA': 'CONSTRUCTION & MASONRY LABORER',
    'Peón de Construcción y Albañilería': 'Construction & Masonry Laborer',
    'Peón de construcción y albañilería': 'Construction & Masonry Laborer',
    'PEÓN DE OBRA Y CONSTRUCCIÓN': 'CONSTRUCTION & SITE LABORER',
    'Peón de obra y construcción': 'Construction & Site Laborer',
    'PEÓN DE CONSTRUCCIÓN': 'CONSTRUCTION LABORER',
    'Peón de construcción': 'Construction Laborer',
    'AYUDANTE DE ALBAÑILERÍA': 'MASONRY ASSISTANT',
    'Ayudante de Albañilería': 'Masonry Assistant',
    'Ayudante de albañilería': 'Masonry Assistant',
    'PEÓN DE JARDINERÍA': 'GARDENING & LANDSCAPING ASSISTANT',
    'Peón de jardinería': 'Gardening & Landscaping Assistant',
    'PEÓN FORESTAL': 'FORESTRY WORKER',
    'Peón forestal': 'Forestry Worker',
    'AUXILIAR DE SERVICIOS': 'FACILITY SERVICES ASSISTANT',
    'Auxiliar de servicios': 'Facility Services Assistant',
    'AUXILIAR ADMINISTRATIVO/A': 'ADMINISTRATIVE ASSISTANT',
    'Auxiliar administrativo/a': 'Administrative Assistant',
    'AUXILIAR ADMINISTRATIVO': 'ADMINISTRATIVE ASSISTANT',
    'Auxiliar administrativo': 'Administrative Assistant',
    'DEPENDIENTE/A DE COMERCIO': 'RETAIL SALES ASSISTANT',
    'Dependiente/a de comercio': 'Retail Sales Assistant',
    'MOZO/A DE ALMACÉN': 'WAREHOUSE OPERATOR / ORDER PICKER',
    'Mozo/a de almacén': 'Warehouse Operator / Order Picker',
    'MOZO DE ALMACÉN': 'WAREHOUSE OPERATOR',
    'Mozo de almacén': 'Warehouse Operator',
    'CONDUCTOR/A REPARTIDOR/A': 'DELIVERY DRIVER',
    'Conductor/a repartidor/a': 'Delivery Driver',
    'CONDUCTOR REPARTIDOR': 'DELIVERY DRIVER',
    'Conductor repartidor': 'Delivery Driver',
    'CAMARERO/A': 'WAITER / SERVER',
    'Camarero/a': 'Waiter / Server',
    'CAMARERO/A DE PISO': 'HOTEL HOUSEKEEPER',
    'Camarero/a de piso': 'Hotel Housekeeper',
    'AYUDANTE DE COCINA': 'KITCHEN ASSISTANT',
    'Ayudante de cocina': 'Kitchen Assistant',
    'COCINERO/A': 'COOK / CHEF',
    'Cocinero/a': 'Cook / Chef',
    'CONSERJE': 'CARETAKER / CONCIERGE',
    'Conserje': 'Caretaker / Concierge',
    'VIGILANTE DE SEGURIDAD': 'SECURITY GUARD',
    'Vigilante de seguridad': 'Security Guard',
    'ELECTRICISTA': 'ELECTRICIAN',
    'Electricista': 'Electrician',
    'FONTANERO/A': 'PLUMBER',
    'Fontanero/a': 'Plumber',
    'FONTANERO': 'PLUMBER',
    'Fontanero': 'Plumber',
    'PINTOR/A': 'PAINTER & DECORATOR',
    'Pintor/a': 'Painter & Decorator',
    'PINTOR': 'PAINTER',
    'Pintor': 'Painter',
    'CARPINTERO/A': 'CARPENTER',
    'Carpintero/a': 'Carpenter',
    'MECÁNICO/A': 'MECHANIC',
    'Mecánico/a': 'Mechanic',
    'SOLDADOR/A': 'WELDER',
    'Soldador/a': 'Welder',
    'TÉCNICO/A DE INSTALACIONES': 'FACILITIES TECHNICIAN',
    'Técnico/a de instalaciones': 'Facilities Technician',
    'TÉCNICO/A DE MANTENIMIENTO': 'MAINTENANCE TECHNICIAN',
    'Técnico/a de mantenimiento': 'Maintenance Technician',
    'SOCORRISTA': 'LIFEGUARD',
    'Socorrista': 'Lifeguard',
    'CUIDADOR/A DE PERSONAS DEPENDIENTES': 'CAREGIVER FOR DEPENDENT PERSONS',
    'Cuidador/a de personas dependientes': 'Caregiver for Dependent Persons',
    'EMPLEADO/A DE HOGAR': 'DOMESTIC WORKER',
    'Empleado/a de hogar': 'Domestic Worker',
    'TÉCNICO/A EN SISTEMAS MICROINFORMÁTICOS': 'MICROCOMPUTER SYSTEMS TECHNICIAN',
    'Técnico/a en sistemas microinformáticos': 'Microcomputer Systems Technician',
    'DESARROLLADOR/A DE SOFTWARE': 'SOFTWARE DEVELOPER',
    'Desarrollador/a de software': 'Software Developer',
    'ADMINISTRADOR/A DE SISTEMAS': 'SYSTEMS ADMINISTRATOR',
    'Administrador/a de sistemas': 'Systems Administrator',
    'RECEPCIONISTA': 'RECEPTIONIST',
    'Recepcionista': 'Receptionist',
    'CARRETILLERO/A': 'FORKLIFT OPERATOR',
    'Carretillero/a': 'Forklift Operator',
    'JARDINERO/A': 'GARDENER / LANDSCAPER',
    'Jardinero/a': 'Gardener / Landscaper',
    'ALBAÑIL': 'BRICKLAYER / MASON',
    'Albañil': 'Bricklayer / Mason',

    // --- 3. AVAILABILITY, PERMITS & LICENSES ---
    'Disponibilidad horaria e incorporación inmediata':
        'Immediate availability and flexible working hours',
    'Disponibilidad completa e incorporación inmediata':
        'Full availability and immediate start',
    'Disponibilidad completa e inmediata':
        'Full and immediate availability',
    'Incorporación inmediata en turnos rotativos':
        'Immediate start available for rotating shifts',
    'Incorporación inmediata': 'Immediate start',
    'Inmediata': 'Immediate',
    'inmediata': 'immediate',
    'Inmediato': 'Immediate',
    'inmediato': 'immediate',
    'Disponibilidad horaria': 'Flexible working hours',
    'Disponibilidad completa': 'Full availability',
    'Disponibilidad para viajar': 'Willingness to travel',
    'Jornada completa': 'Full-time',
    'Media jornada': 'Part-time',
    'Turnos rotativos': 'Rotating shifts',
    'Turno de mañana': 'Morning shift',
    'Turno de tarde': 'Afternoon shift',
    'Turno de noche': 'Night shift',
    'Fines de semana y festivos': 'Weekends and holidays',
    'Movilidad geográfica': 'Geographical mobility',
    'Permiso B y vehículo propio': 'Driving License (Class B) & own vehicle',
    'B (Vehículo propio)': 'B (Own vehicle)',
    'B (vehículo propio)': 'B (Own vehicle)',
    'Permiso B': 'Driving License (Class B)',
    'Permiso A': 'Motorcycle License (Class A)',
    'Permiso A1': 'Motorcycle License (Class A1)',
    'Permiso A2': 'Motorcycle License (Class A2)',
    'Permiso C': 'Heavy Truck License (Class C)',
    'Permiso C+E': 'Articulated Truck License (Class C+E)',
    'Permiso D': 'Bus Driver License (Class D)',
    'Vehículo propio': 'Own vehicle',
    'Sin vehículo propio': 'No private vehicle',
    'CAP (Certificado de Aptitud Profesional)': 'Certificate of Professional Competence (CPC)',
    'Tarjeta de tacógrafo digital': 'Digital tachograph driver card',
    'Carnet de carretillero': 'Forklift operator license',
    'Carnet de manipulador de alimentos': 'Food hygiene certificate',

    // --- 4. HARD & SOFT SKILLS (UPPERCASE & TITLECASE) ---
    'TRABAJO EN EQUIPO': 'TEAMWORK & COLLABORATION',
    'Trabajo en equipo': 'Teamwork & Collaboration',
    'PREVENCIÓN Y EPIS': 'SAFETY & PPE PROTOCOLS',
    'Prevención y EPIs': 'Safety & PPE Protocols',
    'Prevención de riesgos (EPIs)': 'Occupational Safety & PPE Compliance',
    'PUNTUALIDAD Y SERIEDAD': 'PUNCTUALITY & RELIABILITY',
    'Puntualidad y seriedad': 'Punctuality & Reliability',
    'PUNTUALIDAD': 'PUNCTUALITY',
    'Puntualidad': 'Punctuality',
    'MANEJO DE HERRAMIENTAS': 'TOOL & MACHINERY HANDLING',
    'Manejo de herramientas': 'Tool & Machinery Handling',
    'Manejo de herramienta manual': 'Manual Hand Tool Handling',
    'USO DE HERRAMIENTAS MANUALES': 'MANUAL TOOL HANDLING',
    'Uso de herramientas manuales': 'Manual Tool Handling',
    'USO DE HERRAMIENTAS ELÉCTRICAS': 'POWER TOOL OPERATION',
    'Uso de herramientas eléctricas': 'Power Tool Operation',
    'CAPACIDAD DE APRENDIZAJE': 'LEARNING AGILITY & ADAPTABILITY',
    'Capacidad de aprendizaje': 'Learning Agility & Adaptability',
    'MANTENIMIENTO PREVENTIVO': 'PREVENTIVE MAINTENANCE',
    'Mantenimiento preventivo': 'Preventive Maintenance',
    'MANTENIMIENTO CORRECTIVO': 'CORRECTIVE MAINTENANCE',
    'Mantenimiento correctivo': 'Corrective Maintenance',
    'JARDINERÍA BÁSICA': 'BASIC LANDSCAPING & GARDENING',
    'Jardinería básica': 'Basic Landscaping & Gardening',
    'REPARACIONES RÁPIDAS': 'FAST FACILITY REPAIRS',
    'Reparaciones rápidas': 'Fast Facility Repairs',
    'MANEJO DE MAQUINARIA': 'LIGHT MACHINERY OPERATION',
    'Manejo de maquinaria': 'Light Machinery Operation',
    'Uso de maquinaria ligera': 'Light Machinery Operation',
    'USO DE MAQUINARIA LIGERA': 'LIGHT MACHINERY OPERATION',
    'ALBAÑILERÍA BÁSICA': 'BASIC MASONRY',
    'Albañilería básica': 'Basic Masonry',
    'FONTANERÍA BÁSICA': 'BASIC PLUMBING',
    'Fontanería básica': 'Basic Plumbing',
    'PINTURA Y ACABADOS': 'PAINTING & SURFACE FINISHING',
    'Pintura y acabados': 'Painting & Surface Finishing',
    'ELECTRICIDAD BÁSICA': 'BASIC ELECTRICAL WORK',
    'Electricidad básica': 'Basic Electrical Work',
    'SOLDADURA LIGERA': 'LIGHT WELDING',
    'Soldadura ligera': 'Light Welding',
    'PINTURA INDUSTRIAL': 'INDUSTRIAL COATING & PAINTING',
    'Pintura industrial': 'Industrial Coating & Painting',
    'RESOLUCIÓN DE INCIDENCIAS': 'INCIDENT & PROBLEM RESOLUTION',
    'Resolución de incidencias': 'Incident & Problem Resolution',
    'LIMPIEZA Y DESINFECCIÓN': 'CLEANING & SANITIZATION',
    'Limpieza y desinfección': 'Cleaning & Sanitization',
    'GESTIÓN DE RESIDUOS': 'WASTE MANAGEMENT & RECYCLING',
    'Gestión de residuos': 'Waste Management & Recycling',
    'CARGA Y DESCARGA': 'LOADING & UNLOADING',
    'Carga y descarga': 'Loading & Unloading',
    'CONTROL DE STOCK': 'INVENTORY & STOCK CONTROL',
    'Control de stock': 'Inventory & Stock Control',
    'ATENCIÓN AL CLIENTE': 'CUSTOMER CARE & SUPPORT',
    'Atención al cliente': 'Customer Care & Support',
    'ORGANIZACIÓN Y MÉTODO': 'ORGANIZATION & METHODOLOGY',
    'Organización y método': 'Organization & Methodology',
    'INICIATIVA Y PROACTIVIDAD': 'INITIATIVE & PROACTIVITY',
    'Iniciativa y proactividad': 'Initiative & Proactivity',
    'COMUNICACIÓN ASERTIVA': 'ASSERTIVE COMMUNICATION',
    'Comunicación asertiva': 'Assertive Communication',
    'PRIMEROS AUXILIOS': 'FIRST AID & SAFETY PROTOCOLS',
    'Primeros auxilios': 'First Aid & Safety Protocols',
    'COMPETENCIAS DIGITALES': 'DIGITAL COMPETENCIES',
    'Competencias digitales': 'Digital Competencies',
    'OFIMÁTICA BÁSICA': 'BASIC OFFICE SUITE (MS OFFICE)',
    'Ofimática básica': 'Basic Office Suite (MS Office)',
    'PODA Y DESBROCE': 'PRUNING & BRUSHCUTTING',
    'Poda y desbroce': 'Pruning & Brushcutting',
    'RIEGO POR GOTEO': 'DRIP IRRIGATION SYSTEMS',
    'Riego por goteo': 'Drip Irrigation Systems',

    // --- 5. SKILL DESCRIPTIONS & SUB-LINES ---
    'Compañerismo y coordinación en cuadrilla': 'Teamwork and squad coordination',
    'Seguridad y prevención de riesgos en obra': 'On-site safety protocols and occupational hazard prevention',
    'Compromiso riguroso con horarios y tareas': 'Rigorous commitment to schedules and assigned duties',
    'Destreza con útiles manuales y eléctricos': 'Proficiency with manual tools and power equipment',
    'Asimilación rápida de nuevas técnicas': 'Rapid assimilation of new techniques and workflows',
    'Revisión y conservación de instalaciones': 'Inspection and conservation of facilities',
    'Poda y mantenimiento de zonas verdes': 'Pruning and upkeep of green areas',
    'Solución eficaz de incidencias operativas': 'Effective resolution of operational incidents',
    'Control de herramienta y maquinaria ligera': 'Control of tools and light machinery',
    'Mantenimiento diario de herramientas': 'Daily maintenance of tools and gear',
    'Aplicación de pintura en interiores y exteriores': 'Interior and exterior painting application',
    'Reparación de tuberías y grifería': 'Repair of plumbing, piping, and fixtures',
    'Limpieza y acondicionamiento de espacios': 'Cleaning and conditioning of premises',
    'Cuidado y conservación de maquinaria': 'Care and upkeep of machinery',
    'Atención al público y resolución de dudas': 'Public service and inquiry resolution',
    'Carga y descarga segura de materiales': 'Safe loading and unloading of materials',
    'Uso obligatorio y correcto de EPIs': 'Mandatory and correct use of PPE',
    'Disposición total para el aprendizaje continuo': 'Full dedication to continuous learning',

    // --- 6. COMMON SUMMARIES (ALL DEFAULT PROFILES & TEMPLATES) ---
    // Profile 1 (José Mario Suárez Méndez / Trainee Operator standard)
    'Soy un profesional comprometido y responsable, con vocación práctica, puntualidad y constante disposición para el trabajo en equipo.\n\nDomino con solvencia las herramientas y métodos de oficio, priorizando siempre la prevención de riesgos laborales y el uso correcto de EPIs.':
        'I am a committed and responsible professional with a practical vocation, punctuality, and constant willingness to work in a team.\n\nI handle trade tools and methods with technical proficiency, always prioritizing occupational hazard prevention and the use of PPE.',
    'Soy un profesional comprometido y responsable, con vocación práctica, puntualidad y constante disposición para trabajar en equipo.\n\nManejo herramientas y métodos del oficio con destreza técnica, priorizando siempre la prevención de riesgos y el uso de EPIs.':
        'I am a committed and responsible professional with a practical vocation, punctuality, and constant willingness to work in a team.\n\nI handle trade tools and methods with technical proficiency, always prioritizing occupational hazard prevention and the use of PPE.',

    // Profile 2 (Antonio José Gómez Cabrera)
    'Persona proactiva con sólida experiencia práctica en conservación vial, mantenimiento de edificios e infraestructuras comunitarias.':
        'Proactive individual with solid hands-on experience in roadway conservation, building maintenance, and community infrastructures.',

    // Profile 3 / 4 / New Learner Default Summary
    'Persona responsable y motivada, con iniciativa, puntualidad y capacidad para integrarse con éxito en equipos de trabajo.':
        'Responsible and motivated individual with initiative, punctuality, and proven ability to integrate successfully into work teams.',

    // Alternative Dynamic Profile Summaries
    'Persona dinámica con gran capacidad de adaptación y aprendizaje rápido en labores de conservación de espacios públicos, mantenimiento de instalaciones e infraestructuras municipales.':
        'Dynamic individual with strong adaptability and quick learning skills in the upkeep of public spaces, facilities, and municipal infrastructures.',

    // AI Bio Draft Defaults (from CV Editor Tab 3)
    'Profesional responsable y dinámico con clara orientación práctica y capacidad demostrada para el trabajo en cuadrilla. Domino las herramientas, útiles y maquinaria del oficio, priorizando en todo momento la prevención de riesgos laborales y el rigor en los tiempos de ejecución.\n\nAporto capacidad de aprendizaje ágil, polivalencia y constante iniciativa para resolver incidencias en el puesto de trabajo.':
        'Responsible and dynamic professional with a clear practical orientation and demonstrated ability for squad teamwork. I master trade tools, equipment, and machinery, prioritizing at all times occupational hazard prevention and adherence to execution schedules.\n\nI contribute agile learning capacity, versatility, and constant initiative to resolve workplace incidents.',
    'Profesional cualificado con alto sentido de la responsabilidad, puntualidad rigurosa y vocación de servicio en equipo.':
        'Qualified professional with a high sense of responsibility, rigorous punctuality, and a strong dedication to teamwork.',
    'Poseo dominio práctico en el uso de maquinaria, útiles del oficio y protocolos estrictos de prevención laboral y EPIs.':
        'I possess practical proficiency in operating machinery, trade tools, and strict occupational hazard prevention and PPE protocols.',
    'Aporto versatilidad, rápida capacidad de adaptación y plena disposición para afrontar nuevos retos operativos con dedicación y solvencia.':
        'I contribute versatility, fast adaptability, and full readiness to tackle new operational challenges with dedication and competence.',

    // --- 7. WORK EXPERIENCES, ENTITIES & DESCRIPTIONS ---
    'Ayuntamiento de Arucas (Programa de Empleo y Formación Trayectoria)':
        'Arucas City Council (Employment & Training Program "Trayectoria")',
    'Ayuntamiento de Arucas': 'Arucas City Council',
    'Ayuntamiento de Las Palmas de Gran Canaria': 'Las Palmas de Gran Canaria City Council',
    'Ayuntamiento de Las Palmas': 'Las Palmas City Council',
    'Ayuntamiento de Santa Cruz de Tenerife': 'Santa Cruz de Tenerife City Council',
    'Cabildo de Gran Canaria': 'Gran Canaria Island Council',
    'Servicios Urbanos Integrados': 'Integrated Urban Services Ltd.',
    'Empresa de Mantenimiento y Servicios SL': 'Maintenance & Services Co.',
    'Construcciones y Reformas': 'Construction & Renovations Ltd.',
    'Tareas prácticas en obras y servicios públicos municipales, conservación y manejo de herramientas y maquinaria ligera, y aplicación estricta de medidas de seguridad y EPIs.':
        'Practical duties in municipal public works and community services, conservation and operation of light tools and machinery, with strict application of safety protocols and PPE.',
    'Limpieza y acondicionamiento de viales públicos, mantenimiento de mobiliario y apoyo a cuadrillas de especialistas.':
        'Cleaning and conditioning of public roadways, maintenance of municipal street furniture, and supporting specialized technical teams.',
    'Mantenimiento general preventivo y correctivo de edificios, instalaciones municipales y mobiliario urbano.':
        'General preventive and corrective maintenance of municipal buildings, facilities, and urban street furniture.',
    'Apoyo en labores de albañilería, fontanería básica, pintura y conservación de áreas públicas.':
        'Assisting in masonry works, basic plumbing, painting, and maintenance of public areas.',
    'Manejo de maquinaria de limpieza, desbroce y conservación de jardines y parques municipales.':
        'Operation of municipal cleaning, brushcutting, and upkeep machinery for public parks and gardens.',

    // --- 8. EDUCATIONS, DEGREES & INSTITUTIONS ---
    'CERTIFICADO DE PROFESIONALIDAD (EN CURSO)': 'PROFESSIONAL CERTIFICATE (IN PROGRESS)',
    'Certificado de Profesionalidad (En curso)': 'Professional Certificate (In Progress)',
    'CERTIFICADO DE PROFESIONALIDAD': 'PROFESSIONAL CERTIFICATE',
    'Certificado de profesionalidad': 'Professional Certificate',
    'COMPETENCIAS CLAVE Y HABILIDADES LABORALES': 'CORE COMPETENCIES & WORKPLACE SKILLS',
    'Competencias Clave y Habilidades Laborales': 'Core Competencies & Workplace Skills',
    'GRADUADO EN EDUCACIÓN SECUNDARIA OBLIGATORIA': 'COMPULSORY SECONDARY EDUCATION GRADUATE',
    'Graduado en Educación Secundaria Obligatoria': 'Compulsory Secondary Education Graduate',
    'EDUCACIÓN SECUNDARIA OBLIGATORIA (ESO)': 'COMPULSORY SECONDARY EDUCATION (ESO)',
    'Educación Secundaria Obligatoria (ESO)': 'Compulsory Secondary Education (ESO)',
    'BACHILLERATO': 'BACCALAUREATE / HIGH SCHOOL DIPLOMA',
    'Bachillerato': 'Baccalaureate / High School Diploma',
    'CICLO FORMATIVO DE GRADO MEDIO': 'VOCATIONAL TRAINING DIPLOMA (INTERMEDIATE)',
    'Ciclo Formativo de Grado Medio': 'Vocational Training Diploma (Intermediate)',
    'CICLO FORMATIVO DE GRADO SUPERIOR': 'HIGHER VOCATIONAL TRAINING DIPLOMA',
    'Ciclo Formativo de Grado Superior': 'Higher Vocational Training Diploma',
    'CURSO DE PREVENCIÓN DE RIESGOS LABORALES (PRL)': 'OCCUPATIONAL RISK PREVENTION COURSE (OHS)',
    'Curso de Prevención de Riesgos Laborales (PRL)': 'Occupational Risk Prevention Course (OHS)',
    'CURSO DE MANIPULADOR DE ALIMENTOS': 'FOOD SAFETY & HYGIENE CERTIFICATION',
    'Curso de manipulador de alimentos': 'Food Safety & Hygiene Certification',
    'CURSO DE OPERADOR DE CARRETILLAS ELEVADORAS': 'FORKLIFT OPERATOR CERTIFICATION',
    'Curso de operador de carretillas elevadoras': 'Forklift Operator Certification',
    'CURSO DE PRIMEROS AUXILIOS Y DESA': 'FIRST AID & AED DEFIBRILLATOR COURSE',
    'Curso de primeros auxilios': 'First Aid Course',

    'Servicio Canario de Empleo / Ayuntamiento de Arucas':
        'Canary Islands Employment Service / Arucas City Council',
    'Servicio Canario de Empleo': 'Canary Islands Employment Service',
    'Servicio Canario de Empleo (SCE)': 'Canary Islands Employment Service (SCE)',
    'Servicio Público de Empleo Estatal (SEPE)': 'State Public Employment Service (SEPE)',
    'Programa de Empleo y Formación Trayectoria Arucas':
        'Arucas Employment & Training Program "Trayectoria"',
    'IES Gran Canaria': 'IES Gran Canaria Vocational School',
    'Formación teórico-práctica acreditada con módulos de Competencias Clave y PRL.':
        'Accredited theoretical-practical vocational training including Core Competencies and Occupational Health & Safety modules.',
    'Formación teórico-práctica con módulos de Competencias Clave y PRL.':
        'Theoretical-practical vocational training with Core Competencies and OHS modules.',
    'Módulos transversales de Matemáticas, Lengua Castellana, Competencias Digitales y Orientación Laboral.':
        'Cross-disciplinary coursework in Applied Mathematics, Spanish Language, Digital Competencies, and Career Development.',
    'Graduado con mención en tecnología aplicada.':
        'Graduated with honors in applied vocational technology.',

    // --- 9. PERIODS, MONTHS & COMMON TERMS ---
    'Actualidad': 'Present',
    'actualidad': 'present',
    'En curso': 'In progress',
    'en curso': 'in progress',
    '2024 - Actualidad': '2024 - Present',
    '2023 - Actualidad': '2023 - Present',
    '2022 - Actualidad': '2022 - Present',
    '2025 - Actualidad': '2025 - Present',
    'Sin experiencia registrada.': 'No work experience registered yet.',
    'Sin experiencia registrada aún.': 'No work experience registered yet.',
    'Sin formación registrada.': 'No education registered yet.',
    'Disponibilidad': 'Availability',
    'Permiso': 'License',
    'Tel:': 'Phone:',
    'Email:': 'Email:',
    'Ubicación:': 'Location:',
    'Disp:': 'Avail:',
    'Permiso:': 'License:',
  };

  // Common phrase replacements for heuristic clause-by-clause translation
  static final List<(String, String)> _heuristicRules = [
    ('Actualidad', 'Present'),
    ('actualidad', 'present'),
    ('En curso', 'In progress'),
    ('en curso', 'in progress'),
    ('trabajo en equipo', 'teamwork'),
    ('trabajar en equipo', 'work in a team'),
    ('trabajo en cuadrilla', 'squad teamwork'),
    ('herramientas y maquinaria', 'tools and machinery'),
    ('herramientas manuales', 'manual tools'),
    ('herramientas eléctricas', 'power tools'),
    ('prevención de riesgos laborales', 'occupational hazard prevention'),
    ('prevención de riesgos', 'safety and hazard prevention'),
    ('uso correcto de epis', 'correct use of PPE'),
    ('uso de epis', 'use of PPE'),
    ('espacios públicos', 'public spaces'),
    ('viales públicos', 'public roadways'),
    ('mobiliario urbano', 'urban street furniture'),
    ('zonas verdes', 'green areas'),
    ('limpieza y mantenimiento', 'cleaning and maintenance'),
    ('mantenimiento preventivo', 'preventive maintenance'),
    ('mantenimiento correctivo', 'corrective maintenance'),
    ('incorporación inmediata', 'immediate start'),
    ('disponibilidad horaria', 'flexible working hours'),
    ('disponibilidad completa', 'full availability'),
    ('vehículo propio', 'own vehicle'),
    ('permiso de conducir', 'driving license'),
    ('resolución de incidencias', 'incident resolution'),
    ('atención al cliente', 'customer service'),
    ('capacidad de aprendizaje', 'learning agility'),
    ('rápido aprendizaje', 'quick learning'),
    ('alto sentido de la responsabilidad', 'high sense of responsibility'),
    ('puntualidad rigurosa', 'rigorous punctuality'),
    ('orientación práctica', 'practical orientation'),
    ('peón de construcción y albañilería', 'Construction and Masonry Laborer'),
    ('peón de albañilería y construcción', 'Masonry and Construction Laborer'),
    ('peón de construcción', 'Construction Laborer'),
    ('peón de albañilería', 'Masonry Laborer'),
    ('ayudante de albañilería', 'Masonry Assistant'),
    ('ayudante de construcción', 'Construction Assistant'),
    ('construcción y albañilería', 'construction and masonry'),
    ('albañilería y construcción', 'masonry and construction'),
    ('construcción', 'construction'),
    ('albañilería', 'masonry'),
    ('primeros auxilios', 'first aid'),
  ];

  // ==============================================================================
  // PUBLIC SYNCHRONOUS TRANSLATE (DICTIONARY + HEURISTIC ENGINE)
  // ==============================================================================
  static String translateText(String input, bool toEnglish) {
    if (input.trim().isEmpty) return input;
    final trimmed = input.trim();

    if (toEnglish) {
      // 1. Direct dictionary match
      if (_dictionaryEsToEn.containsKey(trimmed)) {
        return _dictionaryEsToEn[trimmed]!;
      }

      // 2. Case-insensitive dictionary match
      final lower = trimmed.toLowerCase();
      for (final entry in _dictionaryEsToEn.entries) {
        if (entry.key.toLowerCase() == lower) {
          return entry.value;
        }
      }

      // 3. Substring matching for known summary fragments
      if (lower.contains('comprometido y responsable') ||
          lower.contains('vocación práctica') ||
          lower.contains('trabajo en equipo') ||
          lower.contains('trabajar en equipo')) {
        if (lower.contains('domino') || lower.contains('manejo') || lower.contains('epis')) {
          return 'I am a committed and responsible professional with a practical vocation, punctuality, and constant willingness to work in a team.\n\nI handle trade tools and methods with technical proficiency, always prioritizing occupational hazard prevention and the use of PPE.';
        }
      }
      if (lower.contains('proactiva con sólida experiencia') ||
          lower.contains('conservación vial') ||
          lower.contains('infraestructuras comunitarias')) {
        return 'Proactive individual with solid hands-on experience in roadway conservation, building maintenance, and community infrastructures.';
      }
      if (lower.contains('persona dinámica') && lower.contains('adaptación')) {
        return 'Dynamic individual with strong adaptability and quick learning skills in the upkeep of public spaces, facilities, and municipal infrastructures.';
      }
      if (lower.contains('responsable y motivada') || lower.contains('capacidad para integrarse')) {
        return 'Responsible and motivated individual with initiative, punctuality, and proven ability to integrate successfully into work teams.';
      }

      // 4. Period / year pattern: e.g. "2024 - Actualidad"
      if (trimmed.contains('Actualidad') || trimmed.contains('actualidad')) {
        return trimmed.replaceAll('Actualidad', 'Present').replaceAll('actualidad', 'Present');
      }

      // 5. Heuristic clause/rule replacement
      var translated = trimmed;
      bool matchedAny = false;
      for (final rule in _heuristicRules) {
        if (translated.toLowerCase().contains(rule.$1.toLowerCase())) {
          final regex = RegExp(RegExp.escape(rule.$1), caseSensitive: false);
          translated = translated.replaceAll(regex, rule.$2);
          matchedAny = true;
        }
      }

      if (matchedAny) {
        return translated;
      }

      return input;
    } else {
      // Reversible Spanish restoration
      // 1. Check if input is a known English value in dictionary
      for (final entry in _dictionaryEsToEn.entries) {
        if (entry.value.toLowerCase() == trimmed.toLowerCase()) {
          return entry.key;
        }
      }

      // 2. Substring matching for summaries returning to Spanish
      final lower = trimmed.toLowerCase();
      if (lower.contains('committed and responsible') || lower.contains('practical vocation')) {
        return 'Soy un profesional comprometido y responsable, con vocación práctica, puntualidad y constante disposición para trabajar en equipo.\n\nManejo herramientas y métodos del oficio con destreza técnica, priorizando siempre la prevención de riesgos y el uso de EPIs.';
      }
      if (lower.contains('proactive individual') && lower.contains('roadway conservation')) {
        return 'Persona proactiva con sólida experiencia práctica en conservación vial, mantenimiento de edificios e infraestructuras comunitarias.';
      }
      if (lower.contains('dynamic individual') || lower.contains('adaptability and quick learning')) {
        return 'Persona dinámica con gran capacidad de adaptación y aprendizaje rápido en labores de conservación de espacios públicos, mantenimiento de instalaciones e infraestructuras municipales.';
      }
      if (lower.contains('responsible and motivated') || lower.contains('integrate successfully')) {
        return 'Persona responsable y motivada, con iniciativa, puntualidad y capacidad para integrarse con éxito en equipos de trabajo.';
      }

      if (trimmed.contains('Present') || trimmed.contains('present')) {
        return trimmed.replaceAll('Present', 'Actualidad').replaceAll('present', 'Actualidad');
      }

      return input;
    }
  }

  // ==============================================================================
  // ASYNCHRONOUS NEURAL TRANSLATION (VIA PUBLIC TRANSLATE API WITH FALLBACK)
  // Translates arbitrary sentences and custom descriptions with neural accuracy
  // ==============================================================================
  static Future<String> translateTextOnline(String input, {bool toEnglish = true}) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return input;

    // Fast local dictionary check first
    final localResult = translateText(trimmed, toEnglish);
    if (localResult != trimmed) {
      return localResult;
    }

    if (!toEnglish) {
      // Returning to Spanish fallback
      return localResult;
    }

    // Attempt online translation for arbitrary custom text
    try {
      final uri = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=es&tl=en&dt=t&q=${Uri.encodeComponent(trimmed)}',
      );
      final res = await http.get(uri).timeout(const Duration(milliseconds: 2600));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List && data.isNotEmpty && data[0] is List) {
          final sb = StringBuffer();
          for (final part in data[0]) {
            if (part is List && part.isNotEmpty && part[0] != null) {
              sb.write(part[0].toString());
            }
          }
          final translated = sb.toString().trim();
          if (translated.isNotEmpty) {
            return translated;
          }
        }
      }
    } catch (_) {
      // Network timeout or offline: gracefully use local translation result
    }

    return localResult;
  }

  // ==============================================================================
  // TOGGLE LANGUAGE (SYNCHRONOUS, INSTANT & 100% REVERSIBLE)
  // Preserves full backwards-compatibility with tests & synchronous callers
  // ==============================================================================
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
        skillItems: profile.skillItems
            .map((si) => si.copyWith(
                  name: translateText(si.name, true),
                  description: translateText(si.description, true),
                ))
            .toList(),
        experiences: profile.experiences
            .map((e) => e.copyWith(
                  jobTitle: translateText(e.jobTitle, true),
                  company: translateText(e.company, true),
                  description: translateText(e.description, true),
                  period: translateText(e.period, true),
                ))
            .toList(),
        educations: profile.educations
            .map((ed) => ed.copyWith(
                  degree: translateText(ed.degree, true),
                  institution: translateText(ed.institution, true),
                  details: translateText(ed.details, true),
                  period: translateText(ed.period, true),
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
          watermarkDensity: profile.watermarkDensity,
          watermarkRandomness: profile.watermarkRandomness,
          customWatermarkUrl: profile.customWatermarkUrl,
          skillRatingStyle: profile.skillRatingStyle,
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
        skillItems: profile.skillItems
            .map((si) => si.copyWith(
                  name: translateText(si.name, false),
                  description: translateText(si.description, false),
                ))
            .toList(),
        experiences: profile.experiences
            .map((e) => e.copyWith(
                  jobTitle: translateText(e.jobTitle, false),
                  company: translateText(e.company, false),
                  description: translateText(e.description, false),
                  period: translateText(e.period, false),
                ))
            .toList(),
        educations: profile.educations
            .map((ed) => ed.copyWith(
                  degree: translateText(ed.degree, false),
                  institution: translateText(ed.institution, false),
                  details: translateText(ed.details, false),
                  period: translateText(ed.period, false),
                ))
            .toList(),
      );
    }
  }

  // ==============================================================================
  // ASYNCHRONOUS NEURAL ENHANCER (Translates all custom fields with neural online AI)
  // ==============================================================================
  static Future<CvProfileModel> enhanceProfileAsync(CvProfileModel profile) async {
    if (!profile.isEnglishVersion) return profile;

    final translatedSummary = await translateTextOnline(profile.summary, toEnglish: true);
    final translatedJobTitle = await translateTextOnline(profile.jobTitle, toEnglish: true);
    final translatedAvail = await translateTextOnline(profile.availability, toEnglish: true);
    final translatedLicense = await translateTextOnline(profile.drivingLicense, toEnglish: true);

    final translatedSkills = await Future.wait(
      profile.skills.map((s) => translateTextOnline(s, toEnglish: true)),
    );

    final translatedSkillItems = await Future.wait(
      profile.skillItems.map((si) async {
        final name = await translateTextOnline(si.name, toEnglish: true);
        final desc = await translateTextOnline(si.description, toEnglish: true);
        return si.copyWith(name: name, description: desc);
      }),
    );

    final translatedExperiences = await Future.wait(
      profile.experiences.map((exp) async {
        final jobTitle = await translateTextOnline(exp.jobTitle, toEnglish: true);
        final company = await translateTextOnline(exp.company, toEnglish: true);
        final desc = await translateTextOnline(exp.description, toEnglish: true);
        final period = await translateTextOnline(exp.period, toEnglish: true);
        return exp.copyWith(
          jobTitle: jobTitle,
          company: company,
          description: desc,
          period: period,
        );
      }),
    );

    final translatedEducations = await Future.wait(
      profile.educations.map((edu) async {
        final degree = await translateTextOnline(edu.degree, toEnglish: true);
        final inst = await translateTextOnline(edu.institution, toEnglish: true);
        final details = await translateTextOnline(edu.details, toEnglish: true);
        final period = await translateTextOnline(edu.period, toEnglish: true);
        return edu.copyWith(
          degree: degree,
          institution: inst,
          details: details,
          period: period,
        );
      }),
    );

    return profile.copyWith(
      jobTitle: translatedJobTitle,
      summary: translatedSummary,
      availability: translatedAvail,
      drivingLicense: translatedLicense,
      skills: translatedSkills,
      skillItems: translatedSkillItems,
      experiences: translatedExperiences,
      educations: translatedEducations,
    );
  }
}
