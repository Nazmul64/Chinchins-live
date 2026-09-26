import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/services/app_cache_service.dart';
import 'core/services/customer_profile_icon_service.dart';
import 'core/services/fast_api_client.dart';
import 'core/services/hive_cache_service.dart';
import 'core/services/local_vault.dart';
import 'core/services/screen_protection_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_logger.dart';
import 'features/auth/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⚡ Initialize L1/L2 Local Fast Storage, Hive & Disk Caches
  await HiveCacheService.init();
  await FastApiClient.init();
  await LocalVault.init();
  await CustomerProfileIconService.init();

  // ⚡ Fast In-Memory Static Data Pre-fetching (Non-blocking)
  AppCacheService.prefetchAllStaticData();
  CustomerProfileIconService.syncIconsBackground();

  // Allow screenshots and screen recording
  await ScreenProtectionService.instance.allowScreenshots();

  // Global Flutter framework error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.error('FlutterError', details.exceptionAsString(), details.stack);
    FlutterError.presentError(details);
  };

  // Global Platform / Async error handling
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('PlatformDispatcher', error.toString(), stack);
    return true;
  };

  AppLogger.info('AppInit', 'Chinchins Live Production Active');
  // Set system UI overlay style to dark with translucent navigation
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF12101E),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ChinchinsLiveApp());
}

class ChinchinsLiveApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  const ChinchinsLiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Chinchins Live',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}