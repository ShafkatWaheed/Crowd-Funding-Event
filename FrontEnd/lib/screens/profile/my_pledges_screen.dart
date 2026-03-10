import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_icons.dart';
import '../../config/design_tokens.dart';
import '../../utils/date_time_utils.dart';
import '../../config/theme.dart';
import '../../models/funding.dart';
import '../../widgets/animated_list_item.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_switcher.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pledge_provider.dart';
import '../../widgets/app_toast.dart';
import '../event/receipts/pledge_receipt_screen.dart';

class MyPledgesScreen extends StatefulWidget {
  const MyPledgesScreen({super.key});

  @override
  State<MyPledgesScreen> createState() => _MyPledgesScreenState();
}

class _MyPledgesScreenState extends State<MyPledgesScreen> {
  final _scrollCtrl = ScrollController();
  // Client-side UI state (not in provider)
  String _search = '';
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null && (user.isCustomer || user.isSponsor)) {
        context.read<PledgeProvider>().load();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final p = context.read<PledgeProvider>();
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent * 0.8 &&
        !p.loadingMore &&
        p.hasMore &&
        !p.loading) {
      p.loadMore();
    }
  }

  List<Pledge> get _filtered {
    final p = context.read<PledgeProvider>();
    var list = p.pledges;

    if (_filterStatus != 'all') {
      if (_filterStatus == 'donation') {
        list = list.where((p) => p.isGuest).toList();
      } else {
        list = list.where((p) => p.status.name == _filterStatus && !p.isGuest).toList();
      }
    }

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((p) {
        final title = (p.eventTitle ?? '').toLowerCase();
        final receipt = (p.receiptNumber ?? '').toLowerCase();
        return title.contains(q) || receipt.contains(q);
      }).toList();
    }

    return list;
  }

  Map<int, List<Pledge>> get _groupedByEvent {
    final map = <int, List<Pledge>>{};
    for (final p in _filtered) {
      map.putIfAbsent(p.eventId, () => []).add(p);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PledgeProvider>();
    final user = context.read<AuthProvider>().user;
    final roleError = (user == null || !(user.isCustomer || user.isSponsor))
        ? 'Only customers and sponsors can view pledges'
        : null;

    return Scaffold(
      backgroundColor: AppTheme.surfaceOf(context),
      appBar: AppBar(title: const Text('My Pledges')),
      body: LoadingSwitcher(
        loading: p.loading,
        loadingChild: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Column(
            children: List.generate(4, (_) => const ShimmerListTile()),
          ),
        ),
        child: (roleError ?? p.error) != null
            ? ErrorState(message: roleError ?? p.error!, onRetry: p.load)
            : _buildContent(p),
      ),
    );
  }

  Widget _buildContent(PledgeProvider p) {
    final grouped = _groupedByEvent;

    return RefreshIndicator(
      onRefresh: p.refresh,
      color: AppTheme.primaryColor,
      child: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.cardOf(context),
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by event, receipt...',
                      prefixIcon: Icon(Icons.search, size: 20,
                          color: AppTheme.textSecondaryOf(context)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      filled: true,
                      fillColor: AppTheme.inputFillOf(context),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.md,
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                  AppSpacing.vMd,

                  // Sort chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Icon(Icons.sort_rounded, size: 18,
                            color: AppTheme.textSecondaryOf(context)),
                        AppSpacing.hSm,
                        ...<String, String>{
                          'newest': 'Newest',
                          'oldest': 'Oldest',
                          'amount_high': 'Amount \u2191',
                          'amount_low': 'Amount \u2193',
                        }.entries.map((e) => Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.sm),
                              child: Builder(builder: (context) {
                                final (activeBg, activeLabel) = AppTheme.chipActive(context.sponsorAccent);
                                return ChoiceChip(
                                  label: Text(e.value),
                                  selected: p.sortBy == e.key,
                                  onSelected: (_) => p.setSortBy(e.key),
                                  showCheckmark: false,
                                  color: WidgetStateProperty.resolveWith((states) =>
                                      states.contains(WidgetState.selected) ? activeBg : AppTheme.cardOf(context)),
                                  side: BorderSide(
                                    color: p.sortBy == e.key ? activeBg : AppTheme.dividerOf(context),
                                  ),
                                  labelStyle: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: p.sortBy == e.key ? activeLabel : AppTheme.textPrimaryOf(context),
                                  ),
                                );
                              }),
                            )),
                      ],
                    ),
                  ),
                  AppSpacing.vMd,

                  // Filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip('All', 'all'),
                        AppSpacing.hSm,
                        _filterChip('Pledged', 'pledged'),
                        AppSpacing.hSm,
                        _filterChip('Donation', 'donation'),
                        AppSpacing.hSm,
                        _filterChip('Refunded', 'refunded'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (grouped.isEmpty)
            SliverFillRemaining(
              child: p.pledges.isEmpty
                  ? EmptyState(
                      icon: Icons.volunteer_activism_outlined,
                      title: 'No pledges yet',
                      subtitle: 'Pledges you make will appear here',
                    )
                  : EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No matches',
                      subtitle: 'Try a different search or filter',
                    ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final eventId = grouped.keys.elementAt(index);
                    final eventPledges = grouped[eventId]!;
                    final eventTitle = eventPledges.first.eventTitle ?? 'Event #$eventId';
                    return AnimatedListItem(
                      index: index,
                      child: _EventPledgeGroup(
                        eventId: eventId,
                        eventTitle: eventTitle,
                        pledges: eventPledges,
                        onEventTap: () => context.push('/events/$eventId'),
                      ),
                    );
                  },
                  childCount: grouped.length,
                ),
              ),
            ),
          if (p.loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final active = _filterStatus == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (chipIcon, chipColor) = switch (value) {
      'all'      => (Icons.volunteer_activism_rounded, AppTheme.accentColor),
      'pledged'  => (AppIcons.pledgeStatusIcon(PledgeStatus.pledged),  AppIcons.pledgeStatusColor(PledgeStatus.pledged,  isDark: isDark)),
      'donation' => (AppIcons.donationIcon, AppIcons.donationColor(isDark: isDark)),
      'refunded' => (AppIcons.pledgeStatusIcon(PledgeStatus.refunded), AppIcons.pledgeStatusColor(PledgeStatus.refunded, isDark: isDark)),
      _          => (Icons.list_rounded, AppTheme.accentColor),
    };
    final (activeBg, activeLabel) = AppTheme.chipActive(chipColor);
    return ChoiceChip(
      avatar: Icon(chipIcon, size: 14, color: active ? activeLabel : chipColor),
      label: Text(label),
      selected: active,
      showCheckmark: false,
      onSelected: (_) => setState(() => _filterStatus = value),
      color: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? activeBg : AppTheme.cardOf(context)),
      side: BorderSide(color: active ? activeBg : AppTheme.dividerOf(context)),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: active ? activeLabel : AppTheme.textPrimaryOf(context),
      ),
    );
  }
}

