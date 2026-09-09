/// 🕒 DateTimeUtils: Formats chat and message timestamps cleanly with 0 decimal float bugs
class DateTimeUtils {
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  /// Clean any raw strings that may have float decimals like "7.7001399333333 minutes"
  static String cleanRawTimeString(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Just now';

    // Check if string contains decimal minutes like "7.7001399333333 minutes" or "7.7001399333333 mins ago"
    final decimalMinutesRegex = RegExp(r'^(\d+\.\d+)\s*(?:minutes?|mins?)(?:\s*ago)?$', caseSensitive: false);
    final match = decimalMinutesRegex.firstMatch(trimmed);
    if (match != null) {
      final val = double.tryParse(match.group(1) ?? '');
      if (val != null) {
        final mins = val.round();
        if (mins <= 1) return 'Just now';
        return '${mins}m ago';
      }
    }

    // Check for "X minutes ago" or "X mins ago"
    final intMinutesRegex = RegExp(r'^(\d+)\s*(?:minutes?|mins?)(?:\s*ago)?$', caseSensitive: false);
    final intMatch = intMinutesRegex.firstMatch(trimmed);
    if (intMatch != null) {
      final mins = int.tryParse(intMatch.group(1) ?? '') ?? 0;
      if (mins <= 1) return 'Just now';
      return '${mins}m ago';
    }

    return trimmed;
  }

  /// Format ISO 8601 or relative date cleanly for Chat Thread lists
  /// Examples: 'Just now', '7m ago', '14:30', 'Yesterday', 'Sep 9'
  static String formatChatTimestamp(
    String? isoDate, {
    String? fallbackTime,
    int? minutesAgo,
  }) {
    if (minutesAgo != null) {
      if (minutesAgo <= 1) return 'Just now';
      if (minutesAgo < 60) return '${minutesAgo}m ago';
      if (minutesAgo < 1440) return '${(minutesAgo / 60).round()}h ago';
    }

    if (isoDate == null || isoDate.isEmpty) {
      if (fallbackTime != null && fallbackTime.isNotEmpty) {
        return cleanRawTimeString(fallbackTime);
      }
      return 'Just now';
    }

    // First check if it's already a formatted string that isn't ISO format
    if (!isoDate.contains('-') && !isoDate.contains('T')) {
      return cleanRawTimeString(isoDate);
    }

    try {
      final dateTime = DateTime.parse(isoDate).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dateTime);

      if (diff.isNegative || diff.inSeconds < 60) {
        return 'Just now';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24 && dateTime.day == now.day && dateTime.month == now.month && dateTime.year == now.year) {
        final hour = dateTime.hour.toString().padLeft(2, '0');
        final minute = dateTime.minute.toString().padLeft(2, '0');
        return '$hour:$minute';
      } else if (diff.inDays == 1 || (diff.inDays < 2 && dateTime.day == now.day - 1 && dateTime.month == now.month)) {
        return 'Yesterday';
      } else if (dateTime.year == now.year) {
        return '${_months[dateTime.month - 1]} ${dateTime.day}';
      } else {
        return '${_months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
      }
    } catch (_) {
      if (fallbackTime != null && fallbackTime.isNotEmpty) {
        return cleanRawTimeString(fallbackTime);
      }
      return cleanRawTimeString(isoDate);
    }
  }

  /// Format ISO 8601 string to short message bubble time: e.g. "14:30" or "02:30 PM"
  static String formatBubbleTime(String? isoDate, {String? fallbackTime}) {
    if (isoDate == null || isoDate.isEmpty) {
      return fallbackTime != null ? cleanRawTimeString(fallbackTime) : 'Just now';
    }

    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return fallbackTime != null ? cleanRawTimeString(fallbackTime) : cleanRawTimeString(isoDate);
    }
  }
}
