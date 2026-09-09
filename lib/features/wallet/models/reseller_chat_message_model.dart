class ResellerChatMessage {
  final dynamic id;
  final int resellerId;
  final dynamic userId;
  final String senderType; // 'user' | 'reseller' | 'system'
  final bool isMe;
  final String type; // 'text' | 'image' | 'voice' | 'transfer_receipt'
  final String message;
  final String? mediaUrl;
  final int? duration;
  final int? coinsAmount;
  final bool isRead;
  final DateTime? createdAt;
  final String formattedTime;

  const ResellerChatMessage({
    required this.id,
    required this.resellerId,
    this.userId,
    required this.senderType,
    required this.isMe,
    this.type = 'text',
    this.message = '',
    this.mediaUrl,
    this.duration,
    this.coinsAmount,
    this.isRead = true,
    this.createdAt,
    this.formattedTime = '',
  });

  factory ResellerChatMessage.fromJson(Map<String, dynamic> json, {dynamic currentUserId}) {
    final sType = json['sender_type']?.toString().toLowerCase() ?? 'user';
    final jsonIsMe = json['is_me'];
    bool calculatedIsMe = false;
    if (jsonIsMe is bool) {
      calculatedIsMe = jsonIsMe;
    } else if (sType == 'user') {
      calculatedIsMe = true;
    } else if (currentUserId != null && json['user_id'] != null) {
      calculatedIsMe = json['user_id'].toString() == currentUserId.toString() && sType != 'reseller';
    }

    DateTime? dt;
    if (json['created_at'] != null) {
      try {
        dt = DateTime.tryParse(json['created_at'].toString());
      } catch (_) {}
    }

    String timeStr = json['formatted_time']?.toString() ?? '';
    if (timeStr.isEmpty && dt != null) {
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final min = dt.minute.toString().padLeft(2, '0');
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      timeStr = '$hour:$min $amPm';
    }

    return ResellerChatMessage(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch,
      resellerId: json['reseller_id'] is int
          ? json['reseller_id']
          : (int.tryParse('${json['reseller_id']}') ?? 1),
      userId: json['user_id'],
      senderType: sType,
      isMe: calculatedIsMe,
      type: json['type']?.toString().toLowerCase() ?? 'text',
      message: json['message']?.toString() ?? '',
      mediaUrl: json['media_url']?.toString(),
      duration: json['duration'] is int
          ? json['duration']
          : (int.tryParse('${json['duration']}')),
      coinsAmount: json['coins_amount'] is int
          ? json['coins_amount']
          : (int.tryParse('${json['coins_amount']}')),
      isRead: json['is_read'] == true || json['is_read'] == 1,
      createdAt: dt,
      formattedTime: timeStr,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reseller_id': resellerId,
      'user_id': userId,
      'sender_type': senderType,
      'is_me': isMe,
      'type': type,
      'message': message,
      'media_url': mediaUrl,
      'duration': duration,
      'coins_amount': coinsAmount,
      'is_read': isRead,
      'created_at': createdAt?.toIso8601String(),
      'formatted_time': formattedTime,
    };
  }
}
