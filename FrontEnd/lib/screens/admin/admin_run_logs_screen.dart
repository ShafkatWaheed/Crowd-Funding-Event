import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';
import 'admin_shared.dart';

class AdminRunLogsScreen extends StatefulWidget {
  const AdminRunLogsScreen({super.key});

  @override
  State<AdminRunLogsScreen> createState() => _AdminRunLogsScreenState();
}

class _AdminRunLogsScreenState extends State<AdminRunLogsScreen> {
  List<Map<String, dynamic>> _runs = [];
  int _runsTotal = 0;
  bool _loading = true;
  String? _selectedTask;
  String? _selectedStatus;
  String _searchText = '';
  final _searchController = TextEditingController();

  static const _taskNames = [
    null,
    'mock_auto_settle',
    'check_all_ticket_escrows',
    'check_all_sponsor_escrows',
    'process_scheduled_payouts',
    'daily_reconciliation',
  ];
  static const _statuses = [null, 'success', 'error', 'skipped'];

  static const _taskLabels = {
    'mock_auto_settle': 'Mock Auto-Settle',
    'check_all_ticket_escrows': 'Ticket Escrow Check',
    'check_all_sponsor_escrows': 'Sponsor Escrow Check',
    'process_scheduled_payouts': 'Scheduled Payouts',
    'daily_reconciliation': 'Daily Reconciliation',
  };

  String _taskLabel(String name) => _taskLabels[name] ?? statusLabel(name);

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
  void initState() {
    super.initState();
    _loadRuns();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRuns() async {
    setState(() => _loading = true);
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
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredRuns {
    if (_searchText.isEmpty) return _runs;
    final q = _searchText.toLowerCase();
    return _runs.where((r) {
      final task = (r['task_name'] ?? '').toString().toLowerCase();
      final label = _taskLabel(task).toLowerCase();
      final error = (r['error'] ?? '').toString().toLowerCase();
      final status = (r['status'] ?? '').toString().toLowerCase();
      return task.contains(q) ||
          label.contains(q) ||
          error.contains(q) ||
          status.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Run Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadRuns,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRuns,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by task name, status, or error...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchText.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchText = '');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                style: TextStyle(
                    fontSize: 14, color: AppTheme.textPrimaryOf(context)),
                onChanged: (v) => setState(() => _searchText = v.trim()),
              ),
              const SizedBox(height: 12),
              _buildFilters(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('$_runsTotal total',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryOf(context),
                      )),
                ],
              ),
              const SizedBox(height: 8),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_filteredRuns.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text('No runs found',
                        style: TextStyle(
                            color: AppTheme.textSecondaryOf(context))),
                  ),
                )
              else
                ..._filteredRuns.map(_buildRunRow),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String?>(
            initialValue: _selectedTask,
            decoration: InputDecoration(
              labelText: 'Task',
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: _taskNames
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(
                          t == null ? 'All tasks' : _taskLabel(t),
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
            initialValue: _selectedStatus,
            decoration: InputDecoration(
              labelText: 'Status',
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: _statuses
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
          style: TextStyle(
              fontSize: 11, color: AppTheme.textSecondaryOf(context)),
        ),
        trailing: items != null
            ? Text('$items items',
                style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondaryOf(context)))
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
                    fontSize: 12,
                    color: AppTheme.textSecondaryOf(context))),
        ],
      ),
    );
  }
}
