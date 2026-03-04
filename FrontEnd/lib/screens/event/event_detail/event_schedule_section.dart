import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/api_config.dart';
import '../../../config/theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../config/design_tokens.dart';
import '../../../models/event.dart';
import '../../../models/schedule.dart';
import '../../../db/app_database.dart';
import '../../../providers/event_provider.dart';
import '../../../services/sync_service.dart';
import '../../../widgets/shimmer_loaders.dart';
import '../../../widgets/fullscreen_image_viewer.dart';

class EventScheduleSection extends StatefulWidget {
  final int eventId;
  final Event event;

  const EventScheduleSection({super.key, required this.eventId, required this.event});

  @override
  State<EventScheduleSection> createState() => _EventScheduleSectionState();
}

class _EventScheduleSectionState extends State<EventScheduleSection> {
  List<ScheduleDay> _days = [];
  int _selectedIdx = 0;
  bool _loading = true;
  bool _featureEnabled = true;
  bool _isOffline = false;
  final ScrollController _circleScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _circleScroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = context.read<EventProvider>();

      final auth = context.read<AuthProvider>();
      if (auth.user != null && auth.user!.isAdmin) {
        try {
          final config = await repo.getPublicConfig();
          if (!config.featureScheduleEnabled) {
            if (mounted) setState(() { _featureEnabled = false; _loading = false; });
            return;
          }
        } catch (e) { debugPrint(e.toString()); }
      }

      final days = await repo.getSchedule(widget.eventId);