class _EventPledgeGroup extends StatelessWidget {
  final int eventId;
  final String eventTitle;
  final List<Pledge> pledges;
  final VoidCallback onEventTap;

  const _EventPledgeGroup({
    required this.eventId,
    required this.eventTitle,
    required this.pledges,
    required this.onEventTap,
  });

  String _fmt(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final pledgedCents  = pledges.where((p) => !p.isGuest && p.status != PledgeStatus.refunded)
        .fold<int>(0, (s, p) => s + p.amountCents);
    final donationCents = pledges.where((p) => p.isGuest)
        .fold<int>(0, (s, p) => s + p.amountCents);
    final refundedCents = pledges.where((p) => !p.isGuest && p.status == PledgeStatus.refunded)
        .fold<int>(0, (s, p) => s + p.amountCents);

    final parts = <String>[
      if (pledgedCents > 0) '${_fmt(pledgedCents)} pledged',
      if (donationCents > 0) '${_fmt(donationCents)} donated',
      if (refundedCents > 0) '${_fmt(refundedCents)} refunded',
    ];
    final subtitle = parts.join(' \u2022 ');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onEventTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: context.sponsorAccent.withValues(alpha: isDark ? 0.28 : 0.18),
                borderRadius: AppRadius.md,
                border: Border.all(color: context.sponsorAccent.withValues(alpha: 0.28)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: context.sponsorAccent.withValues(alpha: 0.18),
                      borderRadius: AppRadius.sm,
                    ),
                    child: Icon(Icons.event_rounded, size: 18, color: context.sponsorAccent),
                  ),
                  AppSpacing.hMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(eventTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14,
                                color: AppTheme.textPrimaryOf(context))),
                        AppSpacing.vXs,
                        Text(subtitle,
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textSecondaryOf(context))),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: AppTheme.textSecondaryOf(context), size: 20),
                ],
              ),
            ),
          ),
          AppSpacing.vSm,
          ...pledges.map((pledge) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PledgeCard(pledge: pledge),
              )),
        ],
      ),
    );
  }
}

