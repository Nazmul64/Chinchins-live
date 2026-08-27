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
            final list = List<Map<String, dynamic>>.from(data['data']);
            if (list.isNotEmpty) {
              return list;
            }
          }
        } catch (e, st) {
          AppLogger.error('CoinPackagesParse', e, st);
        }
      }
    } catch (e, st) {
      AppLogger.error('CoinPackages', e, st);
    }

    // Default fallback packages if database is being seeded
    return [
      {
        'id': 1,
        'coins': 6000,
        'bonus_coins': 1000,
        'total_coins': 7000,
        'price': 120.0,
        'price_bdt': 120.0,
        'formatted_price': '৳120',
        'badge': 'Starter',
        'badge_color': 'purple',
        'bonus_text': '+1,000 Bonus',
        'is_popular': false,
        'button_text': 'Recharge 7,000 Gems (৳120)',
      },
      {
        'id': 2,
        'coins': 32000,
        'bonus_coins': 8000,
        'total_coins': 40000,
        'price': 550.0,
        'price_bdt': 550.0,
        'formatted_price': '৳550',
        'badge': '🔥 Popular',
        'badge_color': 'pink',
        'bonus_text': '+8,000 Bonus',
        'is_popular': true,
        'button_text': 'Recharge 40,000 Gems (৳550)',
      },
      {
        'id': 3,
        'coins': 65000,
        'bonus_coins': 20000,
        'total_coins': 85000,
        'price': 1100.0,
        'price_bdt': 1100.0,
        'formatted_price': '৳1,100',
        'badge': '⭐ Best Value',
        'badge_color': 'amber',
        'bonus_text': '+20,000 Bonus',
        'is_popular': false,
        'button_text': 'Recharge 85,000 Gems (৳1,100)',
      },
      {
        'id': 4,
        'coins': 150000,
        'bonus_coins': 50000,
        'total_coins': 200000,
        'price': 2500.0,
        'price_bdt': 2500.0,
        'formatted_price': '৳2,500',
        'badge': '👑 VIP Pack',
        'badge_color': 'cyan',
        'bonus_text': '+50,000 Bonus',
        'is_popular': false,
        'button_text': 'Recharge 200,000 Gems (৳2,500)',
      },
    ];
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
