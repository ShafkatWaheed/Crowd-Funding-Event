import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../models/event.dart';
import '../../../services/api_service.dart';
import '../../../widgets/app_toast.dart';

class TicketTierManagement extends StatefulWidget {
  final Event event;
  final VoidCallback onTiersChanged;

  const TicketTierManagement({
    super.key,
    required this.event,
    required this.onTiersChanged,
  });

  @override
  State<TicketTierManagement> createState() => _TicketTierManagementState();
}

class _TicketTierManagementState extends State<TicketTierManagement> {
  Widget _sectionTitle(BuildContext context, String title,
      {IconData? icon, Color? iconColor}) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: (iconColor ?? AppTheme.primaryColor).withValues(alpha: 0.1),
              borderRadius: AppRadius.sm,
            ),
            child: Icon(icon,
                size: AppIconSize.sm,
                color: iconColor ?? AppTheme.primaryColor),
          ),
          AppSpacing.hSm,
        ],
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimaryOf(context),
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        _sectionTitle(context, 'Ticket Tiers',
            icon: Icons.confirmation_number_rounded,
            iconColor: Colors.deepPurple),
        const SizedBox(height: 14),
        FutureBuilder<List<dynamic>>(
          future: context
              .read<ApiService>()
              .dio
              .get('/events/${widget.event.id}/ticket-tiers')
              .then((r) => r.data as List),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2),
              ));
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Could not load tiers',
                    style: TextStyle(color: AppTheme.textSecondaryOf(context))),
              );
            }
            final tiers = snapshot.data ?? [];
            final canModify = widget.event.status != EventStatus.selling_tickets &&
                widget.event.status != EventStatus.live &&
                widget.event.status != EventStatus.completed;
            if (tiers.isEmpty) {
              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: AppSpacing.paddingXl,
                    decoration: BoxDecoration(
                      color: AppTheme.cardOf(context),
                      borderRadius: AppRadius.lg,
                      boxShadow: AppShadow.soft(AppTheme.isDark(context)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.layers_clear_rounded,
                            size: AppIconSize.xxl,
                            color: AppTheme.textSecondaryOf(context)),
                        AppSpacing.vSm,
                        Text('No tiers configured',
                            style: TextStyle(
                                color: AppTheme.textSecondaryOf(context),
                                fontSize: 14)),
                      ],
                    ),
                  ),
                  if (canModify) ...[
                    AppSpacing.vMd,
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddTierDialog(widget.event.id),
                        icon: const Icon(Icons.add_rounded, size: AppIconSize.sm),
                        label: const Text('Add Tier'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.deepPurple,
                          side: BorderSide(
                              color: Colors.deepPurple.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.md),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            }
            return Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardOf(context),
                    borderRadius: AppRadius.lg,
                    boxShadow: AppShadow.card(AppTheme.isDark(context)),
                  ),
                  child: Column(
                    children: tiers.asMap().entries.map((entry) {
                      final i = entry.key;
                      final tier = entry.value;
                      final tierId = tier['id'];
                      final name = tier['name'] ?? '';
                      final desc = tier['description'] ?? '';
                      final priceCents = tier['price_cents'] ?? 0;
                      final price =
                          '\$${(priceCents / 100).toStringAsFixed(2)}';
                      final isLast = i == tiers.length - 1;
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.md),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple
                                        .withValues(alpha: 0.1),
                                    borderRadius: AppRadius.md,
                                  ),
                                  child: const Icon(
                                      Icons.confirmation_number_rounded,
                                      size: AppIconSize.md,
                                      color: Colors.deepPurple),
                                ),
                                AppSpacing.hMd,
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          name,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: AppTheme
                                                  .textPrimaryOf(context))),
                                      if (desc.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(desc,
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: AppTheme
                                                      .textSecondaryOf(context)),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Text(price,
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.successColor)),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.edit_outlined,
                                      size: 20,
                                      color:
                                          AppTheme.textSecondaryOf(context)),
                                  tooltip: 'Edit tier',
                                  onPressed: () => _showEditTierDialog(
                                      widget.event.id, tierId, name, desc,
                                      priceCents),
                                ),
                                if (canModify)
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded,
                                        size: 20,
                                        color: AppTheme.errorColor),
                                    tooltip: 'Delete tier',
                                    onPressed: () => _confirmDeleteTier(
                                        widget.event.id, tierId, name),
                                  ),
                              ],
                            ),
                          ),
                          if (!isLast)
                            Divider(
                                height: 1,
                                indent: 60,
                                color: AppTheme.dividerOf(context)),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                if (canModify) ...[
                  AppSpacing.vMd,
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showAddTierDialog(widget.event.id),
                      icon: const Icon(Icons.add_rounded,
                          size: AppIconSize.sm),
                      label: const Text('Add Tier'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.deepPurple,
                        side: BorderSide(
                            color: Colors.deepPurple.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.md),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _showEditTierDialog(int eventId, int tierId, String name,
      String description, int priceCents) async {
    final nameCtrl = TextEditingController(text: name);
    final descCtrl = TextEditingController(text: description);
    final priceCtrl = TextEditingController(
        text: (priceCents / 100).toStringAsFixed(2));

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Tier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Tier Name'),
            ),
            AppSpacing.vSm,
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            AppSpacing.vSm,
            TextField(
              controller: priceCtrl,
              decoration: const InputDecoration(
                  labelText: 'Price', prefixText: '\$ '),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final price = double.tryParse(priceCtrl.text);
              if (nameCtrl.text.trim().isEmpty || price == null) return;
              try {
                final api = context.read<ApiService>();
                await api.updateTicketTier(eventId, tierId, {
                  'name': nameCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'price_cents': (price * 100).toInt(),
                });
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  AppToast.fromError(ctx, e, fallback: 'Failed to update tier');
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      widget.onTiersChanged();
      AppToast.success(context, 'Tier updated!');
    }
  }

  Future<void> _showAddTierDialog(int eventId) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '0.00');

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Tier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Tier Name'),
            ),
            AppSpacing.vSm,
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            AppSpacing.vSm,
            TextField(
              controller: priceCtrl,
              decoration: const InputDecoration(
                  labelText: 'Price', prefixText: '\$ '),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final price = double.tryParse(priceCtrl.text);
              if (nameCtrl.text.trim().isEmpty || price == null) return;
              try {
                final api = context.read<ApiService>();
                await api.createTicketTier(eventId, {
                  'name': nameCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'price_cents': (price * 100).toInt(),
                });
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  AppToast.fromError(ctx, e, fallback: 'Failed to create tier');
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created == true && mounted) {
      widget.onTiersChanged();
      AppToast.success(context, 'Tier created!');
    }
  }

  Future<void> _confirmDeleteTier(
      int eventId, int tierId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Tier'),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final api = context.read<ApiService>();
        await api.deleteTicketTier(eventId, tierId);
        if (mounted) {
          widget.onTiersChanged();
          AppToast.success(context, 'Tier deleted.');
        }
      } catch (e) {
        if (mounted) {
          AppToast.fromError(context, e, fallback: 'Failed to delete tier');
        }
      }
    }
  }
}
