import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/session.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  static const String _apiBaseUrl = 'https://tipidtrack.dcism.org';
  static const brandColor = Color(0xFF8C6AE6);
  static const surfaceColor = Color(0xFFF6F3FB);
  static const mutedText = Color(0xFF7E7A8E);

  bool _isLoading = true;
  double _monthlyBudget = 0;
  double _totalSpent = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final token = AppSession.instance.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Not authenticated.';
      });
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
          Uri.parse('$_apiBaseUrl/api/expenses/summary'),
          headers: headers,
        ),
      ]);

      if (!mounted) return;

      double budget = 0;
      double spent = 0;

      if (results[0].statusCode == 200) {
        final data = jsonDecode(results[0].body) as Map<String, dynamic>;
        budget = double.tryParse(data['monthly_amount'].toString()) ?? 0;
      }
      if (results[1].statusCode == 200) {
        final data = jsonDecode(results[1].body) as Map<String, dynamic>;
        spent = double.tryParse(data['total'].toString()) ?? 0;
      }

      setState(() {
        _monthlyBudget = budget;
        _totalSpent = spent;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load budget data.';
      });
    }
  }

  Future<void> _saveBudget(double amount) async {
    final token = AppSession.instance.token;
    if (token == null || token.isEmpty) return;

    final response = await http.post(
      Uri.parse('$_apiBaseUrl/api/budget'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'monthly_amount': amount}),
    );

    if (response.statusCode == 200 && mounted) {
      setState(() => _monthlyBudget = amount);
    }
  }

  void _showSetBudgetDialog() {
    final controller = TextEditingController(
      text: _monthlyBudget > 0 ? _monthlyBudget.toStringAsFixed(2) : '',
    );
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Set Monthly Budget',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount (PHP)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final amount =
                            double.tryParse(controller.text.trim());
                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Enter a valid amount.'),
                            ),
                          );
                          return;
                        }
                        setDialogState(() => isSaving = true);
                        await _saveBudget(amount);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (_monthlyBudget - _totalSpent).clamp(0.0, double.infinity);
    final progress = _monthlyBudget > 0
        ? (_totalSpent / _monthlyBudget).clamp(0.0, 1.0)
        : 0.0;
    final isOverBudget = _monthlyBudget > 0 && _totalSpent > _monthlyBudget;

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
          'Monthly Budget',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_errorMessage!,
                          style: const TextStyle(color: mutedText)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandColor,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Budget overview card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: brandColor,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: brandColor.withValues(alpha: 0.28),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Monthly Budget',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _monthlyBudget == 0
                                ? Text(
                                    'Not set yet',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Php ${_monthlyBudget.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                            if (_monthlyBudget > 0) ...[
                              const SizedBox(height: 18),
                              // Progress bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 10,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.25),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isOverBudget
                                        ? const Color(0xFFFF6B6B)
                                        : Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isOverBudget
                                        ? 'Over budget!'
                                        : '${(progress * 100).toStringAsFixed(0)}% used',
                                    style: TextStyle(
                                      color: isOverBudget
                                          ? const Color(0xFFFF6B6B)
                                          : Colors.white.withValues(alpha: 0.85),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Php ${remaining.toStringAsFixed(2)} left',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.85),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Stats row
                      Row(
                        children: [
                          _StatCard(
                            label: 'Total Spent',
                            value: 'Php ${_totalSpent.toStringAsFixed(2)}',
                            iconColor: const Color(0xFFE3696A),
                            icon: Icons.arrow_downward_rounded,
                          ),
                          const SizedBox(width: 14),
                          _StatCard(
                            label: 'Remaining',
                            value: _monthlyBudget == 0
                                ? '—'
                                : 'Php ${remaining.toStringAsFixed(2)}',
                            iconColor: const Color(0xFF4CAF81),
                            icon: Icons.savings_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Set / Edit budget button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showSetBudgetDialog,
                          icon: Icon(
                            _monthlyBudget == 0
                                ? Icons.add_rounded
                                : Icons.edit_rounded,
                            size: 18,
                          ),
                          label: Text(
                            _monthlyBudget == 0
                                ? 'Set Monthly Budget'
                                : 'Edit Budget',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      if (_monthlyBudget == 0) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECE3FB),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: brandColor,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Set a monthly budget to track how much you can spend and stay on target.',
                                  style: TextStyle(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.iconColor,
    required this.icon,
  });

  final String label;
  final String value;
  final Color iconColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
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
            CircleAvatar(
              radius: 16,
              backgroundColor: iconColor.withValues(alpha: 0.15),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF7E7A8E),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

