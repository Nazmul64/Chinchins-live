import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../models/remote_config.dart';
import '../utils/app_logger.dart';
import '../../features/auth/services/auth_api_service.dart';

class RemoteConfigService {
  static final RemoteConfigService instance = RemoteConfigService._internal();
  RemoteConfigService._internal();

  static const String _prefKeyRemoteConfig = 'cached_remote_config';

  RemoteConfig _currentConfig = const RemoteConfig();
  RemoteConfig get config => _currentConfig;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Stream/ValueNotifier for configuration updates
  final StreamController<RemoteConfig> _configStreamController =
      StreamController<RemoteConfig>.broadcast();
  Stream<RemoteConfig> get onConfigUpdated => _configStreamController.stream;

  /// Load cached config from SharedPreferences immediately
  Future<void> initFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString(_prefKeyRemoteConfig);
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final decoded = jsonDecode(cachedStr);
        if (decoded is Map<String, dynamic>) {
          _currentConfig = RemoteConfig.fromJson(decoded);
          _isInitialized = true;
          _configStreamController.add(_currentConfig);
        }
      }
    } catch (e) {
      AppLogger.error('RemoteConfigInitCacheError', e);
    }
  }

  /// Fetch remote configuration live from server
  Future<RemoteConfig?> fetchRemoteConfig() async {
    try {
      final token = await AuthApiService.getToken();
      final url = Uri.parse(ApiConstants.appRemoteConfig);
      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      http.Response response;
      try {
        response = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));
      } catch (_) {
        // Fallback to /api/app/config
        final fallbackUrl = Uri.parse(ApiConstants.appConfig);
        response = await http.get(fallbackUrl, headers: headers).timeout(const Duration(seconds: 10));
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final data = decoded['data'] is Map<String, dynamic>
              ? decoded['data'] as Map<String, dynamic>
              : (decoded['data'] is Map
                  ? Map<String, dynamic>.from(decoded['data'] as Map)
                  : Map<String, dynamic>.from(decoded));

          _currentConfig = RemoteConfig.fromJson(data);
          _isInitialized = true;
          _configStreamController.add(_currentConfig);

          // Cache in SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefKeyRemoteConfig, jsonEncode(_currentConfig.toJson()));

          AppLogger.info('RemoteConfig', 'Remote configurations loaded successfully.');
          return _currentConfig;
        }
      }
    } catch (e, st) {
      AppLogger.error('FetchRemoteConfigError', e, st);
    }
    return _currentConfig;
  }
}
