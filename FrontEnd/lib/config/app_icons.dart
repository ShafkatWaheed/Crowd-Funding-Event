import 'package:flutter/material.dart';

import '../models/event.dart';
import '../models/funding.dart';
import 'theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  EventDetailFieldMeta — icon + color for detail row fields
// ═══════════════════════════════════════════════════════════════════════════

class EventDetailFieldMeta {
  final IconData icon;
  final Color Function(bool isDark) color;
  const EventDetailFieldMeta({required this.icon, required this.color});
}

// ═══════════════════════════════════════════════════════════════════════════
//  EventStatusMeta — icon + color + gradient + display name per event status
// ═══════════════════════════════════════════════════════════════════════════

class EventStatusMeta {
  final String displayName;
  final IconData icon;
  final Color Function(bool isDark) color;
  final List<Color> gradientColors;

  const EventStatusMeta({
    required this.displayName,
    required this.icon,
    required this.color,
    required this.gradientColors,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
//  AppIcons — single source of truth for all status/genre icon+color tokens
// ═══════════════════════════════════════════════════════════════════════════

class AppIcons {
  AppIcons._();

  // ─── Event Status ──────────────────────────────────────────────────────

  static EventStatusMeta forEventStatus(EventStatus s) {
    switch (s) {
      case EventStatus.draft:
        return EventStatusMeta(
          displayName: 'Draft',
          icon: Icons.edit_note_rounded,
          color: (isDark) => isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575),
          gradientColors: const [Color(0xFF616161), Color(0xFF424242)],
        );
      case EventStatus.pending_approval:
        return EventStatusMeta(
          displayName: 'Waiting Approval',
          icon: Icons.hourglass_top_rounded,
          color: (isDark) => isDark ? const Color(0xFFFFB74D) : const Color(0xFFF59E0B),
          gradientColors: const [Color(0xFFF59E0B), Color(0xFFE65100)],
        );
      case EventStatus.approved:
        return EventStatusMeta(
          displayName: 'Funding',
          icon: Icons.rocket_launch_rounded,
          color: (isDark) => isDark ? const Color(0xFF90CAF9) : AppTheme.accentColor,
          gradientColors: const [Color(0xFF276EF1), Color(0xFF1A56D6)],
        );
      case EventStatus.selling_tickets:
        return EventStatusMeta(
          displayName: 'Selling Tickets',
          icon: Icons.confirmation_number_rounded,
          color: (isDark) => isDark ? const Color(0xFF4DD0E1) : AppTheme.cyanColor,
          gradientColors: const [Color(0xFF0891B2), Color(0xFF0E7490)],
        );
      case EventStatus.waiting_event_date:
        return EventStatusMeta(
          displayName: 'Awaiting Date',
          icon: Icons.pending_actions_rounded,
          color: (isDark) => isDark ? const Color(0xFFFFB74D) : const Color(0xFFEA580C),
          gradientColors: const [Color(0xFFEA580C), Color(0xFFC2410C)],
        );
      case EventStatus.live:
        return EventStatusMeta(
          displayName: 'Live',
          icon: Icons.sensors_rounded,
          color: (isDark) => isDark ? const Color(0xFF66BB6A) : AppTheme.secondaryColor,
          gradientColors: const [Color(0xFF05944F), Color(0xFF0A7544)],
        );
      case EventStatus.completed:
        return EventStatusMeta(
          displayName: 'Completed',
          icon: Icons.emoji_events_rounded,
          color: (isDark) => isDark ? const Color(0xFFBB86FC) : AppTheme.purpleColor,
          gradientColors: const [Color(0xFF9333EA), Color(0xFF7C3AED)],
        );
      case EventStatus.cancelled:
        return EventStatusMeta(
          displayName: 'Cancelled',
          icon: Icons.event_busy_rounded,
          color: (isDark) => isDark ? const Color(0xFFEF5350) : const Color(0xFF9B1C1C),
          gradientColors: const [Color(0xFF9B1C1C), Color(0xFF7F1D1D)],
        );
      case EventStatus.under_review:
        return EventStatusMeta(
          displayName: 'Under Review',
          icon: Icons.manage_search_rounded,
          color: (isDark) => isDark ? const Color(0xFFFFD54F) : AppTheme.yellowColor,
          gradientColors: const [Color(0xFFEAB308), Color(0xFFCA8A04)],
        );
    }
  }

  // ─── Genre Icons ───────────────────────────────────────────────────────

  static IconData genreIcon(String genre) {
    switch (genre.toLowerCase()) {
      case 'community':  return Icons.people_rounded;
      case 'music':      return Icons.music_note_rounded;
      case 'tech':       return Icons.computer_rounded;
      case 'sports':     return Icons.sports_soccer_rounded;
      case 'arts':       return Icons.palette_rounded;
      case 'food':       return Icons.restaurant_rounded;
      case 'charity':    return Icons.favorite_rounded;
      case 'education':  return Icons.school_rounded;
      case 'business':   return Icons.business_center_rounded;
      default:           return Icons.category_rounded;
    }
  }

  static Color genreColor(String genre, {bool isDark = false}) {
    switch (genre.toLowerCase()) {
      case 'community':  return isDark ? const Color(0xFFFFB74D) : const Color(0xFFF59E0B);
      case 'music':      return isDark ? const Color(0xFFBB86FC) : AppTheme.purpleColor;
      case 'tech':       return isDark ? const Color(0xFF90CAF9) : AppTheme.accentColor;
      case 'sports':     return isDark ? const Color(0xFF66BB6A) : AppTheme.secondaryColor;
      case 'arts':       return isDark ? const Color(0xFFE040FB) : AppTheme.magentaColor;
      case 'food':       return isDark ? const Color(0xFFFFB74D) : const Color(0xFFEA580C);
      case 'charity':    return isDark ? const Color(0xFFEF5350) : AppTheme.errorColor;
      case 'education':  return isDark ? const Color(0xFF4DB6AC) : AppTheme.tealColor;
      case 'business':   return isDark ? const Color(0xFF90A4AE) : AppTheme.slateColor;
      default:           return isDark ? const Color(0xFF9E9E9E) : const Color(0xFF6B7280);
    }
  }

  // ─── Ticket Status ─────────────────────────────────────────────────────

  static IconData ticketStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'purchased':         return Icons.confirmation_number_rounded;
      case 'waitlisted':        return Icons.queue_rounded;
      case 'refund_requested':  return Icons.assignment_return_rounded;
      case 'refund_processing': return Icons.sync_rounded;
      case 'refunded':          return Icons.currency_exchange_rounded;
      case 'refund_failed':     return Icons.error_outline_rounded;
      case 'cancelled':         return Icons.block_rounded;
      default:                  return Icons.confirmation_number_rounded;
    }
  }

