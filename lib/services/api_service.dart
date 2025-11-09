// lib/services/api_service.dart
import 'package:http/http.dart' as http; // <-- 1. IMPORT HTTP
import 'package:shared_preferences/shared_preferences.dart'; // <-- 2. IMPORT SHARED_PREFERENCES

class ApiService {
  static const String _baseUrl = 'https://pledge-loan-api-as.onrender.com/api';
  String? _token;

  // Singleton pattern to make sure we only have one instance
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Future<void> _loadToken() async {
    if (_token == null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('jwt_token');
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    await _loadToken();
    if (_token == null) {
      // This should ideally not happen if we protect our routes
      throw Exception('Not authenticated');
    }
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $_token',
    };
  }

  // --- Wrapper for HTTP GET ---
  // 3. We use http.Response here, which is now defined
  Future<http.Response> get(String endpoint) async {
    final headers = await _getHeaders();
    return http.get(Uri.parse('$_baseUrl/$endpoint'), headers: headers);
  }

// You can add post, put, delete wrappers here later
}