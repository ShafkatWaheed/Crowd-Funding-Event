import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/app_toast.dart';
import '../legal/terms_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('Profile'),
      ),
      body: user == null
          ? const Center(child: Text('Not signed in'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: AppTheme.accentColor,
                        child: Text(
                          user.initial,
                          style: const TextStyle(
                              fontSize: 36, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.displayLabel,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      if (user.phone != null &&
                          user.phone!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.phone_outlined,
                                size: 16, color: AppTheme.textSecondaryOf(context)),
                            const SizedBox(width: 6),
                            Text(
                              user.phone!,
                              style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondaryOf(context)),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Chip(
                        label: Text(
                          user.role.name.toUpperCase(),
                          style: TextStyle(
                            color: AppTheme.textPrimaryOf(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor:
                            AppTheme.accentColor.withValues(alpha: 0.15),
                        side: BorderSide.none,
                      ),
                      const SizedBox(height: 32),

                      // Quick links
                      Card(
                        child: Column(
                          children: [
                            if (user.isCustomer) ...[
                              ListTile(
                                leading: Icon(Icons.volunteer_activism, color: AppTheme.textSecondaryOf(context)),
                                title: const Text('My Pledges'),
                                trailing: Icon(Icons.chevron_right, color: AppTheme.textSecondaryOf(context)),
                                onTap: () {
                                  AppToast.info(context, 'Coming soon');
                                },
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: Icon(Icons.confirmation_number, color: AppTheme.textSecondaryOf(context)),
                                title: const Text('My Tickets'),
                                trailing: Icon(Icons.chevron_right, color: AppTheme.textSecondaryOf(context)),
                                onTap: () => context.push('/my-tickets'),
                              ),
                              const Divider(height: 1),
                            ],
                            if (user.isOrganizer) ...[
                              ListTile(
                                leading: Icon(Icons.location_city, color: AppTheme.textSecondaryOf(context)),
                                title: const Text('My Venues'),
                                trailing: Icon(Icons.chevron_right, color: AppTheme.textSecondaryOf(context)),
                                onTap: () => context.push('/venues'),
                              ),
                              const Divider(height: 1),
                            ],
                            if (user.isAdmin) ...[
                              ListTile(
                                leading: Icon(Icons.admin_panel_settings, color: AppTheme.textSecondaryOf(context)),
                                title: const Text('Admin Dashboard'),
                                trailing: Icon(Icons.chevron_right, color: AppTheme.textSecondaryOf(context)),
                                onTap: () => context.push('/admin'),
                              ),
                              const Divider(height: 1),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Appearance
                      Card(
                        child: Column(
                          children: [
                            Builder(builder: (ctx) {
                              final themeProv = ctx.watch<ThemeProvider>();
                              return ListTile(
                                leading: Icon(
                                  themeProv.isDark
                                      ? Icons.dark_mode_rounded
                                      : Icons.light_mode_rounded,
                                  color: AppTheme.textSecondaryOf(ctx),
                                ),
                                title: const Text('Dark Mode'),
                                trailing: Switch.adaptive(
                                  value: themeProv.isDark,
                                  activeColor: AppTheme.accentColor,
                                  onChanged: (_) => themeProv.toggle(),
                                ),
                                onTap: () => themeProv.toggle(),
                              );
                            }),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Legal
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: Icon(Icons.description_outlined, color: AppTheme.textSecondaryOf(context)),
                              title: const Text('Terms & Conditions'),
                              trailing: Icon(Icons.chevron_right, color: AppTheme.textSecondaryOf(context)),
                              onTap: () {
                                final role = user.isOrganizer
                                    ? 'organizer'
                                    : 'customer';
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        TermsScreen(role: role),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Sign out
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await auth.signOut();
                            if (context.mounted) {
                              context.go('/login');
                            }
                          },
                          icon: const Icon(Icons.logout,
                              color: AppTheme.errorColor),
                          label: const Text('Sign Out',
                              style:
                                  TextStyle(color: AppTheme.errorColor)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
