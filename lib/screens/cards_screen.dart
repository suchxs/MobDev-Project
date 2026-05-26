import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'dashboard_screen.dart';
import 'expenses_screen.dart';
import 'profile_screen.dart';
import '../services/session.dart';

class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  static const String _apiBaseUrl = 'https://tipidtrack.dcism.org';
  static const brandColor = Color(0xFF8C6AE6);
  static const surfaceColor = Color(0xFFF6F3FB);
  static const mutedText = Color(0xFF7E7A8E);

  bool _isLoading = true;
  List<_AccountModel> _accounts = [];

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    final token = AppSession.instance.token;
    if (token == null || token.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final res = await http.get(
        Uri.parse('$_apiBaseUrl/api/cards'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (data['cards'] as List<dynamic>? ?? [])
            .map((e) => _AccountModel.fromJson(e))
            .toList();
        if (!mounted) return;
        setState(() { _accounts = list; _isLoading = false; });
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAccount(int id) async {
    final token = AppSession.instance.token ?? '';
    await http.delete(
      Uri.parse('$_apiBaseUrl/api/cards/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    await _loadCards();
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddAccountSheet(
        apiBaseUrl: _apiBaseUrl,
        onSaved: _loadCards,
      ),
    );
  }

  void _showEditSheet(_AccountModel acct) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddAccountSheet(
        apiBaseUrl: _apiBaseUrl,
        onSaved: _loadCards,
        existing: acct,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    void openDashboard() =>
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
    void openExpenses() =>
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ExpensesScreen()),
        );
    void openProfile() =>
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );

    final debit = _accounts.where((a) => a.type != 'credit').toList();
    final credit = _accounts.where((a) => a.type == 'credit').toList();

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        title: const Text('Accounts & Cards',
            style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: brandColor),
            onPressed: _showAddSheet,
            tooltip: 'Add account',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCards,
        color: brandColor,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: brandColor))
            : _accounts.isEmpty
                ? _EmptyState(onAdd: _showAddSheet)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (debit.isNotEmpty) ...[
                        _SectionHeader(
                          icon: Icons.account_balance_rounded,
                          label: 'Bank Accounts & Debit',
                        ),
                        const SizedBox(height: 8),
                        for (final a in debit)
                          _AccountCard(
                            account: a,
                            onEdit: () => _showEditSheet(a),
                            onDelete: () => _confirmDelete(a),
                          ),
                        const SizedBox(height: 16),
                      ],
                      if (credit.isNotEmpty) ...[
                        _SectionHeader(
                          icon: Icons.credit_score_rounded,
                          label: 'Credit Cards',
                        ),
                        const SizedBox(height: 8),
                        for (final a in credit)
                          _AccountCard(
                            account: a,
                            onEdit: () => _showEditSheet(a),
                            onDelete: () => _confirmDelete(a),
                          ),
                      ],
                    ],
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        backgroundColor: brandColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Account'),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        onTap: (i) {
          if (i == 0) openDashboard();
          if (i == 2) openExpenses();
          if (i == 3) openProfile();
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: brandColor,
        unselectedItemColor: mutedText,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.credit_card_rounded), label: 'Cards'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Expenses'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }

  void _confirmDelete(_AccountModel acct) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete account?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Remove "${acct.displayName}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteAccount(acct.id);
            },
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE45D5D)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF8C6AE6)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Color(0xFF5A5670),
              letterSpacing: 0.3,
            )),
      ],
    );
  }
}

