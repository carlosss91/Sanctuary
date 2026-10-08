import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../../../core/theme/app_theme.dart';

enum CropHandle {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  inside,
  none,
}

class SignatureImageCropperWidget extends StatefulWidget {
  final Uint8List rawImageBytes;
  final ValueChanged<Uint8List> onCropDone;
  final VoidCallback onCancel;

  const SignatureImageCropperWidget({
    super.key,
    required this.rawImageBytes,
    required this.onCropDone,
    required this.onCancel,
  });

  @override
  State<SignatureImageCropperWidget> createState() => _SignatureImageCropperWidgetState();
}

class _SignatureImageCropperWidgetState extends State<SignatureImageCropperWidget> {
  img.Image? _originalImage;
  img.Image? _rotatedImage;
  Uint8List? _previewBytes;
  bool _isLoading = true;
  bool _isProcessing = false;

  int _rotationAngle = 0; // 0, 90, 180, 270
  bool _removeWhiteBackground = true;
  bool _enhanceContrast = true;

  // Normalized crop bounds (0.0 to 1.0 relative to displayed image)
  double _cropNormLeft = 0.08;
  double _cropNormTop = 0.22;
  double _cropNormRight = 0.92;
  double _cropNormBottom = 0.78;

  // Aspect ratio lock mode: '3:1' | '2:1' | 'free'
  String _aspectRatioMode = '3:1';

  CropHandle _activeHandle = CropHandle.none;
  Offset? _lastPanGlobal;

  @override
  void initState() {
    super.initState();
    _decodeInputImage();
  }

