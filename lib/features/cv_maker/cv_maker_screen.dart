import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/trayectoria_sidebar.dart';
import '../../core/widgets/sanctuary_planet_logo.dart';
import '../hub/user_profile_dialog.dart';
import '../../data/models/cv_profile_model.dart';
import '../../data/services/api_service.dart';
import '../../data/services/pdf_export_service.dart';
import '../../data/services/docx_export_service.dart';
import '../../data/services/translation_service.dart';
import '../../data/services/cv_document_parser_service.dart';
import 'widgets/template_selector_bar.dart';
import 'widgets/cv_editor_tabs.dart';
import 'widgets/a4_sheet_preview.dart';

class CvMakerScreen extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onBackToHub;
  final VoidCallback onLogout;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleCosmic;
  final VoidCallback? onOpenPdfSigner;
  final VoidCallback? onOpenPreziDownloader;
  final VoidCallback? onOpenAdminPanel;
  final bool isDark;
  final bool isCosmicActive;

  const CvMakerScreen({
    super.key,
    required this.apiService,
    required this.onBackToHub,
    this.onOpenPdfSigner,
    this.onOpenPreziDownloader,
    this.onOpenAdminPanel,
    required this.onLogout,
    required this.onToggleTheme,
    required this.onToggleCosmic,
    required this.isDark,
    required this.isCosmicActive,
  });

  @override
  State<CvMakerScreen> createState() => _CvMakerScreenState();
}

typedef CvBuilderScreen = CvMakerScreen;

class _CvMakerScreenState extends State<CvMakerScreen> {
  List<CvProfileModel> _profiles = [];
  String _activeId = 'profile-1';
  bool _isLoading = true;
  Timer? _debounceTimer;
  String _autoSaveStatus = 'Autoguardado activo';
  bool _isSaving = false;
  int _mobileTabIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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

