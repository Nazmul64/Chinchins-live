import '../../features/profile/services/level_bases_api_service.dart';

enum PartyRoomType {
  audioVoice,
  videoParty;

  static PartyRoomType fromString(String? type) {
    if (type == null) return PartyRoomType.audioVoice;
    final lower = type.toLowerCase();
    if (lower == 'video' || lower == 'videoparty' || lower == 'video_party') {
      return PartyRoomType.videoParty;
    }
    return PartyRoomType.audioVoice;
  }

  String toParam() {
    switch (this) {
      case PartyRoomType.videoParty:
        return 'video';
      case PartyRoomType.audioVoice:
        return 'voice';
    }
  }
}

class RoomSeat {
  final int seatIndex;
  final String? userId;
  final String? accountId;
  final String? userName;
  final String? userAvatar;
  final String? frameSvgUrl;
  final bool isHost;
  final bool isMuted;
  final bool isVideoMuted;
  final bool isSpeaking;
  final int level;
  final bool isVerified;
  final int coinsReceived;
  final String status;
  final String role;

  const RoomSeat({
    required this.seatIndex,
    this.userId,
    this.accountId,
    this.userName,
    this.userAvatar,
    this.frameSvgUrl,
    this.isHost = false,
    this.isMuted = false,
    this.isVideoMuted = false,
    this.isSpeaking = false,
    this.level = 1,
    this.isVerified = false,
    this.coinsReceived = 0,
    this.status = 'empty',
    this.role = 'guest',
  });

  bool get isEmpty => userId == null || userId!.isEmpty || status == 'empty';

  factory RoomSeat.fromJson(Map<String, dynamic> json, int defaultIndex) {
    int seatIdx = defaultIndex;
    if (json['seat_index'] != null) {
      final rawIdx = int.tryParse(json['seat_index'].toString()) ?? defaultIndex;
      if (rawIdx >= 1 && defaultIndex == 0 && rawIdx == 1) {
        seatIdx = 0;
      } else if (rawIdx >= 1 && rawIdx <= 16 && (json['seat_index'] is int || json['seat_index'] is String)) {
        seatIdx = rawIdx > 0 ? (rawIdx - 1) : rawIdx;
      } else {
        seatIdx = rawIdx;
      }
    }

    final userData = json['user_profile'] is Map<String, dynamic>
        ? json['user_profile'] as Map<String, dynamic>
        : (json['user'] is Map<String, dynamic>
            ? json['user'] as Map<String, dynamic>
            : (json['guest'] is Map<String, dynamic>
                ? json['guest'] as Map<String, dynamic>
                : (json['sender'] is Map<String, dynamic> ? json['sender'] as Map<String, dynamic> : null)));

    final rawUserId = userData?['id']?.toString() ?? json['user_id']?.toString() ?? json['id']?.toString();
    final isOccupied = json['is_occupied'] == true ||
        json['status'] == 'occupied' ||
        (rawUserId != null && rawUserId.isNotEmpty && rawUserId != '0');
    final role = json['role']?.toString() ?? (seatIdx == 0 ? 'host' : 'guest');
    final isHostFlag = json['is_host'] == true ||
        role.toLowerCase() == 'host' ||
        (userData?['is_host'] == true) ||
        (seatIdx == 0);
    final userLvl = userData?['level'] is int
        ? userData!['level'] as int
        : (int.tryParse(userData?['level']?.toString() ?? json['level']?.toString() ?? '1') ?? 1);

    final parsedFrame = userData?['profile_base_frame']?.toString() ??
        userData?['frame_svg_url']?.toString() ??
        userData?['base_frame_image']?.toString() ??
        json['profile_base_frame']?.toString() ??
        json['frame_svg_url']?.toString();

    final finalFrameUrl = (parsedFrame != null && parsedFrame.isNotEmpty)
        ? parsedFrame
        : (isOccupied ? LevelBasesApiService.getFrameUrlForLevel(userLvl) : null);

    final rawName = userData?['name']?.toString() ??
        userData?['display_name']?.toString() ??
        userData?['nickname']?.toString() ??
        json['user_name']?.toString() ??
        json['display_name']?.toString() ??
        json['name']?.toString();

    final rawAvatar = userData?['avatar_url']?.toString() ??
        userData?['avatar']?.toString() ??
        json['user_avatar']?.toString() ??
        json['avatar_url']?.toString() ??
        json['avatar']?.toString();

    return RoomSeat(
      seatIndex: seatIdx,
      userId: isOccupied ? rawUserId : null,
      accountId: userData?['account_id']?.toString() ?? json['account_id']?.toString(),
      userName: rawName ?? (isOccupied ? 'User $rawUserId' : null),
      userAvatar: rawAvatar,
      frameSvgUrl: finalFrameUrl,
      isHost: isHostFlag,
      isMuted: json['is_muted'] == true || json['is_mic_muted'] == true,
      isVideoMuted: json['is_video_muted'] == true || json['is_camera_off'] == true,
      isSpeaking: json['is_speaking'] == true,
      level: userLvl,
      isVerified: userData?['is_verified'] == true || userData?['verified'] == 1,
      coinsReceived: json['coins_received'] is int
          ? json['coins_received'] as int
          : (int.tryParse(json['coins_received']?.toString() ?? '0') ?? 0),
      status: isOccupied ? 'occupied' : 'empty',
      role: isHostFlag ? 'host' : 'guest',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'seat_index': seatIndex,
      'user_id': userId,
      'account_id': accountId,
      'user_name': userName,
      'user_avatar': userAvatar,
      'frame_svg_url': frameSvgUrl,
      'is_host': isHost,
      'is_muted': isMuted,
      'is_video_muted': isVideoMuted,
      'is_speaking': isSpeaking,
      'level': level,
      'is_verified': isVerified,
      'coins_received': coinsReceived,
      'status': status,
      'role': role,
    };
  }

