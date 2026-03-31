import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_typography.dart';
import '../../config/design_tokens.dart';
import '../../config/theme.dart';
import '../../models/funding.dart';
import '../../utils/date_time_utils.dart';
import '../../providers/pledge_provider.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/shimmer_loaders.dart';
import '../event/receipts/pledge_receipt_screen.dart';

class OrganizerPledgesScreen extends StatefulWidget {
  final String? eventStatus;
  final String? genre;
  final int? eventId;
  final String? eventTitle;
  const OrganizerPledgesScreen({super.key, this.eventStatus, this.genre, this.eventId, this.eventTitle});

  @override
  State<OrganizerPledgesScreen> createState() => _OrganizerPledgesScreenState();
}

class _OrganizerPledgesScreenState extends State<OrganizerPledgesScreen> {
  static const _pageSize = 20;

  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Pledge> _all = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  String _statusFilter = 'all';
  bool _showMore = false;

  static const _primaryStatuses = ['all', 'pledged', 'refunded'];
  static const _extraStatuses = ['donation', 'collected'];

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
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
    setState(() {
      _loading = true;
      _error = null;
      _hasMore = true;
    });
    try {
      final repo = context.read<PledgeProvider>();
      final result = await repo.getOrganizerPledges(
        status: _statusFilter == 'all' ? null : _statusFilter,
        eventStatus: widget.eventStatus,
        genre: widget.genre,
        eventId: widget.eventId,
        offset: 0,
        limit: _pageSize,
      );
      if (mounted) {
        setState(() {
          _all = result.items;
          _hasMore = result.hasMore;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final repo = context.read<PledgeProvider>();
      final result = await repo.getOrganizerPledges(
        status: _statusFilter == 'all' ? null : _statusFilter,
        eventStatus: widget.eventStatus,
        genre: widget.genre,
        eventId: widget.eventId,
        offset: _all.length,
        limit: _pageSize,
      );
      if (mounted) {
        setState(() {
          _all.addAll(result.items);
          _hasMore = result.hasMore;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<Pledge> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((p) {
      final backer = (p.backerName ?? '').toLowerCase();
      final event = (p.eventTitle ?? '').toLowerCase();
      final receipt = (p.receiptNumber ?? '').toLowerCase();
      return backer.contains(q) || event.contains(q) || receipt.contains(q);
    }).toList();
  }

  int get _totalAmount =>
      _all.fold<int>(0, (s, p) => s + p.amountCents);

  int get _totalNet =>
      _all.fold<int>(0, (s, p) => s + p.netToOrganizerCents);

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pledges & Backers'),
            if (widget.eventStatus != null || widget.genre != null || widget.eventId != null)
              Text(
                [
                  if (widget.eventStatus != null) widget.eventStatus!.replaceAll('_', ' '),
                  if (widget.genre != null) widget.genre!,
                  if (widget.eventTitle != null) widget.eventTitle!
                  else if (widget.eventId != null) 'Event #${widget.eventId}',
                ].join(' · '),
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search backer, event, receipt…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.cardOf(context),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppTheme.dividerOf(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppTheme.dividerOf(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppTheme.dividerOf(context)),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Primary status filter chips + "More" toggle
          SizedBox(
            height: AppSpacing.chipRowHeight,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                for (final s in _primaryStatuses) ...[
                  AppChip(
                    label: s[0].toUpperCase() + s.substring(1),
                    selected: _statusFilter == s,
                    onSelected: (_) {
                      setState(() => _statusFilter = s);
                      _load();
                    },
                    chipColor: context.fundingAccent,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                ActionChip(
                  avatar: Icon(
                    _showMore ? Icons.expand_less : Icons.expand_more,
                    size: AppIconSize.sm,
                    color: _showMore
                        ? Colors.white
                        : AppTheme.textSecondaryOf(context),
                  ),
                  label: const Text('More'),
                  labelStyle: AppTypography.chip.copyWith(
                    color: _showMore
                        ? Colors.white
                        : AppTheme.textSecondaryOf(context),
                  ),
                  backgroundColor:
                      _showMore ? AppTheme.accentColor : Colors.transparent,
                  side: BorderSide(
                    color: _showMore
                        ? AppTheme.accentColor
                        : AppTheme.dividerOf(context),
                  ),
                  shape: const StadiumBorder(),
                  onPressed: () => setState(() => _showMore = !_showMore),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Expandable section: extra filters + stat chips
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                // Extra status filter chips
                SizedBox(
                  height: AppSpacing.chipRowHeight,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    children: [
                      for (var i = 0; i < _extraStatuses.length; i++) ...[
                        AppChip(
                          label: _extraStatuses[i][0].toUpperCase() +
                              _extraStatuses[i].substring(1),
                          selected: _statusFilter == _extraStatuses[i],
                          onSelected: (_) {
                            setState(() => _statusFilter = _extraStatuses[i]);
                            _load();
                          },
                          chipColor: context.fundingAccent,
                        ),
                        if (i < _extraStatuses.length - 1)
                          const SizedBox(width: AppSpacing.sm),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),

                // Summary stat chips + refresh
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      _chip(
                        '${_all.length} backer${_all.length == 1 ? '' : 's'}',
                        Icons.volunteer_activism_rounded,
                        context.fundingAccent,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _chip(
                        '\$${(_totalAmount / 100).toStringAsFixed(2)}',
                        Icons.attach_money_rounded,
                        AppTheme.tealColor,
                      ),
                      if (_totalNet > 0 && _totalNet != _totalAmount) ...[
                        const SizedBox(width: AppSpacing.sm),
                        _chip(
                          'Net \$${(_totalNet / 100).toStringAsFixed(2)}',
                          Icons.account_balance_wallet_rounded,
                          AppTheme.purpleColor,
                        ),
                      ],
                      if (_searchCtrl.text.isNotEmpty) ...[
                        const SizedBox(width: AppSpacing.sm),
                        _chip(
                          '${filtered.length} match${filtered.length == 1 ? '' : 'es'}',
                          Icons.filter_list_rounded,
                          AppTheme.accentColor,
                        ),
                      ],
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: AppIconSize.md),
                        onPressed: _load,
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            crossFadeState: _showMore
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: AppDuration.normal,
          ),
          const SizedBox(height: AppSpacing.xs),

          Expanded(
            child: _loading
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children:
                          List.generate(4, (_) => const ShimmerListTile()),
                    ),
                  )
                : _error != null
                    ? _errorWidget()
                    : filtered.isEmpty
                        ? _emptyWidget()
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              controller: _scrollCtrl,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              itemCount:
                                  filtered.length + (_loadingMore ? 1 : 0),
                              itemBuilder: (_, i) {
                                if (i >= filtered.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  );
                                }
                                return _card(filtered[i]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _card(Pledge pledge) {
    final pledgeId = pledge.id;
    final eventId = pledge.eventId;
    final backerName = pledge.backerName ?? 'Anonymous';
    final eventTitle = pledge.eventTitle ?? '';
    final amount = pledge.amountCents;
    final netAmount = pledge.netToOrganizerCents;
    final spots = pledge.reservedSpots;
    final status = pledge.status.name;
    final isGuest = pledge.isGuest;
    final createdAt = AppDateFormat.fullDateTime(pledge.createdAt);

    final statusColor = switch (status) {
      'pledged' => AppTheme.successColor,
      'refunded' => AppTheme.errorColor,
      'collected' => AppTheme.tealColor,
      _ => AppTheme.textSecondaryOf(context),
    };

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PledgeReceiptScreen(
              eventId: eventId,
              pledgeId: pledgeId,
            ),
          )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isGuest
                ? context.photoAccent.withValues(alpha: 0.25)
                : AppTheme.dividerOf(context),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (isGuest ? context.photoAccent : context.fundingAccent)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isGuest
                      ? Icons.card_giftcard_rounded
                      : Icons.volunteer_activism_rounded,
                  size: 20,
                  color:
                      isGuest ? context.photoAccent : context.fundingAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      backerName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      eventTitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.accentColor,
                      ),
                    ),
                    if (spots > 0)
                      Text(
                        '$spots spot${spots == 1 ? '' : 's'} reserved',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                    if (createdAt.isNotEmpty)
                      Text(
                        createdAt,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                    Row(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            isGuest
                                ? 'DONATION'
                                : status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${(amount / 100).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  if (netAmount > 0 && netAmount != amount) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Net \$${(netAmount / 100).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon, Color c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = (isDark && (c.r * 255.0).round() < 50 && (c.g * 255.0).round() < 50 && (c.b * 255.0).round() < 50)
        ? AppTheme.accentColor
        : c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:
            isDark ? AppTheme.cardOf(context) : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: color.withValues(alpha: isDark ? 0.4 : 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.textPrimaryOf(context) : color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorWidget() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: AppTheme.textSecondaryOf(context)),
            const SizedBox(height: 12),
            Text('Failed to load pledges',
                style:
                    TextStyle(color: AppTheme.textSecondaryOf(context))),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );

  Widget _emptyWidget() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.volunteer_activism_outlined,
              size: 56,
              color: AppTheme.textSecondaryOf(context),
            ),
            const SizedBox(height: 12),
            Text(
              _searchCtrl.text.isNotEmpty
                  ? 'No matching pledges'
                  : 'No pledges yet',
              style: TextStyle(
                color: AppTheme.textSecondaryOf(context),
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
}
