import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_screen.dart';
import 'dashboard_screen.dart';
import '../services/session.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String _apiBaseUrl = 'https://tipidtrack.dcism.org';
  static const String _guideFlagKey = 'hasSeenGuide';
  static const brandColor = Color(0xFF8C6AE6);
  static const surfaceColor = Color(0xFFF6F3FB);

  bool _isDeleting = false;
  bool _isResetting = false;

  void _showMessage(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            success ? const Color(0xFF4CAF81) : const Color(0xFFE45D5D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF3F0FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brandColor, width: 1.5),
        ),
      );

  void _showEditNameSheet() {
    final controller =
        TextEditingController(text: AppSession.instance.fullName ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: _BottomSheet(
            title: 'Edit Name',
            icon: Icons.person_rounded,
            child: Column(
              children: [
                TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: _inputDeco('Full Name')),
                const SizedBox(height: 16),
                _SheetButton(
                  label: 'Save',
                  isBusy: isSaving,
                  onPressed: () async {
                    final name = controller.text.trim();
                    if (name.isEmpty) return;
                    setSS(() => isSaving = true);
                    try {
                      final token = AppSession.instance.token ?? '';
                      final res = await http.post(
                        Uri.parse('$_apiBaseUrl/api/profile/name'),
                        headers: {
                          'Authorization': 'Bearer $token',
                          'Content-Type': 'application/json',
                        },
                        body: jsonEncode({'fullName': name}),
                      );
                      if (res.statusCode == 200) {
                        AppSession.instance.fullName = name;
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (mounted) setState(() {});
                        _showMessage('Name updated.', success: true);
                      } else {
                        setSS(() => isSaving = false);
                        _showMessage('Update failed. Try again.');
                      }
                    } catch (_) {
                      setSS(() => isSaving = false);
                      _showMessage('Unable to connect.');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditPasswordSheet() {
    final pwController = TextEditingController();
    final confirmController = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: _BottomSheet(
            title: 'Change Password',
            icon: Icons.lock_rounded,
            child: Column(
              children: [
                TextField(
                    controller: pwController,
                    autofocus: true,
                    obscureText: true,
                    decoration: _inputDeco('New Password')),
                const SizedBox(height: 12),
                TextField(
                    controller: confirmController,
                    obscureText: true,
                    decoration: _inputDeco('Confirm Password')),
                const SizedBox(height: 16),
                _SheetButton(
                  label: 'Update Password',
                  isBusy: isSaving,
                  onPressed: () async {
                    final pw = pwController.text;
                    if (pw.length < 6) {
                      _showMessage('Password must be at least 6 characters.');
                      return;
                    }
                    if (pw != confirmController.text) {
                      _showMessage('Passwords do not match.');
                      return;
                    }
                    setSS(() => isSaving = true);
                    try {
                      final token = AppSession.instance.token ?? '';
                      final res = await http.post(
                        Uri.parse('$_apiBaseUrl/api/profile/password'),
                        headers: {
                          'Authorization': 'Bearer $token',
                          'Content-Type': 'application/json',
                        },
                        body: jsonEncode({'newPassword': pw}),
                      );
                      if (res.statusCode == 200) {
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        _showMessage('Password updated.', success: true);
                      } else {
                        setSS(() => isSaving = false);
                        _showMessage('Update failed. Try again.');
                      }
                    } catch (_) {
                      setSS(() => isSaving = false);
                      _showMessage('Unable to connect.');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resetGuide() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_guideFlagKey, false);
    } catch (_) {}
    AppSession.instance.showGuideAfterLogin = true;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  Future<void> _logout() async {
    AppSession.instance.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen(showLogin: true)),
      (_) => false,
    );
  }

  Future<void> _resetData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset financial data?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'This will delete all your transactions and budget data.\n\n'
          'Your account (email & password) will remain intact.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFE45D5D)),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isResetting = true);
    try {
      final token = AppSession.instance.token ?? '';
      final res = await http.delete(
        Uri.parse('$_apiBaseUrl/api/data/reset'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        _showMessage('Financial data reset successfully.', success: true);
      } else {
        _showMessage('Reset failed. Try again.');
      }
    } catch (_) {
      _showMessage('Unable to connect.');
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete account?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'This will permanently delete your account and all data. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFE45D5D)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isDeleting = true);
    try {
      final token = AppSession.instance.token ?? '';
      final res = await http.delete(
        Uri.parse('$_apiBaseUrl/api/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        AppSession.instance.clear();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen(showLogin: true)),
          (_) => false,
        );
      } else {
        _showMessage('Delete failed. Try again.');
      }
    } catch (_) {
      _showMessage('Unable to connect.');
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = AppSession.instance.fullName ?? 'User';
    final email = AppSession.instance.email ?? '';
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: surfaceColor,
      body: CustomScrollView(
        slivers: [
          // Purple gradient header
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8C6AE6), Color(0xFFAB8FF0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white),
                          ),
                          const Spacer(),
                          const Text(
                            'Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 2.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Settings list
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _SectionLabel('Account'),
                const SizedBox(height: 8),
                _SettingsCard(children: [
                  _SettingsTile(
                    icon: Icons.person_rounded,
                    label: 'Edit Name',
                    onTap: _showEditNameSheet,
                  ),
                  const _TileDivider(),
                  _SettingsTile(
                    icon: Icons.lock_rounded,
                    label: 'Change Password',
                    onTap: _showEditPasswordSheet,
                  ),
                ]),
                const SizedBox(height: 20),
                const _SectionLabel('General'),
                const SizedBox(height: 8),
                _SettingsCard(children: [
                  _SettingsTile(
                    icon: Icons.menu_book_rounded,
                    label: 'Show Quick Guide',
                    onTap: _resetGuide,
                  ),
                ]),
                const SizedBox(height: 20),
                const _SectionLabel('Session'),
                const SizedBox(height: 8),
                _SettingsCard(children: [
                  _SettingsTile(
                    icon: Icons.logout_rounded,
                    label: 'Log Out',
                    color: brandColor,
                    onTap: _logout,
                  ),
                ]),
                const SizedBox(height: 20),
                const _SectionLabel('Danger Zone'),
                const SizedBox(height: 8),
                _SettingsCard(children: [
                  _SettingsTile(
                    icon: Icons.restart_alt_rounded,
                    label: _isResetting ? 'Resetting...' : 'Reset Data',
                    sublabel: 'Clear all transactions & budget',
                    color: const Color(0xFFE45D5D),
                    onTap: _isResetting ? null : _resetData,
                  ),
                  const Divider(height: 1, indent: 52),
                  _SettingsTile(
                    icon: Icons.delete_forever_rounded,
                    label: _isDeleting ? 'Deleting...' : 'Delete Account',
                    sublabel: 'Permanently remove your account',
                    color: const Color(0xFFE45D5D),
                    onTap: _isDeleting ? null : _deleteAccount,
                  ),
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF9E9AB0),
        letterSpacing: 0.8,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.sublabel,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? sublabel;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tileColor = color ?? const Color(0xFF2D2D3A);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tileColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: tileColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      color: tileColor,
                    ),
                  ),
                  if (sublabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sublabel!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7E7A8E),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFFB0A9C2), size: 20),
          ],
        ),
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 66,
      endIndent: 0,
      color: Color(0xFFF0EDF8),
    );
  }
}

class _BottomSheet extends StatelessWidget {
  const _BottomSheet({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0DCF0),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFE9FB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF8C6AE6), size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.isBusy,
    required this.onPressed,
  });

  final String label;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isBusy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8C6AE6),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        child: isBusy
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}
