import 'package:flutter/foundation.dart';

/// Global singleton notifier that broadcasts profile modification events
/// to keep Dashboard calorie targets, AI Coach, and Workout screens
/// synchronized in real time when settings are updated.
class ProfileSyncNotifier extends ChangeNotifier {
  ProfileSyncNotifier._();

  static final ProfileSyncNotifier instance = ProfileSyncNotifier._();

  /// Notify all listening widgets and controllers that user health profile has changed
  void notifyProfileChanged() {
    notifyListeners();
  }
}