  RoomSeat copyWith({
    int? seatIndex,
    String? userId,
    String? accountId,
    String? userName,
    String? userAvatar,
    String? frameSvgUrl,
    bool? isHost,
    bool? isMuted,
    bool? isVideoMuted,
    bool? isSpeaking,
    int? level,
    bool? isVerified,
    int? coinsReceived,
    String? status,
    String? role,
  }) {
    return RoomSeat(
      seatIndex: seatIndex ?? this.seatIndex,
      userId: userId ?? this.userId,
      accountId: accountId ?? this.accountId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      frameSvgUrl: frameSvgUrl ?? this.frameSvgUrl,
      isHost: isHost ?? this.isHost,
      isMuted: isMuted ?? this.isMuted,
      isVideoMuted: isVideoMuted ?? this.isVideoMuted,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      level: level ?? this.level,
      isVerified: isVerified ?? this.isVerified,
      coinsReceived: coinsReceived ?? this.coinsReceived,
      status: status ?? this.status,
      role: role ?? this.role,
    );
  }
}

class GroupPartyRoom {
  final String id;
  final String roomId;
  final String title;
  final String hostId;
  final String? hostAccountId;
  final String hostName;
  final String hostAvatar;
  final int hostLevel;
  final bool hostIsVerified;
  final String coverUrl;
  final String channelName;
  final PartyRoomType roomType;
  final String tag;
  final int maxSeats;
  final int occupiedSeats;
  final int audienceCount;
  final int coinRatePerMinute;
  final double hostCommissionPercentage;
  final double adminCommissionPercentage;
  final bool isLocked;
  final String status;
  final String? announcement;
  final List<RoomSeat> seats;
  final List<String> audienceAvatars;
  final PartyRoomRtcData? rtc;

