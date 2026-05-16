import 'package:flutter/material.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.showLogin = false});

  final bool showLogin;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.showLogin ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFFB38AF7);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            const Text(
              'Welcome to TipidTrack',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Start saving smarter today',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 22),
              padding: const EdgeInsets.all(4),
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
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: brandColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black.withValues(alpha: 0.6),
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Sign Up'),
                  Tab(text: 'Log In'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _AuthForm(
                    title: 'Create your account',
                    fields: [
                      _AuthField(label: 'Full Name', icon: Icons.person_outline),
                      _AuthField(label: 'Email Address', icon: Icons.email_outlined),
                      _AuthField(
                        label: 'Password',
                        isPassword: true,
                        icon: Icons.lock_outline,
                      ),
                    ],
                    primaryActionLabel: 'Create Account',
                  ),
                  _AuthForm(
                    title: 'Welcome back',
                    fields: [
                      _AuthField(label: 'Email Address', icon: Icons.email_outlined),
                      _AuthField(
                        label: 'Password',
                        isPassword: true,
                        icon: Icons.lock_outline,
                      ),
                    ],
                    primaryActionLabel: 'Log In',
                    showForgotPassword: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthForm extends StatelessWidget {
  const _AuthForm({
    required this.title,
    required this.fields,
    required this.primaryActionLabel,
    this.showForgotPassword = false,
  });

  final String title;
  final List<_AuthField> fields;
  final String primaryActionLabel;
  final bool showForgotPassword;

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFFB38AF7);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          for (final field in fields) ...[
            TextField(
              obscureText: field.isPassword,
              decoration: InputDecoration(
                labelText: field.label,
                prefixIcon:
                    field.icon == null ? null : Icon(field.icon, size: 20),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (showForgotPassword)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                child: Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 6),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: brandColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(primaryActionLabel),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _AuthField {
  const _AuthField({
    required this.label,
    this.isPassword = false,
    this.icon,
  });

  final String label;
  final bool isPassword;
  final IconData? icon;
}
