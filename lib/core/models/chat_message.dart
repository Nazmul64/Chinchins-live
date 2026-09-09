import '../utils/date_time_utils.dart';

enum MessageType {
  text,
  introSecret,
  callRecord,
  image,
  voice,
  gift,
}

enum CallRecordStatus {
  rejected,
  missed,
  completed,
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String text;
  final MessageType type;
  final String time;
  final bool isFromMe;
  final String? imageUrl;
  final CallRecordStatus? callStatus;
  final int? callDurationSeconds;
  final String? giftName;
  final String? giftEmoji;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.text,
    required this.type,
    required this.time,
    required this.isFromMe,
    this.imageUrl,
    this.callStatus,
    this.callDurationSeconds,
    this.giftName,
    this.giftEmoji,
  });

  factory ChatMessage.fromJson(
    Map<String, dynamic> json, {
    String myUserId = '',
    String partnerName = '',
    String partnerAvatar = '',
  }) {
    final senderIdStr = json['sender_id']?.toString() ?? json['user_id']?.toString() ?? '';
    final isFromMe = myUserId.isNotEmpty && (senderIdStr == myUserId || json['is_from_me'] == true);

    // Detect media URL comprehensively
    String? mediaUrl = json['media_url']?.toString() ??
        json['image_url']?.toString() ??
        json['file_url']?.toString() ??
        json['voice_url']?.toString() ??
        json['audio_url']?.toString() ??
        json['attachment_url']?.toString() ??
        json['media_path']?.toString() ??
        json['file_path']?.toString() ??
        json['photo_url']?.toString() ??
        json['image']?.toString() ??
        json['photo']?.toString() ??
        json['voice']?.toString() ??
        json['audio']?.toString() ??
        json['file']?.toString() ??
        json['path']?.toString() ??
        json['media']?.toString() ??
        json['attachment']?.toString();

    if (mediaUrl != null && mediaUrl.isEmpty) {
      mediaUrl = null;
    }

    final rawType = json['type']?.toString().toLowerCase() ?? '';
    final rawMsg = json['message']?.toString() ?? json['text']?.toString() ?? '';

    MessageType type = MessageType.text;
    if (rawType == 'voice' ||
        rawType == 'audio' ||
        json['voice_url'] != null ||
        json['audio_url'] != null ||
        (mediaUrl != null && (mediaUrl.endsWith('.m4a') || mediaUrl.endsWith('.mp3') || mediaUrl.endsWith('.aac') || mediaUrl.endsWith('.wav') || mediaUrl.endsWith('.ogg')))) {
      type = MessageType.voice;
    } else if (rawType == 'image' ||
        rawType == 'photo' ||
        rawType == 'picture' ||
        json['image_url'] != null ||
        json['photo_url'] != null ||
        (mediaUrl != null && (mediaUrl.endsWith('.jpg') || mediaUrl.endsWith('.png') || mediaUrl.endsWith('.webp') || mediaUrl.endsWith('.jpeg') || mediaUrl.endsWith('.gif')))) {
      type = MessageType.image;
    } else if (rawType == 'gift') {
      type = MessageType.gift;
    } else if (rawType == 'call_record' || rawType == 'video_call' || rawType == 'call') {
      type = MessageType.callRecord;
    } else if (rawMsg == 'Photo' && mediaUrl != null) {
      type = MessageType.image;
    }

    final rawCreatedAt = json['created_at']?.toString();
    final rawTime = json['time']?.toString() ?? json['formatted_time']?.toString() ?? json['time_formatted']?.toString();
    final String timeStr = DateTimeUtils.formatBubbleTime(rawCreatedAt, fallbackTime: rawTime);

    final senderObj = json['sender'] is Map<String, dynamic> ? json['sender'] as Map<String, dynamic> : null;
    final senderName = isFromMe
        ? 'Me'
        : (senderObj?['name'] ?? senderObj?['display_name'] ?? json['sender_name'] ?? (partnerName.isNotEmpty ? partnerName : 'Host'));

    final senderAvatar = isFromMe
        ? ''
        : (senderObj?['avatar_url'] ??
            senderObj?['avatar'] ??
            senderObj?['cover_photo_url'] ??
            senderObj?['profile_photo'] ??
            json['sender_avatar'] ??
            json['avatar_url'] ??
            json['avatar'] ??
            partnerAvatar);

    final dur = json['duration'] is int
        ? json['duration'] as int
        : int.tryParse(json['duration']?.toString() ?? '');

    return ChatMessage(
      id: json['id']?.toString() ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderIdStr,
      senderName: senderName.toString(),
      senderAvatar: senderAvatar.toString(),
      text: rawMsg,
      type: type,
      time: timeStr,
      isFromMe: isFromMe,
      imageUrl: mediaUrl,
      callDurationSeconds: dur,
      giftName: json['gift_name']?.toString() ?? json['gift']?['name']?.toString(),
      giftEmoji: json['gift_emoji']?.toString() ?? json['gift']?['emoji']?.toString(),
    );
  }
}

