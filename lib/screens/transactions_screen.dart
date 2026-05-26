import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/session.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  static const String _apiBaseUrl = 'https://tipidtrack.dcism.org';

  bool _isLoading = true;
  List<TxItem> _transactions = [];

  static const brandColor = Color(0xFF8C6AE6);
  static const surfaceColor = Color(0xFFF6F3FB);
  static const mutedText = Color(0xFF7E7A8E);

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
    try {
      final res = await http.get(
        Uri.parse('$_apiBaseUrl/api/transactions'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final items = (data['transactions'] as List<dynamic>? ?? [])
            .map((e) => TxItem.fromJson(e))
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

  Future<void> _deleteTransaction(int id) async {
    final token = AppSession.instance.token;
    if (token == null) return;
    await http.delete(
      Uri.parse('$_apiBaseUrl/api/transactions/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    await _load();
  }

  void _openEdit(TxItem tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditTransactionSheet(
        apiBaseUrl: _apiBaseUrl,
        tx: tx,
        onSaved: _load,
        onDeleted: () async {
          await _deleteTransaction(tx.id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'All Transactions',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: brandColor,
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: brandColor))
            : _transactions.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_rounded,
                                size: 56, color: mutedText),
                            SizedBox(height: 12),
                            Text(
                              'No transactions yet.',
                              style:
                                  TextStyle(color: mutedText, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _transactions.length,
                    itemBuilder: (ctx, i) {
                      final tx = _transactions[i];
                      return _TxTile(
                        tx: tx,
                        onTap: () => _openEdit(tx),
                      );
                    },
                  ),
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({required this.tx, required this.onTap});
  final TxItem tx;
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
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: tx.iconColor.withValues(alpha: 0.18),
              child: Icon(tx.icon, color: tx.iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.title,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    tx.subtitle,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  tx.formattedAmount,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: tx.isIncome
                        ? const Color(0xFF4CAF7A)
                        : const Color(0xFFE3696A),
                  ),
                ),
                const SizedBox(height: 2),
                const Icon(Icons.edit_rounded,
                    size: 13, color: Color(0xFFBBB7CC)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Edit Sheet ─────────────────────────────────────────────────────────────

class EditTransactionSheet extends StatefulWidget {
  const EditTransactionSheet({
    super.key,
    required this.apiBaseUrl,
    required this.tx,
    required this.onSaved,
    required this.onDeleted,
  });

  final String apiBaseUrl;
  final TxItem tx;
  final Future<void> Function() onSaved;
  final Future<void> Function() onDeleted;

  @override
  State<EditTransactionSheet> createState() => _EditTransactionSheetState();
}

class _EditTransactionSheetState extends State<EditTransactionSheet> {
  static const brandColor = Color(0xFF8C6AE6);
  static const mutedText = Color(0xFF7E7A8E);

  late final TextEditingController _titleCtrl;
  late final TextEditingController _amountCtrl;
  late String _category;
  int? _sourceCardId;
  String _sourceName = 'Cash';

  bool _isSaving = false;
  bool _isDeleting = false;
  bool _cardsLoading = true;
  List<_CardOpt> _cards = [];

  static const _categories = [
    'Food',
    'Transportation',
    'Shopping',
    'Bills',
    'Personal',
    'General'
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.tx.title);
    _amountCtrl =
        TextEditingController(text: widget.tx.amount.toStringAsFixed(2));
    _category = widget.tx.category.isEmpty ? 'General' : widget.tx.category;
    _sourceCardId = widget.tx.sourceCardId;
    _sourceName = widget.tx.sourceName ?? 'Cash';
    _fetchCards();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCards() async {
    final token = AppSession.instance.token;
    if (token == null) {
      setState(() => _cardsLoading = false);
      return;
    }
    try {
      final res = await http.get(
        Uri.parse('${widget.apiBaseUrl}/api/cards'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final raw = (data['cards'] as List<dynamic>? ?? []);
        final cards = raw.map((c) => _CardOpt(
              id: c['id'] as int,
              name: c['card_name'] as String? ?? 'Account',
              bankName: c['bank_name'] as String? ?? '',
              type: c['card_type'] as String? ?? 'debit',
            ));
        if (!mounted) return;
        setState(() {
          _cards = widget.tx.isIncome
              ? cards
                  .where((c) => c.type != 'credit')
                  .toList() // no credit cards for income
              : cards.toList();
          _cardsLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _cardsLoading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _cardsLoading = false);
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (title.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Check title and amount')));
      return;
    }

    setState(() => _isSaving = true);
    final token = AppSession.instance.token;
    try {
      final body = <String, dynamic>{
        'title': title,
        'amount': double.parse(amount.toStringAsFixed(2)),
        if (!widget.tx.isIncome) 'category': _category,
        if (_sourceCardId != null) 'source_card_id': _sourceCardId,
        'source_name': _sourceCardId == null ? 'Cash' : _sourceName,
      };
      final res = await http.put(
        Uri.parse('${widget.apiBaseUrl}/api/transactions/${widget.tx.id}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        Navigator.of(context).pop();
        await widget.onSaved();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to save')));
        setState(() => _isSaving = false);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Network error')));
      setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text(
            'This will permanently remove this transaction and update your balance.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style:
                  TextButton.styleFrom(foregroundColor: const Color(0xFFE45D5D)),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    if (!mounted) return;
    Navigator.of(context).pop();
    await widget.onDeleted();
  }

  void _pickSource() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.tx.isIncome ? 'Received into' : 'Paid with',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 14),
            // Cash option
            _SourceRow(
              label: 'Cash',
              sublabel: 'No specific account',
              icon: Icons.payments_rounded,
              color: const Color(0xFF26A69A),
              isSelected: _sourceCardId == null,
              onTap: () {
                setState(() {
                  _sourceCardId = null;
                  _sourceName = 'Cash';
                });
                Navigator.of(context).pop();
              },
            ),
            if (_cardsLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              for (final card in _cards)
                _SourceRow(
                  label: card.name,
                  sublabel: card.bankName,
                  icon: card.type == 'credit'
                      ? Icons.credit_card_rounded
                      : Icons.account_balance_rounded,
                  color: card.type == 'credit'
                      ? const Color(0xFFE45D5D)
                      : const Color(0xFF5B8AF6),
                  isSelected: _sourceCardId == card.id,
                  onTap: () {
                    setState(() {
                      _sourceCardId = card.id;
                      _sourceName = card.name;
                    });
                    Navigator.of(context).pop();
                  },
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottom),
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
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: widget.tx.isIncome
                    ? const Color(0xFF4CAF7A).withValues(alpha: 0.15)
                    : const Color(0xFFE45D5D).withValues(alpha: 0.15),
                child: Icon(
                  widget.tx.isIncome
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: widget.tx.isIncome
                      ? const Color(0xFF4CAF7A)
                      : const Color(0xFFE45D5D),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                widget.tx.isIncome ? 'Edit Income' : 'Edit Expense',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                onPressed: _isDeleting ? null : _confirmDelete,
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFE45D5D)),
                tooltip: 'Delete',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Title
          const Text('Title',
              style: TextStyle(fontSize: 13, color: mutedText)),
          const SizedBox(height: 6),
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF6F3FB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              hintText: 'e.g. Grocery',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          // Amount
          const Text('Amount',
              style: TextStyle(fontSize: 13, color: mutedText)),
          const SizedBox(height: 6),
          TextField(
            controller: _amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF6F3FB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixText: 'Php ',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          // Category (expense only)
          if (!widget.tx.isIncome) ...[
            const Text('Category',
                style: TextStyle(fontSize: 13, color: mutedText)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF6F3FB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              ),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 14),
          ],

          // Source / paid-with
          Text(
            widget.tx.isIncome ? 'Received into' : 'Paid with',
            style: const TextStyle(fontSize: 13, color: mutedText),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _cardsLoading ? null : _pickSource,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F3FB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _sourceCardId == null
                        ? Icons.payments_rounded
                        : Icons.account_balance_rounded,
                    color: brandColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _sourceCardId == null ? 'Cash' : _sourceName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, color: mutedText),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: brandColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Save Changes',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : const Color(0xFFF6F3FB),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: color, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withValues(alpha: 0.2),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  if (sublabel.isNotEmpty)
                    Text(sublabel,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF7E7A8E))),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}

class _CardOpt {
  const _CardOpt(
      {required this.id,
      required this.name,
      required this.bankName,
      required this.type});
  final int id;
  final String name;
  final String bankName;
  final String type;
}

// ─── Shared TxItem data model ────────────────────────────────────────────────

class TxItem {
  TxItem({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.isIncome,
    this.sourceCardId,
    this.sourceName,
  });

  final int id;
  final String title;
  final String category;
  final double amount;
  final bool isIncome;
  final int? sourceCardId;
  final String? sourceName;

  String get subtitle => isIncome ? (sourceName ?? 'Cash') : category;

  String get formattedAmount {
    final prefix = isIncome ? '+' : '-';
    return '$prefix Php ${amount.toStringAsFixed(2)}';
  }

  IconData get icon {
    if (isIncome) return Icons.arrow_downward_rounded;
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
      case 'personal':
        return Icons.person_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  Color get iconColor {
    if (isIncome) return const Color(0xFF4CAF7A);
    switch (category.toLowerCase()) {
      case 'food':
        return const Color(0xFFF8B26A);
      case 'transportation':
      case 'transport':
        return const Color(0xFF7FB3FF);
      case 'shopping':
        return const Color(0xFFB38AF7);
      case 'bills':
        return const Color(0xFFE45D5D);
      case 'personal':
        return const Color(0xFF7AD7AA);
      default:
        return const Color(0xFF7E7A8E);
    }
  }

  factory TxItem.fromJson(Map<String, dynamic> json) {
    return TxItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'Transaction',
      category: json['category'] as String? ?? 'General',
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      isIncome: (json['type'] as String?)?.toLowerCase() == 'income',
      sourceCardId: (json['source_card_id'] as num?)?.toInt(),
      sourceName: json['source_name'] as String?,
    );
  }
}
