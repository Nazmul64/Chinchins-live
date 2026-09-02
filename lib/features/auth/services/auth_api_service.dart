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
    String? email,
    required String password,
    required String passwordConfirmation,
    String? country,
    String? nickname,
    String? city,
    String? gender,
    int? age,
    String? introduction,
    List<String>? languages,
    List<String>? tags,
    int? videoCallRate,
  }) async {
    try {
      final url = Uri.parse(ApiConstants.register);
      final Map<String, dynamic> requestPayload = {
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'phone': phone.trim(),
        'phone_number': phone.trim(),
        'country': country ?? 'Bangladesh',
        'password': password,
        'password_confirmation': passwordConfirmation,
        'confirm_password': passwordConfirmation,
      };

      if (email != null && email.trim().isNotEmpty) {
        requestPayload['email'] = email.trim().toLowerCase();
      }
      if (nickname != null && nickname.trim().isNotEmpty) {
        requestPayload['nickname'] = nickname.trim();
      }
      if (city != null && city.trim().isNotEmpty) {
        requestPayload['city'] = city.trim();
      }
      if (gender != null && gender.trim().isNotEmpty) {
        requestPayload['gender'] = gender.trim();
      }
      if (age != null) {
        requestPayload['age'] = age;
      }
      if (introduction != null && introduction.trim().isNotEmpty) {
        requestPayload['introduction'] = introduction.trim();
      }
      if (languages != null && languages.isNotEmpty) {
        requestPayload['languages'] = languages;
      }
      if (tags != null && tags.isNotEmpty) {
        requestPayload['tags'] = tags;
      }
      if (videoCallRate != null) {
        requestPayload['video_call_rate'] = videoCallRate;
      }

      final body = jsonEncode(requestPayload);

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
        final token = data['data']?['token'] ?? data['token'];
        final user = data['data']?['user'] ?? data['user'];

        if (token != null) {
          await _saveSession(token: token.toString(), user: user);
        }

        return {
          'success': true,
          'message': data['message'] ?? 'Registration successful',
          'user': user,
          'token': token,
        };
      } else {
        String message = data is Map ? (data['message'] ?? 'Registration failed') : 'Registration failed';
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
          'errors': data is Map ? data['errors'] : null,
        };
      }
    } on SocketException {
      return {
        'success': false,
        'message': 'Cannot connect to backend server (${ApiConstants.baseUrl}). Please check internet connection.',
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

  /// Check if user has an existing saved login session
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Verify session with backend or fallback to cached user
  static Future<Map<String, dynamic>?> checkAuthSession() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) return null;

      final headers = {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // 1. Try /api/auth/check or /api/auth/me or /api/user
      http.Response? response;
      try {
        response = await http.get(Uri.parse(ApiConstants.authCheck), headers: headers).timeout(const Duration(seconds: 6));
      } catch (_) {
        try {
          response = await http.get(Uri.parse(ApiConstants.userProfile), headers: headers).timeout(const Duration(seconds: 6));
        } catch (_) {}
      }

      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final userData = decoded['data']?['user'] ?? decoded['user'] ?? decoded['data'];
          if (userData is Map<String, dynamic>) {
            await saveUser(userData);
            return userData;
          }
        }
        return await getSavedUser();
      } else if (response != null && response.statusCode == 401) {
        // Token was explicitly revoked / invalid
        await logout();
        return null;
      }

      // If server is slow or temporary network error, use cached user to keep user logged in!
      return await getSavedUser();
    } catch (e) {
      // Offline fallback: Keep user logged in with cached session
      return await getSavedUser();
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

  /// Update locally stored user data
  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUser, jsonEncode(user));
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

  /// Clear session on explicit manual logout ONLY
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
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 4));
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
  }
}
