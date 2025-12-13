import 'package:flutter/material.dart';

class CalendarPanel extends StatefulWidget {
  const CalendarPanel({super.key});

  @override
  State<CalendarPanel> createState() => _CalendarPanelState();
}

class _CalendarPanelState extends State<CalendarPanel> {
  late DateTime _selectedDate;
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _currentMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  int _getDaysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  int _getFirstDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1).weekday - 1;
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = _getDaysInMonth(_currentMonth);
    final firstDay = _getFirstDayOfMonth(_currentMonth);
    final monthName = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ][_currentMonth.month - 1];

    // Generate calendar days
    final calendarDays = <int>[];
    for (int i = 0; i < firstDay; i++) {
      calendarDays.add(0); // Empty cells
    }
    for (int i = 1; i <= daysInMonth; i++) {
      calendarDays.add(i);
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Month Navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$monthName ${_currentMonth.year}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _previousMonth,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _nextMonth,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Day headers
            Table(
              children: [
                TableRow(
                  children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                      .map((day) => Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            day,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ))
                      .toList(),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Calendar grid using Table
            Table(
              defaultColumnWidth: const FlexColumnWidth(1),
              children: List.generate(
                (calendarDays.length / 7).ceil(),
                (rowIndex) {
                  final startIdx = rowIndex * 7;
                  final endIdx = (startIdx + 7 > calendarDays.length)
                      ? calendarDays.length
                      : startIdx + 7;
                  final row = calendarDays.sublist(startIdx, endIdx);

                  return TableRow(
                    children: List.generate(7, (colIndex) {
                      final day = colIndex < row.length ? row[colIndex] : 0;
                      final date = day > 0
                          ? DateTime(_currentMonth.year, _currentMonth.month, day)
                          : null;

                      final isSelected = date != null &&
                          _selectedDate.year == date.year &&
                          _selectedDate.month == date.month &&
                          _selectedDate.day == date.day;
                      final isToday = date != null &&
                          date.year == DateTime.now().year &&
                          date.month == DateTime.now().month &&
                          date.day == DateTime.now().day;

                      return GestureDetector(
                        onTap: date != null ? () {
                          setState(() => _selectedDate = date);
                        } : null,
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF1396E9)
                                : isToday
                                    ? const Color(0xFF1396E9).withOpacity(0.1)
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isToday && !isSelected
                                ? Border.all(color: const Color(0xFF1396E9), width: 1.5)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              day > 0 ? day.toString() : '',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: day > 0
                                    ? (isSelected ? Colors.white : Colors.black)
                                    : Colors.transparent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Selected date info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event, size: 18, color: Color(0xFF1396E9)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_selectedDate.day} ${monthName} ${_selectedDate.year}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}