import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../models/event.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/event_provider.dart';
import '../../../widgets/app_toast.dart';
import '../../../widgets/press_feedback.dart';

class QuickActionBar extends StatefulWidget {
  final Event event;
  final bool isRegistered;
  final String? regStatus;
  final bool ageBlocked;
  final VoidCallback onRegistrationChanged;

  const QuickActionBar({
    super.key,
    required this.event,
    required this.isRegistered,
    this.regStatus,
    this.ageBlocked = false,
    required this.onRegistrationChanged,
  });

  @override
  State<QuickActionBar> createState() => _QuickActionBarState();
}

class _QuickActionBarState extends State<QuickActionBar> {
  bool _loading = false;

  Future<void> _register() async {
    setState(() => _loading = true);
    try {
      final api = context.read<EventProvider>();
      final result = await api.register(widget.event.id);
      widget.onRegistrationChanged();
      if (!mounted) return;
      context.read<EventProvider>().loadEvent(widget.event.id);
      final status = result.status;
      final event = context.read<EventProvider>().selectedEvent;
      final isSelling = event?.status == EventStatus.selling_tickets ||
          event?.status == EventStatus.live;
      if (status == 'waitlisted') {
        AppToast.info(
            context,
            isSelling
                ? 'Event is at capacity. Once the organizer approves, you can buy tickets.'
                : 'Event is at capacity. Your registration is waiting for organizer approval.');
      } else {
        AppToast.success(context,
            isSelling ? 'Registered! You can now buy tickets.' : 'Registered successfully!');
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.fromError(context, e, fallback: 'Registration failed');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _unregister() async {
    final event = context.read<EventProvider>().selectedEvent;
    final bool refundEligible = event?.isRefundEligible ?? true;
    final deadlineDays = event?.refundDeadlineDays ?? 7;

    String message;
    if (refundEligible) {
      message =
          'Are you sure you want to unregister? Your pledged amount will be fully refunded.';
    } else {
      message =
          'The refund deadline has passed ($deadlineDays day${deadlineDays == 1 ? '' : 's'} before event start).\n\n'
          'If you unregister now, your pledged amount will NOT be refunded.\n\n'
          'Are you sure you want to proceed?';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unregister'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  refundEligible ? AppTheme.warningColor : AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: Text(
                refundEligible ? 'Unregister' : 'Unregister (No Refund)'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      final api = context.read<EventProvider>();
      final result = await api.unregister(widget.event.id);
      widget.onRegistrationChanged();
      if (!mounted) return;
      context.read<EventProvider>().loadEvent(widget.event.id);
      final refunded = result.refundedCents;
      final pledges = result.pledgesRefunded;
      final wasRefunded = result.refundEligible;
      String msg;
      if (wasRefunded && pledges > 0) {
        msg =
            'Unregistered successfully. Refunded \$${(refunded / 100).toStringAsFixed(2)} from $pledges pledge(s).';
      } else if (!wasRefunded) {
        msg =
            'Unregistered successfully. No refund — the refund deadline had passed.';
      } else {
        msg = 'Unregistered successfully.';
      }
      AppToast.success(context, msg);
    } catch (e) {
      if (!mounted) return;
      AppToast.fromError(context, e, fallback: 'Unregister failed');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isCustomer = user != null && user.isCustomer;
    final event = widget.event;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: AppRadius.lg,
      ),
      child: Row(
        children: [
          if (isCustomer && event.canUnregister)
            Expanded(
              flex: 3,
              child: widget.ageBlocked
                  ? _quickActionBtn(
                      icon: Icons.block,
                      label: '${event.minAge}+ Only',
                      color: AppTheme.errorColor.withValues(alpha: 0.5),
                      filled: false,
                      onTap: null,
                    )
                  : widget.isRegistered && widget.regStatus == 'registered'
                      ? _quickActionBtn(
                          icon: Icons.check_circle,
                          label: 'Registered',
                          color: AppTheme.successColor,
                          filled: true,
                          onTap: _loading ? null : _unregister,
                          trailing: Icon(Icons.close,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.7)),
                        )
                      : _quickActionBtn(
                          icon: widget.regStatus == 'waitlisted'
                              ? Icons.hourglass_top
                              : Icons.how_to_reg,
                          label: widget.regStatus == 'waitlisted'
                              ? 'Waiting Approval'
                              : 'Register',
                          color: widget.regStatus == 'waitlisted'
                              ? AppTheme.warningColor
                              : AppTheme.accentColor,
                          filled: widget.regStatus != 'waitlisted',
                          onTap: _loading || widget.regStatus == 'waitlisted'
                              ? null
                              : _register,
                        ),
            ),
        ],
      ),
    );
  }

  Widget _quickActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required bool filled,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return PressFeedback(
      child: Material(
        color: filled ? color : Colors.transparent,
        borderRadius: AppRadius.md,
        child: InkWell(
          borderRadius: AppRadius.md,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
                vertical: 10, horizontal: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: AppIconSize.sm,
                    color: filled ? Colors.white : color),
                AppSpacing.hXs,
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: filled ? Colors.white : color,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 4),
                  trailing,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
