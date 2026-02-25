import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/design_tokens.dart';
import '../../config/theme.dart';
import '../../widgets/animated_list_item.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';
import '../event/pledge_receipt_screen.dart';

class MyPledgesScreen extends StatefulWidget {
  const MyPledgesScreen({super.key});

  @override
  State<MyPledgesScreen> createState() => _MyPledgesScreenState();
}

class _MyPledgesScreenState extends State<MyPledgesScreen> {
  static const _pageSize = 20;

  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _pledges = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  String _search = '';
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent * 0.8 &&
        !_loadingMore &&
        _hasMore &&
        !_loading) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().user;
    if (user == null || !(user.isCustomer || user.isSponsor)) {
      if (mounted) setState(() { _loading = false; _error = 'Only customers and sponsors can view pledges'; });
      return;
    }
    setState(() { _loading = true; _error = null; _hasMore = true; });
    try {
      final api = context.read<ApiService>();
      final data = await api.getMyPledges(offset: 0, limit: _pageSize);
      if (mounted) {
        setState(() {
          _pledges = List<Map<String, dynamic>>.from(data);
          _hasMore = data.length >= _pageSize;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ApiService.extractError(e, fallback: 'Failed to load pledges');
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final api = context.read<ApiService>();
      final data = await api.getMyPledges(offset: _pledges.length, limit: _pageSize);
      if (mounted) {
        setState(() {
          _pledges.addAll(List<Map<String, dynamic>>.from(data));
          _hasMore = data.length >= _pageSize;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _pledges;

    if (_filterStatus != 'all') {
      if (_filterStatus == 'donation') {
        list = list.where((p) => p['is_guest'] == true).toList();
      } else {
        list = list.where((p) => p['status'] == _filterStatus && p['is_guest'] != true).toList();
      }
    }

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((p) {
        final title = (p['event_title'] ?? '').toString().toLowerCase();
        final receipt = (p['receipt_number'] ?? '').toString().toLowerCase();
        return title.contains(q) || receipt.contains(q);
      }).toList();
    }

    return list;
  }

  Map<int, List<Map<String, dynamic>>> get _groupedByEvent {
    final map = <int, List<Map<String, dynamic>>>{};
    for (final p in _filtered) {
      final eventId = p['event_id'] as int;
      map.putIfAbsent(eventId, () => []).add(p);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceOf(context),
      appBar: AppBar(title: const Text('My Pledges')),
      body: _loading
          ? SingleChildScrollView(
              padding: AppSpacing.paddingLg,
              child: Column(
                children: List.generate(4, (_) => const ShimmerListTile()),
              ),
            )
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final grouped = _groupedByEvent;
    final pledgedCount = _pledges.where((p) => p['status'] == 'pledged' && p['is_guest'] != true).length;
    final donationCount = _pledges.where((p) => p['is_guest'] == true).length;
    final refundedCount = _pledges.where((p) => p['status'] == 'refunded').length;
    final totalCents = _pledges.fold<int>(0, (s, p) => s + ((p['amount_cents'] ?? 0) as int));

    return RefreshIndicator(
      onRefresh: _load,
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
                  Row(
                    children: [
                      _statChip(Icons.volunteer_activism_rounded, '${_pledges.length}', 'Total'),
                      AppSpacing.hMd,
                      _statChip(Icons.check_circle_rounded, '$pledgedCount', 'Pledged',
                          color: AppTheme.successColor),
                      if (donationCount > 0) ...[
                        AppSpacing.hMd,
                        _statChip(Icons.card_giftcard_rounded, '$donationCount', 'Donations',
                            color: context.photoAccent),
                      ],
                      if (refundedCount > 0) ...[
                        AppSpacing.hMd,
                        _statChip(Icons.undo_rounded, '$refundedCount', 'Refunded',
                            color: AppTheme.errorColor),
                      ],
                    ],
                  ),
                  AppSpacing.vMd,
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: context.sponsorAccent.withValues(alpha: 0.08),
                      borderRadius: AppRadius.md,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.attach_money_rounded, size: 18, color: context.sponsorAccent),
                        AppSpacing.hSm,
                        Text('Total Contributed: \$${(totalCents / 100).toStringAsFixed(2)}',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700, color: context.sponsorAccent)),
                      ],
                    ),
                  ),
                  AppSpacing.vLg,
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
              child: _pledges.isEmpty
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
                    final pledges = grouped[eventId]!;
                    final eventTitle = (pledges.first['event_title'] ?? 'Event #$eventId').toString();
                    return AnimatedListItem(
                      index: index,
                      child: _EventPledgeGroup(
                        eventId: eventId,
                        eventTitle: eventTitle,
                        pledges: pledges,
                        onEventTap: () => context.push('/events/$eventId'),
                      ),
                    );
                  },
                  childCount: grouped.length,
                ),
              ),
            ),
          if (_loadingMore)
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

  Widget _statChip(IconData icon, String value, String label, {Color? color}) {
    final c = color ?? AppTheme.textPrimaryOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: AppRadius.md,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: c),
          AppSpacing.hSm,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c)),
              Text(label,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                      color: c.withValues(alpha: 0.7))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final active = _filterStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => setState(() => _filterStatus = value),
      selectedColor: AppTheme.primaryColor,
      backgroundColor: AppTheme.cardOf(context),
      side: BorderSide(
        color: active ? AppTheme.primaryColor : AppTheme.dividerOf(context),
      ),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: active ? Colors.white : AppTheme.textPrimaryOf(context),
      ),
    );
  }
}

