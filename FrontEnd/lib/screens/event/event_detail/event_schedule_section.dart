import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../models/event.dart';
import '../../../models/schedule.dart';
import '../../../services/api_service.dart';

class EventScheduleSection extends StatefulWidget {
  final int eventId;
  final Event event;

  const EventScheduleSection({required this.eventId, required this.event});

  @override
  State<EventScheduleSection> createState() => _EventScheduleSectionState();
}

class _EventScheduleSectionState extends State<EventScheduleSection> {
  List<ScheduleDay> _days = [];
  int _selectedIdx = 0;
  bool _loading = true;
  bool _featureEnabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();

      try {
        final flags = await api.getFeatureFlags();
        if (flags['feature_schedule_enabled'] == false) {
          if (mounted) setState(() { _featureEnabled = false; _loading = false; });
          return;
        }
      } catch (_) {}

      final list = await api.getSchedule(widget.eventId);
      final days = list.map((j) => ScheduleDay.fromJson(j)).toList();

      if (mounted) {
        setState(() {
          _days = days;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(String isoDate) {
    try {
      final d = DateTime.parse(isoDate);
      return DateFormat('MMM d, yyyy').format(d);
    } catch (_) {
      return isoDate;
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
                const Spacer(),
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
                      width: AppSpacing.xxxl,
                      child: Column(
                        children: [
                          Container(
                            width: AppSpacing.xxl,
                            height: AppSpacing.xxl,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isOverlap ? context.photoAccent : context.feedAccent,
                            ),
                            child: Center(
                              child: Icon(
                                isOverlap ? Icons.warning_rounded : Icons.schedule_rounded,
                                size: AppIconSize.sm,
                                color: Colors.white,
                              ),
                            ),
                          ),
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
}
