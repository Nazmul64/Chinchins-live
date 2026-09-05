import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/model_profile.dart';
import '../../features/auth/services/auth_api_service.dart';

class ProfileApiService {
  /// Safely parse JSON from raw HTTP body without throwing FormatException on HTML error pages
  static dynamic _safeJsonDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  /// Fetch authenticated user profile
  static Future<ModelProfile?> getMyProfile() async {
    try {
      final token = await AuthApiService.getToken();
      if (token == null) return null;

      Uri url = Uri.parse(ApiConstants.profileMe);
      var response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 404) {
        url = Uri.parse(ApiConstants.userProfile);
        response = await http.get(
          url,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 10));
      }

      if (response.statusCode == 200) {
        final data = _safeJsonDecode(response.body);
        if (data != null) {
          final userData = data['data']?['user'] ?? data['data'] ?? data['user'];
          if (userData != null && userData is Map<String, dynamic>) {
            return ModelProfile.fromJson(userData);
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Fetch streamers/users for Home Feed
  static Future<List<ModelProfile>> getHomeFeed({
    int page = 1,
    int perPage = 20,
    String? country,
    String? gender,
    String? search,
    bool? isActive,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final queryParams = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (country != null && country.isNotEmpty && country != 'All') {
        queryParams['country'] = country;
      }
      if (gender != null && gender.isNotEmpty && gender != 'All') {
        queryParams['gender'] = gender.toLowerCase();
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (isActive != null) {
        queryParams['is_active'] = isActive ? '1' : '0';
      }

      final uri = Uri.parse(ApiConstants.homeFeed).replace(queryParameters: queryParams);
      var response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 404) {
        // Fallback to /api/users
        final usersUri = Uri.parse(ApiConstants.users).replace(queryParameters: queryParams);
        response = await http.get(
          usersUri,
          headers: {
            'Accept': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 10));
      }

      if (response.statusCode == 200) {
        final data = _safeJsonDecode(response.body);
        if (data != null) {
          List? userList;
          if (data is List) {
            userList = data;
          } else if (data is Map) {
            if (data['data'] is List) {
              userList = data['data'] as List;
            } else if (data['data'] is Map) {
              if (data['data']['users'] is List) {
                userList = data['data']['users'] as List;
              } else if (data['data']['data'] is List) {
                userList = data['data']['data'] as List;
              }
            } else if (data['users'] is List) {
              userList = data['users'] as List;
            }
          }

          if (userList != null && userList.isNotEmpty) {
            return userList
                .whereType<Map<String, dynamic>>()
                .map((u) => ModelProfile.fromJson(u))
                .where((profile) {
                  final name = profile.name.trim().toLowerCase();
                  final firstName = (profile.firstName ?? '').trim().toLowerCase();
                  final lastName = (profile.lastName ?? '').trim().toLowerCase();
                  final email = (profile.email ?? '').trim().toLowerCase();

                  if (name == 'admin' ||
                      name.contains('administrator') ||
                      name == 'ayeena04' ||
                      name == 'ayeena' ||
                      firstName == 'admin' ||
                      lastName == 'admin' ||
                      email.startsWith('admin@') ||
                      email.contains('admin@')) {
                    return false;
                  }
                  return true;
                })
                .toList();
          }
        }
      }
    } catch (_) {}
    return [];
  }

  /// Search users by 8-digit Account ID or Name (GET /api/search?q={query})
  static Future<List<ModelProfile>> searchUsers({required String query}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      final token = await AuthApiService.getToken();
      final headers = {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      // 1. Try GET /api/search?q={query}
      Uri url = Uri.parse(ApiConstants.searchUsers(cleanQuery));
      var response = await http.get(url, headers: headers).timeout(const Duration(seconds: 8));

      // 2. Fallback to /api/users/search?search={query} or /api/users?search={query}
      if (response.statusCode != 200) {
        url = Uri.parse('${ApiConstants.usersSearch}?search=${Uri.encodeComponent(cleanQuery)}');
        response = await http.get(url, headers: headers).timeout(const Duration(seconds: 8));
      }
      if (response.statusCode != 200) {
        url = Uri.parse('${ApiConstants.users}?search=${Uri.encodeComponent(cleanQuery)}');
        response = await http.get(url, headers: headers).timeout(const Duration(seconds: 8));
      }

      if (response.statusCode == 200) {
        final data = _safeJsonDecode(response.body);
        if (data != null) {
          List? list;
          if (data is List) {
            list = data;
          } else if (data is Map) {
            if (data['data'] is List) {
              list = data['data'] as List;
            } else if (data['data'] is Map && data['data']['users'] is List) {
              list = data['data']['users'] as List;
            } else if (data['users'] is List) {
              list = data['users'] as List;
            } else if (data['data'] is Map && data['data']['data'] is List) {
              list = data['data']['data'] as List;
            }
          }

          if (list != null && list.isNotEmpty) {
            return list
                .whereType<Map<String, dynamic>>()
                .map((u) => ModelProfile.fromJson(u))
                .toList();
          }
        }
      }
    } catch (_) {}
    return [];
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
        final data = _safeJsonDecode(response.body);
        if (data != null) {
          final userData = data['data']?['user'] ?? data['user'];
          if (userData != null && userData is Map<String, dynamic>) {
            return ModelProfile.fromJson(userData);
          }
        }
      }
    } catch (_) {}
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

      final data = _safeJsonDecode(response.body);
      if (response.statusCode == 200 && data != null && (data['status'] == true || data['success'] == true)) {
        return {
          'success': true,
          'message': data['message'] ?? 'Profile updated successfully',
          'user': data['data']?['user'] ?? data['user'] ?? data['data'],
        };
      } else {
        String msg = 'Failed to update profile';
        if (data != null && data is Map) {
          msg = data['message'] ?? data['error'] ?? msg;
        }
        return {
          'success': false,
          'message': msg,
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
      final data = _safeJsonDecode(response.body);

      if ((response.statusCode == 200 || response.statusCode == 201) && data != null) {
        final userData = data['data']?['user'] ?? data['user'] ?? (data['data'] is Map<String, dynamic> ? data['data'] : null);
        return {
          'success': true,
          'message': data['message'] ?? 'Photos uploaded successfully',
          'user': userData,
        };
      } else {
        String msg = 'Failed to upload photos';
        if (data != null && data is Map) {
          msg = data['message'] ?? data['error'] ?? msg;
        } else if (response.statusCode == 413) {
          msg = 'Photo file is too large (413)';
        } else if (response.statusCode >= 500) {
          msg = 'Server internal error (${response.statusCode})';
        }
        return {
          'success': false,
          'message': msg,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error uploading photos: $e',
      };
    }
  }

  /// Upload Avatar Photo (multipart)
  static Future<Map<String, dynamic>> uploadAvatar(String filePath) async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.uploadAvatar);

      final request = http.MultipartRequest('POST', url);
      request.headers['Accept'] = 'application/json';
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      if (File(filePath).existsSync()) {
        request.files.add(await http.MultipartFile.fromPath('avatar', filePath));
      } else {
        return {'success': false, 'message': 'Selected file does not exist.'};
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 40));
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint("Upload Status: ${response.statusCode}");
      debugPrint("Response: ${response.body}");

      final data = _safeJsonDecode(response.body);

      if ((response.statusCode == 200 || response.statusCode == 201) && data != null) {
        final userData = data['data']?['user'] ?? data['user'] ?? (data['data'] is Map<String, dynamic> ? data['data'] : null);
        return {
          'success': true,
          'message': data['message'] ?? 'Avatar uploaded successfully',
          'user': userData,
        };
      } else {
        String msg = 'Failed to upload avatar';
        if (data != null && data is Map) {
          msg = data['message'] ?? data['error'] ?? msg;
        } else if (response.statusCode == 413) {
          msg = 'Avatar image file is too large (413)';
        } else if (response.statusCode >= 500) {
          msg = 'Server internal error (${response.statusCode})';
        }
        return {
          'success': false,
          'message': msg,
        };
      }
    } catch (e) {
      debugPrint("Upload Exception: $e");
      return {
        'success': false,
        'message': 'Error uploading avatar: $e',
      };
    }
  }

  /// Upload Cover Photo (multipart)
  static Future<Map<String, dynamic>> uploadCover(String filePath) async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.uploadCover);

      final request = http.MultipartRequest('POST', url);
      request.headers.addAll({
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });

      if (File(filePath).existsSync()) {
        request.files.add(await http.MultipartFile.fromPath('cover_photo', filePath));
      } else {
        return {'success': false, 'message': 'Selected file does not exist.'};
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 40));
      final response = await http.Response.fromStream(streamedResponse);
      final data = _safeJsonDecode(response.body);

      if ((response.statusCode == 200 || response.statusCode == 201) && data != null) {
        final userData = data['data']?['user'] ?? data['user'] ?? (data['data'] is Map<String, dynamic> ? data['data'] : null);
        return {
          'success': true,
          'message': data['message'] ?? 'Cover photo uploaded successfully',
          'user': userData,
        };
      } else {
        String msg = 'Failed to upload cover photo';
        if (data != null && data is Map) {
          msg = data['message'] ?? data['error'] ?? msg;
        } else if (response.statusCode == 413) {
          msg = 'Cover photo file is too large (413)';
        } else if (response.statusCode >= 500) {
          msg = 'Server internal error (${response.statusCode})';
        }
        return {
          'success': false,
          'message': msg,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error uploading cover: $e',
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

      final data = _safeJsonDecode(response.body);
      if (response.statusCode == 200 && data != null && (data['status'] == true || data['success'] == true)) {
        return {'success': true, 'message': data['message'] ?? 'Photo deleted'};
      } else {
        String msg = 'Failed to delete photo';
        if (data != null && data is Map) {
          msg = data['message'] ?? data['error'] ?? msg;
        }
        return {'success': false, 'message': msg};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error deleting photo: $e'};
    }
  }

  /// Delete Avatar Photo
  static Future<Map<String, dynamic>> deleteAvatar() async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.deleteAvatar);

      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      final data = _safeJsonDecode(response.body);
      if (response.statusCode == 200 && data != null && (data['status'] == true || data['success'] == true)) {
        return {
          'success': true,
          'message': data['message'] ?? 'Avatar deleted successfully',
          'user': data['data']?['user'] ?? data['user'],
        };
      } else {
        String msg = 'Failed to delete avatar';
        if (data != null && data is Map) {
          msg = data['message'] ?? data['error'] ?? msg;
        }
        return {'success': false, 'message': msg};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error deleting avatar: $e'};
    }
  }

  /// Delete Cover Photo
  static Future<Map<String, dynamic>> deleteCover() async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.deleteCover);

      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      final data = _safeJsonDecode(response.body);
      if (response.statusCode == 200 && data != null && (data['status'] == true || data['success'] == true)) {
        return {
          'success': true,
          'message': data['message'] ?? 'Cover photo deleted successfully',
          'user': data['data']?['user'] ?? data['user'],
        };
      } else {
        String msg = 'Failed to delete cover photo';
        if (data != null && data is Map) {
          msg = data['message'] ?? data['error'] ?? msg;
        }
        return {'success': false, 'message': msg};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error deleting cover photo: $e'};
    }
  }

  /// Update / Reorder entire gallery photo list
  static Future<Map<String, dynamic>> updateGallery(List<String> photos) async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.updateGallery);

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'photos': photos}),
      ).timeout(const Duration(seconds: 10));

      final data = _safeJsonDecode(response.body);
      if (response.statusCode == 200 && data != null && (data['status'] == true || data['success'] == true)) {
        return {
          'success': true,
          'message': data['message'] ?? 'Gallery updated successfully',
          'user': data['data']?['user'] ?? data['user'],
        };
      } else {
        String msg = 'Failed to update gallery';
        if (data != null && data is Map) {
          msg = data['message'] ?? data['error'] ?? msg;
        }
        return {'success': false, 'message': msg};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error updating gallery: $e'};
    }
  }

  /// Clear all gallery photos
  static Future<Map<String, dynamic>> clearGallery() async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.clearGallery);

      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      final data = _safeJsonDecode(response.body);
      if (response.statusCode == 200 && data != null && (data['status'] == true || data['success'] == true)) {
        return {
          'success': true,
          'message': data['message'] ?? 'Gallery cleared successfully',
          'user': data['data']?['user'] ?? data['user'],
        };
      } else {
        String msg = 'Failed to clear gallery';
        if (data != null && data is Map) {
          msg = data['message'] ?? data['error'] ?? msg;
        }
        return {'success': false, 'message': msg};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error clearing gallery: $e'};
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
        final data = _safeJsonDecode(response.body);
        return data != null && (data['status'] == true || data['success'] == true);
      }
    } catch (_) {}
    return false;
  }

  /// Record profile view and trigger automated host greeting / callback
  static Future<Map<String, dynamic>?> recordProfileView(dynamic hostId) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final viewerId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.profileView(hostId));

      final payload = {
        'host_id': hostId,
        if (viewerId != null) 'viewer_id': viewerId,
        if (viewerId != null) 'user_id': viewerId,
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          if (viewerId != null) 'X-User-Id': viewerId,
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = _safeJsonDecode(response.body);
        if (data != null && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('[ProfileApiService] recordProfileView error: $e');
    }
    return null;
  }
}

