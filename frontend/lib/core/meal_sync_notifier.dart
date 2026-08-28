import 'package:flutter/foundation.dart';

/// Global singleton notifier that broadcasts meal logging events
/// to keep the Dashboard calorie tracker, Meals list, and Stats screens
/// synchronized in real time without requiring manual refreshes.
class MealSyncNotifier extends ChangeNotifier {
  MealSyncNotifier._();

  static final MealSyncNotifier instance = MealSyncNotifier._();

  /// Notify all listening widgets that meal logs have been modified
  void notifyMealChanged() {
    notifyListeners();
  }
}
