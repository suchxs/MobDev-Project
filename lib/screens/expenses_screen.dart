import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'budget_screen.dart';
import 'cards_screen.dart';
import 'category_detail_screen.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'spending_allocation_screen.dart';
import 'spending_category_screen.dart';
import '../services/session.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  static const String _apiBaseUrl = 'https://tipidtrack.dcism.org';

  bool _isLoading = true;
  double _totalExpenses = 0;
  double _weekExpenses = 0;
  double _monthExpenses = 0;
  List<_ExpenseItem> _expenses = [];
  List<_CategorySummary> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final token = AppSession.instance.token;
    if (token == null || token.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/transactions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawItems = (data['transactions'] as List<dynamic>? ?? [])
            .map((item) => _ExpenseItem.fromJson(item))
            .where((item) => !item.isIncome)
            .toList();

        final total = rawItems.fold<double>(
            0, (sum, item) => sum + item.amount);
        final categoryMap = <String, double>{};
        for (final item in rawItems) {
          categoryMap.update(
            item.category,
            (value) => value + item.amount,
            ifAbsent: () => item.amount,
          );
        }

        final categories = categoryMap.entries
            .map((entry) => _CategorySummary(
                  name: entry.key,
                  amount: entry.value,
                  total: total,
                ))
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));

        if (!mounted) return;
        setState(() {
          _expenses = rawItems;
          _totalExpenses = total;
          _monthExpenses = total;
          _weekExpenses = total * 0.3;
          _categories = categories.take(4).toList();
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFF8C6AE6);
    const surfaceColor = Color(0xFFF6F3FB);
    const mutedText = Color(0xFF7E7A8E);

    void openDashboard() {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }

    void openCards() {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CardsScreen()),
      );
    }

    void openBudget() {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const BudgetScreen()),
      );
    }

    void openProfile() {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    }

    void openAllocation() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SpendingAllocationScreen()),
      );
    }

    void openSpendingCategory() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SpendingCategoryScreen()),
      );
    }

    void openCategoryDetail() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CategoryDetailScreen()),
      );
    }

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
          'Expenses',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
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
                  const Text(
                    'Total expenses',
                    style: TextStyle(
                      fontSize: 12,
                      color: mutedText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Php ${_totalExpenses.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _SummaryChip(
                        label: 'This week',
                        value: 'Php ${_weekExpenses.toStringAsFixed(2)}',
                      ),
                      const SizedBox(width: 10),
                      _SummaryChip(
                        label: 'This month',
                        value: 'Php ${_monthExpenses.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Spending insight',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _InsightCard(
              title: 'Spending allocation',
              subtitle: 'Monthly budget overview',
              icon: Icons.donut_large_rounded,
              onTap: openAllocation,
            ),
            _InsightCard(
              title: 'Spending category',
              subtitle: 'Breakdown by category',
              icon: Icons.pie_chart_rounded,
              onTap: openSpendingCategory,
            ),
            _InsightCard(
              title: 'Category detail',
              subtitle: 'See category limits',
              icon: Icons.favorite_rounded,
              onTap: openCategoryDetail,
            ),
            const SizedBox(height: 18),
            const Text(
              'Categories',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_categories.isEmpty)
              Text(
                'No categories yet.',
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.6),
                ),
              )
            else
              for (final category in _categories)
                _CategoryTile(
                  title: category.name,
                  amount: 'Php ${category.amount.toStringAsFixed(2)}',
                  percent: category.percentLabel,
                  color: category.color,
                ),
            const SizedBox(height: 18),
            const Text(
              'Recent expenses',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_expenses.isEmpty)
              Text(
                'No expenses yet.',
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.6),
                ),
              )
            else
              for (final expense in _expenses.take(6))
                _ExpenseTile(
                  title: expense.title,
                  subtitle: expense.category,
                  amount: expense.formattedAmount,
                  icon: expense.icon,
                  iconColor: expense.iconColor,
                ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) {
            openDashboard();
          }
          if (index == 1) {
            openCards();
          }
          if (index == 3) {
            openProfile();
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: brandColor,
        unselectedItemColor: mutedText,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.credit_card_rounded),
            label: 'Cards',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Expenses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ExpenseItem {
  _ExpenseItem({
    required this.title,
    required this.category,
    required this.amount,
    required this.isIncome,
  });

  final String title;
  final String category;
  final double amount;
  final bool isIncome;

  String get formattedAmount {
    return '- Php ${amount.toStringAsFixed(2)}';
  }

  IconData get icon {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant_rounded;
      case 'transportation':
      case 'transport':
        return Icons.directions_bus_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'bills':
        return Icons.receipt_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  Color get iconColor {
    switch (category.toLowerCase()) {
      case 'food':
        return const Color(0xFFF8B26A);
      case 'transportation':
      case 'transport':
        return const Color(0xFF7FB3FF);
      case 'shopping':
        return const Color(0xFFB38AF7);
      case 'bills':
        return const Color(0xFF7AD7AA);
      default:
        return const Color(0xFF7E7A8E);
    }
  }

  factory _ExpenseItem.fromJson(Map<String, dynamic> json) {
    return _ExpenseItem(
      title: json['title'] as String? ?? 'Expense',
      category: json['category'] as String? ?? 'General',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      isIncome: (json['type'] as String?)?.toLowerCase() == 'income',
    );
  }
}

class _CategorySummary {
  _CategorySummary({
    required this.name,
    required this.amount,
    required this.total,
  });

  final String name;
  final double amount;
  final double total;

  String get percentLabel {
    if (total <= 0) return '0%';
    final percent = (amount / total) * 100;
    return '${percent.toStringAsFixed(0)}%';
  }

  Color get color {
    switch (name.toLowerCase()) {
      case 'food':
        return const Color(0xFFF8B26A);
      case 'transportation':
      case 'transport':
        return const Color(0xFF7FB3FF);
      case 'shopping':
        return const Color(0xFFB38AF7);
      case 'bills':
        return const Color(0xFF7AD7AA);
      default:
        return const Color(0xFF7E7A8E);
    }
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F0FA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF7E7A8E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
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
              backgroundColor: const Color(0xFFEFE9FB),
              child: Icon(icon, color: const Color(0xFF8C6AE6)),
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
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFB0A9C2)),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.title,
    required this.amount,
    required this.percent,
    required this.color,
  });

  final String title;
  final String amount;
  final String percent;
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
            radius: 20,
            backgroundColor: color.withValues(alpha: 0.2),
            child: Icon(Icons.circle, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            amount,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 10),
          Text(
            percent,
            style: const TextStyle(
              color: Color(0xFF7E7A8E),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final String subtitle;
  final String amount;
  final IconData icon;
  final Color iconColor;

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
            radius: 20,
            backgroundColor: iconColor.withValues(alpha: 0.2),
            child: Icon(icon, color: iconColor),
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
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFFE3696A),
            ),
          ),
        ],
      ),
    );
  }
}
