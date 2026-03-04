import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../models/admin.dart';
import '../../../repositories/base_repository.dart';
import '../../../providers/sponsor_provider.dart';
import '../../../widgets/admin/admin_empty_state.dart';
import 'user_detail_shared.dart';

class UserSponsorBidsTab extends StatefulWidget {
  final int userId;
  final AdminUserDetail detail;
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
  List<AdminSponsorshipEvent> get _items {
    if (widget.dataKey == 'sponsorships') {
      return widget.detail.sponsorships ?? [];
    }
    return widget.detail.sponsorBids ?? [];
  }

  Future<void> _refundSponsorBid(
      int eventId, int catId, int bidId) async {
    try {
      await context
          .read<SponsorProvider>()
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

  Widget _sponsorshipTile(AdminSponsorshipEvent sp) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(sp.eventTitle ?? 'Event #${sp.eventId}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        children: sp.bids.map((b) {
          final canRefund = b.canRefund;
          return ListTile(
            title: Text(
                '${b.categoryName ?? 'Category'} · \$${(b.amountCents / 100).toStringAsFixed(2)}'),
            subtitle: Text(b.status),
            trailing: canRefund
                ? IconButton(
                    icon: Icon(Icons.money_off,
                        color: AppTheme.errorOf(context)),
                    tooltip: 'Refund',
                    onPressed: () =>
                        _refundSponsorBid(sp.eventId, b.categoryId, b.bidId),
                  )
                : statusBadge(context, b.status),
          );
        }).toList(),
      ),
    );
  }
}
