import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class AppLogger {
  static bool isDebugEnabled = true;

  /// Standard informational log
  static void info(String tag, String message) {
    if (!isDebugEnabled) return;
    final logText = 'ℹ️ [$tag] $message';
    if (kDebugMode) {
      developer.log(logText, name: tag);
      debugPrint(logText);
    }
  }

  /// Network Request Log
  static void request({
    required String method,
    required String url,
    Map<String, String>? headers,
    Map<String, dynamic>? fields,
    List<String>? files,
  }) {
    if (!isDebugEnabled) return;
    final buffer = StringBuffer();
    buffer.writeln('🚀 [HTTP REQUEST] $method $url');
    if (headers != null && headers.isNotEmpty) {
      buffer.writeln('   📋 Headers: $headers');
    }
    if (fields != null && fields.isNotEmpty) {
      buffer.writeln('   📝 Fields: $fields');
    }
    if (files != null && files.isNotEmpty) {
      buffer.writeln('   📎 Files: $files');
    }
    final logText = buffer.toString().trim();
    if (kDebugMode) {
      developer.log(logText, name: 'HTTP');
      debugPrint(logText);
    }
  }

  /// Network Response Log
  static void response({
    required String method,
    required String url,
    required int statusCode,
    dynamic body,
  }) {
    if (!isDebugEnabled) return;
    final isSuccess = statusCode >= 200 && statusCode < 300;
    final icon = isSuccess ? '✅' : '❌';
    final logText = '$icon [HTTP RESPONSE] $statusCode $method $url\n   📦 Body: $body';
    if (kDebugMode) {
      developer.log(logText, name: 'HTTP');
      debugPrint(logText);
    }
  }

  /// Error & Exception Log
  static void error(String tag, dynamic error, [StackTrace? stackTrace]) {
    final logText = '🚨 [ERROR - $tag]: $error';
    developer.log(logText, name: tag, error: error, stackTrace: stackTrace);
    if (kDebugMode) {
      debugPrint(logText);
      if (stackTrace != null) {
        debugPrint('   📜 StackTrace: $stackTrace');
      }
    }
  }
}
