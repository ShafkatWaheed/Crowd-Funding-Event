import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

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

                      if (user.isSponsor || user.isOrganizer || user.isAdmin)
                        Card(
                          child: Column(
                            children: [
                              if (user.isSponsor) ...[
                                ListTile(
                                  leading: Icon(Icons.dashboard_rounded, color: AppTheme.textSecondaryOf(context)),
                                  title: const Text('Sponsor Dashboard'),
                                  trailing: Icon(Icons.chevron_right, color: AppTheme.textSecondaryOf(context)),
                                  onTap: () => context.push('/sponsor/dashboard'),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: Icon(Icons.confirmation_number_outlined, color: AppTheme.textSecondaryOf(context)),
                                  title: const Text('Sponsor Tickets'),
                                  trailing: Icon(Icons.chevron_right, color: AppTheme.textSecondaryOf(context)),
                                  onTap: () => context.push('/sponsor/tickets'),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: Icon(Icons.storefront_rounded, color: AppTheme.textSecondaryOf(context)),
                                  title: const Text('Edit Sponsor Profile'),
                                  trailing: Icon(Icons.chevron_right, color: AppTheme.textSecondaryOf(context)),
                                  onTap: () => context.push('/sponsor/onboarding'),
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
