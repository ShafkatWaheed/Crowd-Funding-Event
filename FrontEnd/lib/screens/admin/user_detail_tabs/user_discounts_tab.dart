import 'package:flutter/material.dart';

import '../../../widgets/admin/admin_empty_state.dart';

class UserDiscountsTab extends StatefulWidget {
  final int userId;
  final Map<String, dynamic> detail;
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
  List<Map<String, dynamic>> get _discounts =>
      (widget.detail['discounts'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

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

  Widget _discountTile(Map<String, dynamic> d) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(d['event_title'] ?? 'Event',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${d['user_display_name'] ?? 'User'} · ${d['discount_type']} ${d['value']}'),
      ),
    );
  }
}
