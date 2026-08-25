import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/model_profile.dart';
import '../../features/auth/services/auth_api_service.dart';

class ProfileApiService {
  /// Fetch authenticated user profile
  static Future<ModelProfile?> getMyProfile() async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.profileMe);

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userData = data['data']?['user'] ?? data['user'];
        if (userData != null && userData is Map<String, dynamic>) {
          return ModelProfile.fromJson(userData);
        }
      }
    } catch (e) {
      // Return null on connection error
    }
    return null;
  }

  /// Fetch public profile by ID or Account ID
  static Future<ModelProfile?> getProfile(String id) async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.profileById(id));

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userData = data['data']?['user'] ?? data['user'];
        if (userData != null && userData is Map<String, dynamic>) {
          return ModelProfile.fromJson(userData);
        }
      }
    } catch (e) {
      // Fallback
    }
    return null;
  }

  /// Update Profile Information in Laravel Database
  static Future<Map<String, dynamic>> updateProfile({
    String? firstName,
    String? lastName,
    String? nickname,
    String? gender,
    int? age,
    String? country,
    String? city,
    String? introduction,
    List<String>? languages,
    List<String>? tags,
    int? videoCallRate,
    String? level,
    bool? isActive,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.profileUpdate);

      final Map<String, dynamic> body = {};
      if (firstName != null) body['first_name'] = firstName;
      if (lastName != null) body['last_name'] = lastName;
      if (nickname != null) body['nickname'] = nickname;
      if (gender != null) body['gender'] = gender;
      if (age != null) body['age'] = age;
      if (country != null) body['country'] = country;
      if (city != null) body['city'] = city;
      if (introduction != null) body['introduction'] = introduction;
      if (languages != null) body['languages'] = languages;
      if (tags != null) body['tags'] = tags;
      if (videoCallRate != null) body['video_call_rate'] = videoCallRate;
      if (level != null) body['level'] = level;
      if (isActive != null) body['is_active'] = isActive;

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Profile updated successfully',
          'user': data['data']?['user'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update profile',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error updating profile: $e',
      };
    }
  }

  /// Upload real multiple gallery photos (multipart)
  static Future<Map<String, dynamic>> uploadPhotos(List<String> filePaths) async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.uploadPhotos);

      final request = http.MultipartRequest('POST', url);
      request.headers.addAll({
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });

      for (final path in filePaths) {
        if (File(path).existsSync()) {
          request.files.add(await http.MultipartFile.fromPath('photos[]', path));
        }
      }

      if (request.files.isEmpty) {
        return {'success': false, 'message': 'No valid files selected.'};
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 40));
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Photos uploaded successfully',
          'user': data['data']?['user'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to upload photos',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error uploading photos: $e',
      };
    }
  }

  /// Delete Photo from Gallery
  static Future<Map<String, dynamic>> deletePhoto(String photoUrl) async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.deletePhoto);

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'photo': photoUrl}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to delete photo'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error deleting photo: $e'};
    }
  }

  /// Toggle Online Status
  static Future<bool> toggleOnlineStatus(bool isActive) async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.profileStatus);

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'is_active': isActive}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == true;
      }
    } catch (_) {}
    return false;
  }
}
