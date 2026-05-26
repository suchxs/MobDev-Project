import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/session.dart';
import 'category_detail_screen.dart';
import 'spending_utils.dart';

class SpendingCategoryScreen extends StatefulWidget {
  const SpendingCategoryScreen({super.key});

  @override
  State<SpendingCategoryScreen> createState() =>
      _SpendingCategoryScreenState();
}

class _SpendingCategoryScreenState extends State<SpendingCategoryScreen> {
  static const _apiBaseUrl = 'https://tipidtrack.dcism.org';
  static const brandColor = Color(0xFF8C6AE6);
  static const surfaceColor = Color(0xFFF6F3FB);
  static const mutedText = Color(0xFF7E7A8E);

  bool _isLoading = true;
  int _touchedIndex = -1;
  double _budget = 0;
  double _spent = 0;
  Map<String, double> _categoryMap = {};
  Map<String, List<Map<String, dynamic>>> _categoryTxMap = {};

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
      final catTxMap = <String, List<Map<String, dynamic>>>{};
      if (results[1].statusCode == 200) {
        final d = jsonDecode(results[1].body) as Map<String, dynamic>;
        for (final tx in (d['transactions'] as List<dynamic>? ?? [])) {
          if ((tx['type'] as String?)?.toLowerCase() != 'expense') continue;
          final cat = (tx['category'] as String?) ?? 'General';
          final amt = double.tryParse(tx['amount'].toString()) ?? 0;
          catMap[cat] = (catMap[cat] ?? 0) + amt;
          catTxMap.putIfAbsent(cat, () => []).add(tx as Map<String, dynamic>);
        }
      }

      if (!mounted) return;
      setState(() {
        _budget = budget;
        _spent = catMap.values.fold(0, (a, b) => a + b);
        _categoryMap = catMap;
        _categoryTxMap = catTxMap;
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

  List<MapEntry<String, double>> get _sorted {
    final entries = _categoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (_budget - _spent).clamp(0.0, double.infinity);
    final sortedEntries = _sorted;

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
          'Spending Category',
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
                                _budget > 0
                                    ? 'Monthly budget: Php ${_budget.toStringAsFixed(0)}'
                                    : 'No budget set',
                                style: const TextStyle(
                                    color: mutedText, fontSize: 12),
                              ),
                              const Spacer(),
                              if (_budget == 0)
                                GestureDetector(
                                  onTap: _openAdjust,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: brandColor,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Text('Set',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (sortedEntries.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 32),
                                child: Text('No expense data yet.',
                                    style: TextStyle(color: mutedText)),
                              ),
                            )
                          else ...[
                            SizedBox(
                              height: 180,
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 55,
                                  pieTouchData: PieTouchData(
                                    touchCallback: (event, response) {
                                      setState(() {
                                        _touchedIndex = response?.touchedSection
                                                ?.touchedSectionIndex ??
                                            -1;
                                      });
                                    },
                                  ),
                                  sections: List.generate(
                                      sortedEntries.length, (i) {
                                    final isTouched = i == _touchedIndex;
                                    final entry = sortedEntries[i];
                                    return PieChartSectionData(
                                      value: entry.value,
                                      color: categoryColor(entry.key),
                                      radius: isTouched ? 28 : 22,
                                      title: isTouched
                                          ? entry.key.length > 8
                                              ? '${entry.key.substring(0, 6)}…'
                                              : entry.key
                                          : '',
                                      titleStyle: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white),
                                    );
                                  }),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Legend
                            Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              children: sortedEntries.map((e) {
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: categoryColor(e.key),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(e.key,
                                        style: const TextStyle(fontSize: 11)),
                                  ],
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text('Total spent: Php ${_spent.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                const Spacer(),
                                if (_budget > 0)
                                  Text(
                                    'Remaining: Php ${remaining.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _spent > _budget
                                          ? const Color(0xFFE45D5D)
                                          : const Color(0xFF4CAF7A),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Breakdown by category',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    for (final entry in sortedEntries)
                      _CategoryRow(
                        title: entry.key,
                        amount: entry.value,
                        txCount: _categoryTxMap[entry.key]?.length ?? 0,
                        color: categoryColor(entry.key),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CategoryDetailScreen(
                                categoryName: entry.key,
                                transactions:
                                    _categoryTxMap[entry.key] ?? [],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.title,
    required this.amount,
    required this.txCount,
    required this.color,
    required this.onTap,
  });

  final String title;
  final double amount;
  final int txCount;
  final Color color;
  final VoidCallback onTap;

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('$txCount transaction${txCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: Color(0xFF7E7A8E), fontSize: 12)),
                ],
              ),
            ),
            Text('Php ${amount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFF7E7A8E), size: 18),
          ],
        ),
      ),
    );
  }
}
