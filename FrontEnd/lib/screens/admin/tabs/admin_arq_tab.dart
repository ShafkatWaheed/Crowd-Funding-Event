import 'package:flutter/material.dart';

import '../admin_shared.dart';
import '../../../config/theme.dart';
import '../../../services/api_service.dart';
import '../../../widgets/app_toast.dart';

class AdminArqTab extends StatefulWidget {
  final void Function(String) onSnack;
  final List<dynamic> settings;
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
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _runs = [];
  int _runsTotal = 0;
  bool _summaryLoading = true;
  bool _runsLoading = false;
  String? _selectedTask;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadSummary();
    _loadRuns();
  }

  Future<void> _loadSummary() async {
    setState(() => _summaryLoading = true);
    try {
      final data = await ApiService.instance.adminGetWorkerSummary();
      if (mounted) {
        setState(() {
          _tasks = (data['tasks'] as List).cast<Map<String, dynamic>>();
          _summaryLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _summaryLoading = false);
      if (mounted) AppToast.fromError(context, e, 'Failed to load worker summary');
    }
  }

  Future<void> _loadRuns() async {
    setState(() => _runsLoading = true);
    try {
      final data = await ApiService.instance.adminGetWorkerRuns(
        taskName: _selectedTask,
        status: _selectedStatus,
        offset: 0,
        limit: 50,
      );
      if (mounted) {
        setState(() {
          _runs = (data['items'] as List).cast<Map<String, dynamic>>();
          _runsTotal = data['total'] ?? 0;
          _runsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _runsLoading = false);
    }
  }

  Future<void> _toggleTask(String settingKey, bool currentlyEnabled) async {
    widget.onUpdateSetting(settingKey, currentlyEnabled ? 'false' : 'true');
    await Future.delayed(const Duration(milliseconds: 500));
    _loadSummary();
  }

  Future<void> _refresh() async {
    await Future.wait([_loadSummary(), _loadRuns()]);
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
          _buildRunLogSection(),
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

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final name = task['task_name'] as String;
    final enabled = task['enabled'] == true;
    final settingKey = task['setting_key'] as String;
    final totalRuns = task['total_runs'] ?? 0;
    final totalErrors = task['total_errors'] ?? 0;
    final lastRunAt = task['last_run_at'] as String?;
    final lastStatus = task['last_status'] as String?;

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
                  activeColor: AppTheme.successColor,
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

  Widget _buildRunLogSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Run Log',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryOf(context),
                  )),
            ),
            Text('$_runsTotal total',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryOf(context),
                )),
          ],
        ),
        const SizedBox(height: 10),
        _buildFilters(),
        const SizedBox(height: 10),
        if (_runsLoading)
          const Center(child: CircularProgressIndicator())
        else if (_runs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text('No runs recorded yet',
                  style: TextStyle(color: AppTheme.textSecondaryOf(context))),
            ),
          )
        else
          ..._runs.map(_buildRunRow),
      ],
    );
  }

  Widget _buildFilters() {
    final taskNames = [
      null,
      'mock_auto_settle',
      'check_all_ticket_escrows',
      'check_all_sponsor_escrows',
      'process_scheduled_payouts',
      'daily_reconciliation',
    ];
    final statuses = [null, 'success', 'error', 'skipped'];

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String?>(
            value: _selectedTask,
            decoration: InputDecoration(
              labelText: 'Task',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: taskNames
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t == null ? 'All tasks' : _taskLabel(t),
                          style: const TextStyle(fontSize: 13)),
                    ))
                .toList(),
            onChanged: (v) {
              setState(() => _selectedTask = v);
              _loadRuns();
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String?>(
            value: _selectedStatus,
            decoration: InputDecoration(
              labelText: 'Status',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: statuses
                .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s == null ? 'All' : statusLabel(s),
                          style: const TextStyle(fontSize: 13)),
                    ))
                .toList(),
            onChanged: (v) {
              setState(() => _selectedStatus = v);
              _loadRuns();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRunRow(Map<String, dynamic> run) {
    final status = run['status'] as String? ?? 'unknown';
    final taskName = run['task_name'] as String? ?? '';
    final durationMs = run['duration_ms'] as num?;
    final items = run['items_processed'] as int?;
    final error = run['error'] as String?;
    final startedAt = run['started_at'] as String?;

    return Card(
      color: AppTheme.cardOf(context),
      margin: const EdgeInsets.only(bottom: 6),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        leading: Icon(
          status == 'success'
              ? Icons.check_circle_rounded
              : status == 'error'
                  ? Icons.error_rounded
                  : Icons.info_outline,
          color: _statusColor(status),
          size: 20,
        ),
        title: Text(_taskLabel(taskName),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${formatIsoDate(startedAt)} \u2022 ${durationMs != null ? '${durationMs.toStringAsFixed(0)}ms' : '-'}',
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
        ),
        trailing: items != null
            ? Text('$items items',
                style: TextStyle(
                    fontSize: 11, color: AppTheme.textSecondaryOf(context)))
            : null,
        children: [
          if (error != null && error.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(error,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: AppTheme.errorColor,
                  )),
            ),
          if (error == null || error.isEmpty)
            Text('Completed successfully',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textSecondaryOf(context))),
        ],
      ),
    );
  }
}
