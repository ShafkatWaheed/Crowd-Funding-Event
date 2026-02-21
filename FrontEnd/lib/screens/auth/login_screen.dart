import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../config/design_tokens.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    await context.read<AuthProvider>().signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
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
                    'Welcome Back',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayMedium,
                  ).animate(delay: 100.ms).fadeIn(duration: 400.ms).slideY(
                      begin: 0.15, end: 0, duration: 400.ms, curve: AppCurve.enter),

                  AppSpacing.vSm,

                  Text(
                    'Sign in to continue to CrowdFund Events',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textSecondaryOf(context),
                        ),
                  ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

                  const SizedBox(height: 36),

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
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'you@example.com',
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
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),
                          AppSpacing.vXxl,

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

                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: auth.isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentColor,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    AppTheme.accentColor.withValues(alpha: 0.5),
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
                                  : const Text('Sign In',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      .animate(delay: 300.ms)
                      .fadeIn(duration: 500.ms)
                      .slideY(begin: 0.1, end: 0, duration: 500.ms, curve: AppCurve.enter),

                  AppSpacing.vXxl,

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(
                            color: AppTheme.textSecondaryOf(context)),
                      ),
                      TextButton(
                        onPressed: () {
                          final r = GoRouterState.of(context)
                              .uri
                              .queryParameters['redirect'];
                          context.go(r != null && r.isNotEmpty
                              ? '/register?redirect=${Uri.encodeComponent(r)}'
                              : '/register');
                        },
                        child: const Text('Sign Up'),
                      ),
                    ],
                  ).animate(delay: 500.ms).fadeIn(duration: 400.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
