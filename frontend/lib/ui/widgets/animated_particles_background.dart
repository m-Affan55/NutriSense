import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class Particle {
  double x;
  double y;
  double radius;
  double speed;
  double opacity;

  Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.opacity,
  });
}

class AnimatedParticlesBackground extends StatefulWidget {
  final Widget child;
  const AnimatedParticlesBackground({super.key, required this.child});

  @override
  State<AnimatedParticlesBackground> createState() => _AnimatedParticlesBackgroundState();
}

class _AnimatedParticlesBackgroundState extends State<AnimatedParticlesBackground> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final List<Particle> _particles = [];
  final Random _random = Random();
  Size _size = Size.zero;
  final ValueNotifier<int> _tickNotifier = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (_size == Size.zero) return;
      for (var p in _particles) {
        p.y -= p.speed;
        if (p.y < -p.radius * 2) {
          p.y = _size.height + p.radius * 2;
          p.x = _random.nextDouble() * _size.width;
        }
      }
      _tickNotifier.value++;
    });
    _ticker.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newSize = MediaQuery.of(context).size;
    if (_size == Size.zero && newSize != Size.zero) {
      _size = newSize;
      _initParticles(_size);
    } else {
      _size = newSize;
    }
  }

  void _initParticles(Size size) {
    _particles.clear();
    for (int i = 0; i < 20; i++) {
      _particles.add(Particle(
        x: _random.nextDouble() * size.width,
        y: _random.nextDouble() * size.height,
        radius: _random.nextDouble() * 30 + 15, // between 15 and 45
        speed: _random.nextDouble() * 1.0 + 0.3, // slow floating
        opacity: _random.nextDouble() * 0.15 + 0.05, // subtle transparency
      ));
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _tickNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ValueListenableBuilder<int>(
          valueListenable: _tickNotifier,
          builder: (context, _, __) {
            return CustomPaint(
              size: Size.infinite,
              painter: ParticlePainter(particles: _particles),
            );
          },
        ),
        widget.child,
      ],
    );
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  ParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final paint = Paint()
        ..color = const Color(0xFF00E676).withOpacity(particle.opacity) // primary green
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20); // softly glowing bokeh effect

      canvas.drawCircle(Offset(particle.x, particle.y), particle.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) => true;
}
