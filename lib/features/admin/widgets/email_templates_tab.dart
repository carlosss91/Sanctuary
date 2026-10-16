import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../data/services/api_service.dart';

class EmailTemplatesTab extends StatefulWidget {
  final ApiService apiService;
  final bool isDark;

  const EmailTemplatesTab({
    super.key,
    required this.apiService,
    required this.isDark,
  });

  @override
  State<EmailTemplatesTab> createState() => _EmailTemplatesTabState();
}

class _EmailTemplatesTabState extends State<EmailTemplatesTab> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSendingTest = false;
  String? _statusMessage;
  bool _isStatusError = false;

  // Selected template key: 'activation', 'suspension', 'announcement'
  String _selectedTemplate = 'activation';

  // Templates dictionary
  Map<String, dynamic> _templates = {};

  // Controllers for editing the active template
  final TextEditingController _subjectCtrl = TextEditingController();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _bodyCtrl = TextEditingController();
  final TextEditingController _ctaTextCtrl = TextEditingController();
  final TextEditingController _footerCtrl = TextEditingController();
  final TextEditingController _testTargetEmailCtrl = TextEditingController();

  String _currentTheme = 'dark'; // 'dark' or 'light'
  bool _currentAnimated = true;
  int _currentCometCount = 1; // 0 = off, 1 = subtle/recommended, 2 = balanced, 3 = dynamic
  int _currentCometFrequency = 1; // 1 = relaxed/calm, 2 = balanced, 3 = fast
  String _previewMode = 'canvas'; // 'canvas' or 'gif'

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _loadTemplates();
  }

  @override
  void dispose() {
    _animController.dispose();
    _subjectCtrl.dispose();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _ctaTextCtrl.dispose();
    _footerCtrl.dispose();
    _testTargetEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);
    final res = await widget.apiService.getEmailTemplates();
    if (mounted) {
      setState(() {
        _templates = (res['templates'] as Map<String, dynamic>?) ?? {};
        _syncControllersWithTemplate(_selectedTemplate);
        _isLoading = false;
      });
    }
  }

  void _syncControllersWithTemplate(String key) {
    final t = (_templates[key] as Map<String, dynamic>?) ?? {};
    _subjectCtrl.text = t['subject']?.toString() ?? '';
    _titleCtrl.text = t['title']?.toString() ?? '';
    _bodyCtrl.text = t['body']?.toString() ?? '';
    _ctaTextCtrl.text = t['ctaText']?.toString() ?? '';
    _footerCtrl.text = t['footerNote']?.toString() ?? '';
    _currentTheme = t['theme']?.toString() == 'light' ? 'light' : 'dark';
    _currentAnimated = t['animated'] != false;
    _currentCometCount = (t['cometCount'] as num?)?.toInt() ?? 1;
    _currentCometFrequency = (t['cometFrequency'] as num?)?.toInt() ?? 1;
  }

  void _updateActiveTemplateState() {
    if (!_templates.containsKey(_selectedTemplate)) {
      _templates[_selectedTemplate] = {};
    }
    _templates[_selectedTemplate]['subject'] = _subjectCtrl.text;
    _templates[_selectedTemplate]['title'] = _titleCtrl.text;
    _templates[_selectedTemplate]['body'] = _bodyCtrl.text;
    _templates[_selectedTemplate]['ctaText'] = _ctaTextCtrl.text;
    _templates[_selectedTemplate]['footerNote'] = _footerCtrl.text;
    _templates[_selectedTemplate]['theme'] = _currentTheme;
    _templates[_selectedTemplate]['animated'] = _currentAnimated;
    _templates[_selectedTemplate]['cometCount'] = _currentCometCount;
    _templates[_selectedTemplate]['cometFrequency'] = _currentCometFrequency;
    setState(() {});
  }

  Future<void> _saveAllTemplates() async {
    _updateActiveTemplateState();
    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });

    final res = await widget.apiService.saveEmailTemplates(_templates);
    if (mounted) {
      setState(() {
        _isSaving = false;
        _statusMessage = res['message'] ?? (res['success'] == true ? 'Plantillas guardadas con éxito' : 'Error al guardar');
        _isStatusError = res['success'] != true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_statusMessage!),
          backgroundColor: _isStatusError ? Colors.redAccent : const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _sendTestEmail() async {
    final target = _testTargetEmailCtrl.text.trim();
    if (target.isEmpty || !target.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor introduce un correo válido para la prueba'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _updateActiveTemplateState();
    setState(() {
      _isSendingTest = true;
      _statusMessage = null;
    });

    final res = await widget.apiService.sendTemplateEmail(
      to: target,
      templateType: _selectedTemplate,
      customFields: {
        'theme': _currentTheme,
        'animated': _currentAnimated,
        'cometCount': _currentCometCount,
        'cometFrequency': _currentCometFrequency,
        'subject': _subjectCtrl.text,
        'title': _titleCtrl.text,
        'body': _bodyCtrl.text,
        'ctaText': _ctaTextCtrl.text,
        'footerNote': _footerCtrl.text,
        'fullName': 'Carlos Santana (Tester)',
        'username': 'tester_admin',
        'code': '849201',
      },
    );

    if (mounted) {
      setState(() {
        _isSendingTest = false;
        _statusMessage = res['message'] ?? (res['success'] == true ? 'Correo enviado con éxito' : 'Error al enviar');
        _isStatusError = res['success'] != true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_statusMessage!),
          backgroundColor: _isStatusError ? Colors.redAccent : const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _restoreDefaults() {
    setState(() {
      if (_selectedTemplate == 'activation') {
        _subjectCtrl.text = 'Activa tu cuenta en Sanctuary 🪐';
        _titleCtrl.text = '¡Te damos la bienvenida a bordo!';
        _bodyCtrl.text = 'Hola {name}, tu cuenta en Sanctuary está prácticamente lista. Para garantizar la seguridad de tu identidad y activar todas tus herramientas digitales, introduce este código en la aplicación o pulsa el botón inferior:';
        _ctaTextCtrl.text = '✔ Activar Mi Cuenta Ahora';
        _footerCtrl.text = '🔒 Este enlace de activación es único y válido durante 24 horas.\nSi no te has registrado en Sanctuary, puedes desestimar este mensaje de forma segura.';
      } else if (_selectedTemplate == 'suspension') {
        _subjectCtrl.text = 'Aviso de Suspensión de Cuenta · Sanctuary ⚠️';
        _titleCtrl.text = 'Tu cuenta ha sido suspendida';
        _bodyCtrl.text = 'Hola {name},\n\nTe notificamos que el acceso a tu cuenta en Sanctuary Suite (@{username}) ha sido restringido por un administrador del sistema por motivos de moderación o seguridad.';
        _ctaTextCtrl.text = 'Contactar con Soporte';
        _footerCtrl.text = 'Si consideras que esta medida es un error o deseas solicitar una revisión, puedes responder directamente a este correo.';
      } else if (_selectedTemplate == 'announcement') {
        _subjectCtrl.text = 'Novedades y Anuncios · Sanctuary Suite 🪐';
        _titleCtrl.text = 'Comunicado Oficial de la Plataforma';
        _bodyCtrl.text = 'Estimado/a {name},\n\nNos complace compartir contigo las últimas novedades, actualizaciones docentes y herramientas añadidas al ecosistema Sanctuary Suite (CV Maker, Firmador PDF y Descargador de Presentaciones).';
        _ctaTextCtrl.text = 'Explorar la Plataforma';
        _footerCtrl.text = 'Sanctuary Suite © 2026 · Portal Docente, CV Maker interactivo & Digital Signer';
      } else {
        // ai_sentinel
        _subjectCtrl.text = 'Alerta AI Sentinel: Nuevas Convocatorias Oficiales · Sanctuary 🪐';
        _titleCtrl.text = 'AI Sentinel: Vigilancia Oficial Automatizada';
        _bodyCtrl.text = 'El motor inteligente AI Sentinel ha detectado nuevas convocatorias, resoluciones y publicaciones oficiales docentes en el BOC y BOE con alta relevancia para tu perfil:';
        _ctaTextCtrl.text = 'Ver Convocatorias en el Hub';
        _footerCtrl.text = 'Este boletín es generado de forma automatizada por el motor AI Sentinel con asistencia de Google Gemini Pro.\nPuedes ajustar la frecuencia de escaneo y los filtros geográficos desde el panel docente de Sanctuary.';
      }
      _currentTheme = 'dark';
      _currentAnimated = true;
      _updateActiveTemplateState();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDark = widget.isDark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1100;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
          _buildHeaderBanner(isDark),
          const SizedBox(height: 20),

          // Template Type Selector
          _buildTemplateSelector(isDark),
          const SizedBox(height: 24),

          // Main Layout: Split into Controls and Live Preview
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: _buildControlsCard(isDark)),
                const SizedBox(width: 24),
                Expanded(flex: 5, child: _buildPreviewCard(isDark)),
              ],
            )
          else ...[
            _buildControlsCard(isDark),
            const SizedBox(height: 24),
            _buildPreviewCard(isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF06B6D4)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.auto_awesome, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Diseño y Plantillas de Correo Cósmicas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                      ),
                      child: const Text(
                        'Brevo SMTP Activo',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Configura la estética visual con estrellas y cometas, paleta clara/oscura, animación cósmica y textos según el tipo de comunicación.',
                  style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveAllTemplates,
            icon: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(_isSaving ? 'Guardando...' : 'Guardar Todo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateSelector(bool isDark) {
    final templatesList = [
      {'key': 'activation', 'label': 'Activación de Cuenta', 'icon': Icons.verified_user_outlined, 'color': const Color(0xFF10B981)},
      {'key': 'suspension', 'label': 'Suspensión / Baneo', 'icon': Icons.gavel_rounded, 'color': const Color(0xFFEF4444)},
      {'key': 'announcement', 'label': 'Boletín / Noticia', 'icon': Icons.campaign_rounded, 'color': const Color(0xFF06B6D4)},
      {'key': 'ai_sentinel', 'label': 'AI Sentinel (Convocatorias)', 'icon': Icons.radar_rounded, 'color': const Color(0xFF8B5CF6)},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: templatesList.map((t) {
        final isSelected = _selectedTemplate == t['key'];
        final color = t['color'] as Color;
        return InkWell(
          onTap: () {
            _updateActiveTemplateState();
            setState(() {
              _selectedTemplate = t['key'] as String;
              _syncControllersWithTemplate(_selectedTemplate);
            });
          },
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withOpacity(isDark ? 0.2 : 0.12)
                  : (isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? color : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                width: isSelected ? 1.8 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(t['icon'] as IconData, size: 18, color: isSelected ? color : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                const SizedBox(width: 8),
                Text(
                  t['label'] as String,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? color : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildControlsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Personalización de Parámetros',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              TextButton.icon(
                onPressed: _restoreDefaults,
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: const Text('Restablecer'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Theme & Animation Toggles
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Theme Mode Selector
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Paleta de Color',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 6),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'dark', label: Text('Oscuro', style: TextStyle(fontSize: 11.5)), icon: Icon(Icons.dark_mode, size: 15)),
                              ButtonSegment(value: 'light', label: Text('Claro', style: TextStyle(fontSize: 11.5)), icon: Icon(Icons.light_mode, size: 15)),
                            ],
                            selected: {_currentTheme},
                            onSelectionChanged: (newVal) {
                              setState(() {
                                _currentTheme = newVal.first;
                                _updateActiveTemplateState();
                              });
                            },
                            style: ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Cosmic Animation Toggle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Animación Cósmica',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _currentAnimated = !_currentAnimated;
                                _updateActiveTemplateState();
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: _currentAnimated
                                    ? const Color(0xFF10B981).withOpacity(0.14)
                                    : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _currentAnimated ? const Color(0xFF10B981).withOpacity(0.5) : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _currentAnimated ? Icons.stars_rounded : Icons.star_border_rounded,
                                    size: 18,
                                    color: _currentAnimated ? const Color(0xFF10B981) : Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _currentAnimated ? 'Cometas & Estrellas' : 'Estrellas fijas',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _currentAnimated ? const Color(0xFF10B981) : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_currentAnimated) ...[
                  const SizedBox(height: 14),
                  Divider(color: isDark ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFE2E8F0), height: 1),
                  const SizedBox(height: 12),

                  // Slider 1: Cantidad de Cometas
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 15, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 6),
                          Text(
                            'Cantidad de Cometas',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                        ),
                        child: Text(
                          _getCometCountLabel(_currentCometCount),
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFFF59E0B),
                      thumbColor: const Color(0xFFF59E0B),
                      overlayColor: const Color(0xFFF59E0B).withOpacity(0.2),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: _currentCometCount.toDouble(),
                      min: 0,
                      max: 4,
                      divisions: 4,
                      onChanged: (val) {
                        setState(() {
                          _currentCometCount = val.round();
                          _updateActiveTemplateState();
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Slider 2: Frecuencia / Ritmo de Aparición
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.speed_rounded, size: 15, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 6),
                          Text(
                            'Frecuencia y Ritmo',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3)),
                        ),
                        child: Text(
                          _getCometFrequencyLabel(_currentCometFrequency),
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF38BDF8),
                      thumbColor: const Color(0xFF38BDF8),
                      overlayColor: const Color(0xFF38BDF8).withOpacity(0.2),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: _currentCometFrequency.toDouble(),
                      min: 1,
                      max: 3,
                      divisions: 2,
                      onChanged: (val) {
                        setState(() {
                          _currentCometFrequency = val.round();
                          _updateActiveTemplateState();
                        });
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Subject Field
          _buildTextField(
            controller: _subjectCtrl,
            label: 'Asunto del Correo',
            icon: Icons.subject_rounded,
            isDark: isDark,
            onChanged: (_) => _updateActiveTemplateState(),
          ),
          const SizedBox(height: 14),

          // Title / Headline Field
          _buildTextField(
            controller: _titleCtrl,
            label: 'Titular / Encabezado Principal',
            icon: Icons.title_rounded,
            isDark: isDark,
            onChanged: (_) => _updateActiveTemplateState(),
          ),
          const SizedBox(height: 14),

          // Body Message Field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cuerpo del Mensaje',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                    ),
                  ),
                  Wrap(
                    spacing: 4,
                    children: [
                      _buildVariableChip('{name}', isDark),
                      _buildVariableChip('{username}', isDark),
                      if (_selectedTemplate == 'activation') _buildVariableChip('{code}', isDark),
                      if (_selectedTemplate == 'ai_sentinel') ...[
                        _buildVariableChip('{place}', isDark),
                        _buildVariableChip('{count}', isDark),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _bodyCtrl,
                maxLines: 4,
                onChanged: (_) => _updateActiveTemplateState(),
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Introduce el mensaje principal del correo...',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B).withOpacity(0.6) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.6)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // CTA Button Label
          _buildTextField(
            controller: _ctaTextCtrl,
            label: 'Texto del Botón de Acción (CTA)',
            icon: Icons.touch_app_rounded,
            isDark: isDark,
            onChanged: (_) => _updateActiveTemplateState(),
          ),
          const SizedBox(height: 14),

          // Footer / Security Note
          _buildTextField(
            controller: _footerCtrl,
            label: 'Nota al Pie / Advertencia',
            icon: Icons.security_rounded,
            isDark: isDark,
            maxLines: 2,
            onChanged: (_) => _updateActiveTemplateState(),
          ),
          const SizedBox(height: 22),

          // Direct Live Test Email Dispatcher
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4).withOpacity(isDark ? 0.08 : 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.send_rounded, size: 16, color: Color(0xFF06B6D4)),
                    const SizedBox(width: 8),
                    const Text(
                      'Enviar Prueba Real a Bandeja de Entrada',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Dispara esta plantilla con los ajustes actuales directamente por SMTP hacia tu correo.',
                  style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _testTargetEmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'ejemplo@gmail.com',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF06B6D4))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: const Color(0xFF06B6D4).withOpacity(0.4))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _isSendingTest ? null : _sendTestEmail,
                      icon: _isSendingTest
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.mark_email_read_outlined, size: 16),
                      label: const Text('Enviar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF06B6D4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            prefixIcon: maxLines == 1 ? Icon(icon, size: 18, color: const Color(0xFF64748B)) : null,
            filled: true,
            isDense: maxLines == 1,
            fillColor: isDark ? const Color(0xFF1E293B).withOpacity(0.6) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.6)),
          ),
        ),
      ],
    );
  }

  Widget _buildVariableChip(String variable, bool isDark) {
    return InkWell(
      onTap: () {
        _bodyCtrl.text = '${_bodyCtrl.text} $variable';
        _updateActiveTemplateState();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
        ),
        child: Text(
          variable,
          style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
        ),
      ),
    );
  }

  // --- COSMIC CONFIGURATION LABELS & HELPERS ---
  String _getCometCountLabel(int count) {
    switch (count) {
      case 0:
        return '0 · Desactivado (Solo estrellas)';
      case 1:
        return '1 · Sutil (Recomendado)';
      case 2:
        return '2 · Equilibrado';
      case 3:
        return '3 · Dinámico';
      case 4:
        return '4 · Lluvia Cósmica';
      default:
        return '$count cometas';
    }
  }

  String _getCometFrequencyLabel(int freq) {
    switch (freq) {
      case 1:
        return '1 · Pausado y Relajado (Recomendado)';
      case 2:
        return '2 · Cadencia Normal';
      case 3:
        return '3 · Frecuente / Dinámico';
      default:
        return '$freq';
    }
  }

  void _showCosmicRenderingInfoDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.hub_outlined, color: Color(0xFF10B981), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Arquitectura de Entrega Dual',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Cómo Sanctuary garantiza 100% de compatibilidad visual',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoItem(
                  icon: Icons.shield_outlined,
                  color: const Color(0xFFF59E0B),
                  title: '¿Por qué webmail como Gmail no admite Canvas o CSS @keyframes?',
                  description:
                      'Los clientes de correo líderes (Gmail, Outlook.com, Yahoo) despojan el código JavaScript, Canvas y animaciones CSS avanzadas por directivas de seguridad contra phishing. Si solo se enviaran animaciones CSS, en Gmail el fondo aparecería completamente inmóvil y estático.',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildInfoItem(
                  icon: Icons.gif_box_outlined,
                  color: const Color(0xFF10B981),
                  title: '🌌 Solución Sanctuary: Motor Universal GIF (~30 - 47 KB)',
                  description:
                      'Para que el 100% de los usuarios reciban un fondo vivo con estrellas titilantes y cometas majestuosos, Sanctuary compila un tapiz GIF astronómico cuantizado y sin bucles bruscos. Es compatible universalmente, no calienta la CPU/GPU del móvil y pesa menos que una imagen normal.',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildInfoItem(
                  icon: Icons.brush_outlined,
                  color: const Color(0xFF38BDF8),
                  title: '🔮 Motor Vectorial Pro (Canvas / CSS3 a 60 FPS)',
                  description:
                      'En clientes avanzados (como Apple Mail) o dentro de la propia plataforma de Sanctuary, el sistema despliega el motor vectorial fluido a 60 FPS con estelas lumínicas y nebulosas volumétricas.',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildInfoItem(
                  icon: Icons.tune_rounded,
                  color: const Color(0xFFA78BFA),
                  title: '✨ Control de Ritmo y Cero Sobrecarga Visual',
                  description:
                      'Con los nuevos deslizadores de Cantidad y Frecuencia, el fondo cósmico se mantiene sereno, espacioso y elegante: una bóveda estrellada con cometas ocasionales que deleitan sin cansar la vista ni ralentizar el sistema.',
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGifSimulationBackground(bool previewIsDark) {
    final skyUrl = previewIsDark
        ? 'https://raw.githubusercontent.com/carlosss91/Sanctuary/main/web/assets/cosmic-sky-dark.gif'
        : 'https://raw.githubusercontent.com/carlosss91/Sanctuary/main/web/assets/cosmic-sky-light.gif';
    final bannerUrl = previewIsDark
        ? 'https://raw.githubusercontent.com/carlosss91/Sanctuary/main/web/assets/cosmic-banner-dark.gif'
        : 'https://raw.githubusercontent.com/carlosss91/Sanctuary/main/web/assets/cosmic-banner-light.gif';
    final sideUrl = previewIsDark
        ? 'https://raw.githubusercontent.com/carlosss91/Sanctuary/main/web/assets/cosmic-side-dark.gif'
        : 'https://raw.githubusercontent.com/carlosss91/Sanctuary/main/web/assets/cosmic-side-light.gif';

    return Stack(
      children: [
        // 1. Tiled / Fitted GIF Starfield
        Positioned.fill(
          child: Image.network(
            skyUrl,
            fit: BoxFit.cover,
            repeat: ImageRepeat.repeat,
            errorBuilder: (_, __, ___) => Container(
              color: previewIsDark ? const Color(0xFF05080E) : const Color(0xFFD6E4F0),
            ),
          ),
        ),

        // 2. Side Ambient Cosmic Columns (flanking the card)
        if (_currentAnimated) ...[
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 50,
            child: Opacity(
              opacity: 0.65,
              child: Image.network(
                sideUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 50,
            child: Opacity(
              opacity: 0.65,
              child: Image.network(
                sideUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ],

        // 3. Top Majestic Canopy Comet Banner (if cometCount >= 1)
        if (_currentAnimated && _currentCometCount > 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 75,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Image.network(
                  bannerUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),

        // 4. Bottom Canopy Comet Banner (if cometCount >= 2)
        if (_currentAnimated && _currentCometCount > 1)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 75,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Transform.flip(
                  flipY: true,
                  child: Image.network(
                    bannerUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // --- INTERACTIVE COSMIC EMAIL LIVE PREVIEW ---
  Widget _buildPreviewCard(bool isDark) {
    final previewIsDark = _currentTheme == 'dark';
    final isSuspension = _selectedTemplate == 'suspension';
    final isAnnouncement = _selectedTemplate == 'announcement';
    final isAiSentinel = _selectedTemplate == 'ai_sentinel';

    // Theme tokens for preview
    final previewBg = previewIsDark ? const Color(0xFF05080E) : const Color(0xFFD6E4F0);
    final cardBg = previewIsDark ? const Color(0xFF0C1322) : Colors.white;
    final cardBorder = previewIsDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1);
    final textColor = previewIsDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = previewIsDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final primaryAccent = isSuspension
        ? const Color(0xFFEF4444)
        : (isAnnouncement
            ? const Color(0xFF0891B2)
            : (isAiSentinel ? const Color(0xFF8B5CF6) : const Color(0xFF10B981)));
    final codeBoxBg = previewIsDark ? const Color(0xFF080E1A) : const Color(0xFFF1F5F9);

    final titleText = _titleCtrl.text.isNotEmpty ? _titleCtrl.text : 'Título del Correo';
    final bodyText = _bodyCtrl.text.isNotEmpty
        ? _bodyCtrl.text
            .replaceAll('{name}', 'Carlos Santana')
            .replaceAll('{username}', 'carlos_test')
            .replaceAll('{code}', '849201')
            .replaceAll('{place}', 'Canarias')
            .replaceAll('{count}', '2')
        : 'Cuerpo del mensaje...';
    final ctaText = _ctaTextCtrl.text.isNotEmpty ? _ctaTextCtrl.text : 'Botón de Acción';
    final footerText = _footerCtrl.text.isNotEmpty ? _footerCtrl.text : '';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Dual-Engine switcher, info button and theme badge
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Text(
                    'Vista Previa en Tiempo Real',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Engine Toggle: Canvas Pro vs GIF Universal
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'canvas',
                        label: Text('🔮 Canvas Pro', style: TextStyle(fontSize: 11)),
                      ),
                      ButtonSegment(
                        value: 'gif',
                        label: Text('🌌 GIF Universal', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                    selected: {_previewMode},
                    onSelectionChanged: (val) {
                      setState(() {
                        _previewMode = val.first;
                      });
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Info Button for Dual Engine Explanation
                  Tooltip(
                    message: '¿Por qué hay 2 motores de renderizado?',
                    child: InkWell(
                      onTap: () => _showCosmicRenderingInfoDialog(context, isDark),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF10B981)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Theme badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: (previewIsDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      previewIsDark ? '🌙 Oscuro' : '☀️ Claro',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: previewIsDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Cosmic Live Preview Frame
          AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              return Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: previewBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cardBorder),
                ),
                child: Stack(
                  children: [
                    // Dynamic Engine Background (Canvas Pro or Universal GIF Simulation)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _previewMode == 'canvas'
                            ? CustomPaint(
                                painter: CosmicEmailPreviewPainter(
                                  progress: _currentAnimated ? _animController.value : 0.0,
                                  isDark: previewIsDark,
                                  isSuspension: isSuspension,
                                  isAiSentinel: isAiSentinel,
                                  isAnimated: _currentAnimated,
                                  cometCount: _currentCometCount,
                                  cometFrequency: _currentCometFrequency,
                                ),
                              )
                            : _buildGifSimulationBackground(previewIsDark),
                      ),
                    ),

                    // Engine Watermark / Status Badge
                    Positioned(
                      top: 10,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _previewMode == 'canvas' ? Icons.brush_outlined : Icons.gif_box_outlined,
                              size: 11,
                              color: _previewMode == 'canvas' ? const Color(0xFF38BDF8) : const Color(0xFF10B981),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _previewMode == 'canvas'
                                  ? 'Motor Vectorial Pro (Canvas 60fps)'
                                  : 'Motor Universal (GIF ~47KB · Gmail)',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: _previewMode == 'canvas' ? const Color(0xFF38BDF8) : const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Centered Email Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Container(
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: cardBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(previewIsDark ? 0.6 : 0.08),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Top Accent Iridescent Bar
                                Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                                    gradient: isSuspension
                                        ? const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFF59E0B)])
                                        : (isAnnouncement
                                            ? const LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF3B82F6), Color(0xFF8B5CF6)])
                                            : (isAiSentinel
                                                ? const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6), Color(0xFF06B6D4)])
                                                : const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF06B6D4), Color(0xFF3B82F6)]))),
                                  ),
                                ),

                                // Planetary Logo Header
                                Padding(
                                  padding: const EdgeInsets.only(top: 24, bottom: 12),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          gradient: RadialGradient(
                                            center: const Alignment(-0.3, -0.3),
                                            colors: isSuspension
                                                ? [const Color(0xFFEF4444), const Color(0xFF7F1D1D)]
                                                : (isAnnouncement
                                                    ? [const Color(0xFF06B6D4), const Color(0xFF0E7490)]
                                                    : (isAiSentinel
                                                        ? [const Color(0xFF8B5CF6), const Color(0xFF4C1D95)]
                                                        : [const Color(0xFF10B981), const Color(0xFF064E3B)])),
                                          ),
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: primaryAccent.withOpacity(0.4),
                                              blurRadius: 18,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: Image.network(
                                            'https://raw.githubusercontent.com/carlosss91/Sanctuary/main/web/assets/icon-192.png',
                                            width: 52,
                                            height: 52,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Center(
                                              child: Text(
                                                isSuspension ? '⚠️' : (isAnnouncement ? '📢' : (isAiSentinel ? '🛰️' : '🪐')),
                                                style: const TextStyle(fontSize: 26),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'SANCTUARY',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 2,
                                          color: textColor,
                                        ),
                                      ),
                                      Text(
                                        isAiSentinel ? '🛰️ AI SENTINEL · VIGILANCIA OFICIAL' : 'PLATFORM · DIGITAL SUITE',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5,
                                          color: primaryAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Card Content
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                                  child: Column(
                                    children: [
                                      Text(
                                        titleText,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        bodyText,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.55,
                                          color: subtextColor,
                                        ),
                                      ),

                                      // PIN Box for Activation
                                      if (_selectedTemplate == 'activation') ...[
                                        const SizedBox(height: 16),
                                        Container(
                                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                          decoration: BoxDecoration(
                                            color: codeBoxBg,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: primaryAccent.withOpacity(0.7)),
                                            boxShadow: [
                                              BoxShadow(
                                                color: primaryAccent.withOpacity(0.15),
                                                blurRadius: 12,
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                'CÓDIGO DE VERIFICACIÓN',
                                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: subtextColor),
                                              ),
                                              const SizedBox(height: 4),
                                              const Text(
                                                '8 4 9 2 0 1',
                                                style: TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 6,
                                                  color: Color(0xFF10B981),
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],

                                      // AI Sentinel Convocatorias Sample List
                                      if (isAiSentinel) ...[
                                        const SizedBox(height: 14),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: previewIsDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: cardBorder),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF10B981).withOpacity(0.18),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                                                    ),
                                                    child: const Text('BOC', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF8B5CF6).withOpacity(0.18),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
                                                    ),
                                                    child: const Text('📍 Canarias', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFA78BFA))),
                                                  ),
                                                  const Spacer(),
                                                  Text('BOC Nº 198 · 15/10/2026', style: TextStyle(fontSize: 9, color: subtextColor)),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Consejería de Educación: Convocatoria extraordinaria listas de empleo secundaria.',
                                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: textColor),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Apertura del plazo para especialidades docentes con baremación exprés y habilitación.',
                                                style: TextStyle(fontSize: 10, height: 1.4, color: subtextColor),
                                              ),
                                              const SizedBox(height: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF8B5CF6).withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: const Border(left: BorderSide(color: Color(0xFF8B5CF6), width: 3)),
                                                ),
                                                child: const Text(
                                                  '🤖 Análisis Gemini: Alta prioridad para interinos. Plazo de 10 días hábiles.',
                                                  style: TextStyle(fontSize: 9.5, color: Color(0xFFA78BFA)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                      ],

                                      // CTA Button
                                      const SizedBox(height: 18),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: primaryAccent,
                                          gradient: isSuspension
                                              ? const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)])
                                              : (isAnnouncement
                                                  ? const LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF0891B2)])
                                                  : (isAiSentinel
                                                      ? const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)])
                                                      : const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]))),
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                              color: primaryAccent.withOpacity(0.35),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          ctaText,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),

                                      if (footerText.isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        Text(
                                          footerText,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            height: 1.4,
                                            color: subtextColor.withOpacity(0.85),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 18),
                                    ],
                                  ),
                                ),

                                // Footer Band
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: previewIsDark ? const Color(0xFF070C16) : const Color(0xFFF8FAFC),
                                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                                    border: Border(top: BorderSide(color: cardBorder)),
                                  ),
                                  child: Text(
                                    'Sanctuary Suite © 2026 · Diseñado con precisión cósmica',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: subtextColor.withOpacity(0.7),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Custom Painter for the Interactive Cosmic Email Preview Canvas with Full-Canvas Starfield & Configurable Shooting Comets
class CosmicEmailPreviewPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final bool isSuspension;
  final bool isAiSentinel;
  final bool isAnimated;
  final int cometCount;
  final int cometFrequency;

  CosmicEmailPreviewPainter({
    required this.progress,
    required this.isDark,
    required this.isSuspension,
    this.isAiSentinel = false,
    required this.isAnimated,
    this.cometCount = 1,
    this.cometFrequency = 1,
  });

  // Pre-calculated deterministic celestial distribution spanning all quadrants
  static final List<Offset> _denseStars = [
    // Top Sky
    const Offset(0.04, 0.04), const Offset(0.12, 0.07), const Offset(0.19, 0.03),
    const Offset(0.27, 0.09), const Offset(0.34, 0.04), const Offset(0.42, 0.08),
    const Offset(0.50, 0.03), const Offset(0.58, 0.07), const Offset(0.66, 0.04),
    const Offset(0.74, 0.09), const Offset(0.81, 0.03), const Offset(0.89, 0.07),
    const Offset(0.96, 0.05), const Offset(0.08, 0.13), const Offset(0.23, 0.15),
    const Offset(0.38, 0.12), const Offset(0.62, 0.14), const Offset(0.77, 0.12),
    const Offset(0.92, 0.14),

    // Left Flank
    const Offset(0.03, 0.22), const Offset(0.09, 0.26), const Offset(0.04, 0.32),
    const Offset(0.11, 0.38), const Offset(0.02, 0.44), const Offset(0.08, 0.49),
    const Offset(0.03, 0.55), const Offset(0.10, 0.60), const Offset(0.04, 0.66),
    const Offset(0.09, 0.72), const Offset(0.02, 0.77), const Offset(0.08, 0.82),
    const Offset(0.04, 0.88), const Offset(0.11, 0.93),

    // Right Flank
    const Offset(0.96, 0.22), const Offset(0.91, 0.26), const Offset(0.97, 0.32),
    const Offset(0.90, 0.38), const Offset(0.98, 0.44), const Offset(0.92, 0.49),
    const Offset(0.97, 0.55), const Offset(0.90, 0.60), const Offset(0.96, 0.66),
    const Offset(0.91, 0.72), const Offset(0.98, 0.77), const Offset(0.92, 0.82),
    const Offset(0.96, 0.88), const Offset(0.89, 0.93),

    // Bottom Sky
    const Offset(0.05, 0.96), const Offset(0.14, 0.97), const Offset(0.22, 0.95),
    const Offset(0.31, 0.98), const Offset(0.40, 0.95), const Offset(0.48, 0.97),
    const Offset(0.55, 0.95), const Offset(0.64, 0.98), const Offset(0.72, 0.95),
    const Offset(0.80, 0.97), const Offset(0.88, 0.95), const Offset(0.95, 0.97),
    const Offset(0.18, 0.91), const Offset(0.35, 0.92), const Offset(0.65, 0.92),
    const Offset(0.82, 0.91),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Nebulae Glow Auras
    final aura1Paint = Paint()
      ..shader = RadialGradient(
        colors: isDark
            ? [const Color(0xFF10B981).withOpacity(0.15), Colors.transparent]
            : [const Color(0xFF10B981).withOpacity(0.08), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.15, size.height * 0.15), radius: 140));
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.15), 140, aura1Paint);

    final aura2Paint = Paint()
      ..shader = RadialGradient(
        colors: isDark
            ? [(isAiSentinel ? const Color(0xFF8B5CF6) : const Color(0xFF06B6D4)).withOpacity(0.16), Colors.transparent]
            : [(isAiSentinel ? const Color(0xFF8B5CF6) : const Color(0xFF06B6D4)).withOpacity(0.08), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.85, size.height * 0.20), radius: 150));
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.20), 150, aura2Paint);

    final aura3Paint = Paint()
      ..shader = RadialGradient(
        colors: isDark
            ? [const Color(0xFF3B82F6).withOpacity(0.12), Colors.transparent]
            : [const Color(0xFF3B82F6).withOpacity(0.06), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.50, size.height * 0.90), radius: 160));
    canvas.drawCircle(Offset(size.width * 0.50, size.height * 0.90), 160, aura3Paint);

    // 2. Dense Celestial Starfield Across the Whole Canvas
    for (int i = 0; i < _denseStars.length; i++) {
      final p = _denseStars[i];
      final pos = Offset(p.dx * size.width, p.dy * size.height);
      final double twinkle = isAnimated
          ? (0.35 + 0.65 * math.sin(progress * math.pi * 2 + i * 1.35).abs())
          : 0.85;

      Color starColor;
      final mod = i % 5;
      if (mod == 0) {
        starColor = isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706); // Amber
      } else if (mod == 1) {
        starColor = isDark ? Colors.white : const Color(0xFF0284C7); // Diamond
      } else if (mod == 2) {
        starColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7); // Sapphire
      } else if (mod == 3) {
        starColor = isDark ? const Color(0xFF10B981) : const Color(0xFF059669); // Emerald
      } else {
        starColor = isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED); // Violet
      }

      final radius = (i % 3 == 0) ? 2.4 : ((i % 2 == 0) ? 1.8 : 1.2);

      // Subtle halo for prominent stars
      if (radius > 2.0) {
        final haloPaint = Paint()..color = starColor.withOpacity(twinkle * (isDark ? 0.35 : 0.2));
        canvas.drawCircle(pos, radius * 2.2, haloPaint);
      }

      final starPaint = Paint()..color = starColor.withOpacity(twinkle.clamp(0.2, 1.0));
      canvas.drawCircle(pos, radius, starPaint);
    }

    // 3. Dynamic Shooting Comets (Respecting cometCount & cometFrequency)
    if (isAnimated && cometCount > 0) {
      // Frequency multiplier: 1 = calm / long pause (0.75), 2 = balanced (1.0), 3 = dynamic (1.35)
      final freqMult = cometFrequency == 1 ? 0.75 : (cometFrequency == 2 ? 1.0 : 1.35);

      // Comet 1 (Subtle / Recommended): Sweeps majestically across the upper horizon
      if (cometCount >= 1) {
        final c1Raw = (progress * 1.1 * freqMult) % 1.0;
        // Calm astronomical pause: visible only for 45% of cycle
        if (c1Raw < 0.45) {
          final norm = c1Raw / 0.45;
          final startX = -60.0 + norm * (size.width + 160);
          final startY = 16.0 + norm * (size.height * 0.32);
          final endX = startX - 75;
          final endY = startY - 24;

          final cometPaint = Paint()
            ..shader = uiGradient(
              from: Offset(startX, startY),
              to: Offset(endX, endY),
              colors: [Colors.white, const Color(0xFF38BDF8).withOpacity(0.85), Colors.transparent],
            )
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round;

          canvas.drawLine(Offset(startX, startY), Offset(endX, endY), cometPaint);
          canvas.drawCircle(Offset(startX, startY), 3.2, Paint()..color = Colors.white);
        }
      }

      // Comet 2 (Balanced): Warm amber comet sweeping across the lower horizon
      if (cometCount >= 2) {
        final c2Raw = ((progress + 0.52) * 0.95 * freqMult) % 1.0;
        if (c2Raw < 0.42) {
          final norm = c2Raw / 0.42;
          final startX = size.width + 60 - norm * (size.width + 160);
          final startY = size.height * 0.65 + norm * (size.height * 0.28);
          final endX = startX + 70;
          final endY = startY - 22;

          final comet2Paint = Paint()
            ..shader = uiGradient(
              from: Offset(startX, startY),
              to: Offset(endX, endY),
              colors: [const Color(0xFFFDE68A), const Color(0xFFF59E0B).withOpacity(0.8), Colors.transparent],
            )
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round;

          canvas.drawLine(Offset(startX, startY), Offset(endX, endY), comet2Paint);
          canvas.drawCircle(Offset(startX, startY), 2.8, Paint()..color = const Color(0xFFFDE68A));
        }
      }

      // Comet 3 (Dynamic): Emerald / Violet comet along the top-right
      if (cometCount >= 3) {
        final c3Raw = ((progress + 0.25) * 1.3 * freqMult) % 1.0;
        if (c3Raw < 0.38) {
          final norm = c3Raw / 0.38;
          final startX = size.width * 0.15 + norm * (size.width * 0.85);
          final startY = 10.0 + norm * 40.0;
          final endX = startX - 55;
          final endY = startY - 15;

          final comet3Paint = Paint()
            ..shader = uiGradient(
              from: Offset(startX, startY),
              to: Offset(endX, endY),
              colors: [
                Colors.white,
                (isAiSentinel ? const Color(0xFFA78BFA) : const Color(0xFF10B981)).withOpacity(0.8),
                Colors.transparent
              ],
            )
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round;

          canvas.drawLine(Offset(startX, startY), Offset(endX, endY), comet3Paint);
          canvas.drawCircle(Offset(startX, startY), 2.5, Paint()..color = Colors.white);
        }
      }

      // Comet 4 (Meteor Shower): Diagonal comet across the lower sky
      if (cometCount >= 4) {
        final c4Raw = ((progress + 0.78) * 1.2 * freqMult) % 1.0;
        if (c4Raw < 0.40) {
          final norm = c4Raw / 0.40;
          final startX = -30.0 + norm * (size.width + 100);
          final startY = size.height * 0.78 + norm * (size.height * 0.18);
          final endX = startX - 60;
          final endY = startY - 18;

          final comet4Paint = Paint()
            ..shader = uiGradient(
              from: Offset(startX, startY),
              to: Offset(endX, endY),
              colors: [Colors.white, const Color(0xFFEC4899).withOpacity(0.75), Colors.transparent],
            )
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round;

          canvas.drawLine(Offset(startX, startY), Offset(endX, endY), comet4Paint);
          canvas.drawCircle(Offset(startX, startY), 2.5, Paint()..color = Colors.white);
        }
      }
    } else if (!isAnimated && cometCount > 0) {
      // Static decorative single comet
      final comet1 = Paint()
        ..shader = uiGradient(
          from: Offset(size.width * 0.26, size.height * 0.09),
          to: Offset(size.width * 0.16, size.height * 0.04),
          colors: [Colors.white, const Color(0xFF38BDF8).withOpacity(0.75), Colors.transparent],
        )
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(size.width * 0.26, size.height * 0.09), Offset(size.width * 0.16, size.height * 0.04), comet1);
      canvas.drawCircle(Offset(size.width * 0.26, size.height * 0.09), 2.8, Paint()..color = Colors.white);
    }
  }

  Shader uiGradient({required Offset from, required Offset to, required List<Color> colors}) {
    return LinearGradient(colors: colors).createShader(Rect.fromPoints(from, to));
  }

  @override
  bool shouldRepaint(covariant CosmicEmailPreviewPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.isSuspension != isSuspension ||
        oldDelegate.isAiSentinel != isAiSentinel ||
        oldDelegate.isAnimated != isAnimated ||
        oldDelegate.cometCount != cometCount ||
        oldDelegate.cometFrequency != cometFrequency;
  }
}

