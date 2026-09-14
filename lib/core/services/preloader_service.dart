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

    Future.microtask(() async {
      try {
        await FastApiClient.init();
        final token = await AuthApiService.getToken();

        if (token != null && token.isNotEmpty) {
          // Parallel background pre-fetching with isolated error shields
          await Future.wait([
            // 1. Home Feed Streamers
            ProfileApiService.preloadHomeFeedInBackground().catchError((_) => null),
            // 2. Spend Less / VIP Monthly Cards
            VipCardsApiService.getVipCards().catchError((_) => <String, dynamic>{}),
            // 3. User Bag & Backpack Inventory
            BagApiService.getBagInventory().catchError((_) => <String, dynamic>{}),
            // 4. KYC Status & Verification Badge
            KycApiService.getKycStatus().catchError((_) => <String, dynamic>{}),
            // 5. Wallet Balance, Payment Methods & Coin Packages
            WalletApiService.getWalletBalance().catchError((_) => null),
            WalletApiService.getPaymentMethods().catchError((_) => <Map<String, dynamic>>[]),
            WalletApiService.getCoinPackages().catchError((_) => <Map<String, dynamic>>[]),
            // 6. Messages & Inbox Conversations
            ChatApiService.getConversations().catchError((_) => <dynamic>[]),
            // 7. Notification Unread Alerts
            NotificationApiService.instance.fetchNotifications().catchError((_) => null),
            // 8. Remote Config & Feature Toggles
            RemoteConfigService.instance.fetchRemoteConfig().catchError((_) => null),
          ], eagerError: false).timeout(const Duration(seconds: 8), onTimeout: () => []);
        }
      } catch (_) {}
    });
  }
}
