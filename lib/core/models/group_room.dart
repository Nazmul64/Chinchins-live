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
    final seatIdx = json['seat_index'] != null
        ? (json['seat_index'] is int
            ? json['seat_index'] as int
            : int.tryParse(json['seat_index'].toString()) ?? defaultIndex)
        : defaultIndex;

    final userData = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : (json['guest'] is Map<String, dynamic> ? json['guest'] as Map<String, dynamic> : null);

    final rawUserId = userData?['id']?.toString() ?? json['user_id']?.toString();
    final isOccupied = json['is_occupied'] == true || (rawUserId != null && rawUserId.isNotEmpty && rawUserId != '0');
    final role = json['role']?.toString() ?? (seatIdx == 0 || seatIdx == 1 ? 'host' : 'guest');
    final isHostFlag = json['is_host'] == true || role.toLowerCase() == 'host' || (userData?['is_host'] == true);

    return RoomSeat(
      seatIndex: seatIdx,
      userId: isOccupied ? rawUserId : null,
      accountId: userData?['account_id']?.toString() ?? json['account_id']?.toString(),
      userName: userData?['name']?.toString() ?? userData?['nickname']?.toString() ?? json['user_name']?.toString() ?? (isOccupied ? 'User $rawUserId' : null),
      userAvatar: userData?['avatar_url']?.toString() ?? userData?['avatar']?.toString() ?? json['user_avatar']?.toString(),
      isHost: isHostFlag,
      isMuted: json['is_muted'] == true || json['is_mic_muted'] == true,
      isVideoMuted: json['is_video_muted'] == true || json['is_camera_off'] == true,
      isSpeaking: json['is_speaking'] == true,
      level: userData?['level'] is int ? userData!['level'] as int : (int.tryParse(userData?['level']?.toString() ?? '1') ?? 1),
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
    required this.roomId,
    required this.title,
    required this.hostId,
    this.hostAccountId,
    required this.hostName,
    required this.hostAvatar,
    this.hostLevel = 1,
    this.hostIsVerified = false,
    required this.coverUrl,
    required this.channelName,
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

  factory GroupPartyRoom.fromJson(Map<String, dynamic> json) {
    final hostData = json['host'] is Map<String, dynamic> ? json['host'] as Map<String, dynamic> : null;
    final rawSeats = json['seats'];
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
    final rawAudience = json['audience'] ?? json['audience_avatars'] ?? json['members'];
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
        : null;

    final rawRoomType = json['room_type']?.toString() ?? json['type']?.toString();

    return GroupPartyRoom(
      id: json['id']?.toString() ?? '0',
      roomId: json['room_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['room_title']?.toString() ?? json['title']?.toString() ?? 'Live Party Room',
      hostId: hostData?['id']?.toString() ?? json['host_id']?.toString() ?? '0',
      hostAccountId: hostData?['account_id']?.toString() ?? json['host_account_id']?.toString(),
      hostName: hostData?['name']?.toString() ?? hostData?['nickname']?.toString() ?? json['host_name']?.toString() ?? 'Host',
      hostAvatar: hostData?['avatar_url']?.toString() ?? hostData?['avatar']?.toString() ?? json['host_avatar']?.toString() ?? json['room_cover']?.toString() ?? '',
      hostLevel: hostData?['level'] is int ? hostData!['level'] as int : (int.tryParse(hostData?['level']?.toString() ?? '1') ?? 1),
      hostIsVerified: hostData?['is_verified'] == true || hostData?['verified'] == 1,
      coverUrl: json['room_cover']?.toString() ?? json['cover_url']?.toString() ?? hostData?['avatar_url']?.toString() ?? '',
      channelName: json['channel_name']?.toString() ?? 'party_${json['room_id'] ?? json['id']}',
      roomType: PartyRoomType.fromString(rawRoomType),
      tag: json['topic_tag']?.toString() ?? json['tag']?.toString() ?? 'Singing 🎤',
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

  const PartyRoomTopicTag({
    required this.id,
    required this.name,
    required this.tag,
  });

  factory PartyRoomTopicTag.fromJson(Map<String, dynamic> json) {
    return PartyRoomTopicTag(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      tag: json['tag']?.toString() ?? json['name']?.toString() ?? '',
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
      topicTags: tags.isNotEmpty ? tags : defaultTags,
      defaultAnnouncement: json['default_announcement']?.toString() ?? 'Welcome to our Live Fun Hangout 🥳✨! Please be respectful to everyone in the room.',
    );
  }

  static List<PartyRoomTopicTag> get defaultTags => const [
        PartyRoomTopicTag(id: 'singing', name: 'Singing 🎤', tag: 'Singing'),
        PartyRoomTopicTag(id: 'dating', name: 'Dating ❤️', tag: 'Dating'),
        PartyRoomTopicTag(id: 'party', name: 'Party 💃', tag: 'Party'),
        PartyRoomTopicTag(id: 'chitchat', name: 'ChitChat 💬', tag: 'ChitChat'),
        PartyRoomTopicTag(id: 'gaming', name: 'Gaming 🎮', tag: 'Gaming'),
        PartyRoomTopicTag(id: 'latenight', name: 'Late Night 🌙', tag: 'Late Night'),
      ];
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
    required this.createdAt,
  });

  factory PartyRoomMessage.fromJson(Map<String, dynamic> json) {
    final senderData = json['sender'] is Map<String, dynamic> ? json['sender'] as Map<String, dynamic> : null;

    DateTime date;
    try {
      date = json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now();
    } catch (_) {
      date = DateTime.now();
    }

    return PartyRoomMessage(
      id: json['id'] is int ? json['id'] as int : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      roomId: json['room_id']?.toString() ?? '',
      type: json['type']?.toString() ?? (json['image_url'] != null ? 'image' : 'text'),
      message: json['message']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? json['image']?.toString() ?? json['file_url']?.toString(),
      senderId: senderData?['id']?.toString() ?? json['sender_id']?.toString(),
      senderAccountId: senderData?['account_id']?.toString() ?? json['sender_account_id']?.toString(),
      senderName: senderData?['name']?.toString() ?? senderData?['nickname']?.toString() ?? json['sender_name']?.toString() ?? 'Guest',
      senderAvatar: senderData?['avatar_url']?.toString() ?? senderData?['avatar']?.toString() ?? json['sender_avatar']?.toString(),
      senderLevel: senderData?['level'] is int ? senderData!['level'] as int : (int.tryParse(senderData?['level']?.toString() ?? '1') ?? 1),
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
  final String? appId;
  final String role;

  const PartyRoomRtcData({
    required this.driver,
    required this.channelName,
    this.token,
    this.appId,
    this.role = 'host',
  });

  factory PartyRoomRtcData.fromJson(Map<String, dynamic> json) {
    return PartyRoomRtcData(
      driver: json['driver']?.toString() ?? 'agora',
      channelName: json['channel_name']?.toString() ?? '',
      token: json['token']?.toString(),
      appId: json['app_id']?.toString(),
      role: json['role']?.toString() ?? 'host',
    );
  }
}
