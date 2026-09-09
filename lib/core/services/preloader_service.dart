import 'dart:async';
import '../../features/auth/services/auth_api_service.dart';
import '../../features/bag/services/bag_api_service.dart';
import '../../features/chat/services/chat_api_service.dart';
import '../../features/kyc/services/kyc_api_service.dart';
import '../../features/wallet/services/vip_cards_api_service.dart';
import '../../features/wallet/services/wallet_api_service.dart';
import 'fast_api_client.dart';
import 'notification_api_service.dart';
import 'profile_api_service.dart';
import 'remote_config_service.dart';

/// 🚀 PreloaderService: Ultra Fast Background Preloading for Zero-Lag Instant App UI (<100ms)
/// Pre-fetches all critical app pages and caches them in L1 RAM + L2 Disk before the user taps them.
class PreloaderService {
  static bool _hasPreloaded = false;

  /// Fire background preloading of all essential app modules in parallel
  static void preloadAppEssentials() {
    if (_hasPreloaded) return;
    _hasPreloaded = true;

    scheduleMicrotask(() async {
      try {
        await FastApiClient.init();
        final token = await AuthApiService.getToken();

        if (token != null && token.isNotEmpty) {
          // Parallel background pre-fetching
          await Future.wait([
            // 1. Home Feed Streamers
            ProfileApiService.preloadHomeFeedInBackground(),
            // 2. Spend Less / VIP Monthly Cards
            VipCardsApiService.getVipCards(),
            // 3. User Bag & Backpack Inventory
            BagApiService.getBagInventory(),
            // 4. KYC Status & Verification Badge
            KycApiService.getKycStatus(),
            // 5. Wallet Balance, Payment Methods & Coin Packages
            WalletApiService.getWalletBalance(),
            WalletApiService.getPaymentMethods(),
            WalletApiService.getCoinPackages(),
            // 6. Messages & Inbox Conversations
            ChatApiService.getConversations(),
            // 7. Notification Unread Alerts
            NotificationApiService.instance.fetchNotifications(),
            // 8. Remote Config & Feature Toggles
            RemoteConfigService.instance.fetchRemoteConfig(),
          ]).timeout(const Duration(seconds: 12), onTimeout: () => []);
        }
      } catch (_) {}
    });
  }
}
