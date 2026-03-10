import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/design_tokens.dart';
import '../config/theme.dart';
import '../models/ticket.dart';
import '../providers/ticket_provider.dart';
import '../screens/event/receipts/ticket_receipt_screen.dart';

/// Bottom sheet showing the customer's tickets in a searchable, scrollable list.
/// Mirrors the venue-events sheet pattern from EventMapWidget.
class TicketsBottomSheet extends StatefulWidget {
  const TicketsBottomSheet({super.key});

  @override
  State<TicketsBottomSheet> createState() => _TicketsBottomSheetState();
}

class _TicketsBottomSheetState extends State<TicketsBottomSheet> {
  static const _activeEventStatuses = {'selling_tickets', 'live'};

  List<TicketSale> _tickets = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = context.read<TicketProvider>();
      final result = await repo.getMyTickets(offset: 0, limit: 100);
      if (mounted) {
        setState(() {
          _tickets = result.items
              .where((t) =>
                  t.status == 'purchased' &&
                  _activeEventStatuses.contains(t.eventStatus))
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<TicketSale> get _filtered {
    if (_search.isEmpty) return _tickets;
    final q = _search.toLowerCase();
    return _tickets.where((t) {
      return (t.eventTitle?.toLowerCase().contains(q) ?? false) ||
          (t.tierName?.toLowerCase().contains(q) ?? false) ||
          t.ticketCode.toLowerCase().contains(q) ||
          (t.receiptNumber?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  void _openReceipt(TicketSale ticket) {
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TicketReceiptScreen(
          eventId: ticket.eventId,
          saleId: ticket.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.cardOf(context),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.dividerOf(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                          Icons.confirmation_number_rounded,
                          color: Colors.white,
                          size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Tickets',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: AppTheme.textPrimaryOf(context),
                            ),
                          ),
                          if (!_loading)
                            Text(
                              '${_tickets.length} ticket${_tickets.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondaryOf(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by event, tier, code...',
                    prefixIcon: Icon(Icons.search,
                        size: AppIconSize.md,
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
              ),
              const Divider(height: 1),
              // Ticket list
              Expanded(
                child: _loading
                    ? const Center(
                        child:
                            CircularProgressIndicator(strokeWidth: 2))
                    : _filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _tickets.isEmpty
                                      ? Icons
                                          .confirmation_number_outlined
                                      : Icons.search_off_rounded,
                                  size: 48,
                                  color: AppTheme.textSecondaryOf(
                                      context),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _tickets.isEmpty
                                      ? 'No tickets yet'
                                      : 'No matches',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimaryOf(
                                        context),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _tickets.isEmpty
                                      ? 'Tickets you purchase will appear here'
                                      : 'Try a different search term',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondaryOf(
                                        context),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final ticket = _filtered[index];
                              return _TicketRow(
                                ticket: ticket,
                                onTap: () => _openReceipt(ticket),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TicketRow extends StatelessWidget {
  final TicketSale ticket;
  final VoidCallback onTap;

  const _TicketRow({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(context, ticket.status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.eventTitle ?? 'Event #${ticket.eventId}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (ticket.tierName != null) ...[
                        Text(
                          ticket.tierName!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryOf(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ticket.status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (ticket.receiptNumber != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ticket.receiptNumber!,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondaryOf(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppTheme.textSecondaryOf(context),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(BuildContext context, String status) {
    return switch (status.toLowerCase()) {
      'purchased' => AppTheme.successColor,
      'waitlisted' || 'refund_requested' || 'refund_processing' =>
        AppTheme.warningColor,
      'cancelled' || 'refund_failed' => AppTheme.errorColor,
      'refunded' => AppTheme.accentColor,
      _ => AppTheme.textSecondaryOf(context),
    };
  }
}
