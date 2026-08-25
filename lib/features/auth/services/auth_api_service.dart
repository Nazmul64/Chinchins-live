import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';

class AuthApiService {
  static const String _keyToken = 'auth_token';
  static const String _keyUser = 'auth_user';

  /// Register a new user with RESTful API
  static Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final url = Uri.parse(ApiConstants.register);
      final body = jsonEncode({
        'name': '${firstName.trim()} ${lastName.trim()}'.trim(),
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'phone': phone.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'password_confirmation': passwordConfirmation,
      });

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || (data is Map && data['status'] == true)) {
        final token = data['data']?['token'];
        final user = data['data']?['user'];

        if (token != null) {
          await _saveSession(token: token.toString(), user: user);
        }

        return {
          'success': true,
          'message': data['message'] ?? 'Registration successful!',
          'user': user,
          'token': token,
        };
      } else {
        String message = data['message'] ?? 'Registration failed';
        if (data['errors'] != null && data['errors'] is Map) {
          final errors = data['errors'] as Map;
          if (errors.isNotEmpty) {
            final firstErrorList = errors.values.first;
            if (firstErrorList is List && firstErrorList.isNotEmpty) {
              message = firstErrorList.first.toString();
            }
          }
        }
        return {
          'success': false,
          'message': message,
          'errors': data['errors'],
        };
      }
    } on SocketException {
      return {
        'success': false,
        'message': 'Cannot connect to backend server. Please make sure the Laravel API server is running.',
      };
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Connection timed out. Please try again.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred: ',
      };
    }
  }

  /// Login user with Email or Phone Number + Password
  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final url = Uri.parse(ApiConstants.login);
      final body = jsonEncode({
        'identifier': identifier.trim(),
        'password': password,
      });

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      final isSuccess = response.statusCode == 200 &&
          (data is Map && (data['status'] == true || data['status'] == 'success' || data['token'] != null || data['data']?['token'] != null));

      if (isSuccess) {
        final token = data['data']?['token'] ?? data['token'] ?? data['access_token'];
        final user = data['data']?['user'] ?? data['user'];

        if (token != null) {
          await _saveSession(token: token.toString(), user: user);
        }

        return {
          'success': true,
          'message': data['message'] ?? 'Login successful!',
          'user': user,
          'token': token,
        };
      } else {
        String message = (data is Map && data['message'] != null) ? data['message'] : 'Invalid credentials';
        if (data is Map && data['errors'] != null && data['errors'] is Map) {
          final errors = data['errors'] as Map;
          if (errors.isNotEmpty) {
            final firstErrorList = errors.values.first;
            if (firstErrorList is List && firstErrorList.isNotEmpty) {
              message = firstErrorList.first.toString();
            }
          }
        }
        return {
          'success': false,
          'message': message,
        };
      }
    } on SocketException {
      return {
        'success': false,
        'message': 'Cannot connect to backend server (${ApiConstants.baseUrl}). Please ensure backend is reachable.',
      };
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Connection timed out. Please try again.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred: $e',
      };
    }
  }

  /// Save user token & profile in local storage
  static Future<void> _saveSession({
    required String token,
    Map<String, dynamic>? user,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    if (user != null) {
      await prefs.setString(_keyUser, jsonEncode(user));
    }
  }

  /// Retrieve stored auth token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  /// Retrieve stored user data
  static Future<Map<String, dynamic>?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_keyUser);
    if (userStr != null) {
      try {
        return jsonDecode(userStr) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  /// Clear session on logout
  static Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null) {
        final url = Uri.parse(ApiConstants.logout);
        await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ',
          },
        ).timeout(const Duration(seconds: 5));
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
  }
}
