import 'package:flutter/material.dart';
import '../../core/ramadan_controller.dart';
import '../../ui/core/theme.dart';

/// Full-screen or Container background wrapper that paints golden lanterns,
/// glowing crescent moon, and twinkling stars when Ramadan mode is active.
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
    final active = isRamadan ?? RamadanController.instance.isRamadanMode;

    if (!active) {
      return Container(
        decoration: getAppBackgroundDecoration(false),
        child: child,
      );
    }

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
  }
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
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - arm);
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
