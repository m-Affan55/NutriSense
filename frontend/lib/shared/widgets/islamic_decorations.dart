import 'package:flutter/material.dart';
import '../../core/ramadan_controller.dart';

/// Full-screen or Container background wrapper that paints:
/// - Golden lanterns, crescent moon, and celestial stars when Ramadan mode is active.
/// - Fresh botanical leaves, citrus slices, hydration dew drops, and vitality
///   particles in natural organic colors for the standard nutrition theme.
class RamadanBackgroundWrapper extends StatelessWidget {
  final Widget child;
  final bool? isRamadan;

  const RamadanBackgroundWrapper({
    super.key,
    required this.child,
    this.isRamadan,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RamadanController.instance,
      builder: (context, _) {
        final active = isRamadan ?? RamadanController.instance.isRamadanMode;

        if (!active) {
          // Normal Nutrition & Wellness Theme Background
          return Stack(
            children: [
              // 1. Natural Dark Obsidian/Forest Slate base with organic emerald glow
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF090C10),
                    gradient: RadialGradient(
                      center: Alignment(0.25, -0.65),
                      radius: 1.35,
                      colors: [
                        Color(0xFF13221B), // Deep natural organic herbal emerald
                        Color(0xFF0D1217), // Sleek obsidian slate
                        Color(0xFF07090C), // Pure dark base
                      ],
                      stops: [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),

              // 2. Custom Painted Natural Nutrition Visuals
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: NutritionVisualsPainter(),
                  ),
                ),
              ),

              // 3. Screen Child Contents
              Positioned.fill(
                child: child,
              ),
            ],
          );
        }

        // Ramadan Mode Theme Background
        return Stack(
          children: [
            // 1. Deep Midnight/Royal Blue base with ambient radial glow
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF070C18),
                  gradient: RadialGradient(
                    center: Alignment(0.3, -0.6),
                    radius: 1.4,
                    colors: [
                      Color(0xFF14244A), // Rich luminous indigo-blue
                      Color(0xFF0C162E), // Deep midnight blue
                      Color(0xFF060A14), // Dark abyss
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),

            // 2. Custom Painted Golden Islamic Visuals (Lanterns, Crescent Moon, Stars)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: IslamicVisualsPainter(),
                ),
              ),
            ),

            // 3. Main Screen Contents
            Positioned.fill(
              child: child,
            ),
          ],
        );
      },
    );
  }
}

