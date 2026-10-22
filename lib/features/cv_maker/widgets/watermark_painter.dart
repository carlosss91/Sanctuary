import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// ==============================================================================
// WATERMARK PATTERN PAINTER & RENDERER FOR PREVIEW AND HIGH-FIDELITY PDF EXPORT
// ==============================================================================

class WatermarkPainter extends CustomPainter {
  final String pattern;
  final double opacity;
  final double density;
  final double randomness;

  WatermarkPainter({
    required this.pattern,
    this.opacity = 0.14,
    this.density = 1.0,
    this.randomness = 0.0,
  });

  /// Deterministic pseudo-random float [0.0, 1.0) based on seed (stable across repaints & exports)
  double _pr(num seed) {
    final v = math.sin(seed * 12.9898 + 78.233) * 43758.5453123;
    return (v - v.floor()).abs();
  }

  /// Jitters a point based on randomness
  Offset _scatterPoint(Offset base, int seed, double maxDx, double maxDy, [Size? bounds]) {
    if (randomness <= 0.001) return base;
    final rx = (_pr(seed * 23 + 11) * 2.0 - 1.0) * maxDx * randomness;
    final ry = (_pr(seed * 41 + 17) * 2.0 - 1.0) * maxDy * randomness;
    final res = Offset(base.dx + rx, base.dy + ry);
    if (bounds != null) {
      return Offset(
        res.dx.clamp(-15.0, bounds.width + 15.0),
        res.dy.clamp(-15.0, bounds.height + 15.0),
      );
    }
    return res;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.0) return;

    final strokePaint = Paint()
      ..color = Colors.white.withOpacity(opacity.clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final fillPaint = Paint()
      ..color = Colors.white.withOpacity(opacity.clamp(0.0, 1.0) * 0.45)
      ..style = PaintingStyle.fill;

    switch (pattern) {
      case 'gears':
        _drawGears(canvas, size, strokePaint, fillPaint);
        break;
      case 'tools':
        _drawTools(canvas, size, strokePaint, fillPaint);
        break;
      case 'constellation':
        _drawConstellation(canvas, size, strokePaint, fillPaint);
        break;
      case 'circuits':
        _drawCircuits(canvas, size, strokePaint, fillPaint);
        break;
      case 'code_brackets':
        _drawCodeBrackets(canvas, size, strokePaint);
        break;
      case 'geometric':
        _drawHexagons(canvas, size, strokePaint, fillPaint);
        break;
      case 'cubes':
        _drawCubes(canvas, size, strokePaint, fillPaint);
        break;
      case 'waves':
        _drawWaves(canvas, size, strokePaint);
        break;
      case 'shield':
        _drawShield(canvas, size, strokePaint, fillPaint);
        break;
      case 'lines':
        _drawBlueprintLines(canvas, size, strokePaint);
        break;
      case 'tech_dots':
        _drawTechDots(canvas, size, strokePaint, fillPaint);
        break;
      case 'leaves':
        _drawLeaves(canvas, size, strokePaint, fillPaint);
        break;
      default:
        _drawGears(canvas, size, strokePaint, fillPaint);
    }
  }