      if (mounted) {
        setState(() {
          _days = days;
          _isOffline = false;
          _loading = false;
        });
        // Background-cache for offline use
        context.read<SyncService>().cacheScheduleForEvent(widget.eventId);
      }
    } catch (_) {
      // Try loading from offline cache
      await _loadFromCache();
      if (mounted && _days.isEmpty) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final db = context.read<AppDatabase>();
      final rows = await db.getScheduleForEvent(widget.eventId);
      if (mounted && rows.isNotEmpty) {
        final dayMap = <String, List<ScheduleItem>>{};
        for (final row in rows) {
          dayMap.putIfAbsent(row.date, () => []).add(ScheduleItem(
            id: row.id,
            eventId: row.eventId,
            date: row.date,
            startTime: row.startTime,
            endTime: row.endTime,
            title: row.title,
            description: row.description,
            imageUrl: row.imageUrl,
            sortOrder: row.sortOrder,
            overlaps: row.overlaps,
            createdAt: row.syncedAt,
          ));
        }
        final days = dayMap.entries
            .map((e) => ScheduleDay(date: e.key, items: e.value))
            .toList();

        setState(() {
          _days = days;
          _isOffline = true;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load schedule from cache: $e');
    }
  }

  String _formatTime24to12(String hhmm) {
    try {
      final parts = hhmm.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final period = h >= 12 ? 'PM' : 'AM';
      final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$h12:${m.toString().padLeft(2, '0')} $period';
    } catch (_) {
      return hhmm;
    }
  }

  /// Extract day number from ISO date string (e.g. "2026-03-01" → "1")
  String _dayNumber(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day}';
    } catch (_) {
      return isoDate;
    }
  }

  /// Extract short weekday name from ISO date (e.g. "2026-03-01" → "Sat")
  String _weekdayShort(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return names[dt.weekday - 1];
    } catch (_) {
      return '';
    }
  }

  Future<void> _downloadExcel() async {
    final repo = context.read<EventProvider>();
    final url = repo.getScheduleExportUrl(widget.eventId);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _selectDay(int idx) {
    setState(() => _selectedIdx = idx);
    // Auto-scroll selected circle into view
    const circleWidth = 52.0 + 16.0; // circle + spacing
    final target = (idx * circleWidth) - (MediaQuery.of(context).size.width / 2) + circleWidth / 2;
    if (_circleScroll.hasClients) {
      _circleScroll.animateTo(
        target.clamp(0, _circleScroll.position.maxScrollExtent),
        duration: AppDuration.normal,
        curve: AppCurve.enter,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_featureEnabled) return const SizedBox.shrink();
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_days.isEmpty) return const SizedBox.shrink();

    final selectedDay = _days[_selectedIdx];
    int totalSessions = 0;
    for (final d in _days) {
      totalSessions += d.items.length;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Container(
        width: double.infinity,
        padding: AppSpacing.paddingLg,
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: AppRadius.md,
          border: Border.all(color: AppTheme.dividerOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.calendar_month_rounded, size: AppIconSize.sm, color: context.feedAccent),
                AppSpacing.hSm,
                Text(
                  'Event Schedule',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondaryOf(context),
                    letterSpacing: 0.5,
                  ),
                ),
                if (_isOffline) ...[
                  AppSpacing.hSm,
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade700.withValues(alpha: 0.15),
                      borderRadius: AppRadius.sm,
                    ),
                    child: Text('Cached',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (!_isOffline)
                  Material(
                    color: context.feedAccent.withValues(alpha: 0.08),
                    borderRadius: AppRadius.sm,
                    child: InkWell(
                      borderRadius: AppRadius.sm,
                      onTap: _downloadExcel,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.download_rounded, size: AppIconSize.sm, color: context.feedAccent),
                            AppSpacing.hXs,
                            Text('Excel',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: context.feedAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            AppSpacing.vLg,

            // Story circles — date selector
            SizedBox(
              height: 72,
              child: _days.length == 1
                  ? Center(child: _buildStoryCircle(0))
                  : ListView.separated(
                      controller: _circleScroll,
                      scrollDirection: Axis.horizontal,
                      itemCount: _days.length,
                      separatorBuilder: (_, __) => AppSpacing.hLg,
                      itemBuilder: (_, idx) => _buildStoryCircle(idx),
                    ),
            ),
            AppSpacing.vLg,

            // Agenda cards for selected day
            ...selectedDay.items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final isOverlap = item.overlaps;

              return Padding(
                padding: EdgeInsets.only(
                  bottom: idx < selectedDay.items.length - 1 ? AppSpacing.md : 0,
                ),
                child: _buildAgendaCard(item, isOverlap, idx),
              );
            }),

            AppSpacing.vMd,
            Center(
              child: Text(
                '$totalSessions session${totalSessions == 1 ? '' : 's'} across ${_days.length} day${_days.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryCircle(int idx) {
    final isSelected = idx == _selectedIdx;
    final accent = context.feedAccent;

    return GestureDetector(
      onTap: () => _selectDay(idx),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: AppDuration.fast,
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? accent : AppTheme.dividerOf(context),
                width: isSelected ? 3 : 1.5,
              ),
              color: isSelected
                  ? accent.withValues(alpha: 0.08)
                  : Colors.transparent,
            ),
            child: Center(
              child: Text(
                _dayNumber(_days[idx].date),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected ? accent : AppTheme.textSecondaryOf(context),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _weekdayShort(_days[idx].date),
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? accent : AppTheme.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaCard(ScheduleItem item, bool isOverlap, int index) {
    final accent = isOverlap ? context.photoAccent : context.feedAccent;
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time header
        Row(
          children: [
            Text(
              _formatTime24to12(item.startTime),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
            if (isOverlap) ...[
              AppSpacing.hSm,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: context.photoAccent.withValues(alpha: 0.15),
                  borderRadius: AppRadius.sm,
                ),
                child: Text('Overlaps',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: context.photoAccent,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        // Card with left accent border
        Container(
          width: double.infinity,
          padding: AppSpacing.paddingMd,
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: AppRadius.md,
            border: Border.all(color: AppTheme.dividerOf(context), width: 0.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                    if (item.description != null && item.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${_formatTime24to12(item.startTime)} – ${_formatTime24to12(item.endTime)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                    if (item.linkUrl != null && item.linkUrl!.isNotEmpty)
                      _buildLinkChip(context, item.linkUrl!),
                  ],
                ),
              ),
              if (hasImage) ...[
                AppSpacing.hMd,
                _buildSessionThumbnail(item, accent),
              ],
            ],
          ),
        ),
      ],
    )
        .animate(delay: Duration(milliseconds: 50 * index))
        .fadeIn(duration: AppDuration.normal, curve: AppCurve.enter)
        .slideY(begin: 0.1, end: 0, duration: AppDuration.normal, curve: AppCurve.enter);
  }

  Widget _buildSessionThumbnail(ScheduleItem item, Color accent) {
    final resolvedUrl = item.imageUrl!.startsWith('/')
        ? ApiConfig.imageUrl(item.imageUrl!)
        : item.imageUrl!;
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(PageRouteBuilder(
          opaque: false,
          barrierColor: Colors.black87,
          pageBuilder: (_, __, ___) => FullscreenImageViewer(
            imageUrls: [resolvedUrl],
            captions: [item.imageCaption],
            initialIndex: 0,
          ),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ));
      },
      child: ClipRRect(
        borderRadius: AppRadius.sm,
        child: CachedNetworkImage(
          imageUrl: resolvedUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          imageBuilder: (context, imageProvider) => Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: imageProvider,
                fit: BoxFit.cover,
              ),
            ),
          ).animate().fadeIn(
              duration: AppDuration.normal, curve: AppCurve.enter),
          placeholder: (_, __) =>
              const ShimmerImagePlaceholder(width: 48, height: 48),
          errorWidget: (_, __, ___) => Container(
            width: 48,
            height: 48,
            color: accent.withValues(alpha: 0.1),
            child: Icon(Icons.image_rounded, size: 20, color: accent),
          ),
        ),
      ),
    );
  }

  Widget _buildLinkChip(BuildContext context, String url) {
    String domain;
    try {
      final uri = Uri.parse(url);
      domain = uri.host.isNotEmpty ? uri.host : url;
      if (domain.startsWith('www.')) domain = domain.substring(4);
      if (domain.length > 25) domain = '${domain.substring(0, 22)}...';
    } catch (_) {
      domain = url.length > 25 ? '${url.substring(0, 22)}...' : url;
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: GestureDetector(
        onTap: () async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: context.feedAccent.withValues(alpha: 0.08),
            borderRadius: AppRadius.sm,
            border: Border.all(color: context.feedAccent.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_rounded, size: 13, color: context.feedAccent),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  domain,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.feedAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
