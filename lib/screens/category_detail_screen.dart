import 'package:flutter/material.dart';

class CategoryDetailScreen extends StatelessWidget {
  const CategoryDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const surfaceColor = Color(0xFFF6F3FB);
    const mutedText = Color(0xFF7E7A8E);

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
          'Category detail',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            const CircleAvatar(
              radius: 26,
              backgroundColor: Color(0xFFFFEEF0),
              child: Icon(Icons.favorite_rounded, color: Color(0xFFFF7E86)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Personal',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 4),
            const Text(
              '3 transactions',
              style: TextStyle(color: mutedText, fontSize: 12),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  const Text(
                    'Spending Breakdown',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Adjust'),
                  ),
                ],
              ),
            ),
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
                  Row(
                    children: const [
                      Text(
                        'Php 250.00 over',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Spacer(),
                      Icon(Icons.error_outline, color: Color(0xFFE45D5D), size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Limit exceeded',
                        style: TextStyle(color: Color(0xFFE45D5D), fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: 1.2,
                      backgroundColor: const Color(0xFFF3F0FA),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Color(0xFFE45D5D)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Php 1,250 of Php 1,000',
                    style: TextStyle(color: mutedText, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: const Text(
                'Transactions',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            const _TransactionRow(
              title: 'Weeb Stuff',
              amount: '- Php 50.00',
              icon: Icons.person,
            ),
            const _TransactionRow(
              title: 'Shopee Transaction',
              amount: '- Php 500.00',
              icon: Icons.shopping_cart_rounded,
            ),
            const _TransactionRow(
              title: 'Kibushop',
              amount: '- Php 700.00',
              icon: Icons.shopping_bag_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.title,
    required this.amount,
    required this.icon,
  });

  final String title;
  final String amount;
  final IconData icon;

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
            backgroundColor: const Color(0xFFEFE9FB),
            child: Icon(icon, color: const Color(0xFF8C6AE6)),
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