  const GroupPartyRoom({
    required this.id,
    this.roomId = '',
    required this.title,
    required this.hostId,
    this.hostAccountId,
    required this.hostName,
    required this.hostAvatar,
    this.hostLevel = 1,
    this.hostIsVerified = false,
    required this.coverUrl,
    this.channelName = '',
    required this.roomType,
    required this.tag,
    this.maxSeats = 10,
    this.occupiedSeats = 1,
    this.audienceCount = 1,
    this.coinRatePerMinute = 100,
    this.hostCommissionPercentage = 50.0,
    this.adminCommissionPercentage = 50.0,
    this.isLocked = false,
    this.status = 'active',
    this.announcement,
    required this.seats,
    this.audienceAvatars = const [],
    this.rtc,
  });

  factory GroupPartyRoom.fromJson(Map<String, dynamic> rawJson) {
    Map<String, dynamic> json = rawJson;
    if (rawJson['room'] is Map<String, dynamic>) {
      json = Map<String, dynamic>.from(rawJson['room'] as Map<String, dynamic>);
      if (rawJson['token'] != null && json['token'] == null) json['token'] = rawJson['token'];
      if (rawJson['livekit_token'] != null && json['livekit_token'] == null) json['livekit_token'] = rawJson['livekit_token'];
      if (rawJson['livekit_url'] != null && json['livekit_url'] == null) json['livekit_url'] = rawJson['livekit_url'];
      if (rawJson['can_publish'] != null && json['can_publish'] == null) json['can_publish'] = rawJson['can_publish'];
    } else if (rawJson['data'] is Map<String, dynamic>) {
      final innerData = rawJson['data'] as Map<String, dynamic>;
      if (innerData['room'] is Map<String, dynamic>) {
        json = Map<String, dynamic>.from(innerData['room'] as Map<String, dynamic>);
      } else {
        json = innerData;
      }
      if (rawJson['token'] != null && json['token'] == null) json['token'] = rawJson['token'];
      if (rawJson['livekit_token'] != null && json['livekit_token'] == null) json['livekit_token'] = rawJson['livekit_token'];
      if (rawJson['livekit_url'] != null && json['livekit_url'] == null) json['livekit_url'] = rawJson['livekit_url'];
      if (rawJson['can_publish'] != null && json['can_publish'] == null) json['can_publish'] = rawJson['can_publish'];
    }

    final hostData = json['host'] is Map<String, dynamic>
        ? json['host'] as Map<String, dynamic>
        : (rawJson['host'] is Map<String, dynamic> ? rawJson['host'] as Map<String, dynamic> : null);
    final rawSeats = json['seats'] ?? rawJson['seats'];
    final List<RoomSeat> parsedSeats = [];
    final maxSeatsCount = json['max_seats'] is int ? json['max_seats'] as int : (int.tryParse(json['max_seats']?.toString() ?? '10') ?? 10);

    if (rawSeats is List && rawSeats.isNotEmpty) {
      for (int i = 0; i < rawSeats.length; i++) {
        final item = rawSeats[i];
        if (item is Map<String, dynamic>) {
          parsedSeats.add(RoomSeat.fromJson(item, i));
        } else {
          parsedSeats.add(RoomSeat(seatIndex: i));
        }
      }
    }

    // Ensure we have at least maxSeats slots
    while (parsedSeats.length < maxSeatsCount) {
      final idx = parsedSeats.length;
      parsedSeats.add(RoomSeat(seatIndex: idx));
    }

    // Parse audience avatars if any
    final List<String> avatars = [];
    final rawAudience = json['audience'] ?? json['audience_avatars'] ?? json['members'] ?? rawJson['audience'];
    if (rawAudience is List) {
      for (final a in rawAudience) {
        if (a is String && a.isNotEmpty) {
          avatars.add(a);
        } else if (a is Map && (a['avatar_url'] != null || a['avatar'] != null)) {
          avatars.add((a['avatar_url'] ?? a['avatar']).toString());
        }
      }
    }

    final rtcData = json['rtc'] is Map<String, dynamic>
        ? PartyRoomRtcData.fromJson(json['rtc'] as Map<String, dynamic>)
        : ((json['livekit_token'] != null || json['token'] != null || json['livekit_url'] != null || rawJson['livekit_token'] != null || rawJson['token'] != null)
            ? PartyRoomRtcData.fromJson(json)
            : null);

    final rawRoomType = json['room_type']?.toString() ?? json['type']?.toString() ?? rawJson['room_type']?.toString();

    final hostAvatarStr = hostData?['avatar_url']?.toString() ??
        hostData?['avatar']?.toString() ??
        json['host_avatar_url']?.toString() ??
        json['host_avatar']?.toString() ??
        json['room_cover']?.toString() ??
        json['avatar_url']?.toString() ??
        rawJson['host_avatar']?.toString() ??
        '';
    final hostNameStr = hostData?['name']?.toString() ??
        hostData?['display_name']?.toString() ??
        hostData?['nickname']?.toString() ??
        json['host_name']?.toString() ??
        json['display_name']?.toString() ??
        rawJson['host_name']?.toString() ??
        'Host';
    final hostIdStr = hostData?['id']?.toString() ?? json['host_id']?.toString() ?? rawJson['host_id']?.toString() ?? '0';

    // Ensure Seat 0 (Seat #1) always has host information bound
    if (parsedSeats.isNotEmpty) {
      final existingAvatar = parsedSeats[0].userAvatar;
      final existingName = parsedSeats[0].userName;
      final finalAvatar = (hostAvatarStr.isNotEmpty) ? hostAvatarStr : (existingAvatar ?? '');
      final finalName = (hostNameStr.isNotEmpty && hostNameStr != 'Host') ? hostNameStr : (existingName ?? hostNameStr);

      parsedSeats[0] = parsedSeats[0].copyWith(
        userId: hostIdStr != '0' ? hostIdStr : (parsedSeats[0].userId ?? hostIdStr),
        userName: finalName,
        userAvatar: finalAvatar,
        isHost: true,
        status: 'occupied',
        role: 'host',
      );
    }

    return GroupPartyRoom(
      id: json['id']?.toString() ?? rawJson['id']?.toString() ?? '0',
      roomId: json['room_id']?.toString() ?? json['id']?.toString() ?? rawJson['id']?.toString() ?? '',
      title: json['room_title']?.toString() ?? json['title']?.toString() ?? rawJson['room_title']?.toString() ?? 'Live Party Room',
      hostId: hostIdStr,
      hostAccountId: hostData?['account_id']?.toString() ?? json['host_account_id']?.toString(),
      hostName: hostNameStr,
      hostAvatar: hostAvatarStr,
      hostLevel: hostData?['level'] is int ? hostData!['level'] as int : (int.tryParse(hostData?['level']?.toString() ?? '1') ?? 1),
      hostIsVerified: hostData?['is_verified'] == true || hostData?['verified'] == 1,
      coverUrl: json['room_cover']?.toString() ?? json['cover_url']?.toString() ?? hostAvatarStr,
      channelName: json['channel_name']?.toString() ?? 'party_${json['room_id'] ?? json['id'] ?? rawJson['id']}',
      roomType: PartyRoomType.fromString(rawRoomType),
      tag: json['topic_tag']?.toString() ?? json['tag']?.toString() ?? 'Chat',
      maxSeats: maxSeatsCount,
      occupiedSeats: json['occupied_seats'] is int ? json['occupied_seats'] as int : (int.tryParse(json['occupied_seats']?.toString() ?? '1') ?? 1),
      audienceCount: json['online_members'] is int
          ? json['online_members'] as int
          : (json['audience_count'] is int ? json['audience_count'] as int : (int.tryParse(json['online_members']?.toString() ?? json['audience_count']?.toString() ?? '1') ?? 1)),
      coinRatePerMinute: json['coin_rate_per_minute'] is int
          ? json['coin_rate_per_minute'] as int
          : (int.tryParse(json['coin_rate_per_minute']?.toString() ?? '100') ?? 100),
      hostCommissionPercentage: json['host_commission_percentage'] is num
          ? (json['host_commission_percentage'] as num).toDouble()
          : (double.tryParse(json['host_commission_percentage']?.toString() ?? '50.0') ?? 50.0),
      adminCommissionPercentage: json['admin_commission_percentage'] is num
          ? (json['admin_commission_percentage'] as num).toDouble()
          : (double.tryParse(json['admin_commission_percentage']?.toString() ?? '50.0') ?? 50.0),
      isLocked: json['is_locked'] == true || json['is_private'] == true,
      status: json['status']?.toString() ?? 'active',
      announcement: json['announcement']?.toString(),
      seats: parsedSeats,
      audienceAvatars: avatars,
      rtc: rtcData,
    );
  }

