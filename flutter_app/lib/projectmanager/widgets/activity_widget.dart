import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../services/pm_dashboard_service.dart';

enum _ActivityView { daily, monthly }

class ActivityWidget extends StatefulWidget {
  final List<PmActivityPoint> series;
  final List<PmActivityMonthPoint> monthlySeries;

  const ActivityWidget({
    super.key,
    required this.series,
    required this.monthlySeries,
  });

  @override
  State<ActivityWidget> createState() => _ActivityWidgetState();
}

class _ActivityChartPoint {
  final String label;
  final int completed;

  const _ActivityChartPoint({required this.label, required this.completed});
}

class _ActivityWidgetState extends State<ActivityWidget> {
  _ActivityView _selectedView = _ActivityView.daily;

  String _weekdayLabel(DateTime day) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final idx = (day.weekday - 1).clamp(0, 6);
    return labels[idx];
  }

  String _monthLabel(int month) {
    const labels = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return labels[(month - 1).clamp(0, 11)];
  }

  List<_ActivityChartPoint> _buildMonthlyChartSeries() {
    return widget.monthlySeries.map((point) {
      return _ActivityChartPoint(
        label: _monthLabel(point.month),
        completed: point.completed,
      );
    }).toList();
  }

  List<_ActivityChartPoint> _buildDailyChartSeries() {
    final now = DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    final totalsByWeekday = <int, int>{
      1: 0,
      2: 0,
      3: 0,
      4: 0,
      5: 0,
      6: 0,
      7: 0,
    };

    for (final point in widget.series) {
      final day = DateTime(point.day.year, point.day.month, point.day.day);
      if (!day.isBefore(startOfWeek) && day.isBefore(endOfWeek)) {
        totalsByWeekday[day.weekday] =
            (totalsByWeekday[day.weekday] ?? 0) + point.completed;
      }
    }

    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return [
      for (var i = 0; i < labels.length; i++)
        _ActivityChartPoint(
          label: labels[i],
          completed: totalsByWeekday[i + 1] ?? 0,
        ),
    ];
  }

  List<_ActivityChartPoint> _chartSeriesForSelectedView() {
    if (_selectedView == _ActivityView.daily) {
      return _buildDailyChartSeries();
    }
    return _buildMonthlyChartSeries();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final isSmallPhone = screenWidth < 375;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;

    final padding = isSmallPhone
        ? 12.0
        : isMobile
        ? 16.0
        : 20.0;

    if (widget.series.isEmpty) {
      return Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity',
              style: TextStyle(
                fontSize: isSmallPhone
                    ? 14.0
                    : isMobile
                    ? 16.0
                    : isTablet
                    ? 17.0
                    : 18.0,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0C1935),
              ),
            ),
            const SizedBox(height: 8),
            Text('No activity yet.', style: TextStyle(color: Colors.grey[700])),
          ],
        ),
      );
    }

    final chartSeries = _chartSeriesForSelectedView();
    final bars = <BarChartGroupData>[];
    for (var i = 0; i < chartSeries.length; i++) {
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: chartSeries[i].completed.toDouble(),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
              width: isSmallPhone
                  ? 12
                  : isMobile
                  ? 14
                  : 18,
              gradient: const LinearGradient(
                colors: [Color(0xFF2F80ED), Color(0xFF56CCF2)],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ],
        ),
      );
    }

    final maxValue = chartSeries
        .map((p) => p.completed)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final roundedCeil = ((maxValue + 4) ~/ 5) * 5;
    final maxY = (roundedCeil < 15 ? 15 : roundedCeil).toDouble();

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Activity',
                style: TextStyle(
                  fontSize: isSmallPhone
                      ? 14.0
                      : isMobile
                      ? 16.0
                      : isTablet
                      ? 17.0
                      : 18.0,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0C1935),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToggleButton(
                      label: 'Daily',
                      selected: _selectedView == _ActivityView.daily,
                      onTap: () {
                        setState(() {
                          _selectedView = _ActivityView.daily;
                        });
                      },
                      isSmallPhone: isSmallPhone,
                      isMobile: isMobile,
                    ),
                    _buildToggleButton(
                      label: 'Monthly',
                      selected: _selectedView == _ActivityView.monthly,
                      onTap: () {
                        setState(() {
                          _selectedView = _ActivityView.monthly;
                        });
                      },
                      isSmallPhone: isSmallPhone,
                      isMobile: isMobile,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: Colors.grey[200]!, strokeWidth: 1);
                  },
                ),

                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),

                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < chartSeries.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              chartSeries[index].label,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),

                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 5,
                      reservedSize: 40,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final intValue = value.toInt();
                        if (intValue != 0 &&
                            intValue != 5 &&
                            intValue != 10 &&
                            intValue != 15) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          intValue.toString(),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                borderData: FlBorderData(show: false),

                minY: 0,
                maxY: maxY,

                barGroups: bars,
                barTouchData: BarTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchTooltipData: BarTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    tooltipPadding: const EdgeInsets.all(8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final idx = group.x.toInt();
                      if (idx < 0 || idx >= chartSeries.length) {
                        return null;
                      }
                      final point = chartSeries[idx];
                      return BarTooltipItem(
                        '${point.completed} subtasks completed\n${point.label}',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          if (_selectedView == _ActivityView.monthly) ...[
            const SizedBox(height: 8),
            Text(
              'Monthly view: showing totals across the last 12 months',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: isSmallPhone
                    ? 10
                    : isMobile
                    ? 11
                    : 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required bool isSmallPhone,
    required bool isMobile,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSmallPhone
              ? 8
              : isMobile
              ? 10
              : 12,
          vertical: isSmallPhone
              ? 5
              : isMobile
              ? 6
              : 7,
        ),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: isSmallPhone
                ? 10.0
                : isMobile
                ? 11.0
                : 13.0,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? const Color(0xFF0C1935) : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}
