import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/services/auth_api_service.dart';

class CallApiService {
  static Future<Map<String, dynamic>?> getCallConfig() async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.callConfig);
      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      };

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true && decoded['data'] is Map) {
          return decoded['data'] as Map<String, dynamic>;
        }
      }
    } catch (e, st) {
      AppLogger.error('CallConfigError', e, st);
    }
    return null;
  }

  static Future<Map<String, dynamic>?> randomMatch({
    String callType = 'video',
    String gender = 'female',
    bool autoInitiate = false,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.callRandomMatch);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      };

      final payload = {
        'call_type': callType,
        'gender': gender,
        'auto_initiate': autoInitiate,
      };

      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true && decoded['data'] is Map) {
          return decoded['data'] as Map<String, dynamic>;
        }
      }
    } catch (e, st) {
      AppLogger.error('RandomMatchError', e, st);
    }
    return null;
  }

  static Future<Map<String, dynamic>> initiateCall({
    required dynamic receiverId,
    dynamic receiverAccountId,
    String callType = 'video',
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['user_id']?.toString() ?? savedUser?['account_id']?.toString();
      final callerAccountId = savedUser?['account_id']?.toString() ?? userId;

      final url = Uri.parse(ApiConstants.callInitiate);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
        if (callerAccountId != null) 'X-Account-Id': callerAccountId,
      };

      final dynamic parsedReceiverId = int.tryParse(receiverId.toString()) ?? receiverId;

      final payload = {
        'receiver_id': parsedReceiverId,
        'receiverId': parsedReceiverId,
        'receiver_account_id': receiverAccountId ?? receiverId,
        'target_id': parsedReceiverId,
        'target_account_id': receiverAccountId ?? receiverId,
        'user_id': userId,
        'caller_id': userId,
        'caller_account_id': callerAccountId,
        'call_type': callType,
      };

      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 15));

      Map<String, dynamic> decoded = {};
      try {
        final raw = jsonDecode(response.body);
        if (raw is Map<String, dynamic>) {
          decoded = raw;
        }
      } catch (e) {
        return {
          'success': false,
          'message': 'Server response error (${response.statusCode})',
        };
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final dataMap = decoded['data'] is Map ? decoded['data'] as Map<String, dynamic> : decoded;
        final dynamic rawCallId = dataMap['call_id'] ?? dataMap['id'] ?? decoded['call_id'] ?? decoded['id'];
        final int? parsedCallId = rawCallId is int
            ? rawCallId
            : int.tryParse(rawCallId?.toString() ?? '');

        return {
          'success': true,
          'is_free_trial': dataMap['is_free_trial'] == true || decoded['is_free_trial'] == true,
          'free_duration_seconds': dataMap['free_duration_seconds'] ?? decoded['free_duration_seconds'] ?? 10,
          'call_id': parsedCallId,
          'channel_name': dataMap['channel_name'] ?? decoded['channel_name'],
          'rate_per_minute': dataMap['rate_per_minute'] ?? decoded['rate_per_minute'] ?? 100,
          'dial_tone_url': dataMap['dial_tone_url'] ?? decoded['dial_tone_url'],
          'data': dataMap,
          'message': decoded['message'] ?? 'Call initiated successfully.',
        };
      } else if (response.statusCode == 402 || decoded['code'] == 'LOW_BALANCE_DEPOSIT_REQUIRED') {
        return {
          'success': false,
          'is_low_balance': true,
          'code': 'LOW_BALANCE_DEPOSIT_REQUIRED',
          'message': decoded['message'] ?? 'Insufficient coins balance. Please recharge now.',
          'current_coins': decoded['current_coins'] ?? 0,
          'required_coins': decoded['required_coins'] ?? 100,
        };
      } else {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Failed to initiate call (${response.statusCode})',
        };
      }
    } catch (e, st) {
      AppLogger.error('InitiateCallError', e, st);
      return {
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>?> checkIncomingCall() async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['user_id']?.toString();
      final accountId = savedUser?['account_id']?.toString();
      final phone = savedUser?['phone']?.toString();

      final queryParams = <String, String>{};
      if (userId != null && userId.isNotEmpty) {
        queryParams['user_id'] = userId;
        queryParams['receiver_id'] = userId;
        queryParams['target_id'] = userId;
      }
      if (accountId != null && accountId.isNotEmpty) {
        queryParams['account_id'] = accountId;
        queryParams['receiver_account_id'] = accountId;
        queryParams['target_account_id'] = accountId;
      }
      if (phone != null && phone.isNotEmpty) {
        queryParams['phone'] = phone;
      }

      final url = Uri.parse(ApiConstants.callIncoming).replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
        if (accountId != null) 'X-Account-Id': accountId,
      };

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final data = decoded['data'];
          final bool hasIncoming = decoded['has_incoming_call'] == true ||
              (decoded['status'] == true && data != null && data is Map && data.isNotEmpty && decoded['has_incoming_call'] != false) ||
              (decoded['call_id'] != null || (data is Map && data['call_id'] != null));
          if (hasIncoming) {
            final Map<String, dynamic> result = {};
            if (data is Map) {
              result.addAll(Map<String, dynamic>.from(data));
            }
            decoded.forEach((k, v) {
              if (k != 'data' && !result.containsKey(k)) {
                result[k.toString()] = v;
              }
            });
            return result;
          }
        }
      }
    } catch (e, st) {
      AppLogger.error('CheckIncomingCallError', e, st);
    }
    return null;
  }

  static Future<Map<String, dynamic>?> waitIncomingCall({int timeoutSeconds = 15}) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['user_id']?.toString();
      final accountId = savedUser?['account_id']?.toString();
      final phone = savedUser?['phone']?.toString();

      final queryParams = <String, String>{
        'timeout': timeoutSeconds.toString(),
      };
      if (userId != null && userId.isNotEmpty) {
        queryParams['user_id'] = userId;
        queryParams['receiver_id'] = userId;
        queryParams['target_id'] = userId;
      }
      if (accountId != null && accountId.isNotEmpty) {
        queryParams['account_id'] = accountId;
        queryParams['receiver_account_id'] = accountId;
      }
      if (phone != null && phone.isNotEmpty) {
        queryParams['phone'] = phone;
      }

      final url = Uri.parse(ApiConstants.callWaitIncoming).replace(
        queryParameters: queryParams,
      );
      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
        if (accountId != null) 'X-Account-Id': accountId,
      };

      final response = await http
          .get(url, headers: headers)
          .timeout(Duration(seconds: timeoutSeconds + 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final data = decoded['data'];
          final bool hasIncoming = decoded['has_incoming_call'] == true ||
              (decoded['status'] == true && data != null && data is Map && data.isNotEmpty && decoded['has_incoming_call'] != false) ||
              (decoded['call_id'] != null || (data is Map && data['call_id'] != null));
          if (hasIncoming) {
            final Map<String, dynamic> result = {};
            if (data is Map) {
              result.addAll(Map<String, dynamic>.from(data));
            }
            decoded.forEach((k, v) {
              if (k != 'data' && !result.containsKey(k)) {
                result[k.toString()] = v;
              }
            });
            return result;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> sendHeartbeat({
    String status = 'online',
    String deviceType = 'android',
    String? fcmToken,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.userHeartbeat);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      };

      final payload = {
        'status': status,
        'device_type': deviceType,
        if (fcmToken != null && fcmToken.isNotEmpty) 'fcm_token': fcmToken,
      };

      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 6));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getCallStatus(dynamic callId) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.callStatus(callId));
      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      };

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          if (decoded['data'] is Map) {
            return Map<String, dynamic>.from(decoded['data']);
          }
          return Map<String, dynamic>.from(decoded);
        }
      }
    } catch (e, st) {
      AppLogger.error('GetCallStatusError', e, st);
    }
    return null;
  }

  static Future<bool> confirmRinging({required dynamic callId}) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.callRinging);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      };

      final payload = {'call_id': callId};

      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 8));

      return response.statusCode == 200;
    } catch (e, st) {
      AppLogger.error('ConfirmRingingError', e, st);
      return false;
    }
  }

  static Future<Map<String, dynamic>?> acceptCall({required dynamic callId}) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['user_id']?.toString() ?? savedUser?['account_id']?.toString();
      final accountId = savedUser?['account_id']?.toString() ?? userId;

      final url = Uri.parse(ApiConstants.callAccept);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
        if (accountId != null) 'X-Account-Id': accountId,
      };

      final payload = {
        'call_id': callId,
        'user_id': userId,
        'receiver_id': userId,
        'account_id': accountId,
      };

      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          if (decoded['data'] is Map) {
            return Map<String, dynamic>.from(decoded['data']);
          }
          return Map<String, dynamic>.from(decoded);
        }
      }
    } catch (e, st) {
      AppLogger.error('AcceptCallError', e, st);
    }
    return null;
  }

  static Future<bool> rejectCall({required dynamic callId}) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.callReject);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      };

      final payload = {'call_id': callId};

      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 8));

      return response.statusCode == 200;
    } catch (e, st) {
      AppLogger.error('RejectCallError', e, st);
      return false;
    }
  }

  static Future<bool> cancelCall({required dynamic callId}) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.callCancel);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      };

      final payload = {'call_id': callId};

      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 8));

      return response.statusCode == 200;
    } catch (e, st) {
      AppLogger.error('CancelCallError', e, st);
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getIceServers() async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.callIceServers);
      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      };

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true && decoded['data'] != null) {
          final iceData = decoded['data'];
          if (iceData is Map && iceData['iceServers'] is List) {
            return List<Map<String, dynamic>>.from(
              (iceData['iceServers'] as List).map((e) => e is Map ? Map<String, dynamic>.from(e) : {'urls': e}),
            );
          } else if (iceData is List) {
            return List<Map<String, dynamic>>.from(
              iceData.map((e) => e is Map ? Map<String, dynamic>.from(e) : {'urls': e}),
            );
          }
        }
      }
    } catch (e, st) {
      AppLogger.error('GetIceServersError', e, st);
    }
    return [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
          'stun:stun3.l.google.com:19302',
          'stun:stun.relay.metered.ca:80',
        ],
      },
      {
        'urls': [
          'turn:global.relay.metered.ca:80',
          'turn:global.relay.metered.ca:80?transport=tcp',
          'turn:global.relay.metered.ca:443',
          'turns:global.relay.metered.ca:443?transport=tcp',
        ],
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ];
  }

  static Future<bool> sendSignal({
    required dynamic callId,
    String? channelName,
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['user_id']?.toString() ?? savedUser?['account_id']?.toString();
      final accountId = savedUser?['account_id']?.toString() ?? userId;

      final url = Uri.parse(ApiConstants.callSignalSend);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
        if (accountId != null) 'X-Account-Id': accountId,
      };

      final bodyData = <String, dynamic>{
        'call_id': callId,
        'type': type,
        'payload': payload,
        'sdp': payload['sdp'],
        'candidate': payload['candidate'],
        'sender_id': userId,
        'user_id': userId,
        'account_id': accountId,
        'sender_account_id': accountId,
        'sender_role': payload['sender_role'] ?? (type == 'offer' ? 'caller' : 'receiver'),
      };
      if (channelName != null && channelName.isNotEmpty) {
        bodyData['channel_name'] = channelName;
      }

      final response = await http
          .post(url, headers: headers, body: jsonEncode(bodyData))
          .timeout(const Duration(seconds: 8));

      // Dual-relay to RESTful routes for complete backend compatibility
      if (callId != null) {
        try {
          if (type == 'offer' && payload['sdp'] != null) {
            http.post(
              Uri.parse(ApiConstants.callOfferById(callId)),
              headers: headers,
              body: jsonEncode({'sdp': payload['sdp']}),
            ).catchError((_) => http.Response('', 404));
          } else if (type == 'answer' && payload['sdp'] != null) {
            http.post(
              Uri.parse(ApiConstants.callAnswerById(callId)),
              headers: headers,
              body: jsonEncode({'sdp': payload['sdp']}),
            ).catchError((_) => http.Response('', 404));
          } else if (type == 'candidate' && payload['candidate'] != null) {
            http.post(
              Uri.parse(ApiConstants.callIceCandidateById(callId)),
              headers: headers,
              body: jsonEncode({
                'candidate': payload['candidate'],
                'sdpMid': payload['sdpMid'],
                'sdpMLineIndex': payload['sdpMLineIndex'],
              }),
            ).catchError((_) => http.Response('', 404));
          }
        } catch (_) {}
      }

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e, st) {
      AppLogger.error('SendSignalError ($type)', e, st);
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> receiveSignals({
    dynamic callId,
    String? channelName,
    int? lastSignalId,
    bool autoRead = false,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['user_id']?.toString() ?? savedUser?['account_id']?.toString();
      final accountId = savedUser?['account_id']?.toString() ?? userId;

      final queryParams = <String, String>{
        'auto_read': autoRead ? '1' : '0',
      };
      if (callId != null) {
        queryParams['call_id'] = callId.toString();
        queryParams['call_session_id'] = callId.toString();
      }
      if (lastSignalId != null && lastSignalId > 0) {
        queryParams['last_signal_id'] = lastSignalId.toString();
      }

      final url = Uri.parse(ApiConstants.callSignalReceive).replace(queryParameters: queryParams);
      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
        if (accountId != null) 'X-Account-Id': accountId,
      };

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true && decoded['data'] is List) {
          return List<Map<String, dynamic>>.from(decoded['data']);
        } else if (decoded['data'] is List) {
          return List<Map<String, dynamic>>.from(decoded['data']);
        }
      }
    } catch (e, st) {
      AppLogger.error('ReceiveSignalsError', e, st);
    }
    return [];
  }

  static Future<Map<String, dynamic>> deductIntervalPulse({
    required int callId,
    required int elapsedSeconds,
    int coins = 100,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.callDeductInterval);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      };

      final payload = {
        'call_id': callId,
        'elapsed_seconds': elapsedSeconds,
        'coins': coins,
      };

      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 10));

      Map<String, dynamic> decoded = {};
      try {
        final raw = jsonDecode(response.body);
        if (raw is Map<String, dynamic>) {
          decoded = raw;
        }
      } catch (_) {}

      if (response.statusCode == 200) {
        return {
          'success': true,
          'is_free_trial': decoded['is_free_trial'] == true,
          'free_seconds_remaining': decoded['free_seconds_remaining'] ?? 0,
          'current_coins': decoded['data']?['current_coins'],
          'coins_deducted': decoded['data']?['coins_deducted'] ?? 0,
          'host_earned_coins': decoded['data']?['host_earned_coins'] ?? 0,
          'should_terminate_call': false,
          'message': decoded['message'] ?? 'Interval processed',
        };
      } else if (response.statusCode == 402 || decoded['code'] == 'LOW_BALANCE_DEPOSIT_REQUIRED') {
        return {
          'success': false,
          'code': 'LOW_BALANCE_DEPOSIT_REQUIRED',
          'should_terminate_call': true,
          'redirect_to_deposit': true,
          'message': decoded['message'] ?? 'Your balance is insufficient to continue calling. Please deposit now.',
          'current_coins': decoded['current_coins'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'should_terminate_call': decoded['should_terminate_call'] == true,
          'message': decoded['message'] ?? 'Pulse error (${response.statusCode})',
        };
      }
    } catch (e, st) {
      AppLogger.error('DeductPulseError', e, st);
      return {
        'success': false,
        'should_terminate_call': false,
        'message': 'Pulse connection issue: $e',
      };
    }
  }

  static Future<Map<String, dynamic>?> endCall({
    required int callId,
    required int durationSeconds,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final savedUser = await AuthApiService.getSavedUser();
      final userId = savedUser?['id']?.toString() ?? savedUser?['account_id']?.toString();

      final url = Uri.parse(ApiConstants.callEnd);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      };

      final payload = {
        'call_id': callId,
        'duration_seconds': durationSeconds,
      };

      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true && decoded['data'] is Map) {
          return decoded['data'] as Map<String, dynamic>;
        }
      }
    } catch (e, st) {
      AppLogger.error('EndCallError', e, st);
    }
    return null;
  }
}