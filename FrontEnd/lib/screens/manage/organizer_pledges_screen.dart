import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/shimmer_loaders.dart';
import '../event/pledge_receipt_screen.dart';

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
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  String _statusFilter = 'all';

  static const _statuses = ['all', 'pledged', 'donation', 'refunded', 'collected'];

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
      final api = context.read<ApiService>();
      final data = await api.getOrganizerPledges(
        status: _statusFilter == 'all' ? null : _statusFilter,
        eventStatus: widget.eventStatus,
        genre: widget.genre,
        eventId: widget.eventId,
        offset: 0,
        limit: _pageSize,
      );
      if (mounted) {
        setState(() {
          _all = data.map((e) => Map<String, dynamic>.from(e)).toList();
          _hasMore = data.length >= _pageSize;
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
      final api = context.read<ApiService>();
      final data = await api.getOrganizerPledges(
        status: _statusFilter == 'all' ? null : _statusFilter,
        eventStatus: widget.eventStatus,
        genre: widget.genre,
        eventId: widget.eventId,
        offset: _all.length,
        limit: _pageSize,
      );
      if (mounted) {
        setState(() {
          _all.addAll(data.map((e) => Map<String, dynamic>.from(e)));
          _hasMore = data.length >= _pageSize;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((p) {
      final backer = (p['backer_name'] ?? '').toString().toLowerCase();
      final event = (p['event_title'] ?? '').toString().toLowerCase();
      final receipt = (p['receipt_number'] ?? '').toString().toLowerCase();
      return backer.contains(q) || event.contains(q) || receipt.contains(q);
    }).toList();
  }

  int get _totalAmount =>
      _all.fold<int>(0, (s, p) => s + ((p['amount_cents'] ?? 0) as int));

  int get _totalNet =>
      _all.fold<int>(
          0, (s, p) => s + ((p['net_to_organizer_cents'] ?? 0) as int));

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

          // Status filter chips
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _statuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = _statuses[i];
                final active = _statusFilter == s;
                return ChoiceChip(
                  label: Text(s[0].toUpperCase() + s.substring(1)),
                  selected: active,
                  onSelected: (_) {
                    setState(() => _statusFilter = s);
                    _load();
                  },
                  selectedColor: context.fundingAccent,
                  backgroundColor: AppTheme.cardOf(context),
                  side: BorderSide(
                    color: active
                        ? context.fundingAccent
                        : AppTheme.dividerOf(context),
                  ),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active
                        ? Colors.white
                        : AppTheme.textPrimaryOf(context),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),

          // Summary chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _chip(
                  '${_all.length} backer${_all.length == 1 ? '' : 's'}',
                  Icons.volunteer_activism_rounded,
                  context.fundingAccent,
                ),
                const SizedBox(width: 8),
                _chip(
                  '\$${(_totalAmount / 100).toStringAsFixed(2)}',
                  Icons.attach_money_rounded,
                  Colors.teal,
                ),
                if (_totalNet > 0 && _totalNet != _totalAmount) ...[
                  const SizedBox(width: 8),
                  _chip(
                    'Net \$${(_totalNet / 100).toStringAsFixed(2)}',
                    Icons.account_balance_wallet_rounded,
                    Colors.deepPurple,
                  ),
                ],
                if (_searchCtrl.text.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _chip(
                    '${filtered.length} match${filtered.length == 1 ? '' : 'es'}',
                    Icons.filter_list_rounded,
                    AppTheme.accentColor,
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _load,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

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

  Widget _card(Map<String, dynamic> pledge) {
    final pledgeId = pledge['id'] as int?;
    final eventId = pledge['event_id'] as int?;
    final backerName = pledge['backer_name'] ?? 'Anonymous';
    final eventTitle = pledge['event_title'] ?? '';
    final amount = (pledge['amount_cents'] ?? 0) as int;
    final netAmount = (pledge['net_to_organizer_cents'] ?? 0) as int;
    final spots = (pledge['reserved_spots'] ?? 0) as int;
    final status = (pledge['status'] ?? 'pledged').toString();
    final isGuest = pledge['is_guest'] == true;
    final createdAt = pledge['created_at'] != null
        ? DateFormat.yMMMd()
            .add_jm()
            .format(DateTime.parse(pledge['created_at']).toLocal())
        : '';

    final statusColor = switch (status) {
      'pledged' => AppTheme.successColor,
      'refunded' => AppTheme.errorColor,
      'collected' => Colors.teal,
      _ => AppTheme.textSecondaryOf(context),
    };

    return GestureDetector(
      onTap: pledgeId != null && eventId != null
          ? () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PledgeReceiptScreen(
                  eventId: eventId,
                  pledgeId: pledgeId,
                ),
              ))
          : null,
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
    final color = (isDark && c.red < 50 && c.green < 50 && c.blue < 50)
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
