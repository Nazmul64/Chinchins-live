import '../widgets/cached_image_loader.dart';

class ModelProfile {
  final String id;
  final String name;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? email;
  final String? gender;
  final String? city;
  final int age;
  final String location;
  final String intro;
  final List<String> languages;
  final List<String> tags;
  final int level;
  final String avatarUrl;
  final String? coverPhotoUrl;
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
    this.firstName,
    this.lastName,
    this.phone,
    this.email,
    this.gender,
    this.city,
    required this.age,
    required this.location,
    required this.intro,
    required this.languages,
    this.tags = const ['Live video', 'Music', 'Singing', 'Chat'],
    this.level = 4,
    required this.avatarUrl,
    this.coverPhotoUrl,
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

  /// Computed full name
  String get fullName {
    if (firstName != null && firstName!.trim().isNotEmpty) {
      if (lastName != null && lastName!.trim().isNotEmpty) {
        return '${firstName!.trim()} ${lastName!.trim()}';
      }
      return firstName!.trim();
    }
    return name;
  }

  /// Factory constructor to parse Laravel User API JSON response
  factory ModelProfile.fromJson(Map<String, dynamic> json) {
    // Helper to normalize image URLs
    String normalizeImg(dynamic raw) {
      if (raw == null) return '';
      return CachedImageLoader.normalize(raw.toString().trim());
    }

    // Parse gallery URLs
    List<String> parsedGallery = [];
    if (json['gallery_image_urls'] is List) {
      parsedGallery = (json['gallery_image_urls'] as List)
          .map((e) => normalizeImg(e))
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (json['gallery_images'] is List) {
      parsedGallery = (json['gallery_images'] as List)
          .map((e) => normalizeImg(e))
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (json['photos'] is List) {
      parsedGallery = (json['photos'] as List)
          .map((e) => normalizeImg(e))
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (json['gallery'] is List) {
      parsedGallery = (json['gallery'] as List)
          .map((e) => normalizeImg(e))
          .where((e) => e.isNotEmpty)
          .toList();
    }

    // Parse languages
    List<String> parsedLanguages = ['English', 'Bengali'];
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

    final firstName = json['first_name']?.toString();
    final lastName = json['last_name']?.toString();
    final phone = json['phone']?.toString() ?? json['phone_number']?.toString();
    final email = json['email']?.toString();
    final gender = json['gender']?.toString() ?? 'female';
    final city = json['city']?.toString();

    // Full name or display name
    String? combinedName;
    if (firstName != null && firstName.trim().isNotEmpty) {
      combinedName = firstName.trim();
      if (lastName != null && lastName.trim().isNotEmpty) {
        combinedName += ' ${lastName.trim()}';
      }
    }

    final displayName = json['display_name'] ??
        json['nickname'] ??
        combinedName ??
        json['name'] ??
        'User';

    // Avatar URL
    final rawAvatar = json['avatar_url'] ?? json['avatar'] ?? json['profile_picture'] ?? json['photo'];
    String avatar = normalizeImg(rawAvatar);
    if (avatar.isEmpty && parsedGallery.isNotEmpty) {
      avatar = parsedGallery.first;
    }
    if (avatar.isEmpty) {
      avatar = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300';
    }

    // Default fallback gallery if empty
    if (parsedGallery.isEmpty) {
      parsedGallery.add(avatar);
    }

    // Cover photo URL
    final rawCover = json['cover_photo_url'] ?? json['cover_photo'] ?? json['cover'] ?? json['cover_image'];
    String coverPhoto = normalizeImg(rawCover);
    if (coverPhoto.isEmpty) {
      coverPhoto = parsedGallery.isNotEmpty ? parsedGallery.first : avatar;
    }

    return ModelProfile(
      id: accountId,
      name: displayName,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      email: email,
      gender: gender,
      city: city,
      age: json['age'] is int ? json['age'] : (int.tryParse('${json['age']}') ?? 25),
      location: json['country'] ?? json['location'] ?? 'Bangladesh',
      intro: json['introduction'] ?? json['intro'] ?? 'Welcome to Chinchins Live! ✨',
      languages: parsedLanguages,
      tags: parsedTags,
      level: parsedLevel,
      avatarUrl: avatar,
      coverPhotoUrl: coverPhoto,
      galleryUrls: parsedGallery,
      charmLevel: 98,
      topFan: 'Prince_01',
      pricePerMin: json['video_call_rate'] is int
          ? json['video_call_rate']
          : (int.tryParse('${json['video_call_rate']}') ?? 1800),
      isOnline: json['is_active'] == true || json['is_active'] == 1 || json['is_active'] == '1' || json['status'] == 'Active',
      isVerified: json['is_verified'] == true || json['is_verified'] == 1 || json['is_verified'] == '1',
      closeFriendsStatus: 'Close Friends (${json['close_friends_count'] ?? 0}/3)',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'account_id': id,
      'name': name,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'email': email,
      'gender': gender,
      'city': city,
      'age': age,
      'country': location,
      'introduction': intro,
      'languages': languages,
      'tags': tags,
      'level': 'Lv$level',
      'avatar_url': avatarUrl,
      'cover_photo_url': coverPhotoUrl,
      'gallery_image_urls': galleryUrls,
      'video_call_rate': pricePerMin,
      'is_active': isOnline,
      'is_verified': isVerified,
    };
  }
}
