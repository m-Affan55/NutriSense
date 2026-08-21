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
  List<DailyActivity> get weeklyHistory => _weeklyHistory;
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
    if (_weeklyHistory.isEmpty) return 0;
    final total = _weeklyHistory.fold<int>(0, (sum, d) => sum + d.steps);
    return (total / _weeklyHistory.length).round();
  }

  /// Total calories burned this week.
  int get weeklyTotalBurned {
    if (_weeklyHistory.isEmpty) return 0;
    return _weeklyHistory.fold<int>(0, (sum, d) => sum + d.activeKcal);
  }

  /// Average sleep hours this week.
  double get weeklyAverageSleep {
    if (_weeklyHistory.isEmpty) return 0.0;
    final total = _weeklyHistory.fold<double>(0.0, (sum, d) => sum + d.sleepHours);
    return double.parse((total / _weeklyHistory.length).toStringAsFixed(1));
  }

  /// Generates a contextual AI health insight.
  String getInsight(String language) {
    final avgSteps = weeklyAverageSteps;
    final pct = _stepGoal > 0 ? ((avgSteps / _stepGoal) * 100).round() : 0;

    if (pct >= 100) {
      return language == 'ur'
          ? '🎉 زبردست کارکردگی! آپ نے اس ہفتے روزانہ اوسطاً $avgSteps قدم مکمل کیے ہیں جو آپ کے ہدف سے زیادہ ہے!'
          : '🎉 Outstanding performance! You exceeded your daily goal with an average of $avgSteps steps/day this week!';
    } else if (pct >= 75) {
      return language == 'ur'
          ? '💪 بہت عمدہ رفتار! آپ روزانہ اوسطاً $avgSteps قدم ($pct% ہدف) مکمل کر رہے ہیں۔ مستقل مزاجی برقرار رکھیں!'
          : '💪 Great momentum! You are hitting $avgSteps steps/day ($pct% of your goal). Keep this streak alive!';
    } else if (pct >= 50) {
      return language == 'ur'
          ? '🚶 اچھی پیشرفت — روزانہ $avgSteps قدم۔ ہدف حاصل کرنے کے لیے شام کی مختصر چہل قدمی شامل کریں۔'
          : '🚶 Steady progress — averaging $avgSteps steps/day. Add a 15-min evening stroll to reach your target.';
    } else {
      return language == 'ur'
          ? '⚡ آپ کی اوسط $avgSteps قدم/دن ہے۔ روزانہ کی سرگرمی میں اضافہ میٹابولزم کو تیز کرنے میں مدد دے گا۔'
          : '⚡ You are averaging $avgSteps steps/day. Boosting daily activity will elevate your metabolism and recovery.';
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
    _isConnected = true;
    await HealthService.instance.setSyncEnabled(true);
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
