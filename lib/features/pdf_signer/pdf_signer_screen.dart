import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/trayectoria_sidebar.dart';
import '../../data/services/api_service.dart';
import 'models/signature_document_model.dart';
import 'widgets/signature_canvas_widget.dart';
import 'widgets/signer_identification_dialog.dart';
import 'widgets/share_document_dialog.dart';
import 'widgets/security_standards_dialog.dart';

class PdfSignerScreen extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onBackToHub;
  final VoidCallback? onOpenCvBuilder;
  final VoidCallback onLogout;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleCosmic;
  final bool isDark;
  final bool isCosmicActive;

  const PdfSignerScreen({
    super.key,
    required this.apiService,
    required this.onBackToHub,
    this.onOpenCvBuilder,
    required this.onLogout,
    required this.onToggleTheme,
    required this.onToggleCosmic,
    required this.isDark,
    required this.isCosmicActive,
  });

  @override
  State<PdfSignerScreen> createState() => _PdfSignerScreenState();
}

class _PdfSignerScreenState extends State<PdfSignerScreen> {
  late PdfSignerDocument _document;
  SignerIdentity? _currentIdentity;
  bool _isSidebarCollapsed = false;
  double _zoomScale = 1.0;
  bool _isRefreshing = false;
  Timer? _pollingTimer;

  // Real PDF rendering state
  List<Uint8List> _pdfPageImages = [];
  int _currentPageIndex = 0;
  bool _isRasterizingPdf = false;

  // Dragging state with absolute pointer tracking
  String? _activeDraggingSigId;
  bool _isDraggingSig = false;
  Offset? _dragStartGlobalPointer;
  double _dragStartSigNormX = 0.0;
  double _dragStartSigNormY = 0.0;

  static const double pageA4Width = 595.0;
  static const double pageA4Height = 842.0;
  static const double sigCardWidth = 185.0;
  static const double sigCardHeight = 78.0;

