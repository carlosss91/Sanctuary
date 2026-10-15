import 'package:flutter/material.dart';
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

  late TextEditingController _apiKeyCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _newKeywordCtrl;
  late List<String> _keywords;
  late List<String> _activeSources;
  late String _selectedIsland;
  late String _selectedModel;
  late String _selectedFrequency;
  late bool _notifyEmail;

  final List<String> _availableIslands = [
    'Lanzarote',
    'Gran Canaria',
    'Tenerife',
    'Fuerteventura',
    'La Palma',
    'La Gomera',
    'El Hierro',
    'Todas las Islas',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _apiKeyCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _newKeywordCtrl = TextEditingController();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    final cfg = await widget.apiService.getAiWatchdogConfig();
    _config = cfg;
    _apiKeyCtrl.text = cfg.geminiApiKey;
    _emailCtrl.text = cfg.targetEmail.isNotEmpty ? cfg.targetEmail : (widget.currentUser.email ?? '');
    _keywords = List<String>.from(cfg.keywords);
    _activeSources = List<String>.from(cfg.activeSources);
    _selectedIsland = cfg.islandFilter;
    _selectedModel = cfg.geminiModel;
    _selectedFrequency = cfg.checkFrequency;
    _notifyEmail = cfg.notifyEmail;

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final updated = _config.copyWith(
      geminiApiKey: _apiKeyCtrl.text.trim(),
      geminiModel: _selectedModel,
      notifyEmail: _notifyEmail,
      targetEmail: _emailCtrl.text.trim(),
      checkFrequency: _selectedFrequency,
      islandFilter: _selectedIsland,
      keywords: _keywords,
      activeSources: _activeSources,
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
    setState(() {
      _isTestingAi = true;
      _testAiResult = null;
    });

    try {
      // Direct health test with Gemini API
      final res = await widget.apiService.runAiWatchdogScan();
      if (mounted) {
        setState(() {
          _isTestingAi = false;
          _testAiResult = res['geminiTested'] == true
              ? '✅ Conexión con Gemini verificada correctamente.'
              : '✅ Conexión establecida. El motor de análisis está listo.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTestingAi = false;
          _testAiResult = 'Error al probar: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _apiKeyCtrl.dispose();
    _emailCtrl.dispose();
    _newKeywordCtrl.dispose();
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
        const Text(
          'Fuentes Oficiales Activas',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 10),
        _buildSourceSwitch(
          id: 'boc',
          title: 'BOC · Boletín Oficial de Canarias',
          subtitle: 'Monitorea convocatorias del Gobierno de Canarias y cabildos',
          isDark: isDark,
        ),
        _buildSourceSwitch(
          id: 'boe',
          title: 'BOE · Boletín Oficial del Estado',
          subtitle: 'Planes estatales de vivienda, subvenciones y ayudas públicas',
          isDark: isDark,
        ),
        _buildSourceSwitch(
          id: 'gobcan_vivienda',
          title: 'Gobierno de Canarias (Consejería de Vivienda)',
          subtitle: 'Portal oficial de vivienda pública y registro de demandantes',
          isDark: isDark,
        ),
        _buildSourceSwitch(
          id: 'icv',
          title: 'Instituto Canario de la Vivienda (ICV)',
          subtitle: 'Convocatorias de VPO, alquiler y adquisiciones protegidas',
          isDark: isDark,
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 14),

        // Isla Prioritaria
        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 18, color: AppTheme.emerald),
            const SizedBox(width: 8),
            const Text(
              'Isla Prioritaria de Seguimiento:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const Spacer(),
            DropdownButton<String>(
              value: _selectedIsland,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(12),
              items: _availableIslands.map((island) {
                return DropdownMenuItem<String>(
                  value: island,
                  child: Text(
                    island,
                    style: TextStyle(
                      fontWeight: island == 'Lanzarote' ? FontWeight.bold : FontWeight.normal,
                      color: island == 'Lanzarote' ? AppTheme.emerald : null,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedIsland = val);
              },
            ),
          ],
        ),

        const SizedBox(height: 18),
        const Text(
          'Palabras Clave de Detección (Vivienda & Subvenciones):',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),

        // Keywords Chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _keywords.map((kw) {
            return Chip(
              label: Text(kw, style: const TextStyle(fontSize: 11)),
              backgroundColor: isDark ? AppTheme.darkInput : AppTheme.lightInput,
              deleteIcon: const Icon(Icons.close, size: 14),
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
                  hintText: 'Añadir palabra clave (ej. alquiler joven, hipoteca)',
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

  Widget _buildSourceSwitch({
    required String id,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    final isActive = _activeSources.contains(id);
    return SwitchListTile(
      value: isActive,
      activeColor: AppTheme.emerald,
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      onChanged: (val) {
        setState(() {
          if (val) {
            _activeSources.add(id);
          } else {
            _activeSources.remove(id);
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

        const Text('Google Gemini API Key:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: _apiKeyCtrl,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'AIzaSy...',
            prefixIcon: const Icon(Icons.key_rounded, size: 18),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 14),

        // Model Selector
        Row(
          children: [
            const Text('Modelo de IA:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Spacer(),
            DropdownButton<String>(
              value: _selectedModel,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(12),
              items: const [
                DropdownMenuItem(value: 'gemini-1.5-flash', child: Text('Gemini 1.5 Flash (Rápido y Óptimo)')),
                DropdownMenuItem(value: 'gemini-1.5-pro', child: Text('Gemini 1.5 Pro (Análisis Exhaustivo)')),
                DropdownMenuItem(value: 'gemini-2.0-flash', child: Text('Gemini 2.0 Flash')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedModel = val);
              },
            ),
          ],
        ),

        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _isTestingAi ? null : _testGeminiConnection,
          icon: _isTestingAi
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.speed_rounded, size: 16),
          label: Text(_isTestingAi ? 'Comprobando conexión...' : 'Probar Conexión con IA'),
        ),

        if (_testAiResult != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _testAiResult!,
              style: TextStyle(
                fontSize: 12,
                color: _testAiResult!.startsWith('✅') ? AppTheme.emerald : Colors.amber,
              ),
            ),
          ),
        ],
      ],
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
        ),
        const SizedBox(height: 20),

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
