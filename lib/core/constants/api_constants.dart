class ApiConstants {
  // Base URLs - Configured for live production server
  static const String _liveProduction = 'https://chinchins.live/api';
  static const String localDevAndroid = 'http://10.0.2.2:8000/api';
  static const String localDevWeb = 'http://127.0.0.1:8000/api';

  // WebSocket / Reverb Config
  static const String reverbHost = 'ws.chinchins.live';
  static const int reverbPort = 443;
  static const String reverbScheme = 'https';
  static const String reverbKey = 'chinchins_app_key';

  // Customizable baseUrl (can be overridden if testing with custom server IP/URL)
  static String? customBaseUrl;

  static String get baseUrl {
    if (customBaseUrl != null && customBaseUrl!.isNotEmpty) {
      return customBaseUrl!;
    }
    return _liveProduction;
  }

  // Auth endpoints
  static String get register => '$baseUrl/register';
  static String get login => '$baseUrl/login';
  static String get userProfile => '$baseUrl/user';
  static String get logout => '$baseUrl/logout';

  // Profile endpoints
  static String get profileMe => '$baseUrl/profile/me';
  static String profileById(String id) => '$baseUrl/profile/$id';
  static String get profileUpdate => '$baseUrl/profile/update';
  static String get uploadPhotos => '$baseUrl/profile/upload-photos';
  static String get uploadAvatar => '$baseUrl/profile/upload-avatar';
  static String get uploadCover => '$baseUrl/profile/upload-cover';
  static String get deletePhoto => '$baseUrl/profile/delete-photo';
  static String get profileStatus => '$baseUrl/profile/status';
}
