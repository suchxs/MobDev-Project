import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/session.dart';
import 'spending_utils.dart';

class SpendingAllocationScreen extends StatefulWidget {
  const SpendingAllocationScreen({super.key});

  @override
  State<SpendingAllocationScreen> createState() =>
      _SpendingAllocationScreenState();
}

class _SpendingAllocationScreenState extends State<SpendingAllocationScreen> {
  static const _apiBaseUrl = 'https://tipidtrack.dcism.org';
  static const brandColor = Color(0xFF8C6AE6);
  static const surfaceColor = Color(0xFFF6F3FB);
  static const mutedText = Color(0xFF7E7A8E);

  bool _isLoading = true;
  double _budget = 0;
  double _spent = 0;
  Map<String, double> _categoryMap = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final token = AppSession.instance.token;
    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }
    final headers = {'Authorization': 'Bearer $token'};
    try {
      final results = await Future.wait([
        http.get(Uri.parse('$_apiBaseUrl/api/budget'), headers: headers),
        http.get(Uri.parse('$_apiBaseUrl/api/transactions'), headers: headers),
      ]);

      double budget = 0;
      if (results[0].statusCode == 200) {
        final d = jsonDecode(results[0].body) as Map<String, dynamic>;
        budget = double.tryParse(d['monthly_amount'].toString()) ?? 0;
      }

      final catMap = <String, double>{};
      if (results[1].statusCode == 200) {
        final d = jsonDecode(results[1].body) as Map<String, dynamic>;
        for (final tx in (d['transactions'] as List<dynamic>? ?? [])) {
          if ((tx['type'] as String?)?.toLowerCase() != 'expense') continue;
          final cat = (tx['category'] as String?) ?? 'General';
          final amt = double.tryParse(tx['amount'].toString()) ?? 0;
          catMap[cat] = (catMap[cat] ?? 0) + amt;
        }
      }

      if (!mounted) return;
      setState(() {
        _budget = budget;
        _spent = catMap.values.fold(0, (a, b) => a + b);
        _categoryMap = catMap;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _openAdjust() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BudgetSheet(
        apiBaseUrl: _apiBaseUrl,
        current: _budget,
        onSaved: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (_budget - _spent).clamp(0.0, double.infinity);
    final overBudget = _spent > _budget && _budget > 0;

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
          'Spending Allocation',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: _openAdjust,
            icon: const Icon(Icons.tune_rounded, size: 16),
            label: const Text('Adjust'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: brandColor))
          : RefreshIndicator(
              color: brandColor,
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                              Text(
                                _budget == 0
                                    ? 'No budget set'
                                    : 'Monthly budget',
                                style: const TextStyle(
                                    color: mutedText, fontSize: 12),
                              ),
                              const Spacer(),
                              if (_budget == 0)
                                GestureDetector(
                                  onTap: _openAdjust,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: brandColor,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'Set budget',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (_budget > 0) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Php ${_budget.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 170,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  PieChart(
                                    PieChartData(
                                      startDegreeOffset: -90,
                                      sectionsSpace: 0,
                                      centerSpaceRadius: 56,
                                      sections: [
                                        PieChartSectionData(
                                          value: _spent,
                                          color: overBudget
                                              ? const Color(0xFFE45D5D)
                                              : brandColor,
                                          radius: 22,
                                          title: '',
                                        ),
                                        PieChartSectionData(
                                          value: remaining > 0
                                              ? remaining
                                              : (_budget == 0 ? 1 : 0),
                                          color: const Color(0xFFF0EBFA),
                                          radius: 18,
                                          title: '',
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Php ${_spent.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16),
                                      ),
                                      const Text('spent',
                                          style: TextStyle(
                                              color: mutedText, fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (overBudget)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEEEE),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_rounded,
                                        color: Color(0xFFE45D5D), size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Over budget by Php ${(_spent - _budget).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          color: Color(0xFFE45D5D),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Row(
                                children: [
                                  const Text('Left to spend:',
                                      style: TextStyle(
                                          color: mutedText, fontSize: 12)),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0EBFA),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      'Php ${remaining.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                          ] else ...[
                            const SizedBox(height: 16),
                            const Center(
                              child: Text(
                                'Set a monthly budget to see your spending overview.',
                                textAlign: TextAlign.center,
                                style:
                                    TextStyle(color: mutedText, fontSize: 13),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Spending by category',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    if (_categoryMap.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'No expense transactions yet.',
                            style: TextStyle(color: mutedText),
                          ),
                        ),
                      )
                    else
                      for (final entry in _sortedCategories)
                        _CategoryTile(
                          title: entry.key,
                          amount: entry.value,
                          color: categoryColor(entry.key),
                        ),
                  ],
                ),
              ),
            ),
    );
  }

  List<MapEntry<String, double>> get _sortedCategories {
    final entries = _categoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }
}

// ─── Category tile ─────────────────────────────────────────────────────────

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.title,
    required this.amount,
    required this.color,
    this.onTap,
  });

  final String title;
  final double amount;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
              child: Icon(categoryIcon(title), color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFF7E7A8E), size: 18),
            const SizedBox(width: 4),
            Text(
              'Php ${amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
