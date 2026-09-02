import 'package:flutter/foundation.dart';
import '../../../core/health_service.dart';

/// ViewModel for the Health Sync Dashboard across all devices (Android, iOS, Windows, Web).
class HealthSyncViewModel extends ChangeNotifier {
  ActivityData _todayActivity = ActivityData.empty;
  List<DailyActivity> _weeklyHistory = [];
  bool _isConnected = true;
  bool _isLoading = true;
  int _stepGoal = 10000;

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

  /// Generates a contextual AI health insight based on real user activity.
  String getInsight(String language) {
    // No real data at all — user hasn't synced or logged anything yet
    if (!hasRealActivity) {
      return language == 'ur'
          ? '🔗 اپنے قدموں کی ٹریکنگ شروع کرنے کے لیے ہیلتھ کنیکٹ سنک کریں یا اپنی سرگرمی دستی طور پر درج کریں۔'
          : '🔗 Connect Health Connect or log your activity manually to start tracking your daily steps and get personalized coaching!';
    }

    final todaySteps = _todayActivity.steps;
    final avgSteps = weeklyAverageSteps;
    final pct = _stepGoal > 0 ? ((avgSteps / _stepGoal) * 100).round() : 0;
    final todayPct = _stepGoal > 0 ? ((todaySteps / _stepGoal) * 100).round() : 0;

    // Today's steps are 0 but user has prior history
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

  /// Load all health activity.
  Future<void> loadAll() async {
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

  /// Update today's manual activity stats.
  Future<void> updateTodayActivity({
    int? steps,
    int? activeKcal,
    double? sleepHours,
    int? heartRateBpm,
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
  }

  /// Update daily step goal.
  Future<void> updateStepGoal(int newGoal) async {
    _stepGoal = newGoal;
    await HealthService.instance.setStepGoal(newGoal);
    notifyListeners();
  }
}
