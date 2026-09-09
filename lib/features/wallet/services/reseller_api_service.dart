import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/services/auth_api_service.dart';
import '../models/payment_option_model.dart';
import '../models/reseller_chat_message_model.dart';
import '../models/reseller_model.dart';

class ResellerApiService {
  static List<PaymentOption> _cachedOptions = [];
  static List<ResellerModel> _cachedResellers = [];

  /// 1. Get Payment Options (bKash, Nagad, Google Play, Dynamic Resellers)
  static Future<List<PaymentOption>> getPaymentOptions({
    int? packageId,
    double? amount,
    int? coins,
    bool forceRefresh = false,
  }) async {
    final queryParams = <String, String>{
      if (packageId != null) 'package_id': packageId.toString(),
      if (amount != null) 'amount': amount.toString(),
      if (coins != null) 'coins': coins.toString(),
    };

    if (!forceRefresh && _cachedOptions.isNotEmpty) {
      _syncPaymentOptionsInBackground(queryParams);
      return _cachedOptions;
    }

    final liveOptions = await _syncPaymentOptionsInBackground(queryParams);
    if (liveOptions.isNotEmpty) {
      return liveOptions;
    }

    return _cachedOptions.isNotEmpty ? _cachedOptions : _getDefaultPaymentOptionsFallback();
  }

