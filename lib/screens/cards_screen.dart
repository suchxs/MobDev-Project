import 'dart:convert';

import 'package:flutter/material.dart';
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

  bool _isLoading = true;
  List<_CardItem> _cards = [];

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
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/cards'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = (data['cards'] as List<dynamic>? ?? [])
            .map((item) => _CardItem.fromJson(item))
            .toList();
        if (!mounted) return;
        setState(() {
          _cards = items;
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

    void openExpenses() {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ExpensesScreen()),
      );
    }

    void openProfile() {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    }

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        title: const Text(
          'Cards',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your cards',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_cards.isEmpty)
              Text(
                'No cards yet. Add one in the backend.',
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.6),
                ),
              )
            else
              for (final card in _cards)
                _CardTile(
                  title: card.name,
                  subtitle: '${card.typeLabel} •••• ${card.last4}',
                  balance: 'Php ${card.balance.toStringAsFixed(2)}',
                  color: card.color,
                ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            openDashboard();
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

class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.title,
    required this.subtitle,
    required this.balance,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String balance;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            balance,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardItem {
  _CardItem({
    required this.name,
    required this.type,
    required this.last4,
    required this.balance,
  });

  final String name;
  final String type;
  final String last4;
  final double balance;

  String get typeLabel {
    switch (type.toLowerCase()) {
      case 'debit':
        return 'Debit';
      case 'credit':
        return 'Credit';
      case 'wallet':
        return 'Wallet';
      default:
        return 'Card';
    }
  }

  Color get color {
    switch (type.toLowerCase()) {
      case 'wallet':
        return const Color(0xFF8C6AE6);
      case 'debit':
        return const Color(0xFF7FB3FF);
      case 'credit':
        return const Color(0xFFF8B26A);
      default:
        return const Color(0xFF7E7A8E);
    }
  }

  factory _CardItem.fromJson(Map<String, dynamic> json) {
    return _CardItem(
      name: json['card_name'] as String? ?? 'Card',
      type: json['card_type'] as String? ?? 'card',
      last4: json['last4'] as String? ?? '0000',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
