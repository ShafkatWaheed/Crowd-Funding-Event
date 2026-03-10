import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/ticket.dart';
import '../../utils/date_time_utils.dart';
import '../../config/design_tokens.dart';
import '../../providers/ticket_provider.dart';
import '../../widgets/app_toast.dart';

class RefundRequestsScreen extends StatefulWidget {
  final int eventId;
  const RefundRequestsScreen({super.key, required this.eventId});

  @override
  State<RefundRequestsScreen> createState() => _RefundRequestsScreenState();
}

class _RefundRequestsScreenState extends State<RefundRequestsScreen> {
  List<TicketSale> _requests = [];
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = context.read<TicketProvider>();
      final data = await repo.getRefundRequests(widget.eventId);
      if (mounted) setState(() { _requests = data; _loading = false; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _approve(int ticketId) async {
    try {
      final repo = context.read<TicketProvider>();
      await repo.approveTicketRefund(widget.eventId, ticketId);
      if (mounted) {
        AppToast.success(context, 'Refund approved');
        _load();
      }
    } catch (e) {
      if (mounted) AppToast.fromError(context, e, fallback: 'Approve failed');
    }
  }

  Future<void> _reject(int ticketId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Refund'),
        content: const Text('The ticket will be restored to purchased status.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final repo = context.read<TicketProvider>();
      await repo.rejectTicketRefund(widget.eventId, ticketId);
      if (mounted) {
        AppToast.success(context, 'Refund rejected — ticket restored');
        _load();
      }
    } catch (e) {
      if (mounted) AppToast.fromError(context, e, fallback: 'Reject failed');
    }
  }

  List<TicketSale> get _filtered {
    if (_search.isEmpty) return _requests;
    final q = _search.toLowerCase();
    return _requests.where((t) {
      final name = (t.attendeeDisplayName ?? '').toLowerCase();
      final tier = (t.tierName ?? '').toLowerCase();
      final code = t.ticketCode.toLowerCase();
      final receipt = (t.receiptNumber ?? '').toLowerCase();
      return name.contains(q) ||
          tier.contains(q) ||
          code.contains(q) ||
          receipt.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(title: const Text('Refund Requests')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: AppTheme.errorColor)))
              : _requests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 48,
                              color: AppTheme.textSecondaryOf(context)),
                          AppSpacing.vMd,
                          Text('No pending refund requests',
                              style: TextStyle(color: AppTheme.textSecondaryOf(context))),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0,
                            ),
                            child: TextField(
                              onChanged: (v) => setState(() => _search = v),
                              decoration: InputDecoration(
                                hintText: 'Search by name, tier, code...',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                suffixIcon: _search.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.close, size: 18),
                                        onPressed: () => setState(() => _search = ''),
                                      )
                                    : null,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.sm,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: filtered.isEmpty
                                ? Center(
                                    child: Text('No results for "$_search"',
                                        style: TextStyle(
                                            color: AppTheme.textSecondaryOf(context))),
                                  )
                                : ListView.separated(
                                    padding: AppSpacing.paddingLg,
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, __) => AppSpacing.vMd,
                                    itemBuilder: (context, i) =>
                                        _buildCard(filtered[i]),
                                  ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildCard(TicketSale ticket) {
    final amountCents = ticket.amountPaidCents;
    final price = '\$${(amountCents / 100).toStringAsFixed(2)}';
    final tierName = ticket.tierName ?? 'General';
    final attendee = 'User #${ticket.userId}';
    final receiptNo = ticket.receiptNumber ?? ticket.ticketCode;
    final createdAt = AppDateFormat.shortDateTime(ticket.createdAt);
    final ticketId = ticket.id;
    final isDark = AppTheme.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: AppRadius.lg,
        boxShadow: AppShadow.card(isDark),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withValues(alpha: 0.06),
              borderRadius: AppRadius.topLg,
            ),
            child: Row(
              children: [
                Icon(Icons.money_off_rounded, size: 20, color: AppTheme.errorColor),
                AppSpacing.hSm,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(attendee,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppTheme.textPrimaryOf(context))),
                      AppSpacing.vXs,
                      Text('$tierName \u2022 $receiptNo',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryOf(context))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.15),
                    borderRadius: AppRadius.pill,
                  ),
                  child: Text(price,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppTheme.errorColor)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 14, color: AppTheme.textSecondaryOf(context)),
                    AppSpacing.hSm,
                    Text('Purchased $createdAt',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryOf(context))),
                  ],
                ),
                AppSpacing.vMd,
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: OutlinedButton(
                          onPressed: () => _reject(ticketId),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(borderRadius: AppRadius.sm),
                          ),
                          child: Text('Reject',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.errorColor)),
                        ),
                      ),
                    ),
                    AppSpacing.hMd,
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () => _approve(ticketId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successColor,
                            shape: RoundedRectangleBorder(borderRadius: AppRadius.sm),
                          ),
                          child: const Text('Approve',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
