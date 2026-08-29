import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_client.dart';

class ExerciseModel {
  final String name;
  final String targetMuscle;
  final int sets;
  final String reps;
  final int restSeconds;
  final String formCues;
  final String precautions;
  bool isCompleted;

  ExerciseModel({
    required this.name,
    required this.targetMuscle,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    required this.formCues,
    required this.precautions,
    this.isCompleted = false,
  });

  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    return ExerciseModel(
      name: json['name'] ?? 'Exercise',
      targetMuscle: json['target_muscle'] ?? 'Full Body',
      sets: json['sets'] ?? 3,
      reps: json['reps']?.toString() ?? '10-12',
      restSeconds: json['rest_seconds'] ?? 60,
      formCues: json['form_cues'] ?? '',
      precautions: json['precautions'] ?? '',
      isCompleted: json['is_completed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'target_muscle': targetMuscle,
    'sets': sets,
    'reps': reps,
    'rest_seconds': restSeconds,
    'form_cues': formCues,
    'precautions': precautions,
    'is_completed': isCompleted,
  };
}

class WorkoutDayModel {
  final String dayName;
  final bool isRestDay;
  final String workoutTitle;
  final String targetFocus;
  final int durationMins;
  final int estimatedCaloriesBurned;
  final String warmUp;
  final List<ExerciseModel> exercises;
  final String coolDown;
  final String clinicalSafetyNotes;

  WorkoutDayModel({
    required this.dayName,
    required this.isRestDay,
    required this.workoutTitle,
    required this.targetFocus,
    required this.durationMins,
    required this.estimatedCaloriesBurned,
    required this.warmUp,
    required this.exercises,
    required this.coolDown,
    required this.clinicalSafetyNotes,
  });

