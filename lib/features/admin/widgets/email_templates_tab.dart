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
  String _currentAnimationType = 'comets'; // 'comets', 'nebula', 'blackhole', 'fixed'
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
    final animType = t['animationType']?.toString();
    if (animType != null && animType.isNotEmpty) {
      _currentAnimationType = animType;
      _currentAnimated = animType != 'fixed';
    } else {
      _currentAnimated = t['animated'] != false;
      _currentAnimationType = _currentAnimated ? 'comets' : 'fixed';
    }
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
    _templates[_selectedTemplate]['animated'] = _currentAnimationType != 'fixed';
    _templates[_selectedTemplate]['animationType'] = _currentAnimationType;
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
        'animationType': _currentAnimationType,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 680;

        final logoWidget = Container(
          width: isNarrow ? 46 : 52,
          height: isNarrow ? 46 : 52,
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
          child: Center(
            child: Icon(Icons.auto_awesome, color: Colors.white, size: isNarrow ? 24 : 28),
          ),
        );

        final badgeWidget = Container(
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
        );

        final saveBtn = SizedBox(
          width: isNarrow ? double.infinity : null,
          child: ElevatedButton.icon(
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
        );

        if (isNarrow) {
          return Container(
            padding: const EdgeInsets.all(18),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    logoWidget,
                    badgeWidget,
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Diseño y Plantillas de Correo Cósmicas',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Configura la estética visual con estrellas y cometas, paleta clara/oscura, animación cósmica y textos según el tipo de comunicación.',
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                saveBtn,
              ],
            ),
          );
        }

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
              logoWidget,
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
                        badgeWidget,
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
              saveBtn,
            ],
          ),
        );
      },
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
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
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
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
                // 1. PALETA DE COLOR (Texto siempre horizontal)
                const Text(
                  'Paleta de Color',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildThemeOption(
                        title: 'Modo Oscuro',
                        icon: Icons.dark_mode_rounded,
                        isSelected: _currentTheme == 'dark',
                        isDark: isDark,
                        onTap: () {
                          setState(() {
                            _currentTheme = 'dark';
                            _updateActiveTemplateState();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildThemeOption(
                        title: 'Modo Claro',
                        icon: Icons.light_mode_rounded,
                        isSelected: _currentTheme == 'light',
                        isDark: isDark,
                        onTap: () {
                          setState(() {
                            _currentTheme = 'light';
                            _updateActiveTemplateState();
                          });
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Divider(color: isDark ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFE2E8F0), height: 1),
                const SizedBox(height: 14),

                // 2. ESTILO DE ANIMACIÓN CÓSMICA
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Animación Cósmica',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getAnimationTypeBadge(_currentAnimationType),
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, animConstraints) {
                    final isSmall = animConstraints.maxWidth < 420;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildAnimationCard(
                          keyId: 'comets',
                          title: 'Cometas & Estrellas',
                          icon: Icons.auto_awesome,
                          accentColor: const Color(0xFFF59E0B),
                          isDark: isDark,
                          width: isSmall ? animConstraints.maxWidth : (animConstraints.maxWidth - 8) / 2,
                        ),
                        _buildAnimationCard(
                          keyId: 'nebula',
                          title: 'Nebulosa Cósmica',
                          icon: Icons.grain_rounded,
                          accentColor: const Color(0xFF8B5CF6),
                          isDark: isDark,
                          width: isSmall ? animConstraints.maxWidth : (animConstraints.maxWidth - 8) / 2,
                        ),
                        _buildAnimationCard(
                          keyId: 'blackhole',
                          title: 'Agujero Negro & Vórtice',
                          icon: Icons.radio_button_checked_rounded,
                          accentColor: const Color(0xFF06B6D4),
                          isDark: isDark,
                          width: isSmall ? animConstraints.maxWidth : (animConstraints.maxWidth - 8) / 2,
                        ),
                        _buildAnimationCard(
                          keyId: 'fixed',
                          title: 'Estrellas Fijas',
                          icon: Icons.star_border_rounded,
                          accentColor: const Color(0xFF94A3B8),
                          isDark: isDark,
                          width: isSmall ? animConstraints.maxWidth : (animConstraints.maxWidth - 8) / 2,
                        ),
                      ],
                    );
                  },
                ),

                // Homogenized Cosmic Animation Controls (Cometas, Nebulosa, Agujero Negro)
                if (_currentAnimationType != 'fixed') ...[
                  const SizedBox(height: 14),
                  Divider(color: isDark ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFE2E8F0), height: 1),
                  const SizedBox(height: 12),

                  // Slider 1: Cantidad / Densidad
                  Builder(
                    builder: (context) {
                      Color accent;
                      IconData icon;
                      String title;
                      if (_currentAnimationType == 'nebula') {
                        accent = const Color(0xFF8B5CF6);
                        icon = Icons.grain_rounded;
                        title = 'Densidad y Capas de Nebulosa';
                      } else if (_currentAnimationType == 'blackhole') {
                        accent = const Color(0xFF06B6D4);
                        icon = Icons.radio_button_checked_rounded;
                        title = 'Densidad de Materia y Disco';
                      } else {
                        accent = const Color(0xFFF59E0B);
                        icon = Icons.auto_awesome;
                        title = 'Cantidad de Cometas';
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(icon, size: 15, color: accent),
                                  const SizedBox(width: 6),
                                  Text(
                                    title,
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
                                  color: accent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: accent.withOpacity(0.3)),
                                ),
                                child: Text(
                                  _getAnimationCountLabel(_currentAnimationType, _currentCometCount),
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: accent),
                                ),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: accent,
                              thumbColor: accent,
                              overlayColor: accent.withOpacity(0.2),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: _currentCometCount.toDouble().clamp(0.0, 4.0),
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
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 6),

                  // Slider 2: Frecuencia y Ritmo / Velocidad
                  Builder(
                    builder: (context) {
                      Color freqAccent;
                      IconData freqIcon;
                      String freqTitle;
                      if (_currentAnimationType == 'nebula') {
                        freqAccent = const Color(0xFFEC4899);
                        freqIcon = Icons.all_inclusive_rounded;
                        freqTitle = 'Ritmo y Pulsación Cósmica';
                      } else if (_currentAnimationType == 'blackhole') {
                        freqAccent = const Color(0xFF38BDF8);
                        freqIcon = Icons.rotate_right_rounded;
                        freqTitle = 'Velocidad de Giro del Vórtice';
                      } else {
                        freqAccent = const Color(0xFF38BDF8);
                        freqIcon = Icons.speed_rounded;
                        freqTitle = 'Frecuencia y Ritmo';
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(freqIcon, size: 15, color: freqAccent),
                                  const SizedBox(width: 6),
                                  Text(
                                    freqTitle,
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
                                  color: freqAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: freqAccent.withOpacity(0.3)),
                                ),
                                child: Text(
                                  _getAnimationFrequencyLabel(_currentAnimationType, _currentCometFrequency),
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: freqAccent),
                                ),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: freqAccent,
                              thumbColor: freqAccent,
                              overlayColor: freqAccent.withOpacity(0.2),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: _currentCometFrequency.toDouble().clamp(1.0, 3.0),
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
                      );
                    },
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  Text(
                    '✨ Modo de bajo consumo: estrellas fijas con centelleo tranquilo sin movimiento de cometas o vórtices.',
                    style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
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
  String _getAnimationTypeBadge(String type) {
    switch (type) {
      case 'nebula':
        return 'NEBULOSA ACTIVA';
      case 'blackhole':
        return 'AGUJERO NEGRO';
      case 'fixed':
        return 'ESTRELLAS FIJAS';
      case 'comets':
      default:
        return 'COMETAS ACTIVOS';
    }
  }

  Widget _buildThemeOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF10B981).withOpacity(0.16)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? const Color(0xFF10B981) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            const SizedBox(width: 7),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? const Color(0xFF10B981) : (isDark ? Colors.white : const Color(0xFF1E293B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimationCard({
    required String keyId,
    required String title,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    required double width,
  }) {
    final isSelected = _currentAnimationType == keyId;
    return InkWell(
      onTap: () {
        setState(() {
          _currentAnimationType = keyId;
          _currentAnimated = keyId != 'fixed';
          _updateActiveTemplateState();
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withOpacity(isDark ? 0.20 : 0.12)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? accentColor : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? accentColor : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? accentColor : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, size: 14, color: accentColor),
          ],
        ),
      ),
    );
  }
  String _getAnimationCountLabel(String type, int count) {
    if (type == 'nebula') {
      switch (count) {
        case 0:
          return '0 · Desactivado (Estrellas puras)';
        case 1:
          return '1 · Nube Sutil (Recomendado)';
        case 2:
          return '2 · Nebulosa Bicolor';
        case 3:
          return '3 · Manto Tricolor Denso';
        case 4:
          return '4 · Tormenta Cósmica Masiva';
        default:
          return '$count capas';
      }
    } else if (type == 'blackhole') {
      switch (count) {
        case 0:
          return '0 · Singularidad Silenciosa';
        case 1:
          return '1 · Vórtice Sutil (3 corrientes)';
        case 2:
          return '2 · Disco Activo (6 corrientes)';
        case 3:
          return '3 · Acreción Intensa (9 corrientes)';
        case 4:
          return '4 · Cuásar Relativista (12 corrientes)';
        default:
          return '$count niveles';
      }
    } else {
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
  }

  String _getAnimationFrequencyLabel(String type, int freq) {
    if (type == 'nebula') {
      switch (freq) {
        case 1:
          return '1 · Pulso Lento y Relajado';
        case 2:
          return '2 · Expansión Rítmica Normal';
        case 3:
          return '3 · Mareas Estelares Dinámicas';
        default:
          return '$freq';
      }
    } else if (type == 'blackhole') {
      switch (freq) {
        case 1:
          return '1 · Rotación Relajada';
        case 2:
          return '2 · Giro Equilibrado';
        case 3:
          return '3 · Vórtice Ultrarrápido';
        default:
          return '$freq';
      }
    } else {
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
  }

  String _getCometCountLabel(int count) => _getAnimationCountLabel('comets', count);

  String _getCometFrequencyLabel(int freq) => _getAnimationFrequencyLabel('comets', freq);

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
    String skyName = previewIsDark ? 'cosmic-sky-dark.gif' : 'cosmic-sky-light.gif';
    String bannerName = previewIsDark ? 'cosmic-banner-dark.gif' : 'cosmic-banner-light.gif';
    String sideName = previewIsDark ? 'cosmic-side-dark.gif' : 'cosmic-side-light.gif';

    if (_currentAnimationType == 'nebula') {
      skyName = previewIsDark ? 'nebula-sky-dark.gif' : 'nebula-sky-light.gif';
      bannerName = previewIsDark ? 'nebula-banner-dark.gif' : 'nebula-banner-light.gif';
      sideName = previewIsDark ? 'nebula-side-dark.gif' : 'nebula-side-light.gif';
    } else if (_currentAnimationType == 'blackhole') {
      skyName = previewIsDark ? 'blackhole-sky-dark.gif' : 'blackhole-sky-light.gif';
      bannerName = previewIsDark ? 'blackhole-banner-dark.gif' : 'blackhole-banner-light.gif';
      sideName = previewIsDark ? 'blackhole-side-dark.gif' : 'blackhole-side-light.gif';
    }

    final skyUrl = 'https://raw.githubusercontent.com/carlosss91/Sanctuary/main/web/assets/$skyName';
    final bannerUrl = 'https://raw.githubusercontent.com/carlosss91/Sanctuary/main/web/assets/$bannerName';
    final sideUrl = 'https://raw.githubusercontent.com/carlosss91/Sanctuary/main/web/assets/$sideName';

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
          // Responsive Header with Dual-Engine switcher, info button and theme badge
          LayoutBuilder(
            builder: (context, headerConstraints) {
              final isNarrow = headerConstraints.maxWidth < 620;

              final themeBadge = Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (previewIsDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: previewIsDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      previewIsDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      size: 13,
                      color: previewIsDark ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      previewIsDark ? '🌙 Modo Oscuro' : '☀️ Modo Claro',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: previewIsDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              );

              final engineControls = Row(
                mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Flexible(
                    fit: isNarrow ? FlexFit.tight : FlexFit.loose,
                    child: SegmentedButton<String>(
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
                  ),
                  const SizedBox(width: 8),
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
                  if (!isNarrow) ...[
                    const SizedBox(width: 8),
                    themeBadge,
                  ],
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        Text(
                          'Vista Previa en Tiempo Real',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    engineControls,
                    const SizedBox(height: 8),
                    // Theme badge placed cleanly underneath the engine controls on mobile
                    themeBadge,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  engineControls,
                ],
              );
            },
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
                                  animationType: _currentAnimationType,
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

// Custom Painter for the Interactive Cosmic Email Preview Canvas with Full-Canvas Starfield & Configurable Space Animations
class CosmicEmailPreviewPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final bool isSuspension;
  final bool isAiSentinel;
  final bool isAnimated;
  final String animationType;
  final int cometCount;
  final int cometFrequency;

  CosmicEmailPreviewPainter({
    required this.progress,
    required this.isDark,
    required this.isSuspension,
    this.isAiSentinel = false,
    required this.isAnimated,
    this.animationType = 'comets',
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
    final bool enableTwinkle = isAnimated && animationType != 'fixed';
    for (int i = 0; i < _denseStars.length; i++) {
      final p = _denseStars[i];
      final pos = Offset(p.dx * size.width, p.dy * size.height);
      final double twinkle = enableTwinkle
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

    // 3. Dynamic Space Animations based on animationType
    if (animationType == 'nebula') {
      _drawNebula(canvas, size);
    } else if (animationType == 'blackhole') {
      _drawBlackHole(canvas, size);
    } else if (animationType == 'comets') {
      _drawComets(canvas, size);
    }
    // 'fixed': Serene fixed celestial starfield without motion trails
  }

  // --- NEBULA COSMICA: Organic drifting interstellar clouds & stardust ---
  void _drawNebula(Canvas canvas, Size size) {
    // If count == 0, keep quiet starry background with minimal stardust
    if (!isAnimated || cometCount <= 0) return;

    // Frequency multiplier: 1 = calm / slow pulse (0.6), 2 = balanced (1.0), 3 = dynamic (1.8)
    final freqMult = cometFrequency == 1 ? 0.6 : (cometFrequency == 2 ? 1.0 : 1.8);

    // Oscillating pulse dynamics modulated by frequency
    final pulse1 = 1.0 + 0.16 * math.sin(progress * 2 * math.pi * freqMult);
    final pulse2 = 1.0 + 0.18 * math.cos(progress * 2 * math.pi * 1.2 * freqMult);
    final pulse3 = 1.0 + 0.14 * math.sin(progress * 2 * math.pi * 0.85 * freqMult + 1.0);
    final pulseCore = 1.0 + 0.20 * math.sin(progress * 2 * math.pi * 1.5 * freqMult + 0.5);

    // Nebula 1: Ethereal Violet / Magenta Gas Cloud (Upper Left Flank) - activated at cometCount >= 1
    if (cometCount >= 1) {
      final c1 = Offset(size.width * 0.18, size.height * 0.22);
      final r1 = (110.0 * pulse1).clamp(60.0, 210.0);
      final alphaMult = cometCount == 1 ? 0.75 : 1.0;
      final paint1 = Paint()
        ..shader = RadialGradient(
          colors: isDark
              ? [
                  const Color(0xFF8B5CF6).withOpacity(0.32 * alphaMult),
                  const Color(0xFFEC4899).withOpacity(0.18 * alphaMult),
                  const Color(0xFF3B82F6).withOpacity(0.06 * alphaMult),
                  Colors.transparent,
                ]
              : [
                  const Color(0xFF8B5CF6).withOpacity(0.18 * alphaMult),
                  const Color(0xFFEC4899).withOpacity(0.10 * alphaMult),
                  Colors.transparent,
                ],
          stops: const [0.0, 0.45, 0.75, 1.0],
        ).createShader(Rect.fromCircle(center: c1, radius: r1));
      canvas.drawCircle(c1, r1, paint1);
    }

    // Nebula 2: Glowing Emerald / Cyan Interstellar Cloud (Lower Right Flank) - activated at cometCount >= 2
    if (cometCount >= 2) {
      final c2 = Offset(size.width * 0.82, size.height * 0.76);
      final r2 = (125.0 * pulse2).clamp(70.0, 230.0);
      final paint2 = Paint()
        ..shader = RadialGradient(
          colors: isDark
              ? [
                  const Color(0xFF10B981).withOpacity(0.30),
                  const Color(0xFF06B6D4).withOpacity(0.18),
                  const Color(0xFF0284C7).withOpacity(0.06),
                  Colors.transparent,
                ]
              : [
                  const Color(0xFF10B981).withOpacity(0.16),
                  const Color(0xFF06B6D4).withOpacity(0.10),
                  Colors.transparent,
                ],
          stops: const [0.0, 0.45, 0.75, 1.0],
        ).createShader(Rect.fromCircle(center: c2, radius: r2));
      canvas.drawCircle(c2, r2, paint2);
    }

    // Nebula 3: Deep Stellar Blue / Indigo Cloud (Top Center Horizon) - activated at cometCount >= 3
    if (cometCount >= 3) {
      final c3 = Offset(size.width * 0.52, size.height * 0.10);
      final r3 = (95.0 * pulse3).clamp(50.0, 190.0);
      final paint3 = Paint()
        ..shader = RadialGradient(
          colors: isDark
              ? [
                  const Color(0xFF3B82F6).withOpacity(0.28),
                  const Color(0xFF6366F1).withOpacity(0.15),
                  Colors.transparent,
                ]
              : [
                  const Color(0xFF3B82F6).withOpacity(0.14),
                  const Color(0xFF6366F1).withOpacity(0.08),
                  Colors.transparent,
                ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c3, radius: r3));
      canvas.drawCircle(c3, r3, paint3);
    }

    // Nebula 4: Hyper-Stellar Amber/Gold Heart (Central Zenith Glow) - activated at cometCount >= 4
    if (cometCount >= 4) {
      final c4 = Offset(size.width * 0.35, size.height * 0.50);
      final r4 = (140.0 * pulseCore).clamp(75.0, 240.0);
      final paint4 = Paint()
        ..shader = RadialGradient(
          colors: isDark
              ? [
                  const Color(0xFFF59E0B).withOpacity(0.22),
                  const Color(0xFF8B5CF6).withOpacity(0.12),
                  Colors.transparent,
                ]
              : [
                  const Color(0xFFF59E0B).withOpacity(0.12),
                  Colors.transparent,
                ],
          stops: const [0.0, 0.50, 1.0],
        ).createShader(Rect.fromCircle(center: c4, radius: r4));
      canvas.drawCircle(c4, r4, paint4);
    }

    // Floating Stardust Particles drifting along cosmic currents (scaled by cometCount)
    final stardustCount = cometCount * 5; // 5, 10, 15, 20 stardust particles
    final c1 = Offset(size.width * 0.18, size.height * 0.22);
    final c2 = Offset(size.width * 0.82, size.height * 0.76);
    for (int i = 0; i < stardustCount; i++) {
      final angle = (progress * 2 * math.pi * freqMult) + (i * (2 * math.pi / stardustCount));
      final orbitR = 30.0 + (i % 4) * 22.0;
      final center = (i % 2 == 0) ? c1 : c2;
      final pPos = Offset(
        center.dx + math.cos(angle) * orbitR,
        center.dy + math.sin(angle) * orbitR * 0.65,
      );
      final dustPaint = Paint()
        ..color = (i % 3 == 0
                ? const Color(0xFF38BDF8)
                : (i % 3 == 1 ? const Color(0xFFF472B6) : const Color(0xFF34D399)))
            .withOpacity((0.35 + 0.45 * math.sin(angle)).clamp(0.15, 0.85));
      canvas.drawCircle(pPos, (i % 2 == 0) ? 1.6 : 1.1, dustPaint);
    }
  }

  // --- AGUJERO NEGRO & VORTICE: Gravitational vortex, relativistic accretion disk & photon ring ---
  void _drawBlackHole(Canvas canvas, Size size) {
    final bhCenter = Offset(
      size.width > 500 ? size.width * 0.82 : size.width * 0.76,
      size.width > 500 ? size.height * 0.20 : 54.0,
    );

    // Speed multiplier from cometFrequency: 1 = slow rotation (0.6), 2 = balanced (1.0), 3 = relativistic warp (2.0)
    final freqMult = cometFrequency == 1 ? 0.6 : (cometFrequency == 2 ? 1.0 : 2.0);

    // Size / Intensity scaling from cometCount (0 = dormant singularity, 4 = quasar level)
    final countMult = cometCount / 4.0; // 0.0 to 1.0

    // 1. Gravitational Lensing Outer Halo (Deep spacetime distortion glow)
    final lensRadius = 60.0 + cometCount * 7.0;
    final lensPaint = Paint()
      ..shader = RadialGradient(
        colors: isDark
            ? [
                const Color(0xFF8B5CF6).withOpacity((0.20 + 0.20 * countMult).clamp(0.1, 0.45)),
                const Color(0xFF06B6D4).withOpacity((0.10 + 0.15 * countMult).clamp(0.05, 0.3)),
                const Color(0xFFF59E0B).withOpacity((0.05 + 0.10 * countMult).clamp(0.0, 0.2)),
                Colors.transparent,
              ]
            : [
                const Color(0xFF6366F1).withOpacity((0.12 + 0.12 * countMult).clamp(0.05, 0.25)),
                const Color(0xFF0284C7).withOpacity(0.08),
                Colors.transparent,
              ],
        stops: const [0.0, 0.45, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: bhCenter, radius: lensRadius));
    canvas.drawCircle(bhCenter, lensRadius, lensPaint);

    // 2. Relativistic Rotating Accretion Disk (Slanted elliptical plasma disk)
    canvas.save();
    canvas.translate(bhCenter.dx, bhCenter.dy);
    // Slant disk to 22 degrees and flatten into relativistic perspective
    canvas.rotate(-0.35);
    canvas.scale(1.0, 0.38);

    // Spinning plasma rays / spiral accretion streams modulated by freqMult
    final diskRot = isAnimated ? (progress * 2 * math.pi * freqMult) : 0.0;
    canvas.rotate(diskRot);

    final diskRadius = 40.0 + cometCount * 7.0;
    final strokeWidth = (14.0 + cometCount * 2.5).clamp(12.0, 24.0);
    final diskCenterRadius = 26.0 + cometCount * 3.0;

    final plasmaPaint = Paint()
      ..shader = SweepGradient(
        colors: const [
          Color(0xFFF59E0B), // Radiant Amber
          Color(0xFFDC2626), // Relativistic Crimson
          Color(0xFF8B5CF6), // Purple redshift
          Color(0xFF38BDF8), // Cyan blueshift
          Color(0xFFF59E0B), // Radiant Amber
        ],
        stops: const [0.0, 0.28, 0.55, 0.82, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: diskRadius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawCircle(Offset.zero, diskCenterRadius, plasmaPaint);

    // Accretion Disk Highlights / Bright Relativistic Beaming
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: diskCenterRadius),
      0.0,
      math.pi * 0.75,
      false,
      highlightPaint,
    );

    canvas.restore();

    // 3. Photon Sphere Ring (Intense luminous razor-sharp aura)
    final photonRadius = 15.0 + cometCount * 0.8;
    final photonPaint = Paint()
      ..color = const Color(0xFF38BDF8).withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawCircle(bhCenter, photonRadius, photonPaint);

    final photonGlow = Paint()
      ..color = Colors.white.withOpacity(0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(bhCenter, photonRadius - 0.8, photonGlow);

    // 4. The Event Horizon (Pitch-black absolute singularity)
    final horizonRadius = photonRadius - 1.5;
    final horizonPaint = Paint()
      ..color = const Color(0xFF030712)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(bhCenter, horizonRadius, horizonPaint);

    // 5. Infalling Matter Streams (Vortices spiraling in, modulated by cometCount and freqMult)
    if (isAnimated && cometCount > 0) {
      final numStreams = cometCount * 3; // 3, 6, 9, 12 streams
      for (int i = 0; i < numStreams; i++) {
        final streamProgress = (progress * freqMult + (i / numStreams.toDouble())) % 1.0;
        final spiralAngle = diskRot + (i * (2 * math.pi / numStreams)) + (streamProgress * 2 * math.pi);
        final spiralDist = horizonRadius + 2.0 + (1.0 - streamProgress) * (diskRadius - horizonRadius);
        final p = Offset(
          bhCenter.dx + math.cos(spiralAngle) * spiralDist,
          bhCenter.dy + math.sin(spiralAngle) * spiralDist * 0.42,
        );
        final particlePaint = Paint()
          ..color = (i % 2 == 0 ? const Color(0xFFFDE68A) : const Color(0xFF67E8F9))
              .withOpacity((streamProgress * 0.9).clamp(0.1, 0.9));
        canvas.drawCircle(p, 1.8 * streamProgress + 0.6, particlePaint);
      }
    }
  }

  // --- COMETAS Y ESTRELLAS: Sweeping luminous shooting comets ---
  void _drawComets(Canvas canvas, Size size) {
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
        oldDelegate.animationType != animationType ||
        oldDelegate.cometCount != cometCount ||
        oldDelegate.cometFrequency != cometFrequency;
  }
}