  void _decodeInputImage() {
    setState(() => _isLoading = true);
    Future.microtask(() {
      try {
        final decoded = img.decodeImage(widget.rawImageBytes);
        if (decoded != null) {
          // If the image is large (e.g. from a mobile camera 4000x3000), downscale it to max 1200px
          img.Image effectiveImg = decoded;
          const maxDim = 1200;
          if (effectiveImg.width > maxDim || effectiveImg.height > maxDim) {
            if (effectiveImg.width > effectiveImg.height) {
              effectiveImg = img.copyResize(effectiveImg, width: maxDim, interpolation: img.Interpolation.linear);
            } else {
              effectiveImg = img.copyResize(effectiveImg, height: maxDim, interpolation: img.Interpolation.linear);
            }
          }

          final rotated = _rotationAngle == 0 ? effectiveImg : img.copyRotate(effectiveImg, angle: _rotationAngle);
          final Uint8List preview;
          if (_rotationAngle == 0 && effectiveImg == decoded) {
            preview = widget.rawImageBytes;
          } else {
            preview = Uint8List.fromList(img.encodeJpg(rotated, quality: 85));
          }

          if (mounted) {
            setState(() {
              _originalImage = effectiveImg;
              _rotatedImage = rotated;
              _previewBytes = preview;
              _isLoading = false;
            });
          }
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      } catch (e) {
        debugPrint('Error decoding image for signature cropper: $e');
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  void _rotateClockwise() {
    if (_originalImage == null) return;
    setState(() {
      _rotationAngle = (_rotationAngle + 90) % 360;
      _isLoading = true;
    });

    Future.microtask(() {
      final rotated = _rotationAngle == 0
          ? _originalImage!
          : img.copyRotate(_originalImage!, angle: _rotationAngle);
      final preview = Uint8List.fromList(img.encodeJpg(rotated, quality: 85));

      if (mounted) {
        setState(() {
          _rotatedImage = rotated;
          _previewBytes = preview;
          _isLoading = false;
          // Reset crop box comfortably centered
          _cropNormLeft = 0.08;
          _cropNormTop = 0.22;
          _cropNormRight = 0.92;
          _cropNormBottom = 0.78;
        });
      }
    });
  }

  void _applyAspectRatioPreset(String mode, double imgWidth, double imgHeight) {
    setState(() {
      _aspectRatioMode = mode;
      final currentCenterY = (_cropNormTop + _cropNormBottom) / 2;
      final currentWidth = (_cropNormRight - _cropNormLeft).clamp(0.2, 0.95);

      if (mode == '3:1') {
        // Target 3:1 width to height in real pixels
        // (currentWidth * imgWidth) / (targetHeight * imgHeight) = 3.0
        final targetHeightNorm = (currentWidth * imgWidth / (3.0 * imgHeight)).clamp(0.08, 0.95);
        _cropNormTop = (currentCenterY - targetHeightNorm / 2).clamp(0.0, 1.0 - targetHeightNorm);
        _cropNormBottom = _cropNormTop + targetHeightNorm;
      } else if (mode == '2:1') {
        final targetHeightNorm = (currentWidth * imgWidth / (2.0 * imgHeight)).clamp(0.08, 0.95);
        _cropNormTop = (currentCenterY - targetHeightNorm / 2).clamp(0.0, 1.0 - targetHeightNorm);
        _cropNormBottom = _cropNormTop + targetHeightNorm;
      }
    });
  }

  void _resetCropBox() {
    setState(() {
      _cropNormLeft = 0.08;
      _cropNormTop = 0.22;
      _cropNormRight = 0.92;
      _cropNormBottom = 0.78;
    });
  }

  Future<void> _executeCrop() async {
    if (_rotatedImage == null) return;
    setState(() => _isProcessing = true);

    try {
      final imgW = _rotatedImage!.width;
      final imgH = _rotatedImage!.height;

      final normL = math.min(_cropNormLeft, _cropNormRight);
      final normR = math.max(_cropNormLeft, _cropNormRight);
      final normT = math.min(_cropNormTop, _cropNormBottom);
      final normB = math.max(_cropNormTop, _cropNormBottom);

      final cropX = (normL * imgW).round().clamp(0, imgW - 1);
      final cropY = (normT * imgH).round().clamp(0, imgH - 1);
      final cropW = ((normR - normL) * imgW).round().clamp(2, imgW - cropX);
      final cropH = ((normB - normT) * imgH).round().clamp(2, imgH - cropY);

      var cropped = img.copyCrop(
        _rotatedImage!,
        x: cropX,
        y: cropY,
        width: cropW,
        height: cropH,
      );

      if (_removeWhiteBackground) {
        cropped = _filterWhiteBackground(cropped, enhance: _enhanceContrast);
      }

      final pngBytes = Uint8List.fromList(img.encodePng(cropped));

      if (mounted) {
        setState(() => _isProcessing = false);
        widget.onCropDone(pngBytes);
      }
    } catch (e) {
      debugPrint('Error cropping signature image: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar el recorte: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  img.Image _filterWhiteBackground(img.Image src, {bool enhance = true, int threshold = 212}) {
    final out = img.Image(width: src.width, height: src.height, numChannels: 4);

    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final pixel = src.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();
        final lum = 0.299 * r + 0.587 * g + 0.114 * b;

        if (lum >= threshold) {
          // Paper background -> completely transparent
          out.setPixelRgba(x, y, 0, 0, 0, 0);
        } else {
          // Ink stroke: smooth edge falloff for anti-aliasing
          final double delta = (threshold - lum).clamp(0.0, threshold.toDouble());
          final int alpha = ((delta / (threshold * 0.35)).clamp(0.0, 1.0) * 255).toInt();

          int outR = r.toInt();
          int outG = g.toInt();
          int outB = b.toInt();

          if (enhance) {
            // Keep blue notary tone if original was bluish, otherwise crisp notary black
            final isBlue = (b > r + 15) && (b > g + 10);
            if (isBlue) {
              outR = (r * 0.4).round().clamp(0, 50);
              outG = (g * 0.5).round().clamp(0, 80);
              outB = (b * 1.15).round().clamp(110, 230);
            } else {
              final darkFactor = (lum / threshold).clamp(0.0, 1.0);
              outR = (r * darkFactor * 0.6).round().clamp(0, 255);
              outG = (g * darkFactor * 0.6).round().clamp(0, 255);
              outB = (b * darkFactor * 0.6).round().clamp(0, 255);
            }
          }

          out.setPixelRgba(x, y, outR, outG, outB, alpha);
        }
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Container(
        height: 320,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.emerald),
            SizedBox(height: 12),
            Text('Cargando y preparando imagen de firma...', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    if (_rotatedImage == null || _previewBytes == null) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined, size: 36, color: Colors.redAccent),
            const SizedBox(height: 8),
            const Text('No se pudo decodificar el formato de imagen seleccionado.'),
            const SizedBox(height: 12),
            TextButton(onPressed: widget.onCancel, child: const Text('Volver a intentar')),
          ],
        ),
      );
    }

    final imgW = _rotatedImage!.width.toDouble();
    final imgH = _rotatedImage!.height.toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Subheader instructions & aspect buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.crop_rounded, size: 16, color: AppTheme.emerald),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Arrastra las esquinas o el interior para encuadrar la rúbrica:',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
              // Preset chips
              _buildAspectChip('3:1 Firma', '3:1', imgW, imgH),
              const SizedBox(width: 4),
              _buildAspectChip('2:1', '2:1', imgW, imgH),
              const SizedBox(width: 4),
              _buildAspectChip('Libre', 'free', imgW, imgH),
            ],
          ),
        ),

