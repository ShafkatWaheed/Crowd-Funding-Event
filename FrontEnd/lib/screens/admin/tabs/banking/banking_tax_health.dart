import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../../../models/admin.dart';
import '../../../../providers/admin_provider.dart';
import '../../../../widgets/app_toast.dart';
import '../../admin_shared.dart';

class BankingTaxConfigSection extends StatelessWidget {
  final String Function(String key) settingVal;
  final void Function(String key, String value) onUpdateSetting;

  const BankingTaxConfigSection({
    super.key,
    required this.settingVal,
    required this.onUpdateSetting,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tax Configuration',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryOf(context))),
        const SizedBox(height: 8),
        Card(
          color: AppTheme.cardOf(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _taxToggleRow(context, 'Tax Enabled', 'tax_enabled'),
                const Divider(),
                _taxInputRow(
                    context, 'Default Tax Rate (%)', 'default_tax_rate'),
                _taxInputRow(context, 'Tax Jurisdiction',
                    'default_tax_jurisdiction'),
                const Divider(),
                _taxToggleRow(context, 'Applies to Tickets',
                    'tax_applies_to_tickets'),
                _taxToggleRow(context, 'Applies to Sponsors',
                    'tax_applies_to_sponsors'),
                _taxToggleRow(context, 'Applies to Pledges',
                    'tax_applies_to_pledges'),
                const Divider(),
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 14, color: AppTheme.warningColor),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(
                            'Tax collected is a liability — remit to tax authority quarterly.',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.warningColor,
                                fontStyle: FontStyle.italic))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _taxToggleRow(BuildContext context, String label, String key) {
    final val = settingVal(key);
    final enabled = val == 'true' || val == '1';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textPrimaryOf(context))),
          Switch(
            value: enabled,
            activeTrackColor: AppTheme.accentOf(context),
            onChanged: (v) =>
                onUpdateSetting(key, v ? 'true' : 'false'),
          ),
        ],
      ),
    );
  }

  Widget _taxInputRow(BuildContext context, String label, String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              flex: 2,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textPrimaryOf(context)))),
          Expanded(
            flex: 3,
            child: TextField(
              controller: TextEditingController(text: settingVal(key)),
              decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6))),
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textPrimaryOf(context)),
              onSubmitted: (v) => onUpdateSetting(key, v),
            ),
          ),
        ],
      ),
    );
  }
}

class BankingLedgerHealthCard extends StatelessWidget {
  final AdminLedgerHealth? ledgerHealth;
  final bool ledgerHealthLoading;

  const BankingLedgerHealthCard({
    super.key,
    required this.ledgerHealth,
    required this.ledgerHealthLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ledger Health',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryOf(context))),
        const SizedBox(height: 8),
        if (ledgerHealthLoading)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator())),
        if (!ledgerHealthLoading && ledgerHealth != null)
          Card(
            color: AppTheme.cardOf(context),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        ledgerHealth!.balanced
                            ? Icons.check_circle
                            : Icons.error,
                        color: ledgerHealth!.balanced
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                        ledgerHealth!.balanced
                            ? 'Ledger is balanced'
                            : 'Ledger imbalance detected',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: ledgerHealth!.balanced
                                ? AppTheme.successColor
                                : AppTheme.errorColor),
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ledgerRow(context, 'Total Debits',
                      centsToStr(ledgerHealth!.totalDebitsCents)),
                  _ledgerRow(context, 'Total Credits',
                      centsToStr(ledgerHealth!.totalCreditsCents)),
                  if (ledgerHealth!.accounts.isNotEmpty) ...[
                    const Divider(),
                    Text('Per-Account Balances',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                AppTheme.textSecondaryOf(context))),
                    const SizedBox(height: 4),
                    ...ledgerHealth!.accounts.entries
                        .map<Widget>((e) => _ledgerRow(context,
                            e.key, centsToStr(e.value ?? 0))),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _ledgerRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryOf(context))),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryOf(context))),
        ],
      ),
    );
  }
}

class BankingReconciliationChart extends StatelessWidget {
  final List<ReconciliationEntry> reconHistory;
  final bool reconHistoryLoading;

  const BankingReconciliationChart({
    super.key,
    required this.reconHistory,
    required this.reconHistoryLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (reconHistoryLoading) return const SizedBox.shrink();
    if (reconHistory.isEmpty) return const SizedBox.shrink();
    final items = reconHistory.take(30).toList().reversed.toList();
    final maxDelta = items.fold<int>(
        1,
        (m, r) =>
            r.deltaCents.abs() > m ? r.deltaCents.abs() : m);
    return Card(
      color: AppTheme.cardOf(context),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Reconciliation History (last ${items.length} runs)',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: items.map<Widget>((r) {
                  final delta = r.deltaCents.abs();
                  final balanced = r.status == 'balanced';
                  final barHeight = maxDelta > 0
                      ? (delta / maxDelta * 60).clamp(2.0, 60.0)
                      : 2.0;
                  return Expanded(
                    child: Tooltip(
                      message:
                          '${r.runDate ?? ''}: delta ${centsToStr(delta)}',
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 1),
                        height: balanced ? 2 : barHeight,
                        decoration: BoxDecoration(
                          color: balanced
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    items.isNotEmpty
                        ? items.first.runDate ?? ''
                        : '',
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondaryOf(context))),
                Text(
                    items.length > 1
                        ? items.last.runDate ?? ''
                        : '',
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondaryOf(context))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BankingReconciliationStatus extends StatelessWidget {
  final AdminBankingOverview bankingData;
  final VoidCallback onReloadBanking;
  final VoidCallback? onReloadReconHistory;

  const BankingReconciliationStatus({
    super.key,
    required this.bankingData,
    required this.onReloadBanking,
    this.onReloadReconHistory,
  });

  @override
  Widget build(BuildContext context) {
    final d = bankingData;
    return Card(
      color: AppTheme.cardOf(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              d.lastReconciliationStatus == 'balanced'
                  ? Icons.check_circle
                  : Icons.error,
              color: d.lastReconciliationStatus == 'balanced'
                  ? AppTheme.successColor
                  : AppTheme.errorColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                d.lastReconciliationStatus != null
                    ? 'Last: ${d.lastReconciliationStatus} (delta: ${centsToStr(d.lastReconciliationDeltaCents.abs())})'
                    : 'No reconciliation run yet',
                style: TextStyle(
                    color: AppTheme.textPrimaryOf(context)),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Run Now'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 13),
              ),
              onPressed: () async {
                try {
                  await context
                      .read<AdminProvider>()
                      .runReconciliation();
                  onReloadBanking();
                  onReloadReconHistory?.call();
                  if (context.mounted) {
                    AppToast.success(
                        context, 'Reconciliation completed');
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppToast.fromError(context, e,
                        fallback: 'Reconciliation failed');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
