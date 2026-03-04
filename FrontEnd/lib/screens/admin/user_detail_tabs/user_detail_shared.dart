import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/design_tokens.dart';
import '../../../utils/date_time_utils.dart';
import '../../../config/theme.dart';
import '../../../models/admin.dart';
import '../../../providers/admin_provider.dart';
import '../../../repositories/base_repository.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const refundTicketStatuses = {
  'refund_requested',
  'refund_processing',
  'refunded',
  'refund_failed',
};

const refundPledgeStatuses = {
  'refund_processing',
  'refunded',
  'refund_failed',
};

// ---------------------------------------------------------------------------
// ExtraChip model (used by statusChipsWithExtras)
// ---------------------------------------------------------------------------

class ExtraChip {
  final String key;
  final String label;
  final IconData icon;
  const ExtraChip(this.key, this.label, this.icon);
}

// ---------------------------------------------------------------------------
// Search field with built-in debounce
// ---------------------------------------------------------------------------

class UserDetailSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final String currentValue;
  final ValueChanged<String> onChanged;

  const UserDetailSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.currentValue,
    required this.onChanged,
  });

  @override
  State<UserDetailSearchField> createState() => _UserDetailSearchFieldState();
}

class _UserDetailSearchFieldState extends State<UserDetailSearchField> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      widget.onChanged(v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: widget.currentValue.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  widget.controller.clear();
                  widget.onChanged('');
                },
              )
            : null,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        border: OutlineInputBorder(
          borderRadius: AppRadius.sm,
          borderSide: BorderSide(color: AppTheme.dividerOf(context)),
        ),
      ),
      onChanged: _onChanged,
    );
  }
}

// ---------------------------------------------------------------------------
// Badge / chip helpers
// ---------------------------------------------------------------------------

Widget statusBadge(BuildContext context, String status) {
  final color = statusColor(context, status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      formatStatus(status),
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

String formatStatus(String s) {
  return s
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

Color statusColor(BuildContext context, String status) {
  switch (status) {
    case 'purchased':
      return AppTheme.successOf(context);
    case 'refund_requested':
      return AppTheme.warningOf(context);
    case 'refunded':
      return AppTheme.errorOf(context);
    case 'waitlisted':
      return AppTheme.accentOf(context);
    case 'pledged':
      return AppTheme.successOf(context);
    default:
      return AppTheme.textSecondaryOf(context);
  }
}

Widget infoChip(BuildContext context, IconData icon, String label) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: AppTheme.textSecondaryOf(context)),
      const SizedBox(width: 4),
      Text(label,
          style:
              TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
    ],
  );
}

Widget detailRow(BuildContext context, String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondaryOf(context))),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Count strip
// ---------------------------------------------------------------------------

Widget countStrip(BuildContext context, int filtered, int total) {
  if (filtered == total) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
    child: Text(
      '$filtered of $total results',
      style:
          TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
    ),
  );
}

// ---------------------------------------------------------------------------
// Status filter chips with optional refund section and extras
// ---------------------------------------------------------------------------

Widget statusChipsWithExtras(
  BuildContext context, {
  required Set<String> statuses,
  required String selected,
  required void Function(String) onChanged,
  Set<String> refundStatuses = const {},
  Map<String, int> statusCounts = const {},
  List<ExtraChip> extras = const [],
}) {
  final regular =
      statuses.where((s) => !refundStatuses.contains(s)).toList();
  final refund =
      statuses.where((s) => refundStatuses.contains(s)).toList();

  int countFor(String status) => statusCounts[status] ?? 0;

  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: const Text('All'),
            selected: selected == 'all',
            onSelected: (_) => onChanged('all'),
          ),
        ),
        ...regular.map((s) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(formatStatus(s)),
                selected: selected == s,
                onSelected: (_) => onChanged(s),
              ),
            )),
        if (refund.isNotEmpty) ...[
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: AppTheme.dividerOf(context),
          ),
          ...refund.map((s) {
            final count = countFor(s);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: Icon(Icons.money_off,
                    size: 16,
                    color:
                        selected == s ? null : AppTheme.errorOf(context)),
                label: Text(
                    '${formatStatus(s)}${count > 0 ? ' ($count)' : ''}'),
                selected: selected == s,
                onSelected: (_) => onChanged(s),
              ),
            );
          }),
        ],
        if (extras.isNotEmpty) ...[
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: AppTheme.dividerOf(context),
          ),
          ...extras.map((e) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  avatar: Icon(e.icon, size: 16),
                  label: Text(e.label),
                  selected: selected == e.key,
                  onSelected: (_) =>
                      onChanged(selected == e.key ? 'all' : e.key),
                ),
              )),
        ],
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Escrow display helpers
// ---------------------------------------------------------------------------

Widget userDetailEscrowStat(
    BuildContext context, String label, int cents, Color color) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: TextStyle(
              fontSize: 11, color: AppTheme.textSecondaryOf(context))),
      Text('\$${(cents / 100).toStringAsFixed(2)}',
          style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 15, color: color)),
    ],
  );
}

