import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/design_tokens.dart';
import '../../../../config/theme.dart';
import '../../../../models/dashboard.dart';
import '../../../../models/event.dart';
import '../../../../widgets/animated_list_item.dart';
import '../../../../widgets/empty_state.dart';
import '../../../../widgets/event_card.dart';
import '../../../../widgets/press_feedback.dart';

class DashboardEventCarousels extends StatelessWidget {
  final OrganizerDashboard dashboardData;
  final Set<int> bookmarkedIds;
  final void Function(int) onToggleBookmark;

  const DashboardEventCarousels({
    super.key,
    required this.dashboardData,
    required this.bookmarkedIds,
    required this.onToggleBookmark,
  });

  @override
  Widget build(BuildContext context) {
    final trending = dashboardData.trendingEvents;
    final top = dashboardData.topEvents;

    if (trending.isEmpty && top.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, 0),
        child: AnimatedListItem(
          index: 4,
          child: EmptyState(
            icon: Icons.rocket_launch_rounded,
            title: 'Create your first event',
            subtitle:
                'Your trending and top-earning events will appear here.',
          ),
        ),
      );
    }

    return Column(
      children: [
        if (trending.isNotEmpty)
          _buildEventCarousel(
            context: context,
            title: 'Your Trending Events',
            icon: Icons.trending_up_rounded,
            events: trending,
            index: 4,
          ),
        if (top.isNotEmpty)
          _buildEventCarousel(
            context: context,
            title: 'Your Top Earners',
            icon: Icons.emoji_events_rounded,
            events: top,
            index: 5,
          ),
      ],
    );
  }

  Widget _buildEventCarousel({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Event> events,
    required int index,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.xxl, 0, 0),
      child: AnimatedListItem(
        index: index,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Row(
                children: [
                  Icon(icon,
                      size: AppIconSize.sm,
                      color: AppTheme.accentColor),
                  AppSpacing.hSm,
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.vMd,
            SizedBox(
              height: 330,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl),
                itemCount: events.length,
                separatorBuilder: (_, __) => AppSpacing.hMd,
                itemBuilder: (ctx, i) {
                  final e = events[i];
                  return SizedBox(
                    width: 260,
                    child: PressFeedback(
                      child: EventCard(
                        event: e,
                        imageUrl: e.firstImageUrl,
                        isBookmarked: bookmarkedIds.contains(e.id),
                        onBookmarkToggle: () =>
                            onToggleBookmark(e.id),
                        onTap: () =>
                            context.push('/events/${e.id}'),
                      ),
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
}
