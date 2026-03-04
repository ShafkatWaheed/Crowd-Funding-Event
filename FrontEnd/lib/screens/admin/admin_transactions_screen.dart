import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/admin.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/app_toast.dart';
import 'admin_shared.dart';

class AdminTransactionsScreen extends StatefulWidget {
  const AdminTransactionsScreen({super.key});

  @override
  State<AdminTransactionsScreen> createState() =>
      _AdminTransactionsScreenState();
}

class _AdminTransactionsScreenState extends State<AdminTransactionsScreen> {
  List<AdminTransaction> _transactions = [];
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
      final admin = context.read<AdminProvider>();
      final overview = await admin.getBankingOverview();
      if (mounted) {
        setState(() => _mockModeActive = overview.mockModeActive);
      }
    } catch (_) {}
  }

  Future<void> _loadTransactions({int page = 0}) async {
    setState(() => _loading = true);
    try {
      final admin = context.read<AdminProvider>();
      final resp = await admin.getTransactions(
        offset: page * 20,
        search: _searchText.isNotEmpty ? _searchText : null,
        status: _statusFilter != 'all' ? _statusFilter : null,
      );
      if (!mounted) return;
      setState(() {
        _transactions = resp.items;
        _txnTotal = resp.total;
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
      await context.read<AdminProvider>().simulateDispute(transactionId);
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

  Widget _buildTxnCard(BuildContext context, AdminTransaction t) {
    final createdAt = t.createdAt;
    final dateStr = createdAt != null
        ? createdAt.substring(0, 16).replaceFirst('T', ' ')
        : '';
    final statusColor = _statusColor(t.status);

    return Card(
      color: AppTheme.cardOf(context),
      margin: const EdgeInsets.only(bottom: 6),
      child: ExpansionTile(
        dense: true,
        leading:
            Icon(_txnIcon(t.operation), size: 20, color: AppTheme.accentColor),
        title: Text(
          '${t.operation} · ${centsToStr(t.amountCents)}',
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
              child: Text(t.status,
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
        trailing: _mockModeActive && t.transactionId != null
            ? IconButton(
                icon: const Icon(Icons.report_problem, size: 18),
                tooltip: 'Simulate Dispute',
                color: AppTheme.warningColor,
                onPressed: () => _simulateDispute(t.transactionId!),
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (t.fromAccount != null || t.toAccount != null)
                  _txnDetailRow(context, 'Accounts',
                      '${t.fromAccount ?? '\u2014'} \u2192 ${t.toAccount ?? '\u2014'}'),
                if (t.feeCents > 0)
                  _txnDetailRow(
                      context, 'Fee', centsToStr(t.feeCents)),
                if (t.authorizationCode != null)
                  _txnDetailRow(
                      context, 'Auth Code', t.authorizationCode!),
                if (t.receiptReference?.isNotEmpty == true)
                  _txnDetailRow(
                      context, 'Receipt #', t.receiptReference!),
                if (t.description?.isNotEmpty == true)
                  _txnDetailRow(
                      context, 'Description', t.description!),
                if (t.failureReason?.isNotEmpty == true)
                  _txnDetailRow(
                      context, 'Failure', t.failureReason!),
                if (t.transactionId != null)
                  _txnDetailRow(
                      context, 'Transaction ID', t.transactionId!),
                if (t.relatedType != null)
                  _txnDetailRow(context, 'Related',
                      '${t.relatedType} #${t.relatedId ?? ''}'),
                if (t.completedAt != null)
                  _txnDetailRow(context, 'Completed',
                      t.completedAt!.substring(0, 16).replaceFirst('T', ' ')),
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
