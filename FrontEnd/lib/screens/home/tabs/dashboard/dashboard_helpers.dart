import 'package:flutter/material.dart';

import '../../../../utils/date_time_utils.dart';

const periodOptions = {'7d': '7d', '30d': '30d', '90d': '90d', '1y': '1y'};
const periodToDays = {'7d': 7, '30d': 30, '90d': 90, '1y': 365};

String dashFormatCents(int cents) {
  if (cents >= 100000) return '\$${(cents / 100).toStringAsFixed(0)}';
  return '\$${(cents / 100).toStringAsFixed(2)}';
}

String dashRelativeTime(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return AppDateFormat.dateOnly(dt);
}

IconData kpiIcon(String kpi) => switch (kpi) {
      'tickets' => Icons.confirmation_number_rounded,
      'backers' => Icons.volunteer_activism_rounded,
      'sponsors' => Icons.handshake_rounded,
      'events' => Icons.event_rounded,
      _ => Icons.bar_chart_rounded,
    };

String kpiSectionTitle(String kpi) => switch (kpi) {
      'tickets' => 'Events with Ticket Sales',
      'backers' => 'Events with Backers',
      'sponsors' => 'Sponsored Events',
      'events' => 'All Events',
      _ => 'Events',
    };

String kpiEmptyTitle(String kpi) => switch (kpi) {
      'tickets' => 'No ticket sales',
      'backers' => 'No backers yet',
      'sponsors' => 'No sponsors yet',
      'events' => 'No events',
      _ => 'No events',
    };

String kpiEmptySubtitle(String kpi) => switch (kpi) {
      'tickets' => 'None of your events have sold tickets',
      'backers' => 'None of your events have received pledges',
      'sponsors' => 'None of your events have sponsors',
      'events' => 'You have not created any events yet',
      _ => 'No matching events found',
    };
