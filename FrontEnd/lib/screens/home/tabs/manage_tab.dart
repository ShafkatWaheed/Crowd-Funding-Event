import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../config/design_tokens.dart';
import '../../../config/theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/animated_list_item.dart';
import '../../../widgets/press_feedback.dart';

class ManageTab extends StatefulWidget {
  final VoidCallback? onEventCreated;

  const ManageTab({super.key, this.onEventCreated});

  @override
  State<ManageTab> createState() => _ManageTabState();
}

class _ManageTabState extends State<ManageTab> {
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isDark = AppTheme.isDark(context);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardOf(context),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AppRadius.xxlValue),
                bottomRight: Radius.circular(AppRadius.xxlValue),
              ),
              boxShadow: AppShadow.soft(isDark),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl, 56, AppSpacing.xxl, AppSpacing.xl,
            ),
            child: Text(
              'Manage',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Events ───
                _sectionLabel('Events'),
                AppSpacing.vMd,
                AnimatedListItem(
                  index: 0,
                  child: Row(
                    children: [
                      _quickActionCard(
                        icon: Icons.add_circle_rounded,
                        label: 'Create Event',
                        color: AppTheme.accentColor,
                        onTap: () async {
                          final created =
                              await context.push<bool>('/events/create');
                          if (created == true && mounted) {
                            widget.onEventCreated?.call();
                          }
                        },
                      ),
                      AppSpacing.hMd,
                      _quickActionCard(
                        icon: Icons.location_city_rounded,
                        label: 'Venues',
                        color: AppTheme.accentColor,
                        onTap: () => context.push('/venues'),
                      ),
                      AppSpacing.hMd,
                      _quickActionCard(
                        icon: Icons.group_work_rounded,
                        label: 'Co-Organized',
                        color: context.managementAccent,
                        onTap: () => context.push('/manage/co-organized'),
                      ),
                    ],
                  ),
                ),

                // ─── Tickets & Sales ───
                const SizedBox(height: AppSpacing.xxl),
                _sectionLabel('Tickets & Sales'),
                AppSpacing.vMd,
                AnimatedListItem(
                  index: 1,
                  child: Row(
                    children: [
                      _quickActionCard(
                        icon: Icons.confirmation_number_rounded,
                        label: 'Ticket Tiers',
                        color: context.statusSelling,
                        onTap: () => context.push('/ticket-strategies'),
                      ),
                      AppSpacing.hMd,
                      _quickActionCard(
                        icon: Icons.receipt_long_rounded,
                        label: 'All Ticket Sales',
                        color: AppTheme.successColor,
                        onTap: () => context.push('/manage/ticket-sales'),
                      ),
                      AppSpacing.hMd,
                      _quickActionCard(
                        icon: Icons.qr_code_scanner_rounded,
                        label: 'Scanned',
                        color: context.sponsorAccent,
                        onTap: () => context.push('/manage/scanned-tickets'),
                      ),
                    ],
                  ),
                ),
                AppSpacing.vMd,
                AnimatedListItem(
                  index: 2,
                  child: Row(
                    children: [
                      _quickActionCard(
                        icon: Icons.hourglass_top_rounded,
                        label: 'Waitlist',
                        color: context.statusPending,
                        onTap: () => context.push('/manage/waitlist'),
                      ),
                      AppSpacing.hMd,
                      _quickActionCard(
                        icon: Icons.discount_rounded,
                        label: 'Discounts',
                        color: AppTheme.errorColor,
                        onTap: () => context.push('/manage/discounts'),
                      ),
                      AppSpacing.hMd,
                      _quickActionCard(
                        icon: Icons.money_off_rounded,
                        label: 'Refunds',
                        color: AppTheme.errorColor,
                        onTap: () => context.push('/manage/refunds'),
                      ),
                    ],
                  ),
                ),

                // ─── Funding & Sponsors ───
                const SizedBox(height: AppSpacing.xxl),
                _sectionLabel('Funding & Sponsors'),
                AppSpacing.vMd,
                AnimatedListItem(
                  index: 3,
                  child: Row(
                    children: [
                      _quickActionCard(
                        icon: Icons.volunteer_activism_rounded,
                        label: 'Pledges',
                        color: context.fundingAccent,
                        onTap: () => context.push('/manage/pledges'),
                      ),
                      AppSpacing.hMd,
                      _quickActionCard(
                        icon: Icons.handshake_rounded,
                        label: 'Sponsors',
                        color: context.managementAccent,
                        onTap: () => context.push('/manage/sponsors'),
                      ),
                      AppSpacing.hMd,
                      _quickActionCard(
                        icon: Icons.category_rounded,
                        label: 'Sponsorships',
                        color: context.sponsorAccent,
                        onTap: () =>
                            context.push('/sponsor-category-templates'),
                      ),
                    ],
                  ),
                ),

                // ─── Other ───
                const SizedBox(height: AppSpacing.xxl),
                _sectionLabel('Other'),
                AppSpacing.vMd,
                AnimatedListItem(
                  index: 4,
                  child: Row(
                    children: [
                      _quickActionCard(
                        icon: Icons.bookmark_rounded,
                        label: 'Bookmarks',
                        color: AppTheme.warningColor,
                        onTap: () => context.push('/bookmarks'),
                      ),
                      if (user != null && user.isAdmin) ...[
                        AppSpacing.hMd,
                        _quickActionCard(
                          icon: Icons.admin_panel_settings_rounded,
                          label: 'Admin',
                          color: AppTheme.primaryColor,
                          onTap: () => context.push('/admin'),
                        ),
                        AppSpacing.hMd,
                        const Expanded(child: SizedBox()),
                      ] else ...[
                        AppSpacing.hMd,
                        const Expanded(child: SizedBox()),
                        AppSpacing.hMd,
                        const Expanded(child: SizedBox()),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.textSecondaryOf(context),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppTheme.primaryColor,
  }) {
    final isDark = AppTheme.isDark(context);
    return Expanded(
      child: PressFeedback(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppTheme.cardOf(context),
              borderRadius: AppRadius.lg,
              boxShadow: AppShadow.card(isDark),
            ),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: AppRadius.md,
                  ),
                  child: Icon(icon, size: AppIconSize.lg, color: color),
                ),
                AppSpacing.vSm,
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryOf(context)),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
