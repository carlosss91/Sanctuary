import 'dart:math' as math;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../../../core/theme/app_theme.dart';
import '../models/signature_document_model.dart';
import 'signature_image_cropper_widget.dart';
import 'signer_identification_dialog.dart';

class SignatureCanvasWidget extends StatefulWidget {
  final SignerIdentity? initialIdentity;
  final String? initialSignerName;
  final void Function({
    List<SignatureStroke>? strokes,
    Uint8List? imageBytes,
    SignerIdentity? updatedIdentity,
  }) onSaveSignature;
  final VoidCallback? onCancel;

  const SignatureCanvasWidget({
    super.key,
    required this.onSaveSignature,
    this.initialIdentity,
    this.initialSignerName,
    this.onCancel,
  });

  @override
  State<SignatureCanvasWidget> createState() => _SignatureCanvasWidgetState();
}

class _SignatureCanvasWidgetState extends State<SignatureCanvasWidget> {
  // Signer Identity Controllers
  late TextEditingController _signerNameController;
  late TextEditingController _dniController;

  // Mode: 'draw' (vector strokes) | 'image' (attached & cropped image)
  String _activeMode = 'draw';

  // Drawing state
  final List<SignatureStroke> _strokes = [];
  List<Offset> _currentPoints = [];
  Color _selectedColor = const Color(0xFF1D4ED8); // Default notary blue
  double _strokeWidth = 3.5;
  String _activeTool = 'pen'; // 'pen' | 'ballpoint' | 'highlighter'

  @override
  void initState() {
    super.initState();
    final prefill = (widget.initialIdentity?.fullName.trim().isNotEmpty ?? false)
        ? widget.initialIdentity!.fullName.trim()
        : (widget.initialSignerName?.trim() ?? '');
    _signerNameController = TextEditingController(text: prefill);
    _dniController = TextEditingController(text: widget.initialIdentity?.nationalId.trim() ?? '');
    _signerNameController.addListener(_onFieldChanged);
    _dniController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _signerNameController.removeListener(_onFieldChanged);
    _dniController.removeListener(_onFieldChanged);
    _signerNameController.dispose();
    _dniController.dispose();
    super.dispose();
  }

  void _submitSignature({List<SignatureStroke>? strokes, Uint8List? imageBytes}) {
    final rawName = _signerNameController.text.trim();
    if (rawName.isEmpty) return;

    final rawDni = _dniController.text.trim();
    String name = rawName;
    String surname = '';
    final spaceIdx = rawName.indexOf(' ');
    if (spaceIdx > 0) {
      name = rawName.substring(0, spaceIdx).trim();
      surname = rawName.substring(spaceIdx + 1).trim();
    }

    final identity = SignerIdentity(
      name: name,
      surname: surname,
      nationalId: rawDni.isNotEmpty
          ? rawDni
          : (widget.initialIdentity?.nationalId ?? ''),
    );

    widget.onSaveSignature(
      strokes: strokes,
      imageBytes: imageBytes,
      updatedIdentity: identity,
    );
  }

  // Image attachment state
  Uint8List? _uploadedRawBytes;
  Uint8List? _croppedSignatureBytes;
  bool _isCropping = false;
  bool _isPickingImage = false;

  final List<Color> _colorPalette = const [
    Color(0xFF1D4ED8), // Azul Notarial
    Color(0xFF0F172A), // Negro Carbón
    Color(0xFF059669), // Verde Esmeralda
    Color(0xFFDC2626), // Rojo Carmesí
    Color(0xFF7C3AED), // Púrpura Real
    Color(0xFFD97706), // Ámbar Dorado
  ];

