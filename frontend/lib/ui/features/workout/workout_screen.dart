import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/ramadan_controller.dart';
import '../../../core/workout_service.dart';
import '../../../core/reminder_manager.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => WorkoutScreenState();
}

class WorkoutScreenState extends State<WorkoutScreen> with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _isRegenerating = false;
  WorkoutPlanModel? _workoutPlan;
  int _selectedDayIndex = 0;

  final List<String> _dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  final List<String> _shortDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _setInitialDayToToday();
    loadWorkoutData();
  }

  void _setInitialDayToToday() {
    // DateTime.weekday: Monday=1 ... Sunday=7
    final todayWeekday = DateTime.now().weekday;
    _selectedDayIndex = (todayWeekday - 1).clamp(0, 6);
  }

  Future<void> loadWorkoutData({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final isRamadan = RamadanController.instance.isRamadanMode;
      final plan = await WorkoutService.instance.getWorkoutPlan(
        forceRefresh: forceRefresh,
        isRamadan: isRamadan,
      );

      if (mounted) {
        setState(() {
          _workoutPlan = plan;
          _isLoading = false;
        });

        if (plan != null) {
          // Schedule non-daily notifications in background
          ReminderManager.scheduleWorkoutPlanReminders(plan);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _regeneratePlanWithAI() async {
    setState(() => _isRegenerating = true);
    final isRamadan = RamadanController.instance.isRamadanMode;

    try {
      final plan = await WorkoutService.instance.regeneratePlan(isRamadan: isRamadan);
      if (mounted) {
        setState(() {
          _workoutPlan = plan;
          _isRegenerating = false;
        });

        if (plan != null) {
          ReminderManager.scheduleWorkoutPlanReminders(plan);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✨ AI generated a new tailored workout routine!'),
              backgroundColor: isRamadan ? const Color(0xFF00D2FF) : const Color(0xFF00E676),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRegenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RamadanController.instance,
      builder: (context, _) {
        final isRamadan = RamadanController.instance.isRamadanMode;

        final bgColor = isRamadan ? const Color(0xFF080D1A) : const Color(0xFF0D0F14);
        final primaryColor = isRamadan ? const Color(0xFF00D2FF) : const Color(0xFF00E676);
        final cardBg = isRamadan ? const Color(0xFF0E172A).withAlpha(220) : const Color(0xFF161A22).withAlpha(220);

        return Scaffold(
          backgroundColor: bgColor,
          body: Stack(
            children: [
              // Ambient gradient backgrounds
              Positioned(
                top: -100,
                right: -80,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withAlpha(25),
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(primaryColor, isRamadan),
                    const SizedBox(height: 12),
                    _buildWeeklyDaySelector(primaryColor, isRamadan),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _isLoading
                          ? Center(
                              child: CircularProgressIndicator(
                                color: primaryColor,
                              ),
                            )
                          : _workoutPlan == null
                              ? _buildEmptyState(primaryColor)
                              : _buildWorkoutDayContent(primaryColor, cardBg, isRamadan),
                    ),
                  ],
                ),
              ),

              if (_isRegenerating)
                Positioned.fill(
                  child: Container(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: primaryColor),
                          const SizedBox(height: 16),
                          Text(
                            'AI is crafting your tailored workout plan...',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(Color primaryColor, bool isRamadan) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.fitness_center_rounded, color: primaryColor, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'AI Workout Plan',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _workoutPlan?.planName ?? 'Personalized Clinical Protocol',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF8A94A6),
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: _isRegenerating ? null : _regeneratePlanWithAI,
            icon: Icon(Icons.auto_awesome, color: primaryColor),
            tooltip: 'Regenerate Plan with AI',
            style: IconButton.styleFrom(
              backgroundColor: primaryColor.withAlpha(25),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyDaySelector(Color primaryColor, bool isRamadan) {
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 7,
        itemBuilder: (context, index) {
          final isSelected = _selectedDayIndex == index;
          final isToday = (DateTime.now().weekday - 1) == index;

          WorkoutDayModel? dayData;
          if (_workoutPlan != null && index < _workoutPlan!.weeklySchedule.length) {
            dayData = _workoutPlan!.weeklySchedule[index];
          }

          final isRestDay = dayData?.isRestDay ?? false;

          return GestureDetector(
            onTap: () => setState(() => _selectedDayIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 52,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor.withAlpha(40)
                    : (isRamadan ? const Color(0xFF0E172A).withAlpha(160) : const Color(0xFF161A22).withAlpha(160)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? primaryColor
                      : (isToday ? primaryColor.withAlpha(100) : Colors.white.withAlpha(15)),
                  width: isSelected ? 1.8 : 1.0,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _shortDays[index],
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? primaryColor : const Color(0xFF8A94A6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Icon(
                    isRestDay ? Icons.bedtime_outlined : Icons.local_fire_department_rounded,
                    size: 16,
                    color: isRestDay
                        ? const Color(0xFF94A3B8)
                        : (isSelected ? primaryColor : (isRamadan ? const Color(0xFFFFD166) : const Color(0xFFFF6D00))),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWorkoutDayContent(Color primaryColor, Color cardBg, bool isRamadan) {
    if (_workoutPlan == null || _selectedDayIndex >= _workoutPlan!.weeklySchedule.length) {
      return _buildEmptyState(primaryColor);
    }

    final day = _workoutPlan!.weeklySchedule[_selectedDayIndex];

    if (day.isRestDay) {
      return _buildRestDayView(day, primaryColor, cardBg, isRamadan);
    }

    return RefreshIndicator(
      onRefresh: () => loadWorkoutData(forceRefresh: true),
      color: primaryColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
        children: [
          // Workout Overview Hero Banner
          _buildDayHeroBanner(day, primaryColor, cardBg, isRamadan),
          const SizedBox(height: 14),

          // Medical Condition Advisory
          if (day.clinicalSafetyNotes.isNotEmpty)
            _buildMedicalSafetyBanner(day.clinicalSafetyNotes, isRamadan),

          // Warm-up guidance
          if (day.warmUp.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildWarmUpCard(day.warmUp, primaryColor, cardBg),
          ],

          // Exercises Header
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Exercises (${day.exercises.length})',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Tap to check off',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF8A94A6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Exercise Items List
          ...day.exercises.asMap().entries.map((entry) {
            return _buildExerciseCard(entry.key + 1, entry.value, day.dayName, primaryColor, cardBg);
          }),

          // Cool-down guidance
          if (day.coolDown.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildCoolDownCard(day.coolDown, primaryColor, cardBg),
          ],
        ],
      ),
    );
  }

  Widget _buildDayHeroBanner(WorkoutDayModel day, Color primaryColor, Color cardBg, bool isRamadan) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryColor.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  day.dayName.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: 14, color: const Color(0xFF8A94A6)),
                  const SizedBox(width: 4),
                  Text(
                    '${day.durationMins} mins',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.local_fire_department_rounded, size: 14, color: isRamadan ? const Color(0xFFFFD166) : const Color(0xFFFF6D00)),
                  const SizedBox(width: 4),
                  Text(
                    '~${day.estimatedCaloriesBurned} kcal',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            day.workoutTitle,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Target: ${day.targetFocus}',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalSafetyBanner(String safetyNotes, bool isRamadan) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0284C7).withAlpha(25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38BDF8).withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.health_and_safety_outlined, color: Color(0xFF38BDF8), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              safetyNotes,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFFE0F2FE),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarmUpCard(String warmUp, Color primaryColor, Color cardBg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.directions_run_rounded, color: Color(0xFFFF9800), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dynamic Warm-Up',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  warmUp,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoolDownCard(String coolDown, Color primaryColor, Color cardBg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.self_improvement_rounded, color: Color(0xFF10B981), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cool-Down & Recovery Stretch',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  coolDown,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(int order, ExerciseModel exercise, String dayName, Color primaryColor, Color cardBg) {
    return StatefulBuilder(
      builder: (context, setCardState) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: exercise.isCompleted ? primaryColor.withAlpha(120) : Colors.white.withAlpha(15),
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: GestureDetector(
                onTap: () async {
                  setCardState(() {
                    exercise.isCompleted = !exercise.isCompleted;
                  });
                  await WorkoutService.instance.toggleExerciseCompletion(
                    dayName,
                    exercise.name,
                    exercise.isCompleted,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: exercise.isCompleted ? primaryColor : Colors.transparent,
                    border: Border.all(
                      color: exercise.isCompleted ? primaryColor : const Color(0xFF8A94A6),
                      width: 1.5,
                    ),
                  ),
                  child: exercise.isCompleted
                      ? const Icon(Icons.check, size: 18, color: Colors.black)
                      : Center(
                          child: Text(
                            '$order',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8A94A6), fontWeight: FontWeight.bold),
                          ),
                        ),
                ),
              ),
              title: Text(
                exercise.name,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: exercise.isCompleted ? const Color(0xFF94A3B8) : Colors.white,
                  decoration: exercise.isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: primaryColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${exercise.sets} sets × ${exercise.reps}',
                        style: GoogleFonts.inter(fontSize: 11, color: primaryColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Rest: ${exercise.restSeconds}s',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                      ),
                    ),
                  ],
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(color: Colors.white10),
                      if (exercise.formCues.isNotEmpty) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.tips_and_updates_outlined, color: primaryColor, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Form Cue: ${exercise.formCues}',
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (exercise.precautions.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Precaution: ${exercise.precautions}',
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFFCD34D), height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRestDayView(WorkoutDayModel day, Color primaryColor, Color cardBg, bool isRamadan) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF38BDF8).withAlpha(40)),
          ),
          child: Column(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0284C7).withAlpha(30),
                  border: Border.all(color: const Color(0xFF38BDF8).withAlpha(80)),
                ),
                child: const Icon(Icons.nightlight_round, size: 36, color: Color(0xFF38BDF8)),
              ),
              const SizedBox(height: 16),
              Text(
                'Rest & Active Recovery',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                day.targetFocus,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF94A3B8),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Recovery Pillars
        _buildRecoveryPillarCard(
          icon: Icons.water_drop_outlined,
          iconColor: const Color(0xFF00D2FF),
          title: 'Hydration & Electrolytes',
          description: 'Drink at least 2.5–3L of water today to flush lactic acid and replenish intracellular glycogen.',
          cardBg: cardBg,
        ),
        const SizedBox(height: 10),
        _buildRecoveryPillarCard(
          icon: Icons.self_improvement_outlined,
          iconColor: const Color(0xFF10B981),
          title: 'Light Active Mobility',
          description: 'A 15-minute leisurely walk or gentle foam rolling enhances blood flow without taxing your muscles.',
          cardBg: cardBg,
        ),
        const SizedBox(height: 10),
        _buildRecoveryPillarCard(
          icon: Icons.bed_outlined,
          iconColor: const Color(0xFFA855F7),
          title: 'Deep Sleep & Muscle Synthesis',
          description: 'Aim for 7–8 hours of quality sleep. Muscle protein repair and tissue remodeling occur during deep REM sleep.',
          cardBg: cardBg,
        ),
      ],
    );
  }

  Widget _buildRecoveryPillarCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required Color cardBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center_outlined, size: 64, color: primaryColor.withAlpha(120)),
            const SizedBox(height: 16),
            Text(
              'No Workout Plan Available',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap below to let AI generate your personalized workout schedule based on your health goals.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF8A94A6)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _regeneratePlanWithAI,
              icon: const Icon(Icons.auto_awesome, color: Colors.black),
              label: Text(
                'Generate Workout Plan',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
