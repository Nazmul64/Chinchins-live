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

  /// 1. Get Payment Options (bKash, Nagad, Google Play, Reseller Up To 29%↑)
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

    return _getDefaultPaymentOptionsFallback();
  }

  static Future<List<PaymentOption>> _syncPaymentOptionsInBackground(Map<String, String> queryParams) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      Uri uri = Uri.parse(ApiConstants.paymentOptions);
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
        if (decoded is Map && decoded['options'] is List) {
          final list = (decoded['options'] as List)
              .map((e) => PaymentOption.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          if (list.isNotEmpty) {
            _cachedOptions = list;
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
        name: 'Bkash',
        type: 'gateway',
        accountType: 'Personal / Merchant',
        accountNumber: '01706640864',
        icon: 'assets/images/gateways/bkash.png',
        badge: null,
        instructions: 'Send money to our bKash number.',
      ),
      const PaymentOption(
        id: 2,
        key: 'nagad',
        name: 'Nagad',
        type: 'gateway',
        accountType: 'Personal / Merchant',
        accountNumber: '01706640864',
        icon: 'assets/images/gateways/nagad.png',
        badge: null,
        instructions: 'Send money to our Nagad number.',
      ),
      const PaymentOption(
        id: 'google_play',
        key: 'google_play',
        name: 'Google Play',
        type: 'in_app_purchase',
        accountType: 'Official In-App Store',
        icon: 'https://upload.wikimedia.org/wikipedia/commons/7/7a/Google_Play_2022_logo.svg',
        badge: null,
        instructions: 'Instant Google Play in-app purchase.',
      ),
      const PaymentOption(
        id: 'reseller',
        key: 'reseller',
        name: 'Reseller',
        type: 'reseller',
        accountType: 'Direct Agent Chat',
        icon: 'https://ui-avatars.com/api/?name=Reseller&background=1e1b4b&color=fbbf24&bold=true',
        badge: 'Up To 29%↑',
        badgeColor: '#ef4444',
        activeCount: 3,
        instructions: 'Recharge via authorized live resellers with exclusive discounts.',
      ),
    ];
  }

  /// 2. Get Authorized Resellers List
  static Future<List<ResellerModel>> getResellers({int? coins, bool forceRefresh = false}) async {
    final queryParams = <String, String>{
      if (coins != null) 'coins': coins.toString(),
    };

    if (!forceRefresh && _cachedResellers.isNotEmpty) {
      _syncResellersInBackground(queryParams);
      return _cachedResellers;
    }

    final liveList = await _syncResellersInBackground(queryParams);
    if (liveList.isNotEmpty) {
      return liveList;
    }

    return _getDefaultResellersFallback();
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
          if (list.isNotEmpty) {
            _cachedResellers = list;
            return _cachedResellers;
          }
        }
      }
    } catch (e, st) {
      AppLogger.error('ResellersSyncError', e, st);
    }
    return _cachedResellers.isNotEmpty ? _cachedResellers : _getDefaultResellersFallback();
  }

  static List<ResellerModel> _getDefaultResellersFallback() {
    return [
      const ResellerModel(
        id: 1,
        resellerId: '595082249',
        name: 'MURAD COINS RESELLER',
        avatar: 'https://chinchins.live/uploads/reseller/murad_avatar.jpg',
        avatarUrl: 'https://chinchins.live/uploads/reseller/murad_avatar.jpg',
        level: 'Lv5',
        location: 'Dhaka, Bangladesh',
        age: 27,
        gender: 'male',
        phone: '01848340232',
        bio: 'কয়েন রিচার্জ, হোস্টিং এবং বিভিন্ন ধরণের গিফট ক্রয় করা হয়\nযোগাযোগ ০১৮৪৮৩৪০২৩২\nহোস্টিং স্যালারি তুলনামূলক বেশি দেওয়া হয়\nঅনেক কথা বলা\nমানুষটা যদি হঠাৎ চুপ হয়ে যায়,\nবুঝে নিও আঘাতটা অনেক গভীরে লেগেছে।',
        discountTag: 'Up To 29%↑',
        badgeTitle: 'Diamond Reseller',
        sales: 15549000,
        formattedSales: '💎 15,549,000',
        successRate: '91.79%',
        isOnline: true,
        statusText: 'Online',
        prefillMessage: 'Hello! My user ID is 266813634. I want to recharge 7560 gems. How much should I pay? 【GIVE THE BEST DISCOUNT 💎DIAMOND💎】',
      ),
    ];
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
}
