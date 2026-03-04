import 'package:flutter/material.dart';

import '../../../models/admin.dart';
import '../../../widgets/admin/admin_empty_state.dart';

class UserDiscountsTab extends StatefulWidget {
  final int userId;
  final AdminUserDetail detail;
  final void Function(String) onSnack;
  final Future<void> Function() onRefresh;

  const UserDiscountsTab({
    super.key,
    required this.userId,
    required this.detail,
    required this.onSnack,
    required this.onRefresh,
  });

  @override
  State<UserDiscountsTab> createState() => _UserDiscountsTabState();
}

class _UserDiscountsTabState extends State<UserDiscountsTab> {
  List<AdminUserDiscount> get _discounts => widget.detail.discounts ?? [];

  @override
  Widget build(BuildContext context) {
    final discounts = _discounts;
    if (discounts.isEmpty) {
      return Center(
          child: AdminEmptyState(
              icon: Icons.discount, message: 'No discounts'));
    }
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: discounts.length,
        itemBuilder: (ctx, i) => _discountTile(discounts[i]),
      ),
    );
  }

  Widget _discountTile(AdminUserDiscount d) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(d.eventTitle ?? 'Event',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${d.userDisplayName ?? 'User'} · ${d.discountType} ${d.value}'),
      ),
    );
  }
}
