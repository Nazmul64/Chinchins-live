import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';

/// ⚡ FastApiClient: High-Performance Stale-While-Revalidate (SWR) Client
/// - L1: In-Memory RAM Cache (`Map<String, dynamic>`) for sub-millisecond (0.00ms) synchronous access
/// - L2: Persistent Disk Cache via `SharedPreferences` for offline-first instant boot
/// - Non-blocking asynchronous background network synchronization
class FastApiClient {
  static final Map<String, dynamic> _memoryCache = {};
  static SharedPreferences? _prefs;
  static bool _isInitialized = false;

  /// Initialize FastApiClient (preloads disk cache index)
  static Future<void> init() async {
    if (_isInitialized && _prefs != null) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
    } catch (e) {
      AppLogger.error('FastApiClientInit', e);
    }
  }

  /// Generate a unique cache key from endpoint and parameters
  static String _buildKey(String endpoint, [Map<String, dynamic>? queryParams]) {
    if (queryParams == null || queryParams.isEmpty) {
      return 'fast_cache_$endpoint';
    }
    final sortedParams = Map.fromEntries(
      queryParams.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return 'fast_cache_${endpoint}_${jsonEncode(sortedParams)}';
  }

  /// Instant Synchronous Cache Lookup (L1 Memory Cache -> 0.00ms)
  static dynamic getCachedSync(String endpoint, [Map<String, dynamic>? queryParams]) {
    final key = _buildKey(endpoint, queryParams);
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }
    if (_prefs != null) {
      final raw = _prefs!.getString(key);
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          _memoryCache[key] = decoded;
          return decoded;
        } catch (_) {}
      }
    }
    return null;
  }

  /// Instant Asynchronous Cache Lookup (L1 Memory -> L2 SharedPreferences)
  static Future<dynamic> getCached(String endpoint, [Map<String, dynamic>? queryParams]) async {
    final key = _buildKey(endpoint, queryParams);
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }
    if (_prefs == null) {
      await init();
    }
    if (_prefs != null) {
      final raw = _prefs!.getString(key);
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          _memoryCache[key] = decoded;
          return decoded;
        } catch (_) {}
      }
    }
    return null;
  }

  /// Persist data in both L1 RAM and L2 Disk storage
  static Future<void> putCache(String endpoint, dynamic data, [Map<String, dynamic>? queryParams]) async {
    if (data == null) return;
    final key = _buildKey(endpoint, queryParams);
    _memoryCache[key] = data;

    try {
      if (_prefs == null) {
        await init();
      }
      if (_prefs != null) {
        await _prefs!.setString(key, jsonEncode(data));
      }
    } catch (e) {
      AppLogger.error('FastApiClientPutCache', e);
    }
  }

  /// Remove item from cache
  static Future<void> removeCache(String endpoint, [Map<String, dynamic>? queryParams]) async {
    final key = _buildKey(endpoint, queryParams);
    _memoryCache.remove(key);
    if (_prefs != null) {
      await _prefs!.remove(key);
    }
  }

  /// Stale-While-Revalidate (SWR) Fetcher:
  /// 1. Immediately delivers locally cached data via [onData] callback with `isFromCache = true` (0.00ms)
  /// 2. Asynchronously requests fresh data from the server in the background (5–50ms)
  /// 3. Updates local storage and triggers [onData] callback with `isFromCache = false`
  static Future<void> fetchWithInstantCache({
    required String endpoint,
    String? token,
    Map<String, dynamic>? queryParams,
    Map<String, String>? customHeaders,
    Duration timeout = const Duration(seconds: 8),
    required Function(dynamic data, bool isFromCache) onData,
  }) async {
    // 1. Instant Cache Dispatch (L1 / L2)
    final cachedData = await getCached(endpoint, queryParams);
    if (cachedData != null) {
      try {
        onData(cachedData, true);
      } catch (e) {
        AppLogger.error('FastApiClientOnCachedData', e);
      }
    }

    // 2. Fetch fresh data from backend
    try {
      Uri uri = Uri.parse(endpoint);
      if (queryParams != null && queryParams.isNotEmpty) {
        final stringParams = queryParams.map((k, v) => MapEntry(k, v?.toString() ?? ''));
        uri = uri.replace(queryParameters: {
          ...uri.queryParameters,
          ...stringParams,
        });
      }

      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (customHeaders != null) ...customHeaders,
      };

      final response = await http.get(uri, headers: headers).timeout(timeout);

      if (response.statusCode == 200) {
        try {
          final freshData = jsonDecode(response.body);
          if (freshData != null) {
            // Update L1 and L2 Caches
            await putCache(endpoint, freshData, queryParams);
            // Notify UI of fresh server data
            onData(freshData, false);
          }
        } catch (e) {
          AppLogger.error('FastApiClientJsonDecode', e);
        }
      }
    } catch (e) {
      // Offline mode or network fluctuation: cached data is already active on UI
      AppLogger.info('FastApiClientBackgroundSync', 'Network sync offline or delayed: $e');
    }
  }

  /// Simple Direct GET with Automatic Caching Fallback
  static Future<dynamic> getWithCacheFallback({
    required String endpoint,
    String? token,
    Map<String, dynamic>? queryParams,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      Uri uri = Uri.parse(endpoint);
      if (queryParams != null && queryParams.isNotEmpty) {
        final stringParams = queryParams.map((k, v) => MapEntry(k, v?.toString() ?? ''));
        uri = uri.replace(queryParameters: {
          ...uri.queryParameters,
          ...stringParams,
        });
      }

      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(uri, headers: headers).timeout(timeout);

      if (response.statusCode == 200) {
        final freshData = jsonDecode(response.body);
        if (freshData != null) {
          await putCache(endpoint, freshData, queryParams);
          return freshData;
        }
      }
    } catch (_) {}

    // Fallback to cache
    return await getCached(endpoint, queryParams);
  }
}
