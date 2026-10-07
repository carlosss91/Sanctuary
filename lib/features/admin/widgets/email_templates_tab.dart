import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
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
      } else {
        _subjectCtrl.text = 'Novedades y Anuncios · Sanctuary Suite 🪐';
        _titleCtrl.text = 'Comunicado Oficial de la Plataforma';
        _bodyCtrl.text = 'Estimado/a {name},\n\nNos complace compartir contigo las últimas novedades, actualizaciones docentes y herramientas añadidas al ecosistema Sanctuary Suite (CV Maker, Firmador PDF y Descargador de Presentaciones).';
        _ctaTextCtrl.text = 'Explorar la Plataforma';
        _footerCtrl.text = 'Sanctuary Suite © 2026 · Portal Docente, CV Maker interactivo & Digital Signer';
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
                style: TextButton.styleTo(foregroundColor: const Color(0xFF64748B)),
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
            child: Row(
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

  // --- INTERACTIVE COSMIC EMAIL LIVE PREVIEW ---
  Widget _buildPreviewCard(bool isDark) {
    final previewIsDark = _currentTheme == 'dark';
    final isSuspension = _selectedTemplate == 'suspension';

    // Theme tokens for preview
    final previewBg = previewIsDark ? const Color(0xFF05080E) : const Color(0xFFE8EEF5);
    final cardBg = previewIsDark ? const Color(0xFF0C1322) : Colors.white;
    final cardBorder = previewIsDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1);
    final textColor = previewIsDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = previewIsDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final primaryAccent = isSuspension ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    final codeBoxBg = previewIsDark ? const Color(0xFF080E1A) : const Color(0xFFF1F5F9);

    final titleText = _titleCtrl.text.isNotEmpty ? _titleCtrl.text : 'Título del Correo';
    final bodyText = _bodyCtrl.text.isNotEmpty
        ? _bodyCtrl.text
            .replaceAll('{name}', 'Carlos Santana')
            .replaceAll('{username}', 'carlos_test')
            .replaceAll('{code}', '849201')
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (previewIsDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  previewIsDark ? '🌙 Tema Oscuro' : '☀️ Tema Claro',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: previewIsDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
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
                    // Celestial Background Canvas with Stars & Comets
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: CustomPaint(
                          painter: CosmicEmailPreviewPainter(
                            progress: _currentAnimated ? _animController.value : 0.0,
                            isDark: previewIsDark,
                            isSuspension: isSuspension,
                            isAnimated: _currentAnimated,
                          ),
                        ),
                      ),
                    ),

                    // Centered Email Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
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
                                        : const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF06B6D4), Color(0xFF3B82F6)]),
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
                                                : [const Color(0xFF10B981), const Color(0xFF064E3B)],
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
                                        child: Center(
                                          child: Text(
                                            isSuspension ? '⚠️' : '🪐',
                                            style: const TextStyle(fontSize: 26),
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
                                        'PLATFORM · DIGITAL SUITE',
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

                                      // CTA Button
                                      const SizedBox(height: 18),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        decoration: BoxDecoration(
                                          gradient: isSuspension
                                              ? const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)])
                                              : const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
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

