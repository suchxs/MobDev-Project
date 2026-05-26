import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dashboard_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.showLogin = false});

  final bool showLogin;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  static const String _apiBaseUrl = 'https://tipidtrack.dcism.org';

  late final TabController _tabController;
  final GlobalKey<FormState> _signupFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _loginFormKey = GlobalKey<FormState>();
  final TextEditingController _signupNameController = TextEditingController();
  final TextEditingController _signupEmailController = TextEditingController();
  final TextEditingController _signupPasswordController = TextEditingController();
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();

  bool _isSigningUp = false;
  bool _isLoggingIn = false;

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
    _signupNameController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? const Color(0xFF4CAF81) : null,
      ),
    );
  }

  bool _isValidEmail(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return false;
    final pattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return pattern.hasMatch(trimmed);
  }

  Future<void> _signup() async {
    if (!(_signupFormKey.currentState?.validate() ?? false)) {
      return;
    }

    final fullName = _signupNameController.text.trim();
    final email = _signupEmailController.text.trim();
    final password = _signupPasswordController.text;

    if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage('Please fill in all fields.');
      return;
    }

    setState(() => _isSigningUp = true);
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': fullName,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        _showMessage('Account created. Please log in.', success: true);
        _signupPasswordController.clear();
        _tabController.animateTo(1);
      } else if (response.statusCode == 409) {
        _showMessage('Email already used.');
      } else {
        _showMessage('Signup failed. Please try again.');
      }
    } catch (_) {
      _showMessage('Unable to connect. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isSigningUp = false);
      }
    }
  }

  Future<void> _login() async {
    if (!(_loginFormKey.currentState?.validate() ?? false)) {
      return;
    }

    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter email and password.');
      return;
    }

    setState(() => _isLoggingIn = true);
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        _showMessage('Login successful.', success: true);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      } else {
        _showMessage('Invalid credentials.');
      }
    } catch (_) {
      _showMessage('Unable to connect. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoggingIn = false);
      }
    }
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
                children: [
                  _AuthForm(
                    title: 'Create your account',
                    formKey: _signupFormKey,
                    fields: [
                      _AuthField(
                        label: 'Full Name',
                        icon: Icons.person_outline,
                        controller: _signupNameController,
                        textInputType: TextInputType.name,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Full name is required.';
                          }
                          return null;
                        },
                      ),
                      _AuthField(
                        label: 'Email Address',
                        icon: Icons.email_outlined,
                        controller: _signupEmailController,
                        textInputType: TextInputType.emailAddress,
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) {
                            return 'Email is required.';
                          }
                          if (!_isValidEmail(email)) {
                            return 'Enter a valid email address.';
                          }
                          return null;
                        },
                      ),
                      _AuthField(
                        label: 'Password',
                        isPassword: true,
                        icon: Icons.lock_outline,
                        controller: _signupPasswordController,
                        textInputType: TextInputType.visiblePassword,
                        validator: (value) {
                          final password = value ?? '';
                          if (password.isEmpty) {
                            return 'Password is required.';
                          }
                          if (password.length < 6) {
                            return 'Password must be at least 6 characters.';
                          }
                          return null;
                        },
                      ),
                    ],
                    primaryActionLabel: 'Create Account',
                    onSubmit: _signup,
                    isLoading: _isSigningUp,
                  ),
                  _AuthForm(
                    title: 'Welcome back',
                    formKey: _loginFormKey,
                    fields: [
                      _AuthField(
                        label: 'Email Address',
                        icon: Icons.email_outlined,
                        controller: _loginEmailController,
                        textInputType: TextInputType.emailAddress,
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) {
                            return 'Email is required.';
                          }
                          if (!_isValidEmail(email)) {
                            return 'Enter a valid email address.';
                          }
                          return null;
                        },
                      ),
                      _AuthField(
                        label: 'Password',
                        isPassword: true,
                        icon: Icons.lock_outline,
                        controller: _loginPasswordController,
                        textInputType: TextInputType.visiblePassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required.';
                          }
                          return null;
                        },
                      ),
                    ],
                    primaryActionLabel: 'Log In',
                    showForgotPassword: true,
                    onSubmit: _login,
                    isLoading: _isLoggingIn,
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
    required this.formKey,
    required this.fields,
    required this.primaryActionLabel,
    required this.onSubmit,
    required this.isLoading,
    this.showForgotPassword = false,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final List<_AuthField> fields;
  final String primaryActionLabel;
  final VoidCallback onSubmit;
  final bool isLoading;
  final bool showForgotPassword;

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFFB38AF7);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      child: Form(
        key: formKey,
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
            for (var index = 0; index < fields.length; index++) ...[
              TextFormField(
                controller: fields[index].controller,
                obscureText: fields[index].isPassword,
                keyboardType: fields[index].textInputType,
                autocorrect: !fields[index].isPassword,
                enableSuggestions: !fields[index].isPassword,
                textInputAction: index == fields.length - 1
                    ? TextInputAction.done
                    : TextInputAction.next,
                validator: fields[index].validator,
                onFieldSubmitted: (_) {
                  if (index == fields.length - 1) {
                    onSubmit();
                  }
                },
                decoration: InputDecoration(
                  labelText: fields[index].label,
                  prefixIcon: fields[index].icon == null
                      ? null
                      : Icon(fields[index].icon, size: 20),
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
              onPressed: isLoading ? null : onSubmit,
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
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(primaryActionLabel),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _AuthField {
  const _AuthField({
    required this.label,
    required this.controller,
    required this.textInputType,
    required this.validator,
    this.isPassword = false,
    this.icon,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType textInputType;
  final String? Function(String?) validator;
  final bool isPassword;
  final IconData? icon;
}