  GroupPartyRoom copyWith({
    String? id,
    String? roomId,
    String? title,
    String? hostId,
    String? hostAccountId,
    String? hostName,
    String? hostAvatar,
    int? hostLevel,
    bool? hostIsVerified,
    String? coverUrl,
    String? channelName,
    PartyRoomType? roomType,
    String? tag,
    int? maxSeats,
    int? occupiedSeats,
    int? audienceCount,
    int? coinRatePerMinute,
    double? hostCommissionPercentage,
    double? adminCommissionPercentage,
    bool? isLocked,
    String? status,
    String? announcement,
    List<RoomSeat>? seats,
    List<String>? audienceAvatars,
    PartyRoomRtcData? rtc,
  }) {
    return GroupPartyRoom(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      title: title ?? this.title,
      hostId: hostId ?? this.hostId,
      hostAccountId: hostAccountId ?? this.hostAccountId,
      hostName: hostName ?? this.hostName,
      hostAvatar: hostAvatar ?? this.hostAvatar,
      hostLevel: hostLevel ?? this.hostLevel,
      hostIsVerified: hostIsVerified ?? this.hostIsVerified,
      coverUrl: coverUrl ?? this.coverUrl,
      channelName: channelName ?? this.channelName,
      roomType: roomType ?? this.roomType,
      tag: tag ?? this.tag,
      maxSeats: maxSeats ?? this.maxSeats,
      occupiedSeats: occupiedSeats ?? this.occupiedSeats,
      audienceCount: audienceCount ?? this.audienceCount,
      coinRatePerMinute: coinRatePerMinute ?? this.coinRatePerMinute,
      hostCommissionPercentage: hostCommissionPercentage ?? this.hostCommissionPercentage,
      adminCommissionPercentage: adminCommissionPercentage ?? this.adminCommissionPercentage,
      isLocked: isLocked ?? this.isLocked,
      status: status ?? this.status,
      announcement: announcement ?? this.announcement,
      seats: seats ?? this.seats,
      audienceAvatars: audienceAvatars ?? this.audienceAvatars,
      rtc: rtc ?? this.rtc,
    );
  }
}

