import '../widgets/cached_image_loader.dart';

class LiveGiftEvent {
  final String streamId;
  final int senderId;
  final String senderName;
  final String senderAvatar;
  final int giftId;
  final String giftName;
  final String iconUrl;
  final String fileUrl;
  final String format; // 'svga', 'lottie', 'webp', 'image', 'video'
  final String displayType; // 'fullscreen', 'bubble'
  final int coinsSpent;
  final int comboCount;
  final DateTime receivedAt;

  LiveGiftEvent({
    required this.streamId,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.giftId,
    required this.giftName,
    required this.iconUrl,
    required this.fileUrl,
    this.format = 'svga',
    this.displayType = 'fullscreen',
    this.coinsSpent = 0,
    this.comboCount = 1,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  factory LiveGiftEvent.fromJson(Map<String, dynamic> json) {
    final rawSenderId = json['sender_id'] ?? json['user_id'] ?? 0;
    final int sId = rawSenderId is int ? rawSenderId : (int.tryParse('$rawSenderId') ?? 0);

    final rawGiftId = json['gift_id'] ?? json['id'] ?? 0;
    final int gId = rawGiftId is int ? rawGiftId : (int.tryParse('$rawGiftId') ?? 0);

    final rawCoins = json['coins_spent'] ?? json['coins'] ?? json['coin_price'] ?? 0;
    final int coins = rawCoins is int ? rawCoins : (int.tryParse('$rawCoins') ?? 0);

    final rawCombo = json['combo_count'] ?? json['quantity'] ?? 1;
    final int combo = rawCombo is int ? rawCombo : (int.tryParse('$rawCombo') ?? 1);

    final rawAvatar = json['sender_avatar'] ?? json['avatar_url'] ?? json['avatar'] ?? '';
    final rawIcon = json['icon_url'] ?? json['image_url'] ?? json['image'] ?? '';
    final rawFile = json['file_url'] ?? json['animation_url'] ?? json['animation_full_url'] ?? '';

    return LiveGiftEvent(
      streamId: json['stream_id']?.toString() ?? '',
      senderId: sId,
      senderName: json['sender_name']?.toString() ?? json['name']?.toString() ?? 'Fan',
      senderAvatar: CachedImageLoader.normalize(rawAvatar),
      giftId: gId,
      giftName: json['gift_name']?.toString() ?? json['name']?.toString() ?? 'Gift',
      iconUrl: CachedImageLoader.normalize(rawIcon),
      fileUrl: CachedImageLoader.normalize(rawFile),
      format: (json['format']?.toString() ?? 'svga').toLowerCase(),
      displayType: (json['display_type']?.toString() ?? 'fullscreen').toLowerCase(),
      coinsSpent: coins,
      comboCount: combo > 0 ? combo : 1,
      receivedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stream_id': streamId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_avatar': senderAvatar,
      'gift_id': giftId,
      'gift_name': giftName,
      'icon_url': iconUrl,
      'file_url': fileUrl,
      'format': format,
      'display_type': displayType,
      'coins_spent': coinsSpent,
      'combo_count': comboCount,
    };
  }
}
