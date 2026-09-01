class AppNotification {
  final int id;
  final String type; // 'profile_view', 'message', 'gift', 'call'
  final String title;
  final String message;
  final bool isRead;
  final DateTime? createdAt;
  final Map<String, dynamic> data;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.isRead = false,
    this.createdAt,
    this.data = const {},
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['created_at'] != null) {
      try {
        parsedDate = DateTime.parse(json['created_at'].toString());
      } catch (_) {}
    }

    return AppNotification(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      type: json['type']?.toString() ?? 'general',
      title: json['title']?.toString() ?? 'Notification',
      message: json['message']?.toString() ?? '',
      isRead: json['is_read'] == true || json['is_read'] == 1,
      createdAt: parsedDate,
      data: json['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['data'])
          : (json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'message': message,
      'is_read': isRead,
      'created_at': createdAt?.toIso8601String(),
      'data': data,
    };
  }

  // Helper getters for UI
  String? get viewerAvatar => data['avatar_url']?.toString() ?? data['avatar']?.toString();
  String? get viewerName => data['name']?.toString() ?? data['display_name']?.toString();
  int? get viewerId => data['viewer_id'] is int
      ? data['viewer_id']
      : int.tryParse(data['viewer_id']?.toString() ?? '');
  bool get isViewerOnline => data['is_online'] == true;

  String? get giftName => data['gift_name']?.toString();
  String? get giftIcon => data['gift_icon']?.toString();
  int? get coinsEarned => data['coins_earned'] is int
      ? data['coins_earned']
      : int.tryParse(data['coins_earned']?.toString() ?? '');
}
