import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'budget_screen.dart';
import 'cards_screen.dart';
import 'expenses_screen.dart';
import 'profile_screen.dart';
import 'transactions_screen.dart';
import '../services/session.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const String _apiBaseUrl = 'https://tipidtrack.dcism.org';

  bool _isLoading = true;
  bool _isBalanceLoading = true;
  bool _isBudgetLoading = true;
  double _balanceTotal = 0;
  double _monthlyBudget = 0;
  double _totalSpent = 0;
  List<TxItem> _transactions = [];
  List<_BalanceSource> _balanceSources = [];
  bool _showGuide = false;
  int _guideStep = 0;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _loadBalance();
    _loadBudget();
    _loadGuideStatus();
  }

  Future<void> _loadGuideStatus() async {
    if (!AppSession.instance.showGuideAfterLogin) return;
    AppSession.instance.showGuideAfterLogin = false;
    if (!mounted) return;
    setState(() {
      _showGuide = true;
      _guideStep = 0;
    });
  }

  void _completeGuide() {
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
      final results = await Future.wait([
        http.get(Uri.parse('$_apiBaseUrl/api/balance'),
            headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}),
        http.get(Uri.parse('$_apiBaseUrl/api/balance/breakdown'),
            headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}),
      ]);

      if (!mounted) return;
      final totalRes = results[0];
      final breakdownRes = results[1];

      double total = 0;
      List<_BalanceSource> sources = [];

      if (totalRes.statusCode == 200) {
        final data = jsonDecode(totalRes.body) as Map<String, dynamic>;
        total = (data['total'] as num?)?.toDouble() ?? 0.0;
      }
      if (breakdownRes.statusCode == 200) {
        final data = jsonDecode(breakdownRes.body) as Map<String, dynamic>;
        sources = (data['sources'] as List<dynamic>? ?? [])
            .map((s) => _BalanceSource(
                  name: s['name'] as String,
                  amount: (s['amount'] as num).toDouble(),
                  type: s['type'] as String,
                ))
            .toList();
      }

      setState(() {
        _balanceTotal = total;
        _balanceSources = sources;
        _isBalanceLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isBalanceLoading = false);
    }
  }

  Future<void> _loadBudget() async {
    final token = AppSession.instance.token;
    if (token == null || token.isEmpty) {
      setState(() => _isBudgetLoading = false);
      return;
    }
    try {
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      final results = await Future.wait([
        http.get(Uri.parse('$_apiBaseUrl/api/budget'), headers: headers),
        http.get(
            Uri.parse('$_apiBaseUrl/api/expenses/summary'), headers: headers),
      ]);
      if (!mounted) return;
      double budget = 0;
      double spent = 0;
      if (results[0].statusCode == 200) {
        final d = jsonDecode(results[0].body) as Map<String, dynamic>;
        budget = double.tryParse(d['monthly_amount'].toString()) ?? 0;
      }
      if (results[1].statusCode == 200) {
        final d = jsonDecode(results[1].body) as Map<String, dynamic>;
        final txSpent = double.tryParse(d['total'].toString()) ?? 0;
        final monthlyCharges = double.tryParse(d['monthly_charges']?.toString() ?? '0') ?? 0;
        spent = txSpent + monthlyCharges;
      }
      setState(() {
        _monthlyBudget = budget;
        _totalSpent = spent;
        _isBudgetLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isBudgetLoading = false);
    }
  }

  Future<bool> _addTransaction({
    required String title,
    required String category,
    required double amount,
    required bool isIncome,
    int? sourceCardId,
    String? sourceName,
  }) async {
    final token = AppSession.instance.token;
    if (token == null || token.isEmpty) return false;

    try {
      final rounded = double.parse(amount.toStringAsFixed(2));
      final body = <String, dynamic>{
        'title': title,
        'amount': rounded,
        'type': isIncome ? 'income' : 'expense',
      };
      if (!isIncome) body['category'] = category;
      if (sourceCardId != null) body['source_card_id'] = sourceCardId;
      if (sourceName != null) body['source_name'] = sourceName;

      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/transactions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 && mounted) {
        _loadTransactions();
        _loadBalance();
        _loadBudget();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void _showAddTransactionSheet(bool isIncome) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddTransactionSheet(
        isIncome: isIncome,
        apiBaseUrl: _apiBaseUrl,
        onSubmit: (title, category, amount, sourceCardId, sourceName) async {
          return _addTransaction(
            title: title,
            category: category,
            amount: amount,
            isIncome: isIncome,
            sourceCardId: sourceCardId,
            sourceName: sourceName,
          );
        },
      ),
    );
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
            .map((item) => TxItem.fromJson(item))
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

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadTransactions(),
      _loadBalance(),
      _loadBudget(),
    ]);
  }

  // Returns a time-aware greeting
  static String _greeting() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Good morning';
    if (h >= 12 && h < 17) return 'Good afternoon';
    if (h >= 17 && h < 21) return 'Good evening';
    return 'Good night';
  }

  // Returns a fun subtitle based on time
  static String _subtitle() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 9) return 'Rise and shine — let\'s check your finances ☀️';
    if (h >= 9 && h < 12) return 'Hope your morning is going great! 💪';
    if (h >= 12 && h < 14) return 'Lunch break? Review your spending 🍜';
    if (h >= 14 && h < 17) return 'Keep it up — you\'re doing awesome! 🚀';
    if (h >= 17 && h < 20) return 'Time to unwind and check your budget 🌇';
    if (h >= 20 && h < 23) return 'A quiet night to review your goals 🌙';
    return 'Burning midnight oil? Stay on budget 🔥';
  }

  // Build alert items based on current state
  List<_AlertItem> _buildAlerts() {
    final alerts = <_AlertItem>[];

    if (_monthlyBudget > 0) {
      final pct = _totalSpent / _monthlyBudget;
      if (_totalSpent > _monthlyBudget) {
        alerts.add(_AlertItem(
          icon: Icons.warning_rounded,
          color: const Color(0xFFE45D5D),
          title: 'Over budget!',
          body:
              'You\'ve spent Php ${_totalSpent.toStringAsFixed(2)} out of your Php ${_monthlyBudget.toStringAsFixed(2)} budget.',
        ));
      } else if (pct >= 0.8) {
        alerts.add(_AlertItem(
          icon: Icons.error_outline_rounded,
          color: const Color(0xFFF09D3A),
          title: 'Budget warning',
          body:
              'You\'ve used ${(pct * 100).toStringAsFixed(0)}% of your monthly budget. Php ${(_monthlyBudget - _totalSpent).toStringAsFixed(2)} remaining.',
        ));
      }
    } else {
      alerts.add(const _AlertItem(
        icon: Icons.lightbulb_outline_rounded,
        color: Color(0xFF8C6AE6),
        title: 'No budget set',
        body: 'Set a monthly budget to track your spending and get alerts.',
      ));
    }

    if (_balanceTotal < 0) {
      alerts.add(_AlertItem(
        icon: Icons.trending_down_rounded,
        color: const Color(0xFFE45D5D),
        title: 'Negative balance',
        body:
            'Your balance is Php ${_balanceTotal.toStringAsFixed(2)}. Consider adding income or reducing expenses.',
      ));
    }

    return alerts;
  }

  void _showAlertsSheet() {
    final alerts = _buildAlerts();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AlertsSheet(alerts: alerts),
    );
  }

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFF8C6AE6);
    const surfaceColor = Color(0xFFF6F3FB);
    const mutedText = Color(0xFF7E7A8E);
    final displayName = AppSession.instance.fullName ?? 'there';

    void openExpenses() async {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ExpensesScreen()),
      );
      _refreshAll();
    }

    void openBudget() async {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BudgetScreen()),
      );
      _refreshAll();
    }

    void openCards() async {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CardsScreen()),
      );
      _refreshAll();
    }

    void openProfile() async {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
      _refreshAll();
    }

    void openAllTransactions() async {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TransactionsScreen()),
      );
      _refreshAll();
    }

    return Scaffold(
      backgroundColor: surfaceColor,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _refreshAll,
              color: brandColor,
              child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                        '${_greeting()}, $displayName!',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: mutedText,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Alert bell — red dot when there are active alerts
                  Builder(builder: (_) {
                    final alerts = _buildAlerts();
                    final hasUrgent = alerts.any((a) =>
                        a.color == const Color(0xFFE45D5D) ||
                        a.color == const Color(0xFFF09D3A));
                    return Stack(
                      children: [
                        IconButton(
                          onPressed: _showAlertsSheet,
                          icon: const Icon(Icons.notifications_none_rounded),
                        ),
                        if (hasUrgent)
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
                    );
                  }),
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
                          onTap: () => _showAddTransactionSheet(false),
                        ),
                        const SizedBox(width: 10),
                        _ActionChip(
                          label: 'Add Income',
                          icon: Icons.add,
                          onTap: () => _showAddTransactionSheet(true),
                        ),
                        const SizedBox(width: 10),
                        _ActionChip(
                          label: 'Budget',
                          icon: Icons.pie_chart_rounded,
                          onTap: openBudget,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Balance source breakdown bar
              if (!_isBalanceLoading && _balanceSources.isNotEmpty)
                _BalanceBreakdownBar(sources: _balanceSources),
              const SizedBox(height: 18),
              // Budget card: shows progress if set, tip if not
              if (_isBudgetLoading)
                const SizedBox.shrink()
              else if (_monthlyBudget > 0)
                _BudgetProgressCard(
                  monthlyBudget: _monthlyBudget,
                  totalSpent: _totalSpent,
                  onTap: openBudget,
                )
              else
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
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Setting a budget helps you track\n'
                              'your finance easier with TipidTrack',
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
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
                    onPressed: openAllTransactions,
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
                for (final transaction in _transactions.take(5))
                  GestureDetector(
                    onTap: () async {
                      await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => EditTransactionSheet(
                          apiBaseUrl: _apiBaseUrl,
                          tx: transaction,
                          onSaved: _refreshAll,
                          onDeleted: () async {
                            final token = AppSession.instance.token;
                            if (token == null) return;
                            await http.delete(
                              Uri.parse(
                                  '$_apiBaseUrl/api/transactions/${transaction.id}'),
                              headers: {'Authorization': 'Bearer $token'},
                            );
                            await _refreshAll();
                          },
                        ),
                      );
                    },
                    child: _TransactionTile(
                      title: transaction.title,
                      subtitle: transaction.subtitle,
                      amount: transaction.formattedAmount,
                      icon: transaction.icon,
                      iconColor: transaction.iconColor,
                    ),
                  ),
                ],
              ),
            ),
            ),  // end RefreshIndicator
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
  const _ActionChip({
    required this.label,
    required this.icon,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
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

class _GuideOverlay extends StatelessWidget {
  const _GuideOverlay({
    required this.step,
    required this.onNext,
    required this.onSkip,
  });

  final int step;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  static const _steps = [
    (
      icon: Icons.account_balance_wallet_rounded,
      title: 'Your Balance',
      message:
          'See your total balance at a glance. It updates whenever you add income or an expense.',
    ),
    (
      icon: Icons.add_circle_outline_rounded,
      title: 'Quick Actions',
      message:
          'Tap Add Expense or Add Income to log a transaction instantly. Use Budget to set a monthly limit.',
    ),
    (
      icon: Icons.bar_chart_rounded,
      title: 'Track & Explore',
      message:
          'Use the bottom tabs to view your cards, browse all expenses, or manage your profile.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFF8C6AE6);
    final current = _steps[step];
    final isLast = step >= _steps.length - 1;

    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.6),
        child: SafeArea(
          child: Column(
            children: [
              // Skip button top-right
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 8),
                  child: TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Purple header with icon
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        decoration: const BoxDecoration(
                          color: brandColor,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: Icon(
                          current.icon,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                        child: Column(
                          children: [
                            Text(
                              current.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              current.message,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black.withValues(alpha: 0.6),
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            // Step dots
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                _steps.length,
                                (i) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: i == step ? 20 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: i == step
                                        ? brandColor
                                        : const Color(0xFFE0DCF0),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: onNext,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: brandColor,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                child: Text(isLast ? 'Get Started' : 'Next'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Add Transaction Sheet ─────────────────────────────────
typedef _OnSubmit = Future<bool> Function(
    String title, String category, double amount, int? sourceCardId, String? sourceName);

class _AddTransactionSheet extends StatefulWidget {
  const _AddTransactionSheet({
    required this.isIncome,
    required this.apiBaseUrl,
    required this.onSubmit,
  });
  final bool isIncome;
  final String apiBaseUrl;
  final _OnSubmit onSubmit;

  @override
  State<_AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<_AddTransactionSheet> {
  static const _categories = [
    'Food', 'Transportation', 'Shopping', 'Bills', 'Personal', 'General',
  ];
  static const brandColor = Color(0xFF8C6AE6);

  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  String _selectedCategory = 'Food';
  int? _selectedCardId;
  String? _selectedCardName;
  bool _isSubmitting = false;
  bool _cardsLoading = true;
  List<_CardOption> _cards = [];

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    final token = AppSession.instance.token ?? '';
    try {
      final res = await http.get(
        Uri.parse('${widget.apiBaseUrl}/api/cards'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (data['cards'] as List<dynamic>? ?? [])
            .map((c) => _CardOption.fromJson(c))
            .where((c) => widget.isIncome ? c.type != 'credit' : true)
            .toList();
        if (mounted) setState(() { _cards = list; _cardsLoading = false; });
      } else {
        if (mounted) setState(() => _cardsLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _cardsLoading = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0DCF0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.isIncome
                        ? const Color(0xFFE8F5EE)
                        : const Color(0xFFFDECEC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    widget.isIncome
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    color: widget.isIncome
                        ? const Color(0xFF4CAF7A)
                        : const Color(0xFFE45D5D),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.isIncome ? 'Add Income' : 'Add Expense',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _Field(controller: _titleCtrl, label: 'Title'),
            const SizedBox(height: 12),
            // Category only for expenses
            if (!widget.isIncome) ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: _inputDecor('Category'),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedCategory = v);
                },
              ),
              const SizedBox(height: 12),
            ],
            _Field(
              controller: _amountCtrl,
              label: 'Amount (PHP)',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            // Source selector
            InkWell(
              onTap: _cardsLoading ? null : _pickSource,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: _inputDecor(
                  widget.isIncome ? 'Received into' : 'Paid with',
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _cardsLoading
                            ? 'Loading accounts...'
                            : (_selectedCardName ?? 'Cash (no account)'),
                        style: TextStyle(
                          color: _selectedCardName != null
                              ? const Color(0xFF2D2D3A)
                              : const Color(0xFF7E7A8E),
                        ),
                      ),
                    ),
                    const Icon(Icons.expand_more_rounded,
                        color: Color(0xFF7E7A8E), size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(widget.isIncome ? 'Add Income' : 'Add Expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickSource() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0DCF0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.isIncome ? 'Received into' : 'Paid with',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 10),
            // Cash option
            _SourceTile(
              icon: Icons.payments_rounded,
              label: 'Cash',
              sublabel: 'No specific account',
              color: const Color(0xFF7AD7AA),
              selected: _selectedCardId == null,
              onTap: () {
                setState(() { _selectedCardId = null; _selectedCardName = null; });
                Navigator.pop(context);
              },
            ),
            ..._cards.map((c) => _SourceTile(
              icon: c.type == 'credit'
                  ? Icons.credit_score_rounded
                  : Icons.account_balance_rounded,
              label: c.displayName,
              sublabel: c.sublabel,
              color: c.color,
              selected: _selectedCardId == c.id,
              onTap: () {
                setState(() {
                  _selectedCardId = c.id;
                  _selectedCardName = c.displayName;
                });
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (title.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields correctly.')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    final ok = await widget.onSubmit(
      title, _selectedCategory, amount,
      _selectedCardId, _selectedCardName,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save. Please try again.'),
          backgroundColor: Color(0xFFE3696A),
        ),
      );
    }
  }

  static InputDecoration _inputDecor(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.keyboardType,
  });
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
            color: selected ? color : const Color(0xFFE8E3F4),
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(sublabel,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF7E7A8E))),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}

class _CardOption {
  const _CardOption({
    required this.id,
    required this.name,
    required this.bankName,
    required this.type,
    required this.balance,
    required this.debtAmount,
  });
  final int id;
  final String name;
  final String bankName;
  final String type;
  final double balance;
  final double debtAmount;

  String get displayName => bankName.isNotEmpty ? '$bankName - $name' : name;

  String get sublabel {
    if (type == 'credit') {
      return 'Credit • Debt: Php ${debtAmount.toStringAsFixed(2)}';
    }
    return 'Php ${balance.toStringAsFixed(2)}';
  }

  Color get color {
    switch (type) {
      case 'credit':  return const Color(0xFFF8B26A);
      case 'debit':   return const Color(0xFF7FB3FF);
      default:        return const Color(0xFF8C6AE6);
    }
  }

  factory _CardOption.fromJson(Map<String, dynamic> json) {
    return _CardOption(
      id:         json['id'] as int,
      name:       json['card_name'] as String? ?? '',
      bankName:   json['bank_name'] as String? ?? '',
      type:       json['card_type'] as String? ?? 'debit',
      balance:    double.tryParse(json['balance'].toString()) ?? 0,
      debtAmount: double.tryParse(json['debt_amount'].toString()) ?? 0,
    );
  }
}

class _BudgetProgressCard extends StatelessWidget {
  const _BudgetProgressCard({
    required this.monthlyBudget,
    required this.totalSpent,
    required this.onTap,
  });

  final double monthlyBudget;
  final double totalSpent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFF8C6AE6);
    final isOver = totalSpent > monthlyBudget;
    final progress = (totalSpent / monthlyBudget).clamp(0.0, 1.0);
    final remaining = (monthlyBudget - totalSpent).clamp(0.0, double.infinity);
    final barColor = isOver ? const Color(0xFFE45D5D) : brandColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFE9FB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.pie_chart_rounded,
                      color: brandColor, size: 16),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Monthly Budget',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                if (isOver)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFECEC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '⚠ Over budget',
                      style: TextStyle(
                        color: Color(0xFFE45D5D),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFB0A9C2), size: 18),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Php ${totalSpent.toStringAsFixed(2)} spent',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isOver
                        ? const Color(0xFFE45D5D)
                        : const Color(0xFF2D2D3A),
                  ),
                ),
                Text(
                  'of Php ${monthlyBudget.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7E7A8E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: const Color(0xFFF0EDF8),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isOver
                  ? 'Php ${(totalSpent - monthlyBudget).toStringAsFixed(2)} over your budget'
                  : 'Php ${remaining.toStringAsFixed(2)} remaining  •  ${(progress * 100).toStringAsFixed(0)}% used',
              style: TextStyle(
                fontSize: 12,
                color: isOver
                    ? const Color(0xFFE45D5D)
                    : const Color(0xFF7E7A8E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertItem {
  const _AlertItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

class _AlertsSheet extends StatelessWidget {
  const _AlertsSheet({required this.alerts});
  final List<_AlertItem> alerts;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0D8F0),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Alerts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ...alerts.map((a) => _AlertRow(item: a)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.item});
  final _AlertItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, color: item.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: item.color,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.body,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5A5670),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Balance breakdown data model ─────────────────────────────────────────────

class _BalanceSource {
  const _BalanceSource({
    required this.name,
    required this.amount,
    required this.type,
  });
  final String name;
  final double amount;
  final String type; // 'debit', 'cash', 'credit_debt', etc.
}

// ─── Balance breakdown bar widget ─────────────────────────────────────────────

class _BalanceBreakdownBar extends StatelessWidget {
  const _BalanceBreakdownBar({required this.sources});

  final List<_BalanceSource> sources;

  static const List<Color> _palette = [
    Color(0xFF8C6AE6),
    Color(0xFF7FB3FF),
    Color(0xFFF8B26A),
    Color(0xFF7AD7AA),
    Color(0xFFB38AF7),
    Color(0xFF62CFD6),
    Color(0xFFFFD36E),
    Color(0xFFF4A0A0),
  ];

  static const Color _debtColor = Color(0xFFE45D5D);

  @override
  Widget build(BuildContext context) {
    // Assign stable colors: positive sources get palette colors, debts get red
    int paletteIdx = 0;
    final colored = sources.map((s) {
      final color = s.type == 'credit_debt'
          ? _debtColor
          : _palette[paletteIdx++ % _palette.length];
      return (source: s, color: color);
    }).toList();

    final positive = colored.where((e) => e.source.amount > 0).toList();
    final total = positive.fold(0.0, (sum, e) => sum + e.source.amount);

    if (total <= 0 && !sources.any((s) => s.type == 'credit_debt')) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Balance breakdown',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Color(0xFF2D2D3A),
            ),
          ),
          const SizedBox(height: 10),
          // Segmented bar — use LayoutBuilder so each segment fills exact % of width
          if (total > 0)
            LayoutBuilder(
              builder: (context, constraints) {
                final barWidth = constraints.maxWidth;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 12,
                    width: barWidth,
                    child: Row(
                      children: [
                        for (final entry in positive)
                          SizedBox(
                            width: (entry.source.amount / total) * barWidth,
                            height: 12,
                            child: ColoredBox(color: entry.color),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          if (total > 0) const SizedBox(height: 12),
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final entry in colored)
                _LegendChip(
                  label: entry.source.name,
                  amount: entry.source.amount,
                  color: entry.color,
                  pct: (total > 0 && entry.source.amount > 0)
                      ? (entry.source.amount / total * 100)
                      : null,
                  isDebt: entry.source.type == 'credit_debt',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.label,
    required this.amount,
    required this.color,
    this.pct,
    this.isDebt = false,
  });

  final String label;
  final double amount;
  final Color color;
  final double? pct;
  final bool isDebt;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D2D3A),
              ),
            ),
            Text(
              isDebt
                  ? '−Php ${amount.abs().toStringAsFixed(0)}'
                  : pct != null
                      ? '${pct!.toStringAsFixed(0)}% · Php ${amount.toStringAsFixed(0)}'
                      : 'Php ${amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 10,
                color: isDebt ? const Color(0xFFE45D5D) : const Color(0xFF7E7A8E),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