class PartyRoomTopicTag {
  final String id;
  final String name;
  final String tag;
  final String? icon;
  final String? color;
  final String? slug;

  const PartyRoomTopicTag({
    required this.id,
    required this.name,
    required this.tag,
    this.icon,
    this.color,
    this.slug,
  });

  factory PartyRoomTopicTag.fromJson(Map<String, dynamic> json) {
    final rawName = json['name']?.toString() ?? '';
    final icon = json['icon']?.toString();
    final displayName = (icon != null && icon.isNotEmpty && !rawName.contains(icon))
        ? '$rawName $icon'
        : rawName;

    return PartyRoomTopicTag(
      id: json['id']?.toString() ?? json['slug']?.toString() ?? rawName.toLowerCase(),
      name: displayName,
      tag: rawName,
      icon: icon,
      color: json['color']?.toString(),
      slug: json['slug']?.toString(),
    );
  }
}

class PartyRoomConfig {
  final bool isEnabled;
  final int defaultVoiceRate;
  final int defaultVideoRate;
  final double hostCommissionPercentage;
  final double adminCommissionPercentage;
  final int maxGuests;
  final List<PartyRoomTopicTag> topicTags;
  final String defaultAnnouncement;

  const PartyRoomConfig({
    this.isEnabled = true,
    this.defaultVoiceRate = 100,
    this.defaultVideoRate = 100,
    this.hostCommissionPercentage = 50.0,
    this.adminCommissionPercentage = 50.0,
    this.maxGuests = 10,
    this.topicTags = const [],
    this.defaultAnnouncement = 'Welcome to our Live Fun Hangout 🥳✨! Please be respectful to everyone in the room.',
  });

