import 'package:intl/intl.dart';

class DateUtils2 {
  DateUtils2._();

  static final _dateFormat = DateFormat('dd MMM yyyy');
  static final _dateTimeFormat = DateFormat('dd MMM yyyy, HH:mm');
  static final _shortDateFormat = DateFormat('dd MMM');
  static final _timeFormat = DateFormat('HH:mm');

  static String formatDate(DateTime date) => _dateFormat.format(date);
  static String formatDateTime(DateTime date) => _dateTimeFormat.format(date);
  static String formatShortDate(DateTime date) => _shortDateFormat.format(date);
  static String formatTime(DateTime date) => _timeFormat.format(date);

  static String timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) return formatDate(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  static String dateRange(DateTime start, DateTime end) {
    return '${formatShortDate(start)} – ${formatShortDate(end)}';
  }
}
