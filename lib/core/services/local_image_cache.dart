import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalImageCache {
  static const String _keyAvatar = 'local_cached_avatar';
  static const String _keyCover = 'local_cached_cover';
  static const String _keyGallery = 'local_cached_gallery';

  static String? _memAvatar;
  static String? _memCover;
  static List<String> _memGallery = [];

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _memAvatar = prefs.getString(_keyAvatar);
      _memCover = prefs.getString(_keyCover);
      _memGallery = prefs.getStringList(_keyGallery) ?? [];
    } catch (e) {
      debugPrint('[LocalImageCache] Init error: $e');
    }
  }

  static Future<void> setAvatar(String localPath) async {
    _memAvatar = localPath;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAvatar, localPath);
    } catch (_) {}
  }

  static Future<void> setCover(String localPath) async {
    _memCover = localPath;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCover, localPath);
    } catch (_) {}
  }

  static Future<void> addGallery(List<String> localPaths) async {
    for (final p in localPaths) {
      if (!_memGallery.contains(p)) {
        _memGallery.insert(0, p);
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyGallery, _memGallery);
    } catch (_) {}
  }

  static String? get localAvatar {
    if (_memAvatar != null && File(_memAvatar!).existsSync()) {
      return _memAvatar;
    }
    return null;
  }

  static String? get localCover {
    if (_memCover != null && File(_memCover!).existsSync()) {
      return _memCover;
    }
    return null;
  }

  static List<String> get localGallery {
    return _memGallery.where((p) => File(p).existsSync()).toList();
  }

  static Future<void> clear() async {
    _memAvatar = null;
    _memCover = null;
    _memGallery = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAvatar);
      await prefs.remove(_keyCover);
      await prefs.remove(_keyGallery);
    } catch (_) {}
  }
}
