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
  static String get register => '$baseUrl/auth/register';
  static String get legacyRegister => '$baseUrl/register';
  static String get login => '$baseUrl/auth/login';
  static String get legacyLogin => '$baseUrl/login';
  static String get authCheck => '$baseUrl/auth/check';
  static String get authMe => '$baseUrl/auth/me';
  static String get userProfile => '$baseUrl/user';
  static String get logout => '$baseUrl/auth/logout';
  static String get legacyLogout => '$baseUrl/logout';
  static String get forgotPassword => '$baseUrl/auth/forgot-password';
  static String get legacyForgotPassword => '$baseUrl/forgot-password';
  static String get verifyResetCode => '$baseUrl/auth/verify-reset-code';
  static String get legacyVerifyResetCode => '$baseUrl/verify-reset-code';
  static String get resetPassword => '$baseUrl/auth/reset-password';
  static String get legacyResetPassword => '$baseUrl/reset-password';

  // App Legal & Settings (Admin Configurable)
  static String get appTerms => '$baseUrl/app/terms';
  static String get appPrivacy => '$baseUrl/app/privacy-policy';
  static String get appAbout => '$baseUrl/app/about';

  // Feed / Home / Search endpoints
  static String get countries => '$baseUrl/countries';
  static String get homeFeed => '$baseUrl/home';
  static String get users => '$baseUrl/users';
  static String get search => '$baseUrl/search';
  static String get usersSearch => '$baseUrl/users/search';
  static String searchUsers(String query) => '$baseUrl/search?q=${Uri.encodeComponent(query)}';

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
  static String get profileBases => '$baseUrl/profile-bases';
  static String get levels => '$baseUrl/profile-bases';
  static String get levelStatus => '$baseUrl/user/level-status';
  static String levelStatusForUser(dynamic id) => '$baseUrl/user/level-status?user_id=$id';

  // Wallet, Payment, Deposit & Withdrawal endpoints
  static String get walletBalance => '$baseUrl/wallet/balance';
  static String get paymentMethods => '$baseUrl/payment-methods';
  static String get coinPackages => '$baseUrl/coin-packages';
  static String get depositSubmit => '$baseUrl/deposit/submit';
  static String get depositRequest => '$baseUrl/deposit/submit';
  static String get depositHistory => '$baseUrl/deposit/history';
  static String get walletTransactions => '$baseUrl/wallet/transactions';
  
  // Spend Less, Get More Gems & VIP Privilege Cards (Monthly & Weekly Cards)
  static String get spendLessGetMore => '$baseUrl/spend-less-get-more';
  static String get spendLessGetMoreBanner => '$baseUrl/spend-less-get-more/banner';
  static String get spendLessGetMoreMy => '$baseUrl/spend-less-get-more/my';
  static String get spendLessGetMorePurchase => '$baseUrl/spend-less-get-more/purchase';
  static String get spendLessGetMoreClaim => '$baseUrl/spend-less-get-more/claim';
  
  // Endpoint aliases
  static String get vipCards => spendLessGetMore;
  static String get monthlyCards => spendLessGetMore;
  static String get vipBanner => spendLessGetMoreBanner;
  static String get vipCardsMySubscriptions => spendLessGetMoreMy;
  static String get vipCardsPurchase => spendLessGetMorePurchase;
  static String get vipCardsClaimDaily => spendLessGetMoreClaim;
  
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
  static String get checkCallPermission => '$baseUrl/call/check-permission';
  static String get canCall => '$baseUrl/call/can-call';
  static String get callIncoming => '$baseUrl/call/incoming';
  static String callStatus(dynamic id) => '$baseUrl/call/status/$id';
  static String get callRinging => '$baseUrl/call/ringing';
  static String get callAccept => '$baseUrl/call/accept';
  static String get callReject => '$baseUrl/call/reject';
  static String get callCancel => '$baseUrl/call/cancel';
  static String get callStart => '$baseUrl/call/start';
  static String get callConnected => '$baseUrl/call/connected';
  static String get callIceServers => '$baseUrl/call/ice-servers';
  static String get callSignalSend => '$baseUrl/call/signal/send';
  static String get callSignalReceive => '$baseUrl/call/signal/receive';
  static String get callSignalClear => '$baseUrl/call/signal/clear';
  static String get callEnd => '$baseUrl/call/end';
  static String get callDeductInterval => '$baseUrl/call/deduct-interval';
  static String get callHistory => '$baseUrl/call/history';
  static String get callRechargeSheet => '$baseUrl/call/recharge-sheet';
  static String get callQuickMessages => '$baseUrl/call/quick-messages';
  static String get callSendQuickMessage => '$baseUrl/call/send-quick-message';

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
  // KYC Video Verification
  static String get kycVideoVerify => '$baseUrl/kyc/video-verify';

  // Match Tab & Random Match endpoints
  static String get match => '$baseUrl/match';
  static String get matchStatus => '$baseUrl/match/status';
  static String get matchHosts => '$baseUrl/match/hosts';
  static String get matchStart => '$baseUrl/match/start';

  // Profile View Notification & Auto-Callback Trigger
  static String profileView(dynamic id) => '$baseUrl/profile/$id/view';

  // In-App Messaging & Chat endpoints
  static String get messages => '$baseUrl/messages';
  static String get messagesConversations => '$baseUrl/messages/conversations';
  static String messagesByUser(dynamic userId) => '$baseUrl/messages/$userId';
  static String get messageSend => '$baseUrl/messages/send';
  static String get messagesRead => '$baseUrl/messages/read';
  static String get checkChatPermission => '$baseUrl/chat/check-permission';
  static String get checkMessagesPermission => '$baseUrl/messages/check-permission';

  // Gifts & Rewards Endpoints
  static String get giftsCatalog => '$baseUrl/gifts';
  static String get giftsStore => '$baseUrl/gifts/catalog';
  static String giftsReceived(dynamic userId) => '$baseUrl/gifts/received/$userId';
  static String profileGifts(dynamic userId) => '$baseUrl/profile/$userId/gifts';
  static String get giftsReceivedMe => '$baseUrl/gifts/received/me';
  static String get sendGift => '$baseUrl/gifts/send';
  static String profileTopFans(dynamic userId) => '$baseUrl/profile/$userId/top-fans';
  static String profileLike(dynamic userId) => '$baseUrl/profile/$userId/like';
  static String profileHi(dynamic userId) => '$baseUrl/profile/$userId/hi';
  static String get chatSendHi => '$baseUrl/chat/send-hi';
  static String get userLikes => '$baseUrl/profile/likes';
  static String get profileLikes => '$baseUrl/profile/likes';
  static String likesByType(String type) => '$baseUrl/profile/likes?type=$type';

  // App OTA In-App Updates, Remote Config & Device Registration
  static String get appCheckUpdate => '$baseUrl/app/check-update';
  static String get appRemoteConfig => '$baseUrl/app/remote-config';
  static String get appConfig => '$baseUrl/app/config';
  static String get appDeviceRegister => '$baseUrl/app/device/register';
  static String get deviceRegister => '$baseUrl/device/register';

  // Real-Time Notifications & Push Engine
  static String get notifications => '$baseUrl/notifications';
  static String get userNotifications => '$baseUrl/user/notifications';
  static String get testPushNotification => '$baseUrl/notifications/test-push';

  // My Bag & User Inventory Endpoints
  static String get bag => '$baseUrl/bag';
  static String get myBag => '$baseUrl/bag';
  static String get bagStore => '$baseUrl/bag/store';
  static String get bagPurchase => '$baseUrl/bag/purchase';
  static String get bagUse => '$baseUrl/bag/use';
  static String get bagEquip => '$baseUrl/bag/use';
  static String get bagUnequip => '$baseUrl/bag/unequip';
  static String get bagGift => '$baseUrl/bag/gift';
  static String get bagSearchUser => '$baseUrl/bag/search-user';

  // In-Chat & In-Call Recharge Modal Endpoints
  static String get rechargeModalData => '$baseUrl/recharge/modal-data';
  static String get coinPackagesRechargeModal => '$baseUrl/coin-packages/recharge-modal';

  // Payment Options & Reseller System Endpoints
  static String get paymentOptions => '$baseUrl/payment-options';
  static String get resellers => '$baseUrl/resellers';
  static String resellerMessages(dynamic resellerId) => '$baseUrl/resellers/$resellerId/messages';
  static String get resellerChatSend => '$baseUrl/reseller/chat/send';
  static String get resellerChatUpload => '$baseUrl/reseller/chat/upload';
  static String get resellerValidateUser => '$baseUrl/reseller/validate-user';
  static String get resellerTransferCoins => '$baseUrl/reseller/transfer-coins';

  // Account Deletion & Lifecycle Management endpoints
  static String get deleteAccount => '$baseUrl/user/delete-account';
  static String get deleteUserAccount => '$baseUrl/user/account';
  static String get deleteUserAccountAlias => '$baseUrl/user/account/delete';

  // Google Play In-App Purchase Endpoints
  static String get googlePlayVerify => '$baseUrl/payment/google-play/verify';
  static String get googlePlayVerifyAlias => '$baseUrl/google-play/verify-purchase';

  // User Block & Moderation Report endpoints
  static String get chatBlock => '$baseUrl/chat/block';
  static String get userBlock => '$baseUrl/user/block';
  static String get chatUnblock => '$baseUrl/chat/unblock';
  static String get userUnblock => '$baseUrl/user/unblock';
  static String get chatReport => '$baseUrl/chat/report';
  static String get userReport => '$baseUrl/user/report';
  static String get reportReasons => '$baseUrl/chat/report-reasons';

  // 24/7 Customer Service & Admin Live Support Endpoints
  static String get supportMessages => '$baseUrl/support/messages';
  static String get supportSend => '$baseUrl/support/send';
  static String get supportUpload => '$baseUrl/support/upload';
  static String get supportUnreadCount => '$baseUrl/support/unread-count';

  // Party Room (Voice & Video Multi-Guest) Endpoints
  static String get partyRoomsConfig => '$baseUrl/party-rooms/config';
  static String get partyRooms => '$baseUrl/party-rooms';
  static String get partyRoomsCreate => '$baseUrl/party-rooms/create';
  static String partyRoomById(dynamic id) => '$baseUrl/party-rooms/$id';
  static String partyRoomJoin(dynamic id) => '$baseUrl/party-rooms/$id/join';
  static String partyRoomLeave(dynamic id) => '$baseUrl/party-rooms/$id/leave';
  static String partyRoomEnd(dynamic id) => '$baseUrl/party-rooms/$id/end';
  static String partyRoomSearchInvitees(dynamic id, [String? query]) =>
      '$baseUrl/party-rooms/$id/search-invitees${query != null && query.trim().isNotEmpty ? '?query=${Uri.encodeComponent(query.trim())}' : ''}';
  static String partyRoomInviteGuest(dynamic id) => '$baseUrl/party-rooms/$id/invite-guest';
  static String partyRoomRespondInvite(dynamic id) => '$baseUrl/party-rooms/$id/respond-invite';
  static String partyRoomTakeSeat(dynamic id) => '$baseUrl/party-rooms/$id/take-seat';
  static String partyRoomLeaveSeat(dynamic id) => '$baseUrl/party-rooms/$id/leave-seat';
  static String partyRoomKickSeat(dynamic id) => '$baseUrl/party-rooms/$id/kick-seat';
  static String partyRoomToggleMic(dynamic id) => '$baseUrl/party-rooms/$id/toggle-mic';
  static String partyRoomToggleVideo(dynamic id) => '$baseUrl/party-rooms/$id/toggle-video';
  static String partyRoomMessages(dynamic id) => '$baseUrl/party-rooms/$id/messages';
  static String partyRoomSendMessage(dynamic id) => '$baseUrl/party-rooms/$id/messages/send';
  static String partyRoomSendGift(dynamic id) => '$baseUrl/party-rooms/$id/send-gift';
  static String partyRoomDeductInterval(dynamic id) => '$baseUrl/party-rooms/$id/deduct-interval';
}



