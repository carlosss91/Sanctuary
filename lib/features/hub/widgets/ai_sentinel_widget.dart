import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ai_automation_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/api_service.dart';
import 'ai_sentinel_dialog.dart';

class AiSentinelWidget extends StatefulWidget {
  final ApiService apiService;
  final UserModel currentUser;
  final bool isDark;

  const AiSentinelWidget({
    super.key,
    required this.apiService,
    required this.currentUser,
    required this.isDark,
  });

  @override
  State<AiSentinelWidget> createState() => _AiSentinelWidgetState();
}

class _AiSentinelWidgetState extends State<AiSentinelWidget> {
  late AiWatchdogConfig _config;
  List<AiWatchdogNotification> _notifications = [];
  bool _isLoading = true;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    try {
      _config = await widget.apiService.getAiWatchdogConfig();
      // Ensure target email defaults to user email if unset
      if (_config.targetEmail.isEmpty && widget.currentUser.email != null) {
        _config = _config.copyWith(targetEmail: widget.currentUser.email);
      }
      _notifications = await widget.apiService.getAiWatchdogNotifications();
    } catch (_) {
      _config = AiWatchdogConfig.defaultConfig(
        targetEmail: widget.currentUser.email ?? '',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _runScan() async {
    if (_isScanning) return;
    setState(() => _isScanning = true);

    try {
      await widget.apiService.saveAiWatchdogConfig(_config);
      await widget.apiService.runAiWatchdogScan();
      final results = await widget.apiService.getAiWatchdogNotifications();
      final updatedConfig = await widget.apiService.getAiWatchdogConfig();
      if (mounted) {
        setState(() {
          _notifications = results;
          _config = updatedConfig;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.emerald,
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Escaneo finalizado: ${results.length} convocatorias analizadas'),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            content: Text('Error al escanear boletines: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _openConfigDialog() {
    AiSentinelDialog.show(
      context,
      apiService: widget.apiService,
      currentUser: widget.currentUser,
      onConfigSaved: () {
        _initData();
      },
      onTriggerScan: () {
        _runScan();
      },
    );
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _markAsRead(String id) async {
    await widget.apiService.markAiNotificationAsRead(id);
    if (mounted) {
      setState(() {
        final idx = _notifications.indexWhere((n) => n.id == id);
        if (idx != -1) {
          _notifications[idx] = _notifications[idx].copyWith(isRead: true);
        }
      });
    }
  }

  Future<void> _deleteNotif(String id) async {
    await widget.apiService.deleteAiNotification(id);
    if (mounted) {
      setState(() {
        _notifications.removeWhere((n) => n.id == id);
      });
    }
  }

  Color _getSourceColor(String source) {
    final s = source.toUpperCase();
    if (s.contains('BOC')) return const Color(0xFF0284C7); // Sky blue
    if (s.contains('BOE')) return const Color(0xFFD97706); // Amber
    if (s.contains('ICV')) return const Color(0xFF10B981); // Emerald
    if (s.contains('GOBIERNO') || s.contains('GOBCAN')) return const Color(0xFF8B5CF6); // Purple
    return AppTheme.emerald;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 640;

        return ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A).withOpacity(0.60) : Colors.white.withOpacity(0.75),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.70),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.emerald.withOpacity(0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: EdgeInsets.all(isNarrow ? 16 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ==========================================================
                  // 1. WIDGET HEADER: Title, Island badge, and Actions
                  // ==========================================================
                  Row(
                    children: [
                      // Radar Icon (Static, without oscillating pulse)
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF059669), Color(0xFF047857)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.emerald.withOpacity(0.30),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.radar_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),

                      // Title & Island Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                const Text(
                                  'AI Sentinel',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15.5,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B5CF6).withOpacity(0.20),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _config.enablePlaceFilter ? Icons.location_on_rounded : Icons.public_rounded,
                                        size: 10,
                                        color: const Color(0xFFA78BFA),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        _config.enablePlaceFilter ? _config.targetPlace.toUpperCase() : 'ÁMBITO GLOBAL',
                                        style: const TextStyle(
                                          color: Color(0xFFA78BFA),
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (unreadCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$unreadCount nueva${unreadCount > 1 ? 's' : ''}',
                                      style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Vigilancia oficial automatizada (${_config.sources.where((s) => s.enabled).length} fuentes activas · ${_config.keywords.length} filtros)',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Scan Button: compact lightning-bolt button on mobile to save horizontal space
                      if (isNarrow)
                        IconButton(
                          tooltip: _isScanning ? 'Rastreando boletines...' : 'Escanear Ahora',
                          onPressed: _isScanning ? null : _runScan,
                          icon: _isScanning
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.bolt_rounded, size: 20, color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.emerald,
                            padding: const EdgeInsets.all(9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: _isScanning ? null : _runScan,
                          icon: _isScanning
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.bolt_rounded, size: 16),
                          label: Text(
                            _isScanning ? 'Rastreando...' : 'Escanear Ahora',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.emerald,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      const SizedBox(width: 6),

                      // Settings Gear Button
                      IconButton(
                        tooltip: 'Configurar AI Sentinel (Gemini, Fuentes, Email)',
                        onPressed: _openConfigDialog,
                        icon: const Icon(Icons.tune_rounded, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          padding: const EdgeInsets.all(8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ==========================================================
                  // 2. STATUS & ACTIVE SOURCES CHIPS BAR
                  // ==========================================================
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B).withOpacity(0.55) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _config.geminiApiKey.isNotEmpty ? Icons.auto_awesome : Icons.search_rounded,
                          size: 14,
                          color: _config.geminiApiKey.isNotEmpty ? const Color(0xFF06B6D4) : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _config.geminiApiKey.isNotEmpty
                                ? 'Motor: Gemini IA Activo (${_config.geminiModel}) · Alertas automáticas'
                                : 'Motor: Filtro semántico oficial (Sin API Key configurada)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_config.emailNotifications) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.emerald.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.mail_outline_rounded, size: 10, color: AppTheme.emerald),
                                const SizedBox(width: 3),
                                Text(
                                  isNarrow ? 'Email ON' : 'Email ${_config.checkFrequency}',
                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Active Sources Row
                  if (_config.sources.any((s) => s.enabled)) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _config.sources.where((s) => s.enabled).map((source) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B).withOpacity(0.4) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                source.isCustom ? Icons.link_rounded : Icons.account_balance_rounded,
                                size: 10,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                source.name,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // ==========================================================
                  // 3. NOTIFICATIONS FEED / CARDS
                  // ==========================================================
                  if (_isLoading) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 36),
                      child: Center(child: CircularProgressIndicator(color: AppTheme.emerald, strokeWidth: 2.5)),
                    ),
                  ] else if (_notifications.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B).withOpacity(0.3) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined, size: 36, color: Colors.grey.withOpacity(0.6)),
                          const SizedBox(height: 10),
                          Text(
                            _config.enablePlaceFilter
                                ? 'No hay convocatorias pendientes registradas para ${_config.targetPlace}'
                                : 'No hay convocatorias pendientes registradas',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Pulsa "Escanear Ahora" para consultar en directo las fuentes y boletines oficiales configurados.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: _runScan,
                            icon: const Icon(Icons.refresh_rounded, size: 15),
                            label: const Text('Comprobar Boletines Oficiales'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.emerald,
                              side: const BorderSide(color: AppTheme.emerald),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final notif = _notifications[idx];
                        final sourceColor = _getSourceColor(notif.source);

                        return Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? (notif.isRead ? const Color(0xFF1E293B).withOpacity(0.35) : const Color(0xFF1E293B).withOpacity(0.70))
                                : (notif.isRead ? Colors.white.withOpacity(0.6) : Colors.white),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: notif.isRead
                                  ? (isDark ? const Color(0xFF334155).withOpacity(0.4) : const Color(0xFFE2E8F0))
                                  : sourceColor.withOpacity(0.5),
                              width: notif.isRead ? 1 : 1.4,
                            ),
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Badges Row
                              Row(
                                children: [
                                  // Source Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: sourceColor.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: sourceColor.withOpacity(0.4)),
                                    ),
                                    child: Text(
                                      notif.source,
                                      style: TextStyle(
                                        color: sourceColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),

                                  // Island Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8B5CF6).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      notif.island,
                                      style: const TextStyle(
                                        color: Color(0xFFA78BFA),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),

                                  // Bulletin Number
                                  if (notif.bulletinNumber.isNotEmpty)
                                    Text(
                                      notif.bulletinNumber,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),

                                  const Spacer(),

                                  // Date
                                  Text(
                                    notif.date,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  // Mark read / Delete icons
                                  if (!notif.isRead)
                                    IconButton(
                                      tooltip: 'Marcar como leída',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                      icon: const Icon(Icons.check_circle_outline, size: 16, color: AppTheme.emerald),
                                      onPressed: () => _markAsRead(notif.id),
                                    ),
                                  IconButton(
                                    tooltip: 'Descartar notificación',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                    icon: Icon(Icons.close_rounded, size: 16, color: Colors.grey.withOpacity(0.7)),
                                    onPressed: () => _deleteNotif(notif.id),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              // Notification Title
                              Text(
                                notif.title,
                                style: TextStyle(
                                  fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w800,
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),

                              const SizedBox(height: 6),

                              // Notification Summary
                              Text(
                                notif.summary,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  height: 1.35,
                                ),
                              ),

                              // AI Analysis Card (if available)
                              if (notif.aiAnalysis.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF06B6D4).withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF06B6D4)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          notif.aiAnalysis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            height: 1.35,
                                            color: Color(0xFF22D3EE),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 10),

                              // Bottom Action: Direct Link to Bulletin
                              Row(
                                children: [
                                  if (notif.isEmailSent) ...[
                                    const Icon(Icons.mark_email_read_rounded, size: 13, color: AppTheme.emerald),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Aviso enviado al correo',
                                      style: TextStyle(fontSize: 10.5, color: AppTheme.emerald, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                  const Spacer(),
                                  InkWell(
                                    onTap: () => _openUrl(notif.url),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Abrir en ${notif.source}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: sourceColor,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(Icons.open_in_new_rounded, size: 12, color: sourceColor),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 14),

                  // ==========================================================
                  // 4. FOOTER: Quick Links to Portals
                  // ==========================================================
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Acceso directo a sedes oficiales:',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                      ),
                      _buildQuickPortalLink('BOC Canarias', 'https://www.gobiernodecanarias.org/boc/', isDark),
                      _buildQuickPortalLink('BOE Estado', 'https://www.boe.es/', isDark),
                      _buildQuickPortalLink('Vivienda GobCan', 'https://www.gobiernodecanarias.org/vivienda/', isDark),
                      _buildQuickPortalLink('ICV', 'https://www.gobiernodecanarias.org/icv/', isDark),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickPortalLink(String label, String url, bool isDark) {
    return InkWell(
      onTap: () => _openUrl(url),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                decoration: TextDecoration.underline,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_outward_rounded, size: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
          ],
        ),
      ),
    );
  }
}
