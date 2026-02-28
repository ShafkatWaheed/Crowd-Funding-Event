import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// ── Tables ──

/// Cached events for offline browsing and local search.
class CachedEvents extends Table {
  IntColumn get id => integer()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get description => text().nullable()();
  TextColumn get genre => text().nullable()();
  TextColumn get status => text().withDefault(const Constant(''))();
  DateTimeColumn get startTime => dateTime().nullable()();
  DateTimeColumn get endTime => dateTime().nullable()();
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
  TextColumn get venueName => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get firstImageUrl => text().nullable()();
  IntColumn get fundingGoalCents => integer().nullable()();
  IntColumn get totalPledgedCents => integer().nullable()();
  IntColumn get ticketsSoldCount => integer().nullable()();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cached venues (denormalized from events for map lookups).
class CachedVenues extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get address => text().nullable()();
  TextColumn get city => text().nullable()();
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cached ticket tiers for offline display.
class CachedTicketTiers extends Table {
  IntColumn get id => integer()();
  IntColumn get eventId => integer()();
  TextColumn get name => text().withDefault(const Constant(''))();
  IntColumn get priceCents => integer().withDefault(const Constant(0))();
  IntColumn get maxReservedSpots => integer().nullable()();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Pre-downloaded tickets for offline scanning at venues.
class OfflineTickets extends Table {
  IntColumn get id => integer()();
  IntColumn get eventId => integer()();
  TextColumn get ticketCode => text()();
  IntColumn get userId => integer().nullable()();
  TextColumn get userName => text().nullable()();
  TextColumn get tierName => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('purchased'))();
  BoolColumn get scannedLocally =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Offline scan records queued for push sync.
class OfflineScans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get ticketCode => text()();
  IntColumn get eventId => integer()();
  DateTimeColumn get scannedAt => dateTime()();
  IntColumn get scannedById => integer()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
}

/// Cached bookmark event IDs.
class CachedBookmarks extends Table {
  IntColumn get eventId => integer()();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {eventId};
}

/// Cached transport/directions info per event.
class CachedTransport extends Table {
  IntColumn get eventId => integer()();
  TextColumn get parkingInfo => text().nullable()();
  TextColumn get transitInfo => text().nullable()();
  TextColumn get rideshareInfo => text().nullable()();
  TextColumn get accessibilityInfo => text().nullable()();
  TextColumn get directionsUrl => text().nullable()();

  @override
  Set<Column> get primaryKey => {eventId};
}

/// Customer's own purchased tickets with QR payload for offline display.
class CachedMyTickets extends Table {
  IntColumn get id => integer()();
  IntColumn get eventId => integer()();
  IntColumn get userId => integer()();
  TextColumn get ticketCode => text()();
  TextColumn get receiptNumber => text().nullable()();
  TextColumn get tierName => text().nullable()();
  TextColumn get eventTitle => text().nullable()();
  IntColumn get amountPaidCents => integer().withDefault(const Constant(0))();
  IntColumn get discountAppliedCents => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('purchased'))();
  DateTimeColumn get scannedAt => dateTime().nullable()();
  TextColumn get encryptedQrPayload => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cached schedule items for offline event schedule viewing.
class CachedScheduleItems extends Table {
  IntColumn get id => integer()();
  IntColumn get eventId => integer()();
  TextColumn get date => text()();
  TextColumn get startTime => text()();
  TextColumn get endTime => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get overlaps => boolean().withDefault(const Constant(false))();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cached sponsor tickets with QR payload for offline display.
class CachedSponsorTickets extends Table {
  IntColumn get id => integer()();
  IntColumn get eventId => integer()();
  IntColumn get sponsorUserId => integer()();
  TextColumn get receiptNumber => text().withDefault(const Constant(''))();
  TextColumn get encryptedQrPayload => text().nullable()();
  TextColumn get scannedAt => text().nullable()();
  TextColumn get createdAt => text().nullable()();
  TextColumn get eventTitle => text().nullable()();
  TextColumn get eventStatus => text().nullable()();
  TextColumn get eventStartTime => text().nullable()();
  TextColumn get venueName => text().nullable()();
  TextColumn get venueAddress => text().nullable()();
  TextColumn get venueCity => text().nullable()();
  IntColumn get categoryCount => integer().withDefault(const Constant(0))();
  IntColumn get scanCount => integer().withDefault(const Constant(0))();
  TextColumn get categoriesJson => text().withDefault(const Constant('[]'))();
  TextColumn get categoryNamesJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cached sponsor delegates for offline viewing.
class CachedSponsorDelegates extends Table {
  IntColumn get id => integer()();
  IntColumn get sponsorTicketId => integer()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  BoolColumn get checkedIn => boolean().withDefault(const Constant(false))();
  TextColumn get checkedInAt => text().nullable()();
  TextColumn get createdAt => text().nullable()();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tracks last sync timestamps per table for incremental sync.
class SyncMetadata extends Table {
  TextColumn get syncTableName => text()();
  DateTimeColumn get lastSyncAt => dateTime()();
  TextColumn get lastSyncCursor => text().nullable()();

