import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The official Sanctuary logo: A celestial emerald-cyan planet
/// with a 3D tilted orbital ring and a sparkling star on its crest.
class SanctuaryPlanetLogo extends StatelessWidget {
  final double size;
  final bool showGlow;
  final String? tooltip;
  final VoidCallback? onTap;

  const SanctuaryPlanetLogo({
    super.key,
    this.size = 32,
    this.showGlow = false,
    this.tooltip = 'Santuario',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (showGlow)
            Container(
              width: size * 0.85,
              height: size * 0.85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06B6D4).withOpacity(0.35),
                    blurRadius: size * 0.35,
                    spreadRadius: size * 0.05,
                  ),
                ],
              ),
            ),
          CustomPaint(
            size: Size(size, size),
            painter: SanctuaryPlanetPainter(),
          ),
        ],
      ),
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size * 0.3),
        child: content,
      );
    }

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: content,
      );
    }

    return content;
  }
}

class SanctuaryPlanetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final double planetR = size.width * 0.30;

    // 1. Orbital ring behind planet (back half)
    final ringPaint = Paint()
      ..color = const Color(0xFF34D399).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, size.width * 0.04);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.42);

    // Draw full back ellipse
    canvas.drawArc(
      Rect.fromCenter(center: Offset.zero, width: planetR * 3.4, height: planetR * 1.05),
      math.pi,
      math.pi,
      false,
      ringPaint,
    );
    canvas.restore();

    // 2. Planet Sphere with 3D Radiant Gradient
    final planetPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        colors: const [
          Color(0xFF6EE7B7),
          Color(0xFF10B981),
          Color(0xFF047857),
          Color(0xFF022C22),
        ],
        stops: const [0.0, 0.45, 0.8, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: planetR));

    canvas.drawCircle(center, planetR, planetPaint);

    // 3. Orbital ring in front of planet (front half)
    final frontRingPaint = Paint()
      ..shader = LinearGradient(
        colors: const [
          Color(0xFF6EE7B7),
          Color(0xFF38BDF8),
          Color(0xFF10B981),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: planetR * 1.8))
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, size.width * 0.04);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.42);
    canvas.drawArc(
      Rect.fromCenter(center: Offset.zero, width: planetR * 3.4, height: planetR * 1.05),
      0,
      math.pi,
      false,
      frontRingPaint,
    );
    canvas.restore();

    // 4. Sparkling star on the planet's crest
    final sparkCenter = Offset(center.dx + planetR * 0.5, center.dy - planetR * 0.5);
    final sparkPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = math.max(1.2, size.width * 0.02)
      ..strokeCap = StrokeCap.round;

    final sparkLen = math.max(2.5, planetR * 0.22);
    canvas.drawLine(Offset(sparkCenter.dx - sparkLen, sparkCenter.dy), Offset(sparkCenter.dx + sparkLen, sparkCenter.dy), sparkPaint);
    canvas.drawLine(Offset(sparkCenter.dx, sparkCenter.dy - sparkLen), Offset(sparkCenter.dx, sparkCenter.dy + sparkLen), sparkPaint);
    canvas.drawCircle(sparkCenter, math.max(1.0, size.width * 0.018), Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
