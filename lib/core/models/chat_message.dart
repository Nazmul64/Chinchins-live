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
    final senderIdStr = json['sender_id']?.toString() ?? '';
    final isFromMe = myUserId.isNotEmpty && senderIdStr == myUserId;

    final typeStr = json['type']?.toString().toLowerCase() ?? 'text';
    MessageType type = MessageType.text;
    if (typeStr == 'voice') {
      type = MessageType.voice;
    } else if (typeStr == 'image') {
      type = MessageType.image;
    } else if (typeStr == 'gift') {
      type = MessageType.gift;
    } else if (typeStr == 'call_record' || typeStr == 'video_call') {
      type = MessageType.callRecord;
    }

    String timeStr = 'Just now';
    if (json['created_at'] != null) {
      try {
        final dt = DateTime.parse(json['created_at'].toString()).toLocal();
        final h = dt.hour.toString().padLeft(2, '0');
        final m = dt.minute.toString().padLeft(2, '0');
        timeStr = '$h:$m';
      } catch (_) {
        timeStr = json['time']?.toString() ?? 'Just now';
      }
    }

    return ChatMessage(
      id: json['id']?.toString() ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderIdStr,
      senderName: isFromMe ? 'Me' : partnerName,
      senderAvatar: isFromMe ? '' : partnerAvatar,
      text: json['message']?.toString() ?? json['text']?.toString() ?? '',
      type: type,
      time: timeStr,
      isFromMe: isFromMe,
      imageUrl: json['media_url']?.toString(),
      callDurationSeconds: (json['duration'] is int) ? json['duration'] as int : null,
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
  final int unreadCount;
  final bool isOnline;
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
    this.unreadCount = 0,
    this.isOnline = true,
    this.badgeEmoji,
    required this.messages,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    final userId = json['user_id']?.toString() ?? json['id']?.toString() ?? '';
    final name = json['name']?.toString() ?? json['display_name']?.toString() ?? 'Host';
    final avatar = json['avatar_url']?.toString() ?? json['avatar']?.toString() ?? '';
    final isOnline = json['is_online'] == true;
    final unread = (json['unread_count'] is int) ? json['unread_count'] as int : 0;

    String lastMsgText = '';
    String lastMsgPrefix = '';
    String timeStr = 'Just now';

    if (json['last_message'] is Map) {
      final lm = json['last_message'] as Map<String, dynamic>;
      lastMsgText = lm['text']?.toString() ?? '';
      final msgType = lm['type']?.toString() ?? '';
      if (msgType == 'video_call') {
        lastMsgPrefix = '[Video Call]';
      } else if (msgType == 'image') {
        lastMsgPrefix = '[Image]';
      } else if (msgType == 'voice') {
        lastMsgPrefix = '[Voice Note]';
      }
      timeStr = lm['time']?.toString() ?? 'Just now';
    } else if (json['last_message'] != null) {
      lastMsgText = json['last_message'].toString();
    }

    return ChatThread(
      id: 't_$userId',
      modelId: userId,
      name: name,
      avatarUrl: avatar,
      lastMessage: lastMsgText.isNotEmpty ? lastMsgText : 'Say hi! 💕',
      lastMessagePrefix: lastMsgPrefix,
      time: timeStr,
      unreadCount: unread,
      isOnline: isOnline,
      messages: [],
    );
  }
}

