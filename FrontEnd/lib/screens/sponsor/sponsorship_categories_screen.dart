import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/sponsor.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';

class SponsorshipCategoriesScreen extends StatefulWidget {
  final int eventId;
  const SponsorshipCategoriesScreen({super.key, required this.eventId});

  @override
  State<SponsorshipCategoriesScreen> createState() =>
      _SponsorshipCategoriesScreenState();
}

class _SponsorshipCategoriesScreenState
    extends State<SponsorshipCategoriesScreen> {
  List<SponsorshipCategory> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getSponsorshipCategories(widget.eventId);
      if (mounted) {
        setState(() {
          _categories =
              data.map((j) => SponsorshipCategory.fromJson(j)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, ApiService.extractError(e));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showPlaceBidDialog(SponsorshipCategory cat) async {
    final amountCtrl = TextEditingController(
      text: (cat.minBidCents / 100).toStringAsFixed(2),
    );
    final proposalCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Bid on "${cat.name}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Min bid: ${cat.minBidDisplay}  •  '
              '${cat.availableSpots} spot${cat.availableSpots == 1 ? "" : "s"} left',
              style: TextStyle(
                  fontSize: 13, color: AppTheme.textSecondaryOf(ctx)),
            ),
            if (cat.bidCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${cat.bidCount} bid${cat.bidCount == 1 ? "" : "s"} placed',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textSecondaryOf(ctx)),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Bid Amount (\$)',
                prefixText: '\$ ',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: proposalCtrl,
              decoration: const InputDecoration(
                labelText: 'Proposal (optional)',
                hintText: 'Why you want to sponsor...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Place Bid'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final amount =
        ((double.tryParse(amountCtrl.text) ?? 0) * 100).round();
    try {
      final api = context.read<ApiService>();
      await api.placeBid(widget.eventId, cat.id, {
        'amount_cents': amount,
        if (proposalCtrl.text.trim().isNotEmpty)
          'proposal_text': proposalCtrl.text.trim(),
      });
      if (mounted) AppToast.success(context, 'Bid placed!');
      _load();
    } catch (e) {
      if (mounted) AppToast.error(context, ApiService.extractError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isSponsor = user?.isSponsor ?? false;
    final isOrganizerOrAdmin = user != null && (user.isOrganizer || user.isAdmin);

    return Scaffold(
      appBar: AppBar(title: const Text('Sponsorship Categories')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? Center(
                  child: Text(
                    'No sponsorship categories yet.',
                    style: TextStyle(
                        color: AppTheme.textSecondaryOf(context)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cat.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            if (cat.description != null &&
                                cat.description!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(cat.description!,
                                  style: TextStyle(
                                      color:
                                          AppTheme.textSecondaryOf(context),
                                      fontSize: 13)),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _infoBadge(
                                    Icons.monetization_on_outlined,
                                    'Min: ${cat.minBidDisplay}'),
                                const SizedBox(width: 12),
                                _infoBadge(Icons.people_outline,
                                    '${cat.filledSpots}/${cat.totalSpots} spots'),
                                const SizedBox(width: 12),
                                _infoBadge(Icons.gavel,
                                    '${cat.bidCount} bid${cat.bidCount == 1 ? "" : "s"}'),
                              ],
                            ),
                            if (isSponsor && cat.availableSpots > 0) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _showPlaceBidDialog(cat),
                                  icon: const Icon(Icons.gavel, size: 18),
                                  label: const Text('Place Bid'),
                                ),
                              ),
                            ],
                            if (isOrganizerOrAdmin) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => context.push(
                                    '/events/${widget.eventId}/sponsorships/${cat.id}/bids',
                                  ),
                                  icon: const Icon(Icons.visibility_rounded, size: 18),
                                  label: Text(
                                    'View Bids (${cat.bidCount})',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.teal,
                                    side: const BorderSide(color: Colors.teal),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _infoBadge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondaryOf(context)),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                fontSize: 12, color: AppTheme.textSecondaryOf(context))),
      ],
    );
  }
}