Widget userDetailStageDot(
    BuildContext context, String label, bool done, Color color) {
  return Column(
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: done ? color : AppTheme.dividerOf(context),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: done
              ? Icon(Icons.check, color: context.onDarkSurface, size: 16)
              : Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondaryOf(context))),
        ),
      ),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(
              fontSize: 9,
              color:
                  done ? color : AppTheme.textSecondaryOf(context))),
    ],
  );
}

Widget userDetailStageLine(BuildContext context, bool active) {
  return Expanded(
    child: Container(
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: active
            ? AppTheme.successOf(context)
            : AppTheme.dividerOf(context),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

Widget userDetailEscrowBtn(
    String label, IconData icon, Color color, VoidCallback onTap) {
  return SizedBox(
    height: 32,
    child: OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Data matching / filtering helpers
// ---------------------------------------------------------------------------

bool matchesTicketItem(AdminUserTicket t, String q) {
  if (q.isEmpty) return true;
  final lower = q.toLowerCase();
  return (t.eventTitle?.toLowerCase().contains(lower) ?? false) ||
      (t.tierName?.toLowerCase().contains(lower) ?? false) ||
      t.amountPaidCents.toString().contains(lower) ||
      t.status.toLowerCase().contains(lower);
}

bool matchesTicketSale(AdminUserTicketSale t, String q) {
  if (q.isEmpty) return true;
  final lower = q.toLowerCase();
  return (t.eventTitle?.toLowerCase().contains(lower) ?? false) ||
      (t.tierName?.toLowerCase().contains(lower) ?? false) ||
      t.amountPaidCents.toString().contains(lower) ||
      t.status.toLowerCase().contains(lower) ||
      (t.attendeeDisplayName?.toLowerCase().contains(lower) ?? false);
}

bool matchesPledgeItem(AdminUserPledge p, String q) {
  if (q.isEmpty) return true;
  final lower = q.toLowerCase();
  return (p.eventTitle?.toLowerCase().contains(lower) ?? false) ||
      (p.userDisplayName?.toLowerCase().contains(lower) ?? false) ||
      p.amountCents.toString().contains(lower) ||
      p.status.toLowerCase().contains(lower);
}

Set<String> extractStatusesFrom<T>(
    List<T> items, String Function(T) getStatus) {
  final statuses = <String>{};
  for (final item in items) {
    final s = getStatus(item);
    if (s.isNotEmpty) statuses.add(s);
  }
  return statuses;
}

Map<String, int> countByStatus<T>(
    List<T> items, String Function(T) getStatus) {
  final counts = <String, int>{};
  for (final item in items) {
    final s = getStatus(item);
    counts[s] = (counts[s] ?? 0) + 1;
  }
  return counts;
}

// ---------------------------------------------------------------------------
// Event status helpers
// ---------------------------------------------------------------------------

IconData eventStatusIcon(String status) {
  switch (status) {
    case 'draft':
      return Icons.edit_note;
    case 'pending_approval':
      return Icons.hourglass_top;
    case 'approved':
      return Icons.check_circle_outline;
    case 'under_review':
      return Icons.search;
    case 'funding':
      return Icons.attach_money;
    case 'ticket_selling':
      return Icons.confirmation_number;
    case 'live':
      return Icons.play_circle;
    case 'completed':
      return Icons.done_all;
    case 'cancelled':
      return Icons.cancel;
    default:
      return Icons.event;
  }
}

Color eventStatusColor(BuildContext context, String status) {
  switch (status) {
    case 'draft':
      return AppTheme.textSecondaryOf(context);
    case 'pending_approval':
      return AppTheme.accentOf(context);
    case 'approved':
      return AppTheme.successOf(context);
    case 'under_review':
      return AppTheme.warningOf(context);
    case 'funding':
      return context.fundingAccent;
    case 'ticket_selling':
      return context.ticketAccent;
    case 'live':
      return AppTheme.successOf(context);
    case 'completed':
      return AppTheme.successOf(context);
    case 'cancelled':
      return AppTheme.errorOf(context);
    default:
      return AppTheme.textSecondaryOf(context);
  }
}

String formatIsoDateShort(String? iso) => AppDateFormat.isoShort(iso);

// ---------------------------------------------------------------------------
// Shared action helpers
// ---------------------------------------------------------------------------

void confirmAction(
    BuildContext context, String title, String message, VoidCallback onConfirm) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            onConfirm();
          },
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
}

Future<void> escrowAction(
  BuildContext context,
  int eventId,
  String action, {
  int? stage,
  required VoidCallback onRefresh,
  required void Function(String) onSnack,
}) async {
  try {
    final admin = context.read<AdminProvider>();
    await admin.escrowAction(eventId, action, stage: stage);
    onRefresh();
    onSnack('Escrow action completed');
  } catch (e) {
    onSnack('Escrow action failed: ${ApiError.extractMessage(e)}');
  }
}