class _EventPledgeGroup extends StatelessWidget {
  final int eventId;
  final String eventTitle;
  final List<Map<String, dynamic>> pledges;
  final VoidCallback onEventTap;

  const _EventPledgeGroup({
    required this.eventId,
    required this.eventTitle,
    required this.pledges,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    final donationCount = pledges.where((p) => p['is_guest'] == true).length;
    final totalCents = pledges.fold<int>(0, (s, p) => s + ((p['amount_cents'] ?? 0) as int));

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
                color: context.sponsorSurface,
                borderRadius: AppRadius.md,
                border: Border.all(color: context.sponsorAccent.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: context.sponsorAccent.withValues(alpha: 0.1),
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
                        Text(
                          '${pledges.length} pledge${pledges.length == 1 ? '' : 's'}'
                          '${donationCount > 0 ? ' \u2022 $donationCount donation${donationCount == 1 ? '' : 's'}' : ''}'
                          ' \u2022 \$${(totalCents / 100).toStringAsFixed(2)}',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                        ),
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
  final Map<String, dynamic> pledge;

  const _PledgeCard({required this.pledge});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final dateFmt = DateFormat('MMM d, yyyy \u2022 h:mm a');
    final amountCents = (pledge['amount_cents'] ?? 0) as int;
    final reservedSpots = (pledge['reserved_spots'] ?? 0) as int;
    final receipt = (pledge['receipt_number'] ?? '').toString();
    final status = (pledge['status'] ?? 'pledged').toString();
    final isGuest = pledge['is_guest'] == true;
    final createdAt = pledge['created_at'] != null
        ? DateTime.parse(pledge['created_at']).toLocal()
        : null;

    final statusLabel = isGuest ? 'DONATION' : status.toUpperCase();
    final headerColor = isGuest ? context.photoAccent : context.sponsorAccent;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PledgeReceiptScreen(
            eventId: pledge['event_id'] as int,
            pledgeId: pledge['id'] as int,
          ),
        ));
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: AppRadius.lg,
          boxShadow: AppShadow.card(isDark),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md + 2, AppSpacing.lg, AppSpacing.md),
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: AppRadius.topLg,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: AppRadius.sm,
                    ),
                    child: Icon(
                      isGuest ? Icons.card_giftcard_rounded : Icons.volunteer_activism_rounded,
                      color: Colors.white, size: 20),
                  ),
                  AppSpacing.hMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isGuest ? 'Guest Donation' : 'Pledge',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (reservedSpots > 0) ...[
                          AppSpacing.vXs,
                          Text(
                            '$reservedSpots spot(s) reserved',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
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
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: AppRadius.pill,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      statusLabel,
                      style: const TextStyle(
                        color: Colors.white,
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
                  _infoRow(context, Icons.receipt_outlined, 'Receipt', receipt.isNotEmpty ? receipt : '—',
                      copyable: receipt.isNotEmpty),
                  AppSpacing.vSm,
                  if (reservedSpots > 0) ...[
                    _infoRow(context, Icons.event_seat_rounded, 'Spots', '$reservedSpots reserved'),
                    AppSpacing.vSm,
                  ],
                  if (createdAt != null) ...[
                    _infoRow(context, Icons.calendar_today_rounded, 'Date', dateFmt.format(createdAt)),
                    AppSpacing.vSm,
                  ],
                  if (isGuest)
                    _infoRow(context, Icons.info_outline_rounded, 'Type', 'Non-refundable donation',
                        valueColor: context.photoAccent),
                  if (isGuest) AppSpacing.vSm,

                  AppSpacing.vXs,
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                        decoration: BoxDecoration(
                          color: headerColor.withValues(alpha: 0.1),
                          borderRadius: AppRadius.sm,
                        ),
                        child: Text(
                          '\$${(amountCents / 100).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: headerColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: headerColor,
                          borderRadius: AppRadius.sm,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_rounded, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text('View Receipt',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
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
