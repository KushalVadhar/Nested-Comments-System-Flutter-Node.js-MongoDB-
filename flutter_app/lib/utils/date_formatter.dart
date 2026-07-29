import 'package:intl/intl.dart';

class DateFormatter {
  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 45) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '${mins}m ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '${hours}h ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '${days}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  static bool isWithinEditWindow(DateTime createdAt, {int minutes = 5}) {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    return diff.inMinutes < minutes;
  }
}
