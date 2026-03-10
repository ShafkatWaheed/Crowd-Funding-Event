import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../utils/date_time_utils.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/map_event.dart';
import '../../providers/event_provider.dart';

/// Full-screen map widget showing event markers.
/// Tapping a marker shows a bottom sheet listing all events at that venue.
class EventMapWidget extends StatefulWidget {
  /// Optional initial center. Defaults to Ottawa.
  final LatLng? initialCenter;

  /// Optional initial zoom.
  final double initialZoom;

  /// If provided, only show this organizer's events on the map.
  final int? organizerId;

  /// If true, only show events with sponsorship categories.
  final bool sponsorshipOnly;

  final String? search;
  final String? genre;
  final String? status;
  final String? city;

  const EventMapWidget({
    super.key,
    this.initialCenter,
    this.initialZoom = 12.0,
    this.organizerId,
    this.sponsorshipOnly = false,
    this.search,
    this.genre,
    this.status,
    this.city,
  });

  @override
  State<EventMapWidget> createState() => _EventMapWidgetState();
}

class _EventMapWidgetState extends State<EventMapWidget> {
  final MapController _mapController = MapController();
  List<EventMarker> _events = [];
  bool _loading = true;
  Timer? _debounce;

  static String get _mapboxToken =>
      dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEvents());
  }

  @override
  void didUpdateWidget(EventMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.search != widget.search ||
        oldWidget.genre != widget.genre ||
        oldWidget.status != widget.status ||
        oldWidget.city != widget.city ||
        oldWidget.organizerId != widget.organizerId ||
        oldWidget.sponsorshipOnly != widget.sponsorshipOnly) {
      _loadEvents();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    try {
      final repo = context.read<EventProvider>();
      final bounds = _mapController.camera.visibleBounds;
      final center = _mapController.camera.center;
      const distance = Distance();
      final radiusKm = distance.as(
            LengthUnit.Kilometer,
            center,
            LatLng(bounds.north, bounds.east),
          ) +
          5;

      final data = await repo.getMapEvents(
        lat: center.latitude,
        lng: center.longitude,
        radiusKm: radiusKm,
        organizerId: widget.organizerId,
        sponsorshipOnly: widget.sponsorshipOnly,
        search: widget.search,
        genre: widget.genre,
        status: widget.status,
        city: widget.city,
      );
      if (mounted) {
        setState(() {
          _events = data;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onMapMoved() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _loadEvents);
  }

  /// Group events by venue location (rounded lat/lng to cluster same-venue events).
  Map<String, List<EventMarker>> _groupByVenue() {
    final groups = <String, List<EventMarker>>{};
    for (final e in _events) {
      // Use venue_id if available, otherwise round lat/lng to ~10m precision
      final key = e.venueId != null
          ? 'v_${e.venueId}'
          : '${e.lat.toStringAsFixed(4)}_${e.lng.toStringAsFixed(4)}';
      groups.putIfAbsent(key, () => []).add(e);
    }
    return groups;
  }

  void _showVenueEvents(List<EventMarker> events) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _VenueEventsSheet(events: events),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center =
        widget.initialCenter ?? const LatLng(45.4215, -75.6972); // Ottawa
    final groups = _groupByVenue();

    final tileUrl = _mapboxToken.isNotEmpty
        ? 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}@2x?access_token=$_mapboxToken'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: widget.initialZoom,
            onPositionChanged: (pos, hasGesture) {
              if (hasGesture) _onMapMoved();
            },
          ),
          children: [
            TileLayer(
              urlTemplate: tileUrl,
              maxZoom: 19,
              userAgentPackageName: 'com.crowdfunding.app',
              tileProvider: NetworkTileProvider(),
            ),
            MarkerLayer(
              markers: groups.entries.map((entry) {
                final events = entry.value;
                final first = events.first;
                final hasLive = events.any((e) => e.isLive);
                final count = events.length;

                final venueName = first.venueName ?? '';

                return Marker(
                  point: LatLng(first.lat, first.lng),
                  width: 140,
                  height: 70,
                  child: GestureDetector(
                    onTap: () => _showVenueEvents(events),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Venue name label
                        if (venueName.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: hasLive
                                  ? AppTheme.successColor
                                  : AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              venueName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const SizedBox(height: 2),
                        // Pin + badge
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: hasLive
                                    ? AppTheme.successColor
                                    : AppTheme.primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            // Count badge
                            if (count > 1)
                              Positioned(
                                top: -4,
                                right: -4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentColor,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.white, width: 1.5),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // Loading indicator
        if (_loading)
          const Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Venue Events Bottom Sheet ───

class _VenueEventsSheet extends StatelessWidget {
  final List<EventMarker> events;

  const _VenueEventsSheet({required this.events});

  @override
  Widget build(BuildContext context) {
    final venueName = events.first.venueName ?? 'Events';
    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.2,
      maxChildSize: 0.7,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.cardOf(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.dividerOf(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Venue header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.location_city_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            venueName,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: AppTheme.textPrimaryOf(context),
                            ),
                          ),
                          Text(
                            '${events.length} event${events.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondaryOf(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Event list
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    DateTime? startDt;
                    if (event.startTime != null) {
                      try {
                        startDt = DateTime.parse(event.startTime!);
                      } catch (e) { debugPrint(e.toString()); }
                    }

                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/events/${event.id}');
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 4),
                        child: Row(
                          children: [
                            // Status indicator
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: event.isLive
                                    ? AppTheme.successColor
                                    : _statusColor(context, event.status),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.title,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                      color: AppTheme.textPrimaryOf(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      if (event.isLive) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppTheme.successColor,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'LIVE',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      if (startDt != null)
                                        Expanded(
                                          child: Text(
                                            AppDateFormat.eventCard(startDt),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondaryOf(context),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: AppTheme.textSecondaryOf(context),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _statusColor(BuildContext context, String status) {
    return switch (status) {
      'live' => AppTheme.successColor,
      'selling_tickets' => context.statusSelling,
      'approved' => AppTheme.primaryColor,
      _ => AppTheme.textSecondaryOf(context),
    };
  }
}
