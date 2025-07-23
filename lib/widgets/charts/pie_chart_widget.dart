import 'package:flutter/material.dart';
import '../../ models/category.dart';

class PieChartWidget extends StatelessWidget {
  final Map<String, double> categoryTotals;
  final List<Category> categories;

  const PieChartWidget({
    super.key,
    required this.categoryTotals,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    if (categoryTotals.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final total = categoryTotals.values.fold(0.0, (sum, v) => sum + v);

    return Column(
      children: [
        // Simple pie-chart placeholder
        Container(
          height: 200,
          width: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade100,
          ),
          child: const Center(
            child: Text(
              'Spending\nBreakdown',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Scrollable legend
        SizedBox(
          height: 160, // adjust if necessary
          child: SingleChildScrollView(
            child: Column(
              children: categoryTotals.entries.map((entry) {
                final category = categories.firstWhere(
                      (c) => c.id == entry.key,
                  orElse: () => Category(
                    id: entry.key,
                    name: entry.key,
                    icon: Icons.category,
                    color: Colors.grey,
                  ),
                );

                final percentage =
                (entry.value / total * 100).toStringAsFixed(1);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: category.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          category.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '$percentage%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '₹${entry.value.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
