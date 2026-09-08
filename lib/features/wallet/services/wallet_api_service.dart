import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../core/services/fast_api_client.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/services/auth_api_service.dart';

class WalletApiService {
  static Map<String, dynamic>? _cachedBalance;
  static List<Map<String, dynamic>> _cachedPackages = [];
  static List<Map<String, dynamic>> _cachedPaymentMethods = [];

  /// Instant Synchronous Coin Balance Lookup (0.00ms delay)
  static int getCachedCoins() {
    if (_cachedBalance != null) {
      final c = _cachedBalance!['coins'] ?? _cachedBalance!['balance'] ?? _cachedBalance!['gems'];
      if (c is num) return c.toInt();
      if (c != null) return int.tryParse('$c') ?? 0;
    }
    final syncData = FastApiClient.getCachedSync(ApiConstants.walletBalance);
    if (syncData is Map) {
      final d = syncData['data'] ?? syncData;
      if (d is Map) {
        final c = d['coins'] ?? d['balance'] ?? d['gems'];
        if (c is num) return c.toInt();
        if (c != null) return int.tryParse('$c') ?? 0;
      }
    }
    return 0;
  }

  /// 1. Get Wallet Balance, Total Deposited Coins, BDT Spent & Call Minutes (Instant L1/L2 SWR)
  static Future<Map<String, dynamic>?> getWalletBalance({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedBalance != null) {
      // Revalidate in background
      _syncWalletBalanceInBackground();
      return _cachedBalance;
    }

    final localCached = await FastApiClient.getCached(ApiConstants.walletBalance);
    if (localCached is Map && localCached['status'] == true && localCached['data'] != null) {
      _cachedBalance = Map<String, dynamic>.from(localCached['data']);
      _syncWalletBalanceInBackground();
      return _cachedBalance;
    }

    return await _syncWalletBalanceInBackground();
  }

