import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../db/app_database.dart';
import 'api_service.dart';

/// Handles pull sync (server → device) and push sync (offline scans → server).
///
/// Usage: create once, call [init] on app start, [dispose] on app close.
class SyncService {
  SyncService({required this.db, required this.api});

  final AppDatabase db;
  final ApiService api;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _pushTimer;
  bool _isSyncing = false;

  // ── Lifecycle ──

  void init() {
    try {
      _connectivitySub = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    } catch (_) {
      // connectivity_plus not available on web — skip listener
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
    _pushTimer?.cancel();
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final isOnline = results.any((r) => r != ConnectivityResult.none);
    if (isOnline) {
      // Connectivity restored — flush offline scans
      pushOfflineScans();
    }
  }

  /// Returns true if device currently has network connectivity.
  Future<bool> get isOnline async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true; // Assume online when plugin unavailable (web)
    }
  }

  // ── Pull Sync (Server → Device) ──

  /// Pull first 2 pages of events and cache locally.
  Future<void> pullEvents() async {
    try {
      final result = await api.getEvents(limit: 40);
      final items = result['items'] as List? ?? [];
      final now = DateTime.now();
      for (final item in items) {
        await db.upsertEvent(CachedEventsCompanion.insert(
          id: Value(item['id'] as int),
          title: Value(item['title'] as String? ?? ''),
          description: Value(item['description'] as String?),
          genre: Value(item['genre'] as String?),
          status: Value(item['status'] as String? ?? ''),
          startTime: Value(_parseDateTime(item['start_time'])),
          endTime: Value(_parseDateTime(item['end_time'])),
          lat: Value((item['lat'] as num?)?.toDouble()),
          lng: Value((item['lng'] as num?)?.toDouble()),
          venueName: Value(item['venue_name'] as String?),
          city: Value(item['city'] as String?),
          firstImageUrl: Value(item['first_image_url'] as String?),
          fundingGoalCents: Value(item['funding_goal_cents'] as int?),
          totalPledgedCents: Value(item['total_pledged_cents'] as int?),
          ticketsSoldCount: Value(item['tickets_sold_count'] as int?),
          syncedAt: now,
        ));
      }
      final nextCursor = result['next_cursor'] as String?;
      await db.updateSyncMeta('cached_events', cursor: nextCursor);
    } catch (e) {
      debugPrint('SyncService.pullEvents failed: $e');
    }
  }

  /// Download all purchased tickets for an event (manual "Prepare Offline" action).
  Future<int> downloadTicketsForEvent(int eventId) async {
    try {
      // Fetch all ticket sales (API returns List<dynamic>)
      final items = await api.getTicketSales(eventId, limit: 5000);
      final now = DateTime.now();
      await db.clearOfflineTickets(eventId);
      for (final item in items) {
        final map = item as Map<String, dynamic>;
        await db.upsertOfflineTicket(OfflineTicketsCompanion.insert(
          id: Value(map['id'] as int),
          eventId: eventId,
          ticketCode: map['ticket_code'] as String? ?? '',
          userId: Value(map['user_id'] as int?),
          userName: Value(map['buyer_name'] as String?),
          tierName: Value(map['tier_name'] as String?),
          status: Value(map['status'] as String? ?? 'purchased'),
          syncedAt: now,
        ));
      }
      await db.updateSyncMeta('offline_tickets_$eventId');
      return items.length;
    } catch (e) {
      debugPrint('SyncService.downloadTicketsForEvent failed: $e');
      rethrow;
    }
  }

  /// Pull customer's own tickets (with QR payload) for offline display.
  /// Only caches tickets for events in selling_tickets or live status.
  static const _cacheableStatuses = {'selling_tickets', 'live'};

  Future<void> pullMyTickets() async {
    try {
      const pageSize = 100;
      final allEntries = <CachedMyTicketsCompanion>[];
      final now = DateTime.now();
      int offset = 0;
      while (true) {
        final items = await api.getMyTickets(offset: offset, limit: pageSize);
        for (final item in items) {
          final map = item as Map<String, dynamic>;
          final eventStatus = map['event_status'] as String?;
          if (eventStatus == null || !_cacheableStatuses.contains(eventStatus)) {
            continue; // skip tickets for events not in selling/live state
          }
          allEntries.add(CachedMyTicketsCompanion.insert(
            id: Value(map['id'] as int),
            eventId: map['event_id'] as int,
            userId: map['user_id'] as int,
            ticketCode: map['ticket_code'] as String? ?? '',
            receiptNumber: Value(map['receipt_number'] as String?),
            tierName: Value(map['tier_name'] as String?),
            eventTitle: Value(map['event_title'] as String?),
            eventStatus: Value(eventStatus),
            amountPaidCents: Value(map['amount_paid_cents'] as int? ?? 0),
            discountAppliedCents: Value(map['discount_applied_cents'] as int? ?? 0),
            status: Value(map['status'] as String? ?? 'purchased'),
            scannedAt: Value(_parseDateTime(map['scanned_at'])),
            encryptedQrPayload: Value(map['encrypted_qr_payload'] as String?),
            createdAt: _parseDateTime(map['created_at']) ?? now,
            syncedAt: now,
          ));
        }
        if (items.length < pageSize) break;
        offset += pageSize;
      }
      await db.replaceMyTickets(allEntries);
      await db.updateSyncMeta('cached_my_tickets');
    } catch (e) {
      debugPrint('SyncService.pullMyTickets failed: $e');
    }
  }

  /// Cache schedule items for an event (for offline viewing).
  Future<void> cacheScheduleForEvent(int eventId) async {
    try {
      final list = await api.getSchedule(eventId);
      final now = DateTime.now();
      final entries = <CachedScheduleItemsCompanion>[];
      for (final dayJson in list) {
        final day = dayJson as Map<String, dynamic>;
        final date = day['date'] as String;
        final items = day['items'] as List? ?? [];
        for (final item in items) {
          final map = item as Map<String, dynamic>;
          entries.add(CachedScheduleItemsCompanion.insert(
            id: Value(map['id'] as int),
            eventId: eventId,
            date: date,
            startTime: map['start_time'] as String? ?? '',
            endTime: map['end_time'] as String? ?? '',
            title: map['title'] as String? ?? '',
            description: Value(map['description'] as String?),
            imageUrl: Value(map['image_url'] as String?),
            sortOrder: Value(map['sort_order'] as int? ?? 0),
            overlaps: Value(map['overlaps'] as bool? ?? false),
            syncedAt: now,
          ));
        }
      }
      await db.replaceScheduleForEvent(eventId, entries);
    } catch (e) {
      debugPrint('SyncService.cacheScheduleForEvent failed: $e');
    }
  }

  /// Cache transport/directions info for an event (for offline viewing).
  Future<void> cacheTransportForEvent({
    required int eventId,
    String? parkingInfo,
    String? transitInfo,
    String? rideshareInfo,
    String? accessibilityInfo,
    String? directionsUrl,
  }) async {
    try {
      await db.upsertTransport(CachedTransportCompanion(
        eventId: Value(eventId),
        parkingInfo: Value(parkingInfo),
        transitInfo: Value(transitInfo),
        rideshareInfo: Value(rideshareInfo),
        accessibilityInfo: Value(accessibilityInfo),
        directionsUrl: Value(directionsUrl),
      ));
    } catch (e) {
      debugPrint('SyncService.cacheTransportForEvent failed: $e');
    }
  }

  /// Pull sponsor's own tickets (with QR payload) for offline display.
  /// Only caches tickets for events in selling_tickets or live status.
  Future<void> pullSponsorTickets() async {
    try {
      final items = await api.getMySponsorTickets();
      final now = DateTime.now();
      final entries = <CachedSponsorTicketsCompanion>[];
      for (final item in items) {
        final map = item as Map<String, dynamic>;
        final eventStatus = map['event_status'] as String?;
        if (eventStatus == null || !_cacheableStatuses.contains(eventStatus)) {
          continue; // skip tickets for events not in selling/live state
        }
        entries.add(CachedSponsorTicketsCompanion.insert(
          id: Value(map['id'] as int),
          eventId: map['event_id'] as int,
          sponsorUserId: map['sponsor_user_id'] as int,
          receiptNumber: Value(map['receipt_number'] as String? ?? ''),
          encryptedQrPayload:
              Value(map['encrypted_qr_payload'] as String?),
          scannedAt: Value(map['scanned_at'] as String?),
          createdAt: Value(map['created_at'] as String?),
          eventTitle: Value(map['event_title'] as String?),
          eventStatus: Value(eventStatus),
          eventStartTime: Value(map['event_start_time'] as String?),
          venueName: Value(map['venue_name'] as String?),
          venueAddress: Value(map['venue_address'] as String?),
          venueCity: Value(map['venue_city'] as String?),
          categoryCount: Value(map['category_count'] as int? ?? 0),
          scanCount: Value(map['scan_count'] as int? ?? 0),
          categoriesJson:
              Value(jsonEncode(map['categories'] as List? ?? [])),
          categoryNamesJson:
              Value(jsonEncode(map['category_names'] as List? ?? [])),
          syncedAt: now,
        ));
      }
      await db.replaceSponsorTickets(entries);
      await db.updateSyncMeta('cached_sponsor_tickets');
    } catch (e) {
      debugPrint('SyncService.pullSponsorTickets failed: $e');
    }
  }

  /// Cache sponsor delegates for a ticket (for offline viewing).
  Future<void> cacheSponsorDelegates(
      int ticketId, List<dynamic> data) async {
    try {
      final now = DateTime.now();
      final entries = data.map((item) {
        final map = item as Map<String, dynamic>;
        return CachedSponsorDelegatesCompanion.insert(
          id: Value(map['id'] as int),
          sponsorTicketId: ticketId,
          name: Value(map['name'] as String? ?? ''),
          email: Value(map['email'] as String?),
          phone: Value(map['phone'] as String?),
          checkedIn: Value(map['checked_in'] as bool? ?? false),
          checkedInAt: Value(map['checked_in_at'] as String?),
          createdAt: Value(map['created_at'] as String?),
          syncedAt: now,
        );
      }).toList();
      await db.replaceSponsorDelegates(ticketId, entries);
    } catch (e) {
      debugPrint('SyncService.cacheSponsorDelegates failed: $e');
    }
  }

  /// Pull bookmark IDs and replace local cache.
  Future<void> pullBookmarks() async {
    try {
      const pageSize = 100;
      final allIds = <int>[];
      int offset = 0;
      while (true) {
        final items = await api.getBookmarkedEvents(offset: offset, limit: pageSize);
        allIds.addAll(items.map<int>((e) => (e as Map<String, dynamic>)['id'] as int));
        if (items.length < pageSize) break;
        offset += pageSize;
      }
      await db.replaceBookmarks(allIds);
    } catch (e) {
      debugPrint('SyncService.pullBookmarks failed: $e');
    }
  }

  // ── Push Sync (Device → Server) ──

  /// Push all unsynced offline scan records to the server.
  Future<void> pushOfflineScans() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final scans = await db.getUnsyncedScans();
      for (final scan in scans) {
        try {
          await api.scanTicket(scan.eventId, ticketCode: scan.ticketCode);
          await db.markScanSynced(scan.id);
        } catch (e) {
          debugPrint('Failed to sync scan ${scan.id}: $e');
          // Will retry on next push cycle
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  // ── App Launch Sync ──

  /// Called on app launch — pulls events and bookmarks if online.
  Future<void> syncOnLaunch() async {
    if (!await isOnline) return;
    await Future.wait([
      pullEvents(),
      pullMyTickets(),
      pullSponsorTickets(),
      pullBookmarks(),
      pushOfflineScans(),
    ]);
  }

  // ── Helpers ──

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
