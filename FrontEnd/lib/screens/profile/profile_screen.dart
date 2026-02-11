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
      appBar: AppBar(title: const Text('Profile')),
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
                        backgroundColor: AppTheme.primaryColor,
                        child: Text(
                          (user.displayName ?? user.email)
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(
                              fontSize: 36, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.displayName ?? 'No Name',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: TextStyle(
                            fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Chip(
                        label: Text(user.role.name.toUpperCase()),
                        backgroundColor:
                            AppTheme.primaryColor.withValues(alpha: 0.1),
                        side: BorderSide.none,
                      ),
                      const SizedBox(height: 32),

                      // Quick links
                      Card(
                        child: Column(
                          children: [
                            if (user.isCustomer) ...[
                              ListTile(
                                leading: const Icon(Icons.volunteer_activism),
                                title: const Text('My Pledges'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Coming soon')),
                                  );
                                },
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.confirmation_number),
                                title: const Text('My Tickets'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Coming soon')),
                                  );
                                },
                              ),
                              const Divider(height: 1),
                            ],
                            if (user.isOrganizer) ...[
                              ListTile(
                                leading: const Icon(Icons.location_city),
                                title: const Text('My Venues'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context.go('/venues'),
                              ),
                              const Divider(height: 1),
                            ],
                            if (user.isAdmin) ...[
                              ListTile(
                                leading:
                                    const Icon(Icons.admin_panel_settings),
                                title: const Text('Admin Dashboard'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context.go('/admin'),
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
