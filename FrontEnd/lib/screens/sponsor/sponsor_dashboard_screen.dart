import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/sponsor.dart';
import '../../repositories/base_repository.dart';
import '../../providers/sponsor_provider.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/shimmer_loaders.dart';

class SponsorDashboardScreen extends StatefulWidget {
  const SponsorDashboardScreen({super.key});

  @override
  State<SponsorDashboardScreen> createState() =>
      _SponsorDashboardScreenState();
}

class _SponsorDashboardScreenState extends State<SponsorDashboardScreen> {
  SponsorProfile? _profile;
  List<SponsorTicketModel> _tickets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final api = context.read<SponsorProvider>();
      final profile = await api.getSponsorProfile();
      final tickets = await api.getMySponsorTickets();
      if (mounted) {
        setState(() {
          _profile = profile;
          _tickets = tickets;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, ApiError.extractMessage(e));
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sponsor Dashboard')),
      body: _loading
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List.generate(4, (_) => const ShimmerListTile()),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile card
                      if (_profile != null) _buildProfileCard(),
                      const SizedBox(height: 24),

                      // Quick actions
                      Text('Quick Actions',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: Icon(Icons.edit_outlined,
                                  color: AppTheme.textSecondaryOf(context)),
                              title: const Text('Edit Sponsor Profile'),
                              trailing: Icon(Icons.chevron_right,
                                  color: AppTheme.textSecondaryOf(context)),
                              onTap: () => context.push('/sponsor/onboarding'),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: Icon(Icons.confirmation_number_outlined,
                                  color: AppTheme.textSecondaryOf(context)),
                              title: const Text('My Sponsor Tickets'),
                              trailing: Icon(Icons.chevron_right,
                                  color: AppTheme.textSecondaryOf(context)),
                              onTap: () => context.push('/sponsor/tickets'),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Tickets summary
                      Text(
                          'Sponsor Tickets (${_tickets.length})',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (_tickets.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'No sponsor tickets yet. Browse events and place bids to get started!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color:
                                        AppTheme.textSecondaryOf(context)),
                              ),
                            ),
                          ),
                        )
                      else
                        ...List.generate(_tickets.length, (i) {
                          final t = _tickets[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppTheme.accentColor.withValues(alpha: 0.1),
                                child: Text(
                                  '${t.categoryCount}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text('Event #${t.eventId}'),
                              subtitle: Text(
                                '${t.categoryCount} categor${t.categoryCount == 1 ? "y" : "ies"} won  •  ${t.receiptNumber}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: t.scannedAt != null
                                  ? Icon(Icons.verified,
                                      color: AppTheme.successColor, size: 20)
                                  : Icon(Icons.qr_code,
                                      color:
                                          AppTheme.textSecondaryOf(context),
                                      size: 20),
                              onTap: () => context.push('/sponsor/tickets'),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildProfileCard() {
    final p = _profile!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.accentColor.withValues(alpha: 0.1),
              backgroundImage:
                  p.logoUrl != null ? NetworkImage(ApiConfig.imageUrl(p.logoUrl!)) : null,
              child: p.logoUrl == null
                  ? Text(
                      p.companyName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.companyName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                    '${p.contactName}  •  ${p.profession}',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryOf(context)),
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
