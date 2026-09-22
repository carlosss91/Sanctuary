import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/trayectoria_sidebar.dart';
import '../../data/models/cv_profile_model.dart';
import '../../data/services/api_service.dart';
import '../../data/services/pdf_export_service.dart';
import '../../data/services/docx_export_service.dart';
import '../../data/services/translation_service.dart';
import 'widgets/template_selector_bar.dart';
import 'widgets/cv_editor_tabs.dart';
import 'widgets/a4_sheet_preview.dart';

class CvBuilderScreen extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onBackToHub;
  final VoidCallback onLogout;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleCosmic;
  final bool isDark;
  final bool isCosmicActive;

  const CvBuilderScreen({
    super.key,
    required this.apiService,
    required this.onBackToHub,
    required this.onLogout,
    required this.onToggleTheme,
    required this.onToggleCosmic,
    required this.isDark,
    required this.isCosmicActive,
  });

  @override
  State<CvBuilderScreen> createState() => _CvBuilderScreenState();
}

class _CvBuilderScreenState extends State<CvBuilderScreen> {
  List<CvProfileModel> _profiles = [];
  String _activeId = 'profile-1';
  bool _isLoading = true;
  Timer? _debounceTimer;
  String _autoSaveStatus = 'Autoguardado activo';
  bool _isSaving = false;
  int _mobileTabIndex = 0; // 0: Editor, 1: Previsualización A4 (para móviles)
  bool _isSidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    setState(() => _isLoading = true);
    final list = await widget.apiService.getProfiles();
    final savedActiveId = widget.apiService.storage.getActiveCvId();

