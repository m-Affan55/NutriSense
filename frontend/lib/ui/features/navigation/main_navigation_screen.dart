import 'dart:ui';
import 'package:flutter/material.dart';
import '../dashboard/dashboard_screen.dart';
import '../meal_scan/manual_log_screen.dart';
import '../chat/ai_coach_screen.dart';
import '../predictive_coaching/coaching_screen.dart';
import '../workout/workout_screen.dart';
import '../../../core/ramadan_controller.dart';
import '../../../core/meal_sync_notifier.dart';
import '../../../core/language_controller.dart';

final GlobalKey<CoachingScreenState> coachingKey = GlobalKey<CoachingScreenState>();
final GlobalKey<WorkoutScreenState> workoutKey = GlobalKey<WorkoutScreenState>();

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  static MainNavigationScreenState of(BuildContext context) =>
      context.findAncestorStateOfType<MainNavigationScreenState>()!;

  @override
  State<MainNavigationScreen> createState() => MainNavigationScreenState();
}

class MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    LanguageController.instance.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    LanguageController.instance.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {});
      coachingKey.currentState?.loadCoachingData();
      workoutKey.currentState?.loadWorkoutData(forceRefresh: true);
      MealSyncNotifier.instance.notifyMealChanged();
    }
  }

  set currentIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
    if (index == 0) {
      MealSyncNotifier.instance.notifyMealChanged();
    } else if (index == 3) {
      coachingKey.currentState?.loadCoachingData();
    } else if (index == 4) {
      workoutKey.currentState?.loadWorkoutData();
    }
  }

  final List<Widget> _screens = [
    const DashboardScreen(),
    const ManualLogScreen(),
    const AiCoachScreen(),
    CoachingScreen(key: coachingKey),
    WorkoutScreen(key: workoutKey),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([RamadanController.instance, LanguageController.instance]),
      builder: (context, _) {
        final isRamadan = RamadanController.instance.isRamadanMode;
        final isUrdu = LanguageController.instance.isUrdu;

        return Scaffold(
          extendBody: true, // Allows body to go behind the transparent nav bar
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 10),
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
                        _buildNavItem(0, Icons.home_filled, Icons.home_outlined, isUrdu ? 'ہوم' : 'Home', isRamadan),
                        _buildNavItem(1, Icons.restaurant, Icons.restaurant_outlined, isUrdu ? 'کھانے' : 'Meals', isRamadan),
                        _buildNavItem(2, Icons.chat_bubble, Icons.chat_bubble_outline, isUrdu ? 'کوچ' : 'Coach', isRamadan),
                        _buildNavItem(3, Icons.bar_chart, Icons.bar_chart_outlined, isUrdu ? 'اعداد و شمار' : 'Stats', isRamadan),
                        _buildNavItem(4, Icons.fitness_center, Icons.fitness_center_outlined, isUrdu ? 'ورزش' : 'Workout', isRamadan),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
        if (index == 0) {
          MealSyncNotifier.instance.notifyMealChanged();
        } else if (index == 3) {
          coachingKey.currentState?.loadCoachingData();
        } else if (index == 4) {
          workoutKey.currentState?.loadWorkoutData();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
              size: isSelected ? 22 : 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : const Color(0xFF8A94A6),
                fontSize: 9.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

