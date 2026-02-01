import 'package:intl/intl.dart';

class DateUtils {
  DateUtils._();

  static String formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime.toLocal());
  }

  static String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date.toLocal());
  }

  static String formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time.toLocal());
  }

  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final localDateTime = dateTime.toLocal();
    final difference = now.difference(localDateTime);

    if (difference.inDays > 7) {
      return formatDate(localDateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