class ChatThread {
  final String id;
  final String modelId;
  final String name;
  final String avatarUrl;
  final String lastMessage;
  final String lastMessagePrefix; // e.g. [Video Call], [Image]
  final String time;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isOnline;
  final int videoCallRate;
  final String? badgeEmoji; // e.g. "❤️", "⭐", "🦋"
  final List<ChatMessage> messages;

  ChatThread({
    required this.id,
    required this.modelId,
    required this.name,
    required this.avatarUrl,
    required this.lastMessage,
    this.lastMessagePrefix = '',
    required this.time,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.isOnline = true,
    this.videoCallRate = 1800,
    this.badgeEmoji,
    required this.messages,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    final userId = json['user_id']?.toString() ??
        json['id']?.toString() ??
        json['host_id']?.toString() ??
        json['sender_id']?.toString() ??
        '';
    final name = json['name']?.toString() ??
        json['display_name']?.toString() ??
        json['user']?['name']?.toString() ??
        json['user']?['display_name']?.toString() ??
        json['host']?['name']?.toString() ??
        json['host']?['display_name']?.toString() ??
        'Host';
    final avatar = json['avatar_url']?.toString() ??
        json['avatar']?.toString() ??
        json['profile_photo']?.toString() ??
        json['cover_photo_url']?.toString() ??
        json['photo']?.toString() ??
        json['image']?.toString() ??
        json['user']?['avatar_url']?.toString() ??
        json['user']?['avatar']?.toString() ??
        json['host']?['avatar_url']?.toString() ??
        json['host']?['avatar']?.toString() ??
        '';
    final isOnline = json['is_online'] == true || json['is_active'] == true;
    final unread = (json['unread_count'] is int)
        ? json['unread_count'] as int
        : (int.tryParse(json['unread_count']?.toString() ?? '0') ?? 0);
    final rate = (json['video_call_rate'] is int)
        ? json['video_call_rate'] as int
        : (int.tryParse(json['video_call_rate']?.toString() ?? '1800') ?? 1800);

    String lastMsgText = '';
    String lastMsgPrefix = '';
    String timeStr = 'Just now';
    DateTime? lastMsgAt;

    if (json['last_message'] is Map) {
      final lm = json['last_message'] as Map<String, dynamic>;
      lastMsgText = lm['text']?.toString() ?? lm['message']?.toString() ?? '';
      final msgType = lm['type']?.toString() ?? '';
      if (msgType == 'video_call' || msgType == 'call') {
        lastMsgPrefix = '[Video Call]';
      } else if (msgType == 'image' || msgType == 'photo') {
        lastMsgPrefix = '[Image]';
      } else if (msgType == 'voice' || msgType == 'audio') {
        lastMsgPrefix = '[Voice Note]';
      }
      final rawTime = lm['time_formatted']?.toString() ?? lm['time']?.toString() ?? lm['time_ago']?.toString();
      final int? minsAgo = lm['minutes_ago'] is int ? lm['minutes_ago'] as int : int.tryParse(lm['minutes_ago']?.toString() ?? '');
      if (lm['created_at'] != null) {
        try {
          lastMsgAt = DateTime.parse(lm['created_at'].toString());
        } catch (_) {}
      }
      timeStr = DateTimeUtils.formatChatTimestamp(
        lm['created_at']?.toString(),
        fallbackTime: rawTime,
        minutesAgo: minsAgo,
      );
    } else if (json['last_message'] != null) {
      lastMsgText = json['last_message'].toString();
      timeStr = DateTimeUtils.cleanRawTimeString(json['time']?.toString() ?? 'Just now');
    }

    if (json['updated_at'] != null && lastMsgAt == null) {
      try {
        lastMsgAt = DateTime.parse(json['updated_at'].toString());
      } catch (_) {}
    }

    return ChatThread(
      id: 't_$userId',
      modelId: userId,
      name: name,
      avatarUrl: avatar,
      lastMessage: lastMsgText.isNotEmpty ? lastMsgText : 'Say hi! 💕',
      lastMessagePrefix: lastMsgPrefix,
      time: timeStr,
      lastMessageAt: lastMsgAt,
      unreadCount: unread,
      isOnline: isOnline,
      videoCallRate: rate,
      messages: [],
    );
  }
}

