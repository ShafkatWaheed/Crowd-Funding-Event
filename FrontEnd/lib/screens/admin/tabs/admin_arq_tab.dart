import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../admin_shared.dart';
import '../../../config/theme.dart';
import '../../../models/admin.dart';
import 'package:provider/provider.dart';

import '../../../providers/admin_provider.dart';
import '../../../widgets/app_toast.dart';

class AdminArqTab extends StatefulWidget {
  final void Function(String) onSnack;
  final List<PlatformSetting> settings;
  final void Function(String key, String value) onUpdateSetting;

  const AdminArqTab({
    super.key,
    required this.onSnack,
    required this.settings,
    required this.onUpdateSetting,
  });

  @override
  State<AdminArqTab> createState() => _AdminArqTabState();
}

class _AdminArqTabState extends State<AdminArqTab> {
  List<AdminWorkerTask> _tasks = [];
  bool _summaryLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _summaryLoading = true);
    try {
      final data = await context.read<AdminProvider>().getWorkerSummary();
      if (mounted) {
        setState(() {
          _tasks = data.tasks;
          _summaryLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _summaryLoading = false);
      if (mounted) AppToast.fromError(context, e, fallback: 'Failed to load worker summary');
    }
  }

  Future<void> _toggleTask(String settingKey, bool currentlyEnabled) async {
    widget.onUpdateSetting(settingKey, currentlyEnabled ? 'false' : 'true');
    await Future.delayed(const Duration(milliseconds: 500));
    _loadSummary();
  }

  Future<void> _refresh() async {
    await _loadSummary();
  }

  String _taskLabel(String name) {
    const labels = {
      'mock_auto_settle': 'Mock Auto-Settle',
      'check_all_ticket_escrows': 'Ticket Escrow Check',
      'check_all_sponsor_escrows': 'Sponsor Escrow Check',
      'process_scheduled_payouts': 'Scheduled Payouts',
      'daily_reconciliation': 'Daily Reconciliation',
    };
    return labels[name] ?? statusLabel(name);
  }

  String _schedule(String name) {
    const schedules = {
      'mock_auto_settle': 'Every 10s',
      'check_all_ticket_escrows': 'Every 15min',
      'check_all_sponsor_escrows': 'Every 15min',
      'process_scheduled_payouts': 'Daily 00:00',
      'daily_reconciliation': 'Daily 02:00',
    };
    return schedules[name] ?? '';
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'success':
        return AppTheme.successColor;
      case 'error':
        return AppTheme.errorColor;
      case 'skipped':
        return AppTheme.warningColor;
      default:
        return AppTheme.textSecondaryOf(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppTheme.primaryColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('ARQ Worker Control',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryOf(context),
              )),
          const SizedBox(height: 4),
          Text('Manage cron jobs and view execution logs',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryOf(context),
              )),
          const SizedBox(height: 20),

          _buildSummarySection(),
          const SizedBox(height: 24),
          _buildRunLogSummaryCard(),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    if (_summaryLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cron Jobs',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryOf(context),
            )),
        const SizedBox(height: 12),
        ..._tasks.map(_buildTaskCard),
      ],
    );
  }

  Widget _buildTaskCard(AdminWorkerTask task) {
    final name = task.taskName;
    final enabled = task.enabled;
    final settingKey = task.settingKey;
    final totalRuns = task.totalRuns;
    final totalErrors = task.totalErrors;
    final lastRunAt = task.lastRunAt;
    final lastStatus = task.lastStatus;

    return Card(
      color: AppTheme.cardOf(context),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_taskLabel(name),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimaryOf(context),
                          )),
                      const SizedBox(height: 2),
                      Text(_schedule(name),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryOf(context),
                          )),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: enabled,
                  activeTrackColor: AppTheme.successColor,
                  onChanged: (_) => _toggleTask(settingKey, enabled),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _statChip(Icons.play_circle_outline, '$totalRuns runs',
                    AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 12),
                _statChip(Icons.error_outline, '$totalErrors errors',
                    totalErrors > 0 ? AppTheme.errorColor : AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 12),
                if (lastStatus != null)
                  _statChip(
                    lastStatus == 'success'
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_rounded,
                    statusLabel(lastStatus),
                    _statusColor(lastStatus),
                  ),
              ],
            ),
            if (lastRunAt != null) ...[
              const SizedBox(height: 4),
              Text('Last run: ${formatIsoDate(lastRunAt)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondaryOf(context),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            )),
      ],
    );
  }

  Widget _buildRunLogSummaryCard() {
    int totalRuns = 0;
    int totalErrors = 0;
    String? latestRun;
    for (final t in _tasks) {
      totalRuns += t.totalRuns;
      totalErrors += t.totalErrors;
      final runAt = t.lastRunAt;
      if (runAt != null && (latestRun == null || runAt.compareTo(latestRun) > 0)) {
        latestRun = runAt;
      }
    }

    return Card(
      color: AppTheme.cardOf(context),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/admin/run-logs'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.list_alt, color: AppTheme.accentOf(context), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Run Logs',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryOf(context),
                        )),
                  ),
                  Icon(Icons.arrow_forward_ios,
                      size: 16, color: AppTheme.textSecondaryOf(context)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _statChip(Icons.play_circle_outline, '$totalRuns runs',
                      AppTheme.textSecondaryOf(context)),
                  const SizedBox(width: 16),
                  _statChip(Icons.error_outline, '$totalErrors errors',
                      totalErrors > 0 ? AppTheme.errorColor : AppTheme.textSecondaryOf(context)),
                ],
              ),
              if (latestRun != null) ...[
                const SizedBox(height: 6),
                Text('Last run: ${formatIsoDate(latestRun)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondaryOf(context),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
