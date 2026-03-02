import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../repositories/admin_repository.dart';
import '../../repositories/base_repository.dart';
import '../../utils/date_time_utils.dart';

const double adminWideBreakpoint = 900;
const int adminPageSize = 20;

String centsToStr(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String statusLabel(String s) =>
    s.replaceAll('_', ' ').split(' ').map(capitalize).join(' ');

String formatDate(String? iso) => AppDateFormat.isoDateOnly(iso);

String formatIsoDate(String? iso) => AppDateFormat.isoFull(iso);

List<String> getWarnings(Map<String, dynamic> e) {
  final raw = e['validation_warnings'];
  if (raw is List) return raw.map((w) => w.toString()).toList();
  return [];
}

Widget statusChip(BuildContext context, String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(label,
        style:
            TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
  );
}

Color ticketStatusColor(BuildContext context, String status) {
  switch (status) {
    case 'purchased':
      return AppTheme.successOf(context);
    case 'refund_requested':
      return AppTheme.warningOf(context);
    case 'refunded':
      return AppTheme.errorOf(context);
    case 'waitlisted':
      return AppTheme.accentOf(context);
    default:
      return AppTheme.textSecondaryOf(context);
  }
}

Color roleColor(BuildContext context, String role) {
  switch (role) {
    case 'admin':
      return AppTheme.errorOf(context);
    case 'organizer':
      return AppTheme.accentOf(context);
    case 'sponsor':
      return context.sponsorAccent;
    case 'customer':
      return AppTheme.successOf(context);
    default:
      return AppTheme.textSecondaryOf(context);
  }
}

Color genreColor(BuildContext context, String genre) {
  switch (genre) {
    case 'music':
      return context.sponsorAccent;
    case 'tech':
      return AppTheme.accentOf(context);
    case 'sports':
      return context.ticketAccent;
    case 'arts':
      return context.fundingAccent;
    case 'community':
      return AppTheme.successOf(context);
    case 'charity':
      return AppTheme.warningOf(context);
    case 'food':
      return AppTheme.errorOf(context);
    case 'education':
      return context.managementAccent;
    case 'business':
      return context.statusDraft;
    default:
      return AppTheme.textSecondaryOf(context);
  }
}

Color statusColor(BuildContext context, String status) {
  switch (status) {
    case 'draft':
      return context.statusDraft;
    case 'pending_approval':
      return context.statusPending;
    case 'approved':
      return context.statusApproved;
    case 'live':
      return context.statusLive;
    case 'selling_tickets':
      return context.statusSelling;
    case 'waiting_event_date':
      return context.statusWaiting;
    case 'completed':
      return context.statusCompleted;
    case 'cancelled':
      return context.statusCancelled;
    default:
      return context.statusDraft;
  }
}

Color escrowStatusColor(BuildContext context, String status) {
  switch (status) {
    case 'holding':
      return context.fundingAccent;
    case 'partially_released':
      return AppTheme.warningOf(context);
    case 'fully_released':
      return AppTheme.successOf(context);
    case 'refunded':
      return AppTheme.errorOf(context);
    case 'frozen':
      return context.managementAccent;
    case 'waived':
      return context.statusDraft;
    default:
      return context.statusDraft;
  }
}

Widget infoCard(
    BuildContext context, String title, String value, IconData icon, Color color) {
  return Card(
    color: AppTheme.cardOf(context),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context))),
              Text(value,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryOf(context))),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget escrowStat(BuildContext context, String label, int cents, Color color) {
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

Widget escrowStageDot(BuildContext context, String label, bool done, Color color) {
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

Widget stageLine(BuildContext context, bool active) {
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

Widget escrowBtn(
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

class PlatformAccountCard extends StatefulWidget {
  final bool configured;
  final String? institutionNumber;
  final String? transitNumber;
  final String? lastFour;
  final VoidCallback onSaved;

  const PlatformAccountCard({
    super.key,
    required this.configured,
    this.institutionNumber,
    this.transitNumber,
    this.lastFour,
    required this.onSaved,
  });

  @override
  State<PlatformAccountCard> createState() => _PlatformAccountCardState();
}

class _PlatformAccountCardState extends State<PlatformAccountCard> {
  bool _editing = false;
  bool _saving = false;
  final _institutionCtrl = TextEditingController();
  final _transitCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _accountHolderCtrl = TextEditingController();

  @override
  void dispose() {
    _institutionCtrl.dispose();
    _transitCtrl.dispose();
    _accountNumberCtrl.dispose();
    _accountHolderCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_institutionCtrl.text.trim().length != 3 ||
        _transitCtrl.text.trim().length != 5 ||
        _accountNumberCtrl.text.trim().isEmpty ||
        _accountHolderCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All fields are required (Institution: 3 digits, Transit: 5 digits)')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final admin = context.read<AdminRepository>();
      await admin.updatePlatformAccount({
        'institution_number': _institutionCtrl.text.trim(),
        'transit_number': _transitCtrl.text.trim(),
        'account_number': _accountNumberCtrl.text.trim(),
        'account_holder': _accountHolderCtrl.text.trim(),
      });
      if (mounted) {
        setState(() {
          _editing = false;
          _saving = false;
        });
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(ApiError.extractMessage(e, fallback: 'Failed to save'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return Card(
        color: AppTheme.cardOf(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Configure Platform Account',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(context))),
              const SizedBox(height: 4),
              Text('Canadian bank account details',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context))),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _institutionCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Institution # (3 digits)',
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: _transitCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Transit # (5 digits)',
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(5),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _accountNumberCtrl,
                decoration: const InputDecoration(
                    labelText: 'Account Number (7-12 digits)',
                    border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _accountHolderCtrl,
                decoration: const InputDecoration(
                    labelText: 'Account Holder',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _saving ? null : () => setState(() => _editing = false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: AppTheme.cardOf(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              widget.configured
                  ? Icons.check_circle
                  : Icons.warning_amber_rounded,
              color: widget.configured
                  ? AppTheme.successColor
                  : AppTheme.warningColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.configured ? 'Configured' : 'Not configured',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryOf(context)),
                  ),
                  if (widget.configured)
                    Text(
                      '${widget.institutionNumber ?? '—'}-${widget.transitNumber ?? '—'} ••••${widget.lastFour ?? ''}',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryOf(context)),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => setState(() => _editing = true),
              tooltip: 'Edit',
            ),
          ],
        ),
      ),
    );
  }
}