class _PledgeCard extends StatelessWidget {
  final Pledge pledge;

  const _PledgeCard({required this.pledge});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    final statusLabel = pledge.isGuest ? 'DONATION' : pledge.status.name.toUpperCase();
    final headerColor = pledge.isGuest
        ? AppIcons.donationColor(isDark: isDark)
        : AppIcons.pledgeStatusColor(pledge.status, isDark: isDark);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PledgeReceiptScreen(
            eventId: pledge.eventId,
            pledgeId: pledge.id,
          ),
        ));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            context.sponsorAccent.withValues(alpha: 0.04),
            AppTheme.cardOf(context),
          ),
          borderRadius: AppRadius.lg,
          boxShadow: AppShadow.card(isDark),
          border: Border.all(color: AppTheme.dividerOf(context), width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md + 2, AppSpacing.lg, AppSpacing.md),
              decoration: AppTheme.glowHeaderDecoration(
                color: headerColor,
                isDark: isDark,
                borderRadius: AppRadius.topLg,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.glowHeaderIconBox(headerColor, isDark),
                      borderRadius: AppRadius.sm,
                    ),
                    child: Icon(
                      pledge.isGuest ? Icons.card_giftcard_rounded : Icons.volunteer_activism_rounded,
                      color: AppTheme.glowHeaderTitle(isDark), size: 20),
                  ),
                  AppSpacing.hMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pledge.isGuest ? 'Guest Donation' : 'Pledge',
                          style: TextStyle(
                            color: AppTheme.glowHeaderTitle(isDark),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (pledge.reservedSpots > 0) ...[
                          AppSpacing.vXs,
                          Text(
                            '${pledge.reservedSpots} spot(s) reserved',
                            style: TextStyle(
                              color: AppTheme.glowHeaderSubtitle(isDark),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppTheme.glowHeaderBadgeBg(headerColor, isDark),
                      borderRadius: AppRadius.pill,
                      border: Border.all(color: AppTheme.glowHeaderBadgeBorder(headerColor, isDark)),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: AppTheme.glowHeaderBadgeText(headerColor, isDark),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Container(
              width: double.infinity,
              height: 1,
              color: AppTheme.dividerOf(context),
            ),

            Padding(
              padding: AppSpacing.paddingLg,
              child: Column(
                children: [
                  _infoRow(context, Icons.receipt_outlined, 'Receipt',
                      pledge.receiptNumber?.isNotEmpty == true ? pledge.receiptNumber! : '—',
                      copyable: pledge.receiptNumber?.isNotEmpty == true),
                  AppSpacing.vSm,
                  if (pledge.reservedSpots > 0) ...[
                    _infoRow(context, Icons.event_seat_rounded, 'Spots', '${pledge.reservedSpots} reserved'),
                    AppSpacing.vSm,
                  ],
                  _infoRow(context, Icons.calendar_today_rounded, 'Date',
                      AppDateFormat.shortDateTime(pledge.createdAt.toLocal())),
                  AppSpacing.vSm,
                  if (pledge.isGuest)
                    _infoRow(context, Icons.info_outline_rounded, 'Type', 'Non-refundable donation',
                        valueColor: context.photoAccent),
                  if (pledge.isGuest) AppSpacing.vSm,

                  AppSpacing.vXs,
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.frostedBg(isDark, darkAlpha: 0.12, lightAlpha: 0.08),
                          borderRadius: AppRadius.sm,
                        ),
                        child: Text(
                          pledge.amountFormatted,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.frostedFg(isDark),
                          ),
                        ),
                      ),
                      const Spacer(),
                      const _ReceiptButton(),
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

  Widget _infoRow(BuildContext context, IconData icon, String label, String value,
      {bool copyable = false, Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondaryOf(context)),
        AppSpacing.hSm,
        SizedBox(
          width: 72,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryOf(context),
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppTheme.textPrimaryOf(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        if (copyable)
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              AppToast.info(context, 'Copied to clipboard');
            },
            child: Icon(Icons.copy_rounded, size: 14, color: AppTheme.textSecondaryOf(context)),
          ),
      ],
    );
  }
}

class _ReceiptButton extends StatelessWidget {
  const _ReceiptButton();

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final bg = AppTheme.frostedBg(isDark, darkAlpha: 0.12, lightAlpha: 0.08);
    final fg = AppTheme.frostedFg(isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: AppSpacing.sm),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_rounded, size: 16, color: fg),
          const SizedBox(width: 6),
          Text('View Receipt',
              style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
