import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../services/api_service.dart';
import '../../../widgets/admin/admin_empty_state.dart';
import 'user_detail_shared.dart';

class UserTicketsTab extends StatefulWidget {
  final int userId;
  final Map<String, dynamic> detail;
  final void Function(String) onSnack;
  final Future<void> Function() onRefresh;
  final bool isOrganizerSales;

  const UserTicketsTab({
    super.key,
    required this.userId,
    required this.detail,
    required this.onSnack,
    required this.onRefresh,
    this.isOrganizerSales = false,
  });

  @override
  State<UserTicketsTab> createState() => _UserTicketsTabState();
}

class _UserTicketsTabState extends State<UserTicketsTab> {
  String _search = '';
  String _statusFilter = 'all';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _allTickets {
    final key = widget.isOrganizerSales ? 'ticket_sales' : 'tickets';
    return (widget.detail[key] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }

  Future<void> _approveTicketRefund(int eventId, int ticketId) async {
    try {
      await context.read<ApiService>().approveTicketRefund(eventId, ticketId);
      widget.onRefresh();
      widget.onSnack('Refund approved');
    } catch (e) {
      widget.onSnack('Failed: ${ApiService.extractError(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTickets = _allTickets;
    final statuses = extractStatuses(allTickets, 'status');
    statuses.addAll(refundTicketStatuses);
    var filtered =
        allTickets.where((t) => matchesTicket(t, _search)).toList();
    if (_statusFilter != 'all') {
      filtered =
          filtered.where((t) => t['status'] == _statusFilter).toList();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: UserDetailSearchField(
            controller: _searchCtrl,
            hint: widget.isOrganizerSales
                ? 'Search by event, attendee, tier...'
                : 'Search by event, tier, status...',
            currentValue: _search,
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        statusChipsWithExtras(
          context,
          statuses: statuses,
          selected: _statusFilter,
          onChanged: (v) => setState(() => _statusFilter = v),
          refundStatuses: refundTicketStatuses,
          allItems: allTickets,
        ),
        countStrip(context, filtered.length, allTickets.length),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: AdminEmptyState(
                      icon: Icons.confirmation_number,
                      message: 'No tickets'))
              : RefreshIndicator(
                  onRefresh: widget.onRefresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _ticketCard(filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _ticketCard(Map<String, dynamic> t) {
    final eventId = t['event_id'] as int;
    final ticketId = t['id'] as int;
    final status = t['status'] as String? ?? '';
    final canApproveRefund = status == 'refund_requested';
    final isRefundRelated = refundTicketStatuses.contains(status);
    final amountCents = t['amount_paid_cents'] as int? ?? 0;
    final subtitle = widget.isOrganizerSales
        ? '${t['attendee_display_name'] ?? 'User'} · ${t['tier_name'] ?? 'Ticket'} · \$${(amountCents / 100).toStringAsFixed(2)}'
        : '${t['tier_name'] ?? 'Ticket'} · \$${(amountCents / 100).toStringAsFixed(2)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: isRefundRelated
            ? Icon(Icons.money_off,
                color: AppTheme.errorOf(context), size: 20)
            : null,
        title: Text(t['event_title'] ?? 'Event #$eventId',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            statusBadge(context, status),
            if (!widget.isOrganizerSales && canApproveRefund) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.check_circle,
                    color: AppTheme.successOf(context)),
                tooltip: 'Approve refund',
                onPressed: () =>
                    _approveTicketRefund(eventId, ticketId),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
