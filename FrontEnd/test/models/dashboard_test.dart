import 'package:flutter_test/flutter_test.dart';
import 'package:crowd_funding_app/models/dashboard.dart';
import '../helpers/fixtures.dart';

void main() {
  group('KpiItem', () {
    test('fromJson parses value and deltaPercent', () {
      final k = KpiItem.fromJson({'value': 120, 'delta_percent': 9.5});
      expect(k.value, 120);
      expect(k.deltaPercent, 9.5);
    });

    test('defaults when fields are null', () {
      final k = KpiItem.fromJson({});
      expect(k.value, 0);
      expect(k.deltaPercent, isNull);
    });
  });

  group('KpiFloatItem', () {
    test('fromJson parses value and deltaPercent', () {
      final k = KpiFloatItem.fromJson({'value': 2.5, 'delta_percent': -16.7});
      expect(k.value, 2.5);
      expect(k.deltaPercent, -16.7);
    });

    test('defaults when fields are null', () {
      final k = KpiFloatItem.fromJson({});
      expect(k.value, 0.0);
      expect(k.deltaPercent, isNull);
    });

    test('handles int value gracefully', () {
      final k = KpiFloatItem.fromJson({'value': 3});
      expect(k.value, 3.0);
    });
  });

  group('StatusBreakdown', () {
    test('fromJson parses status and count', () {
      final s = StatusBreakdown.fromJson({'status': 'approved', 'count': 5});
      expect(s.status, 'approved');
      expect(s.count, 5);
    });

    test('count defaults to 0', () {
      final s = StatusBreakdown.fromJson({'status': 'live'});
      expect(s.count, 0);
    });
  });

  group('ActivityFeedItem', () {
    test('fromJson parses all fields', () {
      final json = {
        'type': 'ticket_purchase',
        'event_id': 1,
        'event_title': 'Rock Concert',
        'actor_name': 'Alice',
        'amount_cents': 5000,
        'extra': {'tier': 'VIP'},
        'created_at': '2025-02-01T10:00:00',
      };
      final a = ActivityFeedItem.fromJson(json);

      expect(a.type, 'ticket_purchase');
      expect(a.eventId, 1);
      expect(a.eventTitle, 'Rock Concert');
      expect(a.actorName, 'Alice');
      expect(a.amountCents, 5000);
      expect(a.extra, isNotNull);
      expect(a.extra!['tier'], 'VIP');
      expect(a.createdAt, DateTime.parse('2025-02-01T10:00:00'));
    });

    test('defaults for optional fields', () {
      final json = {
        'type': 'pledge',
        'event_id': 2,
        'created_at': '2025-02-01T10:00:00',
      };
      final a = ActivityFeedItem.fromJson(json);

      expect(a.eventTitle, '');
      expect(a.actorName, '');
      expect(a.amountCents, 0);
      expect(a.extra, isNull);
    });
  });

  group('OrganizerDashboard', () {
    test('fromJson parses full dashboard payload', () {
      final json = {
        'total_revenue': {'value': 600000, 'delta_percent': 9.1},
        'tickets_sold': {'value': 120, 'delta_percent': 9.1},
        'total_backers': {'value': 45, 'delta_percent': 12.5},
        'total_events': {'value': 5, 'delta_percent': 25.0},
        'total_sponsors': {'value': 3, 'delta_percent': 50.0},
        'refund_rate': {'value': 2.5, 'delta_percent': -16.7},
        'status_breakdown': [
          {'status': 'approved', 'count': 2},
          {'status': 'completed', 'count': 3},
        ],
        'top_events': [eventJson(id: 1, title: 'Top Event')],
        'trending_events': [eventJson(id: 2, title: 'Trending Event')],
        'popular_events': [eventJson(id: 3, title: 'Popular Event')],
        'recent_activity': [
          {
            'type': 'pledge',
            'event_id': 1,
            'event_title': 'Music Fest',
            'actor_name': 'Bob',
            'amount_cents': 2000,
            'created_at': '2025-02-01T10:00:00',
          }
        ],
      };
      final d = OrganizerDashboard.fromJson(json);

      expect(d.totalRevenue.value, 600000);
      expect(d.ticketsSold.value, 120);
      expect(d.totalBackers.value, 45);
      expect(d.totalEvents.value, 5);
      expect(d.totalSponsors.value, 3);
      expect(d.refundRate.value, 2.5);
      expect(d.statusBreakdown.length, 2);
      expect(d.statusBreakdown[0].status, 'approved');
      expect(d.topEvents.length, 1);
      expect(d.topEvents[0].title, 'Top Event');
      expect(d.trendingEvents.length, 1);
      expect(d.trendingEvents[0].title, 'Trending Event');
      expect(d.popularEvents.length, 1);
      expect(d.popularEvents[0].title, 'Popular Event');
      expect(d.recentActivity.length, 1);
      expect(d.recentActivity[0].type, 'pledge');
    });

    test('empty lists when not provided', () {
      final json = {
        'total_revenue': {'value': 0},
        'tickets_sold': {'value': 0},
        'total_backers': {'value': 0},
        'total_events': {'value': 0},
        'total_sponsors': {'value': 0},
        'refund_rate': {'value': 0.0},
      };
      final d = OrganizerDashboard.fromJson(json);

      expect(d.statusBreakdown, isEmpty);
      expect(d.topEvents, isEmpty);
      expect(d.trendingEvents, isEmpty);
      expect(d.popularEvents, isEmpty);
      expect(d.recentActivity, isEmpty);
    });
  });

  group('TimeSeriesPoint', () {
    test('fromJson parses all fields', () {
      final p = TimeSeriesPoint.fromJson({
        'date': '2025-02-01',
        'revenue_cents': 50000,
        'tickets_sold': 10,
        'pledges_count': 5,
      });
      expect(p.date, '2025-02-01');
      expect(p.revenueCents, 50000);
      expect(p.ticketsSold, 10);
      expect(p.pledgesCount, 5);
    });

    test('defaults for missing fields', () {
      final p = TimeSeriesPoint.fromJson({'date': '2025-02-02'});
      expect(p.revenueCents, 0);
      expect(p.ticketsSold, 0);
      expect(p.pledgesCount, 0);
    });
  });

  group('OrganizerTimeSeries', () {
    test('fromJson parses points and granularity', () {
      final json = {
        'points': [
          {'date': '2025-02-01', 'revenue_cents': 1000, 'tickets_sold': 2, 'pledges_count': 1},
          {'date': '2025-02-02', 'revenue_cents': 2000, 'tickets_sold': 3, 'pledges_count': 2},
        ],
        'granularity': 'weekly',
      };
      final ts = OrganizerTimeSeries.fromJson(json);

      expect(ts.points.length, 2);
      expect(ts.points[0].date, '2025-02-01');
      expect(ts.points[1].revenueCents, 2000);
      expect(ts.granularity, 'weekly');
    });

    test('defaults for empty data', () {
      final ts = OrganizerTimeSeries.fromJson({});
      expect(ts.points, isEmpty);
      expect(ts.granularity, 'daily');
    });
  });

  group('CustomerHistoryItem', () {
    test('fromJson parses all fields', () {
      final json = {
        'customer_id': 42,
        'customer_name': 'Alice',
        'event_id': 1,
        'event_title': 'Rock Concert',
        'scanned_at': '2025-02-01T18:30:00',
        'events_attended': 5,
      };
      final c = CustomerHistoryItem.fromJson(json);

      expect(c.customerId, 42);
      expect(c.customerName, 'Alice');
      expect(c.eventId, 1);
      expect(c.eventTitle, 'Rock Concert');
      expect(c.scannedAt, '2025-02-01T18:30:00');
      expect(c.eventsAttended, 5);
    });

    test('nullable fields', () {
      final json = {
        'customer_id': 43,
        'event_id': 2,
      };
      final c = CustomerHistoryItem.fromJson(json);

      expect(c.customerName, isNull);
      expect(c.eventTitle, isNull);
      expect(c.scannedAt, isNull);
      expect(c.eventsAttended, 0);
    });
  });
}
