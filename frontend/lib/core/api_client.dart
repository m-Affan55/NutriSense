import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiClient {
  static String getBaseUrl() {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api/v1';
    }
    
    if (Platform.isAndroid) {
      // Android Emulator uses 10.0.2.2 to connect to host's localhost
      return 'http://10.0.2.2:8000/api/v1';
    }
    
    // Desktop (Windows/macOS/Linux) or iOS Simulator
    return 'http://127.0.0.1:8000/api/v1';
  }
}
