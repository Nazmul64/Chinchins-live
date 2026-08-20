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
    this.tags = const ['Music 🎵', 'Dating 💕', 'Dancing 💃', 'Movies 🎬'],
    this.level = 7,
    required this.avatarUrl,
    required this.galleryUrls,
    required this.charmLevel,
    required this.topFan,
    required this.pricePerMin,
    this.isOnline = true,
    this.isVerified = true,
    this.hasExtraGems = false,
    this.customBadge,
    this.closeFriendsStatus = 'Close Friends (0/3)',
    this.receivedGifts = const {},
  });
}
