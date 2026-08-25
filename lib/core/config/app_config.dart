import '../constants/api_constants.dart';

class AppConfig {
  static const String appName = 'Chinchins Live';
  static String get baseUrl => ApiConstants.baseUrl;
  static const String reverbAppKey = 'chinchins_app_key';
  static const String authEndpoint = 'https://chinchins.live/broadcasting/auth';
  static const String host = 'ws.chinchins.live';
  static const int port = 443;
}
