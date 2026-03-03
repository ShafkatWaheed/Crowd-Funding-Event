import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/design_tokens.dart';
import '../../../config/theme.dart';
import '../../../models/funding.dart';
import '../../../providers/pledge_provider.dart';
import '../../../models/ticket.dart';
import '../../../repositories/base_repository.dart';
import '../../../providers/ticket_provider.dart';
import '../../../providers/admin_provider.dart';
import '../../../widgets/admin/admin_empty_state.dart';
import '../../../widgets/admin/admin_search_bar.dart';
import '../admin_shared.dart';

class AdminFinancialTab extends StatefulWidget {
  const AdminFinancialTab({
    super.key,
    this.stats,
    required this.onSnack,
  });

  final Map<String, dynamic>? stats;
  final void Function(String) onSnack;

  @override
  State<AdminFinancialTab> createState() => _AdminFinancialTabState();
}

class _AdminFinancialTabState extends State<AdminFinancialTab> {
  static const _pageSize = 20;
  static const _ticketRefundStatuses = [
    'refund_requested',
    'refund_processing',
    'refunded',
    'refund_failed',
  ];
  static const _pledgeRefundStatuses = [
    'refund_processing',
    'refunded',
    'refund_failed',
  ];

  String _financialSubTab = 'tickets';
  String _financialSearch = '';
  String _escrowSearch = '';
  String _ticketStatusFilter = 'all';
  String _pledgeStatusFilter = 'all';

  List<TicketSale> _adminTickets = [];
  int _ticketsTotal = 0;
  bool _ticketsLoadingMore = false;
  List<Pledge> _adminPledges = [];
  int _pledgesTotal = 0;
  bool _pledgesLoadingMore = false;
  List<dynamic> _escrows = [];
  int _escrowsTotal = 0;
  bool _escrowsLoadingMore = false;

  Timer? _financialSearchDebounce;
  Timer? _escrowSearchDebounce;

  final _ticketsScrollCtrl = ScrollController();
  final _pledgesScrollCtrl = ScrollController();
  final _escrowsScrollCtrl = ScrollController();

  String? get _pledgeApiStatus {
    if (_pledgeStatusFilter == 'all' || _pledgeStatusFilter == '_donation') {
      return null;
    }
    return _pledgeStatusFilter;
  }

  bool? get _pledgeApiDonation {
    if (_pledgeStatusFilter == '_donation') return true;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _ticketsScrollCtrl.addListener(
        () => _onScroll(_ticketsScrollCtrl, _loadMoreTickets));
    _pledgesScrollCtrl.addListener(
        () => _onScroll(_pledgesScrollCtrl, _loadMorePledges));
    _escrowsScrollCtrl.addListener(
        () => _onScroll(_escrowsScrollCtrl, _loadMoreEscrows));
    _reloadFinancialData();
    _reloadEscrowData();
  }

