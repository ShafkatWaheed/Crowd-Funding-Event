import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../config/design_tokens.dart';
import '../../../../config/theme.dart';
import '../../../../utils/date_time_utils.dart';
import '../../../../widgets/animated_list_item.dart';
import 'dashboard_shimmer.dart';

class DashboardChartSection extends StatelessWidget {
  final Map<String, dynamic>? timeSeriesData;
  final bool timeSeriesLoading;
  final int chartDays;

  const DashboardChartSection({
    super.key,
    required this.timeSeriesData,
    required this.timeSeriesLoading,
    required this.chartDays,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final isLoading = timeSeriesLoading && timeSeriesData == null;
    final hasData = timeSeriesData != null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, 0),
          child: AnimatedListItem(
            index: 3,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppTheme.cardOf(context),
                borderRadius: AppRadius.lg,
                boxShadow: AppShadow.soft(isDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.attach_money_rounded,
                          size: AppIconSize.md,
                          color: AppTheme.accentColor),
                      AppSpacing.hSm,
                      Text(
                        'Revenue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.vLg,
                  SizedBox(
                    height: 200,
                    child: isLoading
                        ? shimmerBox(context, height: 200)
                        : hasData
                            ? _buildRevenueChart(context)
                            : Center(
                                child: Text(
                                  'No data yet',
                                  style: TextStyle(
                                      color: AppTheme.textSecondaryOf(
                                          context)),
                                ),
                              ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
          child: AnimatedListItem(
            index: 4,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppTheme.cardOf(context),
                borderRadius: AppRadius.lg,
                boxShadow: AppShadow.soft(isDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.insights_rounded,
                          size: AppIconSize.md,
                          color: AppTheme.successColor),
                      AppSpacing.hSm,
                      Text(
                        'Activity',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.vSm,
                  Row(
                    children: [
                      _chartLegendDot(
                          context, context.ticketAccent, 'Tickets'),
                      AppSpacing.hMd,
                      _chartLegendDot(
                          context, context.fundingAccent, 'Pledges'),
                    ],
                  ),
                  AppSpacing.vLg,
                  SizedBox(
                    height: 200,
                    child: isLoading
                        ? shimmerBox(context, height: 200)
                        : hasData
                            ? _buildActivityChart(context)
                            : Center(
                                child: Text(
                                  'No data yet',
                                  style: TextStyle(
                                      color: AppTheme.textSecondaryOf(
                                          context)),
                                ),
                              ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chartLegendDot(BuildContext context, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
              fontSize: 11, color: AppTheme.textSecondaryOf(context)),
        ),
      ],
    );
  }

  Widget _buildRevenueChart(BuildContext context) {
    final points = (timeSeriesData!['points'] as List?) ?? [];
    if (points.isEmpty) {
      return Center(
        child: Text(
          'No data for this period',
          style: TextStyle(color: AppTheme.textSecondaryOf(context)),
        ),
      );
    }

    final isDark = AppTheme.isDark(context);
    final revenueColor = AppTheme.accentColor;

    final spots = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      final p = points[i] as Map;
      spots.add(FlSpot(
          i.toDouble(),
          ((p['revenue_cents'] as num?)?.toDouble() ?? 0) / 100));
    }

    final maxY = spots.map((s) => s.y).reduce(math.max);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.2 + 1,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? maxY / 4 : 1,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppTheme.dividerOf(context),
            strokeWidth: 0.5,
          ),
        ),
        titlesData: _chartTitles(context, points),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppTheme.cardOf(context),
            getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
              return LineTooltipItem(
                '\$${s.y.toStringAsFixed(0)}',
                TextStyle(
                    color: revenueColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: revenueColor,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color:
                  revenueColor.withValues(alpha: isDark ? 0.15 : 0.08),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildActivityChart(BuildContext context) {
    final points = (timeSeriesData!['points'] as List?) ?? [];
    if (points.isEmpty) {
      return Center(
        child: Text(
          'No data for this period',
          style: TextStyle(color: AppTheme.textSecondaryOf(context)),
        ),
      );
    }

    final isDark = AppTheme.isDark(context);
    final ticketColor = context.ticketAccent;
    final pledgeColor = context.fundingAccent;

    final ticketSpots = <FlSpot>[];
    final pledgeSpots = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      final p = points[i] as Map;
      ticketSpots.add(FlSpot(
          i.toDouble(), (p['tickets_sold'] as num?)?.toDouble() ?? 0));
      pledgeSpots.add(FlSpot(
          i.toDouble(), (p['pledges_count'] as num?)?.toDouble() ?? 0));
    }

    final maxY = math.max(
      ticketSpots.map((s) => s.y).reduce(math.max),
      pledgeSpots.map((s) => s.y).reduce(math.max),
    );

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.2 + 1,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? maxY / 4 : 1,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppTheme.dividerOf(context),
            strokeWidth: 0.5,
          ),
        ),
        titlesData: _chartTitles(context, points),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppTheme.cardOf(context),
            getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
              final isTicket = s.barIndex == 0;
              return LineTooltipItem(
                isTicket
                    ? '${s.y.toInt()} tickets'
                    : '${s.y.toInt()} pledges',
                TextStyle(
                  color: isTicket ? ticketColor : pledgeColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: ticketSpots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: ticketColor,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color:
                  ticketColor.withValues(alpha: isDark ? 0.15 : 0.08),
            ),
          ),
          LineChartBarData(
            spots: pledgeSpots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: pledgeColor,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color:
                  pledgeColor.withValues(alpha: isDark ? 0.15 : 0.08),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  FlTitlesData _chartTitles(BuildContext context, List points) {
    return FlTitlesData(
      leftTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 22,
          interval: math.max(1, (points.length / 5).ceilToDouble()),
          getTitlesWidget: (value, meta) {
            final idx = value.toInt();
            if (idx < 0 || idx >= points.length) {
              return const SizedBox.shrink();
            }
            final dateStr =
                (points[idx] as Map)['date'] as String? ?? '';
            final dt = DateTime.tryParse(dateStr);
            if (dt == null) return const SizedBox.shrink();
            return Text(
              AppDateFormat.dateOnly(dt),
              style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondaryOf(context)),
            );
          },
        ),
      ),
    );
  }
}
