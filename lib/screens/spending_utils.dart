import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/session.dart';

Color categoryColor(String cat) {
  switch (cat.toLowerCase()) {
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
    case 'general':
      return const Color(0xFF8C6AE6);
    default:
      return const Color(0xFF9E9E9E);
  }
}

IconData categoryIcon(String cat) {
  switch (cat.toLowerCase()) {
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

class BudgetSheet extends StatefulWidget {
  const BudgetSheet({
    super.key,
    required this.apiBaseUrl,
    required this.current,
    required this.onSaved,
  });

  final String apiBaseUrl;
  final double current;
  final Future<void> Function() onSaved;

  @override
  State<BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<BudgetSheet> {
  static const brandColor = Color(0xFF8C6AE6);

  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.current > 0 ? widget.current.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_ctrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    setState(() => _saving = true);
    final token = AppSession.instance.token;
    try {
      final res = await http.post(
        Uri.parse('${widget.apiBaseUrl}/api/budget'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'monthly_amount': amount}),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        Navigator.of(context).pop();
        await widget.onSaved();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to save')));
        setState(() => _saving = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
    }
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
          const Text(
            'Set Monthly Budget',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'This is the total amount you plan to spend this month.',
            style: TextStyle(color: Color(0xFF7E7A8E), fontSize: 13),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF6F3FB),
              prefixText: 'Php ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              hintText: '0.00',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: brandColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Save Budget',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
