import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../models/event.dart';
import '../../../services/api_service.dart';

// ═══════════════════════════════════════════
// Live Management Stats — clickable stat chips
// (sold, scanned, waitlist, revenue)
// ═══════════════════════════════════════════

class LiveMgmtStats extends StatefulWidget {
  final Event event;
  const LiveMgmtStats({required this.event});

  @override
  State<LiveMgmtStats> createState() => _LiveMgmtStatsState();
}

class _LiveMgmtStatsState extends State<LiveMgmtStats> {
  int _soldCount = 0;
  int _scannedCount = 0;
  int _fundingWaitlistCount = 0;
  int _ticketWaitlistCount = 0;
  bool _loading = true;

  Event get _event => widget.event;
  int get _eventId => _event.id;

  bool get _isEarlyPhase =>
      _event.status == EventStatus.draft ||
      _event.status == EventStatus.pending_approval ||
      _event.status == EventStatus.approved ||
      _event.status == EventStatus.waiting_event_date;

  bool get _isTicketPhase =>
      _event.status == EventStatus.selling_tickets ||
      _event.status == EventStatus.live;

  bool get _isCompleted => _event.status == EventStatus.completed;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();

      if (_isEarlyPhase) {
        // Only need registrations for early phases
        final regs = await api.getRegistrations(_eventId);
        final waitlisted =
            regs.where((r) => r['status'] == 'waitlist').length;
        if (mounted) {
          setState(() {
            _fundingWaitlistCount = waitlisted;
            _loading = false;
          });
        }
      } else {
        // Ticket & completed phases: load everything
        final results = await Future.wait([
          api.getTicketSales(_eventId),
          api.getScannedTickets(_eventId),
          api.getRegistrations(_eventId),
          api.getWaitlistedTickets(_eventId),
        ]);
        final allSales = results[0];
        final scanned = results[1];
        final regs = results[2];
        final ticketWaitlist = results[3];
        final fundingWaitlisted =
            regs.where((r) => r['status'] == 'waitlist').length;
        if (mounted) {
          setState(() {
            _soldCount = allSales.length;
            _scannedCount = scanned.length;
            _fundingWaitlistCount = fundingWaitlisted;
            _ticketWaitlistCount = ticketWaitlist.length;
            _loading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final reservedCount = _event.totalReservedSpots;
    final soldCount = _event.ticketsSoldCount;
    final filledCount = reservedCount + soldCount; // capacity used = reserved + sold
    final maxCap = _event.maxCapacity;
    final isFull = maxCap > 0 && filledCount >= maxCap;

    // ── Early Phases ──
    if (_isEarlyPhase) {
      return Column(
        children: [
          _statChip(
            icon: Icons.hourglass_top_rounded,
            label: '$_fundingWaitlistCount fund waitlist',
            color: AppTheme.warningColor,
            onTap: () => context.push('/events/$_eventId/waitlist'),
          ),
          const SizedBox(height: 8),
          _capacityBadge(filledCount, maxCap, isFull),
        ],
      );
    }

    // ── Selling Tickets / Live ──
    if (_isTicketPhase) {
      return Column(
        children: [
          _capacityBadge(filledCount, maxCap, isFull),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _statChip(
                  icon: Icons.confirmation_number_rounded,
                  label: '$_soldCount sold',
                  color: AppTheme.accentColor,
                  onTap: () => context.push('/events/$_eventId/ticket-sales'),
                ),
              ),
              AppSpacing.hSm,
              Expanded(
                child: _statChip(
                  icon: Icons.qr_code_scanner_rounded,
                  label: '$_scannedCount scanned',
                  color: AppTheme.successColor,
                  onTap: () => context.push('/events/$_eventId/scanned-tickets'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _statChip(
            icon: Icons.event_seat_rounded,
            label: '$_ticketWaitlistCount ticket waitlist',
            color: Colors.orange,
            onTap: () => context.push('/events/$_eventId/ticket-waitlist'),
          ),
        ],
      );
    }

    // ── Completed ── (read-only summary)
    if (_isCompleted) {
      return Column(
        children: [
          _capacityBadge(filledCount, maxCap, isFull),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _statChip(
                  icon: Icons.confirmation_number_rounded,
                  label: '$_soldCount sold',
                  color: AppTheme.accentColor,
                  onTap: () => context.push('/events/$_eventId/ticket-sales'),
                ),
              ),
              AppSpacing.hSm,
              Expanded(
                child: _statChip(
                  icon: Icons.qr_code_scanner_rounded,
                  label: '$_scannedCount scanned',
                  color: AppTheme.successColor,
                  onTap: () => context.push('/events/$_eventId/scanned-tickets'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _statChip(
                  icon: Icons.hourglass_top_rounded,
                  label: '$_fundingWaitlistCount fund wl',
                  color: AppTheme.warningColor,
                  onTap: () => context.push('/events/$_eventId/waitlist'),
                ),
              ),
              AppSpacing.hSm,
              Expanded(
                child: _statChip(
                  icon: Icons.event_seat_rounded,
                  label: '$_ticketWaitlistCount ticket wl',
                  color: Colors.orange,
                  onTap: () => context.push('/events/$_eventId/ticket-waitlist'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Fallback (cancelled / unknown)
    return const SizedBox.shrink();
  }

  // ── Capacity badge ──
  Widget _capacityBadge(int registered, int maxCap, bool isFull) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rawColor = isFull ? AppTheme.errorColor : AppTheme.accentColor;
    final color = isDark && _isNearBlack(rawColor) ? AppTheme.accentColor : rawColor;
    final textColor = isDark ? Colors.white : color;
    final label = maxCap > 0
        ? '$registered / $maxCap capacity'
        : '$registered registered';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.cardOf(context)
            : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.4 : 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFull ? Icons.warning_rounded : Icons.people_rounded,
            size: 18,
            color: textColor,
          ),
          AppSpacing.hSm,
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          if (maxCap > 0) ...[
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: maxCap > 0 ? (registered / maxCap).clamp(0.0, 1.0) : 0,
                  minHeight: 6,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : color.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
          ],
          if (isFull) ...[
            const SizedBox(width: 6),
            Text('FULL',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    letterSpacing: 1)),
          ],
        ],
      ),
    );
  }

  // ── Stat chip (tappable) ──
  Widget _statChip({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipColor = isDark && _isNearBlack(color)
        ? AppTheme.accentColor
        : color;
    final textColor = isDark ? Colors.white : chipColor;
    return Material(
      color: isDark
          ? AppTheme.cardOf(context)
          : chipColor.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: chipColor.withValues(alpha: isDark ? 0.35 : 0.15),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: chipColor),
              AppSpacing.hSm,
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 16, color: textColor.withValues(alpha: 0.5)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Returns true if a color is near-black (e.g. AppTheme.primaryColor #141414).
  bool _isNearBlack(Color c) =>
      c.r < 0.15 && c.g < 0.15 && c.b < 0.15;
}