  // --- Drawing Handlers ---
  void _onPanStart(DragStartDetails details) {
    final pt = Offset(
      details.localPosition.dx.clamp(4.0, 580.0),
      details.localPosition.dy.clamp(4.0, 216.0),
    );
    setState(() {
      _currentPoints = [pt];
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final pt = Offset(
      details.localPosition.dx.clamp(4.0, 580.0),
      details.localPosition.dy.clamp(4.0, 216.0),
    );
    setState(() {
      _currentPoints.add(pt);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentPoints.isNotEmpty) {
      final effectiveColor = _activeTool == 'highlighter'
          ? _selectedColor.withOpacity(0.35)
          : _selectedColor;
      final effectiveWidth = _activeTool == 'highlighter'
          ? _strokeWidth * 3.2
          : (_activeTool == 'ballpoint' ? 2.0 : _strokeWidth);

      setState(() {
        _strokes.add(SignatureStroke(
          points: List.from(_currentPoints),
          color: effectiveColor,
          strokeWidth: effectiveWidth,
        ));
        _currentPoints = [];
      });
    }
  }

  void _undoLastStroke() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _strokes.removeLast();
      });
    }
  }

  void _clearAllStrokes() {
    setState(() {
      _strokes.clear();
      _currentPoints.clear();
    });
  }

  // --- Image Picking Handler ---
  Future<void> _pickImageFile() async {
    try {
      setState(() => _isPickingImage = true);
      final files = await FilePicker.pickFiles(
        type: FileType.image,
      );

      if (files.isNotEmpty) {
        final pickedFile = files.first;
        final bytes = await pickedFile.readAsBytes();
        if (bytes.isNotEmpty) {
          setState(() {
            _uploadedRawBytes = bytes;
            _croppedSignatureBytes = null;
            _isCropping = true;
          });
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se seleccionó ninguna imagen o el archivo estaba vacío.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error seleccionando imagen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir la imagen: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  void _loadSampleSignature() {
    // Generate an authentic sample rubric on white paper for immediate preview & test
    final sample = img.Image(width: 800, height: 350);
    img.fill(sample, color: img.ColorRgb8(248, 249, 252)); // off-white paper

    final ink = img.ColorRgba8(20, 50, 130, 255); // notary blue ink

    void drawSegment(int x0, int y0, int x1, int y1) {
      img.drawLine(sample, x1: x0, y1: y0, x2: x1, y2: y1, color: ink, thickness: 3);
    }

    // Curvature rubric
    for (int t = 0; t < 560; t += 3) {
      final double angle = t * 0.045;
      final int x = 120 + t;
      final int y = (175 + math.sin(angle) * 48 + math.cos(angle * 2.1) * 22).round();
      if (t > 0) {
        final double prevAngle = (t - 3) * 0.045;
        final int prevX = 120 + (t - 3);
        final int prevY = (175 + math.sin(prevAngle) * 48 + math.cos(prevAngle * 2.1) * 22).round();
        drawSegment(prevX, prevY, x, y);
      }
    }
    // Decorative underline
    drawSegment(100, 255, 700, 240);
    drawSegment(210, 275, 630, 260);
    // Initial loop
    drawSegment(130, 110, 160, 270);
    drawSegment(160, 270, 210, 120);

    final jpgBytes = Uint8List.fromList(img.encodeJpg(sample, quality: 90));
    setState(() {
      _uploadedRawBytes = jpgBytes;
      _croppedSignatureBytes = null;
      _isCropping = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(maxWidth: 620),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _activeMode == 'draw' ? Icons.draw_outlined : Icons.add_photo_alternate_outlined,
                    color: AppTheme.emerald,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estampar Firma Digital',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _activeMode == 'draw'
                            ? 'Dibuja con precisión tu firma en el recuadro'
                            : 'Adjunta una fotografía o escaneo de tu firma',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (widget.onCancel != null)
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Cerrar',
                    visualDensity: VisualDensity.compact,
                    splashRadius: 20,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Signer Identity Input (Editable name and optional ID)
          _buildSignerNameInput(isDark),

          // Mode Selector (Firmar a mano vs Adjuntar Imagen)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'draw',
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Firmar a mano', maxLines: 1),
                    ),
                    icon: Icon(Icons.gesture, size: 15),
                  ),
                  ButtonSegment(
                    value: 'image',
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Adjuntar Imagen', maxLines: 1),
                    ),
                    icon: Icon(Icons.crop_original_rounded, size: 15),
                  ),
                ],
                selected: {_activeMode},
                onSelectionChanged: (val) {
                  setState(() => _activeMode = val.first);
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                ),
              ),
            ),
          ),

          // Body Content depending on Mode
          if (_activeMode == 'draw') ...[
            _buildDrawModeContent(isDark),
          ] else ...[
            _buildImageModeContent(isDark),
          ],
        ],
      ),
    );
  }

  // =========================================================
  // DRAW MODE
  // =========================================================
  Widget _buildDrawModeContent(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tools and Color Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Tool selection
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'pen',
                    label: FittedBox(fit: BoxFit.scaleDown, child: Text('Pluma', maxLines: 1)),
                    icon: Icon(Icons.edit, size: 14),
                  ),
                  ButtonSegment(
                    value: 'ballpoint',
                    label: FittedBox(fit: BoxFit.scaleDown, child: Text('Boli', maxLines: 1)),
                    icon: Icon(Icons.border_color, size: 14),
                  ),
                  ButtonSegment(
                    value: 'highlighter',
                    label: FittedBox(fit: BoxFit.scaleDown, child: Text('Marcador', maxLines: 1)),
                    icon: Icon(Icons.brush, size: 14),
                  ),
                ],
                selected: {_activeTool},
                onSelectionChanged: (val) {
                  setState(() => _activeTool = val.first);
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 7, vertical: 4)),
                ),
              ),

              // Color palette
              Row(
                mainAxisSize: MainAxisSize.min,
                children: _colorPalette.map((col) {
                  final isSel = _selectedColor.value == col.value;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = col),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: col,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel ? Colors.white : Colors.transparent,
                          width: 2.2,
                        ),
                        boxShadow: [
                          if (isSel)
                            BoxShadow(
                              color: col.withOpacity(0.5),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                        ],
                      ),
                      child: isSel
                          ? const Center(child: Icon(Icons.check, size: 14, color: Colors.white))
                          : null,
                    ),
                  );
                }).toList(),
              ),

              // Thickness presets
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildThicknessChip('Fino', 2.0),
                  const SizedBox(width: 4),
                  _buildThicknessChip('Medio', 3.5),
                  const SizedBox(width: 4),
                  _buildThicknessChip('Grueso', 5.5),
                ],
              ),
            ],
          ),
        ),

        // Interactive Drawing Pad
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Container(
            height: 210,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161F30) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  // Baseline dotted line for signature guidance
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 44,
                    child: Row(
                      children: List.generate(
                        30,
                        (i) => Expanded(
                          child: Container(
                            height: 1.2,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    bottom: 24,
                    child: Text(
                      'Firma de: ${_signerNameController.text.trim().isEmpty ? "Interesado / Signer" : _signerNameController.text.trim()}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                  // Gesture canvas
                  GestureDetector(
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    child: CustomPaint(
                      painter: _SignaturePainter(
                        strokes: _strokes,
                        currentPoints: _currentPoints,
                        currentColor: _selectedColor,
                        currentWidth: _strokeWidth,
                      ),
                      size: Size.infinite,
                    ),
                  ),

                  if (_strokes.isEmpty && _currentPoints.isEmpty)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.gesture, size: 28, color: Colors.grey.withOpacity(0.4)),
                          const SizedBox(height: 6),
                          Text(
                            'Firma aquí con el ratón, lápiz o dedo',
                            style: TextStyle(fontSize: 12, color: Colors.grey.withOpacity(0.6)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Bottom Actions for Draw Mode
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _strokes.isEmpty ? null : _undoLastStroke,
                icon: const Icon(Icons.undo, size: 14),
                label: const Text('Deshacer', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: _strokes.isEmpty ? null : _clearAllStrokes,
                icon: const Icon(Icons.delete_outline, size: 14),
                label: const Text('Borrar', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: (_strokes.isEmpty || _signerNameController.text.trim().isEmpty)
                    ? null
                    : () {
                        _submitSignature(strokes: _strokes);
                      },
                icon: const Icon(Icons.check_circle_outline, size: 15),
                label: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================
  // IMAGE ATTACH & CROP MODE
  // =========================================================
  Widget _buildImageModeContent(bool isDark) {
    // 1. Cropping view active
    if (_isCropping && _uploadedRawBytes != null) {
      return SignatureImageCropperWidget(
        rawImageBytes: _uploadedRawBytes!,
        onCropDone: (croppedBytes) {
          setState(() {
            _croppedSignatureBytes = croppedBytes;
            _isCropping = false;
          });
        },
        onCancel: () {
          setState(() {
            _isCropping = false;
          });
        },
      );
    }

    // 2. Cropped preview ready
    if (_croppedSignatureBytes != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.verified, size: 16, color: AppTheme.emerald),
                const SizedBox(width: 6),
                const Text(
                  'Firma recortada y procesada con éxito:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.emerald.withOpacity(0.4)),
                  ),
                  child: const Text('Fondo Transparente Activo', style: TextStyle(fontSize: 10, color: AppTheme.emerald, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // Cropped Signature Preview Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161F30) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  width: 1.5,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Dotted baseline
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 40,
                    child: Row(
                      children: List.generate(
                        30,
                        (i) => Expanded(
                          child: Container(
                            height: 1.2,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    bottom: 20,
                    child: Text(
                      'Firma de: ${_signerNameController.text.trim().isEmpty ? "Interesado / Signer" : _signerNameController.text.trim()} (Imagen recortada)',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                  // Signature Image Preview
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 16, 28, 48),
                    child: Center(
                      child: Image.memory(
                        _croppedSignatureBytes!,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom actions for Cropped Preview
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _isCropping = true),
                  icon: const Icon(Icons.crop, size: 14),
                  label: const Text('Reajustar', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: _pickImageFile,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Cambiar', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: (_croppedSignatureBytes == null || _signerNameController.text.trim().isEmpty)
                      ? null
                      : () {
                          _submitSignature(imageBytes: _croppedSignatureBytes);
                        },
                  icon: const Icon(Icons.check_circle_outline, size: 15),
                  label: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // 3. No image uploaded yet -> Upload drop zone
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161F30).withOpacity(0.5) : const Color(0xFFF1F5F9).withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            style: BorderStyle.solid,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_photo_alternate_rounded,
                size: 38,
                color: AppTheme.emerald,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Cargar Fotografía o Escaneo de Firma',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sube una fotografía de tu firma manuscrita sobre papel blanco o transparente.\nFormatos admitidos: PNG, JPG, JPEG, WEBP.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 18),

            // Pick Button
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: _isPickingImage ? null : _pickImageFile,
                  icon: _isPickingImage
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.file_upload_outlined, size: 18),
                  label: Text(
                    _isPickingImage ? 'Abriendo selector...' : 'Seleccionar Archivo de Firma',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _loadSampleSignature,
                  icon: const Icon(Icons.draw_outlined, size: 16),
                  label: const Text('Probar con rúbrica de ejemplo', style: TextStyle(fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.emerald.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: AppTheme.emerald),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Incluye herramienta para recortar la rúbrica exacta y eliminar el fondo blanco del papel de forma automática.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
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

  Widget _buildThicknessChip(String label, double width) {
    final isSel = (_strokeWidth == width);
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      selected: isSel,
      selectedColor: AppTheme.emerald.withOpacity(0.25),
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => _strokeWidth = width),
    );
  }

  Widget _buildSignerNameInput(bool isDark) {
    final hasName = _signerNameController.text.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withOpacity(0.65) : const Color(0xFFF1F5F9).withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: !hasName
              ? Colors.amber.withOpacity(0.8)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.badge_outlined, size: 14, color: AppTheme.emerald),
              ),
              const SizedBox(width: 8),
              const Text(
                'NOMBRE DEL FIRMANTE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppTheme.emerald,
                ),
              ),
              const Spacer(),
              Text(
                'Aparecerá en el sello oficial',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  child: TextField(
                    controller: _signerNameController,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Nombre y apellidos (ej. Juan Pérez)',
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.normal),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      prefixIcon: Icon(Icons.edit_outlined, size: 15, color: Colors.grey),
                      prefixIconConstraints: BoxConstraints(minWidth: 26, minHeight: 0),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: TextField(
                    controller: _dniController,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'DNI / NIF (opc.)',
                      hintStyle: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.normal),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      prefixIcon: Icon(Icons.numbers_outlined, size: 14, color: Colors.grey),
                      prefixIconConstraints: BoxConstraints(minWidth: 24, minHeight: 0),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (!hasName) ...[
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 13, color: Colors.amber),
                SizedBox(width: 4),
                Text(
                  'Indica el nombre del firmante para habilitar el guardado de la firma.',
                  style: TextStyle(fontSize: 10.5, color: Colors.amber, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<SignatureStroke> strokes;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentWidth;

  _SignaturePainter({
    required this.strokes,
    required this.currentPoints,
    required this.currentColor,
    required this.currentWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);

    // 1. Draw saved strokes
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length > 1) {
        final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
        }
        canvas.drawPath(path, paint);
      } else if (stroke.points.length == 1) {
        canvas.drawCircle(stroke.points.first, stroke.strokeWidth / 2, paint..style = PaintingStyle.fill);
      }
    }

    // 2. Draw currently active stroke
    if (currentPoints.length > 1) {
      final currentPaint = Paint()
        ..color = currentColor
        ..strokeWidth = currentWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path()..moveTo(currentPoints.first.dx, currentPoints.first.dy);
      for (int i = 1; i < currentPoints.length; i++) {
        path.lineTo(currentPoints[i].dx, currentPoints[i].dy);
      }
      canvas.drawPath(path, currentPaint);
    } else if (currentPoints.length == 1) {
      final dotPaint = Paint()
        ..color = currentColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(currentPoints.first, currentWidth / 2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
