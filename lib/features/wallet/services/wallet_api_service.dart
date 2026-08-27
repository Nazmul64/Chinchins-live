import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/services/auth_api_service.dart';

class WalletApiService {
  /// 1. Get Wallet Balance, Total Deposited Coins, BDT Spent & Call Minutes
  static Future<Map<String, dynamic>?> getWalletBalance() async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.walletBalance);
      final headers = <String, String>{'Accept': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';
      if (userId != null) headers['X-User-Id'] = userId;

      AppLogger.request(
        method: 'GET',
        url: url.toString(),
        headers: headers,
      );

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      AppLogger.response(
        method: 'GET',
        url: url.toString(),
        statusCode: response.statusCode,
        body: response.body,
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['status'] == true && data['data'] != null) {
            return data['data'] as Map<String, dynamic>;
          }
        } catch (e, st) {
          AppLogger.error('WalletBalanceParse', e, st);
        }
      }
    } catch (e, st) {
      AppLogger.error('WalletBalance', e, st);
    }
    return null;
  }

  /// 2. Get Active Payment Methods (bKash, Nagad, Rocket, Upay)
  static Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.paymentMethods);
      final headers = <String, String>{'Accept': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';
      if (userId != null) headers['X-User-Id'] = userId;

      AppLogger.request(
        method: 'GET',
        url: url.toString(),
        headers: headers,
      );

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      AppLogger.response(
        method: 'GET',
        url: url.toString(),
        statusCode: response.statusCode,
        body: response.body,
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['status'] == true && data['data'] is List) {
            return List<Map<String, dynamic>>.from(data['data']);
          }
        } catch (e, st) {
          AppLogger.error('PaymentMethodsParse', e, st);
        }
      }
    } catch (e, st) {
      AppLogger.error('PaymentMethods', e, st);
    }
    return [];
  }

  /// 3. Get Coin Recharge Packages with Bonus Gems & Prices
  static Future<List<Map<String, dynamic>>> getCoinPackages() async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.coinPackages);
      final headers = <String, String>{'Accept': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';
      if (userId != null) headers['X-User-Id'] = userId;

      AppLogger.request(
        method: 'GET',
        url: url.toString(),
        headers: headers,
      );

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      AppLogger.response(
        method: 'GET',
        url: url.toString(),
        statusCode: response.statusCode,
        body: response.body,
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['status'] == true && data['data'] is List) {
            return List<Map<String, dynamic>>.from(data['data']);
          }
        } catch (e, st) {
          AppLogger.error('CoinPackagesParse', e, st);
        }
      }
    } catch (e, st) {
      AppLogger.error('CoinPackages', e, st);
    }
    return [];
  }

  /// 4. Submit Manual Deposit / Recharge Request (bKash / Nagad / Rocket TrxID + Receipt)
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
    String? customToken,
  }) async {
    try {
      final token = customToken ?? await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.depositRequest);
      final request = http.MultipartRequest('POST', url);

      request.headers['Accept'] = 'application/json';
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      if (userId != null) {
        request.headers['X-User-Id'] = userId;
        request.fields['user_id'] = userId;
      }

      request.fields['payment_method'] = paymentMethod ?? 'bkash';
      if (paymentMethodId != null) {
        request.fields['payment_method_id'] = paymentMethodId.toString();
      }
      request.fields['sender_number'] = senderNumber;
      request.fields['transaction_id'] = transactionId;
      request.fields['amount'] = amount.toString();
      if (coins != null) {
        request.fields['coins'] = coins.toString();
      }
      if (packageId != null) {
        request.fields['package_id'] = packageId.toString();
      }
      if (userNote != null && userNote.isNotEmpty) {
        request.fields['user_note'] = userNote;
      }

      final filesList = <String>[];
      if (screenshot != null) {
        request.files.add(await http.MultipartFile.fromPath('screenshot', screenshot.path));
        filesList.add('screenshot (${(await screenshot.length()) ~/ 1024} KB)');
      }

      AppLogger.request(
        method: 'POST [Deposit Submit]',
        url: url.toString(),
        headers: request.headers,
        fields: request.fields,
        files: filesList,
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 40));
      final response = await http.Response.fromStream(streamedResponse);

      AppLogger.response(
        method: 'POST',
        url: url.toString(),
        statusCode: response.statusCode,
        body: response.body,
      );

      Map<String, dynamic> decoded = {};
      try {
        final raw = jsonDecode(response.body);
        if (raw is Map<String, dynamic>) {
          decoded = raw;
        }
      } catch (e) {
        AppLogger.error('DepositSubmitDecodeError', 'Invalid server response: ${response.body}');
        return {
          'success': false,
          'message': 'Server response (${response.statusCode}): ${response.body.length > 80 ? response.body.substring(0, 80) : response.body}',
        };
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Deposit request submitted successfully! Coins will be credited after admin review.',
          'data': decoded['data'],
        };
      } else {
        String errorMsg = decoded['message'] ?? 'Failed to submit deposit (${response.statusCode})';
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
    } catch (e, st) {
      AppLogger.error('DepositSubmitException', e, st);
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  /// 5. Get User's Deposit History (with status badges & admin notes)
  static Future<List<Map<String, dynamic>>> getDepositHistory({int page = 1}) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse('${ApiConstants.depositHistory}?page=$page');
      final headers = <String, String>{'Accept': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';
      if (userId != null) headers['X-User-Id'] = userId;

      AppLogger.request(
        method: 'GET',
        url: url.toString(),
        headers: headers,
      );

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      AppLogger.response(
        method: 'GET',
        url: url.toString(),
        statusCode: response.statusCode,
        body: response.body,
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['status'] == true && data['data'] != null) {
            if (data['data'] is List) {
              return List<Map<String, dynamic>>.from(data['data']);
            }
            if (data['data'] is Map && data['data']['data'] is List) {
              return List<Map<String, dynamic>>.from(data['data']['data']);
            }
          }
        } catch (e, st) {
          AppLogger.error('DepositHistoryParse', e, st);
        }
      }
    } catch (e, st) {
      AppLogger.error('DepositHistory', e, st);
    }
    return [];
  }
}
