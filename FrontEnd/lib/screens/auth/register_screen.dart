import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../utils/date_time_utils.dart';
import '../../config/design_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/press_feedback.dart';
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
  final _birthdayController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedRole = 'customer';
  bool _agreedToTerms = false;
  DateTime? _selectedBirthday;

  @override
  void initState() {
    super.initState();
    // Clear any error left over from the login screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthProvider>().clearError();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  int? get _calculatedAge {
    if (_selectedBirthday == null) return null;
    final now = DateTime.now();
    int age = now.year - _selectedBirthday!.year;
    if (now.month < _selectedBirthday!.month ||
        (now.month == _selectedBirthday!.month && now.day < _selectedBirthday!.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime(now.year - 20),
      firstDate: DateTime(1920),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedBirthday = picked;
        _birthdayController.text = AppDateFormat.dateOnly(picked);
      });
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) return;
    if (_selectedBirthday == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your birthday')),
      );
      return;
    }
    if (_calculatedAge != null && _calculatedAge! < 13) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be at least 13 years old to register')),
      );
      return;
    }

    await context.read<AuthProvider>().signUp(
          email: _emailController.text.trim().toLowerCase(),
          password: _passwordController.text,
          role: _selectedRole,
          displayName: _nameController.text.trim(),
          phone: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
          termsAcceptedAt: DateTime.now().toUtc().toIso8601String(),
          birthday: AppDateFormat.apiDate(_selectedBirthday!),
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0A0A1A), const Color(0xFF121228)]
                : [const Color(0xFFF0F4FF), const Color(0xFFF8FAFF)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.paddingXxl,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: AppRadius.xl,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentColor.withValues(alpha: 0.25),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.celebration_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
                  )
                      .animate()
                      .scale(
                        begin: const Offset(0.7, 0.7),
                        end: const Offset(1.0, 1.0),
                        duration: 500.ms,
                        curve: AppCurve.overshoot,
                      )
                      .fadeIn(duration: 400.ms),

                  AppSpacing.vXxl,

                  Text(
                    'Create Account',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayMedium,
                  ).animate(delay: 100.ms).fadeIn(duration: 400.ms).slideY(
                      begin: 0.15, end: 0, duration: 400.ms, curve: AppCurve.enter),

                  AppSpacing.vSm,

                  Text(
                    'Join CrowdFund Events today',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textSecondaryOf(context),
                        ),
                  ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

                  const SizedBox(height: 28),

                  // Role selection
                  Text(
                    'I want to...',
                    style: Theme.of(context).textTheme.titleSmall,
                  ).animate(delay: 250.ms).fadeIn(duration: 300.ms),
                  AppSpacing.vMd,
                  Row(
                    children: [
                      Expanded(
                        child: _RoleCard(
                          icon: Icons.person_rounded,
                          label: 'Attend Events',
                          subtitle: 'Customer',
                          selected: _selectedRole == 'customer',
                          onTap: () =>
                              setState(() => _selectedRole = 'customer'),
                        ),
                      ),
                      AppSpacing.hSm,
                      Expanded(
                        child: _RoleCard(
                          icon: Icons.event_rounded,
                          label: 'Organize Events',
                          subtitle: 'Organizer',
                          selected: _selectedRole == 'organizer',
                          onTap: () =>
                              setState(() => _selectedRole = 'organizer'),
                        ),
                      ),
                      AppSpacing.hSm,
                      Expanded(
                        child: _RoleCard(
                          icon: Icons.handshake_rounded,
                          label: 'Sponsor Events',
                          subtitle: 'Sponsor',
                          selected: _selectedRole == 'sponsor',
                          onTap: () =>
                              setState(() => _selectedRole = 'sponsor'),
                        ),
                      ),
                    ],
                  ).animate(delay: 300.ms).fadeIn(duration: 400.ms).slideY(
                      begin: 0.1, end: 0, duration: 400.ms, curve: AppCurve.enter),

                  AppSpacing.vXxl,

                  // Form card
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    decoration: BoxDecoration(
                      color: AppTheme.cardOf(context),
                      borderRadius: AppRadius.xl,
                      boxShadow: AppShadow.elevated(isDark),
                    ),
                    child: Form(
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
                          AppSpacing.vLg,
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
                              final emailRegex = RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
                              if (!emailRegex.hasMatch(value.trim())) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          AppSpacing.vLg,
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone (optional)',
                              prefixIcon: Icon(Icons.phone_outlined),
                              hintText: '+1 234 567 8900',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) return null;
                              final digits = value.replaceAll(RegExp(r'[^\d]'), '');
                              if (digits.length < 7 || digits.length > 15) {
                                return 'Enter a valid phone number (7–15 digits)';
                              }
                              return null;
                            },
                          ),
                          AppSpacing.vLg,
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outlined),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
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
                          AppSpacing.vLg,
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: const Icon(Icons.lock_outlined),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
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
                          AppSpacing.vLg,

                          // Birthday (required for all roles for age verification)
                          GestureDetector(
                            onTap: _pickBirthday,
                            child: AbsorbPointer(
                              child: TextFormField(
                                decoration: InputDecoration(
                                  labelText: 'Birthday *',
                                  prefixIcon: const Icon(Icons.cake_outlined),
                                  hintText: 'Select your birthday',
                                  suffixIcon: _calculatedAge != null
                                      ? Padding(
                                          padding: const EdgeInsets.only(right: 12),
                                          child: Center(
                                            widthFactor: 1,
                                            child: Text(
                                              '${_calculatedAge}y',
                                              style: TextStyle(
                                                color: AppTheme.accentColor,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        )
                                      : const Icon(Icons.calendar_today_outlined, size: 20),
                                ),
                                controller: _birthdayController,
                                validator: (_) {
                                  if (_selectedBirthday == null) return 'Birthday is required';
                                  if (_calculatedAge != null && _calculatedAge! < 13) {
                                    return 'You must be at least 13 years old';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ),

                          AppSpacing.vLg,

                          // Terms
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
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
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
                                        const TextSpan(
                                            text: 'I have read and agree to the '),
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

                          AppSpacing.vXl,

                          if (auth.errorMessage != null) ...[
                            Container(
                              padding: AppSpacing.paddingMd,
                              decoration: BoxDecoration(
                                color: AppTheme.errorSurfaceOf(context),
                                borderRadius: AppRadius.md,
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline_rounded,
                                      size: AppIconSize.md,
                                      color: AppTheme.errorColor),
                                  AppSpacing.hSm,
                                  Expanded(
                                    child: Text(
                                      auth.errorMessage!,
                                      style: const TextStyle(
                                        color: AppTheme.errorColor,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AppSpacing.vLg,
                          ],

                          PressFeedback(
                            child: SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: auth.isLoading || !_agreedToTerms || _selectedBirthday == null
                                    ? null
                                    : _handleRegister,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentColor,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      AppTheme.accentColor.withValues(alpha: 0.3),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: AppRadius.md),
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
                                    : const Text('Create Account',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      .animate(delay: 350.ms)
                      .fadeIn(duration: 500.ms)
                      .slideY(begin: 0.08, end: 0, duration: 500.ms, curve: AppCurve.enter),

                  AppSpacing.vXxl,

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: TextStyle(
                            color: AppTheme.textSecondaryOf(context)),
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
                  ).animate(delay: 550.ms).fadeIn(duration: 400.ms),
                ],
              ),
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
    final isDark = AppTheme.isDark(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDuration.fast,
          curve: AppCurve.standard,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: isDark ? 0.2 : 0.1)
                : AppTheme.cardOf(context),
            borderRadius: AppRadius.lg,
            border: Border.all(
              color: selected ? accent : AppTheme.dividerOf(context),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected ? AppShadow.soft(isDark) : [],
          ),
          child: Column(
            children: [
              AnimatedContainer(
                duration: AppDuration.fast,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.15)
                      : AppTheme.surfaceOf(context),
                  borderRadius: AppRadius.md,
                ),
                child: Icon(icon,
                    size: AppIconSize.lg,
                    color: selected
                        ? accent
                        : AppTheme.textSecondaryOf(context)),
              ),
              AppSpacing.vSm,
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: selected ? accent : AppTheme.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 2),
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
