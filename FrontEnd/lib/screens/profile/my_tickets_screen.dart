import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/design_tokens.dart';
import '../../utils/date_time_utils.dart';
import '../../config/theme.dart';
import '../../widgets/loading_switcher.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../models/ticket.dart';
import '../../providers/auth_provider.dart';
import '../../db/app_database.dart';
import '../../services/api_service.dart';
import '../../services/sync_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/animated_list_item.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/share_bottom_sheet.dart';
import '../event/ticket_receipt_screen.dart';

/// Screen for customers to view all their purchased tickets, grouped by event.
/// Each ticket card shows key info and tapping opens the full receipt.
/// If [filterEventId] is provided, only tickets for that event are shown.
class MyTicketsScreen extends StatefulWidget {
  final int? filterEventId;

  const MyTicketsScreen({super.key, this.filterEventId});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  static const _pageSize = 20;

  final _scrollCtrl = ScrollController();
  List<TicketSale> _tickets = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  String _search = '';
  String _filterStatus = 'all';
  bool _isOffline = false;

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
    if (user == null || !user.isCustomer) {
      if (mounted) setState(() { _loading = false; _error = 'Only customers can view tickets'; });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _hasMore = true;
      _isOffline = false;
    });
    try {
      final api = context.read<ApiService>();
      final data = await api.getMyTickets(offset: 0, limit: _pageSize);
      if (mounted) {
        setState(() {
          _tickets = data.map((e) => TicketSale.fromJson(e)).toList();
          _hasMore = data.length >= _pageSize;
          _loading = false;
        });
        // Background-cache tickets for offline use
        context.read<SyncService>().pullMyTickets();
      }
    } catch (e) {
      // Try loading from offline cache
      await _loadFromCache();
      if (mounted && _tickets.isEmpty) {
        setState(() {
          _error = ApiService.extractError(e, fallback: 'Failed to load tickets');
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final db = context.read<AppDatabase>();
      final rows = await db.getMyTicketsFromCache();
      if (mounted && rows.isNotEmpty) {
        setState(() {
          _tickets = rows.map(_cachedRowToTicketSale).toList();
          _hasMore = false;
          _isOffline = true;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load tickets from cache: $e');
    }
  }

  TicketSale _cachedRowToTicketSale(CachedMyTicket row) {
    return TicketSale(
      id: row.id,
      eventId: row.eventId,
      userId: row.userId,
      ticketTierId: 0,
      ticketCode: row.ticketCode,
      receiptNumber: row.receiptNumber,
      tierName: row.tierName,
      eventTitle: row.eventTitle,
      amountPaidCents: row.amountPaidCents,
      discountAppliedCents: row.discountAppliedCents,
      status: row.status,
      scannedAt: row.scannedAt,
      encryptedQrPayload: row.encryptedQrPayload,
      createdAt: row.createdAt,
    );
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final api = context.read<ApiService>();
      final data = await api.getMyTickets(offset: _tickets.length, limit: _pageSize);
      if (mounted) {
        setState(() {
          _tickets.addAll(data.map((e) => TicketSale.fromJson(e)));
          _hasMore = data.length >= _pageSize;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// Tickets scoped to the event only (no status/search filters).
  /// Used for aggregate stats (Total, Active, etc.) so they reflect the
  /// full event context even when the user applies search or status filters.
  List<TicketSale> get _eventScoped {
    if (widget.filterEventId == null) return _tickets;
    return _tickets.where((t) => t.eventId == widget.filterEventId).toList();
  }

  List<TicketSale> get _filtered {
    var list = _eventScoped;

    // Status filter
    if (_filterStatus == 'refund_pending') {
      list = list.where((t) => t.status == 'refund_requested' || t.status == 'refund_processing').toList();
    } else if (_filterStatus != 'all') {
      list = list.where((t) => t.status == _filterStatus).toList();
    }

    // Text search
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((t) {
        return (t.eventTitle?.toLowerCase().contains(q) ?? false) ||
            (t.tierName?.toLowerCase().contains(q) ?? false) ||
            t.ticketCode.toLowerCase().contains(q) ||
            (t.receiptNumber?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    return list;
  }

  /// Group filtered tickets by event, keeping insertion order.
  Map<int, List<TicketSale>> get _groupedByEvent {
    final map = <int, List<TicketSale>>{};
    for (final t in _filtered) {
      map.putIfAbsent(t.eventId, () => []).add(t);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceOf(context),
      appBar: AppBar(
        title: Text(widget.filterEventId != null
            ? 'Event Tickets'
            : 'My Tickets'),
      ),
      body: LoadingSwitcher(
        loading: _loading,
        loadingChild: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Column(
            children: List.generate(4, (_) => const ShimmerListTile()),
          ),
        ),
        child: _error != null
            ? ErrorState(message: _error!, onRetry: _load)
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final grouped = _groupedByEvent;
    // Stats always reflect event-scoped totals (not affected by search/status filter)
    final statsTickets = _eventScoped;
    final purchasedCount = statsTickets.where((t) => t.status == 'purchased').length;
    final refundPendingCount = statsTickets.where((t) => t.status == 'refund_requested' || t.status == 'refund_processing').length;
    final waitlistedCount = statsTickets.where((t) => t.status == 'waitlisted').length;
    final refundedCount = statsTickets.where((t) => t.status == 'refunded').length;
    final cancelledCount = statsTickets.where((t) => t.status == 'cancelled').length;
    final scannedCount = statsTickets.where((t) => t.isScanned).length;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primaryColor,
      child: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          // ── Offline banner ──
          if (_isOffline)
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2),
                color: Colors.orange.shade700,
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off_rounded,
                        size: 16, color: Colors.white),
                    AppSpacing.hSm,
                    Expanded(
                      child: Text(
                        "You're offline — showing cached tickets",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Stats summary ──
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.cardOf(context),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _statChip(
                          Icons.confirmation_number_rounded,
                          '${statsTickets.length}',
                          'Total',
                        ),
                        AppSpacing.hMd,
                        _statChip(
                          Icons.check_circle_rounded,
                          '$purchasedCount',
                          'Active',
                          color: AppTheme.successColor,
                        ),
                        if (refundPendingCount > 0) ...[
                          AppSpacing.hMd,
                          _statChip(
                            Icons.hourglass_top_rounded,
                            '$refundPendingCount',
                            'Pending',
                            color: AppTheme.warningColor,
                          ),
                        ],
                        if (refundedCount > 0) ...[
                          AppSpacing.hMd,
                          _statChip(
                            Icons.check_circle_outline_rounded,
                            '$refundedCount',
                            'Refunded',
                            color: AppTheme.accentColor,
                          ),
                        ],
                        if (waitlistedCount > 0) ...[
                          AppSpacing.hMd,
                          _statChip(
                            Icons.hourglass_top_rounded,
                            '$waitlistedCount',
                            'Waitlist',
                            color: AppTheme.warningColor,
                          ),
                        ],
                        if (cancelledCount > 0) ...[
                          AppSpacing.hMd,
                          _statChip(
                            Icons.cancel_rounded,
                            '$cancelledCount',
                            'Cancelled',
                            color: AppTheme.errorColor,
                          ),
                        ],
                        if (scannedCount > 0) ...[
                          AppSpacing.hMd,
                          _statChip(
                            Icons.qr_code_scanner_rounded,
                            '$scannedCount',
                            'Scanned',
                            color: context.ticketAccent,
                          ),
                        ],
                      ],
                    ),
                  ),
                  AppSpacing.vMd,

                  // Search bar
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by event, tier, code...',
                      prefixIcon: Icon(Icons.search, size: AppIconSize.md,
                          color: AppTheme.textSecondaryOf(context)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm + 2),
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

                  // Filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip('All', 'all'),
                        AppSpacing.hSm,
                        _filterChip('Purchased', 'purchased'),
                        AppSpacing.hSm,
                        _filterChip('Refund Pending', 'refund_pending'),
                        AppSpacing.hSm,
                        _filterChip('Waitlisted', 'waitlisted'),
                        AppSpacing.hSm,
                        _filterChip('Refunded', 'refunded'),
                        AppSpacing.hSm,
                        _filterChip('Cancelled', 'cancelled'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Grouped Ticket List ──
          if (grouped.isEmpty)
            SliverFillRemaining(
              child: _tickets.isEmpty
                  ? EmptyState(
                      icon: Icons.confirmation_number_outlined,
                      title: 'No tickets yet',
                      subtitle: 'Tickets you purchase will appear here',
                    )
                  : EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No matches',
                      subtitle: 'Try a different search or filter',
                    ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                100,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final eventId = grouped.keys.elementAt(index);
                    final tickets = grouped[eventId]!;
                    final eventTitle = tickets.first.eventTitle ?? 'Event #$eventId';
                    final scannedInGroup = tickets.where((t) => t.isScanned).length;
                    return AnimatedListItem(
                      index: index,
                      child: _EventTicketGroup(
                        eventId: eventId,
                        eventTitle: eventTitle,
                        tickets: tickets,
                        scannedCount: scannedInGroup,
                        onTicketTap: _openReceipt,
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

  void _openReceipt(TicketSale ticket) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TicketReceiptScreen(
          eventId: ticket.eventId,
          saleId: ticket.id,
          offlineTicket: _isOffline ? ticket : null,
        ),
      ),
    );
  }


  Widget _statChip(IconData icon, String value, String label, {Color? color}) {
    final c = color ?? AppTheme.textPrimaryOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md + 2, vertical: AppSpacing.sm),
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: c,
                  )),
              Text(label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: c.withValues(alpha: 0.7),
                  )),
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

// ═══════════════════════════════════════════════════════
// Event Ticket Group Widget
// ═══════════════════════════════════════════════════════

class _EventTicketGroup extends StatelessWidget {
  final int eventId;
  final String eventTitle;
  final List<TicketSale> tickets;
  final int scannedCount;
  final void Function(TicketSale) onTicketTap;
  final VoidCallback onEventTap;

  const _EventTicketGroup({
    required this.eventId,
    required this.eventTitle,
    required this.tickets,
    required this.scannedCount,
    required this.onTicketTap,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event header
          GestureDetector(
            onTap: onEventTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md + 2, vertical: AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                borderRadius: AppRadius.md,
                border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: AppRadius.sm,
                    ),
                    child: const Icon(Icons.event_rounded,
                        size: 18, color: AppTheme.primaryColor),
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
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppTheme.textPrimaryOf(context))),
                        AppSpacing.vXs,
                        Text(
                          '${tickets.length} ticket${tickets.length == 1 ? '' : 's'}'
                          '${scannedCount > 0 ? ' \u2022 $scannedCount scanned' : ''}',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryOf(context)),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: AppTheme.textSecondaryOf(context), size: AppIconSize.md),
                ],
              ),
            ),
          ),
          AppSpacing.vSm,
          // Ticket cards
          ...tickets.map((ticket) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
                child: _TicketCard(
                  ticket: ticket,
                  onTap: () => onTicketTap(ticket),
                ),
              )),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Ticket Card Widget
// ═══════════════════════════════════════════════════════

class _TicketCard extends StatelessWidget {
  final TicketSale ticket;
  final VoidCallback onTap;

  const _TicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isFree = ticket.amountPaidCents == 0;
    final statusColor = _statusColor(context, ticket.status);
    final isDark = AppTheme.isDark(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: AppRadius.lg,
          boxShadow: AppShadow.card(isDark),
        ),
        child: Column(
          children: [
            // ── Header with event title + status ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md + 2,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: AppRadius.topLg,
              ),
              child: Row(
                children: [
                  // Ticket icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: AppRadius.sm,
                    ),
                    child: const Icon(Icons.confirmation_number_rounded,
                        color: Colors.white, size: 20),
                  ),
                  AppSpacing.hMd,
                  // Event title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket.eventTitle ?? 'Event #${ticket.eventId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (ticket.tierName != null) ...[
                          AppSpacing.vXs,
                          Text(
                            ticket.tierName!,
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
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: AppRadius.pill,
                      border: Border.all(
                          color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      ticket.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor == AppTheme.warningColor
                            ? Colors.white
                            : statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Dashed divider effect ──
            Container(
              width: double.infinity,
              height: 1,
              color: AppTheme.dividerOf(context),
            ),

            // ── Body ──
            Padding(
              padding: AppSpacing.paddingLg,
              child: Column(
                children: [
                  // Info rows
                  _infoRow(
                    Icons.receipt_outlined,
                    'Receipt',
                    ticket.receiptNumber ?? '—',
                  ),
                  AppSpacing.vSm,
                  _infoRow(
                    Icons.qr_code_rounded,
                    'Code',
                    ticket.ticketCode,
                    copyable: true,
                  ),
                  AppSpacing.vSm,
                  _infoRow(
                    Icons.calendar_today_rounded,
                    'Purchased',
                    AppDateFormat.shortDateTime(ticket.createdAt),
                  ),
                  if (ticket.isScanned) ...[
                    AppSpacing.vSm,
                    _infoRow(
                      Icons.verified_rounded,
                      'Scanned',
                      AppDateFormat.shortDateTime(ticket.scannedAt!),
                      valueColor: AppTheme.successColor,
                    ),
                  ],

                  AppSpacing.vMd,

                  // ── Price + View Receipt button ──
                  Row(
                    children: [
                      // Price
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm - 2),
                        decoration: BoxDecoration(
                          color: isFree
                              ? AppTheme.successColor.withValues(alpha: 0.1)
                              : AppTheme.accentColor.withValues(alpha: 0.1),
                          borderRadius: AppRadius.sm,
                        ),
                        child: Text(
                          isFree ? 'FREE' : ticket.amountPaidFormatted,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isFree
                                ? AppTheme.successColor
                                : AppTheme.accentColor,
                          ),
                        ),
                      ),
                      if (ticket.discountAppliedCents > 0) ...[
                        AppSpacing.hSm,
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withValues(alpha: 0.08),
                            borderRadius: AppRadius.sm,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_offer_rounded,
                                  size: 12, color: AppTheme.successColor),
                              AppSpacing.hXs,
                              Text(
                                '-\$${(ticket.discountAppliedCents / 100).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.successColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (ticket.status == 'purchased')
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: GestureDetector(
                            onTap: () => showTicketShareSheet(context, ticket),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.08),
                                borderRadius: AppRadius.sm,
                              ),
                              child: Icon(Icons.share_rounded,
                                  size: 16, color: AppTheme.textSecondaryOf(context)),
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md + 2,
                            vertical: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: AppRadius.sm,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_rounded,
                                size: AppIconSize.sm, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'View Receipt',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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

  Widget _infoRow(IconData icon, String label, String value,
      {bool copyable = false, Color? valueColor}) {
    return Builder(builder: (context) {
      return Row(
        children: [
          Icon(icon, size: AppIconSize.sm, color: AppTheme.textSecondaryOf(context)),
          AppSpacing.hSm,
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryOf(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppTheme.textPrimaryOf(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                AppToast.info(context, 'Copied to clipboard');
              },
              child: Icon(Icons.copy_rounded,
                  size: 14, color: AppTheme.textSecondaryOf(context)),
            ),
        ],
      );
    });
  }

  Color _statusColor(BuildContext context, String status) {
    switch (status.toLowerCase()) {
      case 'purchased':
        return AppTheme.successColor;
      case 'waitlisted':
      case 'refund_requested':
      case 'refund_processing':
        return AppTheme.warningColor;
      case 'cancelled':
      case 'refund_failed':
        return AppTheme.errorColor;
      case 'refunded':
        return AppTheme.accentColor;
      default:
        return AppTheme.textSecondaryOf(context);
    }
  }
}
