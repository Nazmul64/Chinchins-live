import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/group_room.dart';
import '../utils/app_logger.dart';
import '../../features/auth/services/auth_api_service.dart';
import 'fast_api_client.dart';

class PartyRoomApiService {
  static PartyRoomConfig _cachedConfig = const PartyRoomConfig();

  /// Helper to get request headers with Sanctum Bearer Token and Custom User headers
  static Future<Map<String, String>> _getHeaders([String? contentType]) async {
    final token = await AuthApiService.getToken();
    final user = await AuthApiService.getSavedUser();
    final userId = user?['id']?.toString();
    final accountId = user?['account_id']?.toString();

    return {
      'Accept': 'application/json',
      if (contentType != null) 'Content-Type': contentType,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (userId != null && userId.isNotEmpty) 'X-User-Id': userId,
      if (accountId != null && accountId.isNotEmpty) 'X-Account-Id': accountId,
    };
  }

  /// 1. Get Party Room Config & Topic Tags (`GET /api/party-rooms/config`)
  static Future<PartyRoomConfig> getConfig() async {
    try {
      final cached = FastApiClient.getCachedSync(ApiConstants.partyRoomsConfig);
      if (cached != null && cached is Map<String, dynamic>) {
        final data = cached['data'] is Map<String, dynamic> ? cached['data'] as Map<String, dynamic> : cached;
        _cachedConfig = PartyRoomConfig.fromJson(data);
      }

      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse(ApiConstants.partyRoomsConfig), headers: headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json is Map<String, dynamic>) {
          await FastApiClient.putCache(ApiConstants.partyRoomsConfig, json);
          final data = json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : json;
          _cachedConfig = PartyRoomConfig.fromJson(data);
          return _cachedConfig;
        }
      }
    } catch (e) {
      AppLogger.error('PartyRoomGetConfig', e);
    }
    return _cachedConfig;
  }

  /// 2. Browse Live Party Rooms Feed (`GET /api/party-rooms`)
  static Future<List<GroupPartyRoom>> getPartyRooms({
    String? roomType,
    String? topicTag,
    String? search,
    int page = 1,
  }) async {
    try {
      final queryParams = <String, String>{
        if (roomType != null && roomType.isNotEmpty && roomType != 'all') 'room_type': roomType,
        if (topicTag != null && topicTag.isNotEmpty && topicTag != 'All') 'topic_tag': topicTag,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (page > 1) 'page': page.toString(),
      };

      Uri uri = Uri.parse(ApiConstants.partyRooms);
      if (queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final headers = await _getHeaders();
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        List? rawList;
        if (json is Map && json['data'] is List) {
          rawList = json['data'] as List;
        } else if (json is List) {
          rawList = json;
        }

        if (rawList != null) {
          final List<GroupPartyRoom> rooms = [];
          for (final item in rawList) {
            if (item is Map<String, dynamic>) {
              rooms.add(GroupPartyRoom.fromJson(item));
            }
          }
          return rooms;
        }
      }
    } catch (e) {
      AppLogger.error('PartyRoomGetList', e);
    }
    return [];
  }

  /// 3. Create / Host a Party Room (`POST /api/party-rooms/create`)
  static Future<Map<String, dynamic>> createPartyRoom({
    required String roomTitle,
    required String roomType, // 'voice' or 'video'
    required String topicTag,
    int maxSeats = 10,
    int coinRatePerMinute = 100,
    String? announcement,
    File? roomCoverFile,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final user = await AuthApiService.getSavedUser();
      final userId = user?['id']?.toString();
      final accountId = user?['account_id']?.toString();

      final uri = Uri.parse(ApiConstants.partyRoomsCreate);

      if (roomCoverFile != null && await roomCoverFile.exists()) {
        final request = http.MultipartRequest('POST', uri);
        request.headers.addAll({
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          if (userId != null && userId.isNotEmpty) 'X-User-Id': userId,
          if (accountId != null && accountId.isNotEmpty) 'X-Account-Id': accountId,
        });

        request.fields['room_title'] = roomTitle.trim();
        request.fields['title'] = roomTitle.trim();
        request.fields['room_type'] = roomType.toLowerCase();
        request.fields['type'] = roomType.toLowerCase();
        request.fields['topic_tag'] = topicTag.trim();
        request.fields['tag'] = topicTag.trim();
        request.fields['max_seats'] = maxSeats.toString();
        request.fields['coin_rate_per_minute'] = coinRatePerMinute.toString();
        if (announcement != null && announcement.trim().isNotEmpty) {
          request.fields['announcement'] = announcement.trim();
        }

        request.files.add(await http.MultipartFile.fromPath(
          'room_cover_file',
          roomCoverFile.path,
        ));

        final streamed = await request.send().timeout(const Duration(seconds: 20));
        final resp = await http.Response.fromStream(streamed);
        final json = jsonDecode(resp.body);

        if (resp.statusCode == 200 || resp.statusCode == 201) {
          GroupPartyRoom? createdRoom;
          if (json is Map && json['data'] is Map && json['data']['room'] is Map<String, dynamic>) {
            createdRoom = GroupPartyRoom.fromJson(json['data']['room'] as Map<String, dynamic>);
          } else if (json is Map && json['data'] is Map<String, dynamic>) {
            createdRoom = GroupPartyRoom.fromJson(json['data'] as Map<String, dynamic>);
          }

          return {
            'success': true,
            'message': json is Map ? json['message'] ?? 'Party room created successfully!' : 'Party room created!',
            'room': createdRoom,
            'data': json is Map ? json['data'] : null,
          };
        } else {
          return {
            'success': false,
            'message': json is Map ? json['message'] ?? 'Failed to create room' : 'Failed to create room',
          };
        }
      } else {
        final headers = await _getHeaders('application/json');
        final payload = {
          'room_title': roomTitle.trim(),
          'title': roomTitle.trim(),
          'room_type': roomType.toLowerCase(),
          'type': roomType.toLowerCase(),
          'topic_tag': topicTag.trim(),
          'tag': topicTag.trim(),
          'max_seats': maxSeats,
          'coin_rate_per_minute': coinRatePerMinute,
          if (announcement != null && announcement.trim().isNotEmpty) 'announcement': announcement.trim(),
        };

        final response = await http
            .post(uri, headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 15));

        final json = jsonDecode(response.body);

        if (response.statusCode == 200 || response.statusCode == 201) {
          GroupPartyRoom? createdRoom;
          if (json is Map && json['data'] is Map && json['data']['room'] is Map<String, dynamic>) {
            createdRoom = GroupPartyRoom.fromJson(json['data']['room'] as Map<String, dynamic>);
          } else if (json is Map && json['data'] is Map<String, dynamic>) {
            createdRoom = GroupPartyRoom.fromJson(json['data'] as Map<String, dynamic>);
          }

          return {
            'success': true,
            'message': json is Map ? json['message'] ?? 'Party room created successfully!' : 'Party room created!',
            'room': createdRoom,
            'data': json is Map ? json['data'] : null,
          };
        } else {
          return {
            'success': false,
            'message': json is Map ? json['message'] ?? 'Failed to create room' : 'Failed to create room',
          };
        }
      }
    } catch (e) {
      AppLogger.error('PartyRoomCreate', e);
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// 4. Get Full Room State (`GET /api/party-rooms/{id}`)
  static Future<GroupPartyRoom?> getPartyRoomDetails(dynamic roomId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse(ApiConstants.partyRoomById(roomId)), headers: headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json is Map && json['data'] is Map<String, dynamic>) {
          return GroupPartyRoom.fromJson(json['data'] as Map<String, dynamic>);
        } else if (json is Map<String, dynamic>) {
          return GroupPartyRoom.fromJson(json);
        }
      }
    } catch (e) {
      AppLogger.error('PartyRoomGetDetails', e);
    }
    return null;
  }

  /// 5. Join Room as Audience (`POST /api/party-rooms/{id}/join`)
  static Future<bool> joinRoom(dynamic roomId) async {
    try {
      final headers = await _getHeaders('application/json');
      final response = await http
          .post(Uri.parse(ApiConstants.partyRoomJoin(roomId)), headers: headers)
          .timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 6. Leave Room (`POST /api/party-rooms/{id}/leave`)
  static Future<bool> leaveRoom(dynamic roomId) async {
    try {
      final headers = await _getHeaders('application/json');
      final response = await http
          .post(Uri.parse(ApiConstants.partyRoomLeave(roomId)), headers: headers)
          .timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 7. Host Ends Party Room (`POST /api/party-rooms/{id}/end`)
  static Future<bool> endRoom(dynamic roomId) async {
    try {
      final headers = await _getHeaders('application/json');
      final response = await http
          .post(Uri.parse(ApiConstants.partyRoomEnd(roomId)), headers: headers)
          .timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 8. Search & Fetch Connected / Liked Friends (`GET /api/party-rooms/{id}/search-invitees`)
  static Future<List<PartyRoomInvitee>> searchInvitees(dynamic roomId, {String? query}) async {
    try {
      final headers = await _getHeaders();
      final url = ApiConstants.partyRoomSearchInvitees(roomId, query);
      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        List? rawList;
        if (json is Map && json['data'] is List) {
          rawList = json['data'] as List;
        } else if (json is List) {
          rawList = json;
        }

        if (rawList != null) {
          return rawList
              .whereType<Map<String, dynamic>>()
              .map((item) => PartyRoomInvitee.fromJson(item))
              .toList();
        }
      }
    } catch (e) {
      AppLogger.error('PartyRoomSearchInvitees', e);
    }
    return [];
  }

  /// 9. Host Invites Guest to Seat (`POST /api/party-rooms/{id}/invite-guest`)
  static Future<Map<String, dynamic>> inviteGuest(dynamic roomId, {
    required dynamic userId,
    required int seatIndex,
  }) async {
    try {
      final headers = await _getHeaders('application/json');
      final payload = {
        'user_id': userId,
        'seat_index': seatIndex,
      };

      final response = await http
          .post(
            Uri.parse(ApiConstants.partyRoomInviteGuest(roomId)),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 8));

      final json = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200 || (json is Map && json['success'] == true),
        'message': json is Map ? json['message'] ?? 'Invitation sent!' : 'Invitation sent!',
        'data': json is Map ? json['data'] : null,
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to invite guest: $e'};
    }
  }

  /// 10. Guest Responds to Seat Invitation (`POST /api/party-rooms/{id}/respond-invite`)
  static Future<Map<String, dynamic>> respondInvite(dynamic roomId, {
    required dynamic invitationId,
    required String action, // 'accept' or 'decline'
  }) async {
    try {
      final headers = await _getHeaders('application/json');
      final payload = {
        'invitation_id': invitationId,
        'action': action.toLowerCase(),
      };

      final response = await http
          .post(
            Uri.parse(ApiConstants.partyRoomRespondInvite(roomId)),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 8));

      final json = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200 || (json is Map && json['success'] == true),
        'message': json is Map ? json['message'] ?? 'Responded to invitation' : 'Responded',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// 11. Guest Takes Open Seat (`POST /api/party-rooms/{id}/take-seat`)
  static Future<Map<String, dynamic>> takeSeat(dynamic roomId, {required int seatIndex}) async {
    try {
      final headers = await _getHeaders('application/json');
      final payload = {'seat_index': seatIndex};

      final response = await http
          .post(
            Uri.parse(ApiConstants.partyRoomTakeSeat(roomId)),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 8));

      final json = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200 || (json is Map && json['success'] == true),
        'message': json is Map ? json['message'] ?? 'Took seat $seatIndex' : 'Seat taken',
        'data': json is Map ? json['data'] : null,
      };
    } catch (e) {
      return {'success': false, 'message': 'Error taking seat: $e'};
    }
  }

  /// 12. Guest Leaves Seat (`POST /api/party-rooms/{id}/leave-seat`)
  static Future<Map<String, dynamic>> leaveSeat(dynamic roomId) async {
    try {
      final headers = await _getHeaders('application/json');
      final response = await http
          .post(Uri.parse(ApiConstants.partyRoomLeaveSeat(roomId)), headers: headers)
          .timeout(const Duration(seconds: 8));

      final json = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200 || (json is Map && json['success'] == true),
        'message': json is Map ? json['message'] ?? 'Left seat successfully' : 'Left seat',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error leaving seat: $e'};
    }
  }

  /// 13. Host Kicks Guest from Seat (`POST /api/party-rooms/{id}/kick-seat`)
  static Future<Map<String, dynamic>> kickSeat(dynamic roomId, {int? seatIndex, dynamic userId}) async {
    try {
      final headers = await _getHeaders('application/json');
      final payload = {
        if (seatIndex != null) 'seat_index': seatIndex,
        if (userId != null) 'user_id': userId,
      };

      final response = await http
          .post(
            Uri.parse(ApiConstants.partyRoomKickSeat(roomId)),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 8));

      final json = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200 || (json is Map && json['success'] == true),
        'message': json is Map ? json['message'] ?? 'Guest removed from seat' : 'Guest removed',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error kicking guest: $e'};
    }
  }

  /// 14. Toggle Microphone Mute/Unmute (`POST /api/party-rooms/{id}/toggle-mic`)
  static Future<bool> toggleMic(dynamic roomId, {required bool isMuted}) async {
    try {
      final headers = await _getHeaders('application/json');
      final payload = {'is_muted': isMuted};

      final response = await http
          .post(
            Uri.parse(ApiConstants.partyRoomToggleMic(roomId)),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 6));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 15. Toggle Camera Video On/Off (`POST /api/party-rooms/{id}/toggle-video`)
  static Future<bool> toggleVideo(dynamic roomId, {required bool isVideoMuted}) async {
    try {
      final headers = await _getHeaders('application/json');
      final payload = {'is_video_muted': isVideoMuted};

      final response = await http
          .post(
            Uri.parse(ApiConstants.partyRoomToggleVideo(roomId)),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 6));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 16. Get In-Room Messages (`GET /api/party-rooms/{id}/messages`)
  static Future<List<PartyRoomMessage>> getMessages(dynamic roomId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse(ApiConstants.partyRoomMessages(roomId)), headers: headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        List? rawList;
        if (json is Map && json['data'] is List) {
          rawList = json['data'] as List;
        } else if (json is List) {
          rawList = json;
        }

        if (rawList != null) {
          return rawList
              .whereType<Map<String, dynamic>>()
              .map((item) => PartyRoomMessage.fromJson(item))
              .toList();
        }
      }
    } catch (e) {
      AppLogger.error('PartyRoomGetMessages', e);
    }
    return [];
  }

  /// 17. Send In-Room Message or Photo (`POST /api/party-rooms/{id}/messages/send`)
  /// Photos are uploaded and saved to `public/uploads/host_image/`
  static Future<PartyRoomMessage?> sendMessage(dynamic roomId, {
    String? message,
    File? imageFile,
  }) async {
    try {
      final token = await AuthApiService.getToken();
      final user = await AuthApiService.getSavedUser();
      final userId = user?['id']?.toString();
      final accountId = user?['account_id']?.toString();

      final uri = Uri.parse(ApiConstants.partyRoomSendMessage(roomId));

      if (imageFile != null && await imageFile.exists()) {
        final request = http.MultipartRequest('POST', uri);
        request.headers.addAll({
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          if (userId != null && userId.isNotEmpty) 'X-User-Id': userId,
          if (accountId != null && accountId.isNotEmpty) 'X-Account-Id': accountId,
        });

        if (message != null && message.trim().isNotEmpty) {
          request.fields['message'] = message.trim();
        }
        request.fields['type'] = 'image';

        request.files.add(await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
        ));

        final streamed = await request.send().timeout(const Duration(seconds: 20));
        final resp = await http.Response.fromStream(streamed);
        final json = jsonDecode(resp.body);

        if (resp.statusCode == 200 || resp.statusCode == 201) {
          if (json is Map && json['data'] is Map<String, dynamic>) {
            return PartyRoomMessage.fromJson(json['data'] as Map<String, dynamic>);
          }
        }
      } else {
        final headers = await _getHeaders('application/json');
        final payload = {
          'message': message?.trim() ?? '',
          'type': 'text',
        };

        final response = await http
            .post(uri, headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200 || response.statusCode == 201) {
          final json = jsonDecode(response.body);
          if (json is Map && json['data'] is Map<String, dynamic>) {
            return PartyRoomMessage.fromJson(json['data'] as Map<String, dynamic>);
          }
        }
      }
    } catch (e) {
      AppLogger.error('PartyRoomSendMessage', e);
    }
    return null;
  }

  /// 18. Send Live Gift in Room (`POST /api/party-rooms/{id}/send-gift`)
  static Future<Map<String, dynamic>> sendGift(dynamic roomId, {
    required int giftId,
    required dynamic receiverId,
    int count = 1,
  }) async {
    try {
      final headers = await _getHeaders('application/json');
      final payload = {
        'gift_id': giftId,
        'receiver_id': receiverId,
        'count': count,
      };

      final response = await http
          .post(
            Uri.parse(ApiConstants.partyRoomSendGift(roomId)),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      final json = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': json is Map ? json['message'] ?? 'Gift sent successfully!' : 'Gift sent!',
          'data': json is Map ? json['data'] : null,
        };
      } else if (response.statusCode == 402) {
        return {
          'success': false,
          'insufficient_balance': true,
          'message': json is Map ? json['message'] ?? 'Insufficient coin balance.' : 'Insufficient balance.',
        };
      } else {
        return {
          'success': false,
          'message': json is Map ? json['message'] ?? 'Failed to send gift.' : 'Failed to send gift.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error sending gift: $e'};
    }
  }

  /// 19. Real-Time 50/50 Minute Billing (`POST /api/party-rooms/{id}/deduct-interval`)
  /// 100 coins/min -> 50 Host (50%) / 50 Admin (50%)
  /// If balance < required, returns `insufficient_balance: true, evicted_from_seat: true`
  static Future<Map<String, dynamic>> deductInterval(dynamic roomId, {int minutes = 1}) async {
    try {
      final headers = await _getHeaders('application/json');
      final payload = {'minutes': minutes};

      final response = await http
          .post(
            Uri.parse(ApiConstants.partyRoomDeductInterval(roomId)),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      final json = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'insufficient_balance': false,
          'evicted_from_seat': false,
          'message': json is Map ? json['message'] : 'Billed interval successfully',
          'data': json is Map ? json['data'] : null,
        };
      } else if (response.statusCode == 402 || (json is Map && json['insufficient_balance'] == true)) {
        return {
          'success': false,
          'insufficient_balance': true,
          'evicted_from_seat': true,
          'message': json is Map ? json['message'] ?? 'Insufficient coins for stage seat. Moved to audience.' : 'Insufficient coins',
        };
      } else {
        return {
          'success': false,
          'insufficient_balance': false,
          'evicted_from_seat': false,
          'message': json is Map ? json['message'] : 'Interval billing check error',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'insufficient_balance': false,
        'evicted_from_seat': false,
        'message': 'Error: $e',
      };
    }
  }
}