  static Future<List<PaymentOption>> _syncPaymentOptionsInBackground(Map<String, String> queryParams) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      };

      // 1. Check if active resellers exist in database
      final activeResellers = await getResellers(
        coins: queryParams['coins'] != null ? int.tryParse(queryParams['coins']!) : null,
        forceRefresh: true,
      );

      // 2. Try primary /api/payment-options endpoint
      Uri uri = Uri.parse(ApiConstants.paymentOptions);
      if (queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      var response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List? rawList;
        if (decoded is Map) {
          if (decoded['options'] is List) {
            rawList = decoded['options'] as List;
          } else if (decoded['data'] is List) {
            rawList = decoded['data'] as List;
          }
        } else if (decoded is List) {
          rawList = decoded;
        }

        if (rawList != null && rawList.isNotEmpty) {
          final list = rawList
              .map((e) => PaymentOption.fromJson(Map<String, dynamic>.from(e)))
              .toList();

          // Dynamic Reseller filter: If no active resellers in DB, omit reseller option
          if (activeResellers.isEmpty) {
            list.removeWhere((o) => o.isReseller);
          }

          if (list.isNotEmpty) {
            _cachedOptions = list;
            return _cachedOptions;
          }
        }
      }

      // 3. Fallback / Alternative: Fetch direct from admin Payment Gateways (/api/payment-methods)
      final pmResponse = await http
          .get(Uri.parse(ApiConstants.paymentMethods), headers: headers)
          .timeout(const Duration(seconds: 6));

      if (pmResponse.statusCode == 200) {
        final pmDecoded = jsonDecode(pmResponse.body);
        List? gateways;
        if (pmDecoded is Map && pmDecoded['data'] is List) {
          gateways = pmDecoded['data'] as List;
        } else if (pmDecoded is List) {
          gateways = pmDecoded;
        }

        if (gateways != null && gateways.isNotEmpty) {
          final List<PaymentOption> builtOptions = [];

          for (final g in gateways) {
            if (g is Map) {
              final isEnabled = g['is_active'] == true ||
                  g['is_active'] == 1 ||
                  g['status'] == 'active' ||
                  g['status'] == 1 ||
                  g['enabled'] == true;
              if (isEnabled || g['is_active'] == null) {
                builtOptions.add(PaymentOption.fromJson(Map<String, dynamic>.from(g)));
              }
            }
          }

          // Append Google Play option
          builtOptions.add(
            const PaymentOption(
              id: 'google_play',
              key: 'google_play',
              name: 'Google Play',
              type: 'in_app_purchase',
              accountType: 'Official In-App Store',
              icon: 'https://chinchins.live/uploads/payment_methods/google_play.svg',
              badge: null,
              instructions: 'Instant Google Play in-app purchase.',
            ),
          );

          // Append Reseller option only if active resellers exist in DB
          if (activeResellers.isNotEmpty) {
            builtOptions.add(
              PaymentOption(
                id: 'reseller',
                key: 'reseller',
                name: 'Reseller',
                type: 'reseller',
                accountType: 'Direct Agent Chat',
                icon: 'https://chinchins.live/uploads/payment_methods/reseller.svg',
                badge: activeResellers.first.discountTag.isNotEmpty
                    ? activeResellers.first.discountTag
                    : 'Up To 29%↑',
                badgeColor: '#ef4444',
                activeCount: activeResellers.length,
                instructions: 'Recharge via authorized live resellers with exclusive discounts.',
              ),
            );
          }

          if (builtOptions.isNotEmpty) {
            _cachedOptions = builtOptions;
            return _cachedOptions;
          }
        }
      }
    } catch (e, st) {
      AppLogger.error('PaymentOptionsSyncError', e, st);
    }
    return _cachedOptions.isNotEmpty ? _cachedOptions : _getDefaultPaymentOptionsFallback();
  }

  static List<PaymentOption> _getDefaultPaymentOptionsFallback() {
    return [
      const PaymentOption(
        id: 1,
        key: 'bkash',
        name: 'bkash',
        type: 'gateway',
        accountType: 'Personal',
        accountNumber: '01706640777',
        icon: 'https://chinchins.live/uploads/payment_methods/bkash.svg',
        badge: null,
        instructions: 'Send money to our bKash Personal Number: 01706640777.',
      ),
      const PaymentOption(
        id: 2,
        key: 'nagad',
        name: 'Nagad',
        type: 'gateway',
        accountType: 'Personal',
        accountNumber: '01706640777',
        icon: 'https://chinchins.live/uploads/payment_methods/nagad.svg',
        badge: null,
        instructions: 'Send money to our Nagad Personal Number: 01706640777.',
      ),
      const PaymentOption(
        id: 'google_play',
        key: 'google_play',
        name: 'Google Play',
        type: 'in_app_purchase',
        accountType: 'Official In-App Store',
        icon: 'https://chinchins.live/uploads/payment_methods/google_play.svg',
        badge: null,
        instructions: 'Instant Google Play in-app purchase.',
      ),
    ];
  }

  /// 2. Get Authorized Resellers List (100% Dynamic from Database)
  static Future<List<ResellerModel>> getResellers({int? coins, bool forceRefresh = false}) async {
    final queryParams = <String, String>{
      if (coins != null) 'coins': coins.toString(),
    };

    if (!forceRefresh && _cachedResellers.isNotEmpty) {
      _syncResellersInBackground(queryParams);
      return _cachedResellers;
    }

    final liveList = await _syncResellersInBackground(queryParams);
    return liveList;
  }

  static Future<List<ResellerModel>> _syncResellersInBackground(Map<String, String> queryParams) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      Uri uri = Uri.parse(ApiConstants.resellers);
      if (queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      };

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['data'] is List) {
          final list = (decoded['data'] as List)
              .map((e) => ResellerModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _cachedResellers = list;
          return list;
        }
      }
    } catch (e, st) {
      AppLogger.error('ResellersSyncError', e, st);
    }
    return _cachedResellers;
  }

  /// 3. Fetch 1-on-1 Chat History with Reseller
  static Future<List<ResellerChatMessage>> getChatMessages(int resellerId) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final currentUserId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final uri = Uri.parse(ApiConstants.resellerMessages(resellerId));
      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (currentUserId != null) 'X-User-Id': currentUserId,
      };

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['data'] is List) {
          final list = (decoded['data'] as List)
              .map((e) => ResellerChatMessage.fromJson(Map<String, dynamic>.from(e), currentUserId: currentUserId))
              .toList();
          return list;
        }
      }
    } catch (e, st) {
      AppLogger.error('ResellerChatMessagesError', e, st);
    }
    return [];
  }

  /// 4. Send Message (Text, Screenshot/Image, Voice Note) to Reseller
  static Future<ResellerChatMessage?> sendMessage({
    required int resellerId,
    String? message,
    String type = 'text',
    File? imageFile,
    File? audioFile,
    int? duration,
    int? coinsAmount,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final currentUserId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final uri = Uri.parse(ApiConstants.resellerChatSend);
      final request = http.MultipartRequest('POST', uri);

      request.headers['Accept'] = 'application/json';
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      if (currentUserId != null) request.headers['X-User-Id'] = currentUserId;

      request.fields['reseller_id'] = resellerId.toString();
      request.fields['type'] = type;
      if (message != null && message.trim().isNotEmpty) {
        request.fields['message'] = message.trim();
      }
      if (duration != null) {
        request.fields['duration'] = duration.toString();
      }
      if (coinsAmount != null) {
        request.fields['coins_amount'] = coinsAmount.toString();
      }

      if (imageFile != null && imageFile.existsSync()) {
        request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      }
      if (audioFile != null && audioFile.existsSync()) {
        request.files.add(await http.MultipartFile.fromPath('voice', audioFile.path));
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['data'] is Map) {
          return ResellerChatMessage.fromJson(
            Map<String, dynamic>.from(decoded['data']),
            currentUserId: currentUserId,
          );
        }
      }
    } catch (e, st) {
      AppLogger.error('ResellerSendMessageError', e, st);
    }
    return null;
  }

  /// 5. Upload Media Standalone Endpoint
  static Future<String?> uploadMedia(File file) async {
    try {
      final token = await AuthApiService.getToken();
      final uri = Uri.parse(ApiConstants.resellerChatUpload);
      final request = http.MultipartRequest('POST', uri);

      request.headers['Accept'] = 'application/json';
      if (token != null) request.headers['Authorization'] = 'Bearer $token';

      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['media_url'] != null) {
          return decoded['media_url'].toString();
        }
      }
    } catch (e, st) {
      AppLogger.error('ResellerUploadMediaError', e, st);
    }
    return null;
  }

  /// 6. Validate User ID / Account ID
  static Future<Map<String, dynamic>?> validateUser(String accountId) async {
    try {
      final token = await AuthApiService.getToken();
      final uri = Uri.parse(ApiConstants.resellerValidateUser);
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .post(uri, headers: headers, body: jsonEncode({'account_id': accountId}))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['user'] is Map) {
          return Map<String, dynamic>.from(decoded['user']);
        }
      }
    } catch (e, st) {
      AppLogger.error('ResellerValidateUserError', e, st);
    }
    return null;
  }

  /// 7. Execute Instant Coin Transfer to User
  static Future<Map<String, dynamic>> transferCoins({
    required String targetAccountId,
    required int coins,
    required double amountBdt,
    String? paymentMethod,
    String? transactionId,
    String? notes,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final uri = Uri.parse(ApiConstants.resellerTransferCoins);
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'target_account_id': targetAccountId,
              'coins': coins,
              'amount_bdt': amountBdt,
              'payment_method': paymentMethod ?? 'bKash',
              'transaction_id': transactionId ?? '',
              'notes': notes ?? 'Recharged via live chat discount',
            }),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e, st) {
      AppLogger.error('ResellerTransferCoinsError', e, st);
      return {'status': false, 'message': 'Connection error: ${e.toString()}'};
    }
    return {'status': false, 'message': 'Unknown error occurred'};
  }

  /// 8. Verify Google Play In-App Purchase and Credit Coins
  static Future<Map<String, dynamic>> verifyGooglePlayPurchase({
    required int packageId,
    required String productId,
    required String purchaseToken,
    String? orderId,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      };

      final payload = jsonEncode({
        'package_id': packageId,
        'product_id': productId,
        'purchase_token': purchaseToken,
        if (orderId != null) 'order_id': orderId,
      });

      var response = await http
          .post(Uri.parse(ApiConstants.googlePlayVerify), headers: headers, body: payload)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 404) {
        response = await http
            .post(Uri.parse(ApiConstants.googlePlayVerifyAlias), headers: headers, body: payload)
            .timeout(const Duration(seconds: 15));
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e, st) {
      AppLogger.error('GooglePlayVerifyError', e, st);
      return {'status': false, 'message': 'Connection error: ${e.toString()}'};
    }
    return {'status': false, 'message': 'Failed to verify Google Play purchase'};
  }
}