  static Color ticketStatusColor(String status, {bool isDark = false}) {
    switch (status.toLowerCase()) {
      case 'purchased':         return isDark ? const Color(0xFF66BB6A) : AppTheme.secondaryColor;
      case 'waitlisted':        return isDark ? const Color(0xFFFFB74D) : const Color(0xFFF59E0B);
      case 'refund_requested':  return isDark ? const Color(0xFFFFB74D) : const Color(0xFFEA580C);
      case 'refund_processing': return isDark ? const Color(0xFF4DD0E1) : AppTheme.cyanColor;
      case 'refunded':          return isDark ? const Color(0xFF90CAF9) : AppTheme.accentColor;
      case 'refund_failed':     return isDark ? const Color(0xFFEF5350) : AppTheme.errorColor;
      case 'cancelled':         return isDark ? const Color(0xFF9E9E9E) : const Color(0xFF6B7280);
      default:                  return isDark ? const Color(0xFF9E9E9E) : const Color(0xFF6B7280);
    }
  }

  // ─── Pledge / Funding Status ───────────────────────────────────────────

  static IconData pledgeStatusIcon(PledgeStatus status) {
    switch (status) {
      case PledgeStatus.pledged:   return Icons.handshake_rounded;
      case PledgeStatus.collected: return Icons.handshake_rounded;
      case PledgeStatus.refunded:  return Icons.currency_exchange_rounded;
    }
  }

  static Color pledgeStatusColor(PledgeStatus status, {bool isDark = false}) {
    switch (status) {
      case PledgeStatus.pledged:   return isDark ? const Color(0xFFFFB74D) : AppTheme.orangeColor;
      case PledgeStatus.collected: return isDark ? const Color(0xFF66BB6A) : AppTheme.secondaryColor;
      case PledgeStatus.refunded:  return isDark ? const Color(0xFF90CAF9) : AppTheme.accentColor;
    }
  }

  // ─── Donation (guest pledge) ───────────────────────────────────────────

  static const IconData donationIcon = Icons.card_giftcard_rounded;

  static Color donationColor({bool isDark = false}) =>
      isDark ? const Color(0xFFE040FB) : AppTheme.magentaColor;

  // ─── Event Detail Row Fields ───────────────────────────────────────────

