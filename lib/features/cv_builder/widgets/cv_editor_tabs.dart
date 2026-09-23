import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/cv_profile_model.dart';
import '../../../data/services/api_service.dart';
import 'photo_zoom_picker.dart';

class CvEditorTabs extends StatefulWidget {
  final CvProfileModel profile;
  final ValueChanged<CvProfileModel> onProfileChanged;
  final ApiService? apiService;

  const CvEditorTabs({
    super.key,
    required this.profile,
    required this.onProfileChanged,
    this.apiService,
  });

  @override
  State<CvEditorTabs> createState() => _CvEditorTabsState();
}

class _CvEditorTabsState extends State<CvEditorTabs> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controllers for text fields
  late TextEditingController _nameCtrl;
  late TextEditingController _jobTitleCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _availabilityCtrl;
  late TextEditingController _licenseCtrl;
  late TextEditingController _summaryCtrl;
  late TextEditingController _q1Ctrl;
  late TextEditingController _q2Ctrl;
  late TextEditingController _q3Ctrl;
  String? _previousSummaryBeforeAi;
  bool _isAiDrafting = false;
  final TextEditingController _skillInputCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _initControllers();
  }

  void _initControllers() {
    _nameCtrl = TextEditingController(text: widget.profile.fullName);
    _jobTitleCtrl = TextEditingController(text: widget.profile.jobTitle);
    _phoneCtrl = TextEditingController(text: widget.profile.phone);
    _emailCtrl = TextEditingController(text: widget.profile.email);
    _locationCtrl = TextEditingController(text: widget.profile.location);
    _availabilityCtrl = TextEditingController(text: widget.profile.availability);
    _licenseCtrl = TextEditingController(text: widget.profile.drivingLicense);
    _summaryCtrl = TextEditingController(text: widget.profile.summary);
    _q1Ctrl = TextEditingController();
    _q2Ctrl = TextEditingController();
    _q3Ctrl = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant CvEditorTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id ||
        oldWidget.profile.isEnglishVersion != widget.profile.isEnglishVersion) {
      _nameCtrl.text = widget.profile.fullName;
      _jobTitleCtrl.text = widget.profile.jobTitle;
      _phoneCtrl.text = widget.profile.phone;
      _emailCtrl.text = widget.profile.email;
      _locationCtrl.text = widget.profile.location;
      _availabilityCtrl.text = widget.profile.availability;
      _licenseCtrl.text = widget.profile.drivingLicense;
      _summaryCtrl.text = widget.profile.summary;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _jobTitleCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _locationCtrl.dispose();
    _availabilityCtrl.dispose();
    _licenseCtrl.dispose();
    _summaryCtrl.dispose();
    _q1Ctrl.dispose();
    _q2Ctrl.dispose();
    _q3Ctrl.dispose();
    _skillInputCtrl.dispose();
    super.dispose();
  }

  void _draftSobreMiWithAi() async {
    setState(() => _isAiDrafting = true);
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    final q1 = _q1Ctrl.text.trim();
    final q2 = _q2Ctrl.text.trim();
    final q3 = _q3Ctrl.text.trim();

    // Store previous version for instant undo
    _previousSummaryBeforeAi = _summaryCtrl.text;

    String aiBio = '';
    if (q1.isNotEmpty || q2.isNotEmpty || q3.isNotEmpty) {
      final part1 = q1.isNotEmpty
          ? 'Profesional comprometido con una sólida metodología de trabajo: $q1.'
          : 'Profesional cualificado con alto sentido de la responsabilidad, puntualidad rigurosa y vocación de servicio en equipo.';

      final part2 = q2.isNotEmpty
          ? 'Cuento con destreza contrastada en $q2, aplicando siempre las directrices de seguridad y buenas prácticas operativas.'
          : 'Poseo dominio práctico en el uso de maquinaria, útiles del oficio y protocolos estrictos de prevención laboral y EPIs.';

      final part3 = q3.isNotEmpty
          ? 'Aporto $q3.'
          : 'Aporto versatilidad, rápida capacidad de adaptación y plena disposición para afrontar nuevos retos operativos con dedicación y solvencia.';

      aiBio = '$part1\n\n$part2\n\n$part3';
    } else {
      aiBio = 'Profesional responsable y dinámico con clara orientación práctica y capacidad demostrada para el trabajo en cuadrilla. '
          'Domino las herramientas, útiles y maquinaria del oficio, priorizando en todo momento la prevención de riesgos laborales y el rigor en los tiempos de ejecución.\n\n'
          'Aporto capacidad de aprendizaje ágil, polivalencia y constante iniciativa para resolver incidencias en el puesto de trabajo.';
    }

    _summaryCtrl.text = aiBio;
    _update(widget.profile.copyWith(summary: aiBio));
    setState(() => _isAiDrafting = false);
  }

  void _restorePreviousSummary() {
    if (_previousSummaryBeforeAi != null) {
      _summaryCtrl.text = _previousSummaryBeforeAi!;
      _update(widget.profile.copyWith(summary: _previousSummaryBeforeAi!));
      setState(() {
        _previousSummaryBeforeAi = null;
      });
    }
  }

  void _update(CvProfileModel updated) {
    widget.onProfileChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard.withOpacity(0.9) : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tab Bar (matching the step-by-step pill buttons in screenshot)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: Colors.transparent,
              dividerColor: Colors.transparent,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              tabs: [
                _buildTabPill(Icons.person_outline, '1. Identidad', 0, isDark),
                _buildTabPill(Icons.phone_outlined, '2. Contacto', 1, isDark),
                _buildTabPill(Icons.article_outlined, '3. Sobre Mí', 2, isDark),
                _buildTabPill(Icons.star_outline, '4. Competencias', 3, isDark),
                _buildTabPill(Icons.work_outline, '5. Experiencia', 4, isDark),
                _buildTabPill(Icons.school_outlined, '6. Formación', 5, isDark),
                _buildTabPill(Icons.palette_outlined, '7. Diseño y Color', 6, isDark),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildIdentidadTab(isDark),
                _buildContactoTab(isDark),
                _buildSobreMiTab(isDark),
                _buildCompetenciasTab(isDark),
                _buildExperienciaTab(isDark),
                _buildFormacionTab(isDark),
                _buildDisenoYColorTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: IDENTIDAD ---
  Widget _buildIdentidadTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_outlined, size: 18, color: AppTheme.emerald),
              const SizedBox(width: 8),
              const Text('Datos Personales y Fotografía', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 14),

          // Photo Zoom Picker
          PhotoZoomPicker(
            profile: widget.profile,
            onProfileChanged: _update,
            apiService: widget.apiService,
          ),

          const SizedBox(height: 20),

          // Nombre Completo y Apellidos
          const Text('Nombre Completo y Apellidos', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(hintText: 'Ej. JOSÉ MARIO SUÁREZ MÉNDEZ'),
            onChanged: (val) => _update(widget.profile.copyWith(fullName: val)),
          ),

          const SizedBox(height: 16),

          // Titular Profesional / Puesto Aspirado
          const Text('Titular Profesional / Puesto Aspirado (Reactivo)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _jobTitleCtrl,
            decoration: const InputDecoration(hintText: 'Ej. OPERARIO/A DE MANTENIMIENTO URBANO'),
            onChanged: (val) => _update(widget.profile.copyWith(jobTitle: val)),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: CONTACTO ---
  Widget _buildContactoTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Información de Contacto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 14),

          const Text('Teléfono', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(hintText: '+34 600 000 000', prefixIcon: Icon(Icons.phone, size: 16)),
            onChanged: (val) => _update(widget.profile.copyWith(phone: val)),
          ),
          const SizedBox(height: 14),

          const Text('Correo Electrónico', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _emailCtrl,
            decoration: const InputDecoration(hintText: 'ejemplo@correo.es', prefixIcon: Icon(Icons.email, size: 16)),
            onChanged: (val) => _update(widget.profile.copyWith(email: val)),
          ),
          const SizedBox(height: 14),

          const Text('Ubicación / Municipio / Isla', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _locationCtrl,
            decoration: const InputDecoration(hintText: 'Arucas, Gran Canaria', prefixIcon: Icon(Icons.location_on, size: 16)),
            onChanged: (val) => _update(widget.profile.copyWith(location: val)),
          ),
          const SizedBox(height: 14),

          const Text('Disponibilidad Horaria', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _availabilityCtrl,
            decoration: const InputDecoration(
              hintText: 'Disponibilidad horaria e incorporación inmediata',
              prefixIcon: Icon(Icons.access_time, size: 16),
            ),
            onChanged: (val) => _update(widget.profile.copyWith(availability: val)),
          ),
          const SizedBox(height: 14),

          const Text('Permiso de Conducir y Vehículo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _licenseCtrl,
            decoration: const InputDecoration(
              hintText: 'Permiso B y vehículo propio',
              prefixIcon: Icon(Icons.directions_car, size: 16),
            ),
            onChanged: (val) => _update(widget.profile.copyWith(drivingLicense: val)),
          ),
        ],
      ),
    );
  }

  // --- TAB 3: SOBRE MÍ ---
  Widget _buildSobreMiTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.psychology_outlined, color: AppTheme.emerald, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Perfil Profesional / Sobre Mí', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(
                    'Responde a estas 3 preguntas y la IA generará una redacción profesional y de alto impacto.',
                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Question 1
          _buildQuestionCard(
            isDark: isDark,
            stepNumber: '1',
            icon: Icons.work_outline,
            question: '¿Cómo es tu forma de trabajar y qué valores te definen profesionalmente?',
            hint: 'Ej: Metódico, puntual, alta capacidad de trabajo en equipo, compromiso y orientación a la seguridad.',
            controller: _q1Ctrl,
          ),
          const SizedBox(height: 14),

          // Question 2
          _buildQuestionCard(
            isDark: isDark,
            stepNumber: '2',
            icon: Icons.handyman_outlined,
            question: '¿Qué habilidades principales, herramientas o métodos utilizas para hacer bien tu trabajo?',
            hint: 'Ej: Manejo de maquinaria y herramientas del oficio, prevención de riesgos laborales (EPIs), control de calidad.',
            controller: _q2Ctrl,
          ),
          const SizedBox(height: 14),

          // Question 3
          _buildQuestionCard(
            isDark: isDark,
            stepNumber: '3',
            icon: Icons.rocket_launch_outlined,
            question: '¿Qué valor extra aportas y qué buscas en tu próximo reto laboral?',
            hint: 'Ej: Rápida asimilación de novedades, polivalencia y motivación para aportar soluciones en proyectos a largo plazo.',
            controller: _q3Ctrl,
          ),
          const SizedBox(height: 18),

          // AI Generate Button
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isAiDrafting ? null : _draftSobreMiWithAi,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 2,
                  ),
                  icon: _isAiDrafting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(
                    _isAiDrafting ? 'Redactando perfil con IA...' : 'Redactar Sobre Mí con IA',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),

          // Undo / Restore Previous Version banner
          if (_previousSummaryBeforeAi != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: AppTheme.emerald),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Se ha aplicado la versión generada por IA. ¿Prefieres tu versión anterior?',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _restorePreviousSummary,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.emerald,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('Volver a la versión anterior', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 22),
          const Divider(),
          const SizedBox(height: 14),

          // Final editable text area
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Resultado final en el CV (Editable):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              if (_summaryCtrl.text.isNotEmpty)
                Text(
                  '${_summaryCtrl.text.length} caracteres',
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _summaryCtrl,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Aquí se mostrará el texto redactado por la IA o tu propio resumen profesional.',
            ),
            onChanged: (val) => _update(widget.profile.copyWith(summary: val)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard({
    required bool isDark,
    required String stepNumber,
    required IconData icon,
    required String question,
    required String hint,
    required TextEditingController controller,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  stepNumber,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.emerald,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  question,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: 2,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 4: COMPETENCIAS ---
  List<CvSkillItem> _getActiveSkillItems() {
    if (widget.profile.skillItems.isNotEmpty) {
      return widget.profile.skillItems;
    }
    if (widget.profile.skills.isNotEmpty) {
      return widget.profile.skills
          .map((s) => CvSkillItem(
                name: s,
                level: 5,
                description: _getAutoDescription(s),
              ))
          .toList();
    }
    return const [
      CvSkillItem(name: 'TRABAJO EN EQUIPO', level: 2, description: 'Compañerismo y coordinación en cuadrilla'),
      CvSkillItem(name: 'PREVENCIÓN Y EPIS', level: 5, description: 'Seguridad y prevención de riesgos en obra'),
      CvSkillItem(name: 'PUNTUALIDAD Y SERIEDAD', level: 5, description: 'Compromiso riguroso con horarios y tareas'),
      CvSkillItem(name: 'MANEJO DE HERRAMIENTAS', level: 4, description: 'Destreza con útiles manuales y eléctricos'),
      CvSkillItem(name: 'CAPACIDAD DE APRENDIZAJE', level: 5, description: 'Asimilación rápida de nuevas técnicas'),
    ];
  }

  void _updateSkillItems(List<CvSkillItem> newItems) {
    _update(widget.profile.copyWith(
      skillItems: newItems,
      skills: newItems.map((e) => e.name).toList(),
    ));
  }

  void _addSkillAtTop() {
    final current = List<CvSkillItem>.from(_getActiveSkillItems());
    current.insert(0, const CvSkillItem(name: 'NUEVA COMPETENCIA', level: 5));
    _updateSkillItems(current);
  }

  void _addSkillAtBottom() {
    final current = List<CvSkillItem>.from(_getActiveSkillItems());
    current.add(const CvSkillItem(name: 'NUEVA COMPETENCIA', level: 5));
    _updateSkillItems(current);
  }

  void _reorderSkill(int oldIndex, int newIndex) {
    final current = List<CvSkillItem>.from(_getActiveSkillItems());
    if (newIndex < 0 || newIndex >= current.length) return;
    final item = current.removeAt(oldIndex);
    current.insert(newIndex, item);
    _updateSkillItems(current);
  }

  void _updateSkillName(int index, String name) {
    final current = List<CvSkillItem>.from(_getActiveSkillItems());
    if (index >= 0 && index < current.length) {
      final old = current[index];
      current[index] = old.copyWith(
        name: name,
        description: old.description.isEmpty ? _getAutoDescription(name) : old.description,
      );
      _updateSkillItems(current);
    }
  }

  void _updateSkillLevel(int index, int level) {
    final current = List<CvSkillItem>.from(_getActiveSkillItems());
    if (index >= 0 && index < current.length) {
      current[index] = current[index].copyWith(level: level);
      _updateSkillItems(current);
    }
  }

  void _updateSkillDescription(int index, String desc) {
    final current = List<CvSkillItem>.from(_getActiveSkillItems());
    if (index >= 0 && index < current.length) {
      current[index] = current[index].copyWith(description: desc);
      _updateSkillItems(current);
    }
  }

  void _deleteSkill(int index) {
    final current = List<CvSkillItem>.from(_getActiveSkillItems());
    if (index >= 0 && index < current.length) {
      current.removeAt(index);
      _updateSkillItems(current);
    }
  }

  static String _getAutoDescription(String name) {
    final upper = name.toUpperCase().trim();
    if (upper.contains('EQUIPO')) return 'Compañerismo y coordinación en cuadrilla';
    if (upper.contains('PREVENCIÓN') || upper.contains('EPIS')) return 'Seguridad y prevención de riesgos en obra';
    if (upper.contains('PUNTUALIDAD') || upper.contains('SERIEDAD')) return 'Compromiso riguroso con horarios y tareas';
    if (upper.contains('HERRAMIENTA')) return 'Destreza con útiles manuales y eléctricos';
    if (upper.contains('APRENDIZAJE')) return 'Asimilación rápida de nuevas técnicas';
    if (upper.contains('ALBAÑIL')) return 'Técnicas de replanteo, tabiquería y enlucidos';
    if (upper.contains('FONTANER')) return 'Instalación y mantenimiento de redes de fontanería';
    if (upper.contains('PINTURA')) return 'Preparación de superficies y acabados de pintura';
    if (upper.contains('MAQUINARIA')) return 'Manejo seguro de maquinaria y equipos ligeros';
    if (upper.contains('JARDIN')) return 'Conservación de zonas verdes y podas';
    if (upper.contains('ELECTRIC')) return 'Instalaciones básicas de baja tensión';
    return '';
  }

  Widget _buildRatingStyleChoice(String style, String label, bool isDark) {
    final isSelected = widget.profile.skillRatingStyle == style;
    return InkWell(
      onTap: () => _update(widget.profile.copyWith(skillRatingStyle: style)),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.emerald.withOpacity(0.18)
              : (isDark ? const Color(0xFF0F172A) : Colors.white),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? AppTheme.emerald
                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? AppTheme.emerald
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildCompetenciasTab(bool isDark) {
    final items = _getActiveSkillItems();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enclosing Card matching Image 2
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1322) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Star Icon, Title and Buttons matching Image 2
                Row(
                  children: [
                    const Icon(
                      Icons.star_outline,
                      color: AppTheme.emerald,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Competencias y Habilidades (Sin iconos)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    // "+ Añadir Arriba" Button
                    InkWell(
                      onTap: _addSkillAtTop,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.emerald, width: 1.2),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 14, color: AppTheme.emerald),
                            SizedBox(width: 4),
                            Text(
                              'Añadir Arriba',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.emerald,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // "+ Añadir al Final" Button
                    InkWell(
                      onTap: _addSkillAtBottom,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add,
                              size: 14,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Añadir al Final',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Rating Style Selector: Círculos vs Estrellas
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF080D18) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Estilo de valoración:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildRatingStyleChoice('dots', '● Círculos', isDark),
                      const SizedBox(width: 8),
                      _buildRatingStyleChoice('stars', '★ Estrellas', isDark),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Competency Items
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No hay competencias añadidas. Pulsa "Añadir al Final" para comenzar.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  )
                else
                  ...List.generate(items.length, (i) {
                    final item = items[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF080D18) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                          width: 1.1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // 1. Reorder Arrows (Up / Down)
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF111827) : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF374151) : const Color(0xFFCBD5E1),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: i > 0 ? () => _reorderSkill(i, i - 1) : null,
                                      child: Padding(
                                        padding: const EdgeInsets.all(3.0),
                                        child: Icon(
                                          Icons.keyboard_arrow_up,
                                          size: 16,
                                          color: i > 0
                                              ? (isDark ? Colors.white70 : Colors.black87)
                                              : Colors.white24,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 14,
                                      color: isDark ? const Color(0xFF374151) : const Color(0xFFCBD5E1),
                                    ),
                                    InkWell(
                                      onTap: i < items.length - 1 ? () => _reorderSkill(i, i + 1) : null,
                                      child: Padding(
                                        padding: const EdgeInsets.all(3.0),
                                        child: Icon(
                                          Icons.keyboard_arrow_down,
                                          size: 16,
                                          color: i < items.length - 1
                                              ? (isDark ? Colors.white70 : Colors.black87)
                                              : Colors.white24,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 10),

                              // 2. Skill Name Input Field
                              Expanded(
                                child: Container(
                                  height: 38,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                      width: 1,
                                    ),
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextFormField(
                                      key: ValueKey('skill_name_${i}_${item.name}'),
                                      initialValue: item.name,
                                      textCapitalization: TextCapitalization.characters,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.4,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                        hintText: 'NOMBRE DE LA COMPETENCIA',
                                      ),
                                      onChanged: (val) => _updateSkillName(i, val.toUpperCase()),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              // 3. 5 Rating Indicators (Circles or Stars)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(5, (dotIndex) {
                                    final dotNumber = dotIndex + 1;
                                    final isFilled = dotNumber <= item.level;
                                    final isStars = widget.profile.skillRatingStyle == 'stars';

                                    if (isStars) {
                                      return GestureDetector(
                                        onTap: () => _updateSkillLevel(i, dotNumber),
                                        child: MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 1.5),
                                            child: Icon(
                                              isFilled ? Icons.star : Icons.star_border,
                                              size: 18,
                                              color: isFilled
                                                  ? const Color(0xFFF59E0B)
                                                  : (isDark ? const Color(0xFF334155) : const Color(0xFF94A3B8)),
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    return GestureDetector(
                                      onTap: () => _updateSkillLevel(i, dotNumber),
                                      child: MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isFilled
                                                ? const Color(0xFFF59E0B) // Amber yellow from Image 2
                                                : (isDark ? const Color(0xFF263348) : const Color(0xFFCBD5E1)),
                                            boxShadow: isFilled
                                                ? [
                                                    BoxShadow(
                                                      color: const Color(0xFFF59E0B).withOpacity(0.4),
                                                      blurRadius: 3,
                                                      spreadRadius: 0.5,
                                                    )
                                                  ]
                                                : null,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),

                              const SizedBox(width: 6),

                              // 4. Trash / Delete Icon
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                                tooltip: 'Eliminar',
                                onPressed: () => _deleteSkill(i),
                              ),
                            ],
                          ),

                          // Optional Subtitle/Description row for rich A4 preview
                          Padding(
                            padding: const EdgeInsets.only(left: 48, right: 40, top: 4),
                            child: TextFormField(
                              key: ValueKey('skill_desc_${i}_${item.description}'),
                              initialValue: item.description.isNotEmpty
                                  ? item.description
                                  : _getAutoDescription(item.name),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintText: 'Subtítulo breve (ej. Compañerismo y coordinación en cuadrilla)...',
                              ),
                              onChanged: (val) => _updateSkillDescription(i, val),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 5: EXPERIENCIA ---
  Widget _buildExperienciaTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Experiencia Laboral', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ElevatedButton.icon(
                onPressed: _addExperience,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Añadir Puesto'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (widget.profile.experiences.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No hay puestos registrados. Haz clic en "Añadir Puesto" para agregar uno.',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...widget.profile.experiences.asMap().entries.map((entry) {
              final idx = entry.key;
              final exp = entry.value;

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Puesto #${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            onPressed: () {
                              final list = List<CvExperience>.from(widget.profile.experiences)..removeAt(idx);
                              _update(widget.profile.copyWith(experiences: list));
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: TextEditingController(text: exp.jobTitle),
                        decoration: const InputDecoration(labelText: 'Cargo / Puesto Aspirado'),
                        onChanged: (val) {
                          final list = List<CvExperience>.from(widget.profile.experiences);
                          list[idx] = exp.copyWith(jobTitle: val);
                          _update(widget.profile.copyWith(experiences: list));
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: exp.company),
                              decoration: const InputDecoration(labelText: 'Empresa u Organismo'),
                              onChanged: (val) {
                                final list = List<CvExperience>.from(widget.profile.experiences);
                                list[idx] = exp.copyWith(company: val);
                                _update(widget.profile.copyWith(experiences: list));
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 140,
                            child: TextField(
                              controller: TextEditingController(text: exp.period),
                              decoration: const InputDecoration(labelText: 'Período (ej. 2024 - 2025)'),
                              onChanged: (val) {
                                final list = List<CvExperience>.from(widget.profile.experiences);
                                list[idx] = exp.copyWith(period: val);
                                _update(widget.profile.copyWith(experiences: list));
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: TextEditingController(text: exp.description),
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Tareas, competencias aplicadas y EPIs'),
                        onChanged: (val) {
                          final list = List<CvExperience>.from(widget.profile.experiences);
                          list[idx] = exp.copyWith(description: val);
                          _update(widget.profile.copyWith(experiences: list));
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  void _addExperience() {
    final newExp = const CvExperience(
      jobTitle: 'OPERARIO/A DE MANTENIMIENTO',
      company: 'Empresa o Ayuntamiento',
      period: '2024 - Actualidad',
      description: 'Labores de mantenimiento general, uso de herramientas mecánicas y aplicación de prevención de riesgos.',
    );
    final list = List<CvExperience>.from(widget.profile.experiences)..add(newExp);
    _update(widget.profile.copyWith(experiences: list));
  }

  // --- TAB 6: FORMACIÓN ---
  Widget _buildFormacionTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Formación y Certificaciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ElevatedButton.icon(
                onPressed: _addEducation,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Añadir Título'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (widget.profile.educations.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No hay estudios registrados.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...widget.profile.educations.asMap().entries.map((entry) {
              final idx = entry.key;
              final edu = entry.value;

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Estudio #${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            onPressed: () {
                              final list = List<CvEducation>.from(widget.profile.educations)..removeAt(idx);
                              _update(widget.profile.copyWith(educations: list));
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: TextEditingController(text: edu.degree),
                        decoration: const InputDecoration(labelText: 'Titulación / Certificado de Profesionalidad'),
                        onChanged: (val) {
                          final list = List<CvEducation>.from(widget.profile.educations);
                          list[idx] = edu.copyWith(degree: val);
                          _update(widget.profile.copyWith(educations: list));
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: edu.institution),
                              decoration: const InputDecoration(labelText: 'Centro o Institución'),
                              onChanged: (val) {
                                final list = List<CvEducation>.from(widget.profile.educations);
                                list[idx] = edu.copyWith(institution: val);
                                _update(widget.profile.copyWith(educations: list));
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 140,
                            child: TextField(
                              controller: TextEditingController(text: edu.period),
                              decoration: const InputDecoration(labelText: 'Período'),
                              onChanged: (val) {
                                final list = List<CvEducation>.from(widget.profile.educations);
                                list[idx] = edu.copyWith(period: val);
                                _update(widget.profile.copyWith(educations: list));
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: TextEditingController(text: edu.details),
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Detalles o módulos clave'),
                        onChanged: (val) {
                          final list = List<CvEducation>.from(widget.profile.educations);
                          list[idx] = edu.copyWith(details: val);
                          _update(widget.profile.copyWith(educations: list));
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  void _addEducation() {
    final newEdu = const CvEducation(
      degree: 'CERTIFICADO DE PROFESIONALIDAD (EN CURSO)',
      institution: 'Servicio Canario de Empleo',
      period: '2024 - 2025',
      details: 'Formación teórico-práctica con módulos de Competencias Clave y PRL.',
    );
    final list = List<CvEducation>.from(widget.profile.educations)..add(newEdu);
    _update(widget.profile.copyWith(educations: list));
  }

  // --- TAB 7: DISEÑO Y COLOR ---
  Widget _buildDisenoYColorTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Diseño, Colores y Marcas de Agua', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 14),

          // 1. Color de Énfasis
          const Text('Color de Énfasis Principal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              const Color(0xFF0D9488), // Teal de la captura de Andriucha
              ...AppTheme.accentOptions,
            ].map((color) {
              final hex = '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
              final isSelected = widget.profile.accentColor.toUpperCase() == hex;

              return GestureDetector(
                onTap: () => _update(widget.profile.copyWith(accentColor: hex)),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: color.withOpacity(0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),

          // 2. Marca de Agua Opcional en Zonas de Color
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161F30) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.water_drop_outlined, size: 16, color: AppTheme.emerald),
                              const SizedBox(width: 8),
                              const Text(
                                'Marca de Agua en Zonas de Color',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Ilustración sutil o textura de fondo sobre las áreas coloreadas del CV (columna lateral y cabeceras).',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: widget.profile.showWatermark,
                      activeColor: AppTheme.emerald,
                      onChanged: (val) {
                        _update(widget.profile.copyWith(showWatermark: val));
                      },
                    ),
                  ],
                ),

                if (widget.profile.showWatermark) ...[
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 10),
                  const Text(
                    'Selecciona el motivo o imagen de fondo para la zona de color:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildWatermarkOption('gears', 'Engranajes Técnicos', Icons.settings, isDark),
                      _buildWatermarkOption('tools', 'Herramientas de Oficio', Icons.build, isDark),
                      _buildWatermarkOption('geometric', 'Malla Geométrica', Icons.grid_view, isDark),
                      _buildWatermarkOption('shield', 'Escudo Profesional', Icons.security, isDark),
                      _buildWatermarkOption('lines', 'Líneas Planimétricas', Icons.line_style, isDark),
                      _buildWatermarkOption('tech_dots', 'Retícula Técnica', Icons.grain, isDark),
                      _buildWatermarkOption('custom', 'URL de Imagen', Icons.image_outlined, isDark),
                      _buildWatermarkOption('none', 'Liso (Sin Marca)', Icons.block, isDark),
                    ],
                  ),

                  // If custom watermark is chosen
                  if (widget.profile.watermarkPattern == 'custom') ...[
                    const SizedBox(height: 14),
                    const Text('URL de Imagen de Marca de Agua Personalizada:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: TextEditingController(text: widget.profile.customWatermarkUrl),
                            decoration: const InputDecoration(
                              hintText: 'https://ejemplo.com/marca-agua.png',
                              prefixIcon: Icon(Icons.link, size: 16),
                            ),
                            onChanged: (val) => _update(widget.profile.copyWith(customWatermarkUrl: val.trim())),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            // Preset sample tech texture
                            const sampleUrl = 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=500&auto=format&fit=crop&q=60';
                            _update(widget.profile.copyWith(customWatermarkUrl: sampleUrl));
                          },
                          child: const Text('Ejemplo', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Watermark Opacity & Transparency Slider (0% a 100%)
                  Row(
                    children: [
                      const Icon(Icons.opacity, size: 15, color: AppTheme.emerald),
                      const SizedBox(width: 8),
                      Text(
                        'Intensidad / Opacidad: ${(widget.profile.watermarkOpacity * 100).toInt()}%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Text(
                        'Transparencia: ${(100 - (widget.profile.watermarkOpacity * 100)).toInt()}%',
                        style: const TextStyle(fontSize: 11, color: AppTheme.emerald, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppTheme.emerald,
                      thumbColor: AppTheme.emerald,
                      overlayColor: AppTheme.emerald.withOpacity(0.2),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: widget.profile.watermarkOpacity.clamp(0.0, 1.0),
                      min: 0.0,
                      max: 1.0,
                      divisions: 100,
                      onChanged: (val) {
                        _update(widget.profile.copyWith(watermarkOpacity: val));
                      },
                    ),
                  ),

                  // Quick presets for transparency
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildPresetChip('0% Transparente', 0.0, isDark),
                      _buildPresetChip('15% Sutil', 0.15, isDark),
                      _buildPresetChip('35% Media', 0.35, isDark),
                      _buildPresetChip('60% Marcada', 0.60, isDark),
                      _buildPresetChip('85% Intensa', 0.85, isDark),
                      _buildPresetChip('100% Opaca', 1.0, isDark),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),

          // 3. Plantillas
          const Text('Tipo de Plantilla de Diseño', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: widget.profile.template,
            decoration: const InputDecoration(),
            items: const [
              DropdownMenuItem(value: 'sidebar_dark', child: Text('Columna Lateral Ejecutiva (Fondo de Énfasis Lateral con Marca)')),
              DropdownMenuItem(value: 'modern_header', child: Text('Cabecera Moderna & 2 Columnas (Banda Superior con Marca)')),
              DropdownMenuItem(value: 'minimalist', child: Text('Minimalista Clásico Centrado (Elegante y Limpio)')),
              DropdownMenuItem(value: 'tech_cards', child: Text('Tarjetas Técnicas Modulares (Bloques de Acento)')),
            ],
            onChanged: (val) {
              if (val != null) _update(widget.profile.copyWith(template: val));
            },
          ),

          const SizedBox(height: 20),

          // 4. Tipografía y Estilo de Texto
          Row(
            children: [
              const Icon(Icons.text_fields_outlined, size: 16, color: AppTheme.emerald),
              const SizedBox(width: 8),
              const Text('Tipografía y Formato de Texto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  _update(widget.profile.copyWith(
                    fontFamily: 'Inter',
                    fontSizeScale: 1.0,
                    fontSpacing: 0.2,
                    lineSpacing: 1.35,
                  ));
                },
                icon: const Icon(Icons.restart_alt, size: 14),
                label: const Text('Restablecer', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.emerald,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Google Font Selector
          DropdownButtonFormField<String>(
            value: [
              'Inter', 'Outfit', 'Roboto', 'Montserrat', 'Poppins', 
              'Merriweather', 'Raleway', 'Lora', 'Fira Code'
            ].contains(widget.profile.fontFamily)
                ? widget.profile.fontFamily
                : 'Inter',
            decoration: const InputDecoration(
              labelText: 'Familia Tipográfica (Google Fonts)',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: [
              _buildFontDropdownItem('Inter', 'Inter (Moderna y Nítida · Defecto)'),
              _buildFontDropdownItem('Outfit', 'Outfit (Geométrica Premium y Elegante)'),
              _buildFontDropdownItem('Roboto', 'Roboto (Neutral y Técnica)'),
              _buildFontDropdownItem('Montserrat', 'Montserrat (Titulares con Personalidad)'),
              _buildFontDropdownItem('Poppins', 'Poppins (Contemporánea y Redondeada)'),
              _buildFontDropdownItem('Merriweather', 'Merriweather (Serif Editorial Clásica)'),
              _buildFontDropdownItem('Raleway', 'Raleway (Fina, Sofisticada y Exclusiva)'),
              _buildFontDropdownItem('Lora', 'Lora (Serif Caligráfica Contemporánea)'),
              _buildFontDropdownItem('Fira Code', 'Fira Code (Monoespaciada de Programador)'),
            ],
            onChanged: (val) {
              if (val != null) _update(widget.profile.copyWith(fontFamily: val));
            },
          ),

          const SizedBox(height: 16),

          // Tamaño de fuente (80% a 130%)
          Row(
            children: [
              const Icon(Icons.format_size_outlined, size: 15, color: AppTheme.emerald),
              const SizedBox(width: 8),
              Text(
                'Escala de Tamaño de Fuente: ${(widget.profile.fontSizeScale * 100).round()}%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                widget.profile.fontSizeScale == 1.0 ? 'Estándar' : (widget.profile.fontSizeScale > 1.0 ? 'Grande' : 'Compacto'),
                style: const TextStyle(fontSize: 11, color: AppTheme.emerald, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.emerald,
              thumbColor: AppTheme.emerald,
              overlayColor: AppTheme.emerald.withOpacity(0.2),
              trackHeight: 3,
            ),
            child: Slider(
              value: widget.profile.fontSizeScale.clamp(0.80, 1.30),
              min: 0.80,
              max: 1.30,
              divisions: 50,
              onChanged: (val) {
                _update(widget.profile.copyWith(fontSizeScale: double.parse(val.toStringAsFixed(2))));
              },
            ),
          ),

          const SizedBox(height: 10),

          // Espaciado entre letras (-0.5px a +2.0px)
          Row(
            children: [
              const Icon(Icons.space_bar_outlined, size: 15, color: AppTheme.emerald),
              const SizedBox(width: 8),
              Text(
                'Espaciado entre Letras (Tracking): ${widget.profile.fontSpacing.toStringAsFixed(2)} px',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                widget.profile.fontSpacing > 0.5 ? 'Espaciado' : (widget.profile.fontSpacing < 0 ? 'Apretado' : 'Equilibrado'),
                style: const TextStyle(fontSize: 11, color: AppTheme.emerald, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.emerald,
              thumbColor: AppTheme.emerald,
              overlayColor: AppTheme.emerald.withOpacity(0.2),
              trackHeight: 3,
            ),
            child: Slider(
              value: widget.profile.fontSpacing.clamp(-0.5, 2.0),
              min: -0.5,
              max: 2.0,
              divisions: 50,
              onChanged: (val) {
                _update(widget.profile.copyWith(fontSpacing: double.parse(val.toStringAsFixed(2))));
              },
            ),
          ),

          const SizedBox(height: 10),

          // Interlineado (1.10x a 1.80x)
          Row(
            children: [
              const Icon(Icons.format_line_spacing_outlined, size: 15, color: AppTheme.emerald),
              const SizedBox(width: 8),
              Text(
                'Interlineado (Altura de línea): ${widget.profile.lineSpacing.toStringAsFixed(2)}x',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                widget.profile.lineSpacing > 1.45 ? 'Aireado' : (widget.profile.lineSpacing < 1.25 ? 'Denso' : 'Normal'),
                style: const TextStyle(fontSize: 11, color: AppTheme.emerald, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.emerald,
              thumbColor: AppTheme.emerald,
              overlayColor: AppTheme.emerald.withOpacity(0.2),
              trackHeight: 3,
            ),
            child: Slider(
              value: widget.profile.lineSpacing.clamp(1.10, 1.80),
              min: 1.10,
              max: 1.80,
              divisions: 70,
              onChanged: (val) {
                _update(widget.profile.copyWith(lineSpacing: double.parse(val.toStringAsFixed(2))));
              },
            ),
          ),

          const SizedBox(height: 14),

          // Live Typography Preview Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.visibility_outlined, size: 14, color: AppTheme.emerald),
                    const SizedBox(width: 6),
                    Text(
                      'Muestra en vivo: ${widget.profile.fontFamily}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.profile.fullName.isNotEmpty ? widget.profile.fullName.toUpperCase() : 'NOMBRE Y APELLIDOS',
                  style: _getSampleTextStyle(fontSize: 14.0 * widget.profile.fontSizeScale, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.profile.jobTitle.isNotEmpty ? widget.profile.jobTitle : 'Especialista en Desarrollo & Gestión Técnica',
                  style: _getSampleTextStyle(fontSize: 11.5 * widget.profile.fontSizeScale, fontWeight: FontWeight.w600, color: AppTheme.emerald),
                ),
                const SizedBox(height: 4),
                Text(
                  'Curriculum Vitae profesional optimizado con tipografía ${widget.profile.fontFamily}. A4 milimétricamente ajustado.',
                  style: _getSampleTextStyle(fontSize: 10.0 * widget.profile.fontSizeScale, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DropdownMenuItem<String> _buildFontDropdownItem(String fontName, String label) {
    return DropdownMenuItem<String>(
      value: fontName,
      child: Text(
        label,
        style: GoogleFonts.getFont(fontName, fontSize: 12),
      ),
    );
  }

  TextStyle _getSampleTextStyle({
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
  }) {
    try {
      return GoogleFonts.getFont(
        widget.profile.fontFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: widget.profile.fontSpacing,
        height: widget.profile.lineSpacing,
      );
    } catch (_) {
      return TextStyle(
        fontFamily: widget.profile.fontFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: widget.profile.fontSpacing,
        height: widget.profile.lineSpacing,
      );
    }
  }

  Widget _buildTabPill(IconData icon, String text, int index, bool isDark) {
    final isSelected = _tabController.index == index;

    return Tab(
      height: 36,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF132A26) : const Color(0xFFE6F4EA))
              : (isDark ? const Color(0xFF161F30) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.emerald
                : (isDark ? const Color(0xFF334155).withOpacity(0.6) : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppTheme.emerald.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppTheme.emerald : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 11.5,
                color: isSelected
                    ? AppTheme.emerald
                    : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatermarkOption(String key, String label, IconData icon, bool isDark) {
    final isSelected = widget.profile.watermarkPattern == key;

    return InkWell(
      onTap: () => _update(widget.profile.copyWith(watermarkPattern: key)),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.emerald.withOpacity(0.18)
              : (isDark ? AppTheme.darkInput : AppTheme.lightInput),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.emerald : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? AppTheme.emerald : Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.emerald : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, double val, bool isDark) {
    final isSelected = (widget.profile.watermarkOpacity - val).abs() < 0.05;
    return InkWell(
      onTap: () => _update(widget.profile.copyWith(watermarkOpacity: val)),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.emerald.withOpacity(0.2) : (isDark ? AppTheme.darkInput : AppTheme.lightInput),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.emerald : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppTheme.emerald : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }
}