  Future<void> _handleImportCvDocument(CvProfileModel activeProfile) async {
    final parsed = await CvDocumentParserService.pickAndParseCvDocument(
      context,
      activeProfile,
      apiService: widget.apiService,
    );
    if (parsed != null) {
      _onProfileEdited(parsed);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Datos del CV importados y aplicados exitosamente!'),
            backgroundColor: AppTheme.emerald,
          ),
        );
      }
    }
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

  Future<void> _confirmAndDeleteProfile(String profileId) async {
    if (_profiles.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se puede eliminar la única ficha activa. Crea otra primero.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    final targetProfile = _profiles.firstWhere(
      (p) => p.id == profileId,
      orElse: () => _profiles.first,
    );
    final targetName = targetProfile.fullName.isNotEmpty ? targetProfile.fullName : 'este alumno';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
              SizedBox(width: 8),
              Text('Eliminar Ficha de Currículum', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            '¿Estás seguro de que deseas eliminar permanentemente la ficha de "$targetName"? Esta acción no se puede deshacer.',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Eliminar Ficha'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await widget.apiService.deleteProfile(profileId);
      final remaining = _profiles.where((p) => p.id != profileId).toList();
      final nextActive = remaining.isNotEmpty ? remaining.first.id : 'temp';
      setState(() => _activeId = nextActive);
      await widget.apiService.storage.setActiveCvId(nextActive);
      _loadProfiles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✔ Ficha de "$targetName" eliminada correctamente.'),
            backgroundColor: AppTheme.emerald,
          ),
        );
      }
    }
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
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      drawer: Drawer(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(28))),
        child: SafeArea(
          child: TrayectoriaSidebar(
            activeItem: 'Orientación',
            isDark: isDark,
            isCollapsed: false,
            onSelect: (itemKey) {
              Navigator.of(context).maybePop();
              if (itemKey == 'Inicio') {
                widget.onBackToHub();
              } else if (itemKey == 'PdfSigner' && widget.onOpenPdfSigner != null) {
                widget.onOpenPdfSigner!();
              } else if (itemKey == 'Prezi2Pdf' && widget.onOpenPreziDownloader != null) {
                widget.onOpenPreziDownloader!();
              } else if ((itemKey == 'AdminPanel' || itemKey == 'Ajustes') && widget.onOpenAdminPanel != null) {
                widget.onOpenAdminPanel!();
              } else if (itemKey == 'Alumnos') {
                _showTeacherManagementDialog();
              }
            },
          ),
        ),
      ),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: !isMobile,
        titleSpacing: isMobile ? 0 : NavigationToolbar.kMiddleSpacing,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0A0F1D).withOpacity(0.55) : Colors.white.withOpacity(0.65),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          tooltip: 'Volver a Sanctuary Hub',
          onPressed: widget.onBackToHub,
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SanctuaryPlanetLogo(size: isMobile ? 20 : 26, showGlow: true),
            SizedBox(width: isMobile ? 6 : 9),
            Text(
              'SANCTUARY',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: isMobile ? 12.5 : 15,
                letterSpacing: isMobile ? 1.0 : 2.0,
              ),
            ),
          ],
        ),
        actions: [
          // Auto-save Status Indicator
          Tooltip(
            message: _autoSaveStatus,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06)),
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
                  if (!isMobile) ...[
                    const SizedBox(width: 6),
                    Text(
                      _autoSaveStatus,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(width: isMobile ? 4 : 8),

          if (!isMobile) ...[
            // Cosmic Animation Toggle
            IconButton(
              tooltip: widget.isCosmicActive ? 'Pausar animación cósmica' : 'Activar animación cósmica',
              icon: Icon(
                widget.isCosmicActive ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                size: 20,
                color: widget.isCosmicActive ? AppTheme.emerald : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              onPressed: widget.onToggleCosmic,
            ),
            const SizedBox(width: 4),

            // Theme Toggle
            IconButton(
              tooltip: isDark ? 'Cambiar a Modo Claro' : 'Cambiar a Modo Oscuro',
              icon: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 20,
                color: isDark ? const Color(0xFFF59E0B) : const Color(0xFF475569),
              ),
              onPressed: widget.onToggleTheme,
            ),
            const SizedBox(width: 4),
          ],

          // User Profile Dropdown Button
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
              } else if (val == 'admin') {
                widget.onOpenAdminPanel?.call();
              } else if (val == 'teacher') {
                _showTeacherManagementDialog();
              } else if (val == 'edit_profile' && currentUser != null) {
                UserProfileDialog.show(
                  context,
                  user: currentUser,
                  apiService: widget.apiService,
                  onUserUpdated: (updated) {
                    setState(() {});
                  },
                );
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
                      backgroundImage: currentUser?.avatarUrl != null && currentUser!.avatarUrl!.isNotEmpty
                          ? NetworkImage(currentUser.avatarUrl!)
                          : null,
                      child: (currentUser?.avatarUrl == null || currentUser!.avatarUrl!.isEmpty)
                          ? Text(
                              userInitial,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            )
                          : null,
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
                value: 'edit_profile',
                child: Row(
                  children: [
                    Icon(Icons.manage_accounts_outlined, size: 16, color: AppTheme.emerald),
                    SizedBox(width: 10),
                    Text('Editar Perfil y Foto', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),

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

              if (currentUser?.role.toLowerCase() == 'admin' && widget.onOpenAdminPanel != null) ...[
                const PopupMenuItem<String>(
                  value: 'admin',
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings_rounded, size: 16, color: Color(0xFF06B6D4)),
                      SizedBox(width: 10),
                      Text(
                        'Panel de Administración',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
              ],

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

              // CERRAR SESIÓN
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
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 5 : 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.emerald.withOpacity(0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: AppTheme.emerald,
                    backgroundImage: currentUser?.avatarUrl != null && currentUser!.avatarUrl!.isNotEmpty
                        ? NetworkImage(currentUser.avatarUrl!)
                        : null,
                    child: (currentUser?.avatarUrl == null || currentUser!.avatarUrl!.isEmpty)
                        ? Text(
                            userInitial,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  if (!isMobile) ...[
                    const SizedBox(width: 8),
                    Text(
                      username,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: Stack(
        children: [
          // 1. CARDS / MAIN CONTENT (Full height down to bottom with small padding)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isLargeScreen = constraints.maxWidth > 920;

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 8 : 14,
                    isMobile ? 8 : 14,
                    isMobile ? 8 : 14,
                    isMobile ? 10 : 14, // Cards extend to bottom edge with small padding
                  ),
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
                        onDeleteProfile: _confirmAndDeleteProfile,
                        onImportCv: () => _handleImportCvDocument(activeProfile),
                      ),

                      const SizedBox(height: 10),

                      // Mobile tab switcher if screen is small
                      if (!isLargeScreen)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
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

          // 2. Floating Action Dock directly at the bottom on BOTH mobile & desktop
          Positioned(
            bottom: isMobile ? 12 : 18,
            left: 0,
            right: 0,
            child: Center(
              child: _buildCvMakerFloatingDock(isDark, isMobile, activeProfile),
            ),
          ),
        ],
      ),
    );
  }

  // Floating Action Dock for CV Maker (iOS27 glassmorphic style on mobile & desktop)
  Widget _buildCvMakerFloatingDock(bool isDark, bool isMobile, CvProfileModel profile) {
    final isEn = profile.isEnglishVersion;
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF131D31).withOpacity(0.50)
                : Colors.white.withOpacity(0.60),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.18) : Colors.white.withOpacity(0.80),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.20 : 0.06),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Alternar Editor / Previsualización A4 (Solo en móvil)
              if (isMobile) ...[
                _buildDockButton(
                  icon: _mobileTabIndex == 0 ? Icons.visibility_outlined : Icons.edit_note_outlined,
                  label: null,
                  tooltip: _mobileTabIndex == 0 ? 'Ver Previsualización A4' : 'Volver al Editor',
                  onTap: () => setState(() => _mobileTabIndex = _mobileTabIndex == 0 ? 1 : 0),
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  bgColor: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                ),
                const SizedBox(width: 8),
              ],

              // 2. Idioma ES / EN
              _buildDockButton(
                icon: Icons.language_rounded,
                label: isMobile ? (isEn ? 'EN' : 'ES') : (isEn ? 'Idioma: EN' : 'Idioma: ES'),
                tooltip: 'Cambiar idioma del currículum (Español / Inglés)',
                onTap: _toggleLanguage,
                color: AppTheme.emerald,
                bgColor: AppTheme.emerald.withOpacity(0.20),
                borderColor: AppTheme.emerald.withOpacity(0.40),
              ),
              const SizedBox(width: 8),

              // 3. Exportar PDF (Rojo/Coral translúcido)
              _buildDockButton(
                icon: Icons.picture_as_pdf_rounded,
                label: isMobile ? 'PDF' : 'Exportar PDF',
                tooltip: 'Exportar currículum a documento PDF oficial',
                onTap: _exportPdf,
                color: Colors.white,
                bgColor: const Color(0xFFEF4444).withOpacity(0.85),
                borderColor: Colors.white.withOpacity(0.30),
                isPrimary: true,
              ),
              const SizedBox(width: 8),

              // 4. Descargar Word DOCX (Azul translúcido)
              _buildDockButton(
                icon: Icons.description_rounded,
                label: isMobile ? 'Word' : 'Descargar Word',
                tooltip: 'Descargar currículum en formato Word DOCX',
                onTap: _exportWord,
                color: Colors.white,
                bgColor: const Color(0xFF2563EB).withOpacity(0.85),
                borderColor: Colors.white.withOpacity(0.30),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDockButton({
    required IconData icon,
    String? label,
    required String tooltip,
    required VoidCallback onTap,
    required Color color,
    required Color bgColor,
    Color? borderColor,
    bool isPrimary = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: label != null ? 12 : 9, vertical: 7),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: borderColor ?? (isPrimary ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.12)),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
