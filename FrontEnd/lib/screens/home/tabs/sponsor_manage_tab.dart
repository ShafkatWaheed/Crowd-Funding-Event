import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../home_shared.dart';
import '../../../config/design_tokens.dart';
import '../../../config/theme.dart';
import '../../../models/event.dart';
import '../../../providers/auth_provider.dart';
import '../../../utils/date_time_utils.dart';
import '../../../providers/sponsor_provider.dart';
import '../../../widgets/animated_list_item.dart';
import '../../../widgets/kyc_required_banner.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/shimmer_loaders.dart';

class SponsorManageTab extends StatefulWidget {
  final Widget? headerIcons;

  const SponsorManageTab({super.key, this.headerIcons});

  @override
  State<SponsorManageTab> createState() => _SponsorManageTabState();
}

class _SponsorManageTabState extends State<SponsorManageTab> {
  List<SponsorBidEvent> _sponsorBidEvents = [];
  bool _sponsorBidEventsLoading = false;
  String _sponsorBidSearch = '';
  String? _sponsorBidStatus;

  List<EventStatus> get _manageVisibleStatuses {
    final user = context.read<AuthProvider>().user;
    if (user != null && (user.isOrganizer || user.isAdmin)) {
      return EventStatus.values.toList();
    }
    return [
      EventStatus.approved,
      EventStatus.waiting_event_date,
      EventStatus.selling_tickets,
      EventStatus.live,
      EventStatus.completed,
      EventStatus.cancelled,
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSponsorBidEvents());
  }

  Future<void> _loadSponsorBidEvents() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null || !auth.user!.isSponsor) return;
    setState(() => _sponsorBidEventsLoading = true);
    try {
      final api = context.read<SponsorProvider>();
      final data = await api.getSponsorBidEvents();
      if (mounted) {
        setState(() {
          _sponsorBidEvents = data;
        });
      }
    } catch (e) {
      debugPrint('_loadSponsorBidEvents error: $e');
    }
    if (mounted) {
      setState(() => _sponsorBidEventsLoading = false);
    }
  }

  Future<void> _refreshSponsorData() async {
    await _loadSponsorBidEvents();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final bidCount = _sponsorBidEvents.length;

    final filteredBids = _sponsorBidEvents.where((item) {
      if (_sponsorBidStatus != null &&
          item.event.status.name != _sponsorBidStatus) {
        return false;
      }
      if (_sponsorBidSearch.isNotEmpty) {
        final q = _sponsorBidSearch.toLowerCase();
        return item.event.title.toLowerCase().contains(q) ||
            (item.event.genre?.toLowerCase().contains(q) ?? false) ||
            item.event.status.name.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    final user = context.read<AuthProvider>().user;

    return Column(
      children: [
        if (user != null && user.kycStatus != 'verified')
          const KycRequiredBanner(action: 'place sponsorship bids'),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardOf(context),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(AppRadius.xxlValue),
              bottomRight: Radius.circular(AppRadius.xxlValue),
            ),
            boxShadow: AppShadow.soft(isDark),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            56,
            AppSpacing.xxl,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sponsorships',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceOf(context),
                      borderRadius: AppRadius.pill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.gavel_rounded, size: 13,
                            color: AppTheme.textSecondaryOf(context)),
                        const SizedBox(width: 4),
                        Text(
                          '$bidCount bid${bidCount != 1 ? "s" : ""}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.headerIcons != null) ...[
                    AppSpacing.hSm,
                    widget.headerIcons!,
                  ],
                ],
              ),
              AppSpacing.vLg,
              Row(
                children: [
                  customerQuickAction(
                    context: context,
                    icon: Icons.workspace_premium_rounded,
                    label: 'Sponsor Tickets',
                    color: context.managementAccent,
                    onTap: () => context.push('/sponsor/tickets'),
                  ),
                  AppSpacing.hSm,
                  customerQuickAction(
                    context: context,
                    icon: Icons.volunteer_activism_rounded,
                    label: 'My Pledges',
                    color: context.sponsorAccent,
                    onTap: () => context.push('/my-pledges'),
                  ),
                ],
              ),
              AppSpacing.vLg,
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search bid events\u2026',
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppTheme.textSecondaryOf(context),
                    size: AppIconSize.md,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: 14,
                  ),
                  filled: true,
                  fillColor: AppTheme.inputFillOf(context),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.md,
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _sponsorBidSearch = v),
              ),
              AppSpacing.vSm,
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _manageVisibleStatuses.map((s) {
                    final isActive = _sponsorBidStatus == s.name;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(statusDisplayName(s)),
                        selected: isActive,
                        onSelected: (selected) {
                          setState(() => _sponsorBidStatus = selected ? s.name : null);
                        },
                        selectedColor: statusChipColor(context, s),
                        backgroundColor: AppTheme.cardOf(context),
                        side: BorderSide(
                          color: isActive
                              ? statusChipColor(context, s)
                              : AppTheme.dividerOf(context),
                        ),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                              isActive ? Colors.white : AppTheme.textPrimaryOf(context),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildSponsorBidsList(filteredBids),
        ),
      ],
    );
  }

  Widget _buildSponsorBidsList(List<SponsorBidEvent> filtered) {
    if (_sponsorBidEventsLoading) {
      return SingleChildScrollView(
        child: ShimmerEventList(count: 3),
      );
    }
    if (filtered.isEmpty) {
      return EmptyState(
        icon: Icons.gavel_rounded,
        title: _sponsorBidEvents.isEmpty ? 'No bids yet' : 'No matches',
        subtitle: _sponsorBidEvents.isEmpty
            ? 'Events you bid on will appear here'
            : 'Try a different search term',
      );
    }
    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: _refreshSponsorData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          100,
        ),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final item = filtered[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AnimatedListItem(
              index: index,
              child: SponsorBidEventCard(
                item: item,
                onTap: () => context.push('/events/${item.event.id}'),
              ),
            ),
          );
        },
      ),
    );
  }
}

