import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../services/api_service.dart';
import '../../../widgets/admin/admin_empty_state.dart';
import 'user_detail_shared.dart';

class UserPledgesTab extends StatefulWidget {
  final int userId;
  final Map<String, dynamic> detail;
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

  List<Map<String, dynamic>> get _allPledges =>
      (widget.detail['pledges'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

  Future<void> _refundPledge(int eventId, int fundingId) async {
    try {
      await context
          .read<ApiService>()
          .adminRefundPledge(eventId, fundingId);
      widget.onRefresh();
      widget.onSnack('Pledge refunded');
    } catch (e) {
      widget.onSnack('Failed: ${ApiService.extractError(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final allPledges = _allPledges;
    final statuses = extractStatuses(allPledges, 'status');
    statuses.addAll(refundPledgeStatuses);
    var filtered =
        allPledges.where((p) => matchesPledge(p, _search)).toList();
    if (_statusFilter == '_donation') {
      filtered =
          filtered.where((p) => p['is_guest'] == true).toList();
    } else if (_statusFilter != 'all') {
      filtered =
          filtered.where((p) => p['status'] == _statusFilter).toList();
    }

    final donationCount =
        allPledges.where((p) => p['is_guest'] == true).length;

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
          allItems: allPledges,
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

  Widget _pledgeCard(Map<String, dynamic> p) {
    final eventId = p['event_id'] as int;
    final fundingId = p['id'] as int;
    final status = p['status'] as String? ?? '';
    final canRefund = status == 'pledged';
    final amountCents = p['amount_cents'] as int? ?? 0;
    final name = p['user_display_name'] ?? 'User';
    final isGuest = p['is_guest'] == true;
    final spots = p['reserved_spots'] as int? ?? 0;

    final subtitleParts = <String>[
      name,
      '\$${(amountCents / 100).toStringAsFixed(2)}'
    ];
    if (spots > 0) subtitleParts.add('$spots spot${spots == 1 ? '' : 's'}');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: isGuest
            ? Icon(Icons.card_giftcard,
                color: AppTheme.warningOf(context), size: 20)
            : null,
        title: Row(
          children: [
            Expanded(
              child: Text(p['event_title'] ?? 'Event #$eventId',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            if (isGuest)
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
            statusBadge(context, status),
            if (canRefund) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.money_off,
                    color: AppTheme.errorOf(context)),
                tooltip: 'Refund',
                onPressed: () => _refundPledge(eventId, fundingId),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
