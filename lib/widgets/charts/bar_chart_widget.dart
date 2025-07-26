import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class BarChartWidget extends StatelessWidget {
  final Map<String, double> weeklyData;

  const BarChartWidget({
    super.key,
    required this.weeklyData,
  });

  @override
  Widget build(BuildContext context) {
    if (weeklyData.isEmpty) {
      return const Center(
        child: Text('No data available'),
      );
    }

    final maxY = weeklyData.values.reduce((a, b) => a > b ? a : b);
    final barGroups = <BarChartGroupData>[];

    int index = 0;
    for (final entry in weeklyData.entries) {
      barGroups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: entry.value,
              color: Colors.teal,
              width: 20,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
      index++;
    }

    return BarChart(
      BarChartData(
        maxY: maxY * 1.1,
        barGroups: barGroups,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '₹${value.toInt()}',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final dates = weeklyData.keys.toList();
                if (value.toInt() < dates.length) {
                  return Text(
                    dates[value.toInt()],
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const Text('');
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
      ),
    );
  }
}