  static Future<Map<String, dynamic>?> _syncWalletBalanceInBackground() async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.walletBalance);
      final headers = <String, String>{'Accept': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';
      if (userId != null) headers['X-User-Id'] = userId;

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] != null) {
          await FastApiClient.putCache(ApiConstants.walletBalance, data);
          _cachedBalance = Map<String, dynamic>.from(data['data']);
          return _cachedBalance;
        }
      }
    } catch (e, st) {
      AppLogger.error('WalletBalance', e, st);
    }
    return _cachedBalance;
  }

  /// 2. Get Active Payment Methods (bKash, Nagad, Rocket, Upay) - Instant SWR
  static Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    if (_cachedPaymentMethods.isNotEmpty) {
      _syncPaymentMethodsInBackground();
      return _cachedPaymentMethods;
    }

    final cached = await FastApiClient.getCached(ApiConstants.paymentMethods);
    if (cached is Map && cached['status'] == true && cached['data'] is List) {
      _cachedPaymentMethods = List<Map<String, dynamic>>.from(cached['data']);
      _syncPaymentMethodsInBackground();
      return _cachedPaymentMethods;
    }

    return await _syncPaymentMethodsInBackground();
  }

  static Future<List<Map<String, dynamic>>> _syncPaymentMethodsInBackground() async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.paymentMethods);
      final headers = <String, String>{'Accept': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';
      if (userId != null) headers['X-User-Id'] = userId;

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] is List) {
          await FastApiClient.putCache(ApiConstants.paymentMethods, data);
          _cachedPaymentMethods = List<Map<String, dynamic>>.from(data['data']);
          return _cachedPaymentMethods;
        }
      }
    } catch (e, st) {
      AppLogger.error('PaymentMethods', e, st);
    }
    return _cachedPaymentMethods;
  }

  /// 3. Get Coin Recharge Packages with Bonus Gems & Prices (Instant SWR + RAM Memoization)
  static Future<List<Map<String, dynamic>>> getCoinPackages() async {
    if (_cachedPackages.isNotEmpty) {
      _syncCoinPackagesInBackground();
      return _cachedPackages;
    }

    final cached = await FastApiClient.getCached(ApiConstants.coinPackages);
    if (cached is Map && cached['status'] == true && cached['data'] is List && (cached['data'] as List).isNotEmpty) {
      _cachedPackages = List<Map<String, dynamic>>.from(cached['data']);
      _syncCoinPackagesInBackground();
      return _cachedPackages;
    }

    final livePackages = await _syncCoinPackagesInBackground();
    if (livePackages.isNotEmpty) {
      return livePackages;
    }

    return _getDefaultPackagesFallback();
  }

  static Future<List<Map<String, dynamic>>> _syncCoinPackagesInBackground() async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.coinPackages);
      final headers = <String, String>{'Accept': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';
      if (userId != null) headers['X-User-Id'] = userId;

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] is List && (data['data'] as List).isNotEmpty) {
          await FastApiClient.putCache(ApiConstants.coinPackages, data);
          _cachedPackages = List<Map<String, dynamic>>.from(data['data']);
          return _cachedPackages;
        }
      }
    } catch (e, st) {
      AppLogger.error('CoinPackages', e, st);
    }
    return _cachedPackages;
  }

  /// 4. Get In-Chat/In-Call Recharge Modal Data with SWR (Receiver info, dynamic header, packages, balance)
  static Future<Map<String, dynamic>?> getRechargeModalData({
    dynamic receiverId,
    String action = 'chat',
    bool forceRefresh = false,
  }) async {
    final queryParams = <String, dynamic>{
      if (receiverId != null) 'receiver_id': receiverId,
      'action': action,
    };

    final localCached = await FastApiClient.getCached(ApiConstants.rechargeModalData, queryParams);
    if (!forceRefresh && localCached is Map) {
      final cachedModal = localCached['recharge_modal_data'] ?? localCached['data'] ?? localCached['modal'];
      if (cachedModal is Map) {
        _syncRechargeModalDataInBackground(queryParams);
        return Map<String, dynamic>.from(cachedModal);
      }
    }

    final liveModal = await _syncRechargeModalDataInBackground(queryParams);
    if (liveModal != null) {
      return liveModal;
    }

    if (localCached is Map) {
      final cachedModal = localCached['recharge_modal_data'] ?? localCached['data'] ?? localCached['modal'];
      if (cachedModal is Map) {
        return Map<String, dynamic>.from(cachedModal);
      }
    }

    return null;
  }

  static Future<Map<String, dynamic>?> _syncRechargeModalDataInBackground(Map<String, dynamic> queryParams) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      Uri uri = Uri.parse(ApiConstants.rechargeModalData).replace(
        queryParameters: queryParams.map((k, v) => MapEntry(k, v.toString())),
      );

      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      };

      var response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 6));

      if (response.statusCode == 404) {
        // Fallback to alias endpoint
        uri = Uri.parse(ApiConstants.coinPackagesRechargeModal).replace(
          queryParameters: queryParams.map((k, v) => MapEntry(k, v.toString())),
        );
        response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 6));
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final modalMap = decoded['recharge_modal_data'] ?? decoded['data'] ?? decoded['modal'] ?? decoded;
          if (modalMap is Map) {
            await FastApiClient.putCache(ApiConstants.rechargeModalData, decoded, queryParams);
            return Map<String, dynamic>.from(modalMap);
          }
        }
      }
    } catch (e, st) {
      AppLogger.error('RechargeModalDataSyncError', e, st);
    }
    return null;
  }

  static List<Map<String, dynamic>> _getDefaultPackagesFallback() {
    return [
      {
        'id': 1,
        'name': 'Starter Pack',
        'coins': 7560,
        'bonus_coins': 0,
        'total_coins': 7560,
        'price': 150.0,
        'price_bdt': 150.0,
        'badge': '50% OFF',
      },
      {
        'id': 2,
        'name': 'Basic Pack',
        'coins': 8100,
        'bonus_coins': 0,
        'total_coins': 8100,
        'price': 300.0,
        'price_bdt': 300.0,
        'badge': '17% OFF',
      },
      {
        'id': 3,
        'name': 'Popular Pack',
        'coins': 16380,
        'bonus_coins': 1000,
        'total_coins': 17380,
        'price': 600.0,
        'price_bdt': 600.0,
        'badge': 'POPULAR',
      },
      {
        'id': 4,
        'name': 'Super Pack',
        'coins': 32940,
        'bonus_coins': 3000,
        'total_coins': 35940,
        'price': 1200.0,
        'price_bdt': 1200.0,
        'badge': '30% OFF',
      },
      {
        'id': 5,
        'name': 'Mega Pack',
        'coins': 66600,
        'bonus_coins': 8000,
        'total_coins': 74600,
        'price': 2400.0,
        'price_bdt': 2400.0,
        'badge': '60% OFF',
      },
      {
        'id': 6,
        'name': 'VIP King Pack',
        'coins': 167400,
        'bonus_coins': 25000,
        'total_coins': 192400,
        'price': 6100.0,
        'price_bdt': 6100.0,
        'badge': '80% OFF',
      },
      {
        'id': 7,
        'name': 'Whale Sovereign',
        'coins': 500000,
        'bonus_coins': 100000,
        'total_coins': 600000,
        'price': 18000.0,
        'price_bdt': 18000.0,
        'badge': 'KING DEAL',
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

      final url = Uri.parse(ApiConstants.depositSubmit);
      final request = http.MultipartRequest('POST', url);

      request.headers['Accept'] = 'application/json';
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      if (userId != null) {
        request.headers['X-User-Id'] = userId;
        request.fields['user_id'] = userId;
      }

      // Format payment method code (e.g. 'bkash', 'nagad', 'rocket', 'upay')
      String methodCode = (paymentMethod ?? 'bkash').toLowerCase().trim();
      if (methodCode.contains('bkash')) {
        methodCode = 'bkash';
      } else if (methodCode.contains('nagad')) {
        methodCode = 'nagad';
      } else if (methodCode.contains('rocket')) {
        methodCode = 'rocket';
      } else if (methodCode.contains('upay')) {
        methodCode = 'upay';
      }

      request.fields['payment_method'] = methodCode;
      if (paymentMethodId != null) {
        request.fields['payment_method_id'] = paymentMethodId.toString();
      }
      request.fields['sender_number'] = senderNumber.trim();
      request.fields['transaction_id'] = transactionId.trim().toUpperCase();

      final amountStr = amount == amount.roundToDouble() ? amount.toInt().toString() : amount.toStringAsFixed(2);
      request.fields['amount'] = amountStr;

      if (coins != null && coins > 0) {
        request.fields['coins'] = coins.toString();
      }
      if (packageId != null) {
        request.fields['package_id'] = packageId.toString();
      }
      if (userNote != null && userNote.trim().isNotEmpty) {
        request.fields['user_note'] = userNote.trim();
      }

      final filesList = <String>[];
      if (screenshot != null && screenshot.existsSync()) {
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
          'message': 'Server response (${response.statusCode}): ${response.body.length > 100 ? response.body.substring(0, 100) : response.body}',
        };
      }

      final isSuccess = response.statusCode == 200 ||
          response.statusCode == 201 ||
          decoded['status'] == true ||
          decoded['status'] == 'success';

      if (isSuccess) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Deposit request submitted successfully! Your coins will be credited once verified by admin.',
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

  /// 6. Get User's Full Wallet Transaction Ledger (Calls, Gifts, Deposits)
  static Future<List<Map<String, dynamic>>> getWalletTransactions({int page = 1}) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse('${ApiConstants.walletTransactions}?page=$page');
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
          AppLogger.error('WalletTransactionsParse', e, st);
        }
      }
    } catch (e, st) {
      AppLogger.error('WalletTransactions', e, st);
    }
    return [];
  }
}
