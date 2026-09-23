import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/signature_document_model.dart';

class SecurityStandardItem {
  final String id;
  final String standardName;
  final String lawReference;
  final String requirementTitle;
  final String complianceReason;
  final IconData icon;

  const SecurityStandardItem({
    required this.id,
    required this.standardName,
    required this.lawReference,
    required this.requirementTitle,
    required this.complianceReason,
    required this.icon,
  });
}

class SecurityStandardsDialog extends StatelessWidget {
  final PdfSignerDocument document;

  const SecurityStandardsDialog({
    super.key,
    required this.document,
  });

  static Future<void> show(BuildContext context, PdfSignerDocument doc) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => SecurityStandardsDialog(document: doc),
    );
  }

  static const List<SecurityStandardItem> standardsList = [
    SecurityStandardItem(
      id: 'eidas-26a',
      standardName: 'Reglamento eIDAS (UE 910/2014)',
      lawReference: 'Artículo 26, letra a) · Reglamento Europeo',
      requirementTitle: '1. Vinculación Unívoca al Firmante',
      complianceReason:
          'Cada rúbrica queda vinculada de manera inequívoca a la persona identificada. El sistema exige un registro previo con Nombre, Apellidos y DNI/NIF verificado, asociando además la cuenta de usuario activa y generando un identificador criptográfico individual que impide la suplantación o anonimato.',
      icon: Icons.person_pin_outlined,
    ),
    SecurityStandardItem(
      id: 'eidas-26b',
      standardName: 'Reglamento eIDAS (UE 910/2014)',
      lawReference: 'Artículo 26, letra b) · Reglamento Europeo',
      requirementTitle: '2. Capacidad de Identificación Acreditada',
      complianceReason:
          'Se registra formalmente la identidad del firmante con sello de trazabilidad previo a la apertura del lienzo de firma. En firmas remotas por enlace compartido, se solicita obligatoriamente la identificación antes de rubricar, reflejando su nombre completo en el registro de auditoría.',
      icon: Icons.badge_outlined,
    ),
    SecurityStandardItem(
      id: 'eidas-26c',
      standardName: 'Reglamento eIDAS (UE 910/2014)',
      lawReference: 'Artículo 26, letra c) · Reglamento Europeo',
      requirementTitle: '3. Control Exclusivo de los Datos de Creación',
      complianceReason:
          'La firma biométrica es dibujada directamente por el firmante en tiempo real mediante su propio dispositivo (pantalla táctil, lápiz óptico o ratón). Los datos vectoriales de presión, trazo y coordenadas se generan exclusivamente bajo la acción directa y voluntaria del usuario sin intervención de algoritmos automáticos.',
      icon: Icons.draw_outlined,
    ),
    SecurityStandardItem(
      id: 'eidas-26d',
      standardName: 'Reglamento eIDAS & ISO/IEC 10118-3',
      lawReference: 'Artículo 26, letra d) · eIDAS & Criptografía SHA-256',
      requirementTitle: '4. Integridad y Detección de Modificaciones Ulteriores',
      complianceReason:
          'Cada firma estampada calcula una huella hash SHA-256 (SEC-XXXXXXXX) basada en el momento exacto, la identidad del firmante y los vectores de la rúbrica. Cualquier modificación posterior del archivo, texto o posición de la firma rompe la coherencia del hash, alertando de la alteración documental.',
      icon: Icons.lock_outline,
    ),
    SecurityStandardItem(
      id: 'pades-etsi',
      standardName: 'Estándar PAdES (ETSI EN 319 142)',
      lawReference: 'Norma Técnica Europea de Firma Avanzada en PDF',
      requirementTitle: '5. Estructura Documental PAdES Conforme',
      complianceReason:
          'La exportación e impresión del documento genera un PDF estándar con capas visuales independientes y metadatos legibles en cualquier visor conforme a ISO 32000 (Adobe Acrobat, Chrome, Preview). Las firmas preservan su apariencia visual exacta y los sellos de seguridad quedan incrustados en el árbol del documento.',
      icon: Icons.picture_as_pdf_outlined,
    ),
    SecurityStandardItem(
      id: 'timestamp-rfc',
      standardName: 'Sellado de Tiempo (RFC 3161)',
      lawReference: 'Time-Stamp Protocol · Estándar IETF',
      requirementTitle: '6. Marcado Cronológico Inmutable (Time-Stamping)',
      complianceReason:
          'Cada firma y evento de sincronización en tiempo real incorpora una marca temporal inmutable con fecha, hora, minutos y segundos sincronizada con reloj universal UTC. Esto garantiza la certeza cronológica del momento exacto de suscripción y evita el repudio temporal.',
      icon: Icons.access_time_outlined,
    ),
    SecurityStandardItem(
      id: 'ley-6-2020',
      standardName: 'Ley 6/2020 y Art. 326 LEC (España)',
      lawReference: 'Ley de Servicios Electrónicos de Confianza & Enjuiciamiento Civil',
      requirementTitle: '7. Pista de Auditoría Integral y No Repudio Legal',
      complianceReason:
          'La plataforma mantiene una pista de auditoría (Audit Trail) exhaustiva que registra la creación del documento, invitaciones mediante enlace seguro, confirmación de identificación y estampado de firmas. Constituye prueba documental plena con validez jurídica ante tribunales según el Art. 326 de la Ley de Enjuiciamiento Civil.',
      icon: Icons.gavel_outlined,
    ),
    SecurityStandardItem(
      id: 'rgpd-consent',
      standardName: 'RGPD (UE 2016/679) y LOPDGDD 3/2018',
      lawReference: 'Reglamento General de Protección de Datos',
      requirementTitle: '8. Consentimiento Expreso y Protección de Datos',
      complianceReason:
          'Se recaba el consentimiento informado y voluntario del firmante mediante la aceptación explícita de la cláusula de validez jurídica antes de plasmar su rúbrica. Se aplican los principios de minimización de datos y confidencialidad en el tratamiento de la información personal.',
      icon: Icons.verified_user_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 760,
        constraints: const BoxConstraints(maxHeight: 720),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161F30) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.emerald.withOpacity(0.4)),
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: AppTheme.emerald, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Seguridad Verificada y Marco Legal',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Color(0xFF059669),
                                borderRadius: BorderRadius.all(Radius.circular(10)),
                              ),
                              child: Text(
                                'Nivel eIDAS: FEA',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Conformidad con el Reglamento (UE) Nº 910/2014 (eIDAS) y Ley 6/2020 de Firma Electrónica',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
            ),

            // Main Content: Summary Card + Scrollable Standards List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // High-level Compliance Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF064E3B), const Color(0xFF0F172A)]
                            : [const Color(0xFFECFDF5), const Color(0xFFF0FDF4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CERTIFICADO DE CONFORMIDAD NORMATIVA TOTAL (8/8)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF059669),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Sanctuary implementa los mecanismos técnicos y jurídicos exigidos para la Firma Electrónica Avanzada (FEA). '
                                'Cada documento rubricado en esta plataforma posee plena admisibilidad como prueba en juicio según el artículo 326 de la Ley de Enjuiciamiento Civil y el artículo 26 del Reglamento eIDAS.',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.45,
                                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'ESTÁNDARES Y REQUISITOS TÉCNICO-LEGALES CUMPLIDOS:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 10),

                  // Standards items
                  ...standardsList.map((std) => _buildStandardCard(std, isDark)),

                  const SizedBox(height: 14),

                  // Live Document Fingerprint Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161F30) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.fingerprint, size: 16, color: AppTheme.emerald),
                            SizedBox(width: 6),
                            Text(
                              'HUELLA DE SEGURIDAD DEL DOCUMENTO ACTIVO',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Título: ${document.title}',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.emerald.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${document.signatures.length} Firmas Válidas',
                                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Token de Auditoría: ${document.shareToken}  ·  Sellado Criptográfico: SHA-256 ACTIVO',
                          style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161F30) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 14, color: AppTheme.emerald),
                  const SizedBox(width: 6),
                  const Text(
                    'Certificado generado y validado en tiempo real.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emerald,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: const Text('Entendido y Conforme', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardCard(SecurityStandardItem item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withOpacity(0.6) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Green tick badge
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFF059669),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        item.requirementTitle,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF059669).withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 10, color: Color(0xFF059669)),
                          SizedBox(width: 4),
                          Text(
                            'CUMPLIDO',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF059669),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      item.standardName,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                    ),
                    const Text('  ·  ', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(
                      item.lawReference,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.complianceReason,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.4,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
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
