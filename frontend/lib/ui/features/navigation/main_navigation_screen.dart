import 'dart:ui';
import 'package:flutter/material.dart';
import '../dashboard/dashboard_screen.dart';
import '../meal_scan/scan_meal_screen.dart';
import '../chat/ai_coach_screen.dart';
import '../predictive_coaching/coaching_screen.dart';
import '../../../core/ramadan_controller.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  static MainNavigationScreenState of(BuildContext context) =>
      context.findAncestorStateOfType<MainNavigationScreenState>()!;

  @override
  State<MainNavigationScreen> createState() => MainNavigationScreenState();
}

class MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  set currentIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  final List<Widget> _screens = [
    const DashboardScreen(),
    const ScanMealScreen(),
    const AiCoachScreen(),
    const CoachingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isRamadan = RamadanController.instance.isRamadanMode;

    return Scaffold(
      extendBody: true, // Allows body to go behind the transparent nav bar
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: isRamadan
                    ? const Color(0xFF0E172A).withAlpha(220)
                    : const Color(0xFF161A22).withAlpha(180),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: isRamadan
                      ? const Color(0xFF00D2FF).withAlpha(50)
                      : Colors.white.withAlpha(20),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(0, Icons.home_filled, Icons.home_outlined, 'Home', isRamadan),
                  _buildScanTab(isRamadan), // Central elevated button
                  _buildNavItem(2, Icons.chat_bubble, Icons.chat_bubble_outline, 'Coach', isRamadan),
                  _buildNavItem(3, Icons.bar_chart, Icons.bar_chart_outlined, 'Stats', isRamadan),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label, bool isRamadan) {
    final isSelected = _currentIndex == index;
    final activeColor = isRamadan ? const Color(0xFF00D2FF) : const Color(0xFF00E676);

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? activeColor : const Color(0xFF8A94A6),
              size: isSelected ? 24 : 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : const Color(0xFF8A94A6),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanTab(bool isRamadan) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = 1;
        });
      },
      child: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: isRamadan
                ? [const Color(0xFF00D2FF), const Color(0xFFFFD166)]
                : [const Color(0xFF00E676), const Color(0xFF00BCD4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: (isRamadan ? const Color(0xFF00D2FF) : const Color(0xFF00E676)).withAlpha(80),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
      ),
    );
  }
}
