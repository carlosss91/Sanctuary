import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ai_automation_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/api_service.dart';

class AiSentinelDialog extends StatefulWidget {
  final ApiService apiService;
  final UserModel currentUser;
  final VoidCallback onConfigSaved;
  final VoidCallback onTriggerScan;

  const AiSentinelDialog({
    super.key,
    required this.apiService,
    required this.currentUser,
    required this.onConfigSaved,
    required this.onTriggerScan,
  });

  static Future<void> show(
    BuildContext context, {
    required ApiService apiService,
    required UserModel currentUser,
    required VoidCallback onConfigSaved,
    required VoidCallback onTriggerScan,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AiSentinelDialog(
        apiService: apiService,
        currentUser: currentUser,
        onConfigSaved: onConfigSaved,
        onTriggerScan: onTriggerScan,
      ),
    );
  }

  @override
  State<AiSentinelDialog> createState() => _AiSentinelDialogState();
}

class _AiSentinelDialogState extends State<AiSentinelDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AiWatchdogConfig _config;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTestingAi = false;
  String? _testAiResult;
  bool _isSendingTestEmail = false;
  String? _testEmailResult;
  bool _obscureApiKey = true;

  static const List<Map<String, String>> _availableGeminiModels = [
    {
      'id': 'gemini-2.5-pro',
      'name': 'Gemini 2.5 Pro',
      'badge': 'Última Gen',
      'desc': 'Máximo razonamiento & documentos densos',
    },
    {
      'id': 'gemini-2.5-flash',
      'name': 'Gemini 2.5 Flash',
      'badge': 'Ultra Rápido',
      'desc': 'Última generación con alta velocidad y precisión',
    },
    {
      'id': 'gemini-2.0-flash',
      'name': 'Gemini 2.0 Flash',
      'badge': '2.0 Multimodal',
      'desc': 'Baja latencia y gran fluidez para alertas',
    },
    {
      'id': 'gemini-2.0-flash-lite',
      'name': 'Gemini 2.0 Flash Lite',
      'badge': 'Económico',
      'desc': 'Alta velocidad con consumo mínimo de cuota',
    },
    {
      'id': 'gemini-2.0-pro-exp-02-05',
      'name': 'Gemini 2.0 Pro Experimental',
      'badge': 'Exp 2.0',
      'desc': 'Capacidad avanzada experimental',
    },
    {
      'id': 'gemini-1.5-flash',
      'name': 'Gemini 1.5 Flash',
      'badge': 'Recomendado',
      'desc': 'Equilibrio contrastado de velocidad y fiabilidad',
    },
    {
      'id': 'gemini-1.5-flash-8b',
      'name': 'Gemini 1.5 Flash-8B',
      'badge': 'Ultraligero',
      'desc': 'Rápida extracción y bajo consumo',
    },
    {
      'id': 'gemini-1.5-pro',
      'name': 'Gemini 1.5 Pro',
      'badge': '2M Tokens',
      'desc': 'Ventana ultra-grande para boletines extensos',
    },
  ];

  late TextEditingController _apiKeyCtrl;
  late TextEditingController _customModelCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _newKeywordCtrl;
  late TextEditingController _placeCtrl;
  late TextEditingController _newSourceNameCtrl;
  late TextEditingController _newSourceUrlCtrl;

  late List<String> _keywords;
  late List<AiWatchdogSource> _sources;
  late bool _enablePlaceFilter;
  late String _selectedModel;
  bool _isCustomModel = false;
  late String _selectedFrequency;
  late bool _notifyEmail;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _apiKeyCtrl = TextEditingController();
    _customModelCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _newKeywordCtrl = TextEditingController();
    _placeCtrl = TextEditingController();
    _newSourceNameCtrl = TextEditingController();
    _newSourceUrlCtrl = TextEditingController();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    final cfg = await widget.apiService.getAiWatchdogConfig();
    _config = cfg;
    _apiKeyCtrl.text = cfg.geminiApiKey;
    _emailCtrl.text = cfg.targetEmail.isNotEmpty ? cfg.targetEmail : (widget.currentUser.email ?? '');
    _placeCtrl.text = cfg.targetPlace;
    _keywords = List<String>.from(cfg.keywords);
    _sources = List<AiWatchdogSource>.from(cfg.sources);
    _enablePlaceFilter = cfg.enablePlaceFilter;
    _selectedModel = cfg.geminiModel;

    if (_availableGeminiModels.any((m) => m['id'] == _selectedModel)) {
      _isCustomModel = false;
      _customModelCtrl.clear();
    } else {
      _isCustomModel = true;
      _customModelCtrl.text = _selectedModel;
    }

    _selectedFrequency = cfg.checkFrequency;
    _notifyEmail = cfg.notifyEmail;

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final place = _placeCtrl.text.trim().isNotEmpty ? _placeCtrl.text.trim() : 'Lanzarote';
    final chosenModel = _isCustomModel
        ? (_customModelCtrl.text.trim().isNotEmpty ? _customModelCtrl.text.trim() : 'gemini-1.5-flash')
        : _selectedModel;

    final updated = _config.copyWith(
      geminiApiKey: _apiKeyCtrl.text.trim(),
      geminiModel: chosenModel,
      notifyEmail: _notifyEmail,
      targetEmail: _emailCtrl.text.trim(),
      checkFrequency: _selectedFrequency,
      enablePlaceFilter: _enablePlaceFilter,
      targetPlace: place,
      keywords: _keywords,
      sources: _sources,
    );
    await widget.apiService.saveAiWatchdogConfig(updated);
    if (mounted) {
      setState(() => _isSaving = false);
      widget.onConfigSaved();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuración de AI Sentinel guardada correctamente'),
          backgroundColor: AppTheme.emerald,
        ),
      );
    }
  }

  Future<void> _testGeminiConnection() async {
    final key = _apiKeyCtrl.text.trim();
    if (key.isEmpty) {
      setState(() => _testAiResult = '⚠️ Introduce una API Key de Gemini para realizar la prueba.');
      return;
    }
    final modelToTest = _isCustomModel
        ? (_customModelCtrl.text.trim().isNotEmpty ? _customModelCtrl.text.trim() : 'gemini-1.5-flash')
        : _selectedModel;

    setState(() {
      _isTestingAi = true;
      _testAiResult = null;
    });

    try {
      final res = await widget.apiService.testGeminiApiKey(key, modelToTest);
      if (mounted) {
        setState(() {
          _isTestingAi = false;
          if (res['success'] == true) {
            _testAiResult = res['message'] ?? '✅ Conexión con $modelToTest verificada exitosamente.';
          } else {
            _testAiResult = '❌ ${res['message'] ?? 'Error desconocido al probar Gemini'}';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTestingAi = false;
          _testAiResult = '❌ Error al probar conexión: $e';
        });
      }
    }
  }

  Future<void> _sendTestEmail() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _testEmailResult = '⚠️ Introduce un correo electrónico válido para enviar la prueba.');
      return;
    }
    setState(() {
      _isSendingTestEmail = true;
      _testEmailResult = null;
    });

    final place = _placeCtrl.text.trim().isNotEmpty ? _placeCtrl.text.trim() : 'Lanzarote';
    final currentCfg = _config.copyWith(
      targetEmail: email,
      targetPlace: place,
      enablePlaceFilter: _enablePlaceFilter,
    );

    try {
      final res = await widget.apiService.sendAiWatchdogTestEmail(email, currentCfg);
      if (mounted) {
        setState(() {
          _isSendingTestEmail = false;
          if (res['success'] == true) {
            _testEmailResult = res['message'] ?? '✅ Correo de prueba enviado con éxito a $email';
          } else {
            _testEmailResult = '❌ ${res['message'] ?? 'Error desconocido al enviar correo'}';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSendingTestEmail = false;
          _testEmailResult = '❌ Error al enviar prueba: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _apiKeyCtrl.dispose();
    _customModelCtrl.dispose();
    _emailCtrl.dispose();
    _newKeywordCtrl.dispose();
    _placeCtrl.dispose();
    _newSourceNameCtrl.dispose();
    _newSourceUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 700),
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: AppTheme.emerald),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dialog Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 18, 14, 14),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF06B6D4), AppTheme.emerald],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.emerald.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.radar_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Configurar AI Sentinel & Automatismos',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Vigilancia de boletines oficiales (BOC, BOE, Vivienda) y conexión IA',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),

                  // Tabs
                  Container(
                    color: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: AppTheme.emerald,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: AppTheme.emerald,
                      indicatorWeight: 3,
                      tabs: const [
                        Tab(icon: Icon(Icons.travel_explore_rounded, size: 18), text: 'Boletines & Filtros'),
                        Tab(icon: Icon(Icons.auto_awesome, size: 18), text: 'IA & Gemini'),
                        Tab(icon: Icon(Icons.mark_email_read_rounded, size: 18), text: 'Alertas por Email'),
                      ],
                    ),
                  ),

                  // Tab Views
                  Flexible(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildSourcesAndFiltersTab(isDark),
                        _buildAiGeminiTab(isDark),
                        _buildEmailAndScheduleTab(isDark),
                      ],
                    ),
                  ),

                  // Footer Actions
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onTriggerScan();
                          },
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text('Escanear Ahora', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.emerald,
                            side: const BorderSide(color: AppTheme.emerald),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save_rounded, size: 16),
                          label: Text(_isSaving ? 'Guardando...' : 'Guardar Ajustes'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.emerald,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // --- TAB 1: Fuentes y Filtros ---
  Widget _buildSourcesAndFiltersTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 1. Fuentes Oficiales y URLs específicas
        Row(
          children: [
            const Icon(Icons.travel_explore_rounded, size: 18, color: AppTheme.emerald),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fuentes Oficiales & URLs de Seguimiento',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  Text(
                    'Activa, desactiva o elimina cualquier fuente oficial o personalizada.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.restart_alt_rounded, size: 13, color: AppTheme.emerald),
              label: const Text('Restablecer predeterminadas', style: TextStyle(fontSize: 11, color: AppTheme.emerald)),
              onPressed: () {
                setState(() {
                  for (final def in AiWatchdogConfig.defaultSources) {
                    if (!_sources.any((s) => s.id == def.id)) {
                      _sources.add(def);
                    }
                  }
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_sources.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B).withOpacity(0.4) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.layers_clear_rounded, size: 30, color: Colors.grey),
                  const SizedBox(height: 6),
                  const Text('No hay fuentes configuradas actualmente.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  const Text('Puedes añadir URLs abajo o restaurar las fuentes oficiales estándar.', style: TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.restore_rounded, size: 14),
                    label: const Text('Restablecer Boletines Oficiales (BOC, BOE, GobCan)', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      setState(() {
                        _sources = List<AiWatchdogSource>.from(AiWatchdogConfig.defaultSources);
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

        // Sources list
        ..._sources.map((src) {
          final isBuiltIn = !src.isCustom;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B).withOpacity(0.6) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: src.enabled
                    ? AppTheme.emerald.withOpacity(0.35)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: src.enabled
                        ? AppTheme.emerald.withOpacity(0.15)
                        : Colors.grey.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isBuiltIn ? Icons.verified_rounded : Icons.link_rounded,
                    size: 16,
                    color: src.enabled ? AppTheme.emerald : Colors.grey,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        src.name,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: src.enabled ? null : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 1),
                      InkWell(
                        onTap: () {
                          if (src.url.isNotEmpty) {
                            launchUrl(Uri.parse(src.url), mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                src.url.isNotEmpty ? src.url : src.description,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF06B6D4),
                                  decoration: TextDecoration.underline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(Icons.open_in_new, size: 10, color: Color(0xFF06B6D4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                  tooltip: 'Eliminar fuente (${src.name})',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () {
                    setState(() => _sources.remove(src));
                  },
                ),
                Switch(
                  value: src.enabled,
                  activeColor: AppTheme.emerald,
                  onChanged: (val) {
                    setState(() {
                      final idx = _sources.indexOf(src);
                      if (idx != -1) {
                        _sources[idx] = src.copyWith(enabled: val);
                      }
                    });
                  },
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 10),

        // Add custom source card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.add_link_rounded, size: 16, color: AppTheme.emerald),
                  SizedBox(width: 6),
                  Text(
                    'Añadir Fuente / Portal Web Específico',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: _newSourceNameCtrl,
                      decoration: InputDecoration(
                        hintText: 'Nombre (ej. Cabildo de Lanzarote)',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 6,
                    child: TextField(
                      controller: _newSourceUrlCtrl,
                      decoration: InputDecoration(
                        hintText: 'URL (ej. https://sede.cabildodelanzarote.com)',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      final name = _newSourceNameCtrl.text.trim();
                      final url = _newSourceUrlCtrl.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Escribe un nombre para la fuente')),
                        );
                        return;
                      }
                      if (url.isEmpty || (!url.startsWith('http://') && !url.startsWith('https://'))) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('La URL debe comenzar con http:// o https://')),
                        );
                        return;
                      }
                      setState(() {
                        _sources.add(
                          AiWatchdogSource(
                            id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                            name: name,
                            url: url,
                            description: 'Fuente personalizada añadida',
                            enabled: true,
                            isCustom: true,
                          ),
                        );
                        _newSourceNameCtrl.clear();
                        _newSourceUrlCtrl.clear();
                      });
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Añadir', style: TextStyle(fontSize: 11.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),
        const Divider(),
        const SizedBox(height: 14),

        // 2. Lugar / Ámbito de Seguimiento (con toggle para activar/desactivar y selector limpio sin cortes)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _enablePlaceFilter
                  ? AppTheme.emerald.withOpacity(0.35)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 18, color: AppTheme.emerald),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lugar / Ámbito de Seguimiento',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          'Activa para filtrar por municipio, isla o provincia. Desactívalo para seguimiento global.',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _enablePlaceFilter,
                    activeColor: AppTheme.emerald,
                    onChanged: (val) {
                      setState(() => _enablePlaceFilter = val);
                    },
                  ),
                ],
              ),
              if (_enablePlaceFilter) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _placeCtrl,
                  decoration: InputDecoration(
                    labelText: 'Lugar o Ámbito (ej. Lanzarote, Arrecife, Canarias, Madrid...)',
                    labelStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.place_outlined, size: 18, color: AppTheme.emerald),
                    suffixIcon: _placeCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              setState(() => _placeCtrl.clear());
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                const Text('Sugerencias rápidas:', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    'Lanzarote',
                    'Gran Canaria',
                    'Tenerife',
                    'Fuerteventura',
                    'La Palma',
                    'Arrecife',
                    'Canarias',
                    'Madrid',
                  ].map((sugg) {
                    final isSel = _placeCtrl.text.trim().toLowerCase() == sugg.toLowerCase();
                    return ActionChip(
                      label: Text(sugg, style: TextStyle(fontSize: 10.5, color: isSel ? Colors.white : null)),
                      backgroundColor: isSel ? AppTheme.emerald : (isDark ? AppTheme.darkInput : AppTheme.lightInput),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      onPressed: () {
                        setState(() {
                          _placeCtrl.text = sugg;
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 22),
        const Divider(),
        const SizedBox(height: 14),

        // 3. Palabras Clave de Detección (Generalizadas para cualquier materia)
        Row(
          children: [
            const Icon(Icons.tag_rounded, size: 18, color: AppTheme.emerald),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Palabras Clave de Detección',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    'Personaliza los términos según la materia: vivienda, empleo público, subvenciones, etc.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Quick Preset packs
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildKeywordPresetChip('+ Vivienda & VPO', ['vivienda protegida', 'vpo', 'alquiler', 'ayudas alquiler', 'vivienda social'], isDark),
            _buildKeywordPresetChip('+ Empleo Público', ['oposiciones', 'empleo público', 'bolsa de empleo', 'convocatoria personal', 'auxiliar'], isDark),
            _buildKeywordPresetChip('+ Becas & Ayudas', ['becas', 'subvención', 'ayudas', 'financiación'], isDark),
            _buildKeywordPresetChip('+ Licitaciones', ['licitación', 'adjudicación', 'contrato público'], isDark),
          ],
        ),
        const SizedBox(height: 10),

        // Keywords Chips
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _keywords.map((kw) {
            return Chip(
              label: Text(kw, style: const TextStyle(fontSize: 11)),
              backgroundColor: isDark ? AppTheme.darkInput : AppTheme.lightInput,
              deleteIcon: const Icon(Icons.close, size: 13),
              onDeleted: () {
                setState(() => _keywords.remove(kw));
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newKeywordCtrl,
                decoration: InputDecoration(
                  hintText: 'Añadir palabra clave (ej. alquiler joven, administrativo, beca)',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onSubmitted: (val) {
                  final trimmed = val.trim().toLowerCase();
                  if (trimmed.isNotEmpty && !_keywords.contains(trimmed)) {
                    setState(() {
                      _keywords.add(trimmed);
                      _newKeywordCtrl.clear();
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                final trimmed = _newKeywordCtrl.text.trim().toLowerCase();
                if (trimmed.isNotEmpty && !_keywords.contains(trimmed)) {
                  setState(() {
                    _keywords.add(trimmed);
                    _newKeywordCtrl.clear();
                  });
                }
              },
              child: const Text('Añadir'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeywordPresetChip(String label, List<String> terms, bool isDark) {
    return ActionChip(
      avatar: const Icon(Icons.add, size: 13, color: AppTheme.emerald),
      label: Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
      backgroundColor: AppTheme.emerald.withOpacity(0.12),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      onPressed: () {
        setState(() {
          for (final t in terms) {
            if (!_keywords.contains(t.toLowerCase())) {
              _keywords.add(t.toLowerCase());
            }
          }
        });
      },
    );
  }

  // --- TAB 2: IA & Gemini ---
  Widget _buildAiGeminiTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.emerald.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.emerald.withOpacity(0.3)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: AppTheme.emerald, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'El motor Sentinel utiliza tu API Key de Gemini para leer los sumarios de los boletines oficiales, extraer las fechas límite y generar resúmenes ejecutivos comprensibles.\n\nSi no dispones de API Key, Sanctuary utilizará su analizador heurístico inteligente integrado de forma totalmente gratuita.',
                  style: TextStyle(fontSize: 11.5, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        Row(
          children: [
            const Text('Google Gemini API Key:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Spacer(),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 13, color: AppTheme.emerald),
              label: const Text('Obtener clave en Google AI Studio', style: TextStyle(fontSize: 11, color: AppTheme.emerald)),
              onPressed: () => launchUrl(Uri.parse('https://aistudio.google.com/app/apikey'), mode: LaunchMode.externalApplication),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _apiKeyCtrl,
          obscureText: _obscureApiKey,
          decoration: InputDecoration(
            hintText: 'AIzaSy...',
            prefixIcon: const Icon(Icons.key_rounded, size: 18),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_apiKeyCtrl.text.isNotEmpty)
                  IconButton(
                    tooltip: 'Borrar clave',
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    onPressed: () => setState(() => _apiKeyCtrl.clear()),
                  ),
                IconButton(
                  tooltip: _obscureApiKey ? 'Mostrar clave API' : 'Ocultar clave API',
                  icon: Icon(
                    _obscureApiKey ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 19,
                    color: _obscureApiKey ? Colors.grey : AppTheme.emerald,
                  ),
                  onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                ),
              ],
            ),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),

        // Model Selector Header
        Row(
          children: [
            const Text('Modelo de IA (Gemini):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.emerald.withOpacity(0.3)),
              ),
              child: Text(
                _isCustomModel
                    ? (_customModelCtrl.text.isNotEmpty ? _customModelCtrl.text : 'Personalizado')
                    : _selectedModel,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.emerald),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Model Dropdown
        DropdownButtonFormField<String>(
          value: _isCustomModel ? '__custom__' : _selectedModel,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          borderRadius: BorderRadius.circular(12),
          items: [
            ..._availableGeminiModels.map((m) {
              final isLatest = m['badge'] == 'Última Gen' || m['badge'] == 'Ultra Rápido';
              return DropdownMenuItem<String>(
                value: m['id'],
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            m['name']!,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            m['desc']!,
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isLatest
                            ? const Color(0xFF8B5CF6).withOpacity(0.18)
                            : AppTheme.emerald.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        m['badge']!,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isLatest ? const Color(0xFFA78BFA) : AppTheme.emerald,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const DropdownMenuItem<String>(
              value: '__custom__',
              child: Row(
                children: [
                  Icon(Icons.edit_note_rounded, size: 16, color: AppTheme.emerald),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '✏️ Personalizado (Escribir cualquier otro modelo...)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
          onChanged: (val) {
            if (val == null) return;
            setState(() {
              if (val == '__custom__') {
                _isCustomModel = true;
              } else {
                _isCustomModel = false;
                _selectedModel = val;
              }
            });
          },
        ),

        // Custom Model Field
        if (_isCustomModel) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _customModelCtrl,
            decoration: InputDecoration(
              labelText: 'Identificador del modelo Gemini',
              hintText: 'ej. gemini-2.5-pro, gemini-3.8-flash, etc.',
              prefixIcon: const Icon(Icons.psychology_rounded, size: 18),
              isDense: true,
              helperText: 'Escribe el nombre del modelo tal como aparece en Google AI Studio',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],

        const SizedBox(height: 8),
        // Quick access chips
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _buildModelQuickChip('Gemini 2.5 Pro', 'gemini-2.5-pro', isDark),
            _buildModelQuickChip('Gemini 2.5 Flash', 'gemini-2.5-flash', isDark),
            _buildModelQuickChip('Gemini 2.0 Flash', 'gemini-2.0-flash', isDark),
            _buildModelQuickChip('Gemini 1.5 Flash', 'gemini-1.5-flash', isDark),
            _buildModelQuickChip('Gemini 1.5 Pro', 'gemini-1.5-pro', isDark),
          ],
        ),

        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _isTestingAi ? null : _testGeminiConnection,
          icon: _isTestingAi
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.emerald))
              : const Icon(Icons.speed_rounded, size: 16, color: AppTheme.emerald),
          label: Text(
            _isTestingAi
                ? 'Comprobando conexión con ${_isCustomModel ? (_customModelCtrl.text.isNotEmpty ? _customModelCtrl.text : 'modelo') : _selectedModel}...'
                : 'Probar Conexión con IA (${_isCustomModel ? (_customModelCtrl.text.isNotEmpty ? _customModelCtrl.text : 'personalizado') : _selectedModel})',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.emerald,
            side: const BorderSide(color: AppTheme.emerald),
          ),
        ),

        if (_testAiResult != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _testAiResult!.startsWith('✅')
                    ? AppTheme.emerald.withOpacity(0.4)
                    : Colors.redAccent.withOpacity(0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _testAiResult!.startsWith('✅') ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  size: 16,
                  color: _testAiResult!.startsWith('✅') ? AppTheme.emerald : Colors.redAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _testAiResult!,
                    style: TextStyle(
                      fontSize: 12,
                      color: _testAiResult!.startsWith('✅')
                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
                          : Colors.redAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildModelQuickChip(String label, String modelId, bool isDark) {
    final isSel = !_isCustomModel && _selectedModel == modelId;
    return ActionChip(
      label: Text(label, style: TextStyle(fontSize: 10.5, color: isSel ? Colors.white : null)),
      backgroundColor: isSel ? AppTheme.emerald : (isDark ? AppTheme.darkInput : AppTheme.lightInput),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      onPressed: () {
        setState(() {
          _isCustomModel = false;
          _selectedModel = modelId;
          _customModelCtrl.clear();
        });
      },
    );
  }

  // --- TAB 3: Alertas por Email ---
  Widget _buildEmailAndScheduleTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SwitchListTile(
          value: _notifyEmail,
          activeColor: AppTheme.emerald,
          contentPadding: EdgeInsets.zero,
          title: const Text('Enviar alertas al correo electrónico', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: const Text('Recibe un aviso al instante cuando se publique una convocatoria que coincida con tus filtros', style: TextStyle(fontSize: 11, color: Colors.grey)),
          onChanged: (val) => setState(() => _notifyEmail = val),
        ),
        const SizedBox(height: 12),

        const Text('Correo Electrónico de Destino:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: _emailCtrl,
          decoration: InputDecoration(
            hintText: 'tu.correo@ejemplo.com',
            prefixIcon: const Icon(Icons.email_outlined, size: 18),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _isSendingTestEmail ? null : _sendTestEmail,
              icon: _isSendingTestEmail
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.emerald))
                  : const Icon(Icons.mark_email_read_rounded, size: 16, color: AppTheme.emerald),
              label: Text(_isSendingTestEmail ? 'Enviando alerta de prueba...' : 'Enviar Alerta de Prueba al Correo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.emerald,
                side: const BorderSide(color: AppTheme.emerald),
              ),
            ),
          ],
        ),

        if (_testEmailResult != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _testEmailResult!.startsWith('✅')
                    ? AppTheme.emerald.withOpacity(0.4)
                    : Colors.redAccent.withOpacity(0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _testEmailResult!.startsWith('✅') ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  size: 16,
                  color: _testEmailResult!.startsWith('✅') ? AppTheme.emerald : Colors.redAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _testEmailResult!,
                    style: TextStyle(
                      fontSize: 12,
                      color: _testEmailResult!.startsWith('✅')
                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
                          : Colors.redAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),

        // Frequency Selector
        const Text('Frecuencia de Rastreo Automático:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _buildFrequencyChip('Diaria (Cada mañana)', 'daily', isDark),
            _buildFrequencyChip('Cada 12 Horas', '12h', isDark),
            _buildFrequencyChip('Cada 6 Horas', '6h', isDark),
            _buildFrequencyChip('Solo Manual', 'manual', isDark),
          ],
        ),

        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.mark_email_read_outlined, color: AppTheme.emerald, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Las alertas se enviarán con formato HTML celestial de Sanctuary, incluyendo el enlace directo al anuncio oficial y los extractos resumidos.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFrequencyChip(String label, String value, bool isDark) {
    final isSelected = _selectedFrequency == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null)),
      selected: isSelected,
      selectedColor: AppTheme.emerald,
      backgroundColor: isDark ? AppTheme.darkInput : AppTheme.lightInput,
      onSelected: (val) {
        if (val) setState(() => _selectedFrequency = value);
      },
    );
  }
}
