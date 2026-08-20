import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiClient {
  static String getBaseUrl() {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api/v1';
    }
    
    if (Platform.isAndroid) {
      // Changed to 127.0.0.1 for physical phone testing via `adb reverse`
      // (Revert to 10.0.2.2 if you ever go back to using the Android Emulator)
      return 'http://127.0.0.1:8000/api/v1';
    }
    
    // Desktop (Windows/macOS/Linux) or iOS Simulator
    return 'http://127.0.0.1:8000/api/v1';
  }
}
