import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/admin.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/app_toast.dart';
import 'admin_shared.dart';

class AdminPayoutsScreen extends StatefulWidget {
  const AdminPayoutsScreen({super.key});

  @override
  State<AdminPayoutsScreen> createState() => _AdminPayoutsScreenState();
}

class _AdminPayoutsScreenState extends State<AdminPayoutsScreen> {
  List<AdminPayoutItem> _payoutItems = [];
  bool _loading = true;
  String? _error;
  String _searchText = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPayouts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminPayoutItem> get _filteredItems {
    if (_searchText.isEmpty) return _payoutItems;
    final q = _searchText.toLowerCase();
    return _payoutItems.where((p) {
      final name = (p.organizerName ?? '').toLowerCase();
      final email = (p.organizerEmail ?? '').toLowerCase();
      final id = p.organizerId.toString();
      return name.contains(q) || email.contains(q) || id.contains(q);
    }).toList();
  }

  Future<void> _loadPayouts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final admin = context.read<AdminProvider>();
      final resp = await admin.getPayoutStatus();
      if (!mounted) return;
      setState(() {
        _payoutItems = resp;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _forcePayout(int organizerId) async {
    try {
      await context.read<AdminProvider>().forcePayout(organizerId);
      _loadPayouts();
      if (!mounted) return;
      AppToast.success(context, 'Payout initiated');
    } catch (e) {
      if (!mounted) return;
      AppToast.fromError(context, e, fallback: 'Payout failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payout Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadPayouts,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPayouts,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
              const SizedBox(height: 12),
              Text('Failed to load payouts',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryOf(context))),
              const SizedBox(height: 8),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondaryOf(context))),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
                onPressed: _loadPayouts,
              ),
            ],
          ),
        ),
      );
    }
    final filtered = _filteredItems;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, email, or ID...',
              prefixIcon: const Icon(Icons.search, size: 18),
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
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (v) => setState(() => _searchText = v),
          ),
        ),
        Expanded(
          child: _payoutItems.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 80),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 48, color: AppTheme.successColor),
                          const SizedBox(height: 12),
                          Text('No pending payouts',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimaryOf(context))),
                          const SizedBox(height: 4),
                          Text('All organizers are up to date.',
                              style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      AppTheme.textSecondaryOf(context))),
                        ],
                      ),
                    ),
                  ],
                )
              : filtered.isEmpty
                  ? Center(
                      child: Text('No results for "$_searchText"',
                          style: TextStyle(
                              color: AppTheme.textSecondaryOf(context))))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) =>
                          _buildPayoutCard(context, filtered[i]),
                    ),
        ),
      ],
    );
  }

  Widget _buildPayoutCard(BuildContext context, AdminPayoutItem p) {
    final hasBankAccount = p.hasBankAccount ||
        p.bankStatus == 'configured' ||
        p.bankStatus == 'verified';
    final pendingCents = p.pendingPayoutCents > 0 ? p.pendingPayoutCents : p.pendingAmountCents;
    final bankStatus = p.bankStatus ?? (hasBankAccount ? 'configured' : 'missing');

    final bankColor = switch (bankStatus) {
      'verified' => AppTheme.successColor,
      'configured' => AppTheme.warningColor,
      _ => AppTheme.errorColor,
    };

    return Card(
      color: AppTheme.cardOf(context),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: bankColor.withValues(alpha:0.15),
                  child: Icon(Icons.person, color: bankColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.organizerName ?? 'Organizer #${p.organizerId}',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryOf(context)),
                      ),
                      if (p.organizerEmail != null)
                        Text(p.organizerEmail!,
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondaryOf(context))),
                    ],
                  ),
                ),
                // Pending amount badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: pendingCents > 0
                        ? AppTheme.accentColor.withValues(alpha:0.1)
                        : AppTheme.successColor.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    centsToStr(pendingCents),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: pendingCents > 0
                            ? AppTheme.accentColor
                            : AppTheme.successColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Detail chips row
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _chip(context, 'Bank', statusLabel(bankStatus), bankColor),
                if (p.payoutSchedule != null)
                  _chip(context, 'Schedule', capitalize(p.payoutSchedule!),
                      AppTheme.textSecondaryOf(context)),
                if (p.nextPayoutDate != null)
                  _chip(context, 'Next', p.nextPayoutDate!,
                      AppTheme.textSecondaryOf(context)),
              ],
            ),
            // Force payout button
            if (hasBankAccount && pendingCents > 0) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('Force Payout'),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      textStyle: const TextStyle(fontSize: 13)),
                  onPressed: () => _forcePayout(p.organizerId),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
