import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../auth/services/auth_api_service.dart';

class KycApiService {
  /// Fetch supported KYC documents, requirements & AI face liveness guidelines
  static Future<Map<String, dynamic>> getInstructions() async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.kycInstructions);
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        }
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
      'ai_liveness_guidelines': {
        'lighting': 'Ensure your room is well-lit without direct glare or shadows on your face or document.',
        'face_orientation': {
          'step_1': 'Look straight into the camera at eye level.',
          'step_2': 'Turn your head slightly to the left when prompted.',
          'step_3': 'Turn your head slightly to the right when prompted.',
          'step_4': 'Blink naturally or smile to verify live human presence.',
        },
        'rules': [
          'No sunglasses, hats, masks, or filters allowed.',
          'All four corners of the identity card/document must be visible.',
          'Text and dates on the document must be sharp, legible, and unblurred.',
          'Selfie face must match the face on the identity document.',
        ]
      }
    };
  }

  /// Get current user's KYC verification status, latest submission, and badge
  static Future<Map<String, dynamic>?> getKycStatus([String? customToken]) async {
    try {
      final token = customToken ?? await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.kycStatus);
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
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
      }
    } catch (_) {}
    return null;
  }

  /// Submit full KYC verification with multi-angle face verification (Center, Left, Right, Blink)
  static Future<Map<String, dynamic>> submitKyc({
    required String documentType,
    required String fullName,
    required String documentNumber,
    required String dateOfBirth, // YYYY-MM-DD
    required File frontImage,
    File? backImage,
    required File selfieImage,
    File? faceLeftImage,
    File? faceRightImage,
    File? faceBlinkImage,
    Map<String, dynamic>? livenessData,
    String? userNotes,
    String? customToken,
  }) async {
    try {
      final token = customToken ?? await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.kycSubmit);
      final request = http.MultipartRequest('POST', url);

      request.headers['Accept'] = 'application/json';
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Text Fields
      request.fields['document_type'] = documentType;
      request.fields['full_name'] = fullName;
      request.fields['document_number'] = documentNumber;
      request.fields['date_of_birth'] = dateOfBirth;
      request.fields['dob'] = dateOfBirth;

      if (livenessData != null) {
        request.fields['liveness_data'] = jsonEncode(livenessData);
      }
      if (userNotes != null && userNotes.isNotEmpty) {
        request.fields['user_notes'] = userNotes;
      }

      // Document Files
      request.files.add(await http.MultipartFile.fromPath('front_image', frontImage.path));
      if (backImage != null) {
        request.files.add(await http.MultipartFile.fromPath('back_image', backImage.path));
      }

      // Multi-Angle Face Files
      request.files.add(await http.MultipartFile.fromPath('selfie_image', selfieImage.path));
      if (faceLeftImage != null) {
        request.files.add(await http.MultipartFile.fromPath('face_left_image', faceLeftImage.path));
      }
      if (faceRightImage != null) {
        request.files.add(await http.MultipartFile.fromPath('face_right_image', faceRightImage.path));
      }
      if (faceBlinkImage != null) {
        request.files.add(await http.MultipartFile.fromPath('face_blink_image', faceBlinkImage.path));
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 50));
      final response = await http.Response.fromStream(streamedResponse);

      final decoded = jsonDecode(response.body);
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
        return {
          'success': false,
          'message': decoded['message'] ?? 'Failed to submit KYC verification (${response.statusCode})',
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

  /// Real-time AI Face Step Verification ('center' | 'turn_left' | 'turn_right' | 'blink')
  static Future<Map<String, dynamic>> verifyFaceStep({
    required String step,
    required File frameImage,
    String? customToken,
  }) async {
    try {
      final token = customToken ?? await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.kycFaceVerifyStep);
      final request = http.MultipartRequest('POST', url);

      request.headers['Accept'] = 'application/json';
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['step'] = step;
      request.files.add(await http.MultipartFile.fromPath('image', frameImage.path));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamedResponse);

      final decoded = jsonDecode(response.body);
      return decoded as Map<String, dynamic>;
    } catch (e) {
      return {
        'status': false,
        'message': 'Face step check error: ${e.toString()}',
      };
    }
  }

  /// Biometric AI Face Re-Unlock for Blocked / Suspended Accounts
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

      final decoded = jsonDecode(response.body);
      return decoded as Map<String, dynamic>;
    } catch (e) {
      return {
        'status': false,
        'message': 'Account unlock error: ${e.toString()}',
      };
    }
  }

  /// AI Pre-check for face quality, liveness & document legibility
  static Future<Map<String, dynamic>?> aiDetect({
    required File frontImage,
    required File selfieImage,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.kycAiDetect);
      final request = http.MultipartRequest('POST', url);

      request.headers['Accept'] = 'application/json';
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(await http.MultipartFile.fromPath('front_image', frontImage.path));
      request.files.add(await http.MultipartFile.fromPath('selfie_image', selfieImage.path));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 25));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return null;
  }

  /// 5. Live Video Face Scan & Circular Progress Processing (0% -> 25% -> 50% -> 75% -> 100%)
  static Future<Map<String, dynamic>> uploadVideoVerify({
    required File videoFile,
    String? customToken,
  }) async {
    try {
      final token = customToken ?? await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.kycVideoVerify);
      final request = http.MultipartRequest('POST', url);

      request.headers['Accept'] = 'application/json';
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(await http.MultipartFile.fromPath('video', videoFile.path));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      final decoded = jsonDecode(response.body);
      return decoded as Map<String, dynamic>;
    } catch (e) {
      return {
        'status': false,
        'message': 'Video face scan error: ${e.toString()}',
      };
    }
  }
}

