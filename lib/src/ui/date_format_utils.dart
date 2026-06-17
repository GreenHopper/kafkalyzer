import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

class DateFormatUtils {
  // Enforce static access
  DateFormatUtils._();

  /// Formats a DateTime using the system locale-aware pattern: yMd HH:mm:ss
  /// Example (en_US): 1/19/2026 09:51:00
  /// Example (de_AT): 19.01.2026 09:51:00
  static String formatDateTime(
    BuildContext context,
    DateTime date, {
    bool withMilliseconds = false,
  }) {
    final locale = Localizations.localeOf(context).toString();
    final formatter = DateFormat.yMd(locale).add_Hms();

    // We manually handle milliseconds to ensure consistent appending if requested
    // although add_Hms() typically gives us second precision.
    if (withMilliseconds) {
      return "${formatter.format(date)}.${date.millisecond.toString().padLeft(3, '0')}";
    } else {
      return formatter.format(date);
    }
  }

  /// Formats just the date part (yMd) using system locale
  static String formatDate(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMd(locale).format(date);
  }

  /// Formats just the time part (Hms)
  static String formatTime(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.Hms(locale).format(date);
  }

  /// Returns a formatted timestamp for [ago] duration from now.
  static String formatFromNow(BuildContext context, Duration ago) {
    return formatDateTime(context, DateTime.now().subtract(ago));
  }

  /// Parses a string formatted by [formatDateTime] back into a [DateTime].
  /// Returns null if parsing fails.
  static DateTime? parseDateTime(BuildContext context, String text) {
    if (text.isEmpty) return null;
    final locale = Localizations.localeOf(context).toString();
    final formatter = DateFormat.yMd(locale).add_Hms();
    try {
      return formatter.parse(text);
    } catch (_) {
      try {
        return formatter.parseLoose(text);
      } catch (e) {
        return null;
      }
    }
  }
}
