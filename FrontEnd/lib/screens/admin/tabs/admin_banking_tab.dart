import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../admin_shared.dart';
import '../../../config/theme.dart';
import 'package:provider/provider.dart';

import '../../../repositories/admin_repository.dart';
import 'banking/banking_disputes_payout.dart';
import 'banking/banking_tax_health.dart';

class AdminBankingTab extends StatefulWidget {
  const AdminBankingTab({
    super.key,
    required this.settings,
    required this.onSnack,
    required this.onUpdateSetting,
    required this.mockModeActive,
  });

  final List<dynamic> settings;
  final void Function(String) onSnack;
  final void Function(String key, String value) onUpdateSetting;
  final bool mockModeActive;

  @override
  State<AdminBankingTab> createState() => _AdminBankingTabState();
}

class _AdminBankingTabState extends State<AdminBankingTab> {
  Map<String, dynamic>? _bankingData;
  bool _bankingLoading = false;

  List<dynamic> _reconHistory = [];
  bool _reconHistoryLoading = false;

  Map<String, dynamic>? _ledgerHealth;
  bool _ledgerHealthLoading = false;

  List<dynamic> _disputes = [];
  bool _disputesLoading = false;

  // Auto-refresh
  bool _autoRefresh = false;
  int _refreshIntervalSeconds = 30;
  Timer? _refreshTimer;
  DateTime? _lastRefreshed;

  String _settingVal(String key) {
    final s = widget.settings.cast<Map<String, dynamic>?>().firstWhere(
          (e) => e != null && e['key'] == key,
          orElse: () => null,
        );
    return s?['value']?.toString() ?? '';
  }

