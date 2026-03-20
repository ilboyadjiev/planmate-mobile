import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../core/config/app_config.dart';

class ApiService {

  static const String baseUrl = '${AppConfig.apiBaseUrl}/v1';

  /// A wrapper for GET requests that automatically handles expired tokens
  static Future<http.Response> getSecure(String endpoint) async {
    print('Running GET request to : ${baseUrl}${endpoint}');
    return _requestWithRetry(() async {
      final token = await _getAccessToken();
      return http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Authorization': 'Bearer $token'},
      );
    });
  }

  /// A wrapper for POST requests
  static Future<http.Response> postSecure(String endpoint, Map<String, dynamic> body) async {
    return _requestWithRetry(() async {
      final token = await _getAccessToken();
      return http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
    });
  }

  /// A wrapper for PUT requests
  static Future<http.Response> putSecure(String endpoint, Map<String, dynamic> body) async {
    return _requestWithRetry(() async {
      final token = await _getAccessToken();
      return http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
    });
  }

  /// A wrapper for DELETE requests
  static Future<http.Response> deleteSecure(String endpoint) async {
    return _requestWithRetry(() async {
      final token = await _getAccessToken();
      return http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
    });
  }

  // --- CORE LOGIC ---

  static Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<http.Response> _requestWithRetry(Future<http.Response> Function() requestFunc) async {

    http.Response response = await requestFunc();

    if (response.statusCode == 401 || response.statusCode == 403) {
      print("Token expired! Attempting to refresh...");
      bool refreshed = await _refreshToken();

      if (refreshed) {
        print("Refresh successful! Retrying original request...");
        response = await requestFunc();
      } else {
        throw Exception("Session Expired. Please log in again.");
      }
    }

    return response;
  }

  static Future<bool> _refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');

    if (refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        await prefs.setString('access_token', data['accessToken']);
        
        if (data.containsKey('refreshToken')) {
           await prefs.setString('refresh_token', data['refreshToken']);
        }
        return true;
      }
    } catch (e) {
      print("Error during refresh: $e");
    }
    return false;
  }
}