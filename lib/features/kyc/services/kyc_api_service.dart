import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../auth/services/auth_api_service.dart';

class KycApiService {
  /// 1. Fetch supported KYC documents, requirements & guidelines
  static Future<Map<String, dynamic>> getInstructions() async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.kycInstructions);
      final headers = <String, String>{'Accept': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';
      if (userId != null) headers['X-User-Id'] = userId;

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['status'] == true && data['data'] != null) {
            return data['data'] as Map<String, dynamic>;
          }
        } catch (_) {}
      }
    } catch (_) {}

    // Fallback default guidelines according to specification
    return {
      'supported_documents': [
        {
          'type': 'nid',
          'title': 'National ID Card (NID)',
          'description': 'Official Government National Identity Card.',
          'required_fields': [
            'full_name',
            'document_number',
            'date_of_birth',
            'front_image',
            'back_image',
            'selfie_image',
          ],
          'front_part_guide': 'Clear, glare-free photo of the front side of your NID Card with photo and name visible.',
          'back_part_guide': 'Clear photo of the back side of your NID Card with address and barcode visible.',
          'selfie_guide': 'Take a clear selfie holding your NID card close to your chest/face without blocking your face.',
        },
        {
          'type': 'passport',
          'title': 'International Passport',
          'description': 'Valid government-issued international travel passport.',
          'required_fields': [
            'full_name',
            'document_number',
            'date_of_birth',
            'front_image',
            'selfie_image',
          ],
          'front_part_guide': 'High-resolution photo or screenshot of the main bio-data page (with photo, MRZ code and passport number).',
          'back_part_guide': 'Optional for passport.',
          'selfie_guide': 'Take a selfie holding your open passport bio-data page clearly visible.',
        },
        {
          'type': 'birth_certificate',
          'title': 'Birth Certificate (জন্ম নিবন্ধন)',
          'description': 'Official 17-digit Online Birth Registration Certificate.',
          'required_fields': [
            'full_name',
            'document_number',
            'date_of_birth',
            'front_image',
            'selfie_image',
          ],
          'front_part_guide': 'Clear photo or digital screenshot of the full birth certificate document.',
          'back_part_guide': 'Optional.',
          'selfie_guide': 'Take a selfie holding the birth certificate document clearly.',
        }
      ],
      'photo_guidelines': {
        'lighting': 'Ensure your room is well-lit without direct glare or shadows on your face or document.',
        'rules': [
          'No sunglasses, hats, masks, or beauty filters allowed.',
          'All four corners of the identity document must be visible.',
          'Text and dates on the document must be sharp, legible, and unblurred.',
          'Selfie face must match the photo on the identity document.',
        ]
      }
    };
  }

  /// 2. Submit Clean KYC Verification (Front Image, Back Image, 1 Single Selfie)
  static Future<Map<String, dynamic>> submitKyc({
    required String documentType,
    required String fullName,
    required String documentNumber,
    required String dateOfBirth, // YYYY-MM-DD
    required File frontImage,
    File? backImage,
    required File selfieImage,
    String? userNotes,
    String? customToken,
  }) async {
    try {
      final token = customToken ?? await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.kycSubmit);
      final request = http.MultipartRequest('POST', url);

      request.headers['Accept'] = 'application/json';
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      if (userId != null) {
        request.headers['X-User-Id'] = userId;
        request.fields['user_id'] = userId;
      }

      // Text Fields
      request.fields['document_type'] = documentType;
      request.fields['full_name'] = fullName;
      request.fields['document_number'] = documentNumber;
      request.fields['date_of_birth'] = dateOfBirth;
      request.fields['dob'] = dateOfBirth;

      if (userNotes != null && userNotes.isNotEmpty) {
        request.fields['user_notes'] = userNotes;
      }

      // Attach Document Images
      request.files.add(await http.MultipartFile.fromPath('front_image', frontImage.path));
      if (backImage != null) {
        request.files.add(await http.MultipartFile.fromPath('back_image', backImage.path));
      }

      // Attach 1 Single Selfie Photo
      request.files.add(await http.MultipartFile.fromPath('selfie_image', selfieImage.path));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse);

      // Safe JSON decode
      Map<String, dynamic> decoded = {};
      try {
        final raw = jsonDecode(response.body);
        if (raw is Map<String, dynamic>) {
          decoded = raw;
        }
      } catch (_) {
        if (response.statusCode == 413) {
          return {
            'success': false,
            'message': 'Image files are too large. Please retake standard resolution photos.',
          };
        }
        if (response.statusCode == 401 || response.statusCode == 419) {
          return {
            'success': false,
            'message': 'Authentication session expired. Please log in again.',
          };
        }
        return {
          'success': false,
          'message': 'Server response code ${response.statusCode}. Please try again.',
        };
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('kyc_verification_status', 'pending');
        await prefs.setString('kyc_legal_name', fullName);
        await prefs.setString('kyc_doc_number', documentNumber);
        await prefs.setString('kyc_doc_type', documentType);
        return {
          'success': true,
          'message': decoded['message'] ?? 'KYC verification submitted successfully.',
          'data': decoded['data'],
        };
      } else {
        String errorMsg = decoded['message'] ?? 'Failed to submit KYC verification (${response.statusCode})';
        if (decoded['errors'] is Map) {
          final errMap = decoded['errors'] as Map;
          final firstKey = errMap.keys.firstOrNull;
          if (firstKey != null && errMap[firstKey] is List && (errMap[firstKey] as List).isNotEmpty) {
            errorMsg = (errMap[firstKey] as List).first.toString();
          }
        }
        return {
          'success': false,
          'message': errorMsg,
          'errors': decoded['errors'],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  /// 3. Get current KYC Status & Verified state
  static Future<Map<String, dynamic>?> getKycStatus([String? customToken]) async {
    try {
      final token = customToken ?? await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.kycStatus);
      final headers = <String, String>{'Accept': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';
      if (userId != null) headers['X-User-Id'] = userId;

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['status'] == true && data['data'] != null) {
            final kycData = data['data'] as Map<String, dynamic>;
            final prefs = await SharedPreferences.getInstance();
            final status = (kycData['kyc_status'] ?? 'unverified').toString().toLowerCase();
            await prefs.setString('kyc_verification_status', status);
            if (kycData['is_verified'] != null) {
              await prefs.setBool('is_verified', kycData['is_verified'] == true || kycData['is_verified'] == 1);
            }
            return kycData;
          }
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }

  /// 4. Biometric Face Re-Unlock for Blocked / Locked Accounts
  static Future<Map<String, dynamic>> unlockAccountWithFace({
    required String accountIdentifier, // phone, email, or account_id
    required File liveFaceImage,
  }) async {
    try {
      final url = Uri.parse(ApiConstants.kycFaceUnlock);
      final request = http.MultipartRequest('POST', url);

      request.headers['Accept'] = 'application/json';
      request.fields['phone'] = accountIdentifier;
      request.fields['account_identifier'] = accountIdentifier;
      request.files.add(await http.MultipartFile.fromPath('image', liveFaceImage.path));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 25));
      final response = await http.Response.fromStream(streamedResponse);

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {}

      return {
        'status': response.statusCode == 200,
        'message': response.statusCode == 200 ? 'Account unlocked successfully!' : 'Unlock request processed.',
      };
    } catch (e) {
      return {
        'status': false,
        'message': 'Account unlock error: ${e.toString()}',
      };
    }
  }

  /// 5. AI Quality & Pre-check (Lighting, blur, face detection)
  static Future<Map<String, dynamic>?> aiDetect({
    required File frontImage,
    required File selfieImage,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.kycAiDetect);
      final request = http.MultipartRequest('POST', url);

      request.headers['Accept'] = 'application/json';
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      if (userId != null) {
        request.headers['X-User-Id'] = userId;
        request.fields['user_id'] = userId;
      }

      request.files.add(await http.MultipartFile.fromPath('front_image', frontImage.path));
      request.files.add(await http.MultipartFile.fromPath('selfie_image', selfieImage.path));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 25));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['status'] == true && data['data'] != null) {
            return data['data'] as Map<String, dynamic>;
          }
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }
}
