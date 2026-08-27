import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LogEntry {
  final DateTime time;
  final String tag;
  final String message;
  final String type; // 'REQ', 'RES', 'ERR', 'INFO'
  final int? statusCode;

  LogEntry({
    required this.time,
    required this.tag,
    required this.message,
    required this.type,
    this.statusCode,
  });
}

class AppLogger {
  static bool isDebugEnabled = true;

  // In-memory log buffer for on-screen debug viewer
  static final List<LogEntry> logs = [];
  static const int maxLogs = 200;

  static final ValueNotifier<int> logCountNotifier = ValueNotifier<int>(0);

  static void _addLog(String type, String tag, String message, {int? statusCode}) {
    if (logs.length >= maxLogs) {
      logs.removeAt(0);
    }
    logs.add(LogEntry(
      time: DateTime.now(),
      tag: tag,
      message: message,
      type: type,
      statusCode: statusCode,
    ));
    logCountNotifier.value++;
  }

  /// Standard informational log
  static void info(String tag, String message) {
    _addLog('INFO', tag, message);
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
    final buffer = StringBuffer();
    buffer.writeln('🚀 $method $url');
    if (headers != null && headers.isNotEmpty) {
      final safeHeaders = Map<String, String>.from(headers);
      if (safeHeaders.containsKey('Authorization')) {
        final auth = safeHeaders['Authorization']!;
        safeHeaders['Authorization'] = auth.length > 20 ? '${auth.substring(0, 15)}...${auth.substring(auth.length - 5)}' : auth;
      }
      buffer.writeln('📋 Headers: $safeHeaders');
    }
    if (fields != null && fields.isNotEmpty) {
      buffer.writeln('📝 Fields: $fields');
    }
    if (files != null && files.isNotEmpty) {
      buffer.writeln('📎 Files: $files');
    }
    final logText = buffer.toString().trim();
    _addLog('REQ', 'HTTP', logText);

    if (kDebugMode && isDebugEnabled) {
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
    final isSuccess = statusCode >= 200 && statusCode < 300;
    final icon = isSuccess ? '✅' : '❌';
    final logText = '$icon $statusCode $method $url\n📦 Body:\n$body';
    _addLog('RES', 'HTTP', logText, statusCode: statusCode);

    if (kDebugMode && isDebugEnabled) {
      developer.log(logText, name: 'HTTP');
      debugPrint(logText);
    }
  }

  /// Error & Exception Log
  static void error(String tag, dynamic error, [StackTrace? stackTrace]) {
    final logText = '🚨 [$tag]: $error${stackTrace != null ? '\n📜 StackTrace: $stackTrace' : ''}';
    _addLog('ERR', tag, logText);

    developer.log(logText, name: tag, error: error, stackTrace: stackTrace);
    if (kDebugMode && isDebugEnabled) {
      debugPrint(logText);
    }
  }

  /// Clear all logs
  static void clear() {
    logs.clear();
    logCountNotifier.value = 0;
  }

  /// Show On-Screen Debug Console Modal
  static void showDebugConsole(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => const DebugConsoleView(),
      ),
    );
  }
}

class DebugConsoleView extends StatefulWidget {
  const DebugConsoleView({super.key});

  @override
  State<DebugConsoleView> createState() => _DebugConsoleViewState();
}

class _DebugConsoleViewState extends State<DebugConsoleView> {
  String _filter = 'ALL'; // ALL, REQ, RES, ERR

  @override
  Widget build(BuildContext context) {
    final filteredLogs = AppLogger.logs.reversed.where((l) {
      if (_filter == 'ALL') return true;
      return l.type == _filter;
    }).toList();

    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          width: 40,
          height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.bug_report_rounded, color: Colors.greenAccent, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Live Debug Console',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy_all_rounded, color: Colors.cyanAccent, size: 20),
                tooltip: 'Copy all logs',
                onPressed: () {
                  final allText = AppLogger.logs.map((e) => '[${e.time.toIso8601String()}] [${e.type}] ${e.message}').join('\n\n---\n\n');
                  Clipboard.setData(ClipboardData(text: allText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All logs copied to clipboard!'), duration: Duration(seconds: 2)),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                tooltip: 'Clear logs',
                onPressed: () {
                  setState(() {
                    AppLogger.clear();
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        // Filter Chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _buildFilterChip('ALL', Colors.blueGrey),
              const SizedBox(width: 8),
              _buildFilterChip('REQ', Colors.blue),
              const SizedBox(width: 8),
              _buildFilterChip('RES', Colors.green),
              const SizedBox(width: 8),
              _buildFilterChip('ERR', Colors.red),
            ],
          ),
        ),
        const Divider(color: Colors.white12, height: 16),
        // Logs List
        Expanded(
          child: filteredLogs.isEmpty
              ? const Center(
                  child: Text('No debug logs recorded yet.', style: TextStyle(color: Colors.white54, fontSize: 13)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filteredLogs.length,
                  separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 8),
                  itemBuilder: (ctx, idx) {
                    final log = filteredLogs[idx];
                    Color badgeColor = Colors.grey;
                    if (log.type == 'REQ') badgeColor = Colors.blue;
                    if (log.type == 'RES') badgeColor = (log.statusCode ?? 200) < 400 ? Colors.green : Colors.red;
                    if (log.type == 'ERR') badgeColor = Colors.redAccent;

                    final timeStr = '${log.time.hour.toString().padLeft(2, '0')}:${log.time.minute.toString().padLeft(2, '0')}:${log.time.second.toString().padLeft(2, '0')}.${log.time.millisecond.toString().padLeft(3, '0')}';

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: badgeColor, width: 0.8),
                                ),
                                child: Text(
                                  log.type,
                                  style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                timeStr,
                                style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace'),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: log.message));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Log item copied!'), duration: Duration(seconds: 1)),
                                  );
                                },
                                child: const Icon(Icons.copy_rounded, color: Colors.white38, size: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            log.message,
                            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontFamily: 'monospace', height: 1.3),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, Color color) {
    final isSelected = _filter == label;
    return GestureDetector(
      onTap: () => setState(() => _filter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.3) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