  @override
  void initState() {
    super.initState();
    final user = widget.apiService.storage.getCurrentUser();
    if (user != null) {
      _currentIdentity = SignerIdentity(
        name: user.fullName ?? user.username,
        surname: user.role == 'Docente' ? 'Profesor FC0003' : 'Santuario',
      );
    }

    _document = PdfSignerDocument(
      id: 'doc-${DateTime.now().millisecondsSinceEpoch}',
      title: 'Contrato de Servicios y Gestión Digital · Sanctuary',
      fileName: 'Acuerdo_Prestacion_Servicios_Sanctuary.pdf',
      signatures: [
        PlacedSignature(
          id: 'sig-demo-1',
          signerName: 'Dirección Técnica',
          signerSurname: 'Sanctuary Platform',
          signedAt: DateTime.now().subtract(const Duration(hours: 2)),
          normalizedX: 0.113,
          normalizedY: 0.863,
          pageNumber: 1,
          strokes: _createDefaultStampStrokes(),
        ),
      ],
      notifications: [
        SignerNotification(
          id: 'notif-1',
          signerName: 'Dirección Técnica Sanctuary',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          message: 'Documento original generado y rubricado con sello corporativo.',
        ),
      ],
    );

    // Periodic live sync simulator (refreshes audit log)
    _pollingTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) {
        setState(() {
          _document.updatedAt = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  static List<SignatureStroke> _createDefaultStampStrokes() {
    return [
      const SignatureStroke(
        points: [Offset(20, 40), Offset(40, 20), Offset(70, 50), Offset(100, 15), Offset(140, 45)],
        color: Color(0xFF059669),
        strokeWidth: 3.0,
      ),
      const SignatureStroke(
        points: [Offset(30, 48), Offset(130, 48)],
        color: Color(0xFF059669),
        strokeWidth: 2.0,
      ),
    ];
  }

  Future<void> _pickPdfFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          setState(() {
            _isRasterizingPdf = true;
          });

          List<Uint8List> rasterPages = [];
          try {
            await for (final page in Printing.raster(bytes, dpi: 150)) {
              final png = await page.toPng();
              rasterPages.add(png);
            }
          } catch (err) {
            debugPrint('Error rasterizing PDF: $err');
          }

          setState(() {
            _pdfPageImages = rasterPages;
            _currentPageIndex = 0;
            _isRasterizingPdf = false;
            _document = PdfSignerDocument(
              id: 'doc-${DateTime.now().millisecondsSinceEpoch}',
              title: file.name.replaceAll('.pdf', '').replaceAll('_', ' '),
              fileName: file.name,
              pdfBytes: bytes,
              signatures: [],
              notifications: [
                SignerNotification(
                  id: 'notif-new',
                  signerName: _currentIdentity?.fullName ?? 'Usuario',
                  timestamp: DateTime.now(),
                  message: 'Nuevo PDF adjuntado: ${file.name} (${rasterPages.length} pág.)',
                ),
              ],
            );
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Documento PDF "${file.name}" cargado (${rasterPages.length} págs.).'),
                backgroundColor: AppTheme.emerald,
              ),
            );
          }
        }
      }
    } catch (e) {
      setState(() => _isRasterizingPdf = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al adjuntar archivo PDF: $e')),
        );
      }
    }
  }

  Future<void> _openSignModal() async {
    // 1. If user is not yet identified, prompt identification modal first
    if (_currentIdentity == null || _currentIdentity!.name.isEmpty) {
      final id = await SignerIdentificationDialog.show(context, _currentIdentity);
      if (id == null) return;
      setState(() => _currentIdentity = id);
    }

    if (!mounted) return;

    // 2. Open signature drawing canvas modal
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: SignatureCanvasWidget(
            onCancel: () => Navigator.of(ctx).pop(),
            onSaveSignature: (strokes) {
              Navigator.of(ctx).pop();
              _registerNewSignature(strokes, _currentIdentity!);
            },
          ),
        );
      },
    );
  }

  void _registerNewSignature(List<SignatureStroke> strokes, SignerIdentity identity) {
    final now = DateTime.now();
    double startX;
    double startY;

    if (_pdfPageImages.isNotEmpty) {
      startX = 0.55;
      startY = 0.80;
    } else {
      if (_document.signatures.isEmpty) {
        startX = 0.113;
        startY = 0.863;
      } else if (_document.signatures.length == 1) {
        startX = 0.576;
        startY = 0.863;
      } else {
        final idx = _document.signatures.length;
        startX = (0.10 + (idx % 2) * 0.45).clamp(0.05, 0.65);
        startY = (0.60 + (idx ~/ 2) * 0.12).clamp(0.15, 0.86);
      }
    }

    final targetPage = _pdfPageImages.isNotEmpty ? _currentPageIndex + 1 : 1;

    final newSig = PlacedSignature(
      id: 'sig-${DateTime.now().millisecondsSinceEpoch}',
      signerName: identity.name,
      signerSurname: identity.surname,
      nationalId: identity.nationalId.isNotEmpty ? identity.nationalId : null,
      signedAt: now,
      strokes: strokes,
      normalizedX: startX,
      normalizedY: startY,
      pageNumber: targetPage,
    );

    final notif = SignerNotification(
      id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
      signerName: identity.fullName,
      timestamp: now,
      message: 'Firma plasmada y validada en pág. $targetPage.',
    );

    setState(() {
      _document.signatures.add(newSig);
      _document.notifications.insert(0, notif);
      _document.updatedAt = now;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.verified, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('¡Firma de ${identity.fullName} registrada en tiempo real!'),
            ),
          ],
        ),
        backgroundColor: AppTheme.emerald,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _simulateExternalGuestSigner() async {
    final sampleGuests = [
      const SignerIdentity(name: 'Laura', surname: 'Mendoza Ruiz', nationalId: '48291034K'),
      const SignerIdentity(name: 'Javier', surname: 'Ortiz Delgado', nationalId: '71928340M'),
      const SignerIdentity(name: 'Beatriz', surname: 'Navarro Gil', nationalId: '52019483L'),
    ];

    final guest = sampleGuests[_document.signatures.length % sampleGuests.length];

    // Create realistic signature stroke coordinates
    final guestStrokes = [
      const SignatureStroke(
        points: [
          Offset(20, 35), Offset(35, 18), Offset(55, 42), Offset(75, 12),
          Offset(95, 38), Offset(115, 20), Offset(135, 40),
        ],
        color: Color(0xFF1D4ED8),
        strokeWidth: 3.2,
      ),
      const SignatureStroke(
        points: [Offset(30, 44), Offset(140, 44)],
        color: Color(0xFF1D4ED8),
        strokeWidth: 2.2,
      ),
    ];

    _registerNewSignature(guestStrokes, guest);
  }

  void _manualRefresh() {
    setState(() => _isRefreshing = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _document.updatedAt = DateTime.now();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Documento y firmas sincronizados en tiempo real.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  Future<Uint8List?> _renderSignatureStrokesToPng(
    List<SignatureStroke> strokes, {
    double width = 480,
    double height = 160,
  }) async {
    if (strokes.isEmpty) return null;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
      final painter = _SignatureMiniPainter(strokes: strokes);
      painter.paint(canvas, Size(width, height));
      final picture = recorder.endRecording();
      final image = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error rendering signature strokes to PNG: $e');
      return null;
    }
  }

  Future<void> _exportSignedPdf() async {
    final pdf = pw.Document();

    // 0. Pre-rasterize signature vector strokes to transparent PNG images
    final Map<String, Uint8List> sigImages = {};
    for (final sig in _document.signatures) {
      if (sig.strokes.isNotEmpty) {
        final png = await _renderSignatureStrokesToPng(sig.strokes);
        if (png != null) {
          sigImages[sig.id] = png;
        }
      }
    }

    if (_pdfPageImages.isNotEmpty) {
      // 1. Real Multi-page PDF Export with Placed Signatures
      for (int i = 0; i < _pdfPageImages.length; i++) {
        final pageImg = pw.MemoryImage(_pdfPageImages[i]);
        final pageSigs = _document.signatures.where((s) => s.pageNumber == (i + 1)).toList();

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (pw.Context ctx) {
              return pw.Stack(
                children: [
                  pw.Positioned.fill(
                    child: pw.Image(pageImg, fit: pw.BoxFit.contain),
                  ),
                  ...pageSigs.map((sig) {
                    final posX = (sig.normalizedX * pageA4Width).clamp(0.0, pageA4Width - sigCardWidth);
                    final posY = (sig.normalizedY * pageA4Height).clamp(0.0, pageA4Height - sigCardHeight);
                    final strokePng = sigImages[sig.id];

                    return pw.Positioned(
                      left: posX,
                      top: posY,
                      child: pw.Container(
                        width: sigCardWidth,
                        padding: const pw.EdgeInsets.all(5),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          border: pw.Border.all(color: PdfColors.teal, width: 1.2),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('FIRMA DIGITAL', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                                pw.Text(sig.verificationHash, style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                              ],
                            ),
                            pw.SizedBox(height: 2),
                            pw.Container(
                              height: 36,
                              width: sigCardWidth - 10,
                              alignment: pw.Alignment.center,
                              child: strokePng != null
                                  ? pw.Image(pw.MemoryImage(strokePng), fit: pw.BoxFit.contain)
                                  : pw.Text(
                                      sig.fullName,
                                      style: pw.TextStyle(fontSize: 10, color: PdfColors.blue900, fontStyle: pw.FontStyle.italic),
                                    ),
                            ),
                            pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                            pw.Text(sig.fullName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                            if (sig.nationalId != null)
                              pw.Text('DNI: ${sig.nationalId}', style: const pw.TextStyle(fontSize: 7.0, color: PdfColors.grey700)),
                            pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(sig.signedAt), style: const pw.TextStyle(fontSize: 7.0, color: PdfColors.grey600)),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        );
      }
    } else {
      // 2. Default Contract Template Export
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('SANCTUARY · PLATAFORMA DIGITAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColors.teal)),
                    pw.Text('DOCUMENTO FIRMADO ELECTRÓNICAMENTE', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
                pw.Divider(thickness: 1, color: PdfColors.teal),
                pw.SizedBox(height: 14),

                pw.Text(_document.title.toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Text('Identificador único: ${_document.id} · Token: ${_document.shareToken}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                pw.SizedBox(height: 18),

                pw.Text(
                  'El presente documento certifica la conformidad de las partes intervinientes, habiendo sido validado mediante el sistema de firma biométrica digital de Sanctuary.',
                  style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.4),
                ),
                pw.SizedBox(height: 14),

                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('CLÁUSULA DE CONFORMIDAD Y VALIDEZ ELECTRÓNICA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Las firmas estampadas a continuación representan la voluntad inequívoca de los firmantes identificados con nombres, apellidos y huella criptográfica verificada.',
                        style: const pw.TextStyle(fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
                pw.Spacer(),

                // Signatures Grid
                pw.Text('RÚBRICAS Y FIRMANTES REGISTRADOS:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                pw.SizedBox(height: 10),
                pw.Wrap(
                  spacing: 14,
                  runSpacing: 10,
                  children: _document.signatures.map((sig) {
                    final strokePng = sigImages[sig.id];
                    return pw.Container(
                      width: 240,
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            height: 45,
                            alignment: pw.Alignment.center,
                            child: strokePng != null
                                ? pw.Image(pw.MemoryImage(strokePng), fit: pw.BoxFit.contain)
                                : pw.Text(
                                    sig.fullName,
                                    style: pw.TextStyle(fontSize: 11, color: PdfColors.blue800, fontStyle: pw.FontStyle.italic),
                                  ),
                          ),
                          pw.Divider(thickness: 0.5),
                          pw.Text(sig.fullName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          if (sig.nationalId != null) pw.Text('DNI/NIF: ${sig.nationalId}', style: const pw.TextStyle(fontSize: 8.5)),
                          pw.Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(sig.signedAt)}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                          pw.Text('Sello: ${sig.verificationHash}', style: pw.TextStyle(fontSize: 8, color: PdfColors.teal, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                pw.SizedBox(height: 20),
                pw.Divider(thickness: 0.5),
                pw.Text('Generado y auditado mediante Sanctuary PDF Signer · Validez legal garantizada.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
              ],
            );
          },
        ),
      );
    }

    final bytes = await pdf.save();
    final safeName = _document.fileName.replaceAll('.pdf', '');
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: '${safeName}_firmado.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerMove: (event) {
          if (_isDraggingSig && _activeDraggingSigId != null && _dragStartGlobalPointer != null) {
            final idx = _document.signatures.indexWhere((s) => s.id == _activeDraggingSigId);
            if (idx != -1) {
              final activeSig = _document.signatures[idx];
              final screenDeltaX = event.position.dx - _dragStartGlobalPointer!.dx;
              final screenDeltaY = event.position.dy - _dragStartGlobalPointer!.dy;

              final docDeltaX = screenDeltaX / _zoomScale;
              final docDeltaY = screenDeltaY / _zoomScale;

              final maxNormX = (pageA4Width - sigCardWidth) / pageA4Width;
              final maxNormY = (pageA4Height - sigCardHeight) / pageA4Height;

              final newNormX = (_dragStartSigNormX + (docDeltaX / pageA4Width)).clamp(0.0, maxNormX);
              final newNormY = (_dragStartSigNormY + (docDeltaY / pageA4Height)).clamp(0.0, maxNormY);

              setState(() {
                activeSig.normalizedX = newNormX;
                activeSig.normalizedY = newNormY;
              });
            }
          }
        },
        onPointerUp: (_) {
          if (_isDraggingSig) {
            setState(() {
              _isDraggingSig = false;
              _activeDraggingSigId = null;
              _dragStartGlobalPointer = null;
            });
          }
        },
        onPointerCancel: (_) {
          if (_isDraggingSig) {
            setState(() {
              _isDraggingSig = false;
              _activeDraggingSigId = null;
              _dragStartGlobalPointer = null;
            });
          }
        },
        child: Row(
          children: [
            // 1. Collapsible Sanctuary Sidebar
            TrayectoriaSidebar(
              isDark: isDark,
              isCollapsed: _isSidebarCollapsed,
              activeItem: 'PdfSigner',
              onSelect: (item) {
                if (item == 'Inicio') {
                  widget.onBackToHub();
                } else if (item == 'Orientación') {
                  if (widget.onOpenCvBuilder != null) {
                    widget.onOpenCvBuilder!();
                  } else {
                    widget.onBackToHub();
                  }
                }
              },
              onToggleCollapse: () {
                setState(() => _isSidebarCollapsed = !_isSidebarCollapsed);
              },
            ),

            // 2. Main PDF Signer Workspace
            Expanded(
              child: Column(
                children: [
                  // Top App Navigation Bar
                  _buildTopBar(isDark),

                  // Main Workspace Layout
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWideScreen = constraints.maxWidth > 960;

                        return Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Document Sheet & Viewer Area
                              Expanded(
                                flex: 14,
                                child: _buildDocumentCanvas(isDark),
                              ),

                              // Audit Trail Sidebar (for wide screens)
                              if (isWideScreen) ...[
                                const SizedBox(width: 14),
                                Expanded(
                                  flex: 6,
                                  child: _buildAuditSidebar(isDark, dateFormat),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
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

  Widget _buildTopBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D121D).withOpacity(0.85) : Colors.white.withOpacity(0.9),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back Button to Hub
          InkWell(
            onTap: widget.onBackToHub,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, size: 16),
                  SizedBox(width: 6),
                  Text('Santuario (Hub)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Document Title and Status Badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _document.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.emerald.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.circle, size: 7, color: AppTheme.emerald),
                          const SizedBox(width: 4),
                          Text(
                            '${_document.signatures.length} Firmas',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  _pdfPageImages.isNotEmpty
                      ? '${_document.fileName} · ${_pdfPageImages.length} pág.'
                      : _document.fileName,
                  style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          // Verified Security Standards Button (eIDAS / PAdES / RFC 3161)
          ElevatedButton.icon(
            onPressed: () => SecurityStandardsDialog.show(context, _document),
            icon: const Icon(Icons.verified_user_rounded, size: 15, color: Colors.white),
            label: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Seguridad Verificada', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                SizedBox(width: 5),
                Icon(Icons.check_circle, size: 13, color: Colors.white),
              ],
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),

          // Action Buttons: Attach, Sign, Share, Save
          ElevatedButton.icon(
            onPressed: _pickPdfFile,
            icon: const Icon(Icons.upload_file_outlined, size: 15),
            label: const Text('Adjuntar PDF', style: TextStyle(fontSize: 11.5)),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              foregroundColor: isDark ? Colors.white : Colors.black87,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
              ),
            ),
          ),
          const SizedBox(width: 8),

          ElevatedButton.icon(
            onPressed: _openSignModal,
            icon: const Icon(Icons.draw_outlined, size: 15),
            label: const Text('Firmar Documento', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 8),

          ElevatedButton.icon(
            onPressed: () => ShareDocumentDialog.show(
              context,
              _document,
              onSimulateGuestSigner: _simulateExternalGuestSigner,
            ),
            icon: const Icon(Icons.share_outlined, size: 15),
            label: const Text('Compartir', style: TextStyle(fontSize: 11.5)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 8),

          ElevatedButton.icon(
            onPressed: _exportSignedPdf,
            icon: const Icon(Icons.download_rounded, size: 15),
            label: const Text('Descargar Firmado', style: TextStyle(fontSize: 11.5)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 12),

          // Theme and Cosmic toggles
          IconButton(
            icon: Icon(widget.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 19),
            tooltip: 'Cambiar tema',
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: Icon(widget.isCosmicActive ? Icons.auto_awesome : Icons.blur_off, size: 19),
            tooltip: 'Animación cósmica',
            onPressed: widget.onToggleCosmic,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCanvas(bool isDark) {
    final activeSignatures = _pdfPageImages.isNotEmpty
        ? _document.signatures.where((s) => s.pageNumber == _currentPageIndex + 1).toList()
        : _document.signatures;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard.withOpacity(0.9) : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Column(
        children: [
          // Toolbar: Zoom, Page Info & Multi-page controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
            ),
            child: Row(
              children: [
                Icon(
                  _pdfPageImages.isNotEmpty ? Icons.picture_as_pdf : Icons.description_outlined,
                  size: 16,
                  color: AppTheme.emerald,
                ),
                const SizedBox(width: 8),
                if (_pdfPageImages.isNotEmpty) ...[
                  Text(
                    'Página ${_currentPageIndex + 1} de ${_pdfPageImages.length}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 18),
                    tooltip: 'Página anterior',
                    onPressed: _currentPageIndex > 0
                        ? () => setState(() => _currentPageIndex--)
                        : null,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 18),
                    tooltip: 'Página siguiente',
                    onPressed: _currentPageIndex < _pdfPageImages.length - 1
                        ? () => setState(() => _currentPageIndex++)
                        : null,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  ),
                ] else ...[
                  const Text(
                    'Plantilla Contractual Digital · Sanctuary A4',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove, size: 16),
                  tooltip: 'Reducir zoom',
                  onPressed: () => setState(() => _zoomScale = (_zoomScale - 0.1).clamp(0.7, 1.4)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
                Text('${(_zoomScale * 100).toInt()}%', style: const TextStyle(fontSize: 11)),
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  tooltip: 'Aumentar zoom',
                  onPressed: () => setState(() => _zoomScale = (_zoomScale + 0.1).clamp(0.7, 1.4)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          ),

          // Document Sheet Area
          Expanded(
            child: SingleChildScrollView(
              physics: _isDraggingSig
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Center(
                child: Transform.scale(
                  scale: _zoomScale,
                  alignment: Alignment.topCenter,
                  child: _isRasterizingPdf
                      ? Container(
                          width: pageA4Width,
                          height: pageA4Height,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8)),
                            ],
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: AppTheme.emerald),
                                SizedBox(height: 16),
                                Text('Procesando y renderizando páginas del PDF...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              ],
                            ),
                          ),
                        )
                      : Container(
                          width: pageA4Width,
                          height: pageA4Height,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Stack(
                              children: [
                                // Document Body: real PDF page image or contract layout
                                if (_pdfPageImages.isNotEmpty)
                                  Positioned.fill(
                                    child: Image.memory(
                                      _pdfPageImages[_currentPageIndex],
                                      fit: BoxFit.contain,
                                    ),
                                  )
                                else
                                  Positioned.fill(
                                    child: Padding(
                                      padding: const EdgeInsets.all(32),
                                      child: _buildContractDocumentBody(),
                                    ),
                                  ),

                                // Embedded Placed Signatures Overlay for current page
                                ...activeSignatures.map((sig) => _buildDraggableSignatureWidget(sig)),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContractDocumentBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SANCTUARY DIGITAL ECOSYSTEM',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.teal.shade800, letterSpacing: 1.0),
                ),
                const SizedBox(height: 2),
                const Text('Gestión Documental y Certificación de Firmas Electrónicas', style: TextStyle(fontSize: 8.5, color: Colors.grey)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.teal.shade700),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'VALIDEZ DIGITAL',
                style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(height: 1.5, color: Colors.teal.shade700),
        const SizedBox(height: 18),

        // Document Title
        Center(
          child: Text(
            _document.title.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
        ),
        const SizedBox(height: 14),

        const Text(
          'En el marco del marco normativo aplicable a la digitalización documental y rúbrica digital certificada, se formaliza el presente documento entre las partes:',
          style: TextStyle(fontSize: 9.2, color: Color(0xFF334155), height: 1.4),
        ),
        const SizedBox(height: 10),

        _buildContractClause('1. OBJETO Y ALCANCE', 'El firmante manifiesta su conformidad respecto al contenido, acuerdos y compromisos formalizados en el presente instrumento, autorizando el registro de su rúbrica digitalizada con sellado de tiempo y trazabilidad.'),
        const SizedBox(height: 6),

        _buildContractClause('2. INTEGRIDAD Y AUDITORÍA', 'Cada rúbrica registrada incorpora una clave de verificación criptográfica única, asociando de forma inequívoca la identidad, fecha, hora y coordenadas del trazo en el documento.'),
        const SizedBox(height: 6),

        _buildContractClause('3. SINCRONIZACIÓN EN TIEMPO REAL', 'Cualquier firma estampada mediante enlace seguro se consolida en la presente copia matriz, garantizando la concurrencia e inalterabilidad de los firmantes acreditados.'),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, size: 15, color: Color(0xFF059669)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Este documento cuenta con protección de sellado de tiempo. Toda modificación posterior invalidará el hash de auditoría.',
                  style: TextStyle(fontSize: 8.2, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // Signature Zones Designation
        const Text(
          'ESPACIO RESERVADO PARA RÚBRICAS Y SELLOS DIGITALES:',
          style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 82,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFFF8FAFC),
                ),
                child: const Center(
                  child: Text(
                    'ZONA DE FIRMA 1 · EMISOR\n(Dirección Técnica)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 8.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Container(
                height: 82,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFFF8FAFC),
                ),
                child: const Center(
                  child: Text(
                    'ZONA DE FIRMA 2 · DESTINATARIO\n(Interesado / Alumno)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 8.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildContractClause(String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 9.2, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        const SizedBox(height: 2),
        Text(body, style: const TextStyle(fontSize: 8.6, color: Color(0xFF475569), height: 1.35)),
      ],
    );
  }

  Widget _buildDraggableSignatureWidget(PlacedSignature sig) {
    final isDraggingThis = _activeDraggingSigId == sig.id;

    // Direct pixel position on the 595 x 842 canvas
    final posX = (sig.normalizedX * pageA4Width).clamp(0.0, pageA4Width - sigCardWidth);
    final posY = (sig.normalizedY * pageA4Height).clamp(0.0, pageA4Height - sigCardHeight);

    return Positioned(
      left: posX,
      top: posY,
      child: MouseRegion(
        cursor: isDraggingThis ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
        child: Listener(
          onPointerDown: (event) {
            setState(() {
              _activeDraggingSigId = sig.id;
              _isDraggingSig = true;
              _dragStartGlobalPointer = event.position;
              _dragStartSigNormX = sig.normalizedX;
              _dragStartSigNormY = sig.normalizedY;
            });
          },
          child: AnimatedContainer(
            duration: isDraggingThis ? Duration.zero : const Duration(milliseconds: 100),
            width: sigCardWidth,
            height: sigCardHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.97),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDraggingThis ? const Color(0xFF2563EB) : const Color(0xFF059669),
                width: isDraggingThis ? 2.2 : 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDraggingThis ? const Color(0xFF2563EB) : const Color(0xFF059669)).withOpacity(isDraggingThis ? 0.40 : 0.18),
                  blurRadius: isDraggingThis ? 16 : 8,
                  offset: isDraggingThis ? const Offset(0, 6) : const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle bar + Delete button
                Row(
                  children: [
                    Icon(
                      Icons.drag_indicator,
                      size: 11,
                      color: isDraggingThis ? const Color(0xFF2563EB) : const Color(0xFF059669),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        isDraggingThis
                            ? 'MOVIENDO · ${(sig.normalizedX * 100).toInt()}% x ${(sig.normalizedY * 100).toInt()}%'
                            : 'FIRMA DIGITAL',
                        style: TextStyle(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                          color: isDraggingThis ? const Color(0xFF2563EB) : const Color(0xFF059669),
                          letterSpacing: 0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() {
                          _document.signatures.removeWhere((s) => s.id == sig.id);
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(2.0),
                        child: Icon(Icons.close, size: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),

                // Signature vector strokes strictly scaled and fitted
                Expanded(
                  child: ClipRect(
                    child: CustomPaint(
                      painter: _SignatureMiniPainter(strokes: sig.strokes),
                      size: const Size(double.infinity, double.infinity),
                    ),
                  ),
                ),

                const SizedBox(height: 2),
                Container(height: 0.6, color: const Color(0xFF059669).withOpacity(0.4)),
                const SizedBox(height: 2),

                // Signer name and verification badge
                Row(
                  children: [
                    const Icon(Icons.verified, size: 10, color: Color(0xFF059669)),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        sig.fullName,
                        style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      sig.verificationHash,
                      style: const TextStyle(fontSize: 7.0, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuditSidebar(bool isDark, DateFormat dateFormat) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard.withOpacity(0.9) : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sidebar Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.history, size: 16, color: AppTheme.emerald),
                const SizedBox(width: 8),
                const Text('Auditoría y Firmantes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: _isRefreshing
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.emerald))
                      : const Icon(Icons.refresh, size: 16),
                  tooltip: 'Refrescar auditoría',
                  onPressed: _manualRefresh,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Security Standards Compliance Button Card
          InkWell(
            onTap: () => SecurityStandardsDialog.show(context, _document),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.fromLTRB(10, 10, 10, 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF059669).withOpacity(0.18),
                    const Color(0xFF047857).withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Seguridad Verificada', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('eIDAS 100%', style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text('PAdES · RFC 3161 · Ley 6/2020', style: TextStyle(fontSize: 8.5, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: Color(0xFF10B981)),
                ],
              ),
            ),
          ),

          // Real-time notification banner
          if (_document.notifications.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.emerald.withOpacity(0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notifications_active, color: AppTheme.emerald, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Última actividad · ${_document.notifications.first.signerName}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _document.notifications.first.message,
                          style: const TextStyle(fontSize: 10.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateFormat.format(_document.notifications.first.timestamp),
                          style: const TextStyle(fontSize: 9, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Signers List Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Firmantes Acreditados (${_document.signatures.length})', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: _simulateExternalGuestSigner,
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: const Text('+ Simular', style: TextStyle(fontSize: 11, color: AppTheme.emerald)),
                ),
              ],
            ),
          ),

          // Signers List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: _document.signatures.length,
              itemBuilder: (ctx, i) {
                final sig = _document.signatures[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161F30) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withOpacity(0.16),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: AppTheme.emerald, size: 14),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${sig.fullName} (Pág. ${sig.pageNumber})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            if (sig.nationalId != null)
                              Text('DNI/NIF: ${sig.nationalId}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(
                              dateFormat.format(sig.signedAt),
                              style: const TextStyle(fontSize: 9.5, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sig.verificationHash,
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Document Metadata Footer
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_outline, size: 14, color: AppTheme.emerald),
                    const SizedBox(width: 6),
                    const Text('Certificado SHA-256 Activo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('En Línea', style: TextStyle(fontSize: 9, color: Colors.teal, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Token: ${_document.shareToken}',
                  style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignatureMiniPainter extends CustomPainter {
  final List<SignatureStroke> strokes;

  _SignatureMiniPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty) return;

    // 1. Strictly clip to size so strokes NEVER bleed outside
    canvas.clipRect(Offset.zero & size);

    // 2. Calculate true vector bounding box
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final stroke in strokes) {
      for (final p in stroke.points) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
    }

    if (!minX.isFinite || !maxX.isFinite || !minY.isFinite || !maxY.isFinite) return;

    final origW = (maxX - minX).clamp(1.0, double.infinity);
    final origH = (maxY - minY).clamp(1.0, double.infinity);

    // 4px margin so strokes sit comfortably inside the box
    const margin = 4.0;
    final targetW = size.width - (margin * 2);
    final targetH = size.height - (margin * 2);

    final scaleX = targetW / origW;
    final scaleY = targetH / origH;
    final scale = math.min(scaleX, scaleY).clamp(0.05, 10.0);

    final scaledW = origW * scale;
    final scaledH = origH * scale;
    final offsetX = margin + (targetW - scaledW) / 2 - (minX * scale);
    final offsetY = margin + (targetH - scaledH) / 2 - (minY * scale);

    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = (stroke.strokeWidth * scale * 0.85).clamp(1.2, 5.0)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length > 1) {
        final path = Path();
        final first = stroke.points.first;
        path.moveTo(first.dx * scale + offsetX, first.dy * scale + offsetY);
        for (int i = 1; i < stroke.points.length; i++) {
          final pt = stroke.points[i];
          path.lineTo(pt.dx * scale + offsetX, pt.dy * scale + offsetY);
        }
        canvas.drawPath(path, paint);
      } else if (stroke.points.length == 1) {
        final p = stroke.points.first;
        canvas.drawCircle(
          Offset(p.dx * scale + offsetX, p.dy * scale + offsetY),
          (stroke.strokeWidth * scale * 0.85).clamp(1.2, 3.2) / 2,
          paint..style = PaintingStyle.fill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignatureMiniPainter oldDelegate) => true;
}
