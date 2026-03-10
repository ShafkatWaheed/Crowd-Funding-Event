import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/design_tokens.dart';
import '../../../../config/theme.dart';
import '../../../../models/event.dart';
import '../../../../widgets/animated_list_item.dart';
import '../../../../widgets/event/event_card.dart';

class DashboardFeaturedSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Event> events;
  final int sectionIndex;
  final int? selectedEventId;
  final String? genreFilter;
  final Set<int> bookmarkedIds;
  final void Function(int) onToggleBookmark;
  final VoidCallback? onSeeAll;
  final VoidCallback? onClearFilter;
  final List<String?>? genreChips;
  final void Function(Event event)? onEventTap;
  final ValueChanged<String?> onGenreSelected;

  const DashboardFeaturedSection({
    super.key,
    required this.title,
    required this.icon,
    required this.events,
    required this.sectionIndex,
    required this.selectedEventId,
    required this.genreFilter,
    required this.bookmarkedIds,
    required this.onToggleBookmark,
    required this.onGenreSelected,
    this.onSeeAll,
    this.onClearFilter,
    this.genreChips,
    this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(top: AppSpacing.xxl, bottom: AppSpacing.md),
      child: AnimatedListItem(
        index: sectionIndex,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                  ),
                  if (onSeeAll != null)
                    GestureDetector(
                      onTap: onSeeAll,
                      child: Text(
                        'See all',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  if (onSeeAll != null && onClearFilter != null)
                    const SizedBox(width: 12),
                  if (onClearFilter != null)
                    GestureDetector(
                      onTap: onClearFilter,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceOf(context),
                          borderRadius: AppRadius.pill,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.close,
                                size: 14,
                                color:
                                    AppTheme.textSecondaryOf(context)),
                            const SizedBox(width: 4),
                            Text(
                              'Clear',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color:
                                    AppTheme.textSecondaryOf(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (genreChips != null && genreChips!.length > 1) ...[
              Padding(
                padding: const EdgeInsets.only(
                    left: AppSpacing.lg, bottom: AppSpacing.sm),
                child: SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _genreChip(context, 'All', null),
                      for (final g in genreChips!)
                        if (g != null) _genreChip(context, g, g),
                    ],
                  ),
                ),
              ),
            ],
            SizedBox(
              height: 330,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  final isSelected = selectedEventId == event.id;
                  return Container(
                    width: 280,
                    margin:
                        const EdgeInsets.only(right: AppSpacing.md),
                    child: Stack(
                      children: [
                        Container(
                          decoration: isSelected
                              ? BoxDecoration(
                                  borderRadius: AppRadius.lg,
                                  border: Border.all(
                                    color: Theme.of(context)
                                                .brightness ==
                                            Brightness.dark
                                        ? AppTheme.accentColor
                                        : AppTheme.primaryColor,
                                    width: 2.5,
                                  ),
                                )
                              : null,
                          child: Stack(
                            children: [
                              EventCard(
                                event: event,
                                imageUrl: event.firstImageUrl,
                                onTap: onEventTap != null
                                    ? () => onEventTap!(event)
                                    : () => context.push(
                                        '/events/${event.id}'),
                                isBookmarked: bookmarkedIds
                                    .contains(event.id),
                                onBookmarkToggle: () =>
                                    onToggleBookmark(event.id),
                              ),
                              if (onEventTap != null)
                                Positioned(
                                  right: 10,
                                  bottom: 10,
                                  child: GestureDetector(
                                    onTap: () => context.push(
                                        '/events/${event.id}'),
                                    child: Icon(
                                      Icons.arrow_forward,
                                      size: 18,
                                      color:
                                          AppTheme.textSecondaryOf(
                                              context),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _genreChip(
      BuildContext context, String label, String? value) {
    final isActive = genreFilter == value;
    final isDark = AppTheme.isDark(context);
    const color = AppTheme.accentColor;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => onGenreSelected(value),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? color
                : color.withValues(alpha: isDark ? 0.15 : 0.1),
            borderRadius: AppRadius.pill,
            border: Border.all(
              color:
                  isActive ? color : color.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive
                  ? Theme.of(context).colorScheme.onSecondary
                  : color,
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardEventFilterBanner extends StatelessWidget {
  final String eventTitle;
  final bool isStatusFilter;
  final VoidCallback onClear;

  const DashboardEventFilterBanner({
    super.key,
    required this.eventTitle,
    required this.isStatusFilter,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, 0),
      child: Row(
        children: [
          Icon(
            Icons.filter_alt_rounded,
            size: 16,
            color: isStatusFilter
                ? AppTheme.primaryColor
                : AppTheme.accentColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Showing metrics for: $eventTitle',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isStatusFilter
                    ? AppTheme.primaryColor
                    : AppTheme.accentColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: onClear,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close,
                  size: 16, color: AppTheme.textSecondaryOf(context)),
            ),
          ),
        ],
      ),
    );
  }
}
