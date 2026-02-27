import 'package:flutter/material.dart';

import '../../../../config/design_tokens.dart';
import '../../../../config/theme.dart';
import '../../../../widgets/animated_list_item.dart';
import 'dashboard_helpers.dart';

class DashboardKpiSection extends StatelessWidget {
  final Map<String, dynamic> dashboardData;
  final String dashboardPeriod;
  final void Function(String period) onPeriodChanged;
  final void Function(String basePath) onNavigate;

  const DashboardKpiSection({
    super.key,
    required this.dashboardData,
    required this.dashboardPeriod,
    required this.onPeriodChanged,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final revenue = dashboardData['total_revenue'] as Map<String, dynamic>;
    final tickets = dashboardData['tickets_sold'] as Map<String, dynamic>;
    final backers = dashboardData['total_backers'] as Map<String, dynamic>;
    final refundRate = dashboardData['refund_rate'] as Map<String, dynamic>?;
    final events = dashboardData['total_events'] as Map<String, dynamic>;
    final sponsors = dashboardData['total_sponsors'] as Map<String, dynamic>?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text(
                  'Period',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondaryOf(context)),
                ),
                const SizedBox(width: 10),
                ...periodOptions.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(e.value),
                        selected: dashboardPeriod == e.key,
                        onSelected: (_) {
                          if (dashboardPeriod != e.key) {
                            onPeriodChanged(e.key);
                          }
                        },
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: dashboardPeriod == e.key
                              ? Colors.white
                              : AppTheme.textSecondaryOf(context),
                        ),
                        selectedColor: AppTheme.accentColor,
                        backgroundColor: AppTheme.surfaceOf(context),
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    )),
              ],
            ),
          ),
          AnimatedListItem(
            index: 0,
            child: Row(
              children: [
                Expanded(
                  child: _DashboardKpiCard(
                    icon: Icons.attach_money_rounded,
                    label: 'Total Revenue',
                    value: dashFormatCents(revenue['value'] as int? ?? 0),
                    deltaPercent:
                        (revenue['delta_percent'] as num?)?.toDouble(),
                    accentColor: AppTheme.successColor,
                  ),
                ),
                AppSpacing.hMd,
                Expanded(
                  child: _DashboardKpiCard(
                    icon: Icons.confirmation_number_rounded,
                    label: 'Tickets Sold',
                    value: '${tickets['value'] ?? 0}',
                    deltaPercent:
                        (tickets['delta_percent'] as num?)?.toDouble(),
                    accentColor: context.ticketAccent,
                    onTap: () => onNavigate('/manage/ticket-sales'),
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.vMd,
          AnimatedListItem(
            index: 1,
            child: Row(
              children: [
                Expanded(
                  child: _DashboardKpiCard(
                    icon: Icons.volunteer_activism_rounded,
                    label: 'Total Backers',
                    value: '${backers['value'] ?? 0}',
                    deltaPercent:
                        (backers['delta_percent'] as num?)?.toDouble(),
                    accentColor: context.fundingAccent,
                    onTap: () => onNavigate('/manage/pledges'),
                  ),
                ),
                AppSpacing.hMd,
                Expanded(
                  child: _DashboardKpiCard(
                    icon: Icons.handshake_rounded,
                    label: 'Total Sponsors',
                    value: '${sponsors?['value'] ?? 0}',
                    deltaPercent:
                        (sponsors?['delta_percent'] as num?)?.toDouble(),
                    accentColor: context.sponsorAccent,
                    onTap: () => onNavigate('/manage/sponsors'),
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.vMd,
          AnimatedListItem(
            index: 2,
            child: Row(
              children: [
                Expanded(
                  child: _DashboardKpiCard(
                    icon: Icons.event_rounded,
                    label: 'Total Events',
                    value: '${events['value'] ?? 0}',
                    deltaPercent:
                        (events['delta_percent'] as num?)?.toDouble(),
                    accentColor: context.managementAccent,
                    isActive: false,
                    onTap: () => onNavigate('/events'),
                  ),
                ),
                AppSpacing.hMd,
                Expanded(
                  child: _DashboardKpiCard(
                    icon: Icons.undo_rounded,
                    label: 'Refund Rate',
                    value:
                        '${(refundRate?['value'] as num?)?.toStringAsFixed(1) ?? '0.0'}%',
                    deltaPercent:
                        (refundRate?['delta_percent'] as num?)?.toDouble(),
                    accentColor: AppTheme.errorColor,
                    invertDelta: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardKpiCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final double? deltaPercent;
  final Color accentColor;
  final VoidCallback? onTap;
  final bool isActive;
  final bool invertDelta;

  const _DashboardKpiCard({
    required this.icon,
    required this.label,
    required this.value,
    this.deltaPercent,
    required this.accentColor,
    this.onTap,
    this.isActive = false,
    this.invertDelta = false,
  });

  @override
  State<_DashboardKpiCard> createState() => _DashboardKpiCardState();
}

class _DashboardKpiCardState extends State<_DashboardKpiCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final accent = widget.accentColor;
    final delta = widget.deltaPercent;

    return Material(
      color: AppTheme.cardOf(context),
      borderRadius: AppRadius.lg,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: AppRadius.lg,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lg,
            boxShadow: AppShadow.soft(isDark),
            border: Border.all(
              color: widget.isActive
                  ? accent
                  : AppTheme.dividerOf(context),
              width: widget.isActive ? 2 : 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color:
                          accent.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: AppRadius.sm,
                    ),
                    child: Icon(widget.icon, size: 18, color: accent),
                  ),
                  if (delta != null) ...[
                    const Spacer(),
                    ScaleTransition(
                      scale: CurvedAnimation(
                          parent: _ctrl, curve: Curves.elasticOut),
                      child: Builder(builder: (_) {
                        final isPositive = widget.invertDelta
                            ? delta < 0
                            : delta >= 0;
                        final deltaColor = isPositive
                            ? AppTheme.successColor
                            : AppTheme.errorColor;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: deltaColor.withValues(
                                alpha: isDark ? 0.2 : 0.1),
                            borderRadius: AppRadius.pill,
                          ),
                          child: Text(
                            '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: deltaColor,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ],
              ),
              AppSpacing.vMd,
              Text(
                widget.value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
              AppSpacing.vXs,
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
