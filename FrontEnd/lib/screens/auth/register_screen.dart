import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../legal/terms_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedRole = 'customer';
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) return;

    await context.read<AuthProvider>().signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          role: _selectedRole,
          displayName: _nameController.text.trim(),
          phone: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
          termsAcceptedAt: DateTime.now().toUtc().toIso8601String(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.celebration_rounded,
                  size: 64,
                  color: AppTheme.primaryOf(context),
                ),
                const SizedBox(height: 16),
                Text(
                  'Create Account',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join CrowdFund Events today',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                      ),
                ),
                const SizedBox(height: 40),

                // Role selection
                Text(
                  'I want to...',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _RoleCard(
                        icon: Icons.person,
                        label: 'Attend Events',
                        subtitle: 'Customer',
                        selected: _selectedRole == 'customer',
                        onTap: () =>
                            setState(() => _selectedRole = 'customer'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _RoleCard(
                        icon: Icons.event,
                        label: 'Organize Events',
                        subtitle: 'Organizer',
                        selected: _selectedRole == 'organizer',
                        onTap: () =>
                            setState(() => _selectedRole = 'organizer'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _RoleCard(
                        icon: Icons.handshake_outlined,
                        label: 'Sponsor Events',
                        subtitle: 'Sponsor',
                        selected: _selectedRole == 'sponsor',
                        onTap: () =>
                            setState(() => _selectedRole = 'sponsor'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Display Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone (optional)',
                          prefixIcon: Icon(Icons.phone_outlined),
                          hintText: '+1 234 567 8900',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () => setState(() =>
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Terms & Conditions checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _agreedToTerms,
                        onChanged: (v) =>
                            setState(() => _agreedToTerms = v ?? false),
                        activeColor: AppTheme.accentColor,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondaryOf(context),
                              height: 1.4,
                            ),
                            children: [
                              const TextSpan(text: 'I have read and agree to the '),
                              TextSpan(
                                text: 'Terms and Conditions',
                                style: TextStyle(
                                  color: AppTheme.accentColor,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => TermsScreen(
                                          role: _selectedRole,
                                        ),
                                      ),
                                    );
                                  },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Error message
                if (auth.errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      auth.errorMessage!,
                      style: const TextStyle(color: AppTheme.errorColor),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Register button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: auth.isLoading || !_agreedToTerms
                        ? null
                        : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[800],
                      disabledForegroundColor: Colors.grey[500],
                    ),
                    child: auth.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Create Account'),
                  ),
                ),
                const SizedBox(height: 16),

                // Login link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: TextStyle(color: AppTheme.textSecondaryOf(context)),
                    ),
                    TextButton(
                      onPressed: () {
                        final r = GoRouterState.of(context)
                            .uri
                            .queryParameters['redirect'];
                        context.go(r != null && r.isNotEmpty
                            ? '/login?redirect=${Uri.encodeComponent(r)}'
                            : '/login');
                      },
                      child: const Text('Sign In'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentColor;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.12)
                : AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accent : AppTheme.dividerOf(context),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: selected ? accent : AppTheme.textSecondaryOf(context)),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: selected ? accent : AppTheme.textPrimaryOf(context),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
