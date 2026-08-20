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
}
