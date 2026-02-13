import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../services/pm_dashboard_service.dart';

class ActivityWidget extends StatelessWidget {
  final List<PmActivityPoint> series;

  const ActivityWidget({super.key, required this.series});

  String _weekdayLabel(DateTime day) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final idx = (day.weekday - 1).clamp(0, 6);
    return labels[idx];
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

    if (series.isEmpty) {
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

    final spots = <FlSpot>[];
    for (var i = 0; i < series.length; i++) {
      spots.add(FlSpot(i.toDouble(), series[i].completed.toDouble()));
    }

    final maxValue = series
        .map((p) => p.completed)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = (maxValue == 0 ? 1 : (maxValue + 1)).toDouble();

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
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallPhone
                      ? 6.0
                      : isMobile
                      ? 8.0
                      : 12.0,
                  vertical: isSmallPhone
                      ? 3.0
                      : isMobile
                      ? 4.0
                      : 6.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Weekly',
                      style: TextStyle(
                        fontSize: isSmallPhone
                            ? 10.0
                            : isMobile
                            ? 11.0
                            : 13.0,
                        color: const Color(0xFF0C1935),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: isSmallPhone
                          ? 12.0
                          : isMobile
                          ? 14.0
                          : 16.0,
                      color: Colors.grey[600],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
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
                        if (index >= 0 && index < series.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _weekdayLabel(series[index].day),
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
                      interval: maxY <= 5 ? 1 : (maxY / 4).ceilToDouble(),
                      reservedSize: 40,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Text(
                          value.toInt().toString(),
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

                minX: 0,
                maxX: (series.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,

                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    isStrokeCapRound: true,

                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: Colors.blue,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],

                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipPadding: const EdgeInsets.all(8),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.x.toInt();
                        final count = (idx >= 0 && idx < series.length)
                            ? series[idx].completed
                            : 0;
                        return LineTooltipItem(
                          '$count tasks completed',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