/// Custom painter that renders natural nutrition visuals:
/// - Fresh botanical leaves & herbal sprigs in natural green
/// - Sliced citrus / kiwi fruit nutrition motifs
/// - Crystal hydration dew drops
/// - Micro vitality & vitamin energy sparkles
class NutritionVisualsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _paintAmbientAtmosphere(canvas, size);
    _paintBotanicalLeaves(canvas, size);
    _paintCitrusFruitSlice(canvas, size);
    _paintHydrationDrops(canvas, size);
    _paintVitalitySparkles(canvas, size);
  }

  /// 1. Paint soft ambient organic glow orbs
  void _paintAmbientAtmosphere(Canvas canvas, Size size) {
    final glowPaint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);

    // Natural Emerald Botanical Glow (top-left)
    glowPaint.color = const Color(0x1A00E676);
    canvas.drawCircle(Offset(size.width * 0.20, size.height * 0.14), 100, glowPaint);

    // Sunny Citrus Amber Glow (top-right)
    glowPaint.color = const Color(0x16FFD54F);
    canvas.drawCircle(Offset(size.width * 0.78, size.height * 0.16), 110, glowPaint);

    // Fresh Hydration Blue-Green Glow (mid-left)
    glowPaint.color = const Color(0x1400E5FF);
    canvas.drawCircle(Offset(size.width * 0.50, size.height * 0.32), 85, glowPaint);
  }

  /// 2. Paint botanical leaves & organic herbal branches
  void _paintBotanicalLeaves(Canvas canvas, Size size) {
    // Large prominent organic leaf branch (Top Right)
    _drawLeafBranch(
      canvas: canvas,
      origin: Offset(size.width * 0.88, size.height * 0.08),
      scale: 1.1,
      angle: -0.35,
    );

    // Dual sprout leaves (Top Left)
    _drawSproutLeaves(
      canvas: canvas,
      origin: Offset(size.width * 0.12, size.height * 0.08),
      scale: 0.9,
    );

    // Floating herbal leaflet (Mid-Right)
    _drawSingleLeaf(
      canvas: canvas,
      center: Offset(size.width * 0.82, size.height * 0.28),
      length: 28.0,
      width: 14.0,
      angle: 0.65,
      color: const Color(0x3066BB6A),
    );

    // Floating small leaflet (Mid-Left)
    _drawSingleLeaf(
      canvas: canvas,
      center: Offset(size.width * 0.18, size.height * 0.24),
      length: 22.0,
      width: 11.0,
      angle: -0.55,
      color: const Color(0x2881C784),
    );
  }

  /// Draw a curving herbal stem with multiple lush leaves
  void _drawLeafBranch({
    required Canvas canvas,
    required Offset origin,
    required double scale,
    required double angle,
  }) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(angle);

    final stemPaint = Paint()
      ..color = const Color(0x3581C784)
      ..strokeWidth = 1.6 * scale
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Curving branch stem
    final stemPath = Path();
    stemPath.moveTo(0, 0);
    stemPath.quadraticBezierTo(20 * scale, 35 * scale, 10 * scale, 70 * scale);
    canvas.drawPath(stemPath, stemPaint);

    // Leaf 1 (Left branch leaf)
    _drawSingleLeaf(
      canvas: canvas,
      center: Offset(-14 * scale, 22 * scale),
      length: 32 * scale,
      width: 16 * scale,
      angle: -0.7,
      color: const Color(0x3500E676),
    );

    // Leaf 2 (Right branch leaf)
    _drawSingleLeaf(
      canvas: canvas,
      center: Offset(18 * scale, 38 * scale),
      length: 36 * scale,
      width: 18 * scale,
      angle: 0.5,
      color: const Color(0x354CAF50),
    );

    // Leaf 3 (Terminal tip leaf)
    _drawSingleLeaf(
      canvas: canvas,
      center: Offset(10 * scale, 75 * scale),
      length: 30 * scale,
      width: 14 * scale,
      angle: 0.15,
      color: const Color(0x3566BB6A),
    );

    canvas.restore();
  }

  /// Draw a pair of sprouting natural leaves
  void _drawSproutLeaves({
    required Canvas canvas,
    required Offset origin,
    required double scale,
  }) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);

    // Left sprout lobe
    _drawSingleLeaf(
      canvas: canvas,
      center: Offset(-12 * scale, 10 * scale),
      length: 26 * scale,
      width: 13 * scale,
      angle: -0.85,
      color: const Color(0x3069F0AE),
    );

    // Right sprout lobe
    _drawSingleLeaf(
      canvas: canvas,
      center: Offset(12 * scale, 10 * scale),
      length: 26 * scale,
      width: 13 * scale,
      angle: 0.85,
      color: const Color(0x3000E676),
    );

    // Tiny stem base
    final sproutPaint = Paint()
      ..color = const Color(0x35A5D6A7)
      ..strokeWidth = 1.5 * scale
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, 10 * scale), Offset(0, 22 * scale), sproutPaint);

    canvas.restore();
  }

  /// Draw an organic pointed leaf with central vein
  void _drawSingleLeaf({
    required Canvas canvas,
    required Offset center,
    required double length,
    required double width,
    required double angle,
    required Color color,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final leafPath = Path();
    final halfLen = length / 2;
    final halfWid = width / 2;

    leafPath.moveTo(0, -halfLen);
    leafPath.cubicTo(halfWid * 1.3, -halfLen * 0.3, halfWid * 1.3, halfLen * 0.4, 0, halfLen);
    leafPath.cubicTo(-halfWid * 1.3, halfLen * 0.4, -halfWid * 1.3, -halfLen * 0.3, 0, -halfLen);
    leafPath.close();

    final a = (color.a * 255.0).round();
    final leafGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withAlpha((a * 1.2).clamp(0, 255).toInt()),
        color.withAlpha((a * 0.6).clamp(0, 255).toInt()),
      ],
    ).createShader(Rect.fromLTWH(-halfWid, -halfLen, width, length));

    final fillPaint = Paint()..shader = leafGradient;
    canvas.drawPath(leafPath, fillPaint);

    // Fine leaf center vein
    final veinPaint = Paint()
      ..color = color.withAlpha((a * 1.4).clamp(0, 255).toInt())
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, -halfLen * 0.85), Offset(0, halfLen * 0.8), veinPaint);

    // Subtle side veins
    canvas.drawLine(Offset(0, -halfLen * 0.2), Offset(halfWid * 0.4, -halfLen * 0.35), veinPaint);
    canvas.drawLine(Offset(0, -halfLen * 0.2), Offset(-halfWid * 0.4, -halfLen * 0.35), veinPaint);
    canvas.drawLine(Offset(0, halfLen * 0.2), Offset(halfWid * 0.4, halfLen * 0.05), veinPaint);
    canvas.drawLine(Offset(0, halfLen * 0.2), Offset(-halfWid * 0.4, halfLen * 0.05), veinPaint);

    canvas.restore();
  }

  /// 3. Paint stylized citrus/fresh fruit cross-section motif
  void _paintCitrusFruitSlice(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.68, size.height * 0.13);
    const radius = 34.0;

    // Ambient citrus halo
    final fruitHalo = Paint()
      ..color = const Color(0x20FFD54F)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawCircle(center, radius + 8, fruitHalo);

    // Outer rind / peel ring
    final peelPaint = Paint()
      ..color = const Color(0x3581C784)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawCircle(center, radius, peelPaint);

    // Inner pith circle
    final pithPaint = Paint()
      ..color = const Color(0x20FFF9C4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius - 3.5, pithPaint);

    // Central hub
    final hubPaint = Paint()..color = const Color(0x35FFF59D);
    canvas.drawCircle(center, 3.5, hubPaint);

    // Radiating citrus segments (6 wedges)
    const segmentCount = 6;
    const segmentAngle = (2 * 3.1415926535) / segmentCount;
    final segPaint = Paint()..color = const Color(0x28FFF59D);

    for (int i = 0; i < segmentCount; i++) {
      final startA = i * segmentAngle + 0.12;
      final sweepA = segmentAngle - 0.24;

      final wedgePath = Path();
      wedgePath.moveTo(center.dx, center.dy);
      wedgePath.arcTo(
        Rect.fromCircle(center: center, radius: radius - 6.0),
        startA,
        sweepA,
        false,
      );
      wedgePath.close();
      canvas.drawPath(wedgePath, segPaint);
    }
  }

  /// 4. Paint crystal hydration dew drops
  void _paintHydrationDrops(Canvas canvas, Size size) {
    _drawHydrationDrop(canvas, Offset(size.width * 0.38, size.height * 0.09), 16.0);
    _drawHydrationDrop(canvas, Offset(size.width * 0.58, size.height * 0.22), 12.0);
    _drawHydrationDrop(canvas, Offset(size.width * 0.08, size.height * 0.20), 10.0);
    _drawHydrationDrop(canvas, Offset(size.width * 0.90, size.height * 0.25), 14.0);
  }

  void _drawHydrationDrop(Canvas canvas, Offset center, double dropHeight) {
    final width = dropHeight * 0.65;
    final top = center.dy - dropHeight / 2;
    final bottom = center.dy + dropHeight / 2;

    final dropPath = Path();
    dropPath.moveTo(center.dx, top);
    dropPath.cubicTo(
      center.dx + width,
      top + dropHeight * 0.6,
      center.dx + width * 0.8,
      bottom,
      center.dx,
      bottom,
    );
    dropPath.cubicTo(
      center.dx - width * 0.8,
      bottom,
      center.dx - width,
      top + dropHeight * 0.6,
      center.dx,
      top,
    );
    dropPath.close();

    final dropGradient = const RadialGradient(
      center: Alignment(-0.3, -0.4),
      radius: 0.8,
      colors: [
        Color(0x5500E5FF), // Crisp bright aqua highlight
        Color(0x3500B0FF), // Natural clear water
        Color(0x1800E676), // Refreshing mineral green rim
      ],
      stops: [0.0, 0.6, 1.0],
    ).createShader(Rect.fromLTWH(center.dx - width, top, width * 2, dropHeight));

    final dropPaint = Paint()..shader = dropGradient;
    canvas.drawPath(dropPath, dropPaint);

    // Glistening highlight spark
    final specPaint = Paint()..color = const Color(0x60FFFFFF);
    canvas.drawCircle(Offset(center.dx - width * 0.22, top + dropHeight * 0.35), dropHeight * 0.09, specPaint);
  }

  /// 5. Paint micro vitality and vitamin energy particles
  void _paintVitalitySparkles(Canvas canvas, Size size) {
    final sparkOffsets = [
      Offset(size.width * 0.26, size.height * 0.06),
      Offset(size.width * 0.48, size.height * 0.07),
      Offset(size.width * 0.76, size.height * 0.05),
      Offset(size.width * 0.32, size.height * 0.18),
      Offset(size.width * 0.64, size.height * 0.28),
      Offset(size.width * 0.85, size.height * 0.18),
      Offset(size.width * 0.14, size.height * 0.16),
      Offset(size.width * 0.42, size.height * 0.26),
    ];

    final sparkRadii = [4.5, 3.0, 5.0, 3.5, 4.0, 5.5, 3.2, 4.2];

    for (int i = 0; i < sparkOffsets.length; i++) {
      _drawVitalitySpark(canvas, sparkOffsets[i], sparkRadii[i % sparkRadii.length]);
    }
  }

  void _drawVitalitySpark(Canvas canvas, Offset center, double radius) {
    // Soft organic glow
    final haloPaint = Paint()
      ..color = const Color(0x2869F0AE)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(center, radius * 1.6, haloPaint);

    // 4-point organic energy spark
    final path = Path();
    final arm = radius;

    path.moveTo(center.dx, center.dy - arm);
    path.quadraticBezierTo(center.dx, center.dy, center.dx + arm, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + arm);
    path.quadraticBezierTo(center.dx, center.dy, center.dx - arm, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - arm);
    path.close();

    final sparkPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFB9F6CA), Color(0xFF69F0AE)],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: arm));

    canvas.drawPath(path, sparkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter that renders golden Islamic lanterns (Fanous),
/// a glowing crescent moon (Hilal), and celestial stars.
class IslamicVisualsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _paintBokehGlows(canvas, size);
    _paintStars(canvas, size);
    _paintCrescentMoon(canvas, size);
    _paintHangingLanterns(canvas, size);
  }

  /// 1. Paint soft bokeh / ambient glowing orbs
  void _paintBokehGlows(Canvas canvas, Size size) {
    final glowPaint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 45);

    // Cyan celestial glow upper-left
    glowPaint.color = const Color(0x1800D2FF);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.12), 90, glowPaint);

    // Warm golden halo around moon area
    glowPaint.color = const Color(0x28FFD166);
    canvas.drawCircle(Offset(size.width * 0.72, size.height * 0.16), 110, glowPaint);

    // Secondary cyan bokeh
    glowPaint.color = const Color(0x1438BDF8);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.28), 70, glowPaint);
  }

  /// 2. Paint twinkling Islamic 4-point & 8-point stars
  void _paintStars(Canvas canvas, Size size) {
    final starOffsets = [
      Offset(size.width * 0.12, size.height * 0.06),
      Offset(size.width * 0.35, size.height * 0.08),
      Offset(size.width * 0.44, size.height * 0.18),
      Offset(size.width * 0.60, size.height * 0.05),
      Offset(size.width * 0.88, size.height * 0.08),
      Offset(size.width * 0.92, size.height * 0.22),
      Offset(size.width * 0.28, size.height * 0.24),
      Offset(size.width * 0.08, size.height * 0.20),
      Offset(size.width * 0.78, size.height * 0.32),
      Offset(size.width * 0.65, size.height * 0.26),
    ];

    final starRadii = [6.0, 4.0, 7.5, 5.0, 7.0, 4.5, 5.5, 3.5, 4.0, 6.0];

    for (int i = 0; i < starOffsets.length; i++) {
      _drawStar(canvas, starOffsets[i], starRadii[i % starRadii.length]);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius) {
    // Soft star halo
    final haloPaint = Paint()
      ..color = const Color(0x40FFE082)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center, radius * 1.5, haloPaint);

    // 4-Point sparkle star path
    final path = Path();
    final arm = radius;

    path.moveTo(center.dx, center.dy - arm);
    path.quadraticBezierTo(center.dx, center.dy, center.dx + arm, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + arm);
    path.quadraticBezierTo(center.dx, center.dy, center.dx - arm, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx - arm, center.dy);
    path.close();

    final starPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFFFD166), Color(0xFFF59E0B)],
        stops: [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: arm));

    canvas.drawPath(path, starPaint);
  }

  /// 3. Paint Luminous Golden Crescent Moon (Hilal)
  void _paintCrescentMoon(Canvas canvas, Size size) {
    final moonCenter = Offset(size.width * 0.73, size.height * 0.16);
    const outerR = 56.0;
    const innerR = 48.0;
    final innerCenter = Offset(moonCenter.dx + 16.0, moonCenter.dy - 12.0);

    // Ambient golden glow behind moon
    final moonHalo = Paint()
      ..color = const Color(0x35FFD166)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawCircle(moonCenter, outerR + 14, moonHalo);

    // Outer & Inner circle paths for subtraction
    final outerPath = Path()..addOval(Rect.fromCircle(center: moonCenter, radius: outerR));
    final innerPath = Path()..addOval(Rect.fromCircle(center: innerCenter, radius: innerR));
    final crescentPath = Path.combine(PathOperation.difference, outerPath, innerPath);

    // Rich metallic golden gradient
    final moonRect = Rect.fromCircle(center: moonCenter, radius: outerR);
    final moonPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFF7C2), // Sparkling highlight
          Color(0xFFFFD166), // Golden body
          Color(0xFFF59E0B), // Warm amber gold
          Color(0xFFD97706), // Deep bronze shading
        ],
        stops: [0.0, 0.35, 0.75, 1.0],
      ).createShader(moonRect);

    canvas.drawPath(crescentPath, moonPaint);

    // Inner rim highlight stroke for crisp 3D golden sheen
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0x00FFD166)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(moonRect);
    canvas.drawPath(crescentPath, rimPaint);
  }

  /// 4. Paint Hanging Golden Lanterns (Fanous)
  void _paintHangingLanterns(Canvas canvas, Size size) {
    // Lantern 1 (Left): Medium height
    _drawLantern(
      canvas: canvas,
      x: size.width * 0.16,
      cordLength: 95.0,
      width: 32.0,
      height: 52.0,
    );

    // Lantern 2 (Center-Right): Prominent, glowing lower lantern
    _drawLantern(
      canvas: canvas,
      x: size.width * 0.48,
      cordLength: 140.0,
      width: 36.0,
      height: 58.0,
      hasExtraGlow: true,
    );

    // Lantern 3 (Far Right): Smaller, higher hanging lantern
    _drawLantern(
      canvas: canvas,
      x: size.width * 0.88,
      cordLength: 75.0,
      width: 26.0,
      height: 42.0,
    );
  }

  void _drawLantern({
    required Canvas canvas,
    required double x,
    required double cordLength,
    required double width,
    required double height,
    bool hasExtraGlow = false,
  }) {
    // 1. Hanging Chain / Cord
    final cordPaint = Paint()
      ..color = const Color(0xCCFFD166)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(x, 0), Offset(x, cordLength), cordPaint);

    // Cord bead accents
    final beadPaint = Paint()..color = const Color(0xFFFFD166);
    canvas.drawCircle(Offset(x, cordLength * 0.35), 1.8, beadPaint);
    canvas.drawCircle(Offset(x, cordLength * 0.70), 2.2, beadPaint);

    final lanternTop = cordLength;
    final bodyCenter = Offset(x, lanternTop + height * 0.55);

    // 2. Ambient Candle Light Radiance
    final candleGlow = Paint()
      ..color = hasExtraGlow ? const Color(0x55FFD166) : const Color(0x35FFD166)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(bodyCenter, width * 1.3, candleGlow);

    // 3. Top Hanging Loop / Ring
    final ringPaint = Paint()
      ..color = const Color(0xFFFFD166)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(Offset(x, lanternTop + 4), 4.5, ringPaint);

    // 4. Lantern Ornate Dome (Top Cap)
    final domePath = Path();
    final domeTop = lanternTop + 7;
    final domeBottom = lanternTop + height * 0.32;
    domePath.moveTo(x, domeTop);
    domePath.quadraticBezierTo(x - width * 0.35, domeTop + 6, x - width * 0.48, domeBottom);
    domePath.lineTo(x + width * 0.48, domeBottom);
    domePath.quadraticBezierTo(x + width * 0.35, domeTop + 6, x, domeTop);
    domePath.close();

    final goldShader = const LinearGradient(
      colors: [Color(0xFFFFF9C4), Color(0xFFFFD166), Color(0xFFF59E0B), Color(0xFFB45309)],
      stops: [0.0, 0.3, 0.7, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Rect.fromLTWH(x - width / 2, lanternTop, width, height));

    final goldPaint = Paint()..shader = goldShader;
    canvas.drawPath(domePath, goldPaint);

    // 5. Glass Chamber with Candle Fire
    final glassRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x - width * 0.42, domeBottom, width * 0.84, height * 0.45),
      const Radius.circular(4),
    );

    // Glass glow gradient (bright candle inside)
    final glassPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0.1),
        radius: 0.85,
        colors: const [
          Color(0xFFFFFFFF), // White flame core
          Color(0xFFFFEA79), // Warm yellow light
          Color(0xFFFFA000), // Amber edge
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(glassRect.outerRect);

    canvas.drawRRect(glassRect, glassPaint);

    // 6. Glass Lattice Struts (Window panes)
    final strutPaint = Paint()
      ..color = const Color(0xFF8D5300)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Vertical grill lines
    canvas.drawLine(
      Offset(x - width * 0.18, domeBottom),
      Offset(x - width * 0.18, domeBottom + height * 0.45),
      strutPaint,
    );
    canvas.drawLine(
      Offset(x + width * 0.18, domeBottom),
      Offset(x + width * 0.18, domeBottom + height * 0.45),
      strutPaint,
    );

    // Arch window ornament
    final archPath = Path();
    archPath.moveTo(x - width * 0.42, domeBottom + height * 0.45);
    archPath.lineTo(x - width * 0.42, domeBottom + height * 0.2);
    archPath.quadraticBezierTo(x, domeBottom - 2, x + width * 0.42, domeBottom + height * 0.2);
    archPath.lineTo(x + width * 0.42, domeBottom + height * 0.45);
    canvas.drawPath(archPath, strutPaint);

    // Outer frame border
    final frameBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = goldShader;
    canvas.drawRRect(glassRect, frameBorderPaint);

    // 7. Base and Bottom Finial
    final baseTop = domeBottom + height * 0.45;
    final basePath = Path();
    basePath.moveTo(x - width * 0.46, baseTop);
    basePath.lineTo(x + width * 0.46, baseTop);
    basePath.lineTo(x + width * 0.32, baseTop + height * 0.18);
    basePath.lineTo(x - width * 0.32, baseTop + height * 0.18);
    basePath.close();
    canvas.drawPath(basePath, goldPaint);

    // Teardrop / Tassel at bottom
    final tasselCenter = Offset(x, baseTop + height * 0.22);
    canvas.drawCircle(tasselCenter, 3.2, Paint()..color = const Color(0xFFFFD166));
    final tipPath = Path();
    tipPath.moveTo(x - 2.5, tasselCenter.dy);
    tipPath.lineTo(x + 2.5, tasselCenter.dy);
    tipPath.lineTo(x, tasselCenter.dy + 8.0);
    tipPath.close();
    canvas.drawPath(tipPath, goldPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