  void _drawTechDots(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final step = 22.0 / math.sqrt(density.clamp(0.4, 2.5));
    // 1. Circuit test points
    for (double y = 10; y < size.height + step; y += step) {
      for (double x = 10; x < size.width + step; x += step) {
        canvas.drawCircle(Offset(x, y), 1.6, fill);
        if (((x + y).toInt() % (step * 2).toInt()) == 0) {
          canvas.drawCircle(Offset(x, y), 3.2, stroke..strokeWidth = 0.8);
        }
      }
    }

    // 2. High-tech orthogonal circuit traces with 45-degree chamfers
    final tracePaint = stroke..strokeWidth = 1.0;
    final traceStep = 80.0 / math.sqrt(density.clamp(0.4, 2.5));
    for (double y = 20; y < size.height + 20; y += traceStep) {
      final p = Path()
        ..moveTo(-10, y)
        ..lineTo(size.width * 0.35, y)
        ..lineTo(size.width * 0.45, y + 12)
        ..lineTo(size.width * 0.85, y + 12)
        ..lineTo(size.width * 0.92, y + 22);
      canvas.drawPath(p, tracePaint);
      canvas.drawCircle(Offset(size.width * 0.92, y + 22), 2.5, fill);
    }

    // 3. Mini Micro-controller IC blocks
    final icWidth = 24.0;
    final icHeight = 16.0;
    final icStep = 130.0 / math.sqrt(density.clamp(0.4, 2.5));
    for (double y = 30; y < size.height + 20; y += icStep) {
      final rect = Rect.fromLTWH(size.width * 0.55 - icWidth / 2, y, icWidth, icHeight);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), stroke..strokeWidth = 1.0);
      for (double px = rect.left + 4; px < rect.right - 2; px += 5) {
        canvas.drawLine(Offset(px, rect.top), Offset(px, rect.top - 3), stroke..strokeWidth = 0.8);
        canvas.drawLine(Offset(px, rect.bottom), Offset(px, rect.bottom + 3), stroke..strokeWidth = 0.8);
      }
    }
  }

  void _drawGears(Canvas canvas, Size size, Paint stroke, Paint fill) {
    if (size.height <= 60) {
      final cy = size.height / 2;
      final step = 38.0 / math.sqrt(density.clamp(0.4, 2.5));
      int idx = 0;
      for (double x = 12; x < size.width + 30; x += step) {
        final baseR = (idx % 2 == 0)
            ? (14.0 * math.sqrt(density.clamp(0.5, 2.0))).clamp(8.0, 22.0)
            : (10.0 * math.sqrt(density.clamp(0.5, 2.0))).clamp(6.0, 16.0);
        final r = (baseR * (1.0 + (_pr(idx * 19 + 3) - 0.5) * 0.35 * randomness)).clamp(5.0, 24.0);
        final teeth = (idx % 2 == 0) ? 9 : 7;

        final dy = (_pr(idx * 37 + 7) * 2.0 - 1.0) * (size.height * 0.42) * randomness;
        final dx = (_pr(idx * 53 + 13) * 2.0 - 1.0) * (step * 0.35) * randomness;
        final center = Offset(x + dx, (cy + dy).clamp(2.0, size.height - 2.0));

        _drawSingleGear(canvas, center, r, teeth, stroke, fill);

        if (randomness >= 0.45 && idx % 2 == 0) {
          final satDy = -dy * 0.85;
          final satCenter = Offset(x + step * 0.5 + dx * 0.3, (cy + satDy).clamp(3.0, size.height - 3.0));
          _drawSingleGear(canvas, satCenter, r * 0.52, 6, stroke, fill);
        }
        idx++;
      }
      return;
    }

    // Multi-gear engineering arrangement across the layout
    final d = math.sqrt(density.clamp(0.4, 2.5));
    _drawSingleGear(canvas, _scatterPoint(Offset(size.width * 0.82, size.height * 0.08), 101, size.width * 0.12, size.height * 0.05), 34.0 * d, 10, stroke, fill);
    _drawSingleGear(canvas, _scatterPoint(Offset(size.width * 0.96, size.height * 0.15), 102, size.width * 0.10, size.height * 0.05), 18.0 * d, 8, stroke, fill);

    _drawSingleGear(canvas, _scatterPoint(Offset(size.width * 0.16, size.height * 0.28), 103, size.width * 0.10, size.height * 0.05), 28.0 * d, 9, stroke, fill);
    _drawSingleGear(canvas, _scatterPoint(Offset(size.width * 0.05, size.height * 0.35), 104, size.width * 0.08, size.height * 0.05), 16.0 * d, 7, stroke, fill);

    _drawSingleGear(canvas, _scatterPoint(Offset(size.width * 0.86, size.height * 0.50), 105, size.width * 0.10, size.height * 0.05), 32.0 * d, 10, stroke, fill);
    _drawSingleGear(canvas, _scatterPoint(Offset(size.width * 0.20, size.height * 0.70), 106, size.width * 0.10, size.height * 0.05), 30.0 * d, 9, stroke, fill);

    _drawSingleGear(canvas, _scatterPoint(Offset(size.width * 0.74, size.height * 0.88), 107, size.width * 0.10, size.height * 0.05), 46.0 * d, 12, stroke, fill);
    _drawSingleGear(canvas, _scatterPoint(Offset(size.width * 0.26, size.height * 0.94), 108, size.width * 0.10, size.height * 0.05), 30.0 * d, 8, stroke, fill);
    _drawSingleGear(canvas, _scatterPoint(Offset(size.width * 0.50, size.height * 0.92), 109, size.width * 0.10, size.height * 0.05), 20.0 * d, 7, stroke, fill);

    if (density >= 1.25) {
      _drawSingleGear(canvas, _scatterPoint(Offset(size.width * 0.52, size.height * 0.20), 110, size.width * 0.10, size.height * 0.05), 22.0 * d, 8, stroke, fill);
      _drawSingleGear(canvas, _scatterPoint(Offset(size.width * 0.80, size.height * 0.38), 111, size.width * 0.10, size.height * 0.05), 24.0 * d, 8, stroke, fill);
      _drawSingleGear(canvas, _scatterPoint(Offset(size.width * 0.15, size.height * 0.58), 112, size.width * 0.10, size.height * 0.05), 20.0 * d, 7, stroke, fill);
    }
  }

  void _drawSingleGear(Canvas canvas, Offset center, double radius, int teeth, Paint stroke, Paint fill) {
    final path = Path();
    final angleStep = (2 * math.pi) / teeth;
    final toothDepth = radius * 0.18;
    final innerR = radius - toothDepth;

    for (int i = 0; i < teeth; i++) {
      final a0 = i * angleStep;
      final a1 = a0 + angleStep * 0.25;
      final a2 = a0 + angleStep * 0.50;
      final a3 = a0 + angleStep * 0.75;
      final a4 = (i + 1) * angleStep;

      final p0 = Offset(center.dx + math.cos(a0) * innerR, center.dy + math.sin(a0) * innerR);
      final p1 = Offset(center.dx + math.cos(a1) * radius, center.dy + math.sin(a1) * radius);
      final p2 = Offset(center.dx + math.cos(a2) * radius, center.dy + math.sin(a2) * radius);
      final p3 = Offset(center.dx + math.cos(a3) * innerR, center.dy + math.sin(a3) * innerR);
      final p4 = Offset(center.dx + math.cos(a4) * innerR, center.dy + math.sin(a4) * innerR);

      if (i == 0) {
        path.moveTo(p0.dx, p0.dy);
      } else {
        path.lineTo(p0.dx, p0.dy);
      }
      path.lineTo(p1.dx, p1.dy);
      path.lineTo(p2.dx, p2.dy);
      path.lineTo(p3.dx, p3.dy);
      path.lineTo(p4.dx, p4.dy);
    }
    path.close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke..strokeWidth = 1.3);

    // Pitch circle & axle hub
    canvas.drawCircle(center, innerR * 0.78, stroke..strokeWidth = 0.8);
    final hubR = innerR * 0.45;
    canvas.drawCircle(center, hubR, stroke..strokeWidth = 1.2);
    canvas.drawCircle(center, hubR * 0.45, fill);
    canvas.drawCircle(center, hubR * 0.45, stroke..strokeWidth = 0.9);

    // Lightening holes (4 spokes)
    final holeR = hubR * 0.38;
    final holeDist = innerR * 0.62;
    for (int h = 0; h < 4; h++) {
      final ha = h * (math.pi / 2) + (math.pi / 4);
      final hc = Offset(center.dx + math.cos(ha) * holeDist, center.dy + math.sin(ha) * holeDist);
      canvas.drawCircle(hc, holeR, stroke..strokeWidth = 0.8);
    }
  }

  void _drawTools(Canvas canvas, Size size, Paint stroke, Paint fill) {
    if (size.height <= 60) {
      final cy = size.height / 2;
      final step = 50.0 / math.sqrt(density.clamp(0.4, 2.5));
      int idx = 0;
      for (double x = 20; x < size.width + 30; x += step) {
        final baseR = (12.0 * math.sqrt(density.clamp(0.5, 2.0))).clamp(8.0, 18.0);
        final r = (baseR * (1.0 + (_pr(idx * 17 + 5) - 0.5) * 0.35 * randomness)).clamp(6.0, 22.0);
        final dy = (_pr(idx * 31 + 11) * 2.0 - 1.0) * (size.height * 0.42) * randomness;
        final dx = (_pr(idx * 47 + 7) * 2.0 - 1.0) * (step * 0.35) * randomness;
        final center = Offset(x + dx, (cy + dy).clamp(3.0, size.height - 3.0));
        final rotJitter = (_pr(idx * 29 + 13) * 2.0 - 1.0) * (math.pi * 0.5) * randomness;

        _drawCrossedTools(canvas, center, r, stroke, fill, rotationJitter: rotJitter);

        if (randomness >= 0.50 && idx % 2 == 1) {
          final altDy = -dy * 0.85;
          _drawCrossedTools(canvas, Offset(x + step * 0.45 + dx * 0.3, (cy + altDy).clamp(3.0, size.height - 3.0)), r * 0.60, stroke, fill, rotationJitter: -rotJitter);
        }
        idx++;
      }
      return;
    }

    final d = math.sqrt(density.clamp(0.4, 2.5));
    _drawCrossedTools(canvas, _scatterPoint(Offset(size.width * 0.80, size.height * 0.10), 201, size.width * 0.10, size.height * 0.05), 22 * d, stroke, fill);
    _drawCrossedTools(canvas, _scatterPoint(Offset(size.width * 0.22, size.height * 0.32), 202, size.width * 0.10, size.height * 0.05), 24 * d, stroke, fill);
    _drawCrossedTools(canvas, _scatterPoint(Offset(size.width * 0.82, size.height * 0.54), 203, size.width * 0.10, size.height * 0.05), 26 * d, stroke, fill);
    _drawCrossedTools(canvas, _scatterPoint(Offset(size.width * 0.25, size.height * 0.74), 204, size.width * 0.10, size.height * 0.05), 24 * d, stroke, fill);

    _drawCrossedTools(canvas, _scatterPoint(Offset(size.width * 0.50, size.height * 0.89), 205, size.width * 0.08, size.height * 0.04), 34 * d, stroke, fill);
    _drawSingleGear(canvas, _scatterPoint(Offset(size.width * 0.50, size.height * 0.89), 206, size.width * 0.08, size.height * 0.04), 40.0 * d, 12, stroke, fill);

    if (density >= 1.25) {
      _drawCrossedTools(canvas, _scatterPoint(Offset(size.width * 0.55, size.height * 0.22), 207, size.width * 0.10, size.height * 0.05), 18 * d, stroke, fill);
      _drawCrossedTools(canvas, _scatterPoint(Offset(size.width * 0.75, size.height * 0.70), 208, size.width * 0.10, size.height * 0.05), 20 * d, stroke, fill);
    }
  }

  void _drawCrossedTools(Canvas canvas, Offset c, double radius, Paint stroke, Paint fill, {double rotationJitter = 0.0}) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(math.pi / 4 + rotationJitter);

    final wrenchShaft = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: radius * 2.2, height: radius * 0.26),
      const Radius.circular(2),
    );
    canvas.drawRRect(wrenchShaft, fill);
    canvas.drawRRect(wrenchShaft, stroke..strokeWidth = 1.1);

    final headRect = Rect.fromCircle(center: Offset(radius * 1.0, 0), radius: radius * 0.45);
    canvas.drawArc(headRect, -math.pi / 2, math.pi, true, stroke..strokeWidth = 1.3);

    canvas.drawCircle(Offset(-radius * 1.0, 0), radius * 0.38, stroke..strokeWidth = 1.1);
    canvas.drawCircle(Offset(-radius * 1.0, 0), radius * 0.18, stroke..strokeWidth = 0.9);

    canvas.restore();

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-math.pi / 4 + rotationJitter);

    final toolShaft = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: radius * 2.1, height: radius * 0.22),
      const Radius.circular(2),
    );
    canvas.drawRRect(toolShaft, fill);
    canvas.drawRRect(toolShaft, stroke..strokeWidth = 1.1);

    final handle = RRect.fromRectAndRadius(
      Rect.fromLTWH(-radius * 1.1, -radius * 0.22, radius * 0.7, radius * 0.44),
      const Radius.circular(3),
    );
    canvas.drawRRect(handle, fill);
    canvas.drawRRect(handle, stroke..strokeWidth = 1.1);

    final tip = Path()
      ..moveTo(radius * 1.0, -radius * 0.1)
      ..lineTo(radius * 1.2, -radius * 0.04)
      ..lineTo(radius * 1.2, radius * 0.04)
      ..lineTo(radius * 1.0, radius * 0.1)
      ..close();
    canvas.drawPath(tip, fill);
    canvas.drawPath(tip, stroke..strokeWidth = 0.9);

    canvas.restore();

    canvas.drawCircle(c, radius * 0.38, fill);
    canvas.drawCircle(c, radius * 0.38, stroke..strokeWidth = 1.3);
    canvas.drawCircle(c, radius * 0.16, stroke..strokeWidth = 0.9);
  }

  void _drawConstellation(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final step = 36.0 / math.sqrt(density.clamp(0.4, 2.5));
    for (double y = 8; y < size.height + step; y += step) {
      for (double x = 8; x < size.width + step; x += step) {
        final c = _scatterPoint(Offset(x, y), (x * 19 + y * 23).toInt(), step * 0.35, step * 0.35, size);
        final rightTarget = _scatterPoint(Offset(x + step, y), ((x + step) * 19 + y * 23).toInt(), step * 0.35, step * 0.35, size);
        final bottomTarget = _scatterPoint(Offset(x, y + step), (x * 19 + (y + step) * 23).toInt(), step * 0.35, step * 0.35, size);
        if (x + step < size.width + step) {
          canvas.drawLine(c, rightTarget, stroke..strokeWidth = 0.55);
        }
        if (y + step < size.height + step) {
          canvas.drawLine(c, bottomTarget, stroke..strokeWidth = 0.55);
          if (((x + y).toInt() % (step * 2).toInt()) == 0) {
            final diagTarget = _scatterPoint(Offset(x + step, y + step), ((x + step) * 19 + (y + step) * 23).toInt(), step * 0.35, step * 0.35, size);
            canvas.drawLine(c, diagTarget, stroke..strokeWidth = 0.55);
          }
        }
        final isHub = ((x + y).toInt() % (step * 3).toInt()) == 0;
        if (isHub) {
          canvas.drawCircle(c, 4.2, fill);
          canvas.drawCircle(c, 4.2, stroke..strokeWidth = 0.9);
          canvas.drawCircle(c, 1.8, fill);
        } else {
          canvas.drawCircle(c, 2.2, fill);
          canvas.drawCircle(c, 2.2, stroke..strokeWidth = 0.7);
        }
      }
    }
  }

  void _drawCircuits(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final step = 42.0 / math.sqrt(density.clamp(0.4, 2.5));
    for (double y = 10; y < size.height + 20; y += step) {
      final p = Path()
        ..moveTo(-10, y)
        ..lineTo(size.width * 0.35, y)
        ..lineTo(size.width * 0.45, y + 10)
        ..lineTo(size.width * 0.82, y + 10)
        ..lineTo(size.width * 0.88, y + 18)
        ..lineTo(size.width + 15, y + 18);
      canvas.drawPath(p, stroke..strokeWidth = 0.8);
      canvas.drawCircle(Offset(size.width * 0.35, y), 2.2, fill);
      canvas.drawCircle(Offset(size.width * 0.45, y + 10), 2.2, fill);
      canvas.drawCircle(Offset(size.width * 0.82, y + 10), 2.2, fill);
    }

    if (size.height > 60) {
      final icW = 26.0;
      final icH = 15.0;
      final icStep = 110.0 / math.sqrt(density.clamp(0.4, 2.5));
      for (double y = 25; y < size.height + 10; y += icStep) {
        final r = Rect.fromLTWH(size.width * 0.4 - icW / 2, y, icW, icH);
        canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), stroke..strokeWidth = 1.0);
        for (double px = r.left + 3; px < r.right - 2; px += 5) {
          canvas.drawLine(Offset(px, r.top), Offset(px, r.top - 3), stroke..strokeWidth = 0.7);
          canvas.drawLine(Offset(px, r.bottom), Offset(px, r.bottom + 3), stroke..strokeWidth = 0.7);
        }
      }
    }
  }

  void _drawCodeBrackets(Canvas canvas, Size size, Paint stroke) {
    final stepX = 54.0 / math.sqrt(density.clamp(0.4, 2.5));
    final stepY = 26.0 / math.sqrt(density.clamp(0.4, 2.5));
    int row = 0;
    for (double y = 12; y < size.height + 20; y += stepY) {
      int col = 0;
      for (double x = 12; x < size.width + 20; x += stepX) {
        final sym = (row + col) % 3;
        final c = _scatterPoint(Offset(x, y), (row * 37 + col * 17), stepX * 0.32, stepY * 0.38, size);
        if (sym == 0) {
          final p = Path()
            ..moveTo(c.dx - 9, c.dy - 4.5)
            ..lineTo(c.dx - 13, c.dy)
            ..lineTo(c.dx - 9, c.dy + 4.5)
            ..moveTo(c.dx - 3, c.dy + 5.5)
            ..lineTo(c.dx + 3, c.dy - 5.5)
            ..moveTo(c.dx + 9, c.dy - 4.5)
            ..lineTo(c.dx + 13, c.dy)
            ..lineTo(c.dx + 9, c.dy + 4.5);
          canvas.drawPath(p, stroke..strokeWidth = 0.9);
        } else if (sym == 1) {
          final p = Path()
            ..moveTo(c.dx - 6, c.dy - 5)
            ..lineTo(c.dx - 9, c.dy - 5)
            ..lineTo(c.dx - 9, c.dy - 1)
            ..lineTo(c.dx - 12, c.dy)
            ..lineTo(c.dx - 9, c.dy + 1)
            ..lineTo(c.dx - 9, c.dy + 5)
            ..lineTo(c.dx - 6, c.dy + 5)
            ..moveTo(c.dx + 6, c.dy - 5)
            ..lineTo(c.dx + 9, c.dy - 5)
            ..lineTo(c.dx + 9, c.dy - 1)
            ..lineTo(c.dx + 12, c.dy)
            ..lineTo(c.dx + 9, c.dy + 1)
            ..lineTo(c.dx + 9, c.dy + 5)
            ..lineTo(c.dx + 6, c.dy + 5);
          canvas.drawPath(p, stroke..strokeWidth = 0.9);
        } else {
          final p = Path()
            ..moveTo(c.dx - 8, c.dy - 4)
            ..lineTo(c.dx - 3, c.dy)
            ..lineTo(c.dx - 8, c.dy + 4)
            ..moveTo(c.dx + 1, c.dy + 4)
            ..lineTo(c.dx + 8, c.dy + 4);
          canvas.drawPath(p, stroke..strokeWidth = 0.9);
        }
        col++;
      }
      row++;
    }
  }

  void _drawHexagons(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final hexR = 14.0 / math.sqrt(density.clamp(0.4, 2.5));
    final wStep = hexR * 1.732;
    final hStep = hexR * 1.5;

    for (double y = -hStep / 2; y < size.height + hStep; y += hStep) {
      final isOdd = (((y + 1000) ~/ hStep) % 2 == 1);
      final startX = isOdd ? (wStep / 2) : 0.0;

      for (double x = startX - wStep; x < size.width + wStep; x += wStep) {
        final center = Offset(x, y);
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final angle = (i * math.pi / 3) - (math.pi / 6);
          final px = center.dx + hexR * math.cos(angle);
          final py = center.dy + hexR * math.sin(angle);
          if (i == 0) {
            path.moveTo(px, py);
          } else {
            path.lineTo(px, py);
          }
        }
        path.close();

        canvas.drawPath(path, stroke..strokeWidth = 0.8);
        canvas.drawCircle(center, 1.8, fill);

        if (((x + y).toInt() % 48) == 0) {
          canvas.drawCircle(center, hexR * 0.45, stroke..strokeWidth = 0.7);
        }
      }
    }
  }

  void _drawCubes(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final s = 14.0 / math.sqrt(density.clamp(0.4, 2.5));
    final dx = s * 1.732;
    final dy = s * 1.5;

    for (double y = -s; y < size.height + s * 2; y += dy) {
      final isOdd = (((y + 1000) ~/ dy) % 2 == 1);
      final startX = isOdd ? (dx / 2) : 0.0;

      for (double x = startX - dx; x < size.width + dx; x += dx) {
        final c = Offset(x, y);

        final topP = Path()
          ..moveTo(c.dx, c.dy - s)
          ..lineTo(c.dx + dx / 2, c.dy - s / 2)
          ..lineTo(c.dx, c.dy)
          ..lineTo(c.dx - dx / 2, c.dy - s / 2)
          ..close();
        canvas.drawPath(topP, fill);
        canvas.drawPath(topP, stroke..strokeWidth = 0.8);

        final leftP = Path()
          ..moveTo(c.dx - dx / 2, c.dy - s / 2)
          ..lineTo(c.dx, c.dy)
          ..lineTo(c.dx, c.dy + s)
          ..lineTo(c.dx - dx / 2, c.dy + s / 2)
          ..close();
        canvas.drawPath(leftP, stroke..strokeWidth = 0.8);

        final rightP = Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + dx / 2, c.dy - s / 2)
          ..lineTo(c.dx + dx / 2, c.dy + s / 2)
          ..lineTo(c.dx, c.dy + s)
          ..close();
        canvas.drawPath(rightP, stroke..strokeWidth = 0.8);
      }
    }
  }

  void _drawWaves(Canvas canvas, Size size, Paint stroke) {
    final stepY = 22.0 / math.sqrt(density.clamp(0.4, 2.5));
    final freq = 0.045 * math.sqrt(density.clamp(0.4, 2.5));

    for (double y = -5; y < size.height + 25; y += stepY) {
      final p = Path();
      for (double x = -10; x <= size.width + 15; x += 4) {
        final waveY = y + 7 * math.sin(x * freq + (y * 0.12));
        if (x == -10) {
          p.moveTo(x, waveY);
        } else {
          p.lineTo(x, waveY);
        }
      }
      canvas.drawPath(p, stroke..strokeWidth = 0.85);
    }
  }

  void _drawShield(Canvas canvas, Size size, Paint stroke, Paint fill) {
    if (size.height <= 60) {
      final cy = size.height / 2;
      final step = 46.0 / math.sqrt(density.clamp(0.4, 2.5));
      int idx = 0;
      for (double x = 18; x < size.width + 30; x += step) {
        final baseS = (11.0 * math.sqrt(density.clamp(0.5, 2.0))).clamp(8.0, 16.0);
        final s = (baseS * (1.0 + (_pr(idx * 23 + 9) - 0.5) * 0.35 * randomness)).clamp(6.0, 20.0);
        final dy = (_pr(idx * 37 + 13) * 2.0 - 1.0) * (size.height * 0.42) * randomness;
        final dx = (_pr(idx * 43 + 3) * 2.0 - 1.0) * (step * 0.35) * randomness;
        final center = Offset(x + dx, (cy + dy).clamp(3.0, size.height - 3.0));

        _drawSingleShield(canvas, center, s, stroke, fill);

        if (randomness >= 0.50 && idx % 2 == 1) {
          final altDy = -dy * 0.85;
          _drawSingleShield(canvas, Offset(x + step * 0.45 + dx * 0.3, (cy + altDy).clamp(3.0, size.height - 3.0)), s * 0.62, stroke, fill);
        }
        idx++;
      }
      return;
    }

    final d = math.sqrt(density.clamp(0.4, 2.5));
    _drawSingleShield(canvas, _scatterPoint(Offset(size.width * 0.80, size.height * 0.10), 301, size.width * 0.10, size.height * 0.05), 24 * d, stroke, fill);
    _drawSingleShield(canvas, _scatterPoint(Offset(size.width * 0.20, size.height * 0.32), 302, size.width * 0.10, size.height * 0.05), 26 * d, stroke, fill);
    _drawSingleShield(canvas, _scatterPoint(Offset(size.width * 0.82, size.height * 0.53), 303, size.width * 0.10, size.height * 0.05), 28 * d, stroke, fill);
    _drawSingleShield(canvas, _scatterPoint(Offset(size.width * 0.22, size.height * 0.74), 304, size.width * 0.10, size.height * 0.05), 26 * d, stroke, fill);
    _drawSingleShield(canvas, _scatterPoint(Offset(size.width * 0.50, size.height * 0.88), 305, size.width * 0.08, size.height * 0.04), 40 * d, stroke, fill);

    if (density >= 1.25) {
      _drawSingleShield(canvas, _scatterPoint(Offset(size.width * 0.52, size.height * 0.20), 306, size.width * 0.10, size.height * 0.05), 20 * d, stroke, fill);
      _drawSingleShield(canvas, _scatterPoint(Offset(size.width * 0.72, size.height * 0.70), 307, size.width * 0.10, size.height * 0.05), 22 * d, stroke, fill);
    }
  }

  void _drawSingleShield(Canvas canvas, Offset c, double s, Paint stroke, Paint fill) {
    final outerPath = Path()
      ..moveTo(c.dx, c.dy - s)
      ..lineTo(c.dx + s * 0.85, c.dy - s * 0.45)
      ..quadraticBezierTo(c.dx + s * 0.8, c.dy + s * 0.4, c.dx, c.dy + s)
      ..quadraticBezierTo(c.dx - s * 0.8, c.dy + s * 0.4, c.dx - s * 0.85, c.dy - s * 0.45)
      ..close();

    canvas.drawPath(outerPath, fill);
    canvas.drawPath(outerPath, stroke..strokeWidth = 1.4);

    final innerS = s * 0.78;
    final innerPath = Path()
      ..moveTo(c.dx, c.dy - innerS)
      ..lineTo(c.dx + innerS * 0.85, c.dy - innerS * 0.45)
      ..quadraticBezierTo(c.dx + innerS * 0.8, c.dy + innerS * 0.4, c.dx, c.dy + innerS)
      ..quadraticBezierTo(c.dx - innerS * 0.8, c.dy + innerS * 0.4, c.dx - innerS * 0.85, c.dy - innerS * 0.45)
      ..close();
    canvas.drawPath(innerPath, stroke..strokeWidth = 0.8);

    final starR = s * 0.35;
    final starPath = Path();
    for (int i = 0; i < 5; i++) {
      final a1 = (i * 4 * math.pi / 5) - (math.pi / 2);
      final px = c.dx + starR * math.cos(a1);
      final py = c.dy + starR * math.sin(a1);
      if (i == 0) {
        starPath.moveTo(px, py);
      } else {
        starPath.lineTo(px, py);
      }
    }
    starPath.close();
    canvas.drawPath(starPath, fill);
    canvas.drawPath(starPath, stroke..strokeWidth = 0.9);
  }

  void _drawBlueprintLines(Canvas canvas, Size size, Paint stroke) {
    final step = 14.0 / math.sqrt(density.clamp(0.4, 2.5));
    for (double y = 0; y <= size.height + step; y += step) {
      final isMajor = (((y / step).round()) % 4 == 0);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), stroke..strokeWidth = isMajor ? 0.9 : 0.45);
    }
    for (double x = 0; x <= size.width + step; x += step) {
      final isMajor = (((x / step).round()) % 4 == 0);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), stroke..strokeWidth = isMajor ? 0.9 : 0.45);
    }

    final crossR = 5.5;
    for (double y = 30; y < size.height; y += 100) {
      for (double x = 30; x < size.width; x += 100) {
        canvas.drawLine(Offset(x - crossR, y), Offset(x + crossR, y), stroke..strokeWidth = 1.0);
        canvas.drawLine(Offset(x, y - crossR), Offset(x, y + crossR), stroke..strokeWidth = 1.0);
        canvas.drawCircle(Offset(x, y), crossR * 0.65, stroke..strokeWidth = 0.7);
      }
    }
  }

  void _drawLeaves(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final stepX = 42.0 / math.sqrt(density.clamp(0.4, 2.5));
    final stepY = 32.0 / math.sqrt(density.clamp(0.4, 2.5));

    for (double y = 10; y < size.height + 20; y += stepY) {
      for (double x = 10; x < size.width + 20; x += stepX) {
        final c = _scatterPoint(Offset(x, y), (x * 11 + y * 17).toInt(), stepX * 0.35, stepY * 0.35, size);
        final p = Path()
          ..moveTo(c.dx - 10, c.dy + 8)
          ..quadraticBezierTo(c.dx - 8, c.dy - 6, c.dx + 10, c.dy - 8)
          ..quadraticBezierTo(c.dx + 8, c.dy + 6, c.dx - 10, c.dy + 8);
        canvas.drawPath(p, fill);
        canvas.drawPath(p, stroke..strokeWidth = 0.85);
        canvas.drawLine(Offset(c.dx - 10, c.dy + 8), Offset(c.dx + 10, c.dy - 8), stroke..strokeWidth = 0.7);
      }
    }
  }

  @override
  bool shouldRepaint(covariant WatermarkPainter oldDelegate) {
    return oldDelegate.pattern != pattern ||
        oldDelegate.opacity != opacity ||
        oldDelegate.density != density ||
        oldDelegate.randomness != randomness;
  }

  // ==============================================================================
  // HIGH-RESOLUTION RENDERER FOR PDF EXPORT
  // Renders the exact watermark onto a PNG buffer at 2x scale for print quality
  // ==============================================================================
  static Future<Uint8List?> renderWatermarkPng({
    required String pattern,
    required double opacity,
    required double density,
    required double randomness,
    required double width,
    required double height,
    Color? backgroundColor,
    double borderRadius = 0.0,
    String? customWatermarkUrl,
    double pixelRatio = 2.0,
  }) async {
    final effectiveOpacity = opacity.clamp(0.0, 1.0);
    if ((pattern == 'none' || effectiveOpacity <= 0.0) && backgroundColor == null) {
      return null;
    }
    if (width <= 0 || height <= 0) {
      return null;
    }

    final targetW = (width * pixelRatio).round().clamp(10, 4000);
    final targetH = (height * pixelRatio).round().clamp(10, 4000);

    // Custom Watermark (User image)
    if (pattern == 'custom' && customWatermarkUrl != null && customWatermarkUrl.isNotEmpty) {
      try {
        Uint8List? rawBytes;
        if (customWatermarkUrl.startsWith('data:image')) {
          final commaIdx = customWatermarkUrl.indexOf(',');
          final b64 = commaIdx != -1 ? customWatermarkUrl.substring(commaIdx + 1) : customWatermarkUrl;
          rawBytes = base64Decode(b64);
        }
        if (rawBytes != null) {
          final codec = await ui.instantiateImageCodec(rawBytes);
          final frame = await codec.getNextFrame();
          final userImg = frame.image;

          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()));

          if (backgroundColor != null) {
            final rrect = RRect.fromRectAndRadius(
              Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
              Radius.circular(borderRadius * pixelRatio),
            );
            canvas.drawRRect(rrect, Paint()..color = backgroundColor);
            canvas.clipRRect(rrect);
          }

          final paint = Paint()
            ..colorFilter = ColorFilter.mode(
              Colors.white.withOpacity(effectiveOpacity),
              BlendMode.modulate,
            );

          // Cover fit
          final srcRect = Rect.fromLTWH(0, 0, userImg.width.toDouble(), userImg.height.toDouble());
          final dstRect = Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble());
          canvas.drawImageRect(userImg, srcRect, dstRect, paint);

          final pic = recorder.endRecording();
          final outImg = await pic.toImage(targetW, targetH);
          final byteData = await outImg.toByteData(format: ui.ImageByteFormat.png);
          return byteData?.buffer.asUint8List();
        }
      } catch (e) {
        debugPrint('[WatermarkRenderer] Custom watermark error: $e');
      }
    }

    // Vector Pattern Watermark or solid/rounded background
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()));

      canvas.scale(pixelRatio, pixelRatio);

      if (backgroundColor != null) {
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, width, height),
          Radius.circular(borderRadius),
        );
        canvas.drawRRect(rrect, Paint()..color = backgroundColor);
        canvas.clipRRect(rrect);
      }

      if (pattern != 'none' && effectiveOpacity > 0.0) {
        final painter = WatermarkPainter(
          pattern: pattern,
          opacity: effectiveOpacity,
          density: density,
          randomness: randomness,
        );

        painter.paint(canvas, Size(width, height));
      }

      final pic = recorder.endRecording();
      final outImg = await pic.toImage(targetW, targetH);
      final byteData = await outImg.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[WatermarkRenderer] Error rendering watermark PNG: $e');
      return null;
    }
  }
}
