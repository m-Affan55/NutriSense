import 'package:supabase_flutter/supabase_flutter.dart';

class ApiClient {
  /// Set to `true` to test against your local backend (http://127.0.0.1:8000/api/v1).
  /// Set to `false` to point to the live Render cloud backend.
  static const bool useLocalBackend = false;

  // Live Cloud Backend on Render
  static const String _liveBackendUrl = 'https://nutrisense-backend-v1.onrender.com/api/v1';

  // Local Backend
  static const String _localBackendUrl = 'http://127.0.0.1:8000/api/v1';

  static String getBaseUrl() {
    if (useLocalBackend) {
      return _localBackendUrl;
    }
    return _liveBackendUrl;
  }

  /// Generates the standard headers including JWT Authorization token if logged in
  static Map<String, String> getHeaders() {
    final session = Supabase.instance.client.auth.currentSession;
    final jwt = session?.accessToken;
    return {
      'Content-Type': 'application/json',
      if (jwt != null) 'Authorization': 'Bearer $jwt',
    };
  }
}
