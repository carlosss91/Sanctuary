import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/cv_profile_model.dart';
import '../models/repo_link_model.dart';

class StorageService {
  static const String _keyCurrentUser = 'sanctuary_current_user';
  static const String _keyLocalUsers = 'sanctuary_local_users';
  static const String _keyCvProfiles = 'sanctuary_cv_profiles';
  static const String _keyActiveCvId = 'sanctuary_active_cv_id';
  static const String _keyRepoLinks = 'sanctuary_repo_links';
  static const String _keyThemeMode = 'sanctuary_theme_mode';
  static const String _keyCosmicActive = 'sanctuary_cosmic_active';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    final service = StorageService(prefs);
    await service._seedDefaultsIfEmpty();
    return service;
  }

  Future<void> _seedDefaultsIfEmpty() async {
    // 1. Default admin user
    final users = getLocalUsers();
    if (users.isEmpty) {
      await saveLocalUser(const UserModel(id: 1, username: 'admin', role: 'admin'), 'admin');
    }

    // 2. Default CV profiles
    final profiles = getCvProfiles();
    if (profiles.isEmpty) {
      final defaultProfiles = [
        const CvProfileModel(
          id: 'profile-1',
          moduleBadge: 'MÓDULO FC0003 · Inserción y Orientación Laboral',
          workshopTitle: 'Taller de Curriculum Vitae · Gestión Docente',
          fullName: 'JOSÉ MARIO SUÁREZ MÉNDEZ',
          jobTitle: 'OPERARIO/A DE MANTENIMIENTO URBANO',
          photoUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80',
          photoZoom: 1.0,
          phone: '+34 600 000 000',
          email: 'jose.suarez.mendez88@correo.es',
          location: 'Arucas, Gran Canaria',
          availability: 'Disponibilidad horaria e incorporación inmediata',
          drivingLicense: 'Permiso B y vehículo propio',
          summary: 'Soy un profesional comprometido y responsable, con vocación práctica, puntualidad y constante disposición para trabajar en equipo.\n\nManejo herramientas y métodos del oficio con destreza técnica, priorizando siempre la prevención de riesgos y el uso de EPIs.',
          skills: [
            'Albañilería básica',
            'Fontanería básica',
            'Pintura y acabados',
            'Uso de maquinaria ligera',
            'Prevención de riesgos (EPIs)',
            'Trabajo en equipo',
            'Resolución de incidencias'
          ],
          experiences: [
            CvExperience(
              jobTitle: 'APRENDIZ TRABAJADOR/A - OPERARIO/A DE MANTENIMIENTO URBANO',
              company: 'Ayuntamiento de Arucas (Programa de Empleo y Formación Trayectoria)',
              period: '2024 - 2025',
              description: 'Tareas prácticas en obras y servicios públicos municipales, conservación y manejo de herramientas y maquinaria ligera, y aplicación estricta de medidas de seguridad y EPIs.',
            ),
          ],
          educations: [
            CvEducation(
              degree: 'CERTIFICADO DE PROFESIONALIDAD (EN CURSO)',
              institution: 'Servicio Canario de Empleo / Ayuntamiento de Arucas',
              period: '2024 - 2025',
              details: 'Formación teórico-práctica acreditada con módulos de Competencias Clave y PRL.',
            ),
            CvEducation(
              degree: 'COMPETENCIAS CLAVE Y HABILIDADES LABORALES',
              institution: 'Programa de Empleo y Formación Trayectoria Arucas',
              period: '2024 - 2025',
              details: 'Módulos transversales de Matemáticas, Lengua Castellana, Competencias Digitales y Orientación Laboral.',
            ),
          ],
          template: 'sidebar_dark',
          accentColor: '#10B981',
          fontFamily: 'Inter',
        ),
        const CvProfileModel(
          id: 'profile-2',
          moduleBadge: 'MÓDULO FC0003 · Inserción y Orientación Laboral',
          workshopTitle: 'Taller de Curriculum Vitae · Gestión Docente',
          fullName: 'ANTONIO JOSÉ GÓMEZ CABRERA',
          jobTitle: 'OPERARIO/A DE MANTENIMIENTO URBANO',
          photoUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80',
          photoZoom: 1.0,
          phone: '+34 611 222 333',
          email: 'antonio.gomez.c@correo.es',
          location: 'Las Palmas de Gran Canaria',
          availability: 'Disponibilidad completa e incorporación inmediata',
          drivingLicense: 'Permiso B y vehículo propio',
          summary: 'Persona proactiva con sólida experiencia práctica en conservación vial, mantenimiento de edificios e infraestructuras comunitarias.',
          skills: ['Mantenimiento preventivo', 'Jardinería básica', 'Reparaciones rápidas', 'Manejo de maquinaria'],
          experiences: [
            CvExperience(
              jobTitle: 'PEÓN DE MANTENIMIENTO URBANO',
              company: 'Servicios Urbanos Integrados',
              period: '2023 - 2024',
              description: 'Limpieza y acondicionamiento de viales públicos, mantenimiento de mobiliario y apoyo a cuadrillas de especialistas.',
            ),
          ],
          educations: [
            CvEducation(
              degree: 'GRADUADO EN EDUCACIÓN SECUNDARIA OBLIGATORIA',
              institution: 'IES Gran Canaria',
              period: '2018 - 2022',
              details: 'Graduado con mención en tecnología aplicada.',
            ),
          ],
          template: 'sidebar_dark',
          accentColor: '#10B981',
          fontFamily: 'Inter',
        ),
        const CvProfileModel(
          id: 'profile-3',
          moduleBadge: 'MÓDULO FC0003 · Inserción y Orientación Laboral',
          workshopTitle: 'Taller de Curriculum Vitae · Gestión Docente',
          fullName: 'ANDRIUCHA CASTILLO NAVARRO',
          jobTitle: 'OPERARIO/A DE MANTENIMIENTO Y SERVICIOS',
          photoUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&auto=format&fit=crop&q=80',
          photoZoom: 1.0,
          phone: '+34 622 333 444',
          email: 'andriucha.castillo@correo.es',
          location: 'Telde, Gran Canaria',
          availability: 'Incorporación inmediata en turnos rotativos',
          drivingLicense: 'Permiso B',
          summary: 'Técnico versátil enfocado en tareas de fontanería, electricidad básica y acondicionamiento de espacios públicos.',
          skills: ['Electricidad básica', 'Fontanería', 'Soldadura ligera', 'Pintura industrial'],
          experiences: [],
          educations: [],
          template: 'sidebar_dark',
          accentColor: '#3B82F6',
          fontFamily: 'Inter',
        ),
      ];
      await saveCvProfiles(defaultProfiles);
      await setActiveCvId('profile-1');
    }

    // 3. Default repo links
    final links = getRepoLinks();
    if (links.isEmpty) {
      final defaultLinks = [
        const RepoLinkModel(
          id: 1,
          title: 'Sanctuary Repository',
          url: 'https://github.com/carlosss91/Sanctuary',
          description: 'Repositorio principal del santuario con CV Builder y Docker',
          category: 'Repositorios',
          iconName: 'folder_git',
        ),
        const RepoLinkModel(
          id: 2,
          title: 'Portal Docente & Orientación',
          url: 'https://github.com/carlosss91',
          description: 'Herramienta de gestión de alumnos y orientación laboral',
          category: 'Educación',
          iconName: 'school',
        ),
        const RepoLinkModel(
          id: 3,
          title: 'Web Apps & Proyectos',
          url: 'https://github.com/carlosss91',
          description: 'Directorio de aplicaciones interactivas y utilidades',
          category: 'Web Apps',
          iconName: 'apps',
        ),
      ];
      await saveRepoLinks(defaultLinks);
    }
  }

  // --- Auth Session ---
  UserModel? getCurrentUser() {
    final str = _prefs.getString(_keyCurrentUser);
    if (str == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> setCurrentUser(UserModel? user) async {
    if (user == null) {
      await _prefs.remove(_keyCurrentUser);
    } else {
      await _prefs.setString(_keyCurrentUser, jsonEncode(user.toJson()));
    }
  }

  // --- Local Users List (fallback) ---
  Map<String, String> _getLocalPasswords() {
    final str = _prefs.getString('${_keyLocalUsers}_pwd');
    if (str == null) return {'admin': 'admin'};
    try {
      return Map<String, String>.from(jsonDecode(str) as Map);
    } catch (_) {
      return {'admin': 'admin'};
    }
  }

  List<UserModel> getLocalUsers() {
    final str = _prefs.getString(_keyLocalUsers);
    if (str == null) return [];
    try {
      final list = jsonDecode(str) as List;
      return list.map((e) => UserModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveLocalUser(UserModel user, String password) async {
    final users = getLocalUsers().where((u) => u.username != user.username).toList();
    users.add(user);
    await _prefs.setString(_keyLocalUsers, jsonEncode(users.map((u) => u.toJson()).toList()));

    final pwds = _getLocalPasswords();
    pwds[user.username] = password;
    await _prefs.setString('${_keyLocalUsers}_pwd', jsonEncode(pwds));
  }

  bool verifyLocalCredentials(String username, String password) {
    final pwds = _getLocalPasswords();
    return pwds[username] == password;
  }

  // --- CV Profiles ---
  List<CvProfileModel> getCvProfiles() {
    final str = _prefs.getString(_keyCvProfiles);
    if (str == null) return [];
    try {
      final list = jsonDecode(str) as List;
      return list.map((e) => CvProfileModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCvProfiles(List<CvProfileModel> profiles) async {
    await _prefs.setString(_keyCvProfiles, jsonEncode(profiles.map((p) => p.toJson()).toList()));
  }

  String? getActiveCvId() => _prefs.getString(_keyActiveCvId);

  Future<void> setActiveCvId(String id) async {
    await _prefs.setString(_keyActiveCvId, id);
  }

  // --- Repo Links ---
  List<RepoLinkModel> getRepoLinks() {
    final str = _prefs.getString(_keyRepoLinks);
    if (str == null) return [];
    try {
      final list = jsonDecode(str) as List;
      return list.map((e) => RepoLinkModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveRepoLinks(List<RepoLinkModel> links) async {
    await _prefs.setString(_keyRepoLinks, jsonEncode(links.map((l) => l.toJson()).toList()));
  }

  // --- Preferences ---
  bool isDarkTheme() => _prefs.getString(_keyThemeMode) != 'light';

  Future<void> setThemeMode(bool isDark) async {
    await _prefs.setString(_keyThemeMode, isDark ? 'dark' : 'light');
  }

  bool isCosmicActive() => _prefs.getBool(_keyCosmicActive) ?? true;

  Future<void> setCosmicActive(bool active) async {
    await _prefs.setBool(_keyCosmicActive, active);
  }

  // --- GitHub Config ---
  static const String _keyGitHubUsername = 'sanctuary_github_username';

  String getGitHubUsername() => _prefs.getString(_keyGitHubUsername) ?? 'carlosss91';

  Future<void> setGitHubUsername(String username) async {
    await _prefs.setString(_keyGitHubUsername, username.trim());
  }
}
