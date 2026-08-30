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

  // Wallet, Payment, Deposit & Withdrawal endpoints
  static String get walletBalance => '$baseUrl/wallet/balance';
  static String get paymentMethods => '$baseUrl/payment-methods';
  static String get coinPackages => '$baseUrl/coin-packages';
  static String get depositSubmit => '$baseUrl/deposit/submit';
  static String get depositRequest => '$baseUrl/deposit/submit';
  static String get depositHistory => '$baseUrl/deposit/history';
  static String get walletTransactions => '$baseUrl/wallet/transactions';
  
  // Withdrawal / Cash Out endpoints
  static String get withdrawInfo => '$baseUrl/withdraw/info';
  static String get withdrawCalculate => '$baseUrl/withdraw/calculate';
  static String get withdrawSubmit => '$baseUrl/withdraw/submit';
  static String get withdrawHistory => '$baseUrl/withdraw/history';
  static String withdrawDetails(String id) => '$baseUrl/withdraw/$id';
  
  // Video & Audio Calling endpoints (Legacy & Standard RESTful /api/calls)
  static String get calls => '$baseUrl/calls';
  static String callById(dynamic id) => '$baseUrl/calls/$id';
  static String callAcceptById(dynamic id) => '$baseUrl/calls/$id/accept';
  static String callRejectById(dynamic id) => '$baseUrl/calls/$id/reject';
  static String callCancelById(dynamic id) => '$baseUrl/calls/$id/cancel';
  static String callEndById(dynamic id) => '$baseUrl/calls/$id/end';
  static String callOfferById(dynamic id) => '$baseUrl/calls/$id/offer';
  static String callAnswerById(dynamic id) => '$baseUrl/calls/$id/answer';
  static String callIceCandidateById(dynamic id) => '$baseUrl/calls/$id/ice-candidate';
  static String callSignalById(dynamic id) => '$baseUrl/calls/$id/signal';

  static String get callConfig => '$baseUrl/call/config';
  static String get callRandomMatch => '$baseUrl/call/random-match';
  static String get callInitiate => '$baseUrl/call/initiate';
  static String get callIncoming => '$baseUrl/call/incoming';
  static String callStatus(dynamic id) => '$baseUrl/call/status/$id';
  static String get callRinging => '$baseUrl/call/ringing';
  static String get callAccept => '$baseUrl/call/accept';
  static String get callReject => '$baseUrl/call/reject';
  static String get callCancel => '$baseUrl/call/cancel';
  static String get callStart => '$baseUrl/call/start';
  static String get callIceServers => '$baseUrl/call/ice-servers';
  static String get callSignalSend => '$baseUrl/call/signal/send';
  static String get callSignalReceive => '$baseUrl/call/signal/receive';
  static String get callSignalClear => '$baseUrl/call/signal/clear';
  static String get callEnd => '$baseUrl/call/end';
  static String get callDeductInterval => '$baseUrl/call/deduct-interval';
  static String get callHistory => '$baseUrl/call/history';

  // User Presence & Heartbeat endpoints
  static String get userHeartbeat => '$baseUrl/user/heartbeat';
  static String get userStatus => '$baseUrl/user/status';
  static String get userFcmToken => '$baseUrl/user/fcm-token';
  static String userPresence(String id) => '$baseUrl/user/presence/$id';
  static String get usersOnline => '$baseUrl/users/online';
  static String get callWaitIncoming => '$baseUrl/call/wait-incoming';

  // KYC Verification endpoints
  static String get kycInstructions => '$baseUrl/kyc/instructions';
  static String get kycSubmit => '$baseUrl/kyc/submit';
  static String get kycStatus => '$baseUrl/kyc/status';
  static String get kycAiDetect => '$baseUrl/kyc/ai-detect';
  static String get kycFaceVerifyStep => '$baseUrl/kyc/face/verify-step';
  static String get kycFaceUnlock => '$baseUrl/kyc/face/unlock';
  static String get kycVideoVerify => '$baseUrl/kyc/video-verify';
}



