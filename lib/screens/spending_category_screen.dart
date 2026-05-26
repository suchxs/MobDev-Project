import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SpendingCategoryScreen extends StatefulWidget {
  const SpendingCategoryScreen({super.key});

  @override
  State<SpendingCategoryScreen> createState() =>
      _SpendingCategoryScreenState();
}

class _SpendingCategoryScreenState extends State<SpendingCategoryScreen> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    const surfaceColor = Color(0xFFF6F3FB);
    const mutedText = Color(0xFF7E7A8E);

    final categories = [
      _CategoryData('General', 600, const Color(0xFFB38AF7)),
      _CategoryData('Transportation', 600, const Color(0xFF7FB3FF)),
      _CategoryData('Personal', 1250, const Color(0xFFFF7E86)),
      _CategoryData('Education', 100, const Color(0xFFF8B26A)),
    ];

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Spending insight',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.tune_rounded, size: 16),
            label: const Text('Adjust'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Budget overview',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Monthly budget',
                    style: TextStyle(color: mutedText, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Php 6,000',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 55,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            setState(() {
                              _touchedIndex =
                                  response?.touchedSection?.touchedSectionIndex ??
                                      -1;
                            });
                          },
                        ),
                        sections: List.generate(categories.length, (index) {
                          final category = categories[index];
                          final isTouched = index == _touchedIndex;
                          return PieChartSectionData(
                            value: category.value.toDouble(),
                            color: category.color,
                            radius: isTouched ? 26 : 22,
                            title: '',
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'Left to spend:',
                        style: TextStyle(color: mutedText, fontSize: 12),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0EBFA),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Php 3,665.80',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Budget category',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            for (final category in categories)
              _CategoryRow(
                title: category.title,
                subtitle: '${category.transactions} transactions',
                amount: 'Php ${category.value} / Php ${category.limit}',
                color: category.color,
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryData {
  const _CategoryData(this.title, this.value, this.color)
      : transactions = 3,
        limit = 1000;

  final String title;
  final int value;
  final int transactions;
  final int limit;
  final Color color;
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.2),
            child: Icon(Icons.circle, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF7E7A8E),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
