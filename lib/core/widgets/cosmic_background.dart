import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class CosmicBackground extends StatefulWidget {
  final Widget child;
  final bool isCosmicActive;
  final bool isDark;

  const CosmicBackground({
    super.key,
    required this.child,
    this.isCosmicActive = true,
    this.isDark = true,
  });

  @override
  State<CosmicBackground> createState() => _CosmicBackgroundState();
}

class _CosmicBackgroundState extends State<CosmicBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<CosmicStar> _stars = [];
  final math.Random _random = math.Random(1337);

  @override
  void initState() {
    super.initState();
    // 20-second cycle for smooth, lively cosmos
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Helper: 45% golden amber, 40% brilliant diamond white, 10% champagne gold, 5% sapphire cyan
    int pickColorType() {
      final r = _random.nextDouble();
      if (r < 0.40) return 0; // Pure white / silver
      if (r < 0.85) return 1; // Warm golden amber
      if (r < 0.95) return 2; // Sparkling champagne gold
      return 3; // Sapphire cyan
    }

    // 1. Layer 1: Distant micro-dust stars (140 stars)
    for (int i = 0; i < 140; i++) {
      _stars.add(CosmicStar(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        radius: _random.nextDouble() * 0.9 + 0.6,
        alphaBase: _random.nextDouble() * 0.45 + 0.25,
        twinkleSpeed: _random.nextDouble() * 4.5 + 2.0,
        phase: _random.nextDouble() * math.pi * 2,
        colorType: pickColorType(),
        layer: 1,
      ));
    }

    // 2. Layer 2: Medium bright stars (80 stars)
    for (int i = 0; i < 80; i++) {
      _stars.add(CosmicStar(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        radius: _random.nextDouble() * 1.3 + 1.2,
        alphaBase: _random.nextDouble() * 0.5 + 0.40,
        twinkleSpeed: _random.nextDouble() * 6.5 + 3.0,
        phase: _random.nextDouble() * math.pi * 2,
        colorType: pickColorType(),
        layer: 2,
      ));
    }

    // 3. Layer 3: Large radiant flare stars (36 stars) with multi-frequency sparkle
    for (int i = 0; i < 36; i++) {
      _stars.add(CosmicStar(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        radius: _random.nextDouble() * 1.6 + 2.2,
        alphaBase: _random.nextDouble() * 0.5 + 0.50,
        twinkleSpeed: _random.nextDouble() * 8.5 + 4.0,
        phase: _random.nextDouble() * math.pi * 2,
        colorType: pickColorType(),
        layer: 3,
        hasFlare: true,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCosmicActive) {
      return Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: CosmicPainter(
                animationValue: 0.0,
                stars: _stars,
                isDark: widget.isDark,
                isStatic: true,
              ),
            ),
          ),
          widget.child,
        ],
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: CosmicPainter(
                  animationValue: _controller.value,
                  stars: _stars,
                  isDark: widget.isDark,
                  isStatic: false,
                ),
              );
            },
          ),
        ),
        widget.child,
      ],
    );
  }
}

class CosmicStar {
  final double x;
  final double y;
  final double radius;
  final double alphaBase;
  final double twinkleSpeed;
  final double phase;
  final int colorType; // 0: white, 1: golden amber, 2: champagne gold, 3: sapphire cyan
  final int layer;
  final bool hasFlare;

  CosmicStar({
    required this.x,
    required this.y,
    required this.radius,
    required this.alphaBase,
    required this.twinkleSpeed,
    required this.phase,
    required this.colorType,
    required this.layer,
    this.hasFlare = false,
  });
}

class CosmicPainter extends CustomPainter {
  final double animationValue;
  final List<CosmicStar> stars;
  final bool isDark;
  final bool isStatic;

