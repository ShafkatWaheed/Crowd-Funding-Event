import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';
import 'admin_shared.dart';

class AdminTransactionsScreen extends StatefulWidget {
  const AdminTransactionsScreen({super.key});

  @override
  State<AdminTransactionsScreen> createState() =>
      _AdminTransactionsScreenState();
}

class _AdminTransactionsScreenState extends State<AdminTransactionsScreen> {
  List<dynamic> _transactions = [];
  int _txnTotal = 0;
  int _txnPage = 0;
  bool _loading = true;
  String _searchText = '';
  String _statusFilter = 'all';
  bool _mockModeActive = false;

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    await Future.wait([
      _loadTransactions(),
      _loadMockMode(),
    ]);
  }

  Future<void> _loadMockMode() async {
    try {
      final overview = await ApiService.instance.adminGetBankingOverview();
      if (mounted) {
        setState(() => _mockModeActive = overview['mock_mode_active'] == true);
      }
    } catch (_) {}
  }

  Future<void> _loadTransactions({int page = 0}) async {
    setState(() => _loading = true);
    try {
      final resp = await ApiService.instance.adminGetTransactions(
        offset: page * 20,
        search: _searchText.isNotEmpty ? _searchText : null,
        status: _statusFilter != 'all' ? _statusFilter : null,
      );
      if (!mounted) return;
      setState(() {
        _transactions = resp['items'] ?? [];
        _txnTotal = resp['total'] ?? 0;
        _txnPage = page;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _simulateDispute(String transactionId) async {
    try {
      await ApiService.instance.adminSimulateDispute(transactionId);
      _loadTransactions(page: _txnPage);
      if (!mounted) return;
      AppToast.success(context, 'Dispute simulated');
    } catch (e) {
      if (!mounted) return;
      AppToast.fromError(context, e, fallback: 'Failed to simulate dispute');
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (_txnTotal / 20).ceil();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Ledger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => _loadTransactions(page: _txnPage),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadTransactions(page: 0),
        child: Column(
          children: [
            // Search & filter bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search transactions...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (v) {
                        _searchText = v;
                        _loadTransactions();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _statusFilter,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(
                          value: 'settled', child: Text('Settled')),
                      DropdownMenuItem(
                          value: 'pending', child: Text('Pending')),
                      DropdownMenuItem(
                          value: 'failed', child: Text('Failed')),
                      DropdownMenuItem(
                          value: 'completed', child: Text('Completed')),
                      DropdownMenuItem(
                          value: 'settlement_pending',
                          child: Text('Settlement Pending')),
                    ],
                    onChanged: (v) {
                      setState(() => _statusFilter = v ?? 'all');
                      _loadTransactions();
                    },
                  ),
                ],
              ),
            ),
            // Transaction list
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _transactions.isEmpty
                      ? Center(
                          child: Text('No transactions found.',
                              style: TextStyle(
                                  color:
                                      AppTheme.textSecondaryOf(context))))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _transactions.length,
                          itemBuilder: (context, i) =>
                              _buildTxnCard(context, _transactions[i]),
                        ),
            ),
            // Pagination
            if (!_loading && totalPages > 1)
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _txnPage > 0
                          ? () => _loadTransactions(page: _txnPage - 1)
                          : null,
                    ),
                    Text('Page ${_txnPage + 1} of $totalPages',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondaryOf(context))),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _txnPage < totalPages - 1
                          ? () => _loadTransactions(page: _txnPage + 1)
                          : null,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTxnCard(BuildContext context, Map<String, dynamic> t) {
    final createdAt = t['created_at'] as String?;
    final dateStr = createdAt != null
        ? createdAt.substring(0, 16).replaceFirst('T', ' ')
        : '';
    final statusColor = _statusColor(t['status']);

    return Card(
      color: AppTheme.cardOf(context),
      margin: const EdgeInsets.only(bottom: 6),
      child: ExpansionTile(
        dense: true,
        leading:
            Icon(_txnIcon(t['operation']), size: 20, color: AppTheme.accentColor),
        title: Text(
          '${t['operation'] ?? ''} · ${centsToStr(t['amount_cents'] ?? 0)}',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryOf(context)),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(t['status'] ?? '',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor)),
            ),
            const SizedBox(width: 6),
            Text(dateStr,
                style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondaryOf(context))),
          ],
        ),
        trailing: _mockModeActive
            ? IconButton(
                icon: const Icon(Icons.report_problem, size: 18),
                tooltip: 'Simulate Dispute',
                color: AppTheme.warningColor,
                onPressed: () => _simulateDispute(t['transaction_id'] as String),
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (t['from_account'] != null || t['to_account'] != null)
                  _txnDetailRow(context, 'Accounts',
                      '${t['from_account'] ?? '\u2014'} \u2192 ${t['to_account'] ?? '\u2014'}'),
                if (t['fee_cents'] != null && (t['fee_cents'] as int) > 0)
                  _txnDetailRow(
                      context, 'Fee', centsToStr(t['fee_cents'])),
                if (t['authorization_code'] != null)
                  _txnDetailRow(
                      context, 'Auth Code', '${t['authorization_code']}'),
                if (t['receipt_reference'] != null &&
                    (t['receipt_reference'] as String).isNotEmpty)
                  _txnDetailRow(
                      context, 'Receipt #', '${t['receipt_reference']}'),
                if (t['description'] != null &&
                    (t['description'] as String).isNotEmpty)
                  _txnDetailRow(
                      context, 'Description', '${t['description']}'),
                if (t['failure_reason'] != null &&
                    (t['failure_reason'] as String).isNotEmpty)
                  _txnDetailRow(
                      context, 'Failure', '${t['failure_reason']}'),
                if (t['transaction_id'] != null)
                  _txnDetailRow(
                      context, 'Transaction ID', '${t['transaction_id']}'),
                if (t['related_type'] != null)
                  _txnDetailRow(context, 'Related',
                      '${t['related_type']} #${t['related_id'] ?? ''}'),
                if (t['completed_at'] != null)
                  _txnDetailRow(context, 'Completed',
                      (t['completed_at'] as String).substring(0, 16).replaceFirst('T', ' ')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _txnIcon(String? op) {
    return switch (op) {
      'charge' => Icons.arrow_downward,
      'refund' => Icons.undo,
      'transfer' => Icons.swap_horiz,
      'hold' => Icons.pause_circle_outline,
      'release' => Icons.play_circle_outline,
      _ => Icons.receipt,
    };
  }

  Color _statusColor(String? status) {
    return switch (status) {
      'settled' || 'completed' => AppTheme.successColor,
      'pending' || 'processing' => AppTheme.warningColor,
      'failed' => AppTheme.errorColor,
      'settlement_pending' => AppTheme.accentColor,
      _ => AppTheme.textSecondaryOf(context),
    };
  }

  Widget _txnDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryOf(context))),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textPrimaryOf(context)),
                overflow: TextOverflow.ellipsis,
                maxLines: 2),
          ),
        ],
      ),
    );
  }
}
