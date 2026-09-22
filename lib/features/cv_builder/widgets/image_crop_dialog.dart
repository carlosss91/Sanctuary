import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ImageCropResult {
  final Uint8List? croppedBytes;
  final String shape; // 'circle' | 'square'
  final double zoom;
  final double panX;
  final double panY;

  const ImageCropResult({
    this.croppedBytes,
    required this.shape,
    this.zoom = 1.0,
    this.panX = 0.0,
    this.panY = 0.0,
  });

  Uint8List get effectiveBytes => croppedBytes ?? Uint8List(0);
}

class ImageCropDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final String initialShape;
  final double initialZoom;
  final double initialPanX;
  final double initialPanY;

  const ImageCropDialog({
    super.key,
    required this.imageBytes,
    this.initialShape = 'circle',
    this.initialZoom = 1.0,
    this.initialPanX = 0.0,
    this.initialPanY = 0.0,
  });

  static Future<ImageCropResult?> show(
    BuildContext context, {
    required Uint8List imageBytes,
    String initialShape = 'circle',
    double initialZoom = 1.0,
    double initialPanX = 0.0,
    double initialPanY = 0.0,
  }) {
    return showDialog<ImageCropResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ImageCropDialog(
        imageBytes: imageBytes,
        initialShape: initialShape,
        initialZoom: initialZoom,
        initialPanX: initialPanX,
        initialPanY: initialPanY,
      ),
    );
  }

  @override
  State<ImageCropDialog> createState() => _ImageCropDialogState();
}

class _ImageCropDialogState extends State<ImageCropDialog> {
  static const double frameSize = 220.0;
  static const double viewportWidth = 400.0;
  static const double viewportHeight = 320.0;

  late String _shape;
  double _zoom = 1.0;
  double _panPixelX = 0.0;
  double _panPixelY = 0.0;

  ui.Image? _decodedImage;
  bool _isLoadingImage = true;
  bool _isProcessingCrop = false;

  @override
  void initState() {
    super.initState();
    _shape = widget.initialShape;
    _zoom = widget.initialZoom.clamp(0.3, 3.5);
    _panPixelX = widget.initialPanX * frameSize;
    _panPixelY = widget.initialPanY * frameSize;
    _loadUiImage();
  }

  Future<void> _loadUiImage() async {
    try {
      final image = await decodeImageFromList(widget.imageBytes);
      if (mounted) {
        setState(() {
          _decodedImage = image;
          _isLoadingImage = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingImage = false);
      }
    }
  }

  void _resetPosition() {
    setState(() {
      _zoom = 1.0;
      _panPixelX = 0.0;
      _panPixelY = 0.0;
    });
  }

  Future<void> _applyCrop() async {
    if (_decodedImage == null) {
      Navigator.of(context).pop(
        ImageCropResult(
          croppedBytes: widget.imageBytes,
          shape: _shape,
          zoom: _zoom,
          panX: _panPixelX / frameSize,
          panY: _panPixelY / frameSize,
        ),
      );
      return;
    }

    setState(() => _isProcessingCrop = true);

    try {
      const double outSize = 512.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, outSize, outSize));

      final double naturalW = _decodedImage!.width.toDouble();
      final double naturalH = _decodedImage!.height.toDouble();

      // Base scale: smaller dimension fits aperture at zoom 1.0
      final double baseScale = frameSize / math.min(naturalW, naturalH);
      final double displayW = naturalW * baseScale * _zoom;
      final double displayH = naturalH * baseScale * _zoom;

      final double ratio = outSize / frameSize;

      canvas.save();
      // Center canvas origin at (outSize/2, outSize/2)
      canvas.translate(outSize / 2, outSize / 2);
      canvas.scale(ratio, ratio);
      canvas.translate(_panPixelX, _panPixelY);

      final srcRect = Rect.fromLTWH(0, 0, naturalW, naturalH);
      final dstRect = Rect.fromCenter(center: Offset.zero, width: displayW, height: displayH);

      final paint = Paint()..filterQuality = FilterQuality.high;
      canvas.drawImageRect(_decodedImage!, srcRect, dstRect, paint);

      canvas.restore();

      final picture = recorder.endRecording();
      final croppedImage = await picture.toImage(outSize.toInt(), outSize.toInt());
      final byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);
      final croppedBytes = byteData != null ? byteData.buffer.asUint8List() : widget.imageBytes;

