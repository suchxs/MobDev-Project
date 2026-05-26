import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SpendingAllocationScreen extends StatefulWidget {
  const SpendingAllocationScreen({super.key});

  @override
  State<SpendingAllocationScreen> createState() =>
      _SpendingAllocationScreenState();
}

class _SpendingAllocationScreenState extends State<SpendingAllocationScreen> {
  bool _showMonthly = true;

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFF8C6AE6);
    const surfaceColor = Color(0xFFF6F3FB);
    const mutedText = Color(0xFF7E7A8E);

    final total = _showMonthly ? 6000.0 : 1500.0;
    final spent = _showMonthly ? 2335.20 : 620.75;
    final remaining = total - spent;

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
                  Row(
                    children: [
                      const Text(
                        'Monthly budget',
                        style: TextStyle(color: mutedText, fontSize: 12),
                      ),
                      const Spacer(),
                      _ToggleChip(
                        label: _showMonthly ? 'Monthly' : 'Weekly',
                        onTap: () =>
                            setState(() => _showMonthly = !_showMonthly),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Php ${total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 170,
                    child: PieChart(
                      PieChartData(
                        startDegreeOffset: -90,
                        sectionsSpace: 0,
                        centerSpaceRadius: 56,
                        sections: [
                          PieChartSectionData(
                            value: spent,
                            color: brandColor,
                            radius: 22,
                            title: '',
                          ),
                          PieChartSectionData(
                            value: remaining,
                            color: const Color(0xFFF0EBFA),
                            radius: 18,
                            title: '',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Php ${spent.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        const Text(
                          'Spent',
                          style: TextStyle(color: mutedText, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
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
                        child: Text(
                          'Php ${remaining.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
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
            const _BudgetCategoryTile(
              title: 'General',
              transactions: '3 transactions',
              amount: 'Php 600 / Php 3,000',
              color: Color(0xFFB38AF7),
            ),
            const _BudgetCategoryTile(
              title: 'Transportation',
              transactions: '5 transactions',
              amount: 'Php 600 / Php 1,000',
              color: Color(0xFF7FB3FF),
            ),
            const _BudgetCategoryTile(
              title: 'Personal',
              transactions: '12 transactions',
              amount: 'Php 1,250 / Php 1,000',
              color: Color(0xFFFF7E86),
            ),
            const _BudgetCategoryTile(
              title: 'School-related',
              transactions: '2 transactions',
              amount: 'Php 100 / Php 1,000',
              color: Color(0xFFF8B26A),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F0FA),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _BudgetCategoryTile extends StatelessWidget {
  const _BudgetCategoryTile({
    required this.title,
    required this.transactions,
    required this.amount,
    required this.color,
  });

  final String title;
  final String transactions;
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
                  transactions,
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