  @override
  Set<Column> get primaryKey => {syncTableName};
}

// ── Database ──

@DriftDatabase(tables: [
  CachedEvents,
  CachedVenues,
  CachedTicketTiers,
  OfflineTickets,
  OfflineScans,
  CachedBookmarks,
  CachedTransport,
  CachedMyTickets,
  CachedScheduleItems,
  CachedSponsorTickets,
  CachedSponsorDelegates,
  SyncMetadata,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e])
      : super(e ?? driftDatabase(
          name: 'crowd_funding_cache',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ));

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(cachedMyTickets);
        await m.createTable(cachedScheduleItems);
        // Recreate sync_metadata with renamed column (table_name → sync_table_name)
        await m.deleteTable('sync_metadata');
        await m.createTable(syncMetadata);
      }
      if (from < 3) {
        await m.createTable(cachedSponsorTickets);
        await m.createTable(cachedSponsorDelegates);
      }
    },
  );

  // ── Event cache helpers ──

  Future<void> upsertEvent(CachedEventsCompanion entry) {
    return into(cachedEvents).insertOnConflictUpdate(entry);
  }

  Future<List<CachedEvent>> searchEvents(String query) {
    final pattern = '%$query%';
    return (select(cachedEvents)
          ..where((e) =>
              e.title.like(pattern) | e.description.like(pattern))
          ..orderBy([(e) => OrderingTerm.desc(e.startTime)])
          ..limit(50))
        .get();
  }

  Future<List<CachedEvent>> getAllCachedEvents({int limit = 100}) {
    return (select(cachedEvents)
          ..orderBy([(e) => OrderingTerm.desc(e.startTime)])
          ..limit(limit))
        .get();
  }

  // ── Offline ticket scanning helpers ──

  Future<void> upsertOfflineTicket(OfflineTicketsCompanion entry) {
    return into(offlineTickets).insertOnConflictUpdate(entry);
  }

