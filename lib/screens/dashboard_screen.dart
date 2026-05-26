import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'budget_screen.dart';
import 'cards_screen.dart';
import 'expenses_screen.dart';
import 'profile_screen.dart';
import '../services/session.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const String _apiBaseUrl = 'https://tipidtrack.dcism.org';
  static const String _guideFlagKey = 'hasSeenGuide';

  bool _isLoading = true;
  bool _isBalanceLoading = true;
  double _balanceTotal = 0;
  List<_TransactionItem> _transactions = [];
  bool _showGuide = false;
  int _guideStep = 0;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _loadBalance();
    _loadGuideStatus();
  }

  Future<void> _loadGuideStatus() async {
    if (!AppSession.instance.showGuideAfterLogin) return;
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool(_guideFlagKey) ?? false;
    if (!mounted) return;
    if (!hasSeen) {
      setState(() {
        _showGuide = true;
        _guideStep = 0;
      });
    }
    AppSession.instance.showGuideAfterLogin = false;
  }

  Future<void> _completeGuide() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guideFlagKey, true);
    if (!mounted) return;
    setState(() {
      _showGuide = false;
      _guideStep = 0;
    });
  }

  Future<void> _loadBalance() async {
    final token = AppSession.instance.token;
    if (token == null || token.isEmpty) {
      setState(() => _isBalanceLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/balance'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final total = (data['total'] as num?)?.toDouble() ?? 0.0;
        if (!mounted) return;
        setState(() {
          _balanceTotal = total;
          _isBalanceLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _isBalanceLoading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isBalanceLoading = false);
    }
  }

  Future<void> _loadTransactions() async {
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
        final items = (data['transactions'] as List<dynamic>? ?? [])
            .map((item) => _TransactionItem.fromJson(item))
            .toList();
        if (!mounted) return;
        setState(() {
          _transactions = items;
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
    final displayName = AppSession.instance.fullName ?? 'there';

    void openExpenses() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ExpensesScreen()),
      );
    }

    void openBudget() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BudgetScreen()),
      );
    }

    void openCards() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CardsScreen()),
      );
    }

    void openProfile() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    }

    return Scaffold(
      backgroundColor: surfaceColor,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: Color(0xFFE8E2F6),
                    child: Icon(Icons.person_outline, color: brandColor),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good Morning, $displayName!',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Have a good day!',
                        style: TextStyle(
                          fontSize: 12,
                          color: mutedText,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Stack(
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.notifications_none_rounded),
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          height: 8,
                          width: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE45D5D),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                decoration: BoxDecoration(
                  color: brandColor,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: brandColor.withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total balance',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _isBalanceLoading
                              ? '—'
                              : _balanceTotal.toStringAsFixed(2),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 3),
                          child: Text(
                            'PHP',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _ActionChip(
                          label: 'Add Expense',
                          icon: Icons.remove,
                        ),
                        const SizedBox(width: 10),
                        _ActionChip(
                          label: 'Add Income',
                          icon: Icons.add,
                        ),
                        const SizedBox(width: 10),
                        _ActionChip(
                          label: 'Budget',
                          icon: Icons.pie_chart_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFECE3FB),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Set a financial budget',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Setting a budget helps you track\n'
                            'your finance easier with\n'
                            'TipidTrack',
                            style: TextStyle(
                              color: Colors.black.withValues(alpha: 0.6),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 30,
                            child: ElevatedButton(
                              onPressed: openBudget,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brandColor,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: const Text('Set up now'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 70,
                      width: 70,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: brandColor,
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Text(
                    'Transactions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {},
                    child: const Text('view all'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_transactions.isEmpty)
                Text(
                  'No transactions yet. Add your first entry.',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.6),
                  ),
                )
              else
                for (final transaction in _transactions)
                  _TransactionTile(
                    title: transaction.title,
                    subtitle: transaction.category,
                    amount: transaction.formattedAmount,
                    icon: transaction.icon,
                    iconColor: transaction.iconColor,
                  ),
                ],
              ),
            ),
            if (_showGuide)
              _GuideOverlay(
                step: _guideStep,
                onNext: () {
                  if (_guideStep >= 2) {
                    _completeGuide();
                  } else {
                    setState(() => _guideStep += 1);
                  }
                },
                onSkip: _completeGuide,
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            openCards();
          }
          if (index == 2) {
            openExpenses();
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

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: amount.startsWith('-')
                  ? const Color(0xFFE3696A)
                  : const Color(0xFF4CAF81),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionItem {
  _TransactionItem({
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
    final prefix = isIncome ? '+' : '-';
    return '$prefix Php ${amount.toStringAsFixed(2)}';
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
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
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
      case 'wallet':
        return const Color(0xFF7AD7AA);
      default:
        return const Color(0xFF7E7A8E);
    }
  }

  factory _TransactionItem.fromJson(Map<String, dynamic> json) {
    return _TransactionItem(
      title: json['title'] as String? ?? 'Transaction',
      category: json['category'] as String? ?? 'General',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      isIncome: (json['type'] as String?)?.toLowerCase() == 'income',
    );
  }
}


class _GuideOverlay extends StatelessWidget {
  const _GuideOverlay({
    required this.step,
    required this.onNext,
    required this.onSkip,
  });

  final int step;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    String title;
    String message;
    Alignment bubbleAlignment;
    Offset bubbleOffset;

    switch (step) {
      case 0:
        title = 'Balance card';
        message = 'See your total balance at a glance.';
        bubbleAlignment = Alignment.topCenter;
        bubbleOffset = const Offset(0, 140);
        break;
      case 1:
        title = 'Quick actions';
        message = 'Add expense, income, or open budget tools here.';
        bubbleAlignment = Alignment.topCenter;
        bubbleOffset = const Offset(0, 320);
        break;
      default:
        title = 'Navigation';
        message = 'Switch between Home, Cards, and Expenses.';
        bubbleAlignment = Alignment.bottomCenter;
        bubbleOffset = const Offset(0, -120);
        break;
    }

    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        child: Stack(
          children: [
            Positioned(
              top: 12,
              right: 12,
              child: TextButton(
                onPressed: onSkip,
                child: const Text(
                  'Skip',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            Align(
              alignment: bubbleAlignment,
              child: Transform.translate(
                offset: bubbleOffset,
                child: Container(
                  width: size.width * 0.78,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: onNext,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(step >= 2 ? 'Done' : 'Next'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
