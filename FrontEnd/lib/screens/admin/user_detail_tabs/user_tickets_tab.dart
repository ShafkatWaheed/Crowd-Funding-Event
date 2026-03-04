import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../models/admin.dart';
import '../../../repositories/base_repository.dart';
import '../../../providers/ticket_provider.dart';
import '../../../widgets/admin/admin_empty_state.dart';
import 'user_detail_shared.dart';

class UserTicketsTab extends StatefulWidget {
  final int userId;
  final AdminUserDetail detail;
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

  Future<void> _approveTicketRefund(int eventId, int ticketId) async {
    try {
      await context.read<TicketProvider>().approveTicketRefund(eventId, ticketId);
      widget.onRefresh();
      widget.onSnack('Refund approved');
    } catch (e) {
      widget.onSnack('Failed: ${ApiError.extractMessage(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isOrganizerSales) {
      return _buildSalesView();
    }
    return _buildTicketsView();
  }

  // ── Customer tickets ──

  Widget _buildTicketsView() {
    final allTickets = widget.detail.tickets ?? [];
    final statuses = extractStatusesFrom(allTickets, (t) => t.status);
    statuses.addAll(refundTicketStatuses);
    final counts = countByStatus(allTickets, (t) => t.status);
    var filtered =
        allTickets.where((t) => matchesTicketItem(t, _search)).toList();
    if (_statusFilter != 'all') {
      filtered = filtered.where((t) => t.status == _statusFilter).toList();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: UserDetailSearchField(
            controller: _searchCtrl,
            hint: 'Search by event, tier, status...',
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
          statusCounts: counts,
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
                    itemBuilder: (ctx, i) => _customerTicketCard(filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _customerTicketCard(AdminUserTicket t) {
    final canApproveRefund = t.status == 'refund_requested';
    final isRefundRelated = refundTicketStatuses.contains(t.status);
    final subtitle =
        '${t.tierName ?? 'Ticket'} · \$${(t.amountPaidCents / 100).toStringAsFixed(2)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: isRefundRelated
            ? Icon(Icons.money_off,
                color: AppTheme.errorOf(context), size: 20)
            : null,
        title: Text(t.eventTitle ?? 'Event #${t.eventId}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            statusBadge(context, t.status),
            if (canApproveRefund) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.check_circle,
                    color: AppTheme.successOf(context)),
                tooltip: 'Approve refund',
                onPressed: () =>
                    _approveTicketRefund(t.eventId, t.id),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Organizer ticket sales ──

  Widget _buildSalesView() {
    final allSales = widget.detail.ticketSales ?? [];
    final statuses = extractStatusesFrom(allSales, (t) => t.status);
    statuses.addAll(refundTicketStatuses);
    final counts = countByStatus(allSales, (t) => t.status);
    var filtered =
        allSales.where((t) => matchesTicketSale(t, _search)).toList();
    if (_statusFilter != 'all') {
      filtered = filtered.where((t) => t.status == _statusFilter).toList();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: UserDetailSearchField(
            controller: _searchCtrl,
            hint: 'Search by event, attendee, tier...',
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
          statusCounts: counts,
        ),
        countStrip(context, filtered.length, allSales.length),
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
                    itemBuilder: (ctx, i) => _saleTicketCard(filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _saleTicketCard(AdminUserTicketSale t) {
    final isRefundRelated = refundTicketStatuses.contains(t.status);
    final subtitle =
        '${t.attendeeDisplayName ?? 'User'} · ${t.tierName ?? 'Ticket'} · \$${(t.amountPaidCents / 100).toStringAsFixed(2)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: isRefundRelated
            ? Icon(Icons.money_off,
                color: AppTheme.errorOf(context), size: 20)
            : null,
        title: Text(t.eventTitle ?? 'Event #${t.eventId}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: statusBadge(context, t.status),
      ),
    );
  }
}