  factory PartyRoomConfig.fromJson(Map<String, dynamic> json) {
    final List<PartyRoomTopicTag> tags = [];
    if (json['topic_tags'] is List) {
      for (final t in json['topic_tags'] as List) {
        if (t is Map<String, dynamic>) {
          tags.add(PartyRoomTopicTag.fromJson(t));
        } else if (t is String) {
          tags.add(PartyRoomTopicTag(id: t.toLowerCase(), name: t, tag: t));
        }
      }
    }

    return PartyRoomConfig(
      isEnabled: json['is_enabled'] != false,
      defaultVoiceRate: json['default_voice_rate'] is int ? json['default_voice_rate'] as int : (int.tryParse(json['default_voice_rate']?.toString() ?? '100') ?? 100),
      defaultVideoRate: json['default_video_rate'] is int ? json['default_video_rate'] as int : (int.tryParse(json['default_video_rate']?.toString() ?? '100') ?? 100),
      hostCommissionPercentage: json['host_commission_percentage'] is num ? (json['host_commission_percentage'] as num).toDouble() : 50.0,
      adminCommissionPercentage: json['admin_commission_percentage'] is num ? (json['admin_commission_percentage'] as num).toDouble() : 50.0,
      maxGuests: json['max_guests'] is int ? json['max_guests'] as int : (int.tryParse(json['max_guests']?.toString() ?? '10') ?? 10),
      topicTags: tags,
      defaultAnnouncement: json['default_announcement']?.toString() ?? 'Welcome to our Live Fun Hangout 🥳✨! Please be respectful to everyone in the room.',
    );
  }
}

class PartyRoomMessage {
  final int id;
  final String roomId;
  final String type; // 'text', 'image', 'gift', 'system'
  final String message;
  final String? imageUrl;
  final String? senderId;
  final String? senderAccountId;
  final String? senderName;
  final String? senderAvatar;
  final int senderLevel;
  final bool senderIsVerified;
  final Map<String, int> reactions;
  final DateTime createdAt;

  const PartyRoomMessage({
    required this.id,
    required this.roomId,
    required this.type,
    required this.message,
    this.imageUrl,
    this.senderId,
    this.senderAccountId,
    this.senderName,
    this.senderAvatar,
    this.senderLevel = 1,
    this.senderIsVerified = false,
    this.reactions = const {},
    required this.createdAt,
  });

