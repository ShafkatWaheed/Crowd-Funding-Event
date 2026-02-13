import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  Map<String, dynamic>? _stats;
  List<dynamic> _users = [];
  List<dynamic> _pendingEvents = [];
  List<dynamic> _pendingApproval = [];
  List<dynamic> _pendingExtensions = [];
  List<dynamic> _pendingCancellations = [];
  List<dynamic> _settings = [];
  List<dynamic> _escrows = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 7, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final api = context.read<ApiService>();
    try {
      final results = await Future.wait([
        api.adminGetStats(),
        api.adminGetUsers(),
        api.adminGetEvents(params: {'status': 'draft'}),
        api.adminGetEvents(params: {'status': 'pending_approval'}),
        api.adminGetEvents(),
        api.dio.get('/admin/settings'),
        api.dio.get('/admin/escrows'),
      ]);
      final allEvents = results[4] as List<dynamic>;
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _users = results[1] as List<dynamic>;
        _pendingEvents = results[2] as List<dynamic>;
        _pendingApproval = results[3] as List<dynamic>;
        _pendingExtensions = allEvents
            .where((e) => e['pending_extension'] != null)
            .toList();
        _pendingCancellations = allEvents
            .where((e) => e['pending_cancellation'] != null)
            .toList();
        _settings = (results[5] as dynamic).data as List<dynamic>;
        _escrows = (results[6] as dynamic).data as List<dynamic>;
      });
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _approveEvent(int id, bool approve) async {
    try {
      final api = context.read<ApiService>();
      await api.adminApproveEvent(id, {
        'approved': approve,
        if (!approve) 'reason': 'Rejected by admin',
      });
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e')),
        );
      }
    }
  }

  Future<void> _decideExtension(int eventId, String action) async {
    try {
      final api = context.read<ApiService>();
      await api.decideExtension(eventId, action);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Extension ${action}d')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('Admin Dashboard'),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabs: [
            const Tab(text: 'Overview'),
            Tab(text: 'Pending Approval (${_pendingApproval.length})'),
            Tab(text: 'Requests (${_pendingExtensions.length + _pendingCancellations.length})'),
            const Tab(text: 'Drafts'),
            const Tab(text: 'Users'),
            Tab(text: 'Escrow (${_escrows.length})'),
            const Tab(text: 'Settings'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildOverview(),
                _buildPendingApproval(),
                _buildPendingExtensions(),
                _buildDrafts(),
                _buildUsers(),
                _buildEscrows(),
                _buildSettings(),
              ],
            ),
    );
  }

  Widget _buildOverview() {
    if (_stats == null) {
      return const Center(child: Text('Failed to load stats'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _StatCard(
                icon: Icons.people,
                label: 'Total Users',
                value: '${_stats!['users_total'] ?? _stats!['total_users'] ?? 0}',
                color: AppTheme.primaryColor,
              ),
              _StatCard(
                icon: Icons.event,
                label: 'Total Events',
                value: '${_stats!['events_total'] ?? _stats!['total_events'] ?? 0}',
                color: AppTheme.secondaryColor,
              ),
              _StatCard(
                icon: Icons.pending_actions,
                label: 'Draft Events',
                value: '${_pendingEvents.length}',
                color: AppTheme.warningColor,
              ),
              _StatCard(
                icon: Icons.monetization_on,
                label: 'Ticket Commission',
                value:
                    '\$${((_stats!['total_ticket_commission_cents'] ?? 0) / 100).toStringAsFixed(2)}',
                color: Colors.deepPurple,
              ),
              _StatCard(
                icon: Icons.savings,
                label: 'Funding Commission',
                value:
                    '\$${((_stats!['total_funding_commission_cents'] ?? 0) / 100).toStringAsFixed(2)}',
                color: Colors.teal,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingApproval() {
    if (_pendingApproval.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No events awaiting approval',
                style: TextStyle(fontSize: 18, color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingApproval.length,
      itemBuilder: (context, index) {
        final event = _pendingApproval[index];
        return Card(
          child: ListTile(
            title: Text(event['title'] ?? 'Untitled',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
                'Edited by organizer #${event['organizer_id']} — needs re-approval'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle,
                      color: AppTheme.successColor),
                  tooltip: 'Approve',
                  onPressed: () => _approveEvent(event['id'], true),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.cancel, color: AppTheme.errorColor),
                  tooltip: 'Reject (back to draft)',
                  onPressed: () => _approveEvent(event['id'], false),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _decideCancellation(int eventId, String action) async {
    try {
      final api = context.read<ApiService>();
      await api.dio.post('/events/$eventId/cancellation/approve', data: {'action': action});
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cancellation ${action}d')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e')),
        );
      }
    }
  }

  Widget _buildPendingExtensions() {
    final hasExtensions = _pendingExtensions.isNotEmpty;
    final hasCancellations = _pendingCancellations.isNotEmpty;

    if (!hasExtensions && !hasCancellations) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('No pending requests'),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Pending Cancellations ──
        if (hasCancellations) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.cancel, color: Colors.red[400], size: 20),
                const SizedBox(width: 8),
                Text('Pending Cancellations (${_pendingCancellations.length})',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
          ),
          ..._pendingCancellations.map((e) {
            final cancel = e['pending_cancellation'] as Map<String, dynamic>? ?? {};
            final pct = cancel['pledge_percent'] ?? '?';
            final reason = cancel['reason'] ?? 'No reason given';
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e['title'] ?? 'Event ${e['id']}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$pct% funded — cancellation requires approval',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red.shade800)),
                    ),
                    const SizedBox(height: 8),
                    Text('Reason: $reason', style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _decideCancellation(e['id'], 'approve'),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Approve Cancel'),
                            style: FilledButton.styleFrom(backgroundColor: Colors.red),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _decideCancellation(e['id'], 'reject'),
                            icon: const Icon(Icons.shield, size: 18),
                            label: const Text('Keep Event'),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.green.shade700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
        // ── Pending Extensions ──
        if (hasExtensions) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.schedule, color: Colors.orange[400], size: 20),
                const SizedBox(width: 8),
                Text('Pending Extensions (${_pendingExtensions.length})',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
          ),
          ..._pendingExtensions.map((e) {
            final ext = e['pending_extension'] as Map<String, dynamic>?;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e['title'] ?? 'Event ${e['id']}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('Status: ${e['status']}',
                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    if (ext != null) ...[
                      const SizedBox(height: 8),
                      if (ext['funding_end_at'] != null)
                        Text('New funding deadline: ${ext['funding_end_at']}',
                            style: const TextStyle(fontSize: 13)),
                      if (ext['funding_goal_cents'] != null)
                        Text('New funding goal: \$${(ext['funding_goal_cents'] / 100).toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 13)),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _decideExtension(e['id'], 'approve'),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Approve'),
                            style: FilledButton.styleFrom(backgroundColor: Colors.green),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _decideExtension(e['id'], 'reject'),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildDrafts() {
    if (_pendingEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No draft events',
                style: TextStyle(fontSize: 18, color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingEvents.length,
      itemBuilder: (context, index) {
        final event = _pendingEvents[index];
        return Card(
          child: ListTile(
            title: Text(event['title'] ?? 'Untitled',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
                'By organizer #${event['organizer_id']} • Capacity: ${event['max_capacity']}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.publish,
                      color: AppTheme.successColor),
                  tooltip: 'Publish',
                  onPressed: () => _approveEvent(event['id'], true),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.delete, color: AppTheme.errorColor),
                  tooltip: 'Delete',
                  onPressed: () => _approveEvent(event['id'], false),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Mask an email string: show first 2 chars + *** + @domain
  String _maskEmail(String email) {
    if (email.isEmpty) return '';
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final local = parts[0];
    final domain = parts[1];
    final visible = local.length >= 2 ? local.substring(0, 2) : local;
    return '$visible***@$domain';
  }

  Widget _buildUsers() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        final name = user['display_name'] ?? 'No name';
        final email = user['email'] ?? '';
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.surfaceColor,
              child: Text(
                (name != 'No name' ? name : email)
                    .substring(0, 1)
                    .toUpperCase(),
              ),
            ),
            title: Text(name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(email),
            trailing: Chip(
              label: Text(
                (user['role'] ?? 'unknown').toString().toUpperCase(),
                style: const TextStyle(fontSize: 11),
              ),
              backgroundColor:
                  AppTheme.primaryColor.withValues(alpha: 0.1),
              side: BorderSide.none,
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateSetting(String key, String newValue) async {
    try {
      final api = context.read<ApiService>();
      await api.dio.patch('/admin/settings/$key', data: {'value': newValue});
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Setting "$key" updated to $newValue')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update setting: $e')),
        );
      }
    }
  }

  Future<void> _escrowAction(int eventId, String action, {int? stage}) async {
    try {
      final api = context.read<ApiService>();
      final path = stage != null
          ? '/admin/escrows/$eventId/release/$stage'
          : '/admin/escrows/$eventId/$action';
      await api.dio.post(path);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Escrow action "$action" completed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Escrow action failed: $e')),
        );
      }
    }
  }

  Widget _buildEscrows() {
    if (_escrows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('No escrows yet'),
            const SizedBox(height: 8),
            Text('Escrows are created when funded events receive pledges.',
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _escrows.length,
      itemBuilder: (ctx, i) {
        final e = _escrows[i];
        final eventId = e['event_id'] ?? 0;
        final totalHeld = (e['total_held_cents'] ?? 0) as int;
        final totalReleased = (e['total_released_cents'] ?? 0) as int;
        final remaining = (e['remaining_cents'] ?? 0) as int;
        final status = e['status'] ?? 'holding';
        final s1 = e['stage1_released_at'];
        final s2 = e['stage2_released_at'];
        final s3 = e['stage3_released_at'];
        final isFrozen = status == 'frozen';
        final statusColor = isFrozen
            ? Colors.red
            : status == 'fully_released'
                ? Colors.green
                : status == 'partially_released'
                    ? Colors.orange
                    : Colors.grey;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.account_balance, size: 20, color: statusColor),
                    const SizedBox(width: 8),
                    Text('Event #$eventId',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.toUpperCase().replaceAll('_', ' '),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Amounts
                Row(
                  children: [
                    _escrowStat('Held', totalHeld, Colors.blueGrey),
                    const SizedBox(width: 16),
                    _escrowStat('Released', totalReleased, Colors.green),
                    const SizedBox(width: 16),
                    _escrowStat('Remaining', remaining, Colors.orange),
                  ],
                ),
                const SizedBox(height: 12),

                // Stage timeline
                Row(
                  children: [
                    _stageDot('S1', s1 != null, Colors.blue),
                    _stageLine(s1 != null && s2 != null),
                    _stageDot('S2', s2 != null, Colors.orange),
                    _stageLine(s2 != null && s3 != null),
                    _stageDot('S3', s3 != null, Colors.green),
                  ],
                ),
                const SizedBox(height: 12),

                // Actions
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (s1 == null)
                      _escrowBtn('Release S1', Icons.looks_one, Colors.blue,
                          () => _escrowAction(eventId, 'release', stage: 1)),
                    if (s1 != null && s2 == null)
                      _escrowBtn('Release S2', Icons.looks_two, Colors.orange,
                          () => _escrowAction(eventId, 'release', stage: 2)),
                    if (s2 != null && s3 == null)
                      _escrowBtn('Release S3', Icons.looks_3, Colors.green,
                          () => _escrowAction(eventId, 'release', stage: 3)),
                    if (!isFrozen)
                      _escrowBtn('Freeze', Icons.ac_unit, Colors.red,
                          () => _escrowAction(eventId, 'freeze'))
                    else
                      _escrowBtn('Unfreeze', Icons.wb_sunny, Colors.teal,
                          () => _escrowAction(eventId, 'unfreeze')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _escrowStat(String label, int cents, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        Text('\$${(cents / 100).toStringAsFixed(2)}',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: color)),
      ],
    );
  }

  Widget _stageDot(String label, bool done, Color color) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: done ? color : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 9, color: done ? color : Colors.grey[400])),
      ],
    );
  }

  Widget _stageLine(bool active) {
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: active ? Colors.green.shade300 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _escrowBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 32,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
    );
  }

  Widget _buildSettings() {
    if (_settings.isEmpty) {
      return const Center(child: Text('No settings configured'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Platform Settings',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Configure commission rates and platform rules.',
                  style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 20),
              ..._settings.map((s) {
                final key = s['key'] ?? '';
                final value = s['value'] ?? '';
                final desc = s['description'] ?? '';
                final isPercent = key.contains('percent');
                final isCents = key.contains('_cents');
                final isCommunity = key.startsWith('community');
                final iconData = isCommunity
                    ? Icons.groups_rounded
                    : key.contains('ticket')
                        ? Icons.confirmation_number
                        : key.contains('funding') || key.contains('escrow')
                            ? Icons.savings
                            : key.contains('cancel') || key.contains('grace') || key.contains('scan')
                                ? Icons.shield_rounded
                                : Icons.settings;
                final color = isCommunity
                    ? Colors.orange
                    : key.contains('ticket')
                        ? Colors.deepPurple
                        : key.contains('funding') || key.contains('escrow')
                            ? Colors.teal
                            : AppTheme.primaryColor;
                // Format display value
                String displayValue = value;
                if (isPercent) {
                  displayValue = '$value%';
                } else if (isCents) {
                  final parsed = int.tryParse(value);
                  displayValue = parsed != null ? '\$${(parsed / 100).toStringAsFixed(2)}' : value;
                }
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(iconData, color: color, size: 22),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                key.replaceAll('_', ' ').toUpperCase(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              if (desc.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(desc,
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey[500])),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 100,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(
                                  displayValue,
                                  style: TextStyle(
                                      fontSize: isCents ? 16 : 22,
                                      fontWeight: FontWeight.bold,
                                      color: color),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          tooltip: 'Edit',
                          onPressed: () {
                            final ctrl = TextEditingController(text: value);
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text('Edit ${key.replaceAll('_', ' ')}'),
                                content: TextField(
                                  controller: ctrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Value',
                                    suffixText: isPercent ? '%' : null,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.of(ctx).pop();
                                      _updateSetting(key, ctrl.text.trim());
                                    },
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 12),
              Text(value,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(label,
                  style:
                      TextStyle(color: Colors.grey[600], fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
