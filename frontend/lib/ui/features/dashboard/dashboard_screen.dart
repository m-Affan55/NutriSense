import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../main.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  late AnimationController _ringController;
  late Animation<double> _ringAnimation;
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _ringAnimation = CurvedAnimation(parent: _ringController, curve: Curves.easeOutCubic);
    
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fabAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.elasticOut),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _ringController.forward();
        _fabController.forward();
      }
    });
  }

  @override
  void dispose() {
    _ringController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section A: Personalized Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Good Morning, Ahmed 👋', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface)),
                      const SizedBox(height: 4),
                      Text('Tuesday, 19 August 2026', style: theme.textTheme.bodySmall),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colorScheme.primary, width: 2),
                    ),
                    child: const CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Section B: Animated Calorie Ring (Hero)
              Center(
                child: SizedBox(
                  height: 220,
                  width: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _ringAnimation,
                        builder: (context, child) {
                          return CustomPaint(
                            size: const Size(220, 220),
                            painter: CalorieRingPainter(
                              progress: 1450 / 1800 * _ringAnimation.value,
                              backgroundColor: const Color(0xFF262626),
                              gradientStart: theme.colorScheme.primary,
                              gradientEnd: const Color(0xFF00BCD4),
                            ),
                          );
                        },
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('1,450', style: theme.textTheme.headlineLarge),
                          Text('of 1,800 kcal', style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMacroPill(context, 'Protein', '32g / 130g', Colors.redAccent),
                  _buildMacroPill(context, 'Carbs', '140g / 220g', Colors.blueAccent),
                  _buildMacroPill(context, 'Fat', '45g / 65g', Colors.amber),
                ],
              ),
              const SizedBox(height: 32),

              // Section C: Today's Log
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Today's Meals", style: theme.textTheme.titleLarge),
                  TextButton.icon(
                    onPressed: () {},
                    icon: Icon(Icons.add, size: 16, color: theme.colorScheme.primary),
                    label: Text('Add Meal', style: TextStyle(color: theme.colorScheme.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildMealCard(context, 'Breakfast', 'Scrambled Eggs + Roti', '380 kcal', Icons.wb_twilight),
              const SizedBox(height: 12),
              _buildMealCard(context, 'Lunch', 'Chicken Karahi', '520 kcal', Icons.wb_sunny),
              const SizedBox(height: 32),

              // Section D: Hydration Strip
              Text("Hydration", style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              Container(
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF161A22),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Stack(
                  children: [
                    FractionallySizedBox(
                      widthFactor: 750 / 2500,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0288D1), Color(0xFF26C6DA)],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Icon(Icons.water_drop, color: Colors.white),
                          const SizedBox(width: 12),
                          Text('750 ml · 2,500 ml goal', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80), // Space for FAB
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 92.0),
        child: ScaleTransition(
          scale: _fabAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00E676), Color(0xFF00BCD4)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E676).withAlpha(50),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () {},
            backgroundColor: Colors.transparent,
            elevation: 0,
            icon: const Icon(Icons.camera_alt, color: Colors.white),
            label: const Text('Scan Meal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
      ),
    );
  }

  Widget _buildMacroPill(BuildContext context, String label, String value, Color dotColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22).withAlpha(200),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor)),
              const SizedBox(width: 6),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildMealCard(BuildContext context, String type, String desc, String kcal, IconData icon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(25), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withAlpha(30), shape: BoxShape.circle),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 2),
                    Text(desc, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                  ],
                ),
              ),
              Text(kcal, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            ],
          ),
        ),
      ),
    );
  }
}

class CalorieRingPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color gradientStart;
  final Color gradientEnd;

  CalorieRingPainter({
    required this.progress,
    required this.backgroundColor,
    required this.gradientStart,
    required this.gradientEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 16.0;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      2 * 3.14159,
      false,
      bgPaint,
    );

    final gradient = SweepGradient(
      startAngle: -3.14159 / 2,
      endAngle: 3 * 3.14159 / 2,
      colors: [gradientStart, gradientEnd],
    );

    final fgPaint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      2 * 3.14159 * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CalorieRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
