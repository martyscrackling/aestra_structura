/// Utility functions for date calculations including Philippine holidays.
///
/// Holidays are tagged as `regular` (Regular Holiday — 200% pay when worked)
/// or `special` (Special Non-Working Day — 130% pay when worked) per DOLE
/// labor advisories.
class PhilippineHoliday {
  const PhilippineHoliday({
    required this.name,
    required this.type,
    required this.month,
    required this.day,
  });

  final String name;
  final String type; // 'regular' | 'special'
  final int month;
  final int day;

  bool get isRegular => type == 'regular';
  bool get isSpecial => type == 'special';

  /// Pay multiplier on the day's regular hours when worked.
  double get payMultiplier => isRegular ? 2.0 : 1.3;

  /// Human label for the kind of holiday.
  String get typeLabel => isRegular ? 'Regular Holiday' : 'Special Non-Working';

  /// Short pay summary, e.g. "200% pay" or "130% pay".
  String get payLabel => isRegular ? '200% pay' : '130% pay';
}

class PhilippineDateUtils {
  /// Philippine holidays for 2024-2027 (expandable).
  /// Each entry is tagged with a `type`: `regular` or `special`.
  static const Map<int, List<Map<String, dynamic>>> philippineHolidays = {
    2024: [
      {'month': 1, 'day': 1, 'name': 'New Year\'s Day', 'type': 'regular'},
      {'month': 2, 'day': 9, 'name': 'Chinese New Year', 'type': 'special'},
      {'month': 2, 'day': 10, 'name': 'Chinese New Year', 'type': 'special'},
      {'month': 3, 'day': 28, 'name': 'Maundy Thursday', 'type': 'regular'},
      {'month': 3, 'day': 29, 'name': 'Good Friday', 'type': 'regular'},
      {'month': 3, 'day': 30, 'name': 'Black Saturday', 'type': 'special'},
      {'month': 4, 'day': 9, 'name': 'Araw ng Kagitingan', 'type': 'regular'},
      {'month': 5, 'day': 1, 'name': 'Labor Day', 'type': 'regular'},
      {'month': 6, 'day': 12, 'name': 'Independence Day', 'type': 'regular'},
      {'month': 8, 'day': 21, 'name': 'Ninoy Aquino Day', 'type': 'special'},
      {'month': 8, 'day': 26, 'name': 'National Heroes Day', 'type': 'regular'},
      {'month': 11, 'day': 1, 'name': 'All Saints\' Day', 'type': 'special'},
      {'month': 11, 'day': 30, 'name': 'Bonifacio Day', 'type': 'regular'},
      {
        'month': 12,
        'day': 8,
        'name': 'Feast of the Immaculate Conception',
        'type': 'special',
      },
      {'month': 12, 'day': 25, 'name': 'Christmas Day', 'type': 'regular'},
      {'month': 12, 'day': 30, 'name': 'Rizal Day', 'type': 'regular'},
      {'month': 12, 'day': 31, 'name': 'New Year\'s Eve', 'type': 'special'},
    ],
    2025: [
      {'month': 1, 'day': 1, 'name': 'New Year\'s Day', 'type': 'regular'},
      {
        'month': 1,
        'day': 25,
        'name': 'EDSA Revolution Anniversary',
        'type': 'special',
      },
      {'month': 1, 'day': 29, 'name': 'Chinese New Year', 'type': 'special'},
      {'month': 4, 'day': 9, 'name': 'Araw ng Kagitingan', 'type': 'regular'},
      {'month': 4, 'day': 17, 'name': 'Maundy Thursday', 'type': 'regular'},
      {'month': 4, 'day': 18, 'name': 'Good Friday', 'type': 'regular'},
      {'month': 4, 'day': 19, 'name': 'Black Saturday', 'type': 'special'},
      {'month': 5, 'day': 1, 'name': 'Labor Day', 'type': 'regular'},
      {'month': 6, 'day': 12, 'name': 'Independence Day', 'type': 'regular'},
      {'month': 8, 'day': 21, 'name': 'Ninoy Aquino Day', 'type': 'special'},
      {'month': 8, 'day': 25, 'name': 'National Heroes Day', 'type': 'regular'},
      {'month': 11, 'day': 1, 'name': 'All Saints\' Day', 'type': 'special'},
      {'month': 11, 'day': 30, 'name': 'Bonifacio Day', 'type': 'regular'},
      {
        'month': 12,
        'day': 8,
        'name': 'Feast of the Immaculate Conception',
        'type': 'special',
      },
      {'month': 12, 'day': 25, 'name': 'Christmas Day', 'type': 'regular'},
      {'month': 12, 'day': 30, 'name': 'Rizal Day', 'type': 'regular'},
      {'month': 12, 'day': 31, 'name': 'New Year\'s Eve', 'type': 'special'},
    ],
    2026: [
      {'month': 1, 'day': 1, 'name': 'New Year\'s Day', 'type': 'regular'},
      {
        'month': 1,
        'day': 25,
        'name': 'EDSA Revolution Anniversary',
        'type': 'special',
      },
      {'month': 2, 'day': 17, 'name': 'Chinese New Year', 'type': 'special'},
      {'month': 4, 'day': 2, 'name': 'Maundy Thursday', 'type': 'regular'},
      {'month': 4, 'day': 3, 'name': 'Good Friday', 'type': 'regular'},
      {'month': 4, 'day': 4, 'name': 'Black Saturday', 'type': 'special'},
      {'month': 4, 'day': 9, 'name': 'Araw ng Kagitingan', 'type': 'regular'},
      {'month': 5, 'day': 1, 'name': 'Labor Day', 'type': 'regular'},
      {'month': 6, 'day': 12, 'name': 'Independence Day', 'type': 'regular'},
      {'month': 8, 'day': 21, 'name': 'Ninoy Aquino Day', 'type': 'special'},
      {'month': 8, 'day': 31, 'name': 'National Heroes Day', 'type': 'regular'},
      {'month': 11, 'day': 1, 'name': 'All Saints\' Day', 'type': 'special'},
      {'month': 11, 'day': 30, 'name': 'Bonifacio Day', 'type': 'regular'},
      {
        'month': 12,
        'day': 8,
        'name': 'Feast of the Immaculate Conception',
        'type': 'special',
      },
      {'month': 12, 'day': 25, 'name': 'Christmas Day', 'type': 'regular'},
      {'month': 12, 'day': 30, 'name': 'Rizal Day', 'type': 'regular'},
      {'month': 12, 'day': 31, 'name': 'New Year\'s Eve', 'type': 'special'},
    ],
    2027: [
      {'month': 1, 'day': 1, 'name': 'New Year\'s Day', 'type': 'regular'},
      {
        'month': 1,
        'day': 25,
        'name': 'EDSA Revolution Anniversary',
        'type': 'special',
      },
      {'month': 2, 'day': 6, 'name': 'Chinese New Year', 'type': 'special'},
      {'month': 3, 'day': 25, 'name': 'Maundy Thursday', 'type': 'regular'},
      {'month': 3, 'day': 26, 'name': 'Good Friday', 'type': 'regular'},
      {'month': 3, 'day': 27, 'name': 'Black Saturday', 'type': 'special'},
      {'month': 4, 'day': 9, 'name': 'Araw ng Kagitingan', 'type': 'regular'},
      {'month': 5, 'day': 1, 'name': 'Labor Day', 'type': 'regular'},
      {'month': 6, 'day': 12, 'name': 'Independence Day', 'type': 'regular'},
      {'month': 8, 'day': 21, 'name': 'Ninoy Aquino Day', 'type': 'special'},
      {'month': 8, 'day': 30, 'name': 'National Heroes Day', 'type': 'regular'},
      {'month': 11, 'day': 1, 'name': 'All Saints\' Day', 'type': 'special'},
      {'month': 11, 'day': 30, 'name': 'Bonifacio Day', 'type': 'regular'},
      {
        'month': 12,
        'day': 8,
        'name': 'Feast of the Immaculate Conception',
        'type': 'special',
      },
      {'month': 12, 'day': 25, 'name': 'Christmas Day', 'type': 'regular'},
      {'month': 12, 'day': 30, 'name': 'Rizal Day', 'type': 'regular'},
      {'month': 12, 'day': 31, 'name': 'New Year\'s Eve', 'type': 'special'},
    ],
  };

  /// Counts the number of Sundays between two dates (inclusive)
  static int countSundays(DateTime startDate, DateTime endDate) {
    int count = 0;
    DateTime current = startDate;

    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      if (current.weekday == DateTime.sunday) {
        count++;
      }
      current = current.add(const Duration(days: 1));
    }

    return count;
  }

  /// Counts Philippine holidays between two dates (inclusive)
  static int countPhilippineHolidays(DateTime startDate, DateTime endDate) {
    int count = 0;
    DateTime current = startDate;

    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      if (isPhilippineHoliday(current)) {
        count++;
      }
      current = current.add(const Duration(days: 1));
    }

    return count;
  }

  /// Checks if a specific date is a Philippine holiday
  static bool isPhilippineHoliday(DateTime date) {
    final yearHolidays = philippineHolidays[date.year];
    if (yearHolidays == null) return false;

    return yearHolidays.any(
      (holiday) => holiday['month'] == date.month && holiday['day'] == date.day,
    );
  }

  /// Gets the name of a Philippine holiday if it exists on the given date
  static String? getHolidayName(DateTime date) {
    final info = getHolidayInfo(date);
    return info?.name;
  }

  /// Gets the type of a Philippine holiday (`regular` or `special`), or null.
  static String? getHolidayType(DateTime date) {
    final info = getHolidayInfo(date);
    return info?.type;
  }

  /// Gets full holiday info for a date, or null if not a holiday.
  static PhilippineHoliday? getHolidayInfo(DateTime date) {
    final yearHolidays = philippineHolidays[date.year];
    if (yearHolidays == null) return null;

    for (final h in yearHolidays) {
      if (h['month'] == date.month && h['day'] == date.day) {
        return PhilippineHoliday(
          name: (h['name'] ?? '').toString(),
          type: (h['type'] ?? 'special').toString(),
          month: h['month'] as int,
          day: h['day'] as int,
        );
      }
    }
    return null;
  }

  /// Returns all holidays falling within the given year.
  static List<PhilippineHoliday> holidaysInYear(int year) {
    final yearHolidays = philippineHolidays[year];
    if (yearHolidays == null) return const [];
    return yearHolidays
        .map(
          (h) => PhilippineHoliday(
            name: (h['name'] ?? '').toString(),
            type: (h['type'] ?? 'special').toString(),
            month: h['month'] as int,
            day: h['day'] as int,
          ),
        )
        .toList();
  }

  /// Returns upcoming holidays relative to [from] within the next [days] days.
  static List<MapEntry<DateTime, PhilippineHoliday>> upcomingHolidays(
    DateTime from, {
    int days = 30,
  }) {
    final result = <MapEntry<DateTime, PhilippineHoliday>>[];
    DateTime cursor = DateTime(from.year, from.month, from.day);
    final end = cursor.add(Duration(days: days));
    while (!cursor.isAfter(end)) {
      final info = getHolidayInfo(cursor);
      if (info != null) {
        result.add(MapEntry(cursor, info));
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return result;
  }

  /// Calculates end date by adding working days (excluding Sundays and holidays)
  static DateTime calculateEndDateExcludingNonWorkingDays(
    DateTime startDate,
    int workingDays,
  ) {
    DateTime currentDate = startDate;
    int addedDays = 0;

    while (addedDays < workingDays) {
      if (currentDate.weekday != DateTime.sunday &&
          !isPhilippineHoliday(currentDate)) {
        addedDays++;
      }

      if (addedDays < workingDays) {
        currentDate = currentDate.add(const Duration(days: 1));
      }
    }

    return currentDate;
  }

  /// Gets a summary of holidays and Sundays in a date range
  static Map<String, dynamic> getDateRangeSummary(
    DateTime startDate,
    DateTime endDate,
  ) {
    return {
      'sundays': countSundays(startDate, endDate),
      'holidays': countPhilippineHolidays(startDate, endDate),
      'total_days': endDate.difference(startDate).inDays + 1,
    };
  }
}