class SponsorBidEventCard extends StatelessWidget {
  final SponsorBidEvent item;
  final VoidCallback onTap;

  const SponsorBidEventCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final e = item.event;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: AppRadius.lg,
          boxShadow: AppShadow.card(isDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                14,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.cardGradientStart, context.cardGradientEnd],
                ),
                borderRadius: AppRadius.topLg,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  AppSpacing.hSm,
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: AppRadius.pill,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      statusDisplayName(e.status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (e.startTime != null)
                    _infoRow(
                      context,
                      Icons.schedule_rounded,
                      AppDateFormat.eventCard(e.startTime!),
                    ),
                  if (e.venue != null) ...[
                    const SizedBox(height: 5),
                    _infoRow(
                      context,
                      Icons.location_on_rounded,
                      '${e.venue!.name}, ${e.venue!.city}',
                    ),
                  ],
                  AppSpacing.vLg,
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      if (item.accepted > 0)
                        _bidChip('${item.accepted} Accepted', context.bidAccepted,
                            Icons.check_circle_rounded),
                      if (item.paid > 0)
                        _bidChip(
                            '${item.paid} Paid', context.bidPaid, Icons.payment_rounded),
                      if (item.pending > 0)
                        _bidChip('${item.pending} Under Review', context.bidPending,
                            Icons.hourglass_top_rounded),
                      if (item.rejected > 0)
                        _bidChip('${item.rejected} Rejected', context.bidRejected,
                            Icons.cancel_rounded),
                      _bidChip('${item.totalBids} Total',
                          AppTheme.textSecondaryOf(context), Icons.gavel_rounded),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppTheme.textSecondaryOf(context)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bidChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pill,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSize.sm - 3, color: color),
          AppSpacing.hXs,
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
