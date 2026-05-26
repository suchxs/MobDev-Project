import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/session.dart';
import 'spending_utils.dart';

class CategoryDetailScreen extends StatefulWidget {
  const CategoryDetailScreen({
    super.key,
    this.categoryName,
    this.transactions,
  });

  final String? categoryName;
  final List<Map<String, dynamic>>? transactions;

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  static const _apiBaseUrl = 'https://tipidtrack.dcism.org';
  static const brandColor = Color(0xFF8C6AE6);
  static const surfaceColor = Color(0xFFF6F3FB);
  static const mutedText = Color(0xFF7E7A8E);

  bool _isLoading = true;
  double _budget = 0;
  String? _selectedCategory;

  // All expense transactions grouped by category
  Map<String, List<Map<String, dynamic>>> _allCategoryTx = {};

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.categoryName;
    if (widget.transactions != null && widget.categoryName != null) {
      // Data pre-loaded from parent — no need to fetch
      _allCategoryTx = {widget.categoryName!: widget.transactions!};
      _loadBudgetOnly();
    } else {
      _loadAll();
    }
  }

  Future<void> _loadBudgetOnly() async {
    final token = AppSession.instance.token;
    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final res = await http.get(
        Uri.parse('$_apiBaseUrl/api/budget'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _budget = double.tryParse(d['monthly_amount'].toString()) ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAll() async {
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

      final catTxMap = <String, List<Map<String, dynamic>>>{};
      if (results[1].statusCode == 200) {
        final d = jsonDecode(results[1].body) as Map<String, dynamic>;
        for (final tx in (d['transactions'] as List<dynamic>? ?? [])) {
          if ((tx['type'] as String?)?.toLowerCase() != 'expense') continue;
          final cat = (tx['category'] as String?) ?? 'General';
          catTxMap.putIfAbsent(cat, () => []).add(tx as Map<String, dynamic>);
        }
      }

      if (!mounted) return;
      setState(() {
        _budget = budget;
        _allCategoryTx = catTxMap;
        // Auto-select first if none selected
        if (_selectedCategory == null && catTxMap.isNotEmpty) {
          final sorted = catTxMap.entries.toList()
            ..sort((a, b) {
              final aTotal =
                  a.value.fold<double>(0, (s, t) => s + (double.tryParse(t['amount'].toString()) ?? 0));
              final bTotal =
                  b.value.fold<double>(0, (s, t) => s + (double.tryParse(t['amount'].toString()) ?? 0));
              return bTotal.compareTo(aTotal);
            });
          _selectedCategory = sorted.first.key;
        }
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
        onSaved: _loadAll,
      ),
    );
  }

  List<Map<String, dynamic>> get _currentTxList =>
      _selectedCategory == null ? [] : (_allCategoryTx[_selectedCategory] ?? []);

  double get _currentTotal =>
      _currentTxList.fold(0.0, (s, t) => s + (double.tryParse(t['amount'].toString()) ?? 0));

  @override
  Widget build(BuildContext context) {
    final color = _selectedCategory != null
        ? categoryColor(_selectedCategory!)
        : brandColor;
    final categories = _allCategoryTx.keys.toList()
      ..sort((a, b) {
        final aTotal = _allCategoryTx[a]!
            .fold<double>(0, (s, t) => s + (double.tryParse(t['amount'].toString()) ?? 0));
        final bTotal = _allCategoryTx[b]!
            .fold<double>(0, (s, t) => s + (double.tryParse(t['amount'].toString()) ?? 0));
        return bTotal.compareTo(aTotal);
      });

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
          'Category Detail',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _openAdjust,
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Adjust budget',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: brandColor))
          : RefreshIndicator(
              color: brandColor,
              onRefresh: widget.categoryName != null ? _loadBudgetOnly : _loadAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category picker if no category was pre-selected
                    if (widget.categoryName == null && categories.length > 1) ...[
                      const Text('Select category',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final cat = categories[i];
                            final isSelected = cat == _selectedCategory;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedCategory = cat),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? categoryColor(cat)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: categoryColor(cat),
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  cat,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : categoryColor(cat),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    if (_selectedCategory == null) ...[
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Column(
                            children: [
                              const Icon(Icons.bar_chart_rounded,
                                  size: 52, color: mutedText),
                              const SizedBox(height: 12),
                              const Text('No expense data yet.',
                                  style:
                                      TextStyle(color: mutedText, fontSize: 15)),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // Header card
                      Center(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: color.withValues(alpha: 0.18),
                              child: Icon(categoryIcon(_selectedCategory!),
                                  color: color, size: 26),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedCategory!,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 18),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_currentTxList.length} transaction${_currentTxList.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                  color: mutedText, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Spending card
                      Container(
                        padding: const EdgeInsets.all(16),
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
                            const Text('Total spent in this category',
                                style:
                                    TextStyle(color: mutedText, fontSize: 12)),
                            const SizedBox(height: 8),
                            Text(
                              'Php ${_currentTotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: color),
                            ),
                            if (_budget > 0) ...[
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  minHeight: 7,
                                  value: (_currentTotal / _budget).clamp(0, 1),
                                  backgroundColor: const Color(0xFFF3F0FA),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      _currentTotal > _budget
                                          ? const Color(0xFFE45D5D)
                                          : color),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${((_currentTotal / _budget) * 100).toStringAsFixed(1)}% of monthly budget (Php ${_budget.toStringAsFixed(0)})',
                                style: const TextStyle(
                                    color: mutedText, fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text('Transactions',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      if (_currentTxList.isEmpty)
                        const Center(
                            child: Text('No transactions.',
                                style: TextStyle(color: mutedText)))
                      else
                        for (final tx in _currentTxList)
                          _TxRow(
                            title: (tx['title'] as String?) ?? 'Transaction',
                            amount: double.tryParse(
                                    tx['amount'].toString()) ??
                                0,
                            icon: categoryIcon(
                                (tx['category'] as String?) ?? ''),
                            color: color,
                          ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String title;
  final double amount;
  final IconData icon;
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
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text(
            '- Php ${amount.toStringAsFixed(2)}',
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: Color(0xFFE3696A)),
          ),
        ],
      ),
    );
  }
}
