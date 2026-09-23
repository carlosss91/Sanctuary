import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/signature_document_model.dart';

class SignatureCanvasWidget extends StatefulWidget {
  final ValueChanged<List<SignatureStroke>> onSaveSignature;
  final VoidCallback? onCancel;

  const SignatureCanvasWidget({
    super.key,
    required this.onSaveSignature,
    this.onCancel,
  });

  @override
  State<SignatureCanvasWidget> createState() => _SignatureCanvasWidgetState();
}

class _SignatureCanvasWidgetState extends State<SignatureCanvasWidget> {
  final List<SignatureStroke> _strokes = [];
  List<Offset> _currentPoints = [];
  Color _selectedColor = const Color(0xFF1D4ED8); // Default notary blue
  double _strokeWidth = 3.5;
  String _activeTool = 'pen'; // 'pen' | 'ballpoint' | 'highlighter'

  final List<Color> _colorPalette = const [
    Color(0xFF1D4ED8), // Azul Notarial
    Color(0xFF0F172A), // Negro Carbón
    Color(0xFF059669), // Verde Esmeralda
    Color(0xFFDC2626), // Rojo Carmesí
    Color(0xFF7C3AED), // Púrpura Real
    Color(0xFFD97706), // Ámbar Dorado
  ];

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 600,
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
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.draw_outlined, color: AppTheme.emerald, size: 20),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Estampar Firma Digital', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Text('Dibuja con precisión tu rúbrica en el recuadro interactivo', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                const Spacer(),
                if (widget.onCancel != null)
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Cerrar',
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Tools and Color Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Tool selection
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'pen', label: Text('Pluma'), icon: Icon(Icons.edit, size: 14)),
                    ButtonSegment(value: 'ballpoint', label: Text('Boli'), icon: Icon(Icons.border_color, size: 14)),
                    ButtonSegment(value: 'highlighter', label: Text('Marcador'), icon: Icon(Icons.brush, size: 14)),
                  ],
                  selected: {_activeTool},
                  onSelectionChanged: (val) {
                    setState(() => _activeTool = val.first);
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
              height: 220,
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
                      bottom: 48,
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
                      bottom: 28,
                      child: Text(
                        'Firma del Interesado / Signer',
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
                            Icon(Icons.gesture, size: 30, color: Colors.grey.withOpacity(0.4)),
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

          // Bottom Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _strokes.isEmpty ? null : _undoLastStroke,
                  icon: const Icon(Icons.undo, size: 15),
                  label: const Text('Deshacer', style: TextStyle(fontSize: 11.5)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _strokes.isEmpty ? null : _clearAllStrokes,
                  icon: const Icon(Icons.delete_outline, size: 15),
                  label: const Text('Borrar todo', style: TextStyle(fontSize: 11.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _strokes.isEmpty
                      ? null
                      : () {
                          widget.onSaveSignature(_strokes);
                        },
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Guardar e Insertar Firma', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ],
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
