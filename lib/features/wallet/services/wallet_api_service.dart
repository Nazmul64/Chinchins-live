import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../auth/services/auth_api_service.dart';

class WalletApiService {
  /// Fetch user's current wallet balance
  static Future<Map<String, dynamic>?> getWalletBalance() async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.walletBalance);
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
    return null;
  }

  /// Fetch active payment methods from database
  static Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.paymentMethods);
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (_) {}
    return [];
  }

  /// Fetch coin pricing packages directly from database via GET /api/coin-packages
  static Future<List<Map<String, dynamic>>> getCoinPackages() async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.coinPackages);
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] is List) {
          final list = List<Map<String, dynamic>>.from(data['data']);
          if (list.isNotEmpty) {
            return list;
          }
        }
      }
    } catch (_) {}

    // Fallback: try payment-methods if coin-packages is empty
    try {
      final pmList = await getPaymentMethods();
      if (pmList.isNotEmpty) {
        return pmList;
      }
    } catch (_) {}

    return [];
  }

  /// Submit manual deposit request with screenshot proof
  static Future<Map<String, dynamic>> submitDepositRequest({
    int? packageId,
    int? paymentMethodId,
    String? paymentMethod,
    required double amount,
    int? coins,
    required String senderNumber,
    required String transactionId,
    File? screenshot,
    String? userNote,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.depositRequest);
      final request = http.MultipartRequest('POST', url);

      request.headers['Accept'] = 'application/json';
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      if (packageId != null) {
        request.fields['package_id'] = packageId.toString();
      }
      if (paymentMethodId != null) {
        request.fields['payment_method_id'] = paymentMethodId.toString();
      }
      if (paymentMethod != null) {
        request.fields['payment_method'] = paymentMethod;
      }
      request.fields['amount'] = amount.toString();
      if (coins != null) {
        request.fields['coins'] = coins.toString();
      }
      request.fields['sender_number'] = senderNumber.trim();
      request.fields['transaction_id'] = transactionId.trim().toUpperCase();
      if (userNote != null && userNote.trim().isNotEmpty) {
        request.fields['user_note'] = userNote.trim();
      }

      if (screenshot != null && await screenshot.exists()) {
        request.files.add(
          await http.MultipartFile.fromPath('screenshot', screenshot.path),
        );
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 25));
      final response = await http.Response.fromStream(streamedResponse);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201 || (data is Map && data['status'] == true)) {
        return {
          'success': true,
          'message': (data is Map && data['message'] != null)
              ? data['message']
              : 'Deposit request submitted successfully! Your coins will be credited once verified by admin.',
          'data': data is Map ? data['data'] : null,
        };
      } else {
        return {
          'success': false,
          'message': (data is Map && data['message'] != null) ? data['message'] : 'Failed to submit deposit request.',
          'errors': data is Map ? data['errors'] : null,
        };
      }
    } on SocketException {
      return {
        'success': false,
        'message': 'Cannot connect to server. Please check internet connection.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error submitting deposit: $e',
      };
    }
  }

  /// Get Deposit History
  static Future<List<Map<String, dynamic>>> getDepositHistory() async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.depositHistory);
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (_) {}
    return [];
  }
}
