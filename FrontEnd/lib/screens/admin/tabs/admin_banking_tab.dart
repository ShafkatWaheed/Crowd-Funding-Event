import 'package:flutter/material.dart';

import '../admin_shared.dart';
import '../../../config/theme.dart';
import '../../../services/api_service.dart';
import 'banking/banking_escrow_config.dart';
import 'banking/banking_escrow_pipeline.dart';
import 'banking/banking_disputes_payout.dart';
import 'banking/banking_transaction_ledger.dart';
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

  List<dynamic> _fundEscrows = [];
  List<dynamic> _ticketEscrows = [];
  List<dynamic> _sponsorEscrows = [];
  bool _pipelineLoading = false;
  String _pipelineTypeFilter = 'all';
  Map<String, dynamic>? _selectedEventEscrows;
  int? _selectedPipelineEventId;

  List<dynamic> _reconHistory = [];
  bool _reconHistoryLoading = false;

  Map<String, dynamic>? _ledgerHealth;
  bool _ledgerHealthLoading = false;

  List<dynamic> _disputes = [];
  bool _disputesLoading = false;

  List<dynamic> _payoutItems = [];
  bool _payoutLoading = false;

  List<dynamic> _transactions = [];
  int _txnTotal = 0;
  int _txnPage = 0;
  bool _txnLoading = false;
  String _txnSearch = '';
  String _txnStatusFilter = 'all';

  String _settingVal(String key) {
    final s = widget.settings.cast<Map<String, dynamic>?>().firstWhere(
          (e) => e != null && e['key'] == key,
          orElse: () => null,
        );
    return s?['value']?.toString() ?? '';
  }

  List<Map<String, dynamic>> get _escrowRows {
    final rows = <Map<String, dynamic>>[];
    for (final e in _fundEscrows) rows.add({...Map<String, dynamic>.from(e as Map), '_type': 'fund'});
    for (final e in _ticketEscrows) rows.add({...Map<String, dynamic>.from(e as Map), '_type': 'ticket'});
    for (final e in _sponsorEscrows) rows.add({...Map<String, dynamic>.from(e as Map), '_type': 'sponsor'});
    return rows;
  }

  Future<void> _loadBankingData() async {
    setState(() => _bankingLoading = true);
    try {
      final data = await ApiService.instance.adminGetBankingOverview();
      if (mounted) setState(() { _bankingData = data; _bankingLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _bankingLoading = false);
    }
  }

  Future<void> _loadEscrowPipeline() async {
    setState(() => _pipelineLoading = true);
    try {
      final fundResp = await ApiService.instance.adminGetEscrows(type: 'fund');
      final ticketResp = await ApiService.instance.adminGetEscrows(type: 'ticket');
      final sponsorResp = await ApiService.instance.adminGetEscrows(type: 'sponsor');
      if (mounted) setState(() {
        _fundEscrows = (fundResp['items'] as List?) ?? [];
        _ticketEscrows = (ticketResp['items'] as List?) ?? [];
        _sponsorEscrows = (sponsorResp['items'] as List?) ?? [];
        _pipelineLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _pipelineLoading = false);
    }
  }

  Future<void> _loadEventEscrowDetail(int eventId) async {
    try {
      final data = await ApiService.instance.adminGetEventEscrows(eventId);
      if (mounted) setState(() { _selectedEventEscrows = data; _selectedPipelineEventId = eventId; });
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _loadReconHistory() async {
    setState(() => _reconHistoryLoading = true);
    try {
      final resp = await ApiService.instance.adminGetReconciliationHistory();
      setState(() => _reconHistory = resp);
    } catch (e) { debugPrint(e.toString()); }
    setState(() => _reconHistoryLoading = false);
  }

  Future<void> _loadLedgerHealth() async {
    setState(() => _ledgerHealthLoading = true);
    try {
      final resp = await ApiService.instance.adminGetLedgerHealth();
      setState(() => _ledgerHealth = resp);
    } catch (e) { debugPrint(e.toString()); }
    setState(() => _ledgerHealthLoading = false);
  }

  Future<void> _loadDisputes() async {
    setState(() => _disputesLoading = true);
    try {
      final resp = await ApiService.instance.adminGetDisputes();
      setState(() => _disputes = (resp['items'] as List?) ?? []);
    } catch (e) { debugPrint(e.toString()); }
    setState(() => _disputesLoading = false);
  }

  Future<void> _loadPayoutStatus() async {
    setState(() => _payoutLoading = true);
    try {
      final resp = await ApiService.instance.adminGetPayoutStatus();
      setState(() => _payoutItems = (resp is List) ? resp : (resp['items'] ?? []));
    } catch (e) { debugPrint(e.toString()); }
    setState(() => _payoutLoading = false);
  }

  Future<void> _loadTransactions({int page = 0}) async {
    setState(() => _txnLoading = true);
    try {
      final resp = await ApiService.instance.adminGetTransactions(
        offset: page * 20,
        search: _txnSearch.isNotEmpty ? _txnSearch : null,
        status: _txnStatusFilter != 'all' ? _txnStatusFilter : null,
      );
      setState(() {
        _transactions = resp['items'] ?? [];
        _txnTotal = resp['total'] ?? 0;
        _txnPage = page;
      });
    } catch (e) { debugPrint(e.toString()); }
    setState(() => _txnLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_bankingData == null && !_bankingLoading) _loadBankingData();
    if (_bankingLoading || _bankingData == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_disputes.isEmpty && !_disputesLoading) _loadDisputes();
    if (_payoutItems.isEmpty && !_payoutLoading) _loadPayoutStatus();
    if (_reconHistory.isEmpty && !_reconHistoryLoading) _loadReconHistory();
    if (_ledgerHealth == null && !_ledgerHealthLoading) _loadLedgerHealth();
    if (_transactions.isEmpty && !_txnLoading && _txnTotal == 0) _loadTransactions();
    if (_fundEscrows.isEmpty && _ticketEscrows.isEmpty && _sponsorEscrows.isEmpty && !_pipelineLoading) _loadEscrowPipeline();

    final d = _bankingData!;
    final mockActive = d['mock_mode_active'] == true || widget.mockModeActive;
    return RefreshIndicator(
      onRefresh: _loadBankingData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mockActive) _buildMockBanner(context),
            Text('Platform Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: 8),
            PlatformAccountCard(
              configured: d['platform_account_configured'] == true,
              bankName: d['platform_account_bank_name'] as String?,
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
            BankingReconciliationStatus(bankingData: d, onReloadBanking: _loadBankingData),
            const SizedBox(height: 8),
            BankingReconciliationChart(reconHistory: _reconHistory, reconHistoryLoading: _reconHistoryLoading),
            const SizedBox(height: 16),
            BankingTaxConfigSection(settingVal: _settingVal, onUpdateSetting: widget.onUpdateSetting),
            const SizedBox(height: 16),
            BankingLedgerHealthCard(ledgerHealth: _ledgerHealth, ledgerHealthLoading: _ledgerHealthLoading),
            const SizedBox(height: 16),
            BankingPayoutSection(payoutItems: _payoutItems, payoutLoading: _payoutLoading, onReloadPayout: _loadPayoutStatus),
            const SizedBox(height: 16),
            BankingTransactionLedger(
              transactions: _transactions,
              txnTotal: _txnTotal,
              txnPage: _txnPage,
              txnLoading: _txnLoading,
              txnSearch: _txnSearch,
              txnStatusFilter: _txnStatusFilter,
              mockModeActive: widget.mockModeActive,
              onSearchChanged: (v) { setState(() => _txnSearch = v); _loadTransactions(); },
              onStatusFilterChanged: (v) { setState(() => _txnStatusFilter = v); _loadTransactions(); },
              onPageChanged: (p) => _loadTransactions(page: p),
              onReloadBanking: _loadBankingData,
              onReloadDisputes: _loadDisputes,
            ),
            const SizedBox(height: 16),
            BankingEscrowConfigSection(settingVal: _settingVal, onUpdateSetting: widget.onUpdateSetting),
            const SizedBox(height: 16),
            BankingEscrowPipelineSection(
              escrowRows: _escrowRows,
              pipelineLoading: _pipelineLoading,
              pipelineTypeFilter: _pipelineTypeFilter,
              onTypeFilterChanged: (v) => setState(() => _pipelineTypeFilter = v),
              onRefresh: _loadEscrowPipeline,
              selectedPipelineEventId: _selectedPipelineEventId,
              selectedEventEscrows: _selectedEventEscrows,
              onLoadEventDetail: _loadEventEscrowDetail,
              onClearSelection: () => setState(() { _selectedEventEscrows = null; _selectedPipelineEventId = null; }),
              onSnack: widget.onSnack,
              onReloadEventDetail: _loadEventEscrowDetail,
              onReloadPipeline: _loadEscrowPipeline,
            ),
          ],
        ),
      ),
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

  Widget _buildEscrowSummary(BuildContext context, Map<String, dynamic> d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Escrow Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _escrowSummaryCard('Fund', d['fund_escrow_total_held_cents'] ?? 0, d['fund_escrow_total_released_cents'] ?? 0, d['fund_escrow_active_count'] ?? 0, context.fundingAccent)),
            const SizedBox(width: 8),
            Expanded(child: _escrowSummaryCard('Ticket', d['ticket_escrow_total_held_cents'] ?? 0, d['ticket_escrow_total_released_cents'] ?? 0, d['ticket_escrow_active_count'] ?? 0, context.ticketAccent)),
            const SizedBox(width: 8),
            Expanded(child: _escrowSummaryCard('Sponsor', d['sponsor_escrow_total_held_cents'] ?? 0, d['sponsor_escrow_total_released_cents'] ?? 0, d['sponsor_escrow_active_count'] ?? 0, context.sponsorAccent)),
          ],
        ),
      ],
    );
  }

  Widget _escrowSummaryCard(String label, int heldCents, int releasedCents, int activeCount, Color color) {
    return Card(
      color: AppTheme.cardOf(context),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
            const SizedBox(height: 8),
            Text('Held: ${centsToStr(heldCents)}', style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(context))),
            Text('Released: ${centsToStr(releasedCents)}', style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context))),
            Text('Active: $activeCount', style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context))),
          ],
        ),
      ),
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