  factory PartyRoomMessage.fromJson(dynamic rawJson) {
    Map<String, dynamic> json;
    if (rawJson is Map) {
      json = Map<String, dynamic>.from(rawJson);
    } else {
      return PartyRoomMessage(
        id: DateTime.now().millisecondsSinceEpoch,
        roomId: '',
        type: 'text',
        message: rawJson?.toString() ?? '',
        createdAt: DateTime.now(),
      );
    }

    // Unwrap if nested in 'message' or 'data'
    if (json.containsKey('message') && json['message'] is Map) {
      final nested = Map<String, dynamic>.from(json['message'] as Map);
      if (nested.containsKey('id') || nested.containsKey('message') || nested.containsKey('sender_id')) {
        json = nested;
      }
    } else if (json.containsKey('data') && json['data'] is Map) {
      final nested = Map<String, dynamic>.from(json['data'] as Map);
      if (nested.containsKey('id') || nested.containsKey('message') || nested.containsKey('sender_id')) {
        json = nested;
      }
    }

    final senderData = json['sender'] is Map<String, dynamic>
        ? json['sender'] as Map<String, dynamic>
        : (json['sender'] is Map ? Map<String, dynamic>.from(json['sender'] as Map) : (json['user'] is Map ? Map<String, dynamic>.from(json['user'] as Map) : null));

    DateTime date;
    try {
      date = json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now();
    } catch (_) {
      date = DateTime.now();
    }

    final Map<String, int> parsedReactions = {};
    if (json['reactions'] is Map) {
      json['reactions'].forEach((k, v) {
        parsedReactions[k.toString()] = v is int ? v : (int.tryParse(v.toString()) ?? 0);
      });
    }

    final msgContent = (json['message'] is String ? json['message'] as String : null) ??
        json['text']?.toString() ??
        json['body']?.toString() ??
        '';

    final senderNameParsed = senderData?['name']?.toString() ??
        senderData?['display_name']?.toString() ??
        senderData?['nickname']?.toString() ??
        json['user_name']?.toString() ??
        json['name']?.toString() ??
        json['display_name']?.toString() ??
        json['sender_name']?.toString() ??
        'User';

    final senderAvatarParsed = senderData?['avatar_url']?.toString() ??
        senderData?['avatar']?.toString() ??
        json['avatar_url']?.toString() ??
        json['avatar']?.toString() ??
        json['sender_avatar']?.toString() ??
        json['user_avatar']?.toString() ??
        '';

    return PartyRoomMessage(
      id: json['id'] is int ? json['id'] as int : (int.tryParse(json['id']?.toString() ?? '0') ?? DateTime.now().millisecondsSinceEpoch),
      roomId: json['room_id']?.toString() ?? json['party_room_id']?.toString() ?? json['stream_id']?.toString() ?? '',
      type: json['type']?.toString() ?? (json['image_url'] != null || json['image'] != null ? 'image' : 'text'),
      message: msgContent,
      imageUrl: json['image_url']?.toString() ?? json['image']?.toString() ?? json['file_url']?.toString() ?? json['media_url']?.toString(),
      senderId: senderData?['id']?.toString() ?? json['sender_id']?.toString() ?? json['user_id']?.toString(),
      senderAccountId: senderData?['account_id']?.toString() ?? json['sender_account_id']?.toString() ?? json['account_id']?.toString(),
      senderName: senderNameParsed,
      senderAvatar: senderAvatarParsed,
      senderLevel: senderData?['level'] is int ? senderData!['level'] as int : (int.tryParse(senderData?['level']?.toString() ?? json['level']?.toString() ?? '1') ?? 1),
      senderIsVerified: senderData?['is_verified'] == true || senderData?['verified'] == 1 || json['sender_is_verified'] == true,
      reactions: parsedReactions,
      createdAt: date,
    );
  }

