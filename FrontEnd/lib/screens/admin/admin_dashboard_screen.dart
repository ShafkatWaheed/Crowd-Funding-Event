import 'package:flutter/material.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final api = context.read<ApiService>();
    try {
      final results = await Future.wait([
        api.adminGetStats(),
        api.adminGetUsers(),
        api.adminGetEvents(params: {'status': 'pending_approval'}),
      ]);
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _users = results[1] as List<dynamic>;
        _pendingEvents = results[2] as List<dynamic>;
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

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Approvals'),
            Tab(text: 'Users'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildOverview(),
                _buildApprovals(),
                _buildUsers(),
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
                value: '${_stats!['total_users'] ?? 0}',
                color: AppTheme.primaryColor,
              ),
              _StatCard(
                icon: Icons.event,
                label: 'Total Events',
                value: '${_stats!['total_events'] ?? 0}',
                color: AppTheme.secondaryColor,
              ),
              _StatCard(
                icon: Icons.pending_actions,
                label: 'Pending Approval',
                value: '${_pendingEvents.length}',
                color: AppTheme.warningColor,
              ),
              _StatCard(
                icon: Icons.attach_money,
                label: 'Total Pledged',
                value:
                    '\$${((_stats!['total_pledged_cents'] ?? 0) / 100).toStringAsFixed(2)}',
                color: AppTheme.successColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApprovals() {
    if (_pendingEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No pending approvals',
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
                  icon: const Icon(Icons.check_circle,
                      color: AppTheme.successColor),
                  tooltip: 'Approve',
                  onPressed: () => _approveEvent(event['id'], true),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.cancel, color: AppTheme.errorColor),
                  tooltip: 'Reject',
                  onPressed: () => _approveEvent(event['id'], false),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsers() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.surfaceColor,
              child: Text(
                (user['display_name'] ?? user['email'] ?? '?')
                    .substring(0, 1)
                    .toUpperCase(),
              ),
            ),
            title: Text(user['display_name'] ?? 'No name',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(user['email'] ?? ''),
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
