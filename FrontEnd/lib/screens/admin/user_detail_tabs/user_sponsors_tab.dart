import 'package:flutter/material.dart';

import '../../../models/admin.dart';
import '../../../widgets/admin/admin_empty_state.dart';

class UserSponsorsTab extends StatefulWidget {
  final int userId;
  final AdminUserDetail detail;
  final void Function(String) onSnack;
  final Future<void> Function() onRefresh;

  const UserSponsorsTab({
    super.key,
    required this.userId,
    required this.detail,
    required this.onSnack,
    required this.onRefresh,
  });

  @override
  State<UserSponsorsTab> createState() => _UserSponsorsTabState();
}

class _UserSponsorsTabState extends State<UserSponsorsTab> {
  List<AdminUserSponsor> get _sponsors => widget.detail.sponsors ?? [];

  @override
  Widget build(BuildContext context) {
    final sponsors = _sponsors;
    if (sponsors.isEmpty) {
      return Center(
          child: AdminEmptyState(
              icon: Icons.business, message: 'No sponsors'));
    }
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sponsors.length,
        itemBuilder: (ctx, i) => _sponsorTile(sponsors[i]),
      ),
    );
  }

  Widget _sponsorTile(AdminUserSponsor s) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(s.companyName ?? 'Sponsor',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${s.contactName ?? ''} · \$${(s.totalAmountCents / 100).toStringAsFixed(2)}'),
      ),
    );
  }
}
