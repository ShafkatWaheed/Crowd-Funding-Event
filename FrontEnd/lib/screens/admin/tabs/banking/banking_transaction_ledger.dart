import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../services/api_service.dart';
import '../../../../widgets/app_toast.dart';
import '../../admin_shared.dart';

class BankingTransactionLedger extends StatelessWidget {
  final List<dynamic> transactions;
  final int txnTotal;
  final int txnPage;
  final bool txnLoading;
  final String txnSearch;
  final String txnStatusFilter;
  final bool mockModeActive;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusFilterChanged;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onReloadBanking;
  final VoidCallback onReloadDisputes;

  const BankingTransactionLedger({
    super.key,
    required this.transactions,
    required this.txnTotal,
    required this.txnPage,
    required this.txnLoading,
    required this.txnSearch,
    required this.txnStatusFilter,
    required this.mockModeActive,
    required this.onSearchChanged,
    required this.onStatusFilterChanged,
    required this.onPageChanged,
    required this.onReloadBanking,
    required this.onReloadDisputes,
  });

  @override
  Widget build(BuildContext context) {
    final totalPages = (txnTotal / 20).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Transaction Ledger',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryOf(context))),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                    hintText: 'Search transactions…',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8))),
                onChanged: onSearchChanged,
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: txnStatusFilter,
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
                    value: 'refunded', child: Text('Refunded')),
              ],
              onChanged: (v) => onStatusFilterChanged(v ?? 'all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (txnLoading)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator())),
        if (!txnLoading)
          ...transactions.map<Widget>((t) {
            final createdAt = t['created_at'] as String?;
            final dateStr = createdAt != null
                ? createdAt.substring(0, 16).replaceFirst('T', ' ')
                : '';
            return Card(
              color: AppTheme.cardOf(context),
              child: ExpansionTile(
                dense: true,
                leading: Icon(_txnIcon(t['operation']),
                    size: 20, color: AppTheme.accentColor),
                title: Text(
                    '${t['operation'] ?? ''} · ${centsToStr(t['amount_cents'] ?? 0)}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryOf(context))),
                subtitle: Text('${t['status'] ?? ''} · $dateStr',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondaryOf(context))),
                trailing: mockModeActive
                    ? IconButton(
                        icon: const Icon(Icons.report_problem,
                            size: 18),
                        tooltip: 'Simulate Dispute',
                        color: AppTheme.warningColor,
                        onPressed: () async {
                          try {
                            await ApiService.instance
                                .adminSimulateDispute(
                                    t['transaction_id'] as String);
                            onReloadBanking();
                            onReloadDisputes();
                            if (context.mounted) {
                              AppToast.success(
                                  context, 'Dispute simulated');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              AppToast.fromError(context, e,
                                  fallback:
                                      'Failed to simulate dispute');
                            }
                          }
                        },
                      )
                    : null,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (t['from_account'] != null ||
                            t['to_account'] != null)
                          _txnDetailRow(context, 'Accounts',
                              '${t['from_account'] ?? '—'} → ${t['to_account'] ?? '—'}'),
                        if (t['authorization_code'] != null)
                          _txnDetailRow(context, 'Auth Code',
                              '${t['authorization_code']}'),
                        if (t['receipt_reference'] != null &&
                            (t['receipt_reference'] as String)
                                .isNotEmpty)
                          _txnDetailRow(context, 'Receipt #',
                              '${t['receipt_reference']}'),
                        if (t['description'] != null &&
                            (t['description'] as String).isNotEmpty)
                          _txnDetailRow(context, 'Description',
                              '${t['description']}'),
                        if (t['transaction_id'] != null)
                          _txnDetailRow(context, 'Transaction ID',
                              '${t['transaction_id']}'),
                        if (t['related_type'] != null)
                          _txnDetailRow(context, 'Related',
                              '${t['related_type']} #${t['related_id'] ?? ''}'),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        if (!txnLoading && totalPages > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: txnPage > 0
                        ? () => onPageChanged(txnPage - 1)
                        : null),
                Text('Page ${txnPage + 1} of $totalPages',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryOf(context))),
                IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: txnPage < totalPages - 1
                        ? () => onPageChanged(txnPage + 1)
                        : null),
              ],
            ),
          ),
      ],
    );
  }

  IconData _txnIcon(String? op) {
    switch (op) {
      case 'charge':
        return Icons.arrow_downward;
      case 'refund':
        return Icons.undo;
      case 'transfer':
        return Icons.swap_horiz;
      default:
        return Icons.receipt;
    }
  }

  Widget _txnDetailRow(
      BuildContext context, String label, String value) {
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
                      color: AppTheme.textSecondaryOf(context)))),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textPrimaryOf(context)),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2)),
        ],
      ),
    );
  }
}