      if (mounted) {
        Navigator.of(context).pop(
          ImageCropResult(
            croppedBytes: croppedBytes,
            shape: _shape,
            zoom: 1.0,
            panX: 0.0,
            panY: 0.0,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pop(
          ImageCropResult(
            croppedBytes: widget.imageBytes,
            shape: _shape,
            zoom: _zoom,
            panX: _panPixelX / frameSize,
            panY: _panPixelY / frameSize,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    double displayW = frameSize;
    double displayH = frameSize;
    if (_decodedImage != null) {
      final double naturalW = _decodedImage!.width.toDouble();
      final double naturalH = _decodedImage!.height.toDouble();
      final double baseScale = frameSize / math.min(naturalW, naturalH);
      displayW = naturalW * baseScale * _zoom;
      displayH = naturalH * baseScale * _zoom;
    }

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.2),
      ),
      titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.crop_outlined, color: AppTheme.emerald, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Encuadre Real de Fotografía',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'La foto se muestra completa sin recortes previos. Ajusta el marco a tu gusto.',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Shape Selection: Round vs Square
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    avatar: const Icon(Icons.circle_outlined, size: 16),
                    label: const Text('Marco Redondo', style: TextStyle(fontSize: 12)),
                    selected: _shape == 'circle',
                    selectedColor: AppTheme.emerald.withOpacity(0.2),
                    onSelected: (val) {
                      if (val) setState(() => _shape = 'circle');
                    },
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    avatar: const Icon(Icons.crop_square, size: 16),
                    label: const Text('Marco Cuadrado', style: TextStyle(fontSize: 12)),
                    selected: _shape == 'square',
                    selectedColor: AppTheme.emerald.withOpacity(0.2),
                    onSelected: (val) {
                      if (val) setState(() => _shape = 'square');
                    },
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ================================================================
              // WYSIWYG VIEWPORT WITH UNCLIPPED NATURAL ASPECT RATIO
              // ================================================================
              Center(
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _panPixelX += details.delta.dx;
                      _panPixelY += details.delta.dy;
                    });
                  },
                  child: Container(
                    width: viewportWidth,
                    height: viewportHeight,
                    decoration: BoxDecoration(
                      color: const Color(0xFF070B12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1), width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _isLoadingImage
                        ? const Center(child: CircularProgressIndicator(color: AppTheme.emerald))
                        : Stack(
                            alignment: Alignment.center,
                            children: [
                              // Layer 1: True natural-aspect unclipped image translated and zoomed
                              Transform.translate(
                                offset: Offset(_panPixelX, _panPixelY),
                                child: SizedBox(
                                  width: displayW,
                                  height: displayH,
                                  child: RawImage(
                                    image: _decodedImage,
                                    fit: BoxFit.fill,
                                    filterQuality: FilterQuality.high,
                                  ),
                                ),
                              ),

                              // Layer 2: Semi-transparent dark mask around the framing aperture
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: FramingMaskPainter(
                                    shape: _shape,
                                    frameSize: frameSize,
                                  ),
                                ),
                              ),

                              // Layer 3: Clean Framing Aperture border
                              IgnorePointer(
                                child: Container(
                                  width: frameSize,
                                  height: frameSize,
                                  decoration: BoxDecoration(
                                    shape: _shape == 'circle' ? BoxShape.circle : BoxShape.rectangle,
                                    borderRadius: _shape == 'square' ? BorderRadius.circular(20) : null,
                                    border: Border.all(color: AppTheme.emerald, width: 2.5),
                                  ),
                                ),
                              ),

                              // Layer 4: Drag Hint Label at the bottom
                              Positioned(
                                bottom: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.75),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white24, width: 0.8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.touch_app_outlined, size: 12, color: Colors.white70),
                                      SizedBox(width: 5),
                                      Text(
                                        'Arrastra la foto para centrar el rostro dentro del marco',
                                        style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Zoom Slider (Range 0.3x to 3.5x for maximum flexibility)
              Row(
                children: [
                  const Icon(Icons.zoom_in, size: 16, color: AppTheme.emerald),
                  const SizedBox(width: 6),
                  const Text('Nivel de Zoom:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('${(_zoom * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                ],
              ),
              Slider(
                value: _zoom,
                min: 0.3,
                max: 3.5,
                divisions: 32,
                activeColor: AppTheme.emerald,
                onChanged: (v) => setState(() => _zoom = v),
              ),

              // Fine Tuning & Reset Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _resetPosition,
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: const Text('Centrar imagen', style: TextStyle(fontSize: 11.5)),
                  ),
                  Row(
                    children: [
                      Text('X: ${(_panPixelX / frameSize).toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(width: 8),
                      Text('Y: ${(_panPixelY / frameSize).toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: (_isLoadingImage || _isProcessingCrop) ? null : _applyCrop,
          icon: _isProcessingCrop
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check, size: 18),
          label: Text(_isProcessingCrop ? 'Recortando...' : 'Aplicar Encuadre'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.emerald,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ==============================================================================
// FRAMING MASK PAINTER (Darkened overlay outside the circular or square frame)
// ==============================================================================
class FramingMaskPainter extends CustomPainter {
  final String shape;
  final double frameSize;

  FramingMaskPainter({required this.shape, required this.frameSize});

  @override
  void paint(Canvas canvas, Size size) {
    final maskPaint = Paint()
      ..color = Colors.black.withOpacity(0.68)
      ..style = PaintingStyle.fill;

    final fullRect = Offset.zero & size;
    final center = Offset(size.width / 2, size.height / 2);
    final frameRect = Rect.fromCenter(center: center, width: frameSize, height: frameSize);

    final Path maskPath = Path()..addRect(fullRect);

    if (shape == 'circle') {
      maskPath.addOval(frameRect);
    } else {
      maskPath.addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(20)));
    }

    // Even-odd fill rule punches out the central aperture
    maskPath.fillType = PathFillType.evenOdd;
    canvas.drawPath(maskPath, maskPaint);

    // Subtle alignment cross lines inside frame
    final guidePaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..strokeWidth = 0.8;

    // Horizontal third lines
    canvas.drawLine(Offset(frameRect.left, frameRect.top + frameSize / 3), Offset(frameRect.right, frameRect.top + frameSize / 3), guidePaint);
    canvas.drawLine(Offset(frameRect.left, frameRect.top + (frameSize * 2) / 3), Offset(frameRect.right, frameRect.top + (frameSize * 2) / 3), guidePaint);

    // Vertical third lines
    canvas.drawLine(Offset(frameRect.left + frameSize / 3, frameRect.top), Offset(frameRect.left + frameSize / 3, frameRect.bottom), guidePaint);
    canvas.drawLine(Offset(frameRect.left + (frameSize * 2) / 3, frameRect.top), Offset(frameRect.left + (frameSize * 2) / 3, frameRect.bottom), guidePaint);
  }

  @override
  bool shouldRepaint(covariant FramingMaskPainter oldDelegate) {
    return oldDelegate.shape != shape || oldDelegate.frameSize != frameSize;
  }
}