  static final EventDetailFieldMeta detailStarts = EventDetailFieldMeta(
    icon: Icons.play_circle_rounded,
    color: (isDark) => isDark ? const Color(0xFF66BB6A) : AppTheme.secondaryColor,
  );
  static final EventDetailFieldMeta detailEnds = EventDetailFieldMeta(
    icon: Icons.stop_circle_rounded,
    color: (isDark) => isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575),
  );
  static final EventDetailFieldMeta detailDateTbd = EventDetailFieldMeta(
    icon: Icons.calendar_month_rounded,
    color: (isDark) => isDark ? const Color(0xFFFFB74D) : AppTheme.orangeColor,
  );
  static final EventDetailFieldMeta detailCapacity = EventDetailFieldMeta(
    icon: Icons.groups_rounded,
    color: (isDark) => isDark ? const Color(0xFF90CAF9) : AppTheme.accentColor,
  );
  static final EventDetailFieldMeta detailTicketsSold = EventDetailFieldMeta(
    icon: Icons.confirmation_number_rounded,
    color: (isDark) => isDark ? const Color(0xFF4DD0E1) : AppTheme.cyanColor,
  );
  static final EventDetailFieldMeta detailRegistration = EventDetailFieldMeta(
    icon: Icons.how_to_reg_rounded,
    color: (isDark) => isDark ? const Color(0xFF4DB6AC) : AppTheme.tealColor,
  );
  static final EventDetailFieldMeta detailSetDateBy = EventDetailFieldMeta(
    icon: Icons.timer_rounded,
    color: (isDark) => isDark ? const Color(0xFFFFD54F) : AppTheme.warningColor,
  );
  static final EventDetailFieldMeta detailTicketStrategy = EventDetailFieldMeta(
    icon: Icons.layers_rounded,
    color: (isDark) => isDark ? const Color(0xFFBB86FC) : AppTheme.purpleColor,
  );
  static final EventDetailFieldMeta detailRefund = EventDetailFieldMeta(
    icon: Icons.assignment_return_rounded,
    color: (isDark) => isDark ? const Color(0xFF66BB6A) : AppTheme.secondaryColor,
  );

  // ─── Getting There Row Fields ──────────────────────────────────────────

  static final EventDetailFieldMeta venueHeader = EventDetailFieldMeta(
    icon: Icons.near_me_rounded,
    color: (isDark) => isDark ? const Color(0xFF90CAF9) : AppTheme.accentColor,
  );
  static final EventDetailFieldMeta venueName = EventDetailFieldMeta(
    icon: Icons.location_city_rounded,
    color: (isDark) => isDark ? const Color(0xFF90CAF9) : AppTheme.accentColor,
  );
  static final EventDetailFieldMeta venueAddress = EventDetailFieldMeta(
    icon: Icons.pin_drop_rounded,
    color: (isDark) => isDark ? const Color(0xFFEF5350) : AppTheme.errorColor,
  );
  static final EventDetailFieldMeta venueParking = EventDetailFieldMeta(
    icon: Icons.local_parking_rounded,
    color: (isDark) => isDark ? const Color(0xFF90CAF9) : AppTheme.accentColor,
  );
  static final EventDetailFieldMeta venueTransit = EventDetailFieldMeta(
    icon: Icons.train_rounded,
    color: (isDark) => isDark ? const Color(0xFF66BB6A) : AppTheme.secondaryColor,
  );
  static final EventDetailFieldMeta venueRideshare = EventDetailFieldMeta(
    icon: Icons.local_taxi_rounded,
    color: (isDark) => isDark ? const Color(0xFFFFD54F) : AppTheme.warningColor,
  );
  static final EventDetailFieldMeta venueAccessibility = EventDetailFieldMeta(
    icon: Icons.accessible_rounded,
    color: (isDark) => isDark ? const Color(0xFF4DB6AC) : AppTheme.tealColor,
  );

  // ─── Event Card Stat Chips ─────────────────────────────────────────────

  static final EventDetailFieldMeta cardTime = EventDetailFieldMeta(
    icon: Icons.access_time_rounded,
    color: (isDark) => isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575),
  );
  static final EventDetailFieldMeta cardLocation = EventDetailFieldMeta(
    icon: Icons.location_on_rounded,
    color: (isDark) => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
  );
  static final EventDetailFieldMeta cardLikes = EventDetailFieldMeta(
    icon: Icons.favorite_rounded,
    color: (isDark) => isDark ? const Color(0xFFF472B6) : AppTheme.magentaColor,
  );
  static final EventDetailFieldMeta cardAttendees = EventDetailFieldMeta(
    icon: Icons.group_rounded,
    color: (isDark) => isDark ? const Color(0xFF90CAF9) : AppTheme.accentColor,
  );
  static final EventDetailFieldMeta cardTickets = EventDetailFieldMeta(
    icon: Icons.confirmation_number_rounded,
    color: (isDark) => isDark ? const Color(0xFF4DD0E1) : AppTheme.cyanColor,
  );
}
