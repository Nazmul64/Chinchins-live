class ApiConstants {
  // Live Production Server
  static const String liveDomain = 'https://chinchins.live';
  static const String baseUrl = 'https://chinchins.live/api';

  // WebSocket / Reverb Config
  static const String reverbHost = 'ws.chinchins.live';
  static const int reverbPort = 443;
  static const String reverbScheme = 'https';
  static const String reverbKey = 'chinchins_app_key';

  // Auth endpoints
  static String get register => '$baseUrl/register';
  static String get login => '$baseUrl/login';
  static String get userProfile => '$baseUrl/user';
  static String get logout => '$baseUrl/logout';

  // Feed / Home endpoints
  static String get homeFeed => '$baseUrl/home';
  static String get users => '$baseUrl/users';

  // Profile endpoints
  static String get profileMe => '$baseUrl/profile/me';
  static String profileById(String id) => '$baseUrl/profile/$id';
  static String get profileUpdate => '$baseUrl/profile/update';
  static String get uploadPhotos => '$baseUrl/profile/upload-photos';
  static String get uploadAvatar => '$baseUrl/profile/upload-avatar';
  static String get deleteAvatar => '$baseUrl/profile/delete-avatar';
  static String get uploadCover => '$baseUrl/profile/upload-cover';
  static String get deleteCover => '$baseUrl/profile/delete-cover';
  static String get deletePhoto => '$baseUrl/profile/delete-photo';
  static String get updateGallery => '$baseUrl/profile/update-gallery';
  static String get clearGallery => '$baseUrl/profile/clear-gallery';
  static String get profileStatus => '$baseUrl/profile/status';

  // Wallet, Payment & Deposit endpoints
  static String get walletBalance => '$baseUrl/wallet/balance';
  static String get paymentMethods => '$baseUrl/payment-methods';
  static String get coinPackages => '$baseUrl/coin-packages';
  static String get depositRequest => '$baseUrl/deposit/request';
  static String get depositHistory => '$baseUrl/deposit/history';
  static String get walletTransactions => '$baseUrl/wallet/transactions';
  
  // Video Calling endpoints
  static String get callInitiate => '$baseUrl/call/initiate';
  static String get callStart => '$baseUrl/call/start';
  static String get callEnd => '$baseUrl/call/end';
  static String get callDeductInterval => '$baseUrl/call/deduct-interval';
  static String get callHistory => '$baseUrl/call/history';

  // KYC Verification endpoints
  static String get kycInstructions => '$baseUrl/kyc/instructions';
  static String get kycSubmit => '$baseUrl/kyc/submit';
  static String get kycStatus => '$baseUrl/kyc/status';
  static String get kycAiDetect => '$baseUrl/kyc/ai-detect';
}