  Future<int> countOfflineTickets(int eventId) async {
    final count = countAll();
    final query = selectOnly(offlineTickets)
      ..addColumns([count])
      ..where(offlineTickets.eventId.equals(eventId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<OfflineTicket?> findTicketByCode(int eventId, String ticketCode) {
    return (select(offlineTickets)
          ..where(
              (t) => t.eventId.equals(eventId) & t.ticketCode.equals(ticketCode)))
        .getSingleOrNull();
  }

  Future<void> markTicketScannedLocally(int ticketId) {
    return (update(offlineTickets)..where((t) => t.id.equals(ticketId)))
        .write(const OfflineTicketsCompanion(
      scannedLocally: Value(true),
    ));
  }

  Future<void> addOfflineScan({
    required String ticketCode,
    required int eventId,
    required int scannedById,
  }) {
    return into(offlineScans).insert(OfflineScansCompanion.insert(
      ticketCode: ticketCode,
      eventId: eventId,
      scannedAt: DateTime.now(),
      scannedById: scannedById,
    ));
  }

  Future<List<OfflineScan>> getUnsyncedScans() {
    return (select(offlineScans)..where((s) => s.synced.equals(false))).get();
  }

  Future<void> markScanSynced(int scanId) {
    return (update(offlineScans)..where((s) => s.id.equals(scanId)))
        .write(const OfflineScansCompanion(synced: Value(true)));
  }

  Future<int> countUnsyncedScans() async {
    final count = countAll();
    final query = selectOnly(offlineScans)
      ..addColumns([count])
      ..where(offlineScans.synced.equals(false));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  // ── Bookmark helpers ──

  Future<void> replaceBookmarks(List<int> eventIds) async {
    await delete(cachedBookmarks).go();
    final now = DateTime.now();
    await batch((b) {
      b.insertAll(
        cachedBookmarks,
        eventIds
            .map((id) => CachedBookmarksCompanion.insert(
                  eventId: Value(id),
                  syncedAt: now,
                ))
            .toList(),
      );
    });
  }

  Future<List<int>> getBookmarkedEventIds() async {
    final rows = await select(cachedBookmarks).get();
    return rows.map((r) => r.eventId).toList();
  }

  // ── Transport helpers ──

  Future<void> upsertTransport(CachedTransportCompanion entry) {
    return into(cachedTransport).insertOnConflictUpdate(entry);
  }

  Future<CachedTransportData?> getTransport(int eventId) {
    return (select(cachedTransport)
          ..where((t) => t.eventId.equals(eventId)))
        .getSingleOrNull();
  }

  // ── Sync metadata helpers ──

  Future<void> updateSyncMeta(String table, {String? cursor}) {
    return into(syncMetadata).insertOnConflictUpdate(SyncMetadataCompanion(
      syncTableName: Value(table),
      lastSyncAt: Value(DateTime.now()),
      lastSyncCursor: Value(cursor),
    ));
  }

  Future<SyncMetadataData?> getSyncMeta(String table) {
    return (select(syncMetadata)
          ..where((m) => m.syncTableName.equals(table)))
        .getSingleOrNull();
  }

  // ── Customer ticket helpers (offline QR) ──

  Future<void> replaceMyTickets(List<CachedMyTicketsCompanion> entries) async {
    await delete(cachedMyTickets).go();
    if (entries.isEmpty) return;
    await batch((b) => b.insertAll(cachedMyTickets, entries));
  }

  Future<List<CachedMyTicket>> getMyTicketsFromCache() {
    return (select(cachedMyTickets)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<CachedMyTicket?> getMyTicketById(int ticketId) {
    return (select(cachedMyTickets)
          ..where((t) => t.id.equals(ticketId)))
        .getSingleOrNull();
  }

  // ── Schedule cache helpers ──

  Future<void> replaceScheduleForEvent(
      int eventId, List<CachedScheduleItemsCompanion> entries) async {
    await (delete(cachedScheduleItems)
          ..where((s) => s.eventId.equals(eventId)))
        .go();
    if (entries.isEmpty) return;
    await batch((b) => b.insertAll(cachedScheduleItems, entries));
  }

  Future<List<CachedScheduleItem>> getScheduleForEvent(int eventId) {
    return (select(cachedScheduleItems)
          ..where((s) => s.eventId.equals(eventId))
          ..orderBy([
            (s) => OrderingTerm.asc(s.date),
            (s) => OrderingTerm.asc(s.sortOrder),
            (s) => OrderingTerm.asc(s.startTime),
          ]))
        .get();
  }

  // ── Sponsor ticket helpers (offline QR) ──

  Future<void> replaceSponsorTickets(
      List<CachedSponsorTicketsCompanion> entries) async {
    await delete(cachedSponsorTickets).go();
    if (entries.isEmpty) return;
    await batch((b) => b.insertAll(cachedSponsorTickets, entries));
  }

  Future<List<CachedSponsorTicket>> getSponsorTicketsFromCache() {
    return (select(cachedSponsorTickets)
          ..orderBy([(t) => OrderingTerm.desc(t.syncedAt)]))
        .get();
  }

  // ── Sponsor delegate helpers ──

  Future<void> replaceSponsorDelegates(
      int ticketId, List<CachedSponsorDelegatesCompanion> entries) async {
    await (delete(cachedSponsorDelegates)
          ..where((d) => d.sponsorTicketId.equals(ticketId)))
        .go();
    if (entries.isEmpty) return;
    await batch((b) => b.insertAll(cachedSponsorDelegates, entries));
  }

  Future<List<CachedSponsorDelegate>> getSponsorDelegatesFromCache(
      int ticketId) {
    return (select(cachedSponsorDelegates)
          ..where((d) => d.sponsorTicketId.equals(ticketId)))
        .get();
  }

  // ── Cleanup ──

  Future<void> clearOfflineTickets(int eventId) {
    return (delete(offlineTickets)
          ..where((t) => t.eventId.equals(eventId)))
        .go();
  }

  Future<void> clearAllCache() async {
    await delete(cachedEvents).go();
    await delete(cachedVenues).go();
    await delete(cachedTicketTiers).go();
    await delete(offlineTickets).go();
    await delete(offlineScans).go();
    await delete(cachedBookmarks).go();
    await delete(cachedTransport).go();
    await delete(cachedMyTickets).go();
    await delete(cachedScheduleItems).go();
    await delete(cachedSponsorTickets).go();
    await delete(cachedSponsorDelegates).go();
    await delete(syncMetadata).go();
  }
}

