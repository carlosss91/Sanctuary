import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../models/signature_document_model.dart';

class ShareDocumentDialog extends StatefulWidget {
  final PdfSignerDocument document;
  final VoidCallback? onSimulateGuestSigner;

  const ShareDocumentDialog({
    super.key,
    required this.document,
    this.onSimulateGuestSigner,
  });

  static void show(BuildContext context, PdfSignerDocument doc, {VoidCallback? onSimulateGuestSigner}) {
    showDialog(
      context: context,
      builder: (ctx) => ShareDocumentDialog(
        document: doc,
        onSimulateGuestSigner: onSimulateGuestSigner,
      ),
    );
  }

  @override
  State<ShareDocumentDialog> createState() => _ShareDocumentDialogState();
}

class _ShareDocumentDialogState extends State<ShareDocumentDialog> {
  bool _copied = false;

  String get _shareUrl {
    // URL oficial alojada en GitHub Pages
    String baseUrl = 'https://carlosss91.github.io/Sanctuary/';
    if (kIsWeb) {
      final uri = Uri.base;
      if (uri.host.contains('github.io')) {
        final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
        baseUrl = '${uri.scheme}://${uri.host}$path';
      }
    }
    if (!baseUrl.endsWith('/')) baseUrl = '$baseUrl/';
    return '$baseUrl#/sign?docId=${widget.document.id}&token=${widget.document.shareToken}';
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _shareUrl));
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Enlace de firma copiado al portapapeles!'),
        backgroundColor: AppTheme.emerald,
        duration: Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(_shareUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error abriendo enlace: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.share_outlined, color: AppTheme.emerald, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Compartir para Firmar en Vivo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Enlace único alojado en GitHub Pages con auditoría', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Envía este enlace a los firmantes. Cuando lo abran, el sistema les solicitará su Nombre y Apellidos antes de permitirles firmar:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.emerald.withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_done_rounded, size: 12, color: AppTheme.emerald),
                      SizedBox(width: 4),
                      Text('GitHub Pages', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Share URL display box with Copy and Open buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161F30) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, size: 18, color: AppTheme.emerald),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _shareUrl,
                      style: const TextStyle(fontSize: 11.0, fontFamily: 'monospace'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Abrir enlace en navegador',
                    child: IconButton(
                      icon: const Icon(Icons.open_in_new, size: 16),
                      onPressed: _openInBrowser,
                      color: isDark ? Colors.cyanAccent : Colors.teal,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: _copyToClipboard,
                    icon: Icon(_copied ? Icons.check : Icons.copy, size: 14),
                    label: Text(_copied ? 'Copiado' : 'Copiar', style: const TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _copied ? Colors.teal : AppTheme.emerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Explanatory steps
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF132A26) : const Color(0xFFE6F4EA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.emerald.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, size: 15, color: AppTheme.emerald),
                      SizedBox(width: 6),
                      Text('Flujo en Tiempo Real:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildStepRow('1', 'El firmante abre el enlace y completa su Nombre y Apellidos.'),
                  _buildStepRow('2', 'Dibuja su firma con la herramienta de pluma, boli o marcador.'),
                  _buildStepRow('3', 'El documento se refresca automáticamente notificando a todos los participantes.'),
                ],
              ),
            ),

            if (widget.onSimulateGuestSigner != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '¿Quieres probar cómo lo ve un firmante externo?',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onSimulateGuestSigner?.call();
                    },
                    icon: const Icon(Icons.person_add_alt, size: 14),
                    label: const Text('Simular Firma de Invitado', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.emerald,
                      side: const BorderSide(color: AppTheme.emerald),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Widget _buildStepRow(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$number. ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11))),
        ],
      ),
    );
  }
}
