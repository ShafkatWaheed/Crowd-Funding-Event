import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../admin_shared.dart';
import '../../../utils/date_time_utils.dart';
import '../../../config/design_tokens.dart';
import '../../../config/theme.dart';
import '../../../models/admin.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/admin_provider.dart';
import '../../../widgets/admin/admin_action_card.dart';
import '../../../widgets/admin/admin_stat_card.dart';
import '../../../widgets/app_chip.dart';

const double _wideBreakpoint = 900;

class AdminHomeTab extends StatefulWidget {
  const AdminHomeTab({
    super.key,
    this.stats,
    required this.onSnack,
    this.onNavigateToSection,
  });

  final AdminStats? stats;
  final void Function(String) onSnack;
  final void Function(int section, int filterIndex)? onNavigateToSection;

  @override
  State<AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends State<AdminHomeTab> {
  AdminDashboard? _dashboardData;
  bool _dashboardLoading = false;
  String _period = '30d';
  String? _filterGenre;
  String? _filterStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboard());
  }

  Future<void> _loadDashboard() async {
    final user = context.read<AuthProvider>().user;
    if (user == null || !user.isAdmin) return;
    setState(() => _dashboardLoading = true);
    try {
      final data = await context.read<AdminProvider>().getDashboard(
            period: _period,
            genre: _filterGenre,
            status: _filterStatus,
          );
      if (mounted) setState(() => _dashboardData = data);
    } catch (e) { debugPrint(e.toString()); }
    if (mounted) setState(() => _dashboardLoading = false);
  }

  void _onPeriodChanged(String p) {
    setState(() {
      _period = p;
      _filterGenre = null;
      _filterStatus = null;
    });
    _loadDashboard();
  }

  void _onGenreChanged(String? g) {
    setState(() {
      _filterGenre = g;
      _filterStatus = null;
    });
    _loadDashboard();
  }

  void _onStatusChanged(String? s) {
    setState(() => _filterStatus = s);
    _loadDashboard();
  }

  @override
  Widget build(BuildContext context) {
    if (_dashboardData == null && !_dashboardLoading) {
      return const Center(child: Text('Failed to load dashboard'));
    }

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFilterBar(),
                const SizedBox(height: AppSpacing.lg),
                if (_dashboardLoading && _dashboardData == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_dashboardData != null) ...[
                  _buildKpiChips(),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildTimeSeriesSection(),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildBreakdownSection(),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildHealthAndEscrow(),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildTopEvents(),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildActionItems(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Filter Bar ──

  Widget _buildFilterBar() {
    final filters = _dashboardData?.availableFilters;
    final genres = filters?.genres ?? [];
    final statuses = filters?.statuses ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final p in ['7d', '30d', '90d', '130d', '1y'])
              AppChip(
                label: p,
                selected: _period == p,
                onSelected: (_) => _onPeriodChanged(p),
                chipColor: AppTheme.accentColor,
                fontSize: 12,
              ),
            const SizedBox(width: AppSpacing.sm),
            _filterDropdown<String>(
              hint: 'Genre',
              value: _filterGenre,
              items: genres.map((g) => DropdownMenuItem(value: g, child: Text(capitalize(g)))).toList(),
              onChanged: _onGenreChanged,
            ),
            _filterDropdown<String>(
              hint: 'Status',
              value: _filterStatus,
              items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(statusLabel(s)))).toList(),
              onChanged: _onStatusChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterDropdown<T>({
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppTheme.inputFillOf(context),
        borderRadius: AppRadius.md,
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          hint: Text(hint, style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13)),
          value: value,
          items: [
            DropdownMenuItem<T>(value: null, child: Text('All $hint', style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13))),
            ...items,
          ],
          onChanged: onChanged,
          style: TextStyle(color: AppTheme.textPrimaryOf(context), fontSize: 13),
          dropdownColor: AppTheme.cardOf(context),
          icon: Icon(Icons.arrow_drop_down, color: AppTheme.textSecondaryOf(context)),
        ),
      ),
    );
  }

  // ── KPI Chips ──

  Widget _buildKpiChips() {
    final kpis = _dashboardData!.kpis;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        AdminStatCard(horizontal: true,
          icon: Icons.paid,
          label: 'Total Revenue',
          value: centsToStr(kpis.totalRevenueCents),
          color: AppTheme.accentOf(context),
        ),
        AdminStatCard(horizontal: true,
          icon: Icons.confirmation_number,
          label: 'Ticket Commission',
          value: centsToStr(kpis.ticketCommissionCents),
          color: context.sponsorAccent,
        ),
        AdminStatCard(horizontal: true,
          icon: Icons.savings,
          label: 'Funding Commission',
          value: centsToStr(kpis.fundingCommissionCents),
          color: context.ticketAccent,
        ),
        AdminStatCard(horizontal: true,
          icon: Icons.account_balance,
          label: 'Escrow Held',
          value: centsToStr(kpis.escrowHeldCents),
          color: context.fundingAccent,
        ),
        AdminStatCard(horizontal: true,
          icon: Icons.local_activity,
          label: 'Tickets Sold',
          value: '${kpis.ticketsSold}',
          color: context.ticketAccent,
        ),
        AdminStatCard(horizontal: true,
          icon: Icons.volunteer_activism,
          label: 'Pledges Made',
          value: '${kpis.pledgesMade}',
          color: context.fundingAccent,
        ),
        AdminStatCard(horizontal: true,
          icon: Icons.event,
          label: 'Total Events',
          value: '${kpis.eventsTotal}',
          color: AppTheme.accentOf(context),
        ),
        AdminStatCard(horizontal: true,
          icon: Icons.event_available,
          label: 'Live Events',
          value: '${kpis.eventsLive}',
          color: AppTheme.successOf(context),
        ),
        AdminStatCard(horizontal: true,
          icon: Icons.people,
          label: 'Total Users',
          value: '${kpis.usersTotal}',
          color: context.managementAccent,
        ),
      ],
    );
  }

  // ── Time Series Charts ──

  Widget _buildTimeSeriesSection() {
    final points = _dashboardData!.timeSeries;
    if (points.isEmpty) {
      return _emptyChartRow('Revenue Over Time', 'Activity Over Time');
    }
    final isWide = MediaQuery.of(context).size.width >= _wideBreakpoint;
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _chartCard('Revenue Over Time', _buildRevenueChart(points))),
          const SizedBox(width: AppSpacing.lg),
          Expanded(child: _chartCard('Activity Over Time', _buildActivityChart(points))),
        ],
      );
    }
    return Column(
      children: [
        _chartCard('Revenue Over Time', _buildRevenueChart(points)),
        const SizedBox(height: AppSpacing.lg),
        _chartCard('Activity Over Time', _buildActivityChart(points)),
      ],
    );
  }

  Widget _emptyChartRow(String title1, String title2) {
    final placeholder = Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 40, color: AppTheme.textSecondaryOf(context)),
            const SizedBox(height: 8),
            Text('No data for selected period',
                style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13)),
          ],
        ),
      ),
    );
    final isWide = MediaQuery.of(context).size.width >= _wideBreakpoint;
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _chartCard(title1, placeholder)),
          const SizedBox(width: AppSpacing.lg),
          Expanded(child: _chartCard(title2, placeholder)),
        ],
      );
    }
    return Column(
      children: [
        _chartCard(title1, placeholder),
        const SizedBox(height: AppSpacing.lg),
        _chartCard(title2, placeholder),
      ],
    );
  }

  Widget _chartCard(String title, Widget chart) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(height: 200, child: chart),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart(List<AdminTimeSeriesPoint> points) {
    final isDark = AppTheme.isDark(context);
    final color = AppTheme.accentColor;
    final spots = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].revenueCents.toDouble() / 100));
    }
    if (spots.isEmpty) return const SizedBox.shrink();
    final maxY = spots.map((s) => s.y).reduce(math.max);
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.2 + 1,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? maxY / 4 : 1,
          getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.dividerOf(context), strokeWidth: 0.5),
        ),
        titlesData: _chartTitles(points),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppTheme.cardOf(context),
            getTooltipItems: (touchedSpots) => touchedSpots.map((s) =>
              LineTooltipItem('\$${s.y.toStringAsFixed(0)}', TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
            ).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: spots.length > 2,
            curveSmoothness: 0.3,
            color: color,
            barWidth: 2.5,
            dotData: FlDotData(show: spots.length <= 3),
            belowBarData: BarAreaData(show: true, color: color.withValues(alpha: isDark ? 0.15 : 0.08)),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildActivityChart(List<AdminTimeSeriesPoint> points) {
    final isDark = AppTheme.isDark(context);
    final ticketColor = context.ticketAccent;
    final pledgeColor = context.fundingAccent;
    final ticketSpots = <FlSpot>[];
    final pledgeSpots = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      ticketSpots.add(FlSpot(i.toDouble(), points[i].ticketsSold.toDouble()));
      pledgeSpots.add(FlSpot(i.toDouble(), points[i].pledgesCount.toDouble()));
    }
    if (ticketSpots.isEmpty) return const SizedBox.shrink();
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
          getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.dividerOf(context), strokeWidth: 0.5),
        ),
        titlesData: _chartTitles(points),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppTheme.cardOf(context),
            getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
              final isTicket = s.barIndex == 0;
              return LineTooltipItem(
                isTicket ? '${s.y.toInt()} tickets' : '${s.y.toInt()} pledges',
                TextStyle(color: isTicket ? ticketColor : pledgeColor, fontWeight: FontWeight.w700, fontSize: 12),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: ticketSpots, isCurved: ticketSpots.length > 2, curveSmoothness: 0.3,
            color: ticketColor, barWidth: 2.5, dotData: FlDotData(show: ticketSpots.length <= 3),
            belowBarData: BarAreaData(show: true, color: ticketColor.withValues(alpha: isDark ? 0.15 : 0.08)),
          ),
          LineChartBarData(
            spots: pledgeSpots, isCurved: pledgeSpots.length > 2, curveSmoothness: 0.3,
            color: pledgeColor, barWidth: 2.5, dotData: FlDotData(show: pledgeSpots.length <= 3),
            belowBarData: BarAreaData(show: true, color: pledgeColor.withValues(alpha: isDark ? 0.15 : 0.08)),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  FlTitlesData _chartTitles(List<AdminTimeSeriesPoint> points) {
    return FlTitlesData(
      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 22,
          interval: math.max(1, (points.length / 5).ceilToDouble()),
          getTitlesWidget: (value, meta) {
            final idx = value.toInt();
            if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
            final dateStr = points[idx].date;
            final dt = DateTime.tryParse(dateStr);
            if (dt == null) return const SizedBox.shrink();
            return Text(
              AppDateFormat.dateOnly(dt),
              style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryOf(context)),
            );
          },
        ),
      ),
    );
  }

  // ── Breakdown Section (Genre Bar + Status Donut) ──

  Widget _buildBreakdownSection() {
    final isWide = MediaQuery.of(context).size.width >= _wideBreakpoint;
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildGenreBreakdown()),
          const SizedBox(width: AppSpacing.lg),
          Expanded(child: _buildStatusBreakdown()),
        ],
      );
    }
    return Column(
      children: [
        _buildGenreBreakdown(),
        const SizedBox(height: AppSpacing.lg),
        _buildStatusBreakdown(),
      ],
    );
  }

  Widget _buildGenreBreakdown() {
    final items = _dashboardData!.byGenre;
    if (items.isEmpty) return const SizedBox.shrink();

    final maxRev = items.map((r) => r.revenueCents).reduce(math.max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Revenue by Genre', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: AppSpacing.lg),
            for (final r in items) ...[
              Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: Text(capitalize(r.genre), style: TextStyle(fontSize: 12, color: AppTheme.textPrimaryOf(context))),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppTheme.dividerOf(context).withValues(alpha: 0.3),
                            borderRadius: AppRadius.sm,
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: maxRev > 0 ? r.revenueCents / maxRev : 0,
                          child: Container(
                            height: 20,
                            decoration: BoxDecoration(
                              color: genreColor(context, r.genre),
                              borderRadius: AppRadius.sm,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 70,
                    child: Text(
                      centsToStr(r.revenueCents),
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBreakdown() {
    final items = _dashboardData!.byStatus;
    if (items.isEmpty) return const SizedBox.shrink();

    final total = items.fold<int>(0, (sum, r) => sum + r.count);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Events by Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 36,
                        sections: items.map((r) {
                          return PieChartSectionData(
                            value: r.count.toDouble(),
                            color: statusColor(context, r.status),
                            radius: 40,
                            showTitle: false,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$total total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimaryOf(context))),
                      const SizedBox(height: AppSpacing.sm),
                      for (final r in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 10, height: 10, decoration: BoxDecoration(color: statusColor(context, r.status), shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text('${statusLabel(r.status)} (${r.count})', style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Health Metrics + Escrow Breakdown ──

  Widget _buildHealthAndEscrow() {
    final isWide = MediaQuery.of(context).size.width >= _wideBreakpoint;
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildEscrowBreakdown()),
          const SizedBox(width: AppSpacing.lg),
          Expanded(child: _buildHealthMetrics()),
        ],
      );
    }
    return Column(
      children: [
        _buildEscrowBreakdown(),
        const SizedBox(height: AppSpacing.lg),
        _buildHealthMetrics(),
      ],
    );
  }

  Widget _buildEscrowBreakdown() {
    final items = _dashboardData!.byEscrowStatus;
    if (items.isEmpty) return const SizedBox.shrink();

    final total = items.fold<int>(0, (sum, r) => sum + r.totalCents);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Escrow Breakdown', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 36,
                        sections: items.map((r) {
                          return PieChartSectionData(
                            value: r.totalCents.toDouble(),
                            color: escrowStatusColor(context, r.status),
                            radius: 40,
                            showTitle: false,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(centsToStr(total), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimaryOf(context))),
                      const SizedBox(height: AppSpacing.sm),
                      for (final r in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 10, height: 10, decoration: BoxDecoration(color: escrowStatusColor(context, r.status), shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text(
                                '${statusLabel(r.status)}  ${centsToStr(r.totalCents)}',
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthMetrics() {
    final kpis = _dashboardData!.kpis;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Platform Health', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: AppSpacing.lg),
            _healthTile(Icons.sync, 'Refund Rate', '${kpis.refundRatePercent.toStringAsFixed(1)}%', AppTheme.errorOf(context)),
            _healthTile(Icons.local_activity, 'Avg Ticket Price', centsToStr(kpis.avgTicketPriceCents), context.ticketAccent),
            _healthTile(Icons.flag, 'Funding Goal Hit Rate', '${kpis.fundingGoalHitRatePercent.toStringAsFixed(1)}%', AppTheme.successOf(context)),
            _healthTile(Icons.savings, 'Avg Funding / Event', centsToStr(kpis.avgFundingPerEventCents), context.fundingAccent),
          ],
        ),
      ),
    );
  }

  Widget _healthTile(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: AppRadius.sm),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)))),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
        ],
      ),
    );
  }

  // ── Top Events Leaderboard ──

  Widget _buildTopEvents() {
    final items = _dashboardData!.topEvents;
    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top Events by Revenue', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: AppSpacing.lg),
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) Divider(color: AppTheme.dividerOf(context), height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text('#${i + 1}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryOf(context))),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(items[i].title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(context)), overflow: TextOverflow.ellipsis),
                          Row(
                            children: [
                              if (items[i].genre != null)
                                Container(
                                  margin: const EdgeInsets.only(right: 6, top: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: AppTheme.accentSurfaceOf(context), borderRadius: AppRadius.pill),
                                  child: Text(items[i].genre!, style: TextStyle(fontSize: 10, color: AppTheme.accentOf(context))),
                                ),
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: statusColor(context, items[i].status).withValues(alpha: 0.15), borderRadius: AppRadius.pill),
                                child: Text(statusLabel(items[i].status), style: TextStyle(fontSize: 10, color: statusColor(context, items[i].status))),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(centsToStr(items[i].revenueCents), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.accentOf(context))),
                        Text(
                          '${items[i].ticketsSold} tix · ${centsToStr(items[i].fundingCents)} funded',
                          style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryOf(context)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Action Items ──

  Widget _buildActionItems() {
    final actions = _dashboardData!.actionItems;

    final pa = actions.pendingApproval;
    final pc = actions.pendingCancellations;
    final pe = actions.pendingExtensions;
    final ur = actions.underReview;
    final pr = actions.pendingRefunds;

    if (pa == 0 && pc == 0 && pe == 0 && ur == 0 && pr == 0) return const SizedBox.shrink();

    final onNavigate = widget.onNavigateToSection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Action Required', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimaryOf(context))),
        const SizedBox(height: AppSpacing.sm),
        if (pa > 0)
          AdminActionCard(
            icon: Icons.pending_actions,
            count: pa,
            title: '$pa events waiting approval',
            subtitle: 'Review and approve pending events',
            color: AppTheme.accentOf(context),
            onTap: () { if (onNavigate != null) { onNavigate(1, 0); } else { widget.onSnack('Tap Events tab to view'); } },
          ),
        if (pc > 0)
          AdminActionCard(
            icon: Icons.cancel_outlined,
            count: pc,
            title: '$pc pending cancellations',
            subtitle: 'Review cancellation requests',
            color: AppTheme.errorOf(context),
            onTap: () { if (onNavigate != null) { onNavigate(1, 3); } else { widget.onSnack('Tap Events tab to view'); } },
          ),
        if (pe > 0)
          AdminActionCard(
            icon: Icons.schedule,
            count: pe,
            title: '$pe pending extensions',
            subtitle: 'Review extension requests',
            color: AppTheme.warningOf(context),
            onTap: () { if (onNavigate != null) { onNavigate(1, 4); } else { widget.onSnack('Tap Events tab to view'); } },
          ),
        if (ur > 0)
          AdminActionCard(
            icon: Icons.warning_amber_rounded,
            count: ur,
            title: '$ur under review',
            subtitle: 'Investigate and resolve flagged events',
            color: AppTheme.warningOf(context),
            onTap: () { if (onNavigate != null) { onNavigate(1, 1); } else { widget.onSnack('Tap Events tab to view'); } },
          ),
        if (pr > 0)
          AdminActionCard(
            icon: Icons.receipt_long,
            count: pr,
            title: '$pr pending refunds',
            subtitle: 'Process ticket refund requests',
            color: AppTheme.errorOf(context),
            onTap: () { if (onNavigate != null) { onNavigate(2, 0); } else { widget.onSnack('Tap Financial tab to view'); } },
          ),
      ],
    );
  }
}
