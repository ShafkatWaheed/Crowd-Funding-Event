import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../repositories/base_repository.dart';
import '../../../repositories/sponsor_repository.dart';
import '../../../widgets/admin/admin_empty_state.dart';
import 'user_detail_shared.dart';

class UserSponsorBidsTab extends StatefulWidget {
  final int userId;
  final Map<String, dynamic> detail;
  final void Function(String) onSnack;
  final Future<void> Function() onRefresh;

  /// Use 'sponsor_bids' for organizer role, 'sponsorships' for sponsor role.
  final String dataKey;

  const UserSponsorBidsTab({
    super.key,
    required this.userId,
    required this.detail,
    required this.onSnack,
    required this.onRefresh,
    this.dataKey = 'sponsor_bids',
  });

  @override
  State<UserSponsorBidsTab> createState() => _UserSponsorBidsTabState();
}

class _UserSponsorBidsTabState extends State<UserSponsorBidsTab> {
  List<Map<String, dynamic>> get _items =>
      (widget.detail[widget.dataKey] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

  Future<void> _refundSponsorBid(
      int eventId, int catId, int bidId) async {
    try {
      await context
          .read<SponsorRepository>()
          .adminRefundSponsorBid(eventId, catId, bidId);
      widget.onRefresh();
      widget.onSnack('Sponsor bid refunded');
    } catch (e) {
      widget.onSnack('Failed: ${ApiError.extractMessage(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items.isEmpty) {
      return Center(
          child: AdminEmptyState(
              icon: Icons.business_center,
              message: widget.dataKey == 'sponsorships'
                  ? 'No sponsorships'
                  : 'No sponsor bids'));
    }
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (ctx, i) => _sponsorshipTile(items[i]),
      ),
    );
  }

  Widget _sponsorshipTile(Map<String, dynamic> sp) {
    final eventId = sp['event_id'] as int;
    final bids = sp['bids'] as List<dynamic>? ?? [];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(sp['event_title'] ?? 'Event #$eventId',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        children: bids.cast<Map<String, dynamic>>().map((b) {
          final bidId = b['bid_id'] as int;
          final catId = b['category_id'] as int;
          final canRefund = b['can_refund'] == true;
          return ListTile(
            title: Text(
                '${b['category_name'] ?? 'Category'} · \$${((b['amount_cents'] ?? 0) / 100).toStringAsFixed(2)}'),
            subtitle: Text(b['status']?.toString() ?? ''),
            trailing: canRefund
                ? IconButton(
                    icon: Icon(Icons.money_off,
                        color: AppTheme.errorOf(context)),
                    tooltip: 'Refund',
                    onPressed: () =>
                        _refundSponsorBid(eventId, catId, bidId),
                  )
                : statusBadge(
                    context, b['status']?.toString() ?? ''),
          );
        }).toList(),
      ),
    );
  }
}