        // Interactive Cropper Canvas
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 250,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B132B) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cw = constraints.maxWidth;
                  final ch = constraints.maxHeight;

                  final scale = math.min(cw / imgW, ch / imgH);
                  final displayW = imgW * scale;
                  final displayH = imgH * scale;
                  final offsetX = (cw - displayW) / 2;
                  final offsetY = (ch - displayH) / 2;

                  final cropLeft = offsetX + _cropNormLeft * displayW;
                  final cropTop = offsetY + _cropNormTop * displayH;
                  final cropRight = offsetX + _cropNormRight * displayW;
                  final cropBottom = offsetY + _cropNormBottom * displayH;
                  final cropRect = Rect.fromLTRB(cropLeft, cropTop, cropRight, cropBottom);

                  return GestureDetector(
                    onPanDown: (details) {
                      _lastPanGlobal = details.localPosition;
                      _activeHandle = _hitTestHandle(details.localPosition, cropRect);
                    },
                    onPanUpdate: (details) {
                      if (_lastPanGlobal == null) return;
                      final delta = details.localPosition - _lastPanGlobal!;
                      _lastPanGlobal = details.localPosition;

                      final deltaNormX = delta.dx / displayW;
                      final deltaNormY = delta.dy / displayH;

                      setState(() {
                        switch (_activeHandle) {
                          case CropHandle.topLeft:
                            _cropNormLeft = (_cropNormLeft + deltaNormX).clamp(0.0, _cropNormRight - 0.08);
                            _cropNormTop = (_cropNormTop + deltaNormY).clamp(0.0, _cropNormBottom - 0.08);
                            break;
                          case CropHandle.topRight:
                            _cropNormRight = (_cropNormRight + deltaNormX).clamp(_cropNormLeft + 0.08, 1.0);
                            _cropNormTop = (_cropNormTop + deltaNormY).clamp(0.0, _cropNormBottom - 0.08);
                            break;
                          case CropHandle.bottomLeft:
                            _cropNormLeft = (_cropNormLeft + deltaNormX).clamp(0.0, _cropNormRight - 0.08);
                            _cropNormBottom = (_cropNormBottom + deltaNormY).clamp(_cropNormTop + 0.08, 1.0);
                            break;
                          case CropHandle.bottomRight:
                            _cropNormRight = (_cropNormRight + deltaNormX).clamp(_cropNormLeft + 0.08, 1.0);
                            _cropNormBottom = (_cropNormBottom + deltaNormY).clamp(_cropNormTop + 0.08, 1.0);
                            break;
                          case CropHandle.inside:
                            final width = _cropNormRight - _cropNormLeft;
                            final height = _cropNormBottom - _cropNormTop;
                            var newL = _cropNormLeft + deltaNormX;
                            var newT = _cropNormTop + deltaNormY;

                            if (newL < 0.0) newL = 0.0;
                            if (newL + width > 1.0) newL = 1.0 - width;
                            if (newT < 0.0) newT = 0.0;
                            if (newT + height > 1.0) newT = 1.0 - height;

                            _cropNormLeft = newL;
                            _cropNormRight = newL + width;
                            _cropNormTop = newT;
                            _cropNormBottom = newT + height;
                            break;
                          case CropHandle.none:
                            break;
                        }
                      });
                    },
                    onPanEnd: (_) {
                      _activeHandle = CropHandle.none;
                      _lastPanGlobal = null;
                    },
                    child: Stack(
                      children: [
                        // Displayed image
                        Positioned(
                          left: offsetX,
                          top: offsetY,
                          width: displayW,
                          height: displayH,
                          child: Image.memory(
                            _previewBytes!,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                        ),

                        // Vignette mask & crop guide overlay
                        CustomPaint(
                          size: Size(cw, ch),
                          painter: _CropOverlayPainter(
                            cropRect: cropRect,
                            imageBounds: Rect.fromLTWH(offsetX, offsetY, displayW, displayH),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // Controls Toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              // Rotate button
              OutlinedButton.icon(
                onPressed: _rotateClockwise,
                icon: const Icon(Icons.rotate_right_rounded, size: 16),
                label: Text('Girar 90° ($_rotationAngle°)', style: const TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              // Reset crop box
              OutlinedButton.icon(
                onPressed: _resetCropBox,
                icon: const Icon(Icons.center_focus_strong_rounded, size: 15),
                label: const Text('Centrar', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              // Filter switches
              FilterChip(
                label: const Text('Quitar fondo blanco (Transparente)', style: TextStyle(fontSize: 11)),
                selected: _removeWhiteBackground,
                onSelected: (val) => setState(() => _removeWhiteBackground = val),
                avatar: Icon(
                  _removeWhiteBackground ? Icons.check_circle : Icons.layers_clear_outlined,
                  size: 14,
                  color: _removeWhiteBackground ? AppTheme.emerald : Colors.grey,
                ),
                selectedColor: AppTheme.emerald.withOpacity(0.2),
                visualDensity: VisualDensity.compact,
              ),

              FilterChip(
                label: const Text('Realzar tinta', style: TextStyle(fontSize: 11)),
                selected: _enhanceContrast,
                onSelected: (val) => setState(() => _enhanceContrast = val),
                avatar: Icon(
                  _enhanceContrast ? Icons.tonality : Icons.contrast,
                  size: 14,
                  color: _enhanceContrast ? AppTheme.emerald : Colors.grey,
                ),
                selectedColor: AppTheme.emerald.withOpacity(0.2),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Action Buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.arrow_back, size: 14),
                label: const Text('Cambiar imagen / Volver', style: TextStyle(fontSize: 11.5)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _executeCrop,
                icon: _isProcessing
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.crop_sharp, size: 16),
                label: Text(
                  _isProcessing ? 'Procesando recorte...' : 'Aplicar Recorte y Continuar',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAspectChip(String label, String mode, double imgW, double imgH) {
    final isSel = _aspectRatioMode == mode;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 10.5)),
      selected: isSel,
      selectedColor: AppTheme.emerald.withOpacity(0.25),
      visualDensity: VisualDensity.compact,
      onSelected: (_) => _applyAspectRatioPreset(mode, imgW, imgH),
    );
  }

  CropHandle _hitTestHandle(Offset pos, Rect cropRect) {
    const handleHitRadius = 24.0;

    if ((pos - cropRect.topLeft).distance <= handleHitRadius) return CropHandle.topLeft;
    if ((pos - cropRect.topRight).distance <= handleHitRadius) return CropHandle.topRight;
    if ((pos - cropRect.bottomLeft).distance <= handleHitRadius) return CropHandle.bottomLeft;
    if ((pos - cropRect.bottomRight).distance <= handleHitRadius) return CropHandle.bottomRight;

    if (cropRect.contains(pos)) return CropHandle.inside;

    return CropHandle.none;
  }
}

class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;
  final Rect imageBounds;

  _CropOverlayPainter({required this.cropRect, required this.imageBounds});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dark mask outside crop box
    final darkPaint = Paint()..color = Colors.black.withOpacity(0.55);

    final bgPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cropPath = Path()..addRect(cropRect);
    final maskPath = Path.combine(PathOperation.difference, bgPath, cropPath);
    canvas.drawPath(maskPath, darkPaint);

    // 2. Crop border
    final borderPaint = Paint()
      ..color = AppTheme.emerald
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawRect(cropRect, borderPaint);

    // 3. Rule lines inside crop area
    final guidePaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final thirdW = cropRect.width / 3;
    final thirdH = cropRect.height / 3;

    canvas.drawLine(
      Offset(cropRect.left + thirdW, cropRect.top),
      Offset(cropRect.left + thirdW, cropRect.bottom),
      guidePaint,
    );
    canvas.drawLine(
      Offset(cropRect.left + thirdW * 2, cropRect.top),
      Offset(cropRect.left + thirdW * 2, cropRect.bottom),
      guidePaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + thirdH),
      Offset(cropRect.right, cropRect.top + thirdH),
      guidePaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + thirdH * 2),
      Offset(cropRect.right, cropRect.top + thirdH * 2),
      guidePaint,
    );

    // Signature baseline indicator
    final baseLinePaint = Paint()
      ..color = const Color(0xFF06B6D4).withOpacity(0.7)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final baselineY = cropRect.top + cropRect.height * 0.72;
    canvas.drawLine(
      Offset(cropRect.left + 8, baselineY),
      Offset(cropRect.right - 8, baselineY),
      baseLinePaint,
    );

    // 4. Corner Handles
    final handlePaint = Paint()
      ..color = AppTheme.emerald
      ..style = PaintingStyle.fill;
    final handleBorder = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    void drawHandle(Offset center) {
      canvas.drawCircle(center, 7.0, handlePaint);
      canvas.drawCircle(center, 7.0, handleBorder);
    }

    drawHandle(cropRect.topLeft);
    drawHandle(cropRect.topRight);
    drawHandle(cropRect.bottomLeft);
    drawHandle(cropRect.bottomRight);
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect || oldDelegate.imageBounds != imageBounds;
  }
}