  factory WorkoutDayModel.fromJson(Map<String, dynamic> json) {
    var rawExercises = json['exercises'] as List<dynamic>? ?? [];
    List<ExerciseModel> exercisesList = rawExercises
        .map((e) => ExerciseModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return WorkoutDayModel(
      dayName: json['day_name'] ?? 'Monday',
      isRestDay: json['is_rest_day'] ?? false,
      workoutTitle: json['workout_title'] ?? 'Daily Workout',
      targetFocus: json['target_focus'] ?? 'General Fitness',
      durationMins: json['duration_mins'] ?? 30,
      estimatedCaloriesBurned: json['estimated_calories_burned'] ?? 150,
      warmUp: json['warm_up'] ?? '',
      exercises: exercisesList,
      coolDown: json['cool_down'] ?? '',
      clinicalSafetyNotes: json['clinical_safety_notes'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'day_name': dayName,
    'is_rest_day': isRestDay,
    'workout_title': workoutTitle,
    'target_focus': targetFocus,
    'duration_mins': durationMins,
    'estimated_calories_burned': estimatedCaloriesBurned,
    'warm_up': warmUp,
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'cool_down': coolDown,
    'clinical_safety_notes': clinicalSafetyNotes,
  };
}

class WorkoutPlanModel {
  final String planName;
  final String goalSummary;
  final String weeklyFrequency;
  final List<String> medicalConsiderations;
  final List<WorkoutDayModel> weeklySchedule;

  WorkoutPlanModel({
    required this.planName,
    required this.goalSummary,
    required this.weeklyFrequency,
    required this.medicalConsiderations,
    required this.weeklySchedule,
  });

  factory WorkoutPlanModel.fromJson(Map<String, dynamic> json) {
    var rawSchedule = json['weekly_schedule'] as List<dynamic>? ?? [];
    List<WorkoutDayModel> scheduleList = rawSchedule
        .map((d) => WorkoutDayModel.fromJson(d as Map<String, dynamic>))
        .toList();

    var rawMed = json['medical_considerations'] as List<dynamic>? ?? [];
    List<String> medList = rawMed.map((m) => m.toString()).toList();

    return WorkoutPlanModel(
      planName: json['plan_name'] ?? 'Personalized Workout Plan',
      goalSummary: json['goal_summary'] ?? 'Customized fitness routine tailored to your health profile.',
      weeklyFrequency: json['weekly_frequency'] ?? '4 Days Active, 3 Days Rest',
      medicalConsiderations: medList,
      weeklySchedule: scheduleList,
    );
  }

  Map<String, dynamic> toJson() => {
    'plan_name': planName,
    'goal_summary': goalSummary,
    'weekly_frequency': weeklyFrequency,
    'medical_considerations': medicalConsiderations,
    'weekly_schedule': weeklySchedule.map((d) => d.toJson()).toList(),
  };
}

class WorkoutService {
  WorkoutService._();
  static final WorkoutService instance = WorkoutService._();

  static const String _cacheKeyPrefix = 'cached_workout_plan_';
  static const String _completedKeyPrefix = 'workout_completed_exercises_';

  /// Fetches the user's active workout plan.
  /// Offline-First: Checks local cache first, then syncs with API if online.
  Future<WorkoutPlanModel?> getWorkoutPlan({bool forceRefresh = false, bool isRamadan = false}) async {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id ?? 'guest_user';

    final prefs = await SharedPreferences.getInstance();
    final language = prefs.getString('language') ?? prefs.getString('app_language') ?? 'en';
    final cacheKey = '$_cacheKeyPrefix${userId}_$language';

    // 1. Return cached plan if not forced to refresh
    if (!forceRefresh && prefs.containsKey(cacheKey)) {
      try {
        final cachedJson = prefs.getString(cacheKey);
        if (cachedJson != null) {
          final data = json.decode(cachedJson);
          return WorkoutPlanModel.fromJson(data);
        }
      } catch (e) {
        debugPrint('[WorkoutService] Error decoding cached plan: $e');
      }
    }

    // 2. Fetch from backend API
    try {
      final url = Uri.parse('${ApiClient.getBaseUrl()}/workout/plan/$userId?is_ramadan=$isRamadan&language=$language');
      final response = await http.get(url, headers: ApiClient.getHeaders()).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final plan = WorkoutPlanModel.fromJson(data);

        // Save to language-specific cache
        await prefs.setString(cacheKey, json.encode(plan.toJson()));
        return plan;
      }
    } catch (e) {
      debugPrint('[WorkoutService] API fetch failed: $e');
    }

    // 3. Fallback: Return cached or default if available
    if (prefs.containsKey(cacheKey)) {
      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson != null) {
        return WorkoutPlanModel.fromJson(json.decode(cachedJson));
      }
    }

    return null;
  }

  /// Regenerates a fresh workout plan via AI
  Future<WorkoutPlanModel?> regeneratePlan({Map<String, dynamic>? profile, bool isRamadan = false}) async {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id ?? 'guest_user';

    final prefs = await SharedPreferences.getInstance();
    final language = prefs.getString('language') ?? prefs.getString('app_language') ?? 'en';
    final cacheKey = '$_cacheKeyPrefix${userId}_$language';

    try {
      final url = Uri.parse('${ApiClient.getBaseUrl()}/workout/generate');
      final response = await http.post(
        url,
        headers: ApiClient.getHeaders(),
        body: json.encode({
          'user_id': userId,
          'client_profile': profile,
          'is_ramadan': isRamadan,
          'language': language,
        }),
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final plan = WorkoutPlanModel.fromJson(data);

        await prefs.setString(cacheKey, json.encode(plan.toJson()));
        return plan;
      }
    } catch (e) {
      debugPrint('[WorkoutService] Regenerate plan failed: $e');
    }
    return null;
  }

  /// Saves the completion state of an exercise for a specific day
  Future<void> toggleExerciseCompletion(String dayName, String exerciseName, bool isCompleted) async {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id ?? 'guest_user';

    final prefs = await SharedPreferences.getInstance();
    final key = '$_completedKeyPrefix${userId}_${dayName}_$exerciseName';
    await prefs.setBool(key, isCompleted);
  }

  /// Loads completion state for an exercise
  Future<bool> isExerciseCompleted(String dayName, String exerciseName) async {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id ?? 'guest_user';

    final prefs = await SharedPreferences.getInstance();
    final key = '$_completedKeyPrefix${userId}_${dayName}_$exerciseName';
    return prefs.getBool(key) ?? false;
  }
}
