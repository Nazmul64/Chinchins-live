import '../constants/api_constants.dart';

class AppConfig {
  static const String appName = 'Chinchins Live';
  static String get baseUrl => ApiConstants.baseUrl;
  static const String reverbAppKey = 'chinchins_app_key';
  static const String reverbHost = 'chinchins.live';
  static const int reverbWsPort = 8080;
  static const int reverbWssPort = 443;
  static const bool reverbUseTLS = true;
  static const String authEndpoint = 'https://chinchins.live/api/broadcasting/auth';
  static const String host = 'chinchins.live';
  static const int port = 443;
}
