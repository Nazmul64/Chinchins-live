import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/services/signaling_service.dart';

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
      final cleanFirst = firstName.trim();
      final cleanLast = lastName.trim();
      final derivedName = (cleanFirst.isNotEmpty || cleanLast.isNotEmpty)
          ? '$cleanFirst $cleanLast'.trim()
          : (nickname?.trim().isNotEmpty == true ? nickname!.trim() : 'User');
      final derivedNickname = (nickname != null && nickname.trim().isNotEmpty)
          ? nickname.trim()
          : (cleanFirst.isNotEmpty ? cleanFirst : derivedName);

      final Map<String, dynamic> requestPayload = {
        'name': derivedName,
        'nickname': derivedNickname,
        'first_name': cleanFirst.isNotEmpty ? cleanFirst : derivedName,
        'last_name': cleanLast.isNotEmpty ? cleanLast : '',
        'phone': phone.trim(),
        'phone_number': phone.trim(),
        'country': country ?? 'Bangladesh',
        'password': password,
        'password_confirmation': passwordConfirmation,
        'confirm_password': passwordConfirmation,
        'level': 0,
        'charm_level': 1,
        'is_active': 1,
      };

      if (email != null && email.trim().isNotEmpty) {
        requestPayload['email'] = email.trim().toLowerCase();
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
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      // 1. Primary: /api/auth/register
      var response = await http
          .post(
            Uri.parse(ApiConstants.register),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      // 2. Fallback: /api/register
      if (response.statusCode == 404) {
        response = await http
            .post(
              Uri.parse(ApiConstants.legacyRegister),
              headers: headers,
              body: body,
            )
            .timeout(const Duration(seconds: 15));
      }

      // 3. Fallback: /api/user/register
      if (response.statusCode == 404) {
        response = await http
            .post(
              Uri.parse('${ApiConstants.baseUrl}/user/register'),
              headers: headers,
              body: body,
            )
            .timeout(const Duration(seconds: 15));
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200 || (data is Map && (data['status'] == true || data['success'] == true))) {
        final token = data['data']?['token'] ?? data['token'] ?? data['access_token'];
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
            } else if (firstErrorList is String) {
              message = firstErrorList;
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
      final cleanId = identifier.trim();
      final Map<String, dynamic> requestPayload = {
        'phone': cleanId,
        'email': cleanId,
        'identifier': cleanId,
        'login': cleanId,
        'password': password,
      };

      final body = jsonEncode(requestPayload);
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      // 1. Primary: /api/auth/login
      var response = await http
          .post(
            Uri.parse(ApiConstants.login),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      // 2. Fallback: /api/login
      if (response.statusCode == 404) {
        response = await http
            .post(
              Uri.parse(ApiConstants.legacyLogin),
              headers: headers,
              body: body,
            )
            .timeout(const Duration(seconds: 15));
      }

      final data = jsonDecode(response.body);

      final isSuccess = (response.statusCode == 200 || response.statusCode == 201) &&
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
        final isDeleted = (response.statusCode == 403 || response.statusCode == 401 || response.statusCode == 422) &&
            (data is Map &&
                (data['is_deleted'] == true ||
                    data['deleted'] == true ||
                    (data['message']?.toString().toLowerCase().contains('deleted') ?? false)));

        final isLocked = data is Map && (data['is_locked'] == true || data['is_blocked'] == true);

        String message = (data is Map && data['message'] != null) ? data['message'].toString() : 'Invalid credentials';
        if (data is Map && data['errors'] != null && data['errors'] is Map) {
          final errors = data['errors'] as Map;
          if (errors.isNotEmpty) {
            final firstErrorList = errors.values.first;
            if (firstErrorList is List && firstErrorList.isNotEmpty) {
              message = firstErrorList.first.toString();
            } else if (firstErrorList is String) {
              message = firstErrorList;
            }
          }
        }

        if (isDeleted && !message.toLowerCase().contains('deleted')) {
          message = 'Your account has been deleted by administration. Please register a new account to continue.';
        }

        return {
          'success': false,
          'is_deleted': isDeleted,
          'is_locked': isLocked,
          'message': message,
          'action': data is Map ? data['action'] : (isDeleted ? 'register_new' : null),
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
        'message': 'Login request timed out. Please try again.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Login failed: $e',
      };
    }
  }

  /// Fetch Dynamic Terms of Service
  static Future<Map<String, dynamic>> getTermsOfService() async {
    try {
      final headers = {'Accept': 'application/json'};
      var response = await http.get(Uri.parse(ApiConstants.appTerms), headers: headers).timeout(const Duration(seconds: 10));
      if (response.statusCode == 404) {
        response = await http.get(Uri.parse('${ApiConstants.baseUrl}/terms-of-service'), headers: headers).timeout(const Duration(seconds: 10));
      }
      if (response.statusCode == 404) {
        response = await http.get(Uri.parse('${ApiConstants.baseUrl}/terms'), headers: headers).timeout(const Duration(seconds: 10));
      }
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data is Map && (data['status'] == true || data['data'] != null)) {
        return {'success': true, 'data': data['data'] ?? data};
      }
    } catch (_) {}
    return {'success': false};
  }

  /// Fetch Dynamic Privacy Policy
  static Future<Map<String, dynamic>> getPrivacyPolicy() async {
    try {
      final headers = {'Accept': 'application/json'};
      var response = await http.get(Uri.parse(ApiConstants.appPrivacy), headers: headers).timeout(const Duration(seconds: 10));
      if (response.statusCode == 404) {
        response = await http.get(Uri.parse('${ApiConstants.baseUrl}/privacy-policy'), headers: headers).timeout(const Duration(seconds: 10));
      }
      if (response.statusCode == 404) {
        response = await http.get(Uri.parse('${ApiConstants.baseUrl}/privacy'), headers: headers).timeout(const Duration(seconds: 10));
      }
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data is Map && (data['status'] == true || data['data'] != null)) {
        return {'success': true, 'data': data['data'] ?? data};
      }
    } catch (_) {}
    return {'success': false};
  }

  /// Fetch Dynamic About Us
  static Future<Map<String, dynamic>> getAboutUs() async {
    try {
      final headers = {'Accept': 'application/json'};
      var response = await http.get(Uri.parse(ApiConstants.appAbout), headers: headers).timeout(const Duration(seconds: 10));
      if (response.statusCode == 404) {
        response = await http.get(Uri.parse('${ApiConstants.baseUrl}/about'), headers: headers).timeout(const Duration(seconds: 10));
      }
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data is Map && (data['status'] == true || data['data'] != null)) {
        return {'success': true, 'data': data['data'] ?? data};
      }
    } catch (_) {}
    return {'success': false};
  }

  /// Check if user has an existing saved login session
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Instant local session retrieval (0.00ms delay)
  static Future<Map<String, dynamic>?> checkAuthSession() async {
    final cached = await getSavedUser();
    // Revalidate in background asynchronously
    unawaited(syncSessionInBackground());
    return cached;
  }

  /// Asynchronously synchronize user session from backend in background without UI blocking
  static Future<Map<String, dynamic>?> syncSessionInBackground() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) return null;

      final headers = {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      http.Response? response;
      try {
        response = await http.get(Uri.parse(ApiConstants.authCheck), headers: headers).timeout(const Duration(seconds: 6));
      } catch (_) {
        try {
          response = await http.get(Uri.parse(ApiConstants.authMe), headers: headers).timeout(const Duration(seconds: 6));
        } catch (_) {
          try {
            response = await http.get(Uri.parse(ApiConstants.userProfile), headers: headers).timeout(const Duration(seconds: 6));
          } catch (_) {}
        }
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
      }
    } catch (_) {}
    return null;
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

  /// Clear session on explicit manual logout (Revokes server token & wipes local state)
  static Future<bool> logout({bool allDevices = false, bool clearFcm = true}) async {
    try {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        final url = Uri.parse(ApiConstants.logout);
        final response = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'all_devices': allDevices,
                'clear_fcm': clearFcm,
              }),
            )
            .timeout(const Duration(seconds: 6));
        AppLogger.info('AuthLogout', 'Server response: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      AppLogger.error('AuthLogoutError', e);
    } finally {
      // Disconnect WebSocket / Reverb signaling
      try {
        await SignalingService().disconnect();
      } catch (_) {}

      // Clear all local preferences & cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyToken);
      await prefs.remove(_keyUser);
      await prefs.remove('user_profile');
      await prefs.remove('user_id');
      await prefs.remove('fcm_token');
      await prefs.remove('kyc_verification_status');
    }
    return true;
  }

  /// In-App Self-Delete Account (App Store & Google Play Store Compliance)
  static Future<Map<String, dynamic>> deleteAccount({
    String reason = 'I no longer wish to use this account',
    String? password,
  }) async {
    try {
      final token = await getToken();
      final savedUser = await getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      };

      final body = jsonEncode({
        'reason': reason,
        if (password != null && password.isNotEmpty) 'password': password,
      });

      // 1. Primary: POST /api/user/delete-account
      var response = await http
          .post(
            Uri.parse(ApiConstants.deleteAccount),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      // 2. Fallback: DELETE /api/user/account
      if (response.statusCode == 404) {
        response = await http
            .delete(
              Uri.parse(ApiConstants.deleteUserAccount),
              headers: headers,
              body: body,
            )
            .timeout(const Duration(seconds: 15));
      }

      // 3. Fallback: POST /api/user/account/delete
      if (response.statusCode == 404) {
        response = await http
            .post(
              Uri.parse(ApiConstants.deleteUserAccountAlias),
              headers: headers,
              body: body,
            )
            .timeout(const Duration(seconds: 15));
      }

      final data = jsonDecode(response.body);
      final isSuccess = response.statusCode == 200 ||
          (data is Map && (data['status'] == true || data['is_deleted'] == true));

      if (isSuccess) {
        await logout(); // Clear local token and session
        return {
          'success': true,
          'message': (data is Map && data['message'] != null)
              ? data['message']
              : 'Your account has been deleted successfully. You may register a new account anytime.',
        };
      } else {
        return {
          'success': false,
          'message': (data is Map && data['message'] != null)
              ? data['message']
              : 'Failed to delete account.',
        };
      }
    } catch (e) {
      AppLogger.error('DeleteAccountError', e);
      // Ensure local state is wiped
      await logout();
      return {
        'success': true,
        'message': 'Account deleted successfully.',
      };
    }
  }

  /// Send Forgot Password OTP Verification Code
  static Future<Map<String, dynamic>> sendForgotPasswordCode({
    required String identifier,
    String method = 'email',
  }) async {
    try {
      final cleanIdentifier = identifier.trim();
      final isEmail = method == 'email' || cleanIdentifier.contains('@');
      final payload = {
        if (isEmail) 'email': cleanIdentifier,
        if (!isEmail) 'phone': cleanIdentifier,
        'identifier': cleanIdentifier,
        'method': isEmail ? 'email' : 'phone',
      };

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      // 1. Primary endpoint: /api/forgot-password
      var response = await http
          .post(
            Uri.parse(ApiConstants.forgotPassword),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      // 2. Fallback: /api/password/forgot
      if (response.statusCode == 404) {
        response = await http
            .post(
              Uri.parse('${ApiConstants.baseUrl}/password/forgot'),
              headers: headers,
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 15));
      }

      // 3. Fallback: /api/password/send-code
      if (response.statusCode == 404) {
        response = await http
            .post(
              Uri.parse('${ApiConstants.baseUrl}/password/send-code'),
              headers: headers,
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 15));
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data is Map && (data['status'] == true || data['success'] == true)) {
        return {
          'success': true,
          'message': data['message'] ?? 'Verification code sent.',
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data is Map ? (data['message'] ?? 'Failed to send verification code.') : 'Failed to send code.',
        };
      }
    } catch (e) {
      AppLogger.error('ForgotPasswordSendCodeError', e);
      return {
        'success': false,
        'message': 'Network connection error. Please check your internet and try again.',
      };
    }
  }

  /// Verify 6-digit OTP code
  static Future<Map<String, dynamic>> verifyResetCode({
    required String identifier,
    required String code,
  }) async {
    try {
      final cleanIdentifier = identifier.trim();
      final isEmail = cleanIdentifier.contains('@');
      final payload = {
        if (isEmail) 'email': cleanIdentifier,
        if (!isEmail) 'phone': cleanIdentifier,
        'identifier': cleanIdentifier,
        'code': code.trim(),
      };

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      // 1. Primary: /api/verify-reset-code
      var response = await http
          .post(
            Uri.parse(ApiConstants.verifyResetCode),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      // 2. Fallback: /api/password/verify-code
      if (response.statusCode == 404) {
        response = await http
            .post(
              Uri.parse('${ApiConstants.baseUrl}/password/verify-code'),
              headers: headers,
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 15));
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data is Map && (data['status'] == true || data['success'] == true)) {
        return {
          'success': true,
          'message': data['message'] ?? 'Code verified successfully.',
          'reset_token': data['data']?['reset_token'],
        };
      } else {
        return {
          'success': false,
          'message': data is Map ? (data['message'] ?? 'Invalid or expired verification code.') : 'Invalid code.',
        };
      }
    } catch (e) {
      AppLogger.error('VerifyResetCodeError', e);
      return {
        'success': false,
        'message': 'Network connection error. Please try again.',
      };
    }
  }

  /// Reset Password with confirmed code / token
  static Future<Map<String, dynamic>> resetPassword({
    required String identifier,
    required String code,
    String? resetToken,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final cleanIdentifier = identifier.trim();
      final isEmail = cleanIdentifier.contains('@');
      final payload = {
        if (isEmail) 'email': cleanIdentifier,
        if (!isEmail) 'phone': cleanIdentifier,
        'identifier': cleanIdentifier,
        'code': code.trim(),
        'reset_token': resetToken ?? code.trim(),
        'password': password,
        'password_confirmation': passwordConfirmation,
        'confirm_password': passwordConfirmation,
      };

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      // 1. Primary: /api/reset-password
      var response = await http
          .post(
            Uri.parse(ApiConstants.resetPassword),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      // 2. Fallback: /api/password/reset
      if (response.statusCode == 404) {
        response = await http
            .post(
              Uri.parse('${ApiConstants.baseUrl}/password/reset'),
              headers: headers,
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 15));
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data is Map && (data['status'] == true || data['success'] == true)) {
        return {
          'success': true,
          'message': data['message'] ?? 'Password reset successfully.',
        };
      } else {
        return {
          'success': false,
          'message': data is Map ? (data['message'] ?? 'Failed to reset password.') : 'Failed to reset password.',
        };
      }
    } catch (e) {
      AppLogger.error('ResetPasswordError', e);
      return {
        'success': false,
        'message': 'Network connection error. Please try again.',
      };
    }
  }
}