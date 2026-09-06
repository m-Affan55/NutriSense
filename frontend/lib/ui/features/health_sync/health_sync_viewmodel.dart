import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api_client.dart';
import '../../../core/health_service.dart';
import '../family_profiles/family_viewmodel.dart';

/// ViewModel for the Health Sync Dashboard across all devices (Android, iOS, Windows, Web).
class HealthSyncViewModel extends ChangeNotifier {
  ActivityData _todayActivity = ActivityData.empty;
  List<DailyActivity> _weeklyHistory = [];
  bool _isConnected = true;
  bool _isLoading = true;
  int _stepGoal = 10000;

  // AI Metabolic Insights & Clinical Goal Tracking
  String? _aiInsight;
  int? _aiOptimalGoal;
  bool _isGoalAdequate = true;
  String? _goalFeedback;
  String? _conditionDetected;
  bool _isAiLoading = false;
  int _lastAnalyzedSteps = -1;
  DateTime? _lastManualAiCallTime;

  ActivityData get todayActivity => _todayActivity;
  List<DailyActivity> get weeklyHistory {
    if (!hasRealActivity) {
      final now = DateTime.now();
      return List.generate(7, (i) {
        final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i));
        return DailyActivity(
          date: date,
          steps: 0,
          activeKcal: 0,
          sleepHours: 0.0,
          heartRateBpm: 0,
        );
      });
    }
    return _weeklyHistory;
  }

  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;
  int get stepGoal => _stepGoal;
  bool get isNativeHealthSupported => HealthService.instance.isNativeHealthSupported;

  // AI getters
  String? get aiInsight => _aiInsight;
  int? get aiOptimalGoal => _aiOptimalGoal;
  bool get isGoalAdequate => _isGoalAdequate;
  String? get goalFeedback => _goalFeedback;
  String? get conditionDetected => _conditionDetected;
  bool get isAiLoading => _isAiLoading;

  /// Percentage of step goal completed today (0.0 – 1.0+).
  double get stepProgress {
    if (_stepGoal <= 0) return 0.0;
    return _todayActivity.steps / _stepGoal;
  }

  /// Average steps over the weekly history.
  int get weeklyAverageSteps {
    if (!hasRealActivity || _weeklyHistory.isEmpty) return 0;
    final total = _weeklyHistory.fold<int>(0, (sum, d) => sum + d.steps);
    return (total / _weeklyHistory.length).round();
  }

  /// Total calories burned this week.
  int get weeklyTotalBurned {
    if (!hasRealActivity || _weeklyHistory.isEmpty) return 0;
    return _weeklyHistory.fold<int>(0, (sum, d) => sum + d.activeKcal);
  }

  /// Average sleep hours this week.
  double get weeklyAverageSleep {
    if (!hasRealActivity || _weeklyHistory.isEmpty) return 0.0;
    final total = _weeklyHistory.fold<double>(0.0, (sum, d) => sum + d.sleepHours);
    return double.parse((total / _weeklyHistory.length).toStringAsFixed(1));
  }

  /// Whether we have any real recorded activity (not just fallback demo data).
  bool get hasRealActivity {
    // 1. If today has positive steps
    if (_todayActivity.steps > 0) return true;
    // 2. If user manually entered data
    if (_todayActivity.source == 'User Logged') return true;
    // 3. If connected to native health platform and any day has steps
    if ((_todayActivity.source == 'Health Connect' || _todayActivity.source == 'Apple Health') &&
        _weeklyHistory.any((d) => d.steps > 0)) {
      return true;
    }
    // Otherwise in un-synced / flat-zero state
    return false;
  }

  static String _todayDateKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String _cacheKey(String prefix, String userId, [String? familyMemberId]) {
    final memberScope = (familyMemberId != null && familyMemberId.isNotEmpty) ? familyMemberId : 'primary';
    return '${prefix}_${userId}_${memberScope}_${_todayDateKey()}';
  }

  /// Clears locally cached AI insight keys for [userId] (called when medical profile or goals change in Settings).
  static Future<void> clearInsightCache(String userId, [String? familyMemberId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final memberScope = (familyMemberId != null && familyMemberId.isNotEmpty) ? familyMemberId : 'primary';
      final today = _todayDateKey();
      final keys = [
        'health_sync_ai_insight_${userId}_${memberScope}_$today',
        'health_sync_ai_optimal_goal_${userId}_${memberScope}_$today',
        'health_sync_ai_adequate_${userId}_${memberScope}_$today',
        'health_sync_ai_feedback_${userId}_${memberScope}_$today',
        'health_sync_ai_condition_${userId}_${memberScope}_$today',
        'health_sync_last_steps_${userId}_${memberScope}_$today',
        // Also clear unpartitioned legacy keys
        'health_sync_ai_insight_${userId}_$today',
        'health_sync_ai_optimal_goal_${userId}_$today',
        'health_sync_ai_adequate_${userId}_$today',
        'health_sync_ai_feedback_${userId}_$today',
        'health_sync_ai_condition_${userId}_$today',
        'health_sync_last_steps_${userId}_$today',
      ];
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (e) {
      debugPrint('[HealthSyncVM] clearInsightCache error: $e');
    }
  }

  /// Generates or returns the AI health insight based on real activity and profile.
  String getInsight(String language) {
    if (_aiInsight != null && _aiInsight!.trim().isNotEmpty) {
      return _aiInsight!;
    }

    // Fallback deterministic coaching
    if (!hasRealActivity) {
      return language == 'ur'
          ? '🔗 اپنے قدموں کی ٹریکنگ شروع کرنے کے لیے ہیلتھ کنیکٹ سنک کریں یا اپنی سرگرمی دستی طور پر درج کریں۔'
          : '🔗 Connect Health Connect or log your activity manually to start tracking your daily steps and get personalized coaching!';
    }

    final todaySteps = _todayActivity.steps;
    final avgSteps = weeklyAverageSteps;
    final pct = _stepGoal > 0 ? ((avgSteps / _stepGoal) * 100).round() : 0;
    final todayPct = _stepGoal > 0 ? ((todaySteps / _stepGoal) * 100).round() : 0;

    if (todaySteps == 0) {
      return language == 'ur'
          ? '🌅 آج ابھی تک کوئی قدم ریکارڈ نہیں ہوا۔ صبح کی مختصر سیر آپ کی توانائی بڑھا سکتی ہے!'
          : '🌅 No steps recorded yet today. A short morning walk can boost your energy and metabolism for the day!';
    }

    if (pct >= 100) {
      return language == 'ur'
          ? '🎉 زبردست کارکردگی! آپ نے اس ہفتے روزانہ اوسطاً $avgSteps قدم مکمل کیے ہیں جو آپ کے ہدف سے زیادہ ہے!'
          : '🎉 Outstanding performance! You exceeded your daily goal with an average of $avgSteps steps/day this week!';
    } else if (todayPct >= 75) {
      return language == 'ur'
          ? '💪 بہت عمدہ! آج آپ $todaySteps قدم ($todayPct% ہدف) مکمل کر چکے ہیں۔ ہدف کے قریب پہنچ رہے ہیں!'
          : '💪 Great effort! You have hit $todaySteps steps today ($todayPct% of your goal). You are close — finish strong!';
    } else if (pct >= 50) {
      return language == 'ur'
          ? '🚶 اچھی پیشرفت — روزانہ اوسطاً $avgSteps قدم۔ ہدف حاصل کرنے کے لیے شام کی مختصر چہل قدمی شامل کریں۔'
          : '🚶 Steady progress — averaging $avgSteps steps/day. Add a 15-min evening stroll to reach your daily target.';
    } else {
      return language == 'ur'
          ? '⚡ آج $todaySteps قدم مکمل ہوئے۔ روزانہ کی سرگرمی میں اضافہ میٹابولزم کو تیز کرنے میں مدد دے گا۔'
          : '⚡ You have taken $todaySteps steps today. Boosting daily activity will elevate your metabolism and speed up calorie burn.';
    }
  }

  /// Load all health activity and fetch or load cached AI insights.
  Future<void> loadAll({bool forceAi = false, String language = 'en'}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _stepGoal = await HealthService.instance.getStepGoal();
      _isConnected = await HealthService.instance.isAvailable;
      _todayActivity = await HealthService.instance.getTodayActivity();
      _weeklyHistory = await HealthService.instance.getWeeklyActivity();
    } catch (e) {
      debugPrint('[HealthSyncVM] loadAll error: $e');
    }

    _isLoading = false;
    notifyListeners();

    // Fetch or warm up AI insights in background (0ms UI blocking)
    await fetchOrLoadAiInsight(force: forceAi, language: language);
  }

  /// Fetches AI metabolic insight and optimal goal recommendations with local daily caching.
  Future<void> fetchOrLoadAiInsight({bool force = false, String language = 'en'}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final userId = user.id;

    final activeMember = FamilyViewModel.instance.activeMember;
    final familyMemberId = activeMember?.id;

    try {
      final prefs = await SharedPreferences.getInstance();
      final insightKey = _cacheKey('health_sync_ai_insight', userId, familyMemberId);
      final optimalGoalKey = _cacheKey('health_sync_ai_optimal_goal', userId, familyMemberId);
      final adequateKey = _cacheKey('health_sync_ai_adequate', userId, familyMemberId);
      final feedbackKey = _cacheKey('health_sync_ai_feedback', userId, familyMemberId);
      final conditionKey = _cacheKey('health_sync_ai_condition', userId, familyMemberId);
      final stepsKey = _cacheKey('health_sync_last_steps', userId, familyMemberId);

      // Verify cached condition against current profile in Supabase to guarantee reactivity
      if (!force && prefs.containsKey(conditionKey)) {
        try {
          List<String> currentConditions = [];
          if (familyMemberId != null && familyMemberId.isNotEmpty) {
            final famRes = await Supabase.instance.client
                .from('family_members')
                .select('medical_conditions')
                .eq('id', familyMemberId)
                .maybeSingle();
            currentConditions = (famRes?['medical_conditions'] as List?)
                    ?.map((e) => e.toString().toLowerCase())
                    .toList() ??
                [];
          } else {
            final profileRes = await Supabase.instance.client
                .from('health_profiles')
                .select('medical_conditions')
                .eq('user_id', userId)
                .maybeSingle();
            currentConditions = (profileRes?['medical_conditions'] as List?)
                    ?.map((e) => e.toString().toLowerCase())
                    .toList() ??
                [];
          }

          final cachedCondition = prefs.getString(conditionKey)?.toLowerCase() ?? '';
          if (currentConditions.isNotEmpty) {
            final hasMatch = currentConditions.any((c) => c.contains(cachedCondition) || cachedCondition.contains(c));
            if (!hasMatch) {
              debugPrint('[HealthSyncVM] Medical condition changed (cached: $cachedCondition, db: $currentConditions). Invalidating stale AI insight.');
              force = true;
            }
          } else if (cachedCondition.isNotEmpty && cachedCondition != 'general health') {
            debugPrint('[HealthSyncVM] Medical condition cleared. Invalidating stale AI insight.');
            force = true;
          }
        } catch (dbErr) {
          debugPrint('[HealthSyncVM] Condition check error: $dbErr');
        }
      }

      // 1. Read from local cache if valid and not forced
      if (!force && prefs.containsKey(insightKey)) {
        _aiInsight = prefs.getString(insightKey);
        _aiOptimalGoal = prefs.getInt(optimalGoalKey);
        _isGoalAdequate = prefs.getBool(adequateKey) ?? true;
        _goalFeedback = prefs.getString(feedbackKey);
        _conditionDetected = prefs.getString(conditionKey);
        _lastAnalyzedSteps = prefs.getInt(stepsKey) ?? _todayActivity.steps;

        // Dynamically re-evaluate adequacy against active stepGoal
        if (_aiOptimalGoal != null && _stepGoal < _aiOptimalGoal!) {
          _isGoalAdequate = false;
        } else if (_aiOptimalGoal != null && _stepGoal >= _aiOptimalGoal!) {
          _isGoalAdequate = true;
        }

        notifyListeners();

        // If step change since last analysis is less than 2,500, reuse cache
        if ((_todayActivity.steps - _lastAnalyzedSteps).abs() < 2500) {
          return;
        }
      }

      // 2. Call backend for fresh AI evaluation
      _isAiLoading = true;
      notifyListeners();

      final uri = Uri.parse('${ApiClient.getBaseUrl()}/health-sync/ai-insight');
      final body = jsonEncode({
        'user_id': userId,
        'steps': _todayActivity.steps,
        'step_goal': _stepGoal,
        'active_kcal': _todayActivity.activeKcal,
        'sleep_hours': _todayActivity.sleepHours,
        'heart_rate': _todayActivity.heartRateBpm,
        'source': _todayActivity.source,
        'language': language,
        if (familyMemberId != null && familyMemberId.isNotEmpty)
          'family_member_id': familyMemberId,
      });

      final res = await http
          .post(uri, headers: ApiClient.getHeaders(), body: body)
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _aiOptimalGoal = (data['optimal_step_goal'] as num?)?.toInt();
        _isGoalAdequate = data['is_goal_adequate'] == true;
        _goalFeedback = data['goal_feedback'] as String?;
        _aiInsight = data['insight'] as String?;
        _conditionDetected = data['condition_detected'] as String?;
        _lastAnalyzedSteps = _todayActivity.steps;

        // If user's current goal is below optimal goal, ensure inadequate flag is set
        if (_aiOptimalGoal != null && _stepGoal < _aiOptimalGoal!) {
          _isGoalAdequate = false;
        }

        // Cache results locally for instant startup launch
        if (_aiInsight != null) await prefs.setString(insightKey, _aiInsight!);
        if (_aiOptimalGoal != null) await prefs.setInt(optimalGoalKey, _aiOptimalGoal!);
        await prefs.setBool(adequateKey, _isGoalAdequate);
        if (_goalFeedback != null) await prefs.setString(feedbackKey, _goalFeedback!);
        if (_conditionDetected != null) await prefs.setString(conditionKey, _conditionDetected!);
        await prefs.setInt(stepsKey, _lastAnalyzedSteps);
      }
    } catch (e) {
      debugPrint('[HealthSyncVM] fetchOrLoadAiInsight error: $e');
    } finally {
      _isAiLoading = false;
      notifyListeners();
    }
  }

  /// Silent background prefetch invoked on app startup to guarantee 0ms latency when opening Health Sync.
  static Future<void> prefetchDailyInsight(String userId, {String language = 'en'}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeMember = FamilyViewModel.instance.activeMember;
      final familyMemberId = activeMember?.id;
      final insightKey = _cacheKey('health_sync_ai_insight', userId, familyMemberId);
      if (prefs.containsKey(insightKey)) return; // Already cached for today!

      final activity = await HealthService.instance.getTodayActivity();
      final stepGoal = await HealthService.instance.getStepGoal();

      final uri = Uri.parse('${ApiClient.getBaseUrl()}/health-sync/ai-insight');
      final body = jsonEncode({
        'user_id': userId,
        'steps': activity.steps,
        'step_goal': stepGoal,
        'active_kcal': activity.activeKcal,
        'sleep_hours': activity.sleepHours,
        'heart_rate': activity.heartRateBpm,
        'source': activity.source,
        'language': language,
        if (familyMemberId != null && familyMemberId.isNotEmpty)
          'family_member_id': familyMemberId,
      });

      final res = await http
          .post(uri, headers: ApiClient.getHeaders(), body: body)
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final insight = data['insight'] as String?;
        final optimalGoal = (data['optimal_step_goal'] as num?)?.toInt();
        final adequate = data['is_goal_adequate'] == true;
        final feedback = data['goal_feedback'] as String?;
        final condition = data['condition_detected'] as String?;

        if (insight != null) await prefs.setString(insightKey, insight);
        if (optimalGoal != null) await prefs.setInt(_cacheKey('health_sync_ai_optimal_goal', userId, familyMemberId), optimalGoal);
        await prefs.setBool(_cacheKey('health_sync_ai_adequate', userId, familyMemberId), adequate);
        if (feedback != null) await prefs.setString(_cacheKey('health_sync_ai_feedback', userId, familyMemberId), feedback);
        if (condition != null) await prefs.setString(_cacheKey('health_sync_ai_condition', userId, familyMemberId), condition);
        await prefs.setInt(_cacheKey('health_sync_last_steps', userId, familyMemberId), activity.steps);
      }
    } catch (e) {
      debugPrint('[HealthSyncVM] prefetchDailyInsight error: $e');
    }
  }

  /// Request connection to native or universal health service.
  Future<bool> requestConnection() async {
    final granted = await HealthService.instance.requestPermissions();
    _isConnected = granted;
    await HealthService.instance.setSyncEnabled(granted);
    await loadAll();
    return granted;
  }

  /// Toggle or disconnect sync.
  Future<void> toggleConnection(bool enabled) async {
    _isConnected = enabled;
    await HealthService.instance.setSyncEnabled(enabled);
    if (enabled) {
      await loadAll();
    } else {
      notifyListeners();
    }
  }

  /// Update today's manual activity stats and automatically refresh AI coaching.
  Future<void> updateTodayActivity({
    int? steps,
    int? activeKcal,
    double? sleepHours,
    int? heartRateBpm,
    String language = 'en',
  }) async {
    final updated = ActivityData(
      steps: steps ?? _todayActivity.steps,
      activeKcal: activeKcal ?? _todayActivity.activeKcal,
      sleepHours: sleepHours ?? _todayActivity.sleepHours,
      heartRateBpm: heartRateBpm ?? _todayActivity.heartRateBpm,
      source: 'User Logged',
    );

    _todayActivity = updated;
    await HealthService.instance.saveTodayActivity(updated);
    _weeklyHistory = await HealthService.instance.getWeeklyActivity();
    notifyListeners();

    // User intentionally logged activity -> automatically refresh AI coaching!
    // Protected by a 90-second cooldown so rapid double-saves don't spam the API
    final now = DateTime.now();
    if (_lastManualAiCallTime == null || now.difference(_lastManualAiCallTime!).inSeconds >= 90) {
      _lastManualAiCallTime = now;
      fetchOrLoadAiInsight(force: true, language: language);
    }
  }

  /// Update daily step goal and validate against AI optimal goal.
  Future<void> updateStepGoal(int newGoal) async {
    _stepGoal = newGoal;
    await HealthService.instance.setStepGoal(newGoal);

    if (_aiOptimalGoal != null) {
      _isGoalAdequate = newGoal >= _aiOptimalGoal!;
    } else {
      _isGoalAdequate = newGoal >= 5000;
    }
    notifyListeners();
  }
}
