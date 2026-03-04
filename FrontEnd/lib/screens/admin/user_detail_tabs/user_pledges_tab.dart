import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../models/admin.dart';
import '../../../repositories/base_repository.dart';
import '../../../providers/pledge_provider.dart';
import '../../../widgets/admin/admin_empty_state.dart';
import 'user_detail_shared.dart';

class UserPledgesTab extends StatefulWidget {
  final int userId;
  final AdminUserDetail detail;
  final void Function(String) onSnack;
  final Future<void> Function() onRefresh;
  final bool isOrganizerPledges;

  const UserPledgesTab({
    super.key,
    required this.userId,
    required this.detail,
    required this.onSnack,
    required this.onRefresh,
    this.isOrganizerPledges = false,
  });

  @override
  State<UserPledgesTab> createState() => _UserPledgesTabState();
}

class _UserPledgesTabState extends State<UserPledgesTab> {
  String _search = '';
  String _statusFilter = 'all';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AdminUserPledge> get _allPledges =>
      widget.detail.pledges ?? [];

  Future<void> _refundPledge(int eventId, int fundingId) async {
    try {
      await context
          .read<PledgeProvider>()
          .adminRefundPledge(eventId, fundingId);
      widget.onRefresh();
      widget.onSnack('Pledge refunded');
    } catch (e) {
      widget.onSnack('Failed: ${ApiError.extractMessage(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final allPledges = _allPledges;
    final statuses = extractStatusesFrom(allPledges, (p) => p.status);
    statuses.addAll(refundPledgeStatuses);
    final counts = countByStatus(allPledges, (p) => p.status);
    var filtered =
        allPledges.where((p) => matchesPledgeItem(p, _search)).toList();
    if (_statusFilter == '_donation') {
      filtered = filtered.where((p) => p.isGuest).toList();
    } else if (_statusFilter != 'all') {
      filtered = filtered.where((p) => p.status == _statusFilter).toList();
    }

    final donationCount = allPledges.where((p) => p.isGuest).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: UserDetailSearchField(
            controller: _searchCtrl,
            hint: 'Search by event, user, amount...',
            currentValue: _search,
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        statusChipsWithExtras(
          context,
          statuses: statuses,
          selected: _statusFilter,
          onChanged: (v) => setState(() => _statusFilter = v),
          refundStatuses: refundPledgeStatuses,
          statusCounts: counts,
          extras: [
            if (donationCount > 0)
              ExtraChip('_donation', 'Donations ($donationCount)',
                  Icons.card_giftcard),
          ],
        ),
        countStrip(context, filtered.length, allPledges.length),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: AdminEmptyState(
                      icon: Icons.volunteer_activism,
                      message: 'No pledges'))
              : RefreshIndicator(
                  onRefresh: widget.onRefresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _pledgeCard(filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _pledgeCard(AdminUserPledge p) {
    final canRefund = p.status == 'pledged';
    final name = p.userDisplayName ?? 'User';

    final subtitleParts = <String>[
      name,
      '\$${(p.amountCents / 100).toStringAsFixed(2)}'
    ];
    if (p.reservedSpots > 0) {
      subtitleParts
          .add('${p.reservedSpots} spot${p.reservedSpots == 1 ? '' : 's'}');
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: p.isGuest
            ? Icon(Icons.card_giftcard,
                color: AppTheme.warningOf(context), size: 20)
            : null,
        title: Row(
          children: [
            Expanded(
              child: Text(p.eventTitle ?? 'Event #${p.eventId}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            if (p.isGuest)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      AppTheme.warningOf(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Donation',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.warningOf(context),
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        subtitle: Text(subtitleParts.join(' · ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            statusBadge(context, p.status),
            if (canRefund) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.money_off,
                    color: AppTheme.errorOf(context)),
                tooltip: 'Refund',
                onPressed: () => _refundPledge(p.eventId, p.id),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