  CosmicPainter({
    required this.animationValue,
    required this.stars,
    required this.isDark,
    this.isStatic = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Deep Space Atmospheric Gradient Background
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                const Color(0xFF05080E),
                const Color(0xFF090E18),
                const Color(0xFF0C1424),
                const Color(0xFF070B12),
              ]
            : [
                const Color(0xFFDCE6F1),
                const Color(0xFFE8EEF5),
                const Color(0xFFF4F7FB),
              ],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    if (size.width <= 0 || size.height <= 0) return;

    // 2. Cosmic Nebulae Glow Clouds (Organic harmonic oscillation)
    _drawNebulae(canvas, size);

    // 3. Floating Celestial Sanctuary Ringed Planet & Moon with Pendular Back-and-Forth Oscillation
    _drawCelestialBodies(canvas, size);

    // 4. Multidirectional Passing Comets / Meteors (Only active when animated)
    if (!isStatic) {
      _drawComets(canvas, size);
    }

    // 5. Fixed Starry Sky: Stars remain anchored (no drift jumps) with fast golden-rich twinkling
    for (final star in stars) {
      // High-speed dual sine cadence for sparkling twinkle
      final double progress1 = animationValue * math.pi * 2 * star.twinkleSpeed + star.phase;
      final double progress2 = animationValue * math.pi * 4 * (star.twinkleSpeed * 0.6) + star.phase * 1.5;
      final double twinkle = ((math.sin(progress1) + math.cos(progress2)) / 2 + 1) / 2; // 0..1
      final double alpha = (star.alphaBase + twinkle * 0.65).clamp(0.12, 1.0);

      Color starColor;
      Color glowColor;
      if (isDark) {
        switch (star.colorType) {
          case 1:
            starColor = Color.fromRGBO(251, 191, 36, alpha); // Warm Golden Amber
            glowColor = const Color(0xFFF59E0B);
            break;
          case 2:
            starColor = Color.fromRGBO(253, 230, 138, alpha); // Sparkling Champagne Gold
            glowColor = const Color(0xFFD97706);
            break;
          case 3:
            starColor = Color.fromRGBO(56, 189, 248, alpha); // Sapphire Cyan
            glowColor = const Color(0xFF0EA5E9);
            break;
          default:
            starColor = Color.fromRGBO(255, 255, 255, alpha); // Diamond White
            glowColor = Colors.white;
        }
      } else {
        // High-contrast light theme stars (rich amber and deep slate)
        switch (star.colorType) {
          case 1:
            starColor = Color.fromRGBO(217, 119, 6, alpha); // Golden Amber
            glowColor = const Color(0xFFB45309);
            break;
          case 2:
            starColor = Color.fromRGBO(180, 83, 9, alpha); // Warm Ochre
            glowColor = const Color(0xFF92400E);
            break;
          case 3:
            starColor = Color.fromRGBO(2, 132, 199, alpha); // Sapphire Blue
            glowColor = const Color(0xFF0369A1);
            break;
          default:
            starColor = Color.fromRGBO(15, 23, 42, alpha * 0.85); // Deep Slate Star
            glowColor = const Color(0xFF64748B);
        }
      }

      final starPaint = Paint()..color = starColor;

      // Stars remain permanently anchored to their coordinates: NO translation, NO jump when repeating
      final starPos = Offset(star.x * size.width, star.y * size.height);

      // Draw star core
      canvas.drawCircle(starPos, star.radius, starPaint);

      // Draw outer halo and diffraction spikes for flare stars in BOTH themes
      if (star.hasFlare) {
        final flareIntensity = (twinkle * alpha).clamp(0.15, 1.0);

        // Soft outer halo glow
        final haloPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              glowColor.withOpacity(flareIntensity * (isDark ? 0.45 : 0.35)),
              glowColor.withOpacity(flareIntensity * 0.10),
              Colors.transparent,
            ],
            stops: const [0.0, 0.4, 1.0],
          ).createShader(Rect.fromCircle(center: starPos, radius: star.radius * 5.5));
        canvas.drawCircle(starPos, star.radius * 5.5, haloPaint);

        // 4-Point cross sparkle flare
        final double spikeLen = star.radius * (3.5 + twinkle * 4.0);
        final spikePaint = Paint()
          ..color = starColor.withOpacity(flareIntensity * (isDark ? 0.85 : 0.75))
          ..strokeWidth = isDark ? 0.9 : 1.1;

        // Horizontal spike
        canvas.drawLine(
          Offset(starPos.dx - spikeLen, starPos.dy),
          Offset(starPos.dx + spikeLen, starPos.dy),
          spikePaint,
        );
        // Vertical spike
        canvas.drawLine(
          Offset(starPos.dx, starPos.dy - spikeLen),
          Offset(starPos.dx, starPos.dy + spikeLen),
          spikePaint,
        );

        // Diagonal micro-glints for peak moments
        if (twinkle > 0.60) {
          final diagLen = spikeLen * 0.55;
          final diagPaint = Paint()
            ..color = starColor.withOpacity(flareIntensity * 0.5)
            ..strokeWidth = 0.7;
          canvas.drawLine(
            Offset(starPos.dx - diagLen, starPos.dy - diagLen),
            Offset(starPos.dx + diagLen, starPos.dy + diagLen),
            diagPaint,
          );
          canvas.drawLine(
            Offset(starPos.dx + diagLen, starPos.dy - diagLen),
            Offset(starPos.dx - diagLen, starPos.dy + diagLen),
            diagPaint,
          );
        }
      }
    }
  }

  void _drawNebulae(Canvas canvas, Size size) {
    // Continuous harmonic swing (sin(t * 2pi) returns seamlessly to 0 at t=1)
    final swing1 = math.sin(animationValue * 2 * math.pi);
    final swing2 = math.sin(animationValue * 2 * math.pi + math.pi);

    // Nebula 1: Emerald Sanctuary Core (Top Right)
    final nebula1Center = Offset(
      size.width * 0.82 + swing1 * 24,
      size.height * 0.18 + swing1 * 16,
    );
    final nebula1Paint = Paint()
      ..shader = RadialGradient(
        colors: isDark
            ? [
                const Color(0xFF10B981).withOpacity(0.14),
                const Color(0xFF06B6D4).withOpacity(0.07),
                Colors.transparent,
              ]
            : [
                const Color(0xFF10B981).withOpacity(0.08),
                const Color(0xFF06B6D4).withOpacity(0.04),
                Colors.transparent,
              ],
        radius: 0.9,
      ).createShader(Rect.fromCircle(center: nebula1Center, radius: 380));
    canvas.drawCircle(nebula1Center, 380, nebula1Paint);

    // Nebula 2: Deep Violet / Sapphire Nebula (Bottom Left)
    final nebula2Center = Offset(
      size.width * 0.15 + swing2 * 20,
      size.height * 0.78 + swing2 * 18,
    );
    final nebula2Paint = Paint()
      ..shader = RadialGradient(
        colors: isDark
            ? [
                const Color(0xFF8B5CF6).withOpacity(0.12),
                const Color(0xFF3B82F6).withOpacity(0.05),
                Colors.transparent,
              ]
            : [
                const Color(0xFF3B82F6).withOpacity(0.06),
                const Color(0xFF8B5CF6).withOpacity(0.04),
                Colors.transparent,
              ],
        radius: 0.85,
      ).createShader(Rect.fromCircle(center: nebula2Center, radius: 340));
    canvas.drawCircle(nebula2Center, 340, nebula2Paint);

    // Nebula 3: Cosmic Cyan Horizon (Center Ambient)
    final nebula3Center = Offset(size.width * 0.5, size.height * 0.45);
    final nebula3Paint = Paint()
      ..shader = RadialGradient(
        colors: isDark
            ? [
                const Color(0xFF06B6D4).withOpacity(0.05),
                Colors.transparent,
              ]
            : [
                const Color(0xFF0EA5E9).withOpacity(0.035),
                Colors.transparent,
              ],
        radius: 0.9,
      ).createShader(Rect.fromCircle(center: nebula3Center, radius: 460));
    canvas.drawCircle(nebula3Center, 460, nebula3Paint);
  }

  void _drawCelestialBodies(Canvas canvas, Size size) {
    // Pendular oscillation: smooth harmonic swing back-and-forth so at t=1 it connects seamlessly
    final oscX = math.sin(animationValue * 2 * math.pi) * 32.0;
    final oscY = math.sin(animationValue * 4 * math.pi) * 12.0;

    final planetCenter = Offset(
      size.width * 0.86 + oscX,
      size.height * 0.18 + oscY,
    );
    const double planetRadius = 38.0;

    // Atmospheric Glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: isDark
            ? [
                const Color(0xFF10B981).withOpacity(0.40),
                const Color(0xFF059669).withOpacity(0.16),
                Colors.transparent,
              ]
            : [
                const Color(0xFF10B981).withOpacity(0.25),
                const Color(0xFF059669).withOpacity(0.08),
                Colors.transparent,
              ],
      ).createShader(Rect.fromCircle(center: planetCenter, radius: planetRadius * 2.5));
    canvas.drawCircle(planetCenter, planetRadius * 2.5, glowPaint);

    // Planet Body Sphere with 3D Spherical Shader
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        colors: isDark
            ? [
                const Color(0xFF6EE7B7),
                const Color(0xFF10B981),
                const Color(0xFF047857),
                const Color(0xFF022C22),
              ]
            : [
                const Color(0xFFA7F3D0),
                const Color(0xFF34D399),
                const Color(0xFF059669),
              ],
      ).createShader(Rect.fromCircle(center: planetCenter, radius: planetRadius));
    canvas.drawCircle(planetCenter, planetRadius, bodyPaint);

    // Planet Rings with Oscillating Tilt
    final ringPaint = Paint()
      ..color = (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669)).withOpacity(isDark ? 0.45 : 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6;

    final outerRingPaint = Paint()
      ..color = (isDark ? const Color(0xFF34D399) : const Color(0xFF10B981)).withOpacity(isDark ? 0.25 : 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.save();
    canvas.translate(planetCenter.dx, planetCenter.dy);
    canvas.rotate(-0.38 + math.sin(animationValue * 2 * math.pi) * 0.08);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: planetRadius * 3.4, height: planetRadius * 0.9),
      ringPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: planetRadius * 3.9, height: planetRadius * 1.1),
      outerRingPaint,
    );
    canvas.restore();

    // Distant Sapphire Moon with harmonic pendulum swing
    final moonOscX = math.sin(animationValue * 2 * math.pi + math.pi) * 24.0;
    final moonOscY = math.sin(animationValue * 4 * math.pi + math.pi) * 10.0;
    final moonCenter = Offset(
      size.width * 0.10 + moonOscX,
      size.height * 0.65 + moonOscY,
    );
    const double moonRadius = 17.0;

    final moonGlow = Paint()
      ..shader = RadialGradient(
        colors: isDark
            ? [
                const Color(0xFF38BDF8).withOpacity(0.28),
                Colors.transparent,
              ]
            : [
                const Color(0xFF0284C7).withOpacity(0.18),
                Colors.transparent,
              ],
      ).createShader(Rect.fromCircle(center: moonCenter, radius: moonRadius * 2.2));
    canvas.drawCircle(moonCenter, moonRadius * 2.2, moonGlow);

    final moonPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        colors: isDark
            ? [
                const Color(0xFFBAE6FD),
                const Color(0xFF38BDF8),
                const Color(0xFF0369A1),
                const Color(0xFF082F49),
              ]
            : [
                const Color(0xFFE0F2FE),
                const Color(0xFF38BDF8),
                const Color(0xFF0284C7),
              ],
      ).createShader(Rect.fromCircle(center: moonCenter, radius: moonRadius));
    canvas.drawCircle(moonCenter, moonRadius, moonPaint);
  }

  /// Draws a single shooting star/comet guaranteed to travel head-first.
  /// The gradient starts bright at [currentHead] and fades out along [-u] to [currentTail].
  void _drawSingleComet({
    required Canvas canvas,
    required Offset start,
    required Offset end,
    required double cycleProgress, // 0..1
    required double activeFraction, // portion of cycle during which comet streaks
    required Color coreColor,
    required Color midColor,
    double tailLength = 95.0,
    double strokeWidth = 2.4,
  }) {
    if (cycleProgress >= activeFraction) return;

    final double t = cycleProgress / activeFraction; // 0..1
    final double dx = end.dx - start.dx;
    final double dy = end.dy - start.dy;
    final double totalDist = math.sqrt(dx * dx + dy * dy);
    if (totalDist == 0) return;

    // Unit vector along motion
    final double ux = dx / totalDist;
    final double uy = dy / totalDist;

    // Current position of the leading head
    final currentHead = Offset(start.dx + ux * totalDist * t, start.dy + uy * totalDist * t);

    // The tail is strictly behind the head (in the opposite direction of motion -ux, -uy)
    final currentTail = Offset(currentHead.dx - ux * tailLength, currentHead.dy - uy * tailLength);

    // Fade in as it starts, fade out at end
    final double alpha = math.sin(t * math.pi).clamp(0.0, 1.0);
    if (alpha <= 0.01) return;

    // Head-to-tail vector gradient: currentHead is stop 0.0 (bright core), currentTail is stop 1.0 (transparent)
    final tailShader = ui.Gradient.linear(
      currentHead,
      currentTail,
      isDark
          ? [
              Colors.white.withOpacity(alpha * 0.98),
              coreColor.withOpacity(alpha * 0.85),
              midColor.withOpacity(alpha * 0.35),
              Colors.transparent,
            ]
          : [
              coreColor.withOpacity(alpha * 0.98),
              midColor.withOpacity(alpha * 0.70),
              coreColor.withOpacity(alpha * 0.25),
              Colors.transparent,
            ],
      const [0.0, 0.25, 0.70, 1.0],
    );

    final cometPaint = Paint()
      ..shader = tailShader
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw tail line behind head
    canvas.drawLine(currentHead, currentTail, cometPaint);

    // Draw glowing head nucleus at currentHead
    final headCorePaint = Paint()..color = (isDark ? Colors.white : coreColor).withOpacity(alpha);
    canvas.drawCircle(currentHead, strokeWidth * 0.85, headCorePaint);

    final headHaloPaint = Paint()..color = coreColor.withOpacity(alpha * 0.45);
    canvas.drawCircle(currentHead, strokeWidth * 2.2, headHaloPaint);
  }

  void _drawComets(Canvas canvas, Size size) {
    // -------------------------------------------------------------
    // COMET 1: Streaking from Top-Right down towards Center-Left
    // -------------------------------------------------------------
    _drawSingleComet(
      canvas: canvas,
      start: Offset(size.width * 0.92, size.height * 0.06),
      end: Offset(size.width * 0.22, size.height * 0.58),
      cycleProgress: (animationValue * 2.8) % 1.0,
      activeFraction: 0.26,
      coreColor: const Color(0xFF38BDF8), // Sapphire Cyan
      midColor: const Color(0xFF10B981),
      tailLength: 105.0,
      strokeWidth: isDark ? 2.4 : 2.6,
    );

    // -------------------------------------------------------------
    // COMET 2: Streaking from Top-Left down towards Bottom-Right
    // -------------------------------------------------------------
    _drawSingleComet(
      canvas: canvas,
      start: Offset(size.width * 0.06, size.height * 0.12),
      end: Offset(size.width * 0.78, size.height * 0.76),
      cycleProgress: (animationValue * 2.4 + 0.38) % 1.0,
      activeFraction: 0.28,
      coreColor: const Color(0xFF34D399), // Emerald
      midColor: const Color(0xFF06B6D4),
      tailLength: 100.0,
      strokeWidth: isDark ? 2.3 : 2.5,
    );

    // -------------------------------------------------------------
    // COMET 3: Ascending Shooting Star from Lower-Left up towards Upper-Right
    // -------------------------------------------------------------
    _drawSingleComet(
      canvas: canvas,
      start: Offset(size.width * 0.12, size.height * 0.86),
      end: Offset(size.width * 0.72, size.height * 0.24),
      cycleProgress: (animationValue * 2.2 + 0.68) % 1.0,
      activeFraction: 0.25,
      coreColor: const Color(0xFFF59E0B), // Golden Amber
      midColor: const Color(0xFFD97706),
      tailLength: 110.0,
      strokeWidth: isDark ? 2.2 : 2.4,
    );

    // -------------------------------------------------------------
    // COMET 4: Plunging from Top-Center diagonally down towards Lower-Left
    // -------------------------------------------------------------
    _drawSingleComet(
      canvas: canvas,
      start: Offset(size.width * 0.58, size.height * 0.02),
      end: Offset(size.width * 0.24, size.height * 0.72),
      cycleProgress: (animationValue * 3.1 + 0.15) % 1.0,
      activeFraction: 0.24,
      coreColor: const Color(0xFFC084FC), // Violet
      midColor: const Color(0xFF38BDF8),
      tailLength: 95.0,
      strokeWidth: isDark ? 2.1 : 2.3,
    );
  }

  @override
  bool shouldRepaint(covariant CosmicPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isDark != isDark ||
        oldDelegate.isStatic != isStatic;
  }
}
