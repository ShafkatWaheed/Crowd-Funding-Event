import 'package:intl/intl.dart';

class AppDateFormat {
  AppDateFormat._();

  static final _full = DateFormat("MMM d, yyyy 'at' h:mm a");
  static final _short = DateFormat("MMM d 'at' h:mm a");
  static final _eventCard = DateFormat("EEE, MMM d, yyyy 'at' h:mm a");
  static final _dateOnly = DateFormat('MMM d, yyyy');
  static final _timeOnly = DateFormat('h:mm a');
  static final _apiDate = DateFormat('yyyy-MM-dd');
  static final _monthYear = DateFormat('MMMM yyyy');

  // --- DateTime formatters (auto-convert to local) ---

  static String fullDateTime(DateTime dt) => _full.format(dt.toLocal());

  static String shortDateTime(DateTime dt) => _short.format(dt.toLocal());

  static String eventCard(DateTime dt) => _eventCard.format(dt.toLocal());

  static String dateOnly(DateTime dt) => _dateOnly.format(dt.toLocal());

  static String timeOnly(DateTime dt) => _timeOnly.format(dt.toLocal());

  static String monthYear(DateTime dt) => _monthYear.format(dt.toLocal());

  /// For API submission; no timezone conversion.
  static String apiDate(DateTime dt) => _apiDate.format(dt);

  static String dateRange(DateTime start, DateTime end) {
    final s = start.toLocal();
    final e = end.toLocal();
    if (s.year == e.year && s.month == e.month && s.day == e.day) {
      return '${_dateOnly.format(s)}, ${_timeOnly.format(s)} \u2013 ${_timeOnly.format(e)}';
    }
    return '${_short.format(s)} \u2013 ${_short.format(e)}';
  }

  // --- ISO string convenience helpers ---

  static String isoFull(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      return fullDateTime(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  static String isoShort(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      return shortDateTime(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  static String isoDateOnly(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      return dateOnly(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  // --- Relative time ---

  static String relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 365) return '${diff.inDays ~/ 365}y ago';
    if (diff.inDays > 30) return '${diff.inDays ~/ 30}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}