    if (mounted) {
      setState(() {
        _profiles = list;
        if (savedActiveId != null && _profiles.any((p) => p.id == savedActiveId)) {
          _activeId = savedActiveId;
        } else if (_profiles.isNotEmpty) {
          _activeId = _profiles.first.id;
        }
        _isLoading = false;
      });
    }
  }

  CvProfileModel get _activeProfile {
    return _profiles.firstWhere(
      (p) => p.id == _activeId,
      orElse: () => _profiles.isNotEmpty ? _profiles.first : const CvProfileModel(id: 'temp'),
    );
  }

  void _onProfileEdited(CvProfileModel updated) {
    setState(() {
      final index = _profiles.indexWhere((p) => p.id == updated.id);
      if (index >= 0) {
        _profiles[index] = updated;
      }
      _autoSaveStatus = 'Guardando cambios...';
      _isSaving = true;
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      await widget.apiService.saveProfile(updated);
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      if (mounted) {
        setState(() {
          _autoSaveStatus = 'Guardado a las $timeStr';
          _isSaving = false;
        });
      }
    });
  }

  Future<void> _addNewLearner() async {
    final newId = 'profile-${DateTime.now().millisecondsSinceEpoch}';
    final newLearner = CvProfileModel(
      id: newId,
      fullName: 'NUEVO APRENDIZ / ALUMNO',
      jobTitle: 'OPERARIO/A EN FORMACIÓN',
      photoUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80',
      phone: '+34 600 000 000',
      email: 'alumno@correo.es',
      location: 'Las Palmas, Gran Canaria',
      availability: 'Disponibilidad horaria e incorporación inmediata',
      drivingLicense: 'Permiso B',
      summary: 'Persona responsable y motivada, con iniciativa, puntualidad y capacidad para integrarse con éxito en equipos de trabajo.',
      skills: ['Trabajo en equipo', 'Puntualidad', 'Manejo de herramientas', 'Prevención de riesgos'],
      template: 'sidebar_dark',
      accentColor: '#0D9488',
      fontFamily: 'Inter',
      showWatermark: true,
      watermarkPattern: 'gears',
    );

    setState(() {
      _profiles.add(newLearner);
      _activeId = newId;
    });

    await widget.apiService.storage.setActiveCvId(newId);
    await widget.apiService.saveProfile(newLearner);
  }

  void _toggleLanguage() {
    final translated = TranslationService.toggleLanguage(_activeProfile);
    _onProfileEdited(translated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(translated.isEnglishVersion
            ? '¡Currículum traducido al Inglés con éxito!'
            : 'Currículum restaurado a versión en Español.'),
        backgroundColor: AppTheme.emerald,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _exportPdf() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generando documento PDF A4 vectorial de alta fidelidad...'),
        backgroundColor: AppTheme.emerald,
        duration: Duration(seconds: 2),
      ),
    );
    await PdfExportService.printOrSavePdf(_activeProfile);
  }

  void _exportWord() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generando archivo Word (.docx) editable...'),
        backgroundColor: AppTheme.emerald,
        duration: Duration(seconds: 2),
      ),
    );
    await DocxExportService.downloadDocx(_activeProfile);
  }

  void _showInstallDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.download_for_offline_outlined, color: AppTheme.emerald),
              SizedBox(width: 10),
              Text('Instalar / Exportar Aplicación'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Elige tu método de instalación o descarga:'),
              const SizedBox(height: 14),
              ListTile(
                dense: true,
                leading: const Icon(Icons.android, color: AppTheme.emerald),
                title: const Text('Compilar APK para Android'),
                subtitle: const Text('Ejecuta bash build_apk.sh o usa las tareas de Antigravity'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ejecuta "bash build_apk.sh" en terminal para generar el APK.'),
                      backgroundColor: AppTheme.emerald,
                    ),
                  );
                },
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.web, color: AppTheme.emerald),
                title: const Text('Acceso Web Directo (PWA)'),
                subtitle: const Text('Disponible en http://localhost:8085'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  void _showTrayectorIaDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppTheme.emerald),
              SizedBox(width: 10),
              Text('TrayectorIA · Asistente Vocacional'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sugerencias automáticas para mejorar el CV del alumno:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 12),
                _buildAiTip('Potenciar EPIs', 'Se recomienda destacar el uso de equipos de protección individual en mantenimiento.'),
                const SizedBox(height: 8),
                _buildAiTip('Competencias Clave', 'Añadir habilidades de fontanería básica y resolución rápida de incidencias.'),
                const SizedBox(height: 8),
                _buildAiTip('Formato A4 Oficial', 'El perfil actual cumple al 100% los requisitos del módulo docente FC0003.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAiTip(String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.emerald.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.emerald.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, size: 14, color: AppTheme.emerald),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.emerald)),
            ],
          ),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  void _showTeacherManagementDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.school, color: AppTheme.emerald),
              SizedBox(width: 8),
              Text('Gestión Docente · Módulo FC0003'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Listado de Alumnos Matriculados (${_profiles.length}):',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _profiles.length,
                    itemBuilder: (ctx, i) {
                      final p = _profiles[i];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          child: Text(p.fullName.isNotEmpty ? p.fullName[0] : 'A', style: const TextStyle(fontSize: 10)),
                        ),
                        title: Text(p.fullName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: Text(p.jobTitle, style: const TextStyle(fontSize: 10)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                          onPressed: () async {
                            if (_profiles.length <= 1) return;
                            await widget.apiService.deleteProfile(p.id);
                            if (context.mounted) Navigator.pop(context);
                            _loadProfiles();
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final currentUser = widget.apiService.storage.getCurrentUser();
    final username = currentUser?.username ?? 'admin';
    final userInitial = username.isNotEmpty ? username[0].toUpperCase() : 'P';

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(color: AppTheme.emerald)),
      );
    }

    final activeProfile = _activeProfile;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ================================================================
          // LEFT SIDEBAR (Trayectoria 2026 - Portal de Gestión y Formación)
          // ================================================================
          TrayectoriaSidebar(
            activeItem: 'Orientación',
            isDark: isDark,
            isCollapsed: _isSidebarCollapsed,
            onToggleCollapse: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
            onSelect: (itemKey) {
              if (itemKey == 'Inicio') {
                widget.onBackToHub();
              } else if (itemKey == 'Alumnos') {
                _showTeacherManagementDialog();
              } else if (itemKey == 'Orientación') {
                // Stay on CV Builder
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Sección "$itemKey" activa.'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
          ),

          // ================================================================
          // MAIN CONTENT AREA
          // ================================================================
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // TOP NAVIGATION BAR (Clean with Back button, title, language, install and user menu)
                Container(
                  height: 58,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0E131F) : const Color(0xFFFFFFFF),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // PERMANENT "ATRÁS" BUTTON (Takes user back to Hub)
                      InkWell(
                        onTap: widget.onBackToHub,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back, size: 16, color: isDark ? Colors.white : Colors.black87),
                              const SizedBox(width: 6),
                              Text(
                                'Atrás',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Module tag / Title
                      Text(
                        'Orientación Laboral · Taller de Curriculum Vitae',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        ),
                      ),

                      const Spacer(),

                      // Auto-save Status Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161F30) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isSaving ? Colors.amber : AppTheme.emerald,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _autoSaveStatus,
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      const SizedBox(width: 8),

                      // "Instalar App" Button (matching screenshot)
                      OutlinedButton.icon(
                        onPressed: _showInstallDialog,
                        icon: const Icon(Icons.install_mobile_outlined, size: 14, color: AppTheme.emerald),
                        label: const Text('Instalar', style: TextStyle(fontSize: 12, color: AppTheme.emerald)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          side: BorderSide(color: AppTheme.emerald.withOpacity(0.4)),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // "TrayectorIA" Button (matching screenshot)
                      ElevatedButton.icon(
                        onPressed: _showTrayectorIaDialog,
                        icon: const Icon(Icons.auto_awesome, size: 14),
                        label: const Text('TrayectorIA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Theme Toggle (Moon / Sun icon matching screenshot)
                      IconButton(
                        tooltip: isDark ? 'Cambiar a Modo Claro' : 'Cambiar a Modo Oscuro',
                        icon: Icon(isDark ? Icons.nightlight_outlined : Icons.wb_sunny_outlined, size: 19),
                        onPressed: widget.onToggleTheme,
                      ),
                      const SizedBox(width: 6),

                      // USER CIRCLE AVATAR WITH DROPDOWN MENU
                      PopupMenuButton<String>(
                        tooltip: 'Perfil de Usuario',
                        offset: const Offset(0, 46),
                        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                        ),
                        onSelected: (val) {
                          if (val == 'logout') {
                            widget.onLogout();
                          } else if (val == 'hub') {
                            widget.onBackToHub();
                          } else if (val == 'cosmic') {
                            widget.onToggleCosmic();
                          } else if (val == 'teacher') {
                            _showTeacherManagementDialog();
                          }
                        },
                        itemBuilder: (context) => [
                          // User Info Header
                          PopupMenuItem<String>(
                            enabled: false,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppTheme.emerald,
                                  child: Text(
                                    userInitial,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      username,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      'Usuario Activo · ${currentUser?.role ?? "admin"}',
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),

                          const PopupMenuItem<String>(
                            value: 'teacher',
                            child: Row(
                              children: [
                                Icon(Icons.school, size: 16, color: AppTheme.emerald),
                                SizedBox(width: 10),
                                Text('Gestión Docente (FC0003)', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),

                          const PopupMenuDivider(),

                          PopupMenuItem<String>(
                            value: 'hub',
                            child: const Row(
                              children: [
                                Icon(Icons.hub_outlined, size: 16),
                                SizedBox(width: 10),
                                Text('Ir al Santuario (Hub)', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),

                          PopupMenuItem<String>(
                            value: 'cosmic',
                            child: Row(
                              children: [
                                Icon(widget.isCosmicActive ? Icons.auto_awesome : Icons.auto_awesome_outlined, size: 16),
                                SizedBox(width: 10),
                                Text(
                                  widget.isCosmicActive ? 'Pausar Estrellas' : 'Activar Estrellas',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),

                          const PopupMenuDivider(),

                          // CERRAR SESIÓN (Inside user dropdown as requested!)
                          const PopupMenuItem<String>(
                            value: 'logout',
                            child: Row(
                              children: [
                                Icon(Icons.logout, size: 16, color: Colors.redAccent),
                                SizedBox(width: 10),
                                Text(
                                  'Cerrar Sesión',
                                  style: TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            border: Border.all(color: AppTheme.emerald.withOpacity(0.5), width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              userInitial,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.emerald,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // WORKSPACE (Carousel + Action buttons + Editor tabs + A4 Preview)
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isLargeScreen = constraints.maxWidth > 920;

                      return Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. TOP CURRICULUM TEMPLATE SELECTOR BAR
                            TemplateSelectorBar(
                              activeTemplate: activeProfile.template,
                              onSelectTemplate: (tpl) {
                                _onProfileEdited(activeProfile.copyWith(template: tpl));
                              },
                              profiles: _profiles,
                              activeProfileId: _activeId,
                              onSelectProfile: (id) async {
                                setState(() => _activeId = id);
                                await widget.apiService.storage.setActiveCvId(id);
                              },
                              onAddProfile: _addNewLearner,
                            ),

                            const SizedBox(height: 10),

                            // Mobile tab switcher if screen is small
                            if (!isLargeScreen)
                              Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: ChoiceChip(
                                        label: const Center(child: Text('Editor del CV')),
                                        selected: _mobileTabIndex == 0,
                                        selectedColor: AppTheme.emerald.withOpacity(0.2),
                                        onSelected: (_) => setState(() => _mobileTabIndex = 0),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ChoiceChip(
                                        label: const Center(child: Text('Previsualización A4')),
                                        selected: _mobileTabIndex == 1,
                                        selectedColor: AppTheme.emerald.withOpacity(0.2),
                                        onSelected: (_) => setState(() => _mobileTabIndex = 1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // 2. MAIN SPLIT VIEW (Editor on Left, A4 Live Sheet on Right)
                            Expanded(
                              child: isLargeScreen
                                  ? Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // Left Panel: Form Editor Tabs (7 steps)
                                        Expanded(
                                          flex: 11,
                                          child: CvEditorTabs(
                                            profile: activeProfile,
                                            onProfileChanged: _onProfileEdited,
                                            apiService: widget.apiService,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Right Panel: Live A4 Preview
                                        Expanded(
                                          flex: 10,
                                          child: A4SheetPreview(
                                            profile: activeProfile,
                                            onExportPdf: _exportPdf,
                                            onExportWord: _exportWord,
                                            onToggleLanguage: _toggleLanguage,
                                          ),
                                        ),
                                      ],
                                    )
                                  : (_mobileTabIndex == 0
                                      ? CvEditorTabs(
                                          profile: activeProfile,
                                          onProfileChanged: _onProfileEdited,
                                          apiService: widget.apiService,
                                        )
                                      : A4SheetPreview(
                                          profile: activeProfile,
                                          onExportPdf: _exportPdf,
                                          onExportWord: _exportWord,
                                          onToggleLanguage: _toggleLanguage,
                                        )),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
