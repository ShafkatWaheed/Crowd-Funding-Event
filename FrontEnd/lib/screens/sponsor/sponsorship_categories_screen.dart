import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/event.dart';
import '../../models/sponsor.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/base_repository.dart';
import '../../providers/event_provider.dart';
import '../../providers/sponsor_provider.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/shimmer_loaders.dart';
import 'sponsorship_categories/bid_leaderboard.dart';
import 'sponsorship_categories/category_requirements.dart';
import 'sponsorship_categories/my_bid_actions.dart';
import 'sponsorship_categories/place_bid_dialog.dart';
import 'sponsorship_categories/prerequisite_sheet.dart';

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
  EventStatus? _eventStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final sponsorRepo = context.read<SponsorProvider>();
      final eventRepo = context.read<EventProvider>();
      final results = await Future.wait([
        sponsorRepo.getSponsorshipCategories(widget.eventId),
        eventRepo.getEvent(widget.eventId),
      ]);
      final categories = results[0] as List<SponsorshipCategory>;
      final eventData = results[1] as Map<String, dynamic>;
      final statusStr = eventData['status'] as String? ?? 'draft';
      if (mounted) {
        setState(() {
          _categories = categories;
          _eventStatus = EventStatus.values.firstWhere(
            (e) => e.name == statusStr,
            orElse: () => EventStatus.draft,
          );
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

  Future<void> _showPlaceBidDialog(SponsorshipCategory cat) async {
    final result = await showDialog<BidDialogResult>(
      context: context,
      builder: (ctx) => PlaceBidDialog(
        eventId: widget.eventId,
        category: cat,
      ),
    );

    if (result == null || !mounted) return;

    try {
      final api = context.read<SponsorProvider>();
      await api.placeBid(widget.eventId, cat.id, {
        'amount_cents': result.amountCents,
        if (result.proposalText != null)
          'proposal_text': result.proposalText,
      });

      if (mounted) AppToast.success(context, 'Bid placed!');
      _load();
    } catch (e) {
      if (mounted) AppToast.error(context, ApiError.extractMessage(e));
    }
  }

  Future<void> _showPrerequisitesSheet(SponsorshipCategory cat) async {
    final locked = _eventStatus == EventStatus.live ||
        _eventStatus == EventStatus.completed ||
        _eventStatus == EventStatus.cancelled;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: AppTheme.cardOf(context),
      builder: (ctx) => PrerequisiteSheet(
        eventId: widget.eventId,
        categoryId: cat.id,
        categoryName: cat.name,
        readOnly: locked,
      ),
    );
  }

  Future<void> _showAddSponsorshipDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final spotsCtrl = TextEditingController(text: '1');
    final minBidCtrl = TextEditingController(text: '100.00');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Sponsorship'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Sponsorship Name *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: spotsCtrl,
                decoration: const InputDecoration(labelText: 'Total Spots *'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: minBidCtrl,
                decoration: const InputDecoration(
                  labelText: 'Minimum Bid (\$) *',
                  hintText: '100.00',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );

    if (confirmed != true) return;
    final name = nameCtrl.text.trim();
    final spots = int.tryParse(spotsCtrl.text.trim());
    final minBid = double.tryParse(minBidCtrl.text.trim());
    if (name.isEmpty || spots == null || spots < 1 || minBid == null || minBid <= 0) {
      if (mounted) AppToast.error(context, 'Please fill in all required fields correctly.');
      return;
    }

    if (!mounted) return;
    try {
      final api = context.read<SponsorProvider>();
      await api.createSponsorshipCategory(widget.eventId, {
        'name': name,
        'description': descCtrl.text.trim(),
        'total_spots': spots,
        'min_bid_cents': (minBid * 100).round(),
      });
      if (mounted) AppToast.success(context, 'Sponsorship created');
      _load();
    } catch (e) {
      if (mounted) AppToast.error(context, ApiError.extractMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isSponsor = user?.isSponsor ?? false;
    final isOrganizerOrAdmin = user != null && (user.isOrganizer || user.isAdmin);
    final canCreate = isOrganizerOrAdmin &&
        _eventStatus != null &&
        _eventStatus != EventStatus.live &&
        _eventStatus != EventStatus.completed &&
        _eventStatus != EventStatus.cancelled;

    return Scaffold(
      appBar: AppBar(title: const Text('Sponsorships')),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _showAddSponsorshipDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Sponsorship'),
              backgroundColor: context.sponsorAccent,
              foregroundColor: Colors.white,
            )
          : null,
      body: _loading
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List.generate(3, (_) => const ShimmerListTile()),
              ),
            )
          : _categories.isEmpty
              ? LayoutBuilder(
                  builder: (context, constraints) => RefreshIndicator(
                    onRefresh: _load,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Center(
                          child: Text(
                            'No sponsorships yet.',
                            style: TextStyle(
                                color: AppTheme.textSecondaryOf(context)),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    return _buildCategoryCard(cat, isSponsor, isOrganizerOrAdmin);
                  },
                ),
              ),
    );
  }

  Widget _buildCategoryCard(
    SponsorshipCategory cat,
    bool isSponsor,
    bool isOrganizerOrAdmin,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cat.name,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.textPrimaryOf(context))),
            if (cat.description != null &&
                cat.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(cat.description!,
                  style: TextStyle(
                      color: AppTheme.textSecondaryOf(context),
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
            if (cat.bidAmounts.length >= 2) ...[
              const SizedBox(height: 12),
              BidLeaderboard(bidAmounts: cat.bidAmounts),
            ],
            if (isSponsor && cat.canPlaceMoreBids) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showPlaceBidDialog(cat),
                  icon: const Icon(Icons.gavel, size: 18),
                  label: Text(cat.myBidCount > 0
                      ? 'Place Another Bid (${cat.myBidCount}/${cat.totalSpots})'
                      : 'Place Bid'),
                ),
              ),
            ],
            if (isSponsor && cat.myBids.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...cat.myBids.map((b) => MyBidActions(
                bid: b,
                eventId: widget.eventId,
                categoryId: cat.id,
                onDone: _load,
              )),
            ],
            if (isSponsor && cat.prereqCount > 0) ...[
              const SizedBox(height: 10),
              CategoryRequirements(
                eventId: widget.eventId,
                categoryId: cat.id,
                categoryName: cat.name,
                myBids: cat.myBids,
              ),
            ],
            if (isOrganizerOrAdmin) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
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
                        foregroundColor: context.ticketAccent,
                        side: BorderSide(color: context.ticketAccent),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showPrerequisitesSheet(cat),
                    icon: const Icon(Icons.checklist_rounded, size: 18),
                    label: const Text('Reqs',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.sponsorAccent,
                      side: BorderSide(color: context.sponsorAccent),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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
