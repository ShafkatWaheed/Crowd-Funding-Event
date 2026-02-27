import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../config/design_tokens.dart';
import '../../../config/theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../widgets/animated_list_item.dart';
import '../../legal/terms_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isDark = AppTheme.isDark(context);

    if (user == null) return _buildSigningOut();

    Widget sectionCard(Widget child) => Container(
          decoration: BoxDecoration(
            color: AppTheme.cardOf(context),
            borderRadius: AppRadius.lg,
            boxShadow: AppShadow.card(isDark),
          ),
          child: child,
        );

    int animIdx = 0;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AppRadius.xxlValue + 8),
                bottomRight: Radius.circular(AppRadius.xxlValue + 8),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl, 60, AppSpacing.xxl, AppSpacing.xxxl,
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.cardOf(context),
                    borderRadius: AppRadius.xl,
                  ),
                  child: Center(
                    child: Text(
                      user.initial,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                  ),
                ),
                AppSpacing.vLg,
                Text(
                  user.displayLabel,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                if (user.phone != null && user.phone!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.phone_outlined,
                          size: 15, color: Colors.white70),
                      const SizedBox(width: 6),
                      Text(user.phone!,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ],
                AppSpacing.vMd,
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: AppRadius.pill,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    user.role.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedListItem(
                  index: animIdx++,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Account',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondaryOf(context),
                              letterSpacing: 0.5)),
                      AppSpacing.vMd,
                      sectionCard(
                        _profileTile(
                          icon: Icons.person_outline_rounded,
                          label: 'Edit Profile',
                          onTap: () => context.push('/profile'),
                        ),
                      ),
                    ],
                  ),
                ),

                if (user.isOrganizer) ...[
                  AppSpacing.vXxl,
                  AnimatedListItem(
                    index: animIdx++,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Public Profile',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondaryOf(context),
                                letterSpacing: 0.5)),
                        AppSpacing.vMd,
                        sectionCard(
                          _profileTile(
                            icon: Icons.visibility_rounded,
                            label: 'View Organizer Profile',
                            onTap: () => context.push('/users/${user.id}/profile'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (user.isSponsor) ...[
                  AppSpacing.vXxl,
                  AnimatedListItem(
                    index: animIdx++,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Public Profile',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondaryOf(context),
                                letterSpacing: 0.5)),
                        AppSpacing.vMd,
                        sectionCard(
                          _profileTile(
                            icon: Icons.visibility_rounded,
                            label: 'View Sponsor Profile',
                            onTap: () => context.push('/users/${user.id}/sponsor-profile'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (user.isAdmin) ...[
                  AppSpacing.vXxl,
                  AnimatedListItem(
                    index: animIdx++,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Administration',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondaryOf(context),
                                letterSpacing: 0.5)),
                        AppSpacing.vMd,
                        sectionCard(
                          _profileTile(
                            icon: Icons.admin_panel_settings_rounded,
                            label: 'Admin Dashboard',
                            onTap: () => context.push('/admin'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (user.isCustomer) ...[
                  AppSpacing.vXxl,
                  AnimatedListItem(
                    index: animIdx++,
                    child: sectionCard(
                      _profileTile(
                        icon: Icons.storefront_rounded,
                        label: 'Become a Sponsor',
                        onTap: () => context.push('/sponsor/onboarding'),
                      ),
                    ),
                  ),
                ],

                AppSpacing.vXxl,
                AnimatedListItem(
                  index: animIdx++,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Preferences',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondaryOf(context),
                              letterSpacing: 0.5)),
                      AppSpacing.vMd,
                      sectionCard(
                        Column(
                          children: [
                            Builder(builder: (ctx) {
                              final themeProv = ctx.watch<ThemeProvider>();
                              return InkWell(
                                onTap: () => themeProv.toggle(),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(AppRadius.lgValue),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.lg, vertical: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: AppTheme.surfaceOf(ctx),
                                          borderRadius: AppRadius.sm,
                                        ),
                                        child: Icon(
                                          themeProv.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                          size: AppIconSize.md,
                                          color: AppTheme.textPrimaryOf(ctx),
                                        ),
                                      ),
                                      AppSpacing.hLg,
                                      Expanded(
                                        child: Text('Dark Mode',
                                            style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                                color: AppTheme.textPrimaryOf(ctx))),
                                      ),
                                      Switch.adaptive(
                                        value: themeProv.isDark,
                                        activeColor: AppTheme.accentColor,
                                        onChanged: (_) => themeProv.toggle(),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            Divider(height: 1, indent: 56, color: AppTheme.dividerOf(context)),
                            _profileTile(
                              icon: Icons.description_outlined,
                              label: 'Terms & Conditions',
                              onTap: () {
                                final role = user.isOrganizer ? 'organizer' : 'customer';
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TermsScreen(role: role),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                AppSpacing.vXxxl,

                AnimatedListItem(
                  index: animIdx++,
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await auth.signOut();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                      icon:
                          const Icon(Icons.logout_rounded, color: AppTheme.errorColor),
                      label: const Text('Sign Out',
                          style: TextStyle(
                              color: AppTheme.errorColor,
                              fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: AppTheme.errorColor.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.md),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSigningOut() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.logout_rounded,
              size: 36,
              color: AppTheme.accentColor,
            ),
          )
              .animate()
              .scale(
                begin: const Offset(0.0, 0.0),
                end: const Offset(1.0, 1.0),
                duration: 500.ms,
                curve: Curves.elasticOut,
              )
              .fadeIn(duration: 300.ms),
          const SizedBox(height: 24),
          Text(
            'Signing out\u2026',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryOf(context),
            ),
          )
              .animate(delay: 200.ms)
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.3, end: 0, duration: 400.ms, curve: AppCurve.enter),
          const SizedBox(height: 12),
          Text(
            'See you next time!',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondaryOf(context),
            ),
          )
              .animate(delay: 400.ms)
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.3, end: 0, duration: 400.ms, curve: AppCurve.enter),
          const SizedBox(height: 32),
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppTheme.accentColor,
            ),
          )
              .animate(delay: 500.ms)
              .fadeIn(duration: 300.ms),
        ],
      ),
    );
  }

  Widget _profileTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.md,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: 14,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.surfaceOf(context),
                borderRadius: AppRadius.sm,
              ),
              child: Icon(icon, size: AppIconSize.md, color: AppTheme.textPrimaryOf(context)),
            ),
            AppSpacing.hLg,
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimaryOf(context))),
            ),
            Icon(Icons.chevron_right_rounded,
                size: AppIconSize.md, color: AppTheme.textSecondaryOf(context)),
          ],
        ),
      ),
    );
  }
}
