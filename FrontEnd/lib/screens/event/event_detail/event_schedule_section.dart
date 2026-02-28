import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/api_config.dart';
import '../../../utils/date_time_utils.dart';
import '../../../config/theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../config/design_tokens.dart';
import '../../../models/event.dart';
import '../../../models/schedule.dart';
import '../../../db/app_database.dart';
import '../../../services/api_service.dart';
import '../../../services/sync_service.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();

      final auth = context.read<AuthProvider>();
      if (auth.user != null && auth.user!.isAdmin) {
        try {
          final flags = await api.getFeatureFlags();
          if (flags['feature_schedule_enabled'] == false) {
            if (mounted) setState(() { _featureEnabled = false; _loading = false; });
            return;
          }
        } catch (e) { debugPrint(e.toString()); }
      }

      final list = await api.getSchedule(widget.eventId);
      final days = list.map((j) => ScheduleDay.fromJson(j)).toList();

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
        // Group by date to reconstruct ScheduleDay list
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

  String _formatDate(String isoDate) => AppDateFormat.isoDateOnly(isoDate);

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

  Future<void> _downloadExcel() async {
    final api = context.read<ApiService>();
    final url = api.getScheduleExportUrl(widget.eventId);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
            AppSpacing.vMd,

            // Date tab pills
            SizedBox(
              height: AppSpacing.xxxl,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _days.length,
                separatorBuilder: (_, __) => AppSpacing.hSm,
                itemBuilder: (context, idx) {
                  final isSelected = idx == _selectedIdx;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIdx = idx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.feedAccent.withValues(alpha: 0.12)
                            : AppTheme.surfaceOf(context),
                        borderRadius: AppRadius.xl,
                        border: Border.all(
                          color: isSelected
                              ? context.feedAccent.withValues(alpha: 0.4)
                              : AppTheme.dividerOf(context),
                        ),
                      ),
                      child: Text(
                        _formatDate(_days[idx].date),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? context.feedAccent
                              : AppTheme.textSecondaryOf(context),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            AppSpacing.vLg,

            // Vertical timeline for selected date
            ...selectedDay.items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final isLast = idx == selectedDay.items.length - 1;
              final isOverlap = item.overlaps;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 40,
                      child: Column(
                        children: [
                          _buildTimelineNode(context, item, isOverlap),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: isOverlap
                                    ? context.photoAccent.withValues(alpha: 0.4)
                                    : context.feedAccent.withValues(alpha: 0.2),
                              ),
                            ),
                        ],
                      ),
                    ),
                    AppSpacing.hSm,
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
                        padding: AppSpacing.paddingMd,
                        decoration: BoxDecoration(
                          color: AppTheme.cardOf(context),
                          borderRadius: AppRadius.sm,
                          border: Border.all(
                            color: isOverlap
                                ? context.photoAccent.withValues(alpha: 0.5)
                                : context.feedAccent.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                                  decoration: BoxDecoration(
                                    color: isOverlap
                                        ? context.photoAccent.withValues(alpha: 0.15)
                                        : context.feedAccent.withValues(alpha: 0.12),
                                    borderRadius: AppRadius.sm,
                                  ),
                                  child: Text(
                                    '${_formatTime24to12(item.startTime)} – ${_formatTime24to12(item.endTime)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isOverlap
                                          ? context.photoAccent
                                          : context.feedAccent,
                                    ),
                                  ),
                                ),
                                if (isOverlap) ...[
                                  AppSpacing.hSm,
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
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
                            AppSpacing.vSm,
                            Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : AppTheme.textPrimaryOf(context),
                              ),
                            ),
                            if (item.description != null && item.description!.isNotEmpty) ...[
                              AppSpacing.vXs,
                              Text(
                                item.description!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondaryOf(context),
                                ),
                              ),
                            ],
                            if (item.linkUrl != null && item.linkUrl!.isNotEmpty)
                              _buildLinkChip(context, item.linkUrl!),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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

  Widget _buildTimelineNode(BuildContext context, ScheduleItem item, bool isOverlap) {
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;
    final accent = isOverlap ? context.photoAccent : context.feedAccent;

    if (hasImage) {
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
        child: Tooltip(
          message: item.imageCaption ?? '',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6.5),
                child: CachedNetworkImage(
                  imageUrl: resolvedUrl,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    color: accent.withValues(alpha: 0.1),
                    child: Icon(Icons.image_rounded, size: 16, color: accent),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: AppSpacing.xxl,
      height: AppSpacing.xxl,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent,
      ),
      child: Center(
        child: Icon(
          isOverlap ? Icons.warning_rounded : Icons.schedule_rounded,
          size: AppIconSize.sm,
          color: Colors.white,
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
