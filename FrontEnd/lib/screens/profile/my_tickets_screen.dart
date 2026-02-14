import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/ticket.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';
import '../event/ticket_receipt_screen.dart';
import '../event/purchase_group_receipt_screen.dart';

/// Screen for customers to view all their purchased tickets, grouped by event.
/// Each ticket card shows key info and tapping opens the full receipt.
class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  List<TicketSale> _tickets = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String _filterStatus = 'all'; // all, purchased, waitlisted, cancelled

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final data = await api.getMyTickets();
      if (mounted) {
        setState(() {
          _tickets = data.map((e) => TicketSale.fromJson(e)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ApiService.extractError(e, fallback: 'Failed to load tickets');
          _loading = false;
        });
      }
    }
  }

  List<TicketSale> get _filtered {
    var list = _tickets;

    // Status filter
    if (_filterStatus != 'all') {
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
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(title: const Text('My Tickets')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final grouped = _groupedByEvent;
    final purchasedCount = _tickets.where((t) => t.status == 'purchased').length;
    final waitlistedCount = _tickets.where((t) => t.status == 'waitlisted').length;
    final scannedCount = _tickets.where((t) => t.isScanned).length;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primaryColor,
      child: CustomScrollView(
        slivers: [
          // ── Stats summary ──
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats chips
                  Row(
                    children: [
                      _statChip(
                        Icons.confirmation_number_rounded,
                        '${_tickets.length}',
                        'Total',
                      ),
                      const SizedBox(width: 10),
                      _statChip(
                        Icons.check_circle_rounded,
                        '$purchasedCount',
                        'Active',
                        color: AppTheme.successColor,
                      ),
                      if (waitlistedCount > 0) ...[
                        const SizedBox(width: 10),
                        _statChip(
                          Icons.hourglass_top_rounded,
                          '$waitlistedCount',
                          'Waitlist',
                          color: AppTheme.warningColor,
                        ),
                      ],
                      if (scannedCount > 0) ...[
                        const SizedBox(width: 10),
                        _statChip(
                          Icons.qr_code_scanner_rounded,
                          '$scannedCount',
                          'Scanned',
                          color: Colors.teal,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Search bar
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by event, tier, code...',
                      prefixIcon: const Icon(Icons.search, size: 20,
                          color: AppTheme.textSecondary),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      filled: true,
                      fillColor: AppTheme.surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                  const SizedBox(height: 12),

                  // Filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip('All', 'all'),
                        const SizedBox(width: 8),
                        _filterChip('Purchased', 'purchased'),
                        const SizedBox(width: 8),
                        _filterChip('Waitlisted', 'waitlisted'),
                        const SizedBox(width: 8),
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
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.confirmation_number_outlined,
                          size: 40, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _tickets.isEmpty ? 'No tickets yet' : 'No matches',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _tickets.isEmpty
                          ? 'Tickets you purchase will appear here'
                          : 'Try a different search or filter',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final eventId = grouped.keys.elementAt(index);
                    final tickets = grouped[eventId]!;
                    final eventTitle = tickets.first.eventTitle ?? 'Event #$eventId';
                    final scannedInGroup = tickets.where((t) => t.isScanned).length;
                    return _EventTicketGroup(
                      eventId: eventId,
                      eventTitle: eventTitle,
                      tickets: tickets,
                      scannedCount: scannedInGroup,
                      onTicketTap: _openReceipt,
                      onEventTap: () => context.push('/events/$eventId'),
                    );
                  },
                  childCount: grouped.length,
                ),
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
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: (color ?? AppTheme.primaryColor).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color ?? AppTheme.primaryColor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color ?? AppTheme.primaryColor,
                  )),
              Text(label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: (color ?? AppTheme.primaryColor).withValues(alpha: 0.7),
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
      backgroundColor: Colors.white,
      side: BorderSide(
        color: active ? AppTheme.primaryColor : AppTheme.dividerColor,
      ),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: active ? Colors.white : AppTheme.textPrimary,
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
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event header
          GestureDetector(
            onTap: onEventTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.event_rounded,
                        size: 18, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(eventTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(
                          '${tickets.length} ticket${tickets.length == 1 ? '' : 's'}'
                          '${scannedCount > 0 ? ' \u2022 $scannedCount scanned' : ''}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: AppTheme.textSecondary, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Ticket cards
          ...tickets.map((ticket) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
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
    final dateFmt = DateFormat('MMM d, yyyy \u2022 h:mm a');
    final isFree = ticket.amountPaidCents == 0;
    final statusColor = _statusColor(ticket.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Header with event title + status ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  // Ticket icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.confirmation_number_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
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
                          const SizedBox(height: 2),
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
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
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
              color: AppTheme.dividerColor,
            ),

            // ── Body ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Info rows
                  _infoRow(
                    Icons.receipt_outlined,
                    'Receipt',
                    ticket.receiptNumber ?? '—',
                  ),
                  const SizedBox(height: 8),
                  _infoRow(
                    Icons.qr_code_rounded,
                    'Code',
                    ticket.ticketCode,
                    copyable: true,
                    context: context,
                  ),
                  const SizedBox(height: 8),
                  _infoRow(
                    Icons.calendar_today_rounded,
                    'Purchased',
                    dateFmt.format(ticket.createdAt.toLocal()),
                  ),
                  if (ticket.isScanned) ...[
                    const SizedBox(height: 8),
                    _infoRow(
                      Icons.verified_rounded,
                      'Scanned',
                      dateFmt.format(ticket.scannedAt!.toLocal()),
                      valueColor: AppTheme.successColor,
                    ),
                  ],

                  const SizedBox(height: 12),

                  // ── Price + View Receipt button ──
                  Row(
                    children: [
                      // Price
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isFree
                              ? AppTheme.successColor.withValues(alpha: 0.1)
                              : AppTheme.accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
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
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_offer_rounded,
                                  size: 12, color: AppTheme.successColor),
                              const SizedBox(width: 4),
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
                      // View Receipt button
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_rounded,
                                size: 16, color: Colors.white),
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
      {bool copyable = false, BuildContext? context, Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
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
              color: valueColor ?? AppTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (copyable && context != null)
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              AppToast.info(context, 'Copied to clipboard');
            },
            child: Icon(Icons.copy_rounded, size: 14, color: Colors.grey[400]),
          ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'purchased':
        return AppTheme.successColor;
      case 'waitlisted':
        return AppTheme.warningColor;
      case 'cancelled':
        return AppTheme.errorColor;
      default:
        return Colors.grey;
    }
  }
}
