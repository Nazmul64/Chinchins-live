class SupportMessageModel {
  final int id;
  final int userId;
  final String senderType; // 'user' or 'admin'
  final bool isMe;
  final String senderName;
  final String type; // 'text', 'image', 'voice', 'system'
  final String? message;
  final String? mediaUrl;
  final bool isRead;
  final DateTime? createdAt;
  final String formattedTime;

  const SupportMessageModel({
    required this.id,
    required this.userId,
    required this.senderType,
    required this.isMe,
    required this.senderName,
    required this.type,
    this.message,
    this.mediaUrl,
    required this.isRead,
    this.createdAt,
    required this.formattedTime,
  });

  factory SupportMessageModel.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final senderTypeStr = json['sender_type']?.toString().toLowerCase() ?? 'user';
    final rawUserId = json['user_id'] is int
        ? json['user_id']
        : (int.tryParse('${json['user_id']}') ?? 0);

    bool isMeMsg = json['is_me'] == true ||
        senderTypeStr == 'user' ||
        (currentUserId != null && currentUserId == '$rawUserId');
    if (senderTypeStr == 'admin') {
      isMeMsg = false;
    }

    String? media = json['media_url']?.toString() ??
        json['image_url']?.toString() ??
        json['image']?.toString() ??
        json['file_url']?.toString() ??
        json['file']?.toString();

    if (media != null && media.isNotEmpty) {
      if (!media.startsWith('http://') &&
          !media.startsWith('https://') &&
          !media.startsWith('assets/')) {
        if (media.startsWith('/')) {
          media = 'https://chinchins.live$media';
        } else {
          media = 'https://chinchins.live/$media';
        }
      }
    }

    DateTime? parsedDate;
    if (json['created_at'] != null) {
      parsedDate = DateTime.tryParse(json['created_at'].toString());
    }

    String timeStr = json['formatted_time']?.toString() ?? '';
    if (timeStr.isEmpty && parsedDate != null) {
      final hour = parsedDate.hour > 12
          ? parsedDate.hour - 12
          : (parsedDate.hour == 0 ? 12 : parsedDate.hour);
      final min = parsedDate.minute.toString().padLeft(2, '0');
      final amPm = parsedDate.hour >= 12 ? 'PM' : 'AM';
      timeStr = '$hour:$min $amPm';
    }

    return SupportMessageModel(
      id: json['id'] is int ? json['id'] : (int.tryParse('${json['id']}') ?? 0),
      userId: rawUserId,
      senderType: senderTypeStr,
      isMe: isMeMsg,
      senderName: json['sender_name']?.toString() ??
          (senderTypeStr == 'admin' ? 'ChinChins Official Support' : 'You'),
      type: json['type']?.toString().toLowerCase() ??
          (media != null && media.isNotEmpty ? 'image' : 'text'),
      message: json['message']?.toString(),
      mediaUrl: media,
      isRead: json['is_read'] == true || json['is_read'] == 1,
      createdAt: parsedDate,
      formattedTime: timeStr,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'sender_type': senderType,
      'is_me': isMe,
      'sender_name': senderName,
      'type': type,
      'message': message,
      'media_url': mediaUrl,
      'is_read': isRead,
      'created_at': createdAt?.toIso8601String(),
      'formatted_time': formattedTime,
    };
  }
}