  Future<void> _loadBankingData() async {
    // Only show full-page spinner on first load; reloads update in-place
    if (_bankingData == null) setState(() => _bankingLoading = true);
    try {
      final admin = context.read<AdminRepository>();
      final data = await admin.getBankingOverview();
      if (mounted) setState(() { _bankingData = data; _bankingLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _bankingLoading = false);
    }
  }

  Future<void> _loadReconHistory() async {
    setState(() => _reconHistoryLoading = true);
    try {
      final admin = context.read<AdminRepository>();
      final resp = await admin.getReconciliationHistory();
      setState(() => _reconHistory = resp);
    } catch (e) { debugPrint(e.toString()); }
    setState(() => _reconHistoryLoading = false);
  }

  Future<void> _loadLedgerHealth() async {
    setState(() => _ledgerHealthLoading = true);
    try {
      final admin = context.read<AdminRepository>();
      final resp = await admin.getLedgerHealth();
      setState(() => _ledgerHealth = resp);
    } catch (e) { debugPrint(e.toString()); }
    setState(() => _ledgerHealthLoading = false);
  }

  Future<void> _loadDisputes() async {
    setState(() => _disputesLoading = true);
    try {
      final admin = context.read<AdminRepository>();
      final resp = await admin.getDisputes();
      setState(() => _disputes = (resp['items'] as List?) ?? []);
    } catch (e) { debugPrint(e.toString()); }
    setState(() => _disputesLoading = false);
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadBankingData(),
      _loadDisputes(),
      _loadReconHistory(),
      _loadLedgerHealth(),
    ]);
    if (mounted) setState(() => _lastRefreshed = DateTime.now());
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      Duration(seconds: _refreshIntervalSeconds),
      (_) => _refreshAll(),
    );
  }

  void _stopTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void _toggleAutoRefresh(bool enabled) {
    setState(() => _autoRefresh = enabled);
    if (enabled) {
      _startTimer();
    } else {
      _stopTimer();
    }
  }

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Widget _buildRefreshBar(BuildContext context) {
    final intervals = [15, 30, 60, 120];
    final lastFmt = _lastRefreshed == null
        ? 'Never'
        : '${_lastRefreshed!.hour.toString().padLeft(2, '0')}:${_lastRefreshed!.minute.toString().padLeft(2, '0')}:${_lastRefreshed!.second.toString().padLeft(2, '0')}';

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          tooltip: 'Refresh now',
          onPressed: _refreshAll,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 6),
        Text('Last: $lastFmt', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
        const Spacer(),
        Text('Auto-refresh', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
        const SizedBox(width: 4),
        Switch(
          value: _autoRefresh,
          onChanged: _toggleAutoRefresh,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        if (_autoRefresh) ...[
          const SizedBox(width: 4),
          DropdownButton<int>(
            value: _refreshIntervalSeconds,
            isDense: true,
            underline: const SizedBox(),
            items: intervals.map((s) => DropdownMenuItem(
              value: s,
              child: Text('${s}s', style: const TextStyle(fontSize: 12)),
            )).toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _refreshIntervalSeconds = v);
              if (_autoRefresh) _startTimer();
            },
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_bankingLoading || _bankingData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final d = _bankingData!;
    final mockActive = d['mock_mode_active'] == true || widget.mockModeActive;
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mockActive) _buildMockBanner(context),
            if (d['stripe_enabled'] == true)
              _buildStripeBanner(context, d['stripe_connect_enabled'] == true),
            _buildRefreshBar(context),
            const SizedBox(height: 8),
            Text('Platform Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: 8),
            PlatformAccountCard(
              configured: d['platform_account_configured'] == true,
              institutionNumber: d['platform_account_institution'] as String?,
              transitNumber: d['platform_account_transit'] as String?,
              lastFour: d['platform_account_last_four'] as String?,
              onSaved: () => _loadBankingData(),
            ),
            const SizedBox(height: 16),
            _buildEscrowSummary(context, d),
            const SizedBox(height: 16),
            _buildCommissionTax(context, d),
            const SizedBox(height: 16),
            Text('Disputes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: infoCard(context, 'Open Disputes', '${d['disputes_open_count'] ?? 0}', Icons.gavel, AppTheme.errorColor)),
                const SizedBox(width: 8),
                Expanded(child: infoCard(context, 'Disputed Amount', centsToStr(d['disputes_total_amount_cents'] ?? 0), Icons.money_off, AppTheme.errorColor)),
              ],
            ),
            const SizedBox(height: 8),
            BankingDisputesSection(disputes: _disputes, disputesLoading: _disputesLoading, onReloadDisputes: _loadDisputes, onReloadBanking: _loadBankingData),
            const SizedBox(height: 16),
            Text('Reconciliation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: 8),
            BankingReconciliationStatus(bankingData: d, onReloadBanking: _loadBankingData, onReloadReconHistory: _loadReconHistory),
            const SizedBox(height: 8),
            BankingReconciliationChart(reconHistory: _reconHistory, reconHistoryLoading: _reconHistoryLoading),
            const SizedBox(height: 16),
            BankingTaxConfigSection(settingVal: _settingVal, onUpdateSetting: widget.onUpdateSetting),
            const SizedBox(height: 16),
            BankingLedgerHealthCard(ledgerHealth: _ledgerHealth, ledgerHealthLoading: _ledgerHealthLoading),
            const SizedBox(height: 16),
            _buildPayoutSummaryCard(context, d),
            const SizedBox(height: 16),
            _buildTransactionSummaryCard(context, d),
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutSummaryCard(BuildContext context, Map<String, dynamic> d) {
    final pendingCount = d['payout_pending_count'] ?? 0;
    final pendingCents = d['payout_pending_total_cents'] ?? 0;
    return Card(
      color: AppTheme.cardOf(context),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/admin/payouts'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet, color: AppTheme.accentColor, size: 22),
                  const SizedBox(width: 8),
                  Text('Payout Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondaryOf(context)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pending Payouts', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
                      Text('$pendingCount organizers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryOf(context))),
                    ],
                  )),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Pending', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
                      Text(centsToStr(pendingCents), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryOf(context))),
                    ],
                  )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionSummaryCard(BuildContext context, Map<String, dynamic> d) {
    final total = d['transaction_total_count'] ?? 0;
    final settled = d['transaction_settled_count'] ?? 0;
    final pending = d['transaction_pending_count'] ?? 0;
    final failed = d['transaction_failed_count'] ?? 0;
    return Card(
      color: AppTheme.cardOf(context),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/admin/transactions'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt_long, color: AppTheme.accentColor, size: 22),
                  const SizedBox(width: 8),
                  Text('Transaction Ledger', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondaryOf(context)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _txnStatCell(context, 'Total', '$total', AppTheme.textPrimaryOf(context))),
                  Expanded(child: _txnStatCell(context, 'Settled', '$settled', AppTheme.successColor)),
                  Expanded(child: _txnStatCell(context, 'Pending', '$pending', AppTheme.warningColor)),
                  Expanded(child: _txnStatCell(context, 'Failed', '$failed', AppTheme.errorColor)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _txnStatCell(BuildContext context, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _buildMockBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.warningSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('Mock Mode Active — No real money is moving', style: TextStyle(color: AppTheme.textPrimaryOf(context), fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildStripeBanner(BuildContext context, bool connectEnabled) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.payment, color: Colors.indigo, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Stripe is the active payment gateway${connectEnabled ? ' • Connect enabled for organizer payouts' : ''}',
              style: TextStyle(color: AppTheme.textPrimaryOf(context), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEscrowSummary(BuildContext context, Map<String, dynamic> d) {
    return Card(
      color: AppTheme.cardOf(context),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/admin/escrow-pipeline'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lock_clock, color: AppTheme.accentColor, size: 22),
                  const SizedBox(width: 8),
                  Text('Escrow Pipeline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondaryOf(context)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _escrowSummaryCol('Fund', d['fund_escrow_total_held_cents'] ?? 0, d['fund_escrow_active_count'] ?? 0, context.fundingAccent)),
                  Expanded(child: _escrowSummaryCol('Ticket', d['ticket_escrow_total_held_cents'] ?? 0, d['ticket_escrow_active_count'] ?? 0, context.ticketAccent)),
                  Expanded(child: _escrowSummaryCol('Sponsor', d['sponsor_escrow_total_held_cents'] ?? 0, d['sponsor_escrow_active_count'] ?? 0, context.sponsorAccent)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _escrowSummaryCol(String label, int heldCents, int activeCount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
        const SizedBox(height: 4),
        Text('Held: ${centsToStr(heldCents)}', style: TextStyle(fontSize: 12, color: AppTheme.textPrimaryOf(context))),
        Text('Active: $activeCount', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
      ],
    );
  }

  Widget _buildCommissionTax(BuildContext context, Map<String, dynamic> d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Commission & Tax', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: infoCard(context, 'Commission Total', centsToStr(d['commission_total_cents'] ?? 0), Icons.attach_money, AppTheme.accentColor)),
            const SizedBox(width: 8),
            Expanded(child: infoCard(context, 'Tax Collected', centsToStr(d['tax_collected_total_cents'] ?? 0), Icons.receipt_long, AppTheme.warningColor)),
          ],
        ),
        if (d['commission_by_source'] is Map) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              for (final entry in (d['commission_by_source'] as Map).entries) ...[
                if (entry != (d['commission_by_source'] as Map).entries.first) const SizedBox(width: 6),
                Expanded(
                  child: Card(
                    color: AppTheme.cardOf(context),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: [
                          Text(entry.key.toString().toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppTheme.textSecondaryOf(context))),
                          const SizedBox(height: 4),
                          Text(centsToStr(entry.value ?? 0), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryOf(context))),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