  @override
  void dispose() {
    _financialSearchDebounce?.cancel();
    _escrowSearchDebounce?.cancel();
    _ticketsScrollCtrl.dispose();
    _pledgesScrollCtrl.dispose();
    _escrowsScrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll(ScrollController ctrl, VoidCallback loadMore) {
    if (ctrl.position.pixels >= ctrl.position.maxScrollExtent - 200) {
      loadMore();
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    widget.onSnack(msg);
  }

  void _confirmAction(String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onConfirm();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadTickets() async {
    try {
      final ticketRepo = context.read<TicketProvider>();
      final result = await ticketRepo.adminGetTickets(
        offset: 0,
        limit: _pageSize,
        search: _financialSearch.isEmpty ? null : _financialSearch,
        status: _ticketStatusFilter == 'all' ? null : _ticketStatusFilter,
      );
      if (mounted) {
        setState(() {
          _adminTickets = result.items;
          _ticketsTotal = result.total ?? 0;
        });
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _loadPledges() async {
    try {
      final repo = context.read<PledgeProvider>();
      final result = await repo.adminGetPledges(
        offset: 0,
        limit: _pageSize,
        search: _financialSearch.isEmpty ? null : _financialSearch,
        status: _pledgeApiStatus,
        isDonation: _pledgeApiDonation,
      );
      if (mounted) {
        setState(() {
          _adminPledges = result.items;
          _pledgesTotal = result.total ?? 0;
        });
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _loadEscrowsOnly() async {
    try {
      final admin = context.read<AdminProvider>();
      final data = await admin.getEscrowList(
        offset: 0,
        limit: _pageSize,
        search: _escrowSearch.isNotEmpty ? _escrowSearch : null,
      );
      if (mounted) {
        setState(() {
          _escrows = (data['items'] as List<dynamic>?) ?? [];
          _escrowsTotal = (data['total'] as int?) ?? 0;
        });
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _loadMoreTickets() async {
    if (_ticketsLoadingMore || _adminTickets.length >= _ticketsTotal) return;
    setState(() => _ticketsLoadingMore = true);
    try {
      final ticketRepo = context.read<TicketProvider>();
      final result = await ticketRepo.adminGetTickets(
        offset: _adminTickets.length,
        limit: _pageSize,
        search: _financialSearch.isEmpty ? null : _financialSearch,
        status: _ticketStatusFilter == 'all' ? null : _ticketStatusFilter,
      );
      setState(() {
        _adminTickets.addAll(result.items);
        _ticketsTotal = result.total ?? _ticketsTotal;
      });
    } catch (e) { debugPrint(e.toString()); }
    if (mounted) setState(() => _ticketsLoadingMore = false);
  }

  Future<void> _loadMorePledges() async {
    if (_pledgesLoadingMore || _adminPledges.length >= _pledgesTotal) return;
    setState(() => _pledgesLoadingMore = true);
    try {
      final repo = context.read<PledgeProvider>();
      final result = await repo.adminGetPledges(
        offset: _adminPledges.length,
        limit: _pageSize,
        search: _financialSearch.isEmpty ? null : _financialSearch,
        status: _pledgeApiStatus,
        isDonation: _pledgeApiDonation,
      );
      setState(() {
        _adminPledges.addAll(result.items);
        _pledgesTotal = result.total ?? _pledgesTotal;
      });
    } catch (e) { debugPrint(e.toString()); }
    if (mounted) setState(() => _pledgesLoadingMore = false);
  }

  Future<void> _loadMoreEscrows() async {
    if (_escrowsLoadingMore || _escrows.length >= _escrowsTotal) return;
    setState(() => _escrowsLoadingMore = true);
    try {
      final admin = context.read<AdminProvider>();
      final data = await admin.getEscrowList(
        offset: _escrows.length,
        limit: _pageSize,
        search: _escrowSearch.isNotEmpty ? _escrowSearch : null,
      );
      final items = (data['items'] as List<dynamic>?) ?? [];
      setState(() {
        _escrows.addAll(items);
        _escrowsTotal = (data['total'] as int?) ?? _escrowsTotal;
      });
    } catch (e) { debugPrint(e.toString()); }
    if (mounted) setState(() => _escrowsLoadingMore = false);
  }

  void _onFinancialSearchChanged(String q) {
    _financialSearchDebounce?.cancel();
    _financialSearchDebounce = Timer(
      const Duration(milliseconds: 300),
      () {
        setState(() => _financialSearch = q);
        _reloadFinancialData();
      },
    );
  }

  Future<void> _reloadFinancialData() async {
    final ticketRepo = context.read<TicketProvider>();
    final fundingRepo = context.read<PledgeProvider>();
    try {
      final search = _financialSearch.isEmpty ? null : _financialSearch;
      final ticketsResult = await ticketRepo.adminGetTickets(
        offset: 0,
        limit: _pageSize,
        search: search,
        status: _ticketStatusFilter == 'all' ? null : _ticketStatusFilter,
      );
      final pledgesResult = await fundingRepo.adminGetPledges(
        offset: 0,
        limit: _pageSize,
        search: search,
        status: _pledgeApiStatus,
        isDonation: _pledgeApiDonation,
      );
      if (mounted) {
        setState(() {
          _adminTickets = ticketsResult.items;
          _ticketsTotal = ticketsResult.total ?? 0;
          _adminPledges = pledgesResult.items;
          _pledgesTotal = pledgesResult.total ?? 0;
        });
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  void _onEscrowSearchChanged(String q) {
    _escrowSearchDebounce?.cancel();
    _escrowSearchDebounce = Timer(
      const Duration(milliseconds: 300),
      () {
        setState(() => _escrowSearch = q);
        _reloadEscrowData();
      },
    );
  }

  Future<void> _reloadEscrowData() async {
    final admin = context.read<AdminProvider>();
    try {
      final data = await admin.getEscrowList(
        offset: 0,
        limit: _pageSize,
        search: _escrowSearch.isNotEmpty ? _escrowSearch : null,
      );
      if (mounted) {
        setState(() {
          _escrows = (data['items'] as List<dynamic>?) ?? [];
          _escrowsTotal = (data['total'] as int?) ?? 0;
        });
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _escrowAction(int eventId, String action, {int? stage}) async {
    try {
      final admin = context.read<AdminProvider>();
      await admin.escrowAction(eventId, action, stage: stage);
      _loadEscrowsOnly();
      _snack('Escrow action completed');
    } catch (e) {
      _snack('Escrow action failed: ${ApiError.extractMessage(e)}');
    }
  }

  String _formatFilterStatus(String s) {
    return statusLabel(s);
  }

  Future<void> _refreshAll() async {
    await _reloadFinancialData();
    await _reloadEscrowData();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'tickets',
                label: Text('Tickets ($_ticketsTotal)'),
              ),
              ButtonSegment(
                value: 'pledges',
                label: Text('Pledges ($_pledgesTotal)'),
              ),
              ButtonSegment(
                value: 'escrow',
                label: Text('Escrow ($_escrowsTotal)'),
              ),
            ],
            selected: {_financialSubTab},
            onSelectionChanged: (s) {
              setState(() {
                _financialSubTab = s.first;
                _financialSearch = '';
                _escrowSearch = '';
                _ticketStatusFilter = 'all';
                _pledgeStatusFilter = 'all';
              });
              _reloadFinancialData();
              _reloadEscrowData();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: AdminSearchBar(
            hint: _financialSubTab == 'tickets'
                ? 'Search by event, attendee, or tier...'
                : _financialSubTab == 'pledges'
                    ? 'Search by event or user...'
                    : 'Search by event name or ID...',
            onChanged: _financialSubTab == 'escrow'
                ? _onEscrowSearchChanged
                : _onFinancialSearchChanged,
          ),
        ),
        if (_financialSubTab == 'tickets') _buildTicketFilterChips(),
        if (_financialSubTab == 'pledges') _buildPledgeFilterChips(),
        _financialSummary(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshAll,
            child: _financialSubTab == 'tickets'
                ? _buildTicketsList()
                : _financialSubTab == 'pledges'
                    ? _buildPledgesList()
                    : _buildEscrowList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTicketFilterChips() {
    const regular = ['purchased', 'waitlisted', 'cancelled'];
    final selected = _ticketStatusFilter;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All'),
              selected: selected == 'all',
              onSelected: (_) {
                setState(() => _ticketStatusFilter = 'all');
                _reloadFinancialData();
              },
            ),
          ),
          ...regular.map(
            (s) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_formatFilterStatus(s)),
                selected: selected == s,
                onSelected: (_) {
                  setState(() => _ticketStatusFilter = s);
                  _reloadFinancialData();
                },
              ),
            ),
          ),
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: AppTheme.dividerOf(context),
          ),
          ..._ticketRefundStatuses.map(
            (s) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: Icon(
                  Icons.money_off,
                  size: 16,
                  color:
                      selected == s ? null : AppTheme.errorOf(context),
                ),
                label: Text(_formatFilterStatus(s)),
                selected: selected == s,
                onSelected: (_) {
                  setState(() => _ticketStatusFilter = s);
                  _reloadFinancialData();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPledgeFilterChips() {
    const regular = ['pledged', 'collected'];
    final selected = _pledgeStatusFilter;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All'),
              selected: selected == 'all',
              onSelected: (_) {
                setState(() => _pledgeStatusFilter = 'all');
                _reloadFinancialData();
              },
            ),
          ),
          ...regular.map(
            (s) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_formatFilterStatus(s)),
                selected: selected == s,
                onSelected: (_) {
                  setState(() => _pledgeStatusFilter = s);
                  _reloadFinancialData();
                },
              ),
            ),
          ),
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: AppTheme.dividerOf(context),
          ),
          ..._pledgeRefundStatuses.map(
            (s) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: Icon(
                  Icons.money_off,
                  size: 16,
                  color:
                      selected == s ? null : AppTheme.errorOf(context),
                ),
                label: Text(_formatFilterStatus(s)),
                selected: selected == s,
                onSelected: (_) {
                  setState(() => _pledgeStatusFilter = s);
                  _reloadFinancialData();
                },
              ),
            ),
          ),
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: AppTheme.dividerOf(context),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(
                Icons.card_giftcard,
                size: 16,
                color:
                    selected == '_donation' ? null : AppTheme.warningOf(context),
              ),
              label: const Text('Donations'),
              selected: selected == '_donation',
              onSelected: (_) {
                setState(() => _pledgeStatusFilter =
                    selected == '_donation' ? 'all' : '_donation');
                _reloadFinancialData();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _financialSummary() {
    if (_financialSubTab == 'tickets') {
      final totalRevenue = _adminTickets.fold<int>(
          0, (sum, t) => sum + t.amountPaidCents);
      final refundRequested =
          _adminTickets.where((t) => t.status == 'refund_requested').length;
      return _summaryStrip([
        'Total sold: ${_adminTickets.length}',
        'Refund requested: $refundRequested',
        'Revenue: ${centsToStr(totalRevenue)}',
      ]);
    } else if (_financialSubTab == 'pledges') {
      final totalAmount = _adminPledges.fold<int>(
          0, (sum, p) => sum + p.amountCents);
      final guests =
          _adminPledges.where((p) => p.isGuest).length;
      return _summaryStrip([
        'Total pledges: ${_adminPledges.length}',
        'Total: ${centsToStr(totalAmount)}',
        'Guests: $guests',
      ]);
    } else {
      final totalHeld = _escrows.fold<int>(
          0, (sum, e) => sum + ((e['total_held_cents'] as int?) ?? 0));
      final totalReleased = _escrows.fold<int>(
          0, (sum, e) => sum + ((e['total_released_cents'] as int?) ?? 0));
      final frozenCount =
          _escrows.where((e) => e['status'] == 'frozen').length;
      return _summaryStrip([
        'Held: ${centsToStr(totalHeld)}',
        'Released: ${centsToStr(totalReleased)}',
        'Frozen: $frozenCount',
      ]);
    }
  }

  Widget _summaryStrip(List<String> items) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: AppRadius.sm,
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: items
            .map(
              (item) => Text(
                item,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTicketsList() {
    final tickets = _adminTickets;
    if (tickets.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: 300,
          child: AdminEmptyState(
            icon: Icons.confirmation_number,
            message: 'No tickets found',
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _ticketsScrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: tickets.length + (_ticketsLoadingMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i >= tickets.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final t = tickets[i];
        final eventId = t.eventId;
        final ticketId = t.id;
        final status = t.status;
        final amountCents = t.amountPaidCents;
        final canApproveRefund = status == 'refund_requested';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(
              t.eventTitle ?? 'Event #$eventId',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${t.attendeeDisplayName ?? 'User #${t.userId}'} • ${t.tierName ?? 'Ticket'} • ${centsToStr(amountCents)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                statusChip(
                  context,
                  status.toUpperCase().replaceAll('_', ' '),
                  ticketStatusColor(context, status),
                ),
                if (canApproveRefund) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.check_circle,
                      color: AppTheme.successOf(context),
                    ),
                    tooltip: 'Approve refund',
                    onPressed: () => _confirmAction(
                      'Approve Refund',
                      'Approve refund for this ticket?',
                      () async {
                        await context
                            .read<TicketProvider>()
                            .approveTicketRefund(eventId, ticketId);
                        _loadTickets();
                        _snack('Refund approved');
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPledgesList() {
    final pledges = _adminPledges;
    if (pledges.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: 300,
          child: AdminEmptyState(
            icon: Icons.volunteer_activism,
            message: 'No pledges found',
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _pledgesScrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: pledges.length + (_pledgesLoadingMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i >= pledges.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final p = pledges[i];
        final eventId = p.eventId;
        final fundingId = p.id;
        final amountCents = p.amountCents;
        final isGuest = p.isGuest;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(
              p.eventTitle ?? 'Event #$eventId',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${p.userDisplayName ?? (isGuest ? 'Guest' : 'User #${p.userId}')} • ${centsToStr(amountCents)}${isGuest ? ' (donation)' : ''}',
            ),
            trailing: FilledButton.tonal(
              onPressed: () => _confirmAction(
                'Refund Pledge',
                'Are you sure you want to refund this pledge of ${centsToStr(amountCents)}?',
                () async {
                  await context
                      .read<PledgeProvider>()
                      .adminRefundPledge(eventId, fundingId);
                  _loadPledges();
                  _snack('Pledge refunded');
                },
              ),
              child: const Text('Refund'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEscrowList() {
    if (_escrows.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: 300,
          child: AdminEmptyState(
            icon: Icons.account_balance,
            message: 'No escrows yet',
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _escrowsScrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _escrows.length + (_escrowsLoadingMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i >= _escrows.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _escrowCard(_escrows[i]);
      },
    );
  }

  Widget _escrowCard(Map<String, dynamic> e) {
    final eventId = e['event_id'] ?? 0;
    final eventTitle = e['event_title'] as String? ?? 'Event #$eventId';
    final organizerName = e['organizer_name'] as String?;
    final organizerEmail = e['organizer_email'] as String? ?? '';
    final totalHeld = (e['total_held_cents'] ?? 0) as int;
    final totalReleased = (e['total_released_cents'] ?? 0) as int;
    final remaining = (e['remaining_cents'] ?? 0) as int;
    final status = e['status'] ?? 'holding';
    final s1 = e['stage1_released_at'];
    final s2 = e['stage2_released_at'];
    final s3 = e['stage3_released_at'];
    final isFrozen = status == 'frozen';
    final statusColor = escrowStatusColor(context, status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance, size: 20, color: statusColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eventTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Event #$eventId',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                statusChip(
                  context,
                  status.toUpperCase().replaceAll('_', ' '),
                  statusColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 16,
                  color: AppTheme.textSecondaryOf(context),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${organizerName ?? 'Unknown'} · $organizerEmail',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                escrowStat(
                  context,
                  'Held',
                  totalHeld,
                  AppTheme.textSecondaryOf(context),
                ),
                const SizedBox(width: 16),
                escrowStat(
                  context,
                  'Released',
                  totalReleased,
                  AppTheme.successOf(context),
                ),
                const SizedBox(width: 16),
                escrowStat(
                  context,
                  'Remaining',
                  remaining,
                  context.fundingAccent,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                escrowStageDot(context, 'S1', s1 != null, context.feedAccent),
                stageLine(context, s1 != null && s2 != null),
                escrowStageDot(
                  context,
                  'S2',
                  s2 != null,
                  context.fundingAccent,
                ),
                stageLine(context, s2 != null && s3 != null),
                escrowStageDot(
                  context,
                  'S3',
                  s3 != null,
                  AppTheme.successOf(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (s1 == null)
                  escrowBtn(
                    'Release S1',
                    Icons.looks_one,
                    context.feedAccent,
                    () => _confirmAction(
                      'Release Stage 1',
                      'Release Stage 1 escrow?',
                      () => _escrowAction(eventId as int, 'release', stage: 1),
                    ),
                  ),
                if (s1 != null && s2 == null)
                  escrowBtn(
                    'Release S2',
                    Icons.looks_two,
                    context.fundingAccent,
                    () => _confirmAction(
                      'Release Stage 2',
                      'Release Stage 2 escrow?',
                      () => _escrowAction(eventId as int, 'release', stage: 2),
                    ),
                  ),
                if (s2 != null && s3 == null)
                  escrowBtn(
                    'Release S3',
                    Icons.looks_3,
                    AppTheme.successOf(context),
                    () => _confirmAction(
                      'Release Stage 3',
                      'Release Stage 3 escrow?',
                      () => _escrowAction(eventId as int, 'release', stage: 3),
                    ),
                  ),
                if (!isFrozen)
                  escrowBtn(
                    'Freeze',
                    Icons.ac_unit,
                    AppTheme.errorOf(context),
                    () => _confirmAction(
                      'Freeze Escrow',
                      'Freeze this escrow?',
                      () => _escrowAction(eventId as int, 'freeze'),
                    ),
                  )
                else
                  escrowBtn(
                    'Unfreeze',
                    Icons.wb_sunny,
                    context.ticketAccent,
                    () => _confirmAction(
                      'Unfreeze Escrow',
                      'Unfreeze this escrow?',
                      () => _escrowAction(eventId as int, 'unfreeze'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