  PartyRoomMessage copyWith({
    int? id,
    String? roomId,
    String? type,
    String? message,
    String? imageUrl,
    String? senderId,
    String? senderAccountId,
    String? senderName,
    String? senderAvatar,
    int? senderLevel,
    bool? senderIsVerified,
    Map<String, int>? reactions,
    DateTime? createdAt,
  }) {
    return PartyRoomMessage(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      type: type ?? this.type,
      message: message ?? this.message,
      imageUrl: imageUrl ?? this.imageUrl,
      senderId: senderId ?? this.senderId,
      senderAccountId: senderAccountId ?? this.senderAccountId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      senderLevel: senderLevel ?? this.senderLevel,
      senderIsVerified: senderIsVerified ?? this.senderIsVerified,
      reactions: reactions ?? this.reactions,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class PartyRoomSeatRequest {
  final dynamic id;
  final dynamic requestId;
  final dynamic userId;
  final String accountId;
  final String name;
  final String avatarUrl;
  final int level;
  final int coins;
  final String status;
  final DateTime createdAt;

  const PartyRoomSeatRequest({
    required this.id,
    required this.requestId,
    required this.userId,
    required this.accountId,
    required this.name,
    required this.avatarUrl,
    this.level = 1,
    this.coins = 0,
    this.status = 'pending',
    required this.createdAt,
  });

  factory PartyRoomSeatRequest.fromJson(Map<String, dynamic> json) {
    DateTime date;
    try {
      date = json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now();
    } catch (_) {
      date = DateTime.now();
    }

    final userData = json['user'] is Map<String, dynamic> ? json['user'] as Map<String, dynamic> : null;

    return PartyRoomSeatRequest(
      id: json['id'] ?? json['request_id'],
      requestId: json['request_id'] ?? json['id'] ?? json['invitation_id'],
      userId: json['user_id'] ?? userData?['id'],
      accountId: json['account_id']?.toString() ?? userData?['account_id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['display_name']?.toString() ?? userData?['name']?.toString() ?? 'User',
      avatarUrl: json['avatar_url']?.toString() ?? json['avatar']?.toString() ?? userData?['avatar_url']?.toString() ?? '',
      level: json['level'] is int ? json['level'] as int : (int.tryParse(json['level']?.toString() ?? '1') ?? 1),
      coins: json['coins'] is int ? json['coins'] as int : (int.tryParse(json['coins']?.toString() ?? '0') ?? 0),
      status: json['status']?.toString() ?? 'pending',
      createdAt: date,
    );
  }
}

class PartyRoomInvitee {
  final dynamic id;
  final String accountId;
  final String name;
  final String avatarUrl;
  final int level;
  final int coins;
  final bool isOnline;
  final bool isOnSeat;
  final bool isFriend;
  final bool isLiked;

  const PartyRoomInvitee({
    required this.id,
    required this.accountId,
    required this.name,
    required this.avatarUrl,
    this.level = 1,
    this.coins = 0,
    this.isOnline = true,
    this.isOnSeat = false,
    this.isFriend = false,
    this.isLiked = false,
  });

  factory PartyRoomInvitee.fromJson(Map<String, dynamic> json) {
    return PartyRoomInvitee(
      id: json['id'],
      accountId: json['account_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['nickname']?.toString() ?? 'User',
      avatarUrl: json['avatar_url']?.toString() ?? json['avatar']?.toString() ?? '',
      level: json['level'] is int ? json['level'] as int : (int.tryParse(json['level']?.toString() ?? '1') ?? 1),
      coins: json['coins'] is int ? json['coins'] as int : (int.tryParse(json['coins']?.toString() ?? '0') ?? 0),
      isOnline: json['is_online'] != false,
      isOnSeat: json['is_on_seat'] == true,
      isFriend: json['is_friend'] == true || json['is_connected'] == true,
      isLiked: json['is_liked'] == true,
    );
  }
}

class PartyRoomRtcData {
  final String driver;
  final String channelName;
  final String? token;
  final String? livekitToken;
  final String? livekitUrl;
  final String? appId;
  final String role;
  final bool canPublish;

  const PartyRoomRtcData({
    required this.driver,
    required this.channelName,
    this.token,
    this.livekitToken,
    this.livekitUrl,
    this.appId,
    this.role = 'host',
    this.canPublish = true,
  });

  factory PartyRoomRtcData.fromJson(Map<String, dynamic> json) {
    final t = json['token']?.toString() ?? json['livekit_token']?.toString() ?? json['rtc_token']?.toString();
    final lt = json['livekit_token']?.toString() ?? json['token']?.toString();
    final lu = json['livekit_url']?.toString() ?? 'wss://chinchins.live/livekit';

    return PartyRoomRtcData(
      driver: json['driver']?.toString() ?? 'livekit',
      channelName: json['channel_name']?.toString() ?? json['room_name']?.toString() ?? '',
      token: t,
      livekitToken: lt,
      livekitUrl: lu,
      appId: json['app_id']?.toString(),
      role: json['role']?.toString() ?? 'host',
      canPublish: json['can_publish'] != false,
    );
  }
}

/// Type alias for real-time chat room messages
typedef ChatMessageModel = PartyRoomMessage;


