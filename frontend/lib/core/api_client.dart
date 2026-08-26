import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiClient {
  // Live Cloud Backend on Render
  static const String _liveBackendUrl = 'https://nutrisense-backend-v1.onrender.com/api/v1';

  static String getBaseUrl() {
    return _liveBackendUrl;
  }
}
