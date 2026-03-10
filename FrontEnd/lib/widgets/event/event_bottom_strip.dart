import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/design_tokens.dart';
import '../config/theme.dart';
import '../models/event.dart';
import '../providers/auth_provider.dart';
import '../providers/event_provider.dart';
import '../widgets/app_toast.dart';
import '../widgets/press_feedback.dart';

/// Premium frosted-glass bottom action strip for the event detail screen.
///
/// Shows a Register / Unregister button (and an optional Pledge button when
/// [onPledgeTap] is supplied). Replaces the scroll-gated [QuickActionBar] in
/// [bottomNavigationBar] so the primary action is always reachable.
class EventBottomStrip extends StatefulWidget {
  final Event event;
  final bool isRegistered;
  final String? regStatus;
  final bool ageBlocked;
  final void Function(bool isRegistered, String? status) onRegistrationChanged;

  /// When provided, a Pledge button is shown alongside Register.
  final VoidCallback? onPledgeTap;

  const EventBottomStrip({
    super.key,
    required this.event,
    required this.isRegistered,
    this.regStatus,
    this.ageBlocked = false,
    required this.onRegistrationChanged,
    this.onPledgeTap,
  });

  @override
  State<EventBottomStrip> createState() => _EventBottomStripState();
}

class _EventBottomStripState extends State<EventBottomStrip> {
  bool _loading = false;

  // ── Registration actions (same logic as QuickActionBar) ──

  Future<void> _register() async {
    setState(() => _loading = true);
    try {
      final api = context.read<EventProvider>();
      final result = await api.register(widget.event.id);
      widget.onRegistrationChanged(true, result.status);
      if (!mounted) return;
      context.read<EventProvider>().patchRegistrationCount(widget.event.id, 1);
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
              : 'Event is at capacity. Your registration is waiting for organizer approval.',
        );
      } else {
        AppToast.success(
          context,
          isSelling ? 'Registered! You can now buy tickets.' : 'Registered successfully!',
        );
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

    final message = refundEligible
        ? 'Are you sure you want to unregister? Your pledged amount will be fully refunded.'
        : 'The refund deadline has passed ($deadlineDays day${deadlineDays == 1 ? '' : 's'} before event start).\n\n'
            'If you unregister now, your pledged amount will NOT be refunded.\n\n'
            'Are you sure you want to proceed?';

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
            child: Text(refundEligible ? 'Unregister' : 'Unregister (No Refund)'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      final api = context.read<EventProvider>();
      final result = await api.unregister(widget.event.id);
      widget.onRegistrationChanged(false, null);
      if (!mounted) return;
      context.read<EventProvider>().patchRegistrationCount(widget.event.id, -1);
      context.read<EventProvider>().loadEvent(widget.event.id);
      final refunded = result.refundedCents;
      final pledges = result.pledgesRefunded;
      final wasRefunded = result.refundEligible;
      String msg;
      if (wasRefunded && pledges > 0) {
        msg = 'Unregistered. Refunded \$${(refunded / 100).toStringAsFixed(2)} from $pledges pledge(s).';
      } else if (!wasRefunded) {
        msg = 'Unregistered. No refund — the refund deadline had passed.';
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

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isCustomer = user != null && user.isCustomer;
    final event = widget.event;

    // Nothing to show for non-customers or events that don't allow registration
    if (!isCustomer || !event.canUnregister) return const SizedBox.shrink();

    final bottomPad = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomPad),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E1E1E).withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.88),
            border: Border(
              top: BorderSide(
                color: AppTheme.dividerOf(context),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // Register / Unregister button
              Expanded(
                flex: widget.onPledgeTap != null ? 5 : 1,
                child: _buildRegisterButton(context, event),
              ),
              // Pledge button (optional)
              if (widget.onPledgeTap != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: _StripButton(
                    icon: Icons.volunteer_activism_rounded,
                    label: 'Pledge',
                    // Amber gradient — matches combined_design.html #FF8C00 → #FFC043
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF8C00), Color(0xFFFFC043)],
                    ),
                    height: 54,
                    onTap: widget.onPledgeTap,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterButton(BuildContext context, Event event) {
    if (widget.ageBlocked) {
      return _StripButton(
        icon: Icons.block_rounded,
        label: '${event.minAge}+ Only',
        solidColor: AppTheme.errorColor.withValues(alpha: 0.55),
        height: 54,
        onTap: null,
      );
    }

    if (widget.isRegistered && widget.regStatus == 'registered') {
      return _StripButton(
        icon: Icons.check_circle_rounded,
        label: 'Registered',
        solidColor: AppTheme.successColor,
        trailing: Icon(
          Icons.close_rounded,
          size: 14,
          color: Colors.white.withValues(alpha: 0.75),
        ),
        height: 54,
        onTap: _loading ? null : _unregister,
      );
    }

    if (widget.regStatus == 'waitlisted') {
      return _StripButton(
        icon: Icons.hourglass_top_rounded,
        label: 'Waiting Approval',
        solidColor: const Color(0xFFFFC043),
        labelColor: const Color(0xFF5C3000),
        height: 54,
        onTap: null,
      );
    }

    // Default: Register CTA — near-black in light, near-white in dark (matches combined design)
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _StripButton(
      icon: Icons.how_to_reg_rounded,
      label: 'Register',
      solidColor: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF0F0F0F),
      labelColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
      height: 54,
      isLoading: _loading,
      onTap: _loading ? null : _register,
    );
  }
}

// ─── Private strip button ───

class _StripButton extends StatelessWidget {
  final IconData icon;
  final String label;
  /// Gradient fill — takes priority over [solidColor].
  final LinearGradient? gradient;
  /// Flat solid background (used when gradient is null).
  final Color? solidColor;
  /// Label + icon foreground colour (defaults to white).
  final Color labelColor;
  final double height;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isLoading;

  const _StripButton({
    required this.icon,
    required this.label,
    required this.height,
    this.gradient,
    this.solidColor,
    this.labelColor = Colors.white,
    this.onTap,
    this.trailing,
    this.isLoading = false,
  }) : assert(gradient != null || solidColor != null,
            'Provide either gradient or solidColor');

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final shadowColor =
        gradient?.colors.first ?? solidColor ?? Colors.transparent;

    return PressFeedback(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: disabled ? 0.55 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          height: height,
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null ? solidColor : null,
            borderRadius: AppRadius.lg,
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: shadowColor.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: AppRadius.lg,
            child: InkWell(
              borderRadius: AppRadius.lg,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLoading)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(labelColor),
                        ),
                      )
                    else
                      Icon(icon, size: 18, color: labelColor),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: labelColor,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 6),
                      trailing!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