// ── Account card tile ─────────────────────────────────────
class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.onEdit,
    required this.onDelete,
  });
  final _AccountModel account;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isCredit = account.type == 'credit';
    final gradient = isCredit
        ? [const Color(0xFFE05FA0), const Color(0xFFF8943A)]
        : account.type == 'cash'
            ? [const Color(0xFF6BC5A4), const Color(0xFF4EA8D5)]
            : [const Color(0xFF6C7FE2), const Color(0xFF8C6AE6)];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.bankName.isNotEmpty
                            ? account.bankName
                            : account.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      if (account.bankName.isNotEmpty)
                        Text(
                          account.name,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isCredit
                        ? 'Credit'
                        : account.type == 'cash'
                            ? 'Cash'
                            : 'Debit',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isCredit) ...[
                        Text(
                          'Current Debt',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          'Php ${account.debtAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Limit: Php ${account.creditLimit.toStringAsFixed(2)}  •  Monthly: Php ${account.monthlyCharge.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Balance',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          'Php ${account.balance.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  children: [
                    _CardAction(
                      icon: Icons.edit_rounded,
                      onTap: onEdit,
                    ),
                    const SizedBox(width: 8),
                    _CardAction(
                      icon: Icons.delete_rounded,
                      onTap: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFEFE9FB),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.credit_card_rounded,
                color: Color(0xFF8C6AE6), size: 40),
          ),
          const SizedBox(height: 16),
          const Text('No accounts yet',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          const Text(
            'Add your bank accounts, debit or\ncredit cards to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF7E7A8E), fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Account'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8C6AE6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add / Edit Account Sheet ──────────────────────────────
class _AddAccountSheet extends StatefulWidget {
  const _AddAccountSheet({
    required this.apiBaseUrl,
    required this.onSaved,
    this.existing,
  });
  final String apiBaseUrl;
  final VoidCallback onSaved;
  final _AccountModel? existing;

  @override
  State<_AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends State<_AddAccountSheet> {
  static const brandColor = Color(0xFF8C6AE6);

  String _selectedType = 'debit';
  final _bankCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();
  final _creditLimitCtrl = TextEditingController();
  final _debtCtrl = TextEditingController();
  final _monthlyCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _selectedType = e.type;
      _bankCtrl.text = e.bankName;
      _nameCtrl.text = e.name;
      _balanceCtrl.text = e.balance > 0 ? e.balance.toStringAsFixed(2) : '';
      _creditLimitCtrl.text =
          e.creditLimit > 0 ? e.creditLimit.toStringAsFixed(2) : '';
      _debtCtrl.text = e.debtAmount > 0 ? e.debtAmount.toStringAsFixed(2) : '';
      _monthlyCtrl.text =
          e.monthlyCharge > 0 ? e.monthlyCharge.toStringAsFixed(2) : '';
    }
  }

  @override
  void dispose() {
    _bankCtrl.dispose();
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    _creditLimitCtrl.dispose();
    _debtCtrl.dispose();
    _monthlyCtrl.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.existing != null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: SingleChildScrollView(
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
                _isEdit ? 'Edit Account' : 'Add Account',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              // Type selector (only on create)
              if (!_isEdit) ...[
                const Text('Account type',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7E7A8E))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _TypeChip(
                      label: 'Debit / Bank',
                      icon: Icons.account_balance_rounded,
                      selected: _selectedType == 'debit',
                      color: const Color(0xFF6C7FE2),
                      onTap: () => setState(() => _selectedType = 'debit'),
                    ),
                    const SizedBox(width: 8),
                    _TypeChip(
                      label: 'Credit Card',
                      icon: Icons.credit_score_rounded,
                      selected: _selectedType == 'credit',
                      color: const Color(0xFFE05FA0),
                      onTap: () => setState(() => _selectedType = 'credit'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              _Field2(controller: _bankCtrl, label: 'Bank name (e.g. BDO, BPI)'),
              const SizedBox(height: 10),
              _Field2(controller: _nameCtrl,
                  label: _selectedType == 'credit'
                      ? 'Card name (e.g. Classic Visa)'
                      : 'Account name (e.g. Savings)'),
              const SizedBox(height: 10),
              if (_selectedType != 'credit') ...[
                _Field2(
                  controller: _balanceCtrl,
                  label: 'Current balance (PHP)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                  ],
                ),
              ] else ...[
                _Field2(
                  controller: _creditLimitCtrl,
                  label: 'Credit limit (PHP)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                  ],
                ),
                const SizedBox(height: 10),
                _Field2(
                  controller: _debtCtrl,
                  label: 'Current debt / balance owed (PHP)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                  ],
                ),
                const SizedBox(height: 10),
                _Field2(
                  controller: _monthlyCtrl,
                  label: 'Monthly charge / minimum due (PHP)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: Color(0xFFF09D3A), size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Credit debt reduces your total balance. Monthly charges count toward your budget usage.',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8C6A30),
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 18, width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(_isEdit ? 'Save Changes' : 'Add Account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an account name.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    final token = AppSession.instance.token ?? '';
    final body = {
      'card_name': name,
      'card_type': _selectedType,
      'bank_name': _bankCtrl.text.trim(),
      'last4': '0000',
      'balance': double.tryParse(_balanceCtrl.text) ?? 0,
      'credit_limit': double.tryParse(_creditLimitCtrl.text) ?? 0,
      'debt_amount': double.tryParse(_debtCtrl.text) ?? 0,
      'monthly_charge': double.tryParse(_monthlyCtrl.text) ?? 0,
    };
    try {
      final http.Response res;
      if (_isEdit) {
        res = await http.put(
          Uri.parse('${widget.apiBaseUrl}/api/cards/${widget.existing!.id}'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        );
      } else {
        res = await http.post(
          Uri.parse('${widget.apiBaseUrl}/api/cards'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        );
      }
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        Navigator.of(context).pop();
        widget.onSaved();
      } else {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save. Try again.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection error. Try again.')),
      );
    }
  }
}

// ── Type chip selector ────────────────────────────────────
class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : Colors.white,
            border: Border.all(
              color: selected ? color : const Color(0xFFE0D8F0),
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: selected ? color : const Color(0xFF5A5670),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable text field ───────────────────────────────────
class _Field2 extends StatelessWidget {
  const _Field2({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.inputFormatters,
  });
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────
class _AccountModel {
  const _AccountModel({
    required this.id,
    required this.name,
    required this.bankName,
    required this.type,
    required this.balance,
    required this.creditLimit,
    required this.debtAmount,
    required this.monthlyCharge,
  });

  final int id;
  final String name;
  final String bankName;
  final String type;
  final double balance;
  final double creditLimit;
  final double debtAmount;
  final double monthlyCharge;

  String get displayName =>
      bankName.isNotEmpty ? '$bankName – $name' : name;

  factory _AccountModel.fromJson(Map<String, dynamic> json) {
    return _AccountModel(
      id:            json['id'] as int,
      name:          json['card_name'] as String? ?? '',
      bankName:      json['bank_name'] as String? ?? '',
      type:          json['card_type'] as String? ?? 'debit',
      balance:       double.tryParse(json['balance'].toString()) ?? 0,
      creditLimit:   double.tryParse(json['credit_limit'].toString()) ?? 0,
      debtAmount:    double.tryParse(json['debt_amount'].toString()) ?? 0,
      monthlyCharge: double.tryParse(json['monthly_charge'].toString()) ?? 0,
    );
  }
}
