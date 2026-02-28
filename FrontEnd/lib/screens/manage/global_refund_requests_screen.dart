import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../config/design_tokens.dart';
import '../../utils/date_time_utils.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';

class GlobalRefundRequestsScreen extends StatefulWidget {
  const GlobalRefundRequestsScreen({super.key});

  @override
  State<GlobalRefundRequestsScreen> createState() =>
      _GlobalRefundRequestsScreenState();
}

class _GlobalRefundRequestsScreenState
    extends State<GlobalRefundRequestsScreen> {
  List<dynamic> _requests = [];
  bool _loading = true;
  String? _error;
  String _searchText = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final data = await api.getOrganizerRefundRequests();
      if (mounted) {
        setState(() {
          _requests = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  List<dynamic> get _filtered {
    if (_searchText.isEmpty) return _requests;
    final q = _searchText.toLowerCase();
    return _requests.where((r) {
      final attendee =
          (r['attendee_display_name'] ?? '').toString().toLowerCase();
      final event = (r['event_title'] ?? '').toString().toLowerCase();
      final tier = (r['tier_name'] ?? '').toString().toLowerCase();
      final code = (r['ticket_code'] ?? '').toString().toLowerCase();
      return attendee.contains(q) ||
          event.contains(q) ||
          tier.contains(q) ||
          code.contains(q);
    }).toList();
  }

  Future<void> _approve(int eventId, int ticketId) async {
    try {
      final api = context.read<ApiService>();
      await api.approveTicketRefund(eventId, ticketId);
      if (mounted) {
        AppToast.success(context, 'Refund approved');
        _load();
      }
    } catch (e) {
      if (mounted) AppToast.fromError(context, e, fallback: 'Approve failed');
    }
  }

  Future<void> _reject(int eventId, int ticketId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Refund'),
        content: const Text('The ticket will be restored to purchased status.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final api = context.read<ApiService>();
      await api.rejectTicketRefund(eventId, ticketId);
      if (mounted) {
        AppToast.success(context, 'Refund rejected — ticket restored');
        _load();
      }
    } catch (e) {
      if (mounted) AppToast.fromError(context, e, fallback: 'Reject failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Refund Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: AppTheme.errorColor),
                      AppSpacing.vMd,
                      Text('Failed to load refund requests',
                          style: TextStyle(
                              color: AppTheme.textSecondaryOf(context))),
                      AppSpacing.vMd,
                      ElevatedButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _requests.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                              height: 300,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_outline,
                                        size: 48,
                                        color:
                                            AppTheme.textSecondaryOf(context)),
                                    AppSpacing.vMd,
                                    Text('No pending refund requests',
                                        style: TextStyle(
                                            color: AppTheme.textSecondaryOf(
                                                context))),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView(
                          padding: AppSpacing.paddingLg,
                          children: [
                            // Search bar
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText:
                                    'Search by attendee, event, or tier...',
                                prefixIcon:
                                    const Icon(Icons.search, size: 20),
                                suffixIcon: _searchText.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear,
                                            size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(
                                              () => _searchText = '');
                                        },
                                      )
                                    : null,
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 12),
                                border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(8)),
                              ),
                              style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      AppTheme.textPrimaryOf(context)),
                              onChanged: (v) =>
                                  setState(() => _searchText = v.trim()),
                            ),
                            AppSpacing.vMd,

                            // Count chip
                            Row(
                              children: [
                                Icon(Icons.money_off_rounded,
                                    size: 16,
                                    color: AppTheme.errorColor),
                                const SizedBox(width: 6),
                                Text(
                                  '${filtered.length} pending${_searchText.isNotEmpty ? ' (of ${_requests.length})' : ''}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        AppTheme.textSecondaryOf(context),
                                  ),
                                ),
                              ],
                            ),
                            AppSpacing.vMd,

                            if (filtered.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 32),
                                child: Center(
                                  child: Text('No matching requests',
                                      style: TextStyle(
                                          color:
                                              AppTheme.textSecondaryOf(
                                                  context))),
                                ),
                              )
                            else
                              ...filtered.map((r) {
                                final index = filtered.indexOf(r);
                                return Padding(
                                  padding: EdgeInsets.only(
                                      bottom: index < filtered.length - 1
                                          ? AppSpacing.md
                                          : 0),
                                  child: _buildCard(
                                      r as Map<String, dynamic>),
                                );
                              }),
                          ],
                        ),
                ),
    );
  }

  Widget _buildCard(Map<String, dynamic> ticket) {
    final amountCents = ticket['amount_paid_cents'] ?? 0;
    final price = '\$${(amountCents / 100).toStringAsFixed(2)}';
    final tierName = ticket['tier_name'] ?? 'General';
    final attendee = ticket['attendee_display_name'] ?? 'Unknown';
    final eventTitle = ticket['event_title'] ?? '';
    final receiptNo = ticket['receipt_number'] ?? ticket['ticket_code'] ?? '';
    final createdAt = ticket['created_at'] != null
        ? AppDateFormat.isoShort(ticket['created_at'])
        : '';
    final ticketId = ticket['id'] as int;
    final eventId = ticket['event_id'] as int;
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
                Icon(Icons.money_off_rounded,
                    size: 20, color: AppTheme.errorColor),
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
                if (eventTitle.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.event_rounded,
                          size: 14, color: AppTheme.accentOf(context)),
                      AppSpacing.hSm,
                      Expanded(
                        child: Text(eventTitle,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accentOf(context)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  AppSpacing.vSm,
                ],
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
                          onPressed: () => _reject(eventId, ticketId),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: AppTheme.errorColor
                                    .withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(
                                borderRadius: AppRadius.sm),
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
                          onPressed: () => _approve(eventId, ticketId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successColor,
                            shape: RoundedRectangleBorder(
                                borderRadius: AppRadius.sm),
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
