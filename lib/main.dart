import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_logger.dart';
import 'features/auth/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  AppLogger.info('AppInit', 'Chinchins Live Debug Mode Active');

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
  const ChinchinsLiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chinchins Live',
      debugShowCheckedModeBanner: true,
      theme: AppTheme.darkTheme,
      home: const LoginScreen(),
    );
  }
}