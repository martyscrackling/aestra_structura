/// Utility functions for date calculations including Philippine holidays
class PhilippineDateUtils {
  /// Philippine holidays for 2024-2027 (can be expanded as needed)
  /// Includes regular holidays and special non-working days
  static const Map<int, List<Map<String, dynamic>>> philippineHolidays = {
    2024: [
      {'month': 1, 'day': 1, 'name': 'New Year\'s Day'},
      {'month': 2, 'day': 10, 'name': 'Feast of the Black Nazarene'},
      {'month': 2, 'day': 12, 'name': 'Chinese New Year'},
      {'month': 2, 'day': 13, 'name': 'Chinese New Year (Chinese New Year observance)'},
      {'month': 2, 'day': 14, 'name': 'Chinese New Year (Chinese New Year observance)'},
      {'month': 3, 'day': 28, 'name': 'Maundy Thursday'},
      {'month': 3, 'day': 29, 'name': 'Good Friday'},
      {'month': 3, 'day': 30, 'name': 'Black Saturday'},
      {'month': 4, 'day': 9, 'name': 'Araw ng Kagitingan'},
      {'month': 4, 'day': 10, 'name': 'Special Non-Working Day'},
      {'month': 4, 'day': 11, 'name': 'Special Non-Working Day'},
      {'month': 6, 'day': 12, 'name': 'Independence Day'},
      {'month': 7, 'day': 22, 'name': 'Special Non-Working Day'},
      {'month': 8, 'day': 21, 'name': 'Ninoy Aquino Day'},
      {'month': 8, 'day': 26, 'name': 'National Heroes Day'},
      {'month': 11, 'day': 1, 'name': 'All Saints\' Day'},
      {'month': 11, 'day': 30, 'name': 'Bonifacio Day'},
      {'month': 12, 'day': 8, 'name': 'Feast of the Immaculate Conception'},
      {'month': 12, 'day': 25, 'name': 'Christmas Day'},
      {'month': 12, 'day': 26, 'name': 'Special Non-Working Day'},
      {'month': 12, 'day': 30, 'name': 'Rizal Day'},
      {'month': 12, 'day': 31, 'name': 'New Year\'s Eve'},
    ],
    2025: [
      {'month': 1, 'day': 1, 'name': 'New Year\'s Day'},
      {'month': 1, 'day': 25, 'name': 'EDSA Revolution Anniversary'},
      {'month': 2, 'day': 10, 'name': 'Feast of the Black Nazarene'},
      {'month': 2, 'day': 29, 'name': 'Chinese New Year'},
      {'month': 3, 'day': 1, 'name': 'Chinese New Year (observance)'},
      {'month': 3, 'day': 2, 'name': 'Chinese New Year (observance)'},
      {'month': 4, 'day': 17, 'name': 'Maundy Thursday'},
      {'month': 4, 'day': 18, 'name': 'Good Friday'},
      {'month': 4, 'day': 19, 'name': 'Black Saturday'},
      {'month': 4, 'day': 9, 'name': 'Araw ng Kagitingan'},
      {'month': 6, 'day': 12, 'name': 'Independence Day'},
      {'month': 8, 'day': 21, 'name': 'Ninoy Aquino Day'},
      {'month': 8, 'day': 25, 'name': 'National Heroes Day'},
      {'month': 11, 'day': 1, 'name': 'All Saints\' Day'},
      {'month': 11, 'day': 30, 'name': 'Bonifacio Day'},
      {'month': 12, 'day': 8, 'name': 'Feast of the Immaculate Conception'},
      {'month': 12, 'day': 25, 'name': 'Christmas Day'},
      {'month': 12, 'day': 30, 'name': 'Rizal Day'},
      {'month': 12, 'day': 31, 'name': 'New Year\'s Eve'},
    ],
    2026: [
      {'month': 1, 'day': 1, 'name': 'New Year\'s Day'},
      {'month': 1, 'day': 25, 'name': 'EDSA Revolution Anniversary'},
      {'month': 2, 'day': 10, 'name': 'Feast of the Black Nazarene'},
      {'month': 2, 'day': 17, 'name': 'Chinese New Year'},
      {'month': 2, 'day': 18, 'name': 'Chinese New Year (observance)'},
      {'month': 2, 'day': 19, 'name': 'Chinese New Year (observance)'},
      {'month': 4, 'day': 2, 'name': 'Maundy Thursday'},
      {'month': 4, 'day': 3, 'name': 'Good Friday'},
      {'month': 4, 'day': 4, 'name': 'Black Saturday'},
      {'month': 4, 'day': 9, 'name': 'Araw ng Kagitingan'},
      {'month': 6, 'day': 12, 'name': 'Independence Day'},
      {'month': 8, 'day': 21, 'name': 'Ninoy Aquino Day'},
      {'month': 8, 'day': 31, 'name': 'National Heroes Day'},
      {'month': 11, 'day': 1, 'name': 'All Saints\' Day'},
      {'month': 11, 'day': 30, 'name': 'Bonifacio Day'},
      {'month': 12, 'day': 8, 'name': 'Feast of the Immaculate Conception'},
      {'month': 12, 'day': 25, 'name': 'Christmas Day'},
      {'month': 12, 'day': 30, 'name': 'Rizal Day'},
      {'month': 12, 'day': 31, 'name': 'New Year\'s Eve'},
    ],
    2027: [
      {'month': 1, 'day': 1, 'name': 'New Year\'s Day'},
      {'month': 1, 'day': 25, 'name': 'EDSA Revolution Anniversary'},
      {'month': 2, 'day': 10, 'name': 'Feast of the Black Nazarene'},
      {'month': 2, 'day': 6, 'name': 'Chinese New Year'},
      {'month': 2, 'day': 7, 'name': 'Chinese New Year (observance)'},
      {'month': 2, 'day': 8, 'name': 'Chinese New Year (observance)'},
      {'month': 3, 'day': 25, 'name': 'Maundy Thursday'},
      {'month': 3, 'day': 26, 'name': 'Good Friday'},
      {'month': 3, 'day': 27, 'name': 'Black Saturday'},
      {'month': 4, 'day': 9, 'name': 'Araw ng Kagitingan'},
      {'month': 6, 'day': 12, 'name': 'Independence Day'},
      {'month': 8, 'day': 21, 'name': 'Ninoy Aquino Day'},
      {'month': 8, 'day': 30, 'name': 'National Heroes Day'},
      {'month': 11, 'day': 1, 'name': 'All Saints\' Day'},
      {'month': 11, 'day': 30, 'name': 'Bonifacio Day'},
      {'month': 12, 'day': 8, 'name': 'Feast of the Immaculate Conception'},
      {'month': 12, 'day': 25, 'name': 'Christmas Day'},
      {'month': 12, 'day': 30, 'name': 'Rizal Day'},
      {'month': 12, 'day': 31, 'name': 'New Year\'s Eve'},
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
    
    return yearHolidays.any((holiday) =>
        holiday['month'] == date.month && holiday['day'] == date.day);
  }

  /// Gets the name of a Philippine holiday if it exists on the given date
  static String? getHolidayName(DateTime date) {
    final yearHolidays = philippineHolidays[date.year];
    if (yearHolidays == null) return null;
    
    final holiday = yearHolidays.firstWhere(
      (holiday) => holiday['month'] == date.month && holiday['day'] == date.day,
      orElse: () => {},
    );
    
    return holiday['name'] as String?;
  }

  /// Calculates end date by adding working days (excluding Sundays and holidays)
  static DateTime calculateEndDateExcludingNonWorkingDays(
    DateTime startDate,
    int workingDays,
  ) {
    DateTime currentDate = startDate;
    int addedDays = 0;

    while (addedDays < workingDays) {
      // Check if current date is not a Sunday and not a holiday
      if (currentDate.weekday != DateTime.sunday &&
          !isPhilippineHoliday(currentDate)) {
        addedDays++;
      }

      // Move to next day if we haven't reached the target
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