// Custom Painter for the Interactive Cosmic Email Preview Canvas
class CosmicEmailPreviewPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final bool isSuspension;
  final bool isAnimated;

  CosmicEmailPreviewPainter({
    required this.progress,
    required this.isDark,
    required this.isSuspension,
    required this.isAnimated,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Nebulae Glow Auras
    final aura1Paint = Paint()
      ..shader = RadialGradient(
        colors: isDark
            ? [const Color(0xFF10B981).withOpacity(0.18), Colors.transparent]
            : [const Color(0xFF10B981).withOpacity(0.10), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.15, size.height * 0.18), radius: 130));
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.18), 130, aura1Paint);

    final aura2Paint = Paint()
      ..shader = RadialGradient(
        colors: isDark
            ? [const Color(0xFF06B6D4).withOpacity(0.18), Colors.transparent]
            : [const Color(0xFF06B6D4).withOpacity(0.10), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.85, size.height * 0.25), radius: 150));
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.25), 150, aura2Paint);

    // 2. Fixed & Twinkling Stars
    final starPoints = [
      const Offset(0.08, 0.08),
      const Offset(0.22, 0.05),
      const Offset(0.78, 0.06),
      const Offset(0.92, 0.10),
      const Offset(0.05, 0.35),
      const Offset(0.95, 0.40),
      const Offset(0.06, 0.65),
      const Offset(0.94, 0.70),
      const Offset(0.12, 0.90),
      const Offset(0.85, 0.92),
      const Offset(0.50, 0.03),
      const Offset(0.50, 0.97),
    ];

    for (int i = 0; i < starPoints.length; i++) {
      final p = starPoints[i];
      final pos = Offset(p.dx * size.width, p.dy * size.height);
      final double twinkle = isAnimated
          ? (0.4 + 0.6 * math.sin(progress * math.pi * 2 + i * 1.3).abs())
          : 0.8;

      Color starColor;
      if (i % 3 == 0) {
        starColor = const Color(0xFFF59E0B); // Amber
      } else if (i % 3 == 1) {
        starColor = isDark ? Colors.white : const Color(0xFF0284C7); // White / Blue
      } else {
        starColor = const Color(0xFF38BDF8); // Sapphire
      }

      final starPaint = Paint()..color = starColor.withOpacity(twinkle.clamp(0.2, 1.0));
      final radius = (i % 2 == 0) ? 2.2 : 1.5;
      canvas.drawCircle(pos, radius, starPaint);
    }

    // 3. Shooting Comets
    if (isAnimated) {
      // Comet 1: Left to Right across top space
      final c1Progress = (progress * 1.5) % 1.0;
      if (c1Progress < 0.6) {
        final norm = c1Progress / 0.6;
        final startX = -40.0 + norm * (size.width + 100);
        final startY = 20.0 + norm * (size.height * 0.5);
        final endX = startX - 60;
        final endY = startY - 35;

        final cometPaint = Paint()
          ..shader = uiGradient(
            from: Offset(startX, startY),
            to: Offset(endX, endY),
            colors: [Colors.white, const Color(0xFF10B981).withOpacity(0.8), Colors.transparent],
          )
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(Offset(startX, startY), Offset(endX, endY), cometPaint);
        canvas.drawCircle(Offset(startX, startY), 3.0, Paint()..color = Colors.white);
      }

      // Comet 2: Right to Left across bottom space
      final c2Progress = ((progress + 0.5) * 1.2) % 1.0;
      if (c2Progress < 0.55) {
        final norm = c2Progress / 0.55;
        final startX = size.width + 40 - norm * (size.width + 100);
        final startY = size.height * 0.45 + norm * (size.height * 0.45);
        final endX = startX + 55;
        final endY = startY - 30;

        final comet2Paint = Paint()
          ..shader = uiGradient(
            from: Offset(startX, startY),
            to: Offset(endX, endY),
            colors: [const Color(0xFFFDE68A), const Color(0xFFEF4444).withOpacity(0.7), Colors.transparent],
          )
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(Offset(startX, startY), Offset(endX, endY), comet2Paint);
        canvas.drawCircle(Offset(startX, startY), 2.5, Paint()..color = const Color(0xFFFDE68A));
      }
    } else {
      // Static decorative comets
      final comet1 = Paint()
        ..shader = uiGradient(
          from: Offset(size.width * 0.22, size.height * 0.12),
          to: Offset(size.width * 0.14, size.height * 0.06),
          colors: [Colors.white, const Color(0xFF10B981).withOpacity(0.75), Colors.transparent],
        )
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(size.width * 0.22, size.height * 0.12), Offset(size.width * 0.14, size.height * 0.06), comet1);
      canvas.drawCircle(Offset(size.width * 0.22, size.height * 0.12), 2.8, Paint()..color = Colors.white);
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
        oldDelegate.isAnimated != isAnimated;
  }
}
