import 'package:flutter/material.dart';

Widget loadFuture<T>(
    {required Future<T> future,
    required Widget Function(BuildContext context, T?) builder}) {
  return FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return builder(context, snapshot.data);
      } else if (snapshot.hasError) {
        return Text('${snapshot.error}');
      }

      return const Center(child: CircularProgressIndicator());
    },
  );
}

extension StringExtension on String {
  String capitalize() {
    if (length <= 1) {
      return toUpperCase();
    }

    return this[0].toUpperCase() + substring(1);
  }
}

class DateHelper {
  static String display(DateTime dateTime) {
    DateTime locale = dateTime.toLocal();
    String time =
        '${locale.hour.toString().padLeft(2, '0')}:${locale.minute.toString().padLeft(2, '0')}:${locale.second.toString().padLeft(2, '0')}';
    String date =
        '${locale.day.toString().padLeft(2, '0')}/${locale.month.toString().padLeft(2, '0')}/${locale.year}';
    return '$time\n$date';
  }

  static DateTime lastDayOfMonth(DateTime dateTime) {
    return nextMonth(DateTime(dateTime.year, dateTime.month, 1))
        .subtract(const Duration(seconds: 1));
  }

  static DateTime firstDayOfMonth(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, 1);
  }

  static DateTime nextMonth(DateTime now) {
    if (now.month == 12) {
      return DateTime(now.year + 1, 1, now.day);
    }

    return DateTime(now.year, now.month + 1, now.day);
  }

  static DateTime previousMonth(DateTime now) {
    if (now.month == 1) {
      return DateTime(now.year - 1, 12, now.day);
    }

    return DateTime(now.year, now.month - 1, now.day);
  }

  static (DateTime, DateTime) monthRange(DateTime dateTime) {
    var start = firstDayOfMonth(dateTime);
    var end = lastDayOfMonth(start);

    return (start, end);
  }

  static Map<String, DateTime> displayDates() {
    var now = firstDayOfMonth(DateTime.now());

    Map<String, DateTime> result = {};
    for (int i = 0; i < 12; i++) {
      result['${now.month.toString().padLeft(2, '0')}/${now.year}'] = now;

      now = previousMonth(now);
    }

    return result;
  }
}
