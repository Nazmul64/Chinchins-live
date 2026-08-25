class ModelProfile {
  final String id;
  final String name;
  final int age;
  final String location;
  final String intro;
  final List<String> languages;
  final List<String> tags;
  final int level;
  final String avatarUrl;
  final List<String> galleryUrls;
  final int charmLevel;
  final String topFan;
  final int pricePerMin;
  final bool isOnline;
  final bool isVerified;
  final bool hasExtraGems;
  final String? customBadge;
  final String closeFriendsStatus;
  final Map<String, int> receivedGifts;

  const ModelProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.location,
    required this.intro,
    required this.languages,
    this.tags = const ['Live video', 'Music', 'Singing', 'Chat'],
    this.level = 4,
    required this.avatarUrl,
    required this.galleryUrls,
    this.charmLevel = 98,
    this.topFan = 'Prince_01',
    this.pricePerMin = 1800,
    this.isOnline = true,
    this.isVerified = true,
    this.hasExtraGems = false,
    this.customBadge,
    this.closeFriendsStatus = 'Close Friends (0/3)',
    this.receivedGifts = const {},
  });

  /// Factory constructor to parse Laravel User API JSON response
  factory ModelProfile.fromJson(Map<String, dynamic> json) {
    // Parse gallery URLs
    List<String> parsedGallery = [];
    if (json['gallery_image_urls'] is List) {
      parsedGallery = List<String>.from(json['gallery_image_urls']);
    } else if (json['gallery_images'] is List) {
      parsedGallery = List<String>.from(json['gallery_images']);
    }

    // Default fallback gallery if empty
    if (parsedGallery.isEmpty) {
      final avatar = json['avatar_url'] ?? json['avatar'];
      if (avatar != null && avatar.toString().isNotEmpty) {
        parsedGallery.add(avatar.toString());
      }
    }

    // Parse languages
    List<String> parsedLanguages = ['English', 'Urdu'];
    if (json['languages'] is List) {
      parsedLanguages = List<String>.from(json['languages']);
    }

    // Parse tags
    List<String> parsedTags = ['Live video', 'Music', 'Singing', 'Chat'];
    if (json['tags'] is List) {
      parsedTags = List<String>.from(json['tags']);
    }

    // Parse level
    int parsedLevel = 4;
    final rawLevel = json['level']?.toString() ?? 'Lv4';
    final levelDigits = rawLevel.replaceAll(RegExp(r'[^0-9]'), '');
    if (levelDigits.isNotEmpty) {
      parsedLevel = int.tryParse(levelDigits) ?? 4;
    }

    // Account ID or primary ID
    final accountId = json['account_id']?.toString() ?? json['id']?.toString() ?? '602281635';

    // Name / Display Name
    final displayName = json['display_name'] ?? json['nickname'] ?? json['name'] ?? 'Ayeena04';

    // Avatar URL
    final avatar = json['avatar_url'] ??
        json['avatar'] ??
        (parsedGallery.isNotEmpty ? parsedGallery.first : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300');

    return ModelProfile(
      id: accountId,
      name: displayName,
      age: json['age'] is int ? json['age'] : (int.tryParse('${json['age']}') ?? 27),
      location: json['country'] ?? json['location'] ?? 'Pakistan',
      intro: json['introduction'] ?? json['intro'] ?? 'Sweet girl looking for honest talk ❤️',
      languages: parsedLanguages,
      tags: parsedTags,
      level: parsedLevel,
      avatarUrl: avatar.toString(),
      galleryUrls: parsedGallery,
      charmLevel: 98,
      topFan: 'Prince_01',
      pricePerMin: json['video_call_rate'] is int
          ? json['video_call_rate']
          : (int.tryParse('${json['video_call_rate']}') ?? 1800),
      isOnline: json['is_active'] == true || json['is_active'] == 1 || json['status'] == 'Active',
      isVerified: json['is_verified'] == true || json['is_verified'] == 1,
      closeFriendsStatus: 'Close Friends (${json['close_friends_count'] ?? 0}/3)',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'account_id': id,
      'name': name,
      'age': age,
      'country': location,
      'introduction': intro,
      'languages': languages,
      'tags': tags,
      'level': 'Lv$level',
      'avatar_url': avatarUrl,
      'gallery_image_urls': galleryUrls,
      'video_call_rate': pricePerMin,
      'is_active': isOnline,
      'is_verified': isVerified,
    };
  }
}
