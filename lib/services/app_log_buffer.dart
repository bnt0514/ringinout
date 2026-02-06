class AppLogEntry {
  const AppLogEntry({
    required this.timestamp,
    required this.tag,
    required this.message,
  });

  final DateTime timestamp;
  final String tag;
  final String message;

  Map<String, dynamic> toJson() => {
    'time': timestamp.toIso8601String(),
    'tag': tag,
    'message': message,
  };
}

class AppLogBuffer {
  static const int _maxEntries = 500;
  static const Duration _maxAge = Duration(minutes: 60);
  static final List<AppLogEntry> _entries = [];

  static void record(String tag, String message) {
    final entry = AppLogEntry(
      timestamp: DateTime.now(),
      tag: tag,
      message: message,
    );
    _entries.add(entry);
    _trim();
  }

  static List<Map<String, dynamic>> snapshot({Duration? window}) {
    final cutoff = DateTime.now().subtract(window ?? _maxAge);
    return _entries
        .where((entry) => entry.timestamp.isAfter(cutoff))
        .map((entry) => entry.toJson())
        .toList(growable: false);
  }

  static void _trim() {
    final cutoff = DateTime.now().subtract(_maxAge);
    _entries.removeWhere((entry) => entry.timestamp.isBefore(cutoff));
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
  }
}
