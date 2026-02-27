import 'package:flutter/material.dart';

import '../admin_shared.dart';
import '../../../config/theme.dart';
import '../../../services/api_service.dart';
import '../../../widgets/app_toast.dart';

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
  String _pipelineSearch = '';
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

  Map<String, String> _sliderOverrides = {};

  String _settingVal(String key) {
    if (_sliderOverrides.containsKey(key)) return _sliderOverrides[key]!;
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
    } catch (_) {}
  }

  Future<void> _loadReconHistory() async {
    setState(() => _reconHistoryLoading = true);
    try {
      final resp = await ApiService.instance.adminGetReconciliationHistory();
      setState(() => _reconHistory = resp);
    } catch (_) {}
    setState(() => _reconHistoryLoading = false);
  }

  Future<void> _loadLedgerHealth() async {
    setState(() => _ledgerHealthLoading = true);
    try {
      final resp = await ApiService.instance.adminGetLedgerHealth();
      setState(() => _ledgerHealth = resp);
    } catch (_) {}
    setState(() => _ledgerHealthLoading = false);
  }

  Future<void> _loadDisputes() async {
    setState(() => _disputesLoading = true);
    try {
      final resp = await ApiService.instance.adminGetDisputes();
      setState(() => _disputes = (resp['items'] as List?) ?? []);
    } catch (_) {}
    setState(() => _disputesLoading = false);
  }

  Future<void> _loadPayoutStatus() async {
    setState(() => _payoutLoading = true);
    try {
      final resp = await ApiService.instance.adminGetPayoutStatus();
      setState(() => _payoutItems = (resp is List) ? resp : (resp['items'] ?? []));
    } catch (_) {}
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
    } catch (_) {}
    setState(() => _txnLoading = false);
  }

  void _snack(String msg) => widget.onSnack(msg);

  @override
  Widget build(BuildContext context) {
    if (_bankingData == null && !_bankingLoading) _loadBankingData();
    if (_bankingLoading || _bankingData == null) {
      return const Center(child: CircularProgressIndicator());
    }
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
            if (mockActive)
              Container(
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
              ),
            Text('Platform Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: 8),
            PlatformAccountCard(
              configured: d['platform_account_configured'] == true,
              bankName: d['platform_account_bank_name'] as String?,
              lastFour: d['platform_account_last_four'] as String?,
              onSaved: () => _loadBankingData(),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
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
            _buildDisputesDetail(),
            const SizedBox(height: 16),
            Text('Reconciliation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: 8),
            Card(
              color: AppTheme.cardOf(context),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      d['last_reconciliation_status'] == 'balanced' ? Icons.check_circle : Icons.error,
                      color: d['last_reconciliation_status'] == 'balanced' ? AppTheme.successColor : AppTheme.errorColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        d['last_reconciliation_status'] != null
                          ? 'Last: ${d['last_reconciliation_status']} (delta: ${centsToStr((d['last_reconciliation_delta_cents'] ?? 0).abs())})'
                          : 'No reconciliation run yet',
                        style: TextStyle(color: AppTheme.textPrimaryOf(context)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Run Now'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                      onPressed: () async {
                        try {
                          await ApiService.instance.adminRunReconciliation();
                          _loadBankingData();
                          if (mounted) AppToast.success(context, 'Reconciliation completed');
                        } catch (e) {
                          if (mounted) AppToast.fromError(context, e, fallback: 'Reconciliation failed');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildReconciliationChart(),
            const SizedBox(height: 16),
            _buildTaxConfigUI(),
            const SizedBox(height: 16),
            _buildLedgerHealthCard(),
            const SizedBox(height: 16),
            _buildPayoutStatusSection(),
            const SizedBox(height: 16),
            _buildTransactionLedger(),
            const SizedBox(height: 16),
            _buildEscrowConfigUI(),
            const SizedBox(height: 16),
            _buildEscrowPipelineUI(),
          ],
        ),
      ),
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

  Widget _buildEscrowConfigUI() {
    final fundStages = [
      {'label': 'Stage 1', 'pct': 'escrow_stage1_percent'},
      {'label': 'Stage 2', 'pct': 'escrow_stage2_percent'},
      {'label': 'Stage 3', 'pct': 'escrow_stage3_percent'},
    ];
    final ticketStages = [
      {'label': 'Stage 1', 'pct': 'ticket_escrow_stage1_percent', 'days': 'ticket_escrow_stage1_days_after_event'},
      {'label': 'Stage 2', 'pct': 'ticket_escrow_stage2_percent', 'days': 'ticket_escrow_stage2_days_after_event', 'extra': 'ticket_escrow_stage2_max_refund_rate'},
      {'label': 'Stage 3', 'pct': 'ticket_escrow_stage3_percent', 'days': 'ticket_escrow_stage3_days_after_event', 'extra': 'ticket_escrow_stage3_require_no_disputes'},
    ];
    final sponsorStages = [
      {'label': 'Stage 1', 'pct': 'sponsor_escrow_stage1_percent', 'mode': 'sponsor_escrow_stage1_trigger_mode', 'days': 'sponsor_escrow_stage1_days_before_event'},
      {'label': 'Stage 2', 'pct': 'sponsor_escrow_stage2_percent', 'mode': 'sponsor_escrow_stage2_trigger_mode', 'days': 'sponsor_escrow_stage2_ticket_percent'},
      {'label': 'Stage 3', 'pct': 'sponsor_escrow_stage3_percent', 'mode': 'sponsor_escrow_stage3_trigger_mode', 'days': 'sponsor_escrow_stage3_days_after_event'},
    ];

    int fundSum = fundStages.fold(0, (s, st) => s + (int.tryParse(_settingVal(st['pct']!)) ?? 0));
    int ticketSum = ticketStages.fold(0, (s, st) => s + (int.tryParse(_settingVal(st['pct']!)) ?? 0));
    int sponsorSum = sponsorStages.fold(0, (s, st) => s + (int.tryParse(_settingVal(st['pct']!)) ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Escrow Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
        const SizedBox(height: 8),
        _escrowConfigTile('Fund Escrow', '${_settingVal('escrow_stage1_percent')}% / ${_settingVal('escrow_stage2_percent')}% / ${_settingVal('escrow_stage3_percent')}%',
          fundSum, context.fundingAccent, fundStages.map((st) => _escrowStageRow(st['label']!, st['pct']!)).toList()),
        const SizedBox(height: 8),
        _escrowConfigTile(
          'Ticket Escrow',
          '${_settingVal('ticket_escrow_stage1_percent')}% / ${_settingVal('ticket_escrow_stage2_percent')}% / ${_settingVal('ticket_escrow_stage3_percent')}%',
          ticketSum, context.ticketAccent,
          ticketStages.map((st) {
            return Column(children: [
              _escrowStageRow(st['label']!, st['pct']!),
              if (st['days'] != null) _mockInputRow('Days after event', st['days']!),
              if (st['extra'] != null && (st['extra'] as String).contains('refund'))
                _mockInputRow('Max refund rate (%)', st['extra']!),
              if (st['extra'] != null && (st['extra'] as String).contains('disputes'))
                _escrowBoolRow('Require no disputes', st['extra']!),
            ]);
          }).toList(),
        ),
        const SizedBox(height: 8),
        _escrowConfigTile(
          'Sponsor Escrow',
          '${_settingVal('sponsor_escrow_stage1_percent')}% / ${_settingVal('sponsor_escrow_stage2_percent')}% / ${_settingVal('sponsor_escrow_stage3_percent')}%',
          sponsorSum, context.sponsorAccent,
          sponsorStages.map((st) {
            return Column(children: [
              _escrowStageRow(st['label']!, st['pct']!),
              if (st['mode'] != null) _escrowModeRow('Trigger', st['mode']!),
              if (st['days'] != null) _mockInputRow('Param', st['days']!),
            ]);
          }).toList(),
        ),
      ],
    );
  }

  Widget _escrowConfigTile(String title, String subtitle, int sum, Color color, List<Widget> children) {
    final valid = sum == 100;
    return Card(
      color: AppTheme.cardOf(context),
      child: ExpansionTile(
        leading: Icon(Icons.lock_clock, color: color),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
        subtitle: Text(subtitle, style: TextStyle(color: valid ? AppTheme.textSecondaryOf(context) : AppTheme.errorColor)),
        trailing: valid
            ? Icon(Icons.check_circle, color: AppTheme.successColor, size: 20)
            : Text('$sum% (must = 100)', style: const TextStyle(color: AppTheme.errorColor, fontSize: 12)),
        children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Column(children: children)),
        ],
      ),
    );
  }

  Widget _escrowStageRow(String label, String key) {
    final val = double.tryParse(_settingVal(key)) ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(context)))),
          Expanded(
            child: Slider(
              value: val.clamp(0, 100),
              min: 0, max: 100, divisions: 100,
              label: '${val.round()}%',
              activeColor: AppTheme.accentOf(context),
              onChangeEnd: (v) {
                setState(() => _sliderOverrides.remove(key));
                widget.onUpdateSetting(key, v.round().toString());
              },
              onChanged: (v) => setState(() => _sliderOverrides[key] = v.round().toString()),
            ),
          ),
          SizedBox(width: 40, child: Text('${val.round()}%', textAlign: TextAlign.end,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.accentOf(context)))),
        ],
      ),
    );
  }

  Widget _escrowBoolRow(String label, String key) {
    final val = _settingVal(key) == 'true';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 180, child: Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(context)))),
          Switch(value: val, activeColor: AppTheme.successOf(context),
            onChanged: (on) => widget.onUpdateSetting(key, on ? 'true' : 'false')),
        ],
      ),
    );
  }

  Widget _escrowModeRow(String label, String key) {
    final val = _settingVal(key);
    const options = {
      'sponsor_escrow_stage1_trigger_mode': ['event_live', 'days_before_event'],
      'sponsor_escrow_stage2_trigger_mode': ['event_started', 'ticket_percent'],
      'sponsor_escrow_stage3_trigger_mode': ['days_after_event', 'sponsor_confirmed'],
    };
    final opts = options[key] ?? [val];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(context)))),
          DropdownButton<String>(
            value: opts.contains(val) ? val : opts.first,
            underline: const SizedBox.shrink(),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.accentOf(context)),
            items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o.replaceAll('_', ' ')))).toList(),
            onChanged: (v) { if (v != null) widget.onUpdateSetting(key, v); },
          ),
        ],
      ),
    );
  }

  Widget _mockInputRow(String label, String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 180, child: Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(context)))),
          SizedBox(
            width: 120,
            child: TextField(
              controller: TextEditingController(text: _settingVal(key)),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 14, color: AppTheme.textPrimaryOf(context)),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.accentOf(context))),
              ),
              onSubmitted: (v) => widget.onUpdateSetting(key, v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEscrowPipelineUI() {
    if (_fundEscrows.isEmpty && _ticketEscrows.isEmpty && _sponsorEscrows.isEmpty && !_pipelineLoading) _loadEscrowPipeline();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Escrow Pipeline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)))),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadEscrowPipeline, iconSize: 20),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          ChoiceChip(label: const Text('All'), selected: _pipelineTypeFilter == 'all',
            selectedColor: AppTheme.accentOf(context).withOpacity(0.2),
            onSelected: (_) => setState(() => _pipelineTypeFilter = 'all')),
          ChoiceChip(label: const Text('Fund'), selected: _pipelineTypeFilter == 'fund',
            selectedColor: context.fundingAccent.withOpacity(0.2),
            onSelected: (_) => setState(() => _pipelineTypeFilter = 'fund')),
          ChoiceChip(label: const Text('Ticket'), selected: _pipelineTypeFilter == 'ticket',
            selectedColor: context.ticketAccent.withOpacity(0.2),
            onSelected: (_) => setState(() => _pipelineTypeFilter = 'ticket')),
          ChoiceChip(label: const Text('Sponsor'), selected: _pipelineTypeFilter == 'sponsor',
            selectedColor: context.sponsorAccent.withOpacity(0.2),
            onSelected: (_) => setState(() => _pipelineTypeFilter = 'sponsor')),
        ]),
        const SizedBox(height: 8),
        if (_pipelineLoading)
          const Center(child: CircularProgressIndicator())
        else ...[
          if (_pipelineTypeFilter == 'all' || _pipelineTypeFilter == 'fund')
            ..._escrowRows.where((e) => e['_type'] == 'fund').map(_pipelineRow),
          if (_pipelineTypeFilter == 'all' || _pipelineTypeFilter == 'ticket')
            ..._escrowRows.where((e) => e['_type'] == 'ticket').map(_pipelineRow),
          if (_pipelineTypeFilter == 'all' || _pipelineTypeFilter == 'sponsor')
            ..._escrowRows.where((e) => e['_type'] == 'sponsor').map(_pipelineRow),
        ],
        if (_selectedEventEscrows != null && _selectedPipelineEventId != null) ...[
          const SizedBox(height: 12),
          _buildEventEscrowDetail(_selectedPipelineEventId!, _selectedEventEscrows!),
        ],
      ],
    );
  }

  Widget _pipelineRow(Map<String, dynamic> e) {
    final type = e['_type'] as String;
    final color = type == 'fund' ? context.fundingAccent : type == 'ticket' ? context.ticketAccent : context.sponsorAccent;
    final statusStr = e['status'] ?? 'holding';
    return Card(
      color: AppTheme.cardOf(context),
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Text(type[0].toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold))),
        title: Text(e['event_title'] ?? 'Event #${e['event_id']}', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(context), fontSize: 14)),
        subtitle: Row(children: [
          _stageDot(e['stage1_released_at']),
          _stageDot(e['stage2_released_at']),
          _stageDot(e['stage3_released_at']),
          const SizedBox(width: 8),
          Text('${centsToStr(e['total_held_cents'] ?? 0)} held', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
        ]),
        trailing: Chip(
          label: Text(statusStr, style: const TextStyle(fontSize: 11)),
          backgroundColor: _escrowStatusChipColor(statusStr),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onTap: () => _loadEventEscrowDetail(e['event_id']),
      ),
    );
  }

  Widget _stageDot(dynamic releasedAt) {
    final released = releasedAt != null;
    return Container(
      width: 12, height: 12,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: released ? AppTheme.successColor : AppTheme.textSecondaryOf(context),
      ),
    );
  }

  Color _escrowStatusChipColor(String status) {
    switch (status) {
      case 'fully_released': return AppTheme.successColor.withOpacity(0.2);
      case 'partially_released': return AppTheme.warningColor.withOpacity(0.2);
      case 'frozen': return AppTheme.errorColor.withOpacity(0.2);
      case 'refunded': return Colors.purple.withOpacity(0.2);
      default: return AppTheme.accentColor.withOpacity(0.15);
    }
  }

  Widget _buildEventEscrowDetail(int eventId, Map<String, dynamic> data) {
    return Card(
      color: AppTheme.cardOf(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text('Event #$eventId — All Escrows', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)))),
              IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() { _selectedEventEscrows = null; _selectedPipelineEventId = null; })),
            ]),
            const SizedBox(height: 8),
            if (data['fund'] != null) _escrowDetailColumn('Fund', data['fund'] as Map<String, dynamic>, 'fund', eventId),
            if (data['ticket'] != null) _escrowDetailColumn('Ticket', data['ticket'] as Map<String, dynamic>, 'ticket', eventId),
            if (data['sponsor'] != null) _escrowDetailColumn('Sponsor', data['sponsor'] as Map<String, dynamic>, 'sponsor', eventId),
            if (data['fund'] == null && data['ticket'] == null && data['sponsor'] == null)
              Text('No escrow records for this event.', style: TextStyle(color: AppTheme.textSecondaryOf(context))),
          ],
        ),
      ),
    );
  }

  Widget _escrowDetailColumn(String label, Map<String, dynamic> esc, String type, int eventId) {
    final color = type == 'fund' ? context.fundingAccent : type == 'ticket' ? context.ticketAccent : context.sponsorAccent;
    final stages = [
      {'n': 1, 'cents': esc['stage1_released_cents'] ?? 0, 'at': esc['stage1_released_at'], 'auto': esc['stage1_auto_release'] ?? true},
      {'n': 2, 'cents': esc['stage2_released_cents'] ?? 0, 'at': esc['stage2_released_at'], 'auto': esc['stage2_auto_release'] ?? true},
      {'n': 3, 'cents': esc['stage3_released_cents'] ?? 0, 'at': esc['stage3_released_at'], 'auto': esc['stage3_auto_release'] ?? true},
    ];
    final frozen = esc['status'] == 'frozen';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label — ${esc['status']}', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
          Text('Held: ${centsToStr(esc['total_held_cents'] ?? 0)} | Released: ${centsToStr(esc['total_released_cents'] ?? 0)} | Remaining: ${centsToStr(esc['remaining_cents'] ?? 0)}',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
          const SizedBox(height: 4),
          ...stages.map((st) {
            final released = st['at'] != null;
            final autoRelease = st['auto'] as bool;
            final stageNum = st['n'] as int;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Icon(released ? Icons.check_circle : Icons.radio_button_unchecked, color: released ? AppTheme.successColor : AppTheme.textSecondaryOf(context), size: 16),
                const SizedBox(width: 6),
                Text('Stage $stageNum: ${centsToStr(st['cents'] as int)}', style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(context))),
                if (!released) ...[
                  const Spacer(),
                  Tooltip(
                    message: autoRelease ? 'Auto-release ON' : 'Auto-release OFF (manual only)',
                    child: SizedBox(
                      height: 28,
                      child: Switch(
                        value: autoRelease,
                        activeColor: color,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (val) async {
                          try {
                            await ApiService.instance.adminToggleAutoRelease(
                              eventId, type,
                              stage1: stageNum == 1 ? val : null,
                              stage2: stageNum == 2 ? val : null,
                              stage3: stageNum == 3 ? val : null,
                            );
                            _loadEventEscrowDetail(eventId);
                            _snack('Stage $stageNum auto-release ${val ? 'enabled' : 'disabled'}');
                          } catch (e) {
                            _snack('Toggle failed: ${ApiService.extractError(e)}');
                          }
                        },
                      ),
                    ),
                  ),
                  if (!frozen)
                    TextButton(
                      onPressed: () async {
                        try {
                          await ApiService.instance.adminReleaseEscrowStage(eventId, type, stageNum);
                          _loadEventEscrowDetail(eventId);
                          _loadEscrowPipeline();
                          _snack('$label Stage $stageNum released');
                        } catch (e) {
                          _snack('Release failed: ${ApiService.extractError(e)}');
                        }
                      },
                      child: const Text('Release', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ]),
            );
          }),
          const SizedBox(height: 4),
          Row(children: [
            if (!frozen)
              TextButton.icon(
                icon: const Icon(Icons.ac_unit, size: 14),
                label: const Text('Freeze', style: TextStyle(fontSize: 12)),
                onPressed: () async {
                  await ApiService.instance.adminFreezeEscrow(eventId, type);
                  _loadEventEscrowDetail(eventId);
                  _loadEscrowPipeline();
                },
              )
            else
              TextButton.icon(
                icon: const Icon(Icons.play_arrow, size: 14),
                label: const Text('Unfreeze', style: TextStyle(fontSize: 12)),
                onPressed: () async {
                  await ApiService.instance.adminUnfreezeEscrow(eventId, type);
                  _loadEventEscrowDetail(eventId);
                  _loadEscrowPipeline();
                },
              ),
          ]),
        ],
      ),
    );
  }

  Widget _buildReconciliationChart() {
    if (_reconHistory.isEmpty && !_reconHistoryLoading) _loadReconHistory();
    if (_reconHistoryLoading) return const SizedBox.shrink();
    if (_reconHistory.isEmpty) return const SizedBox.shrink();
    final items = _reconHistory.take(30).toList().reversed.toList();
    final maxDelta = items.fold<int>(1, (m, r) => ((r['delta_cents'] as int?)?.abs() ?? 0) > m ? ((r['delta_cents'] as int?)?.abs() ?? 0) : m);
    return Card(
      color: AppTheme.cardOf(context),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reconciliation History (last ${items.length} runs)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: items.map<Widget>((r) {
                  final delta = ((r['delta_cents'] as int?) ?? 0).abs();
                  final balanced = r['status'] == 'balanced';
                  final barHeight = maxDelta > 0 ? (delta / maxDelta * 60).clamp(2.0, 60.0) : 2.0;
                  return Expanded(
                    child: Tooltip(
                      message: '${r['run_date'] ?? ''}: delta ${centsToStr(delta)}',
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        height: balanced ? 2 : barHeight,
                        decoration: BoxDecoration(
                          color: balanced ? AppTheme.successColor : AppTheme.errorColor,
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
                Text(items.isNotEmpty ? '${items.first['run_date'] ?? ''}' : '', style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryOf(context))),
                Text(items.length > 1 ? '${items.last['run_date'] ?? ''}' : '', style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryOf(context))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxConfigUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tax Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
        const SizedBox(height: 8),
        Card(
          color: AppTheme.cardOf(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _taxToggleRow('Tax Enabled', 'tax_enabled'),
                const Divider(),
                _taxInputRow('Default Tax Rate (%)', 'default_tax_rate'),
                _taxInputRow('Tax Jurisdiction', 'default_tax_jurisdiction'),
                const Divider(),
                _taxToggleRow('Applies to Tickets', 'tax_applies_to_tickets'),
                _taxToggleRow('Applies to Sponsors', 'tax_applies_to_sponsors'),
                _taxToggleRow('Applies to Pledges', 'tax_applies_to_pledges'),
                const Divider(),
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: AppTheme.warningColor),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Tax collected is a liability — remit to tax authority quarterly.', style: TextStyle(fontSize: 11, color: AppTheme.warningColor, fontStyle: FontStyle.italic))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _taxToggleRow(String label, String key) {
    final val = _settingVal(key);
    final enabled = val == 'true' || val == '1';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(context))),
          Switch(
            value: enabled,
            activeColor: AppTheme.accentOf(context),
            onChanged: (v) => widget.onUpdateSetting(key, v ? 'true' : 'false'),
          ),
        ],
      ),
    );
  }

  Widget _taxInputRow(String label, String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(context)))),
          Expanded(
            flex: 3,
            child: TextField(
              controller: TextEditingController(text: _settingVal(key)),
              decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(6))),
              style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(context)),
              onSubmitted: (v) => widget.onUpdateSetting(key, v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerHealthCard() {
    if (_ledgerHealth == null && !_ledgerHealthLoading) _loadLedgerHealth();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ledger Health', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
        const SizedBox(height: 8),
        if (_ledgerHealthLoading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
        if (!_ledgerHealthLoading && _ledgerHealth != null) Card(
          color: AppTheme.cardOf(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _ledgerHealth!['balanced'] == true ? Icons.check_circle : Icons.error,
                      color: _ledgerHealth!['balanced'] == true ? AppTheme.successColor : AppTheme.errorColor,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      _ledgerHealth!['balanced'] == true ? 'Ledger is balanced' : 'Ledger imbalance detected',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ledgerHealth!['balanced'] == true ? AppTheme.successColor : AppTheme.errorColor),
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                _ledgerRow('Total Debits', centsToStr(_ledgerHealth!['total_debits_cents'] ?? 0)),
                _ledgerRow('Total Credits', centsToStr(_ledgerHealth!['total_credits_cents'] ?? 0)),
                if (_ledgerHealth!['accounts'] is Map) ...[
                  const Divider(),
                  Text('Per-Account Balances', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryOf(context))),
                  const SizedBox(height: 4),
                  ...(_ledgerHealth!['accounts'] as Map).entries.map<Widget>((e) =>
                    _ledgerRow(e.key.toString(), centsToStr(e.value ?? 0)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _ledgerRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context))),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(context))),
        ],
      ),
    );
  }

  Widget _buildDisputesDetail() {
    if (_disputes.isEmpty && !_disputesLoading) _loadDisputes();
    if (_disputesLoading) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
    if (_disputes.isEmpty) return Card(color: AppTheme.cardOf(context), child: Padding(padding: const EdgeInsets.all(16), child: Text('No disputes found.', style: TextStyle(color: AppTheme.textSecondaryOf(context)))));
    return Column(
      children: _disputes.map<Widget>((d) {
        final status = d['status'] ?? 'open';
        final isOpen = status == 'open' || status == 'evidence_submitted';
        final statusColor = switch (status) {
          'open' => AppTheme.errorColor,
          'evidence_submitted' => AppTheme.warningColor,
          'won' => AppTheme.successColor,
          'lost' => AppTheme.textSecondaryOf(context),
          _ => AppTheme.textSecondaryOf(context),
        };
        return Card(
          color: AppTheme.cardOf(context),
          child: ExpansionTile(
            leading: Icon(Icons.gavel, color: statusColor, size: 20),
            title: Text('Dispute ${d['stripe_dispute_id'] ?? '#${d['id']}'}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(context))),
            subtitle: Text('${centsToStr(d['amount_cents'] ?? 0)} · $status', style: TextStyle(fontSize: 12, color: statusColor)),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (d['reason'] != null) Text('Reason: ${d['reason']}', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
                    if (d['created_at'] != null) Text('Opened: ${d['created_at']}', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
                    const SizedBox(height: 8),
                    if (isOpen) Row(
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.upload_file, size: 16),
                          label: const Text('Submit Evidence'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), textStyle: const TextStyle(fontSize: 12)),
                          onPressed: () async {
                            try {
                              await ApiService.instance.adminSubmitDisputeEvidence(d['id'] as int);
                              _loadDisputes();
                              if (mounted) AppToast.success(context, 'Evidence submitted');
                            } catch (e) {
                              if (mounted) AppToast.fromError(context, e, fallback: 'Failed to submit evidence');
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.cancel, size: 16),
                          label: const Text('Accept Loss'),
                          style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), textStyle: const TextStyle(fontSize: 12)),
                          onPressed: () async {
                            try {
                              await ApiService.instance.adminAcceptDisputeLoss(d['id'] as int);
                              _loadDisputes();
                              _loadBankingData();
                              if (mounted) AppToast.success(context, 'Loss accepted');
                            } catch (e) {
                              if (mounted) AppToast.fromError(context, e, fallback: 'Failed to accept loss');
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPayoutStatusSection() {
    if (_payoutItems.isEmpty && !_payoutLoading) _loadPayoutStatus();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payout Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
        const SizedBox(height: 8),
        if (_payoutLoading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
        if (!_payoutLoading && _payoutItems.isEmpty) Card(color: AppTheme.cardOf(context), child: Padding(padding: const EdgeInsets.all(16), child: Text('No pending payouts.', style: TextStyle(color: AppTheme.textSecondaryOf(context))))),
        ..._payoutItems.map<Widget>((p) => Card(
          color: AppTheme.cardOf(context),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: (p['has_bank_account'] == true) ? AppTheme.successColor.withOpacity(0.15) : AppTheme.warningColor.withOpacity(0.15),
              child: Icon(Icons.person, color: (p['has_bank_account'] == true) ? AppTheme.successColor : AppTheme.warningColor, size: 20),
            ),
            title: Text(p['organizer_name'] ?? 'Organizer #${p['organizer_id']}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(context))),
            subtitle: Text(
              'Pending: ${centsToStr(p['pending_amount_cents'] ?? 0)}'
              '${p['has_bank_account'] != true ? ' · No bank account' : ''}'
              '${p['payout_schedule'] != null ? ' · ${p['payout_schedule']}' : ''}'
              '${p['next_payout_date'] != null ? ' · Next: ${p['next_payout_date']}' : ''}',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
            ),
            trailing: (p['has_bank_account'] == true && (p['pending_amount_cents'] ?? 0) > 0) ? ElevatedButton(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), textStyle: const TextStyle(fontSize: 12)),
              onPressed: () async {
                try {
                  await ApiService.instance.adminForcePayout(p['organizer_id'] as int);
                  _loadPayoutStatus();
                  if (mounted) AppToast.success(context, 'Payout initiated');
                } catch (e) {
                  if (mounted) AppToast.fromError(context, e, fallback: 'Payout failed');
                }
              },
              child: const Text('Force Payout'),
            ) : null,
          ),
        )),
      ],
    );
  }

  Widget _buildTransactionLedger() {
    if (_transactions.isEmpty && !_txnLoading && _txnTotal == 0) _loadTransactions();
    final totalPages = (_txnTotal / 20).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Transaction Ledger', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(hintText: 'Search transactions…', prefixIcon: const Icon(Icons.search, size: 18), isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                onChanged: (v) {
                  setState(() => _txnSearch = v);
                  _loadTransactions();
                },
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _txnStatusFilter,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'settled', child: Text('Settled')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'failed', child: Text('Failed')),
                DropdownMenuItem(value: 'refunded', child: Text('Refunded')),
              ],
              onChanged: (v) { setState(() { _txnStatusFilter = v ?? 'all'; }); _loadTransactions(); },
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_txnLoading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
        if (!_txnLoading) ..._transactions.map<Widget>((t) {
          final createdAt = t['created_at'] as String?;
          final dateStr = createdAt != null ? createdAt.substring(0, 16).replaceFirst('T', ' ') : '';
          return Card(
            color: AppTheme.cardOf(context),
            child: ExpansionTile(
              dense: true,
              leading: Icon(_txnIcon(t['operation']), size: 20, color: AppTheme.accentColor),
              title: Text('${t['operation'] ?? ''} · ${centsToStr(t['amount_cents'] ?? 0)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(context))),
              subtitle: Text('${t['status'] ?? ''} · $dateStr', style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
              trailing: widget.mockModeActive ? IconButton(
                icon: const Icon(Icons.report_problem, size: 18),
                tooltip: 'Simulate Dispute',
                color: AppTheme.warningColor,
                onPressed: () async {
                  try {
                    await ApiService.instance.adminSimulateDispute(t['transaction_id'] as String);
                    _loadBankingData();
                    _loadDisputes();
                    if (mounted) AppToast.success(context, 'Dispute simulated');
                  } catch (e) {
                    if (mounted) AppToast.fromError(context, e, fallback: 'Failed to simulate dispute');
                  }
                },
              ) : null,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (t['from_account'] != null || t['to_account'] != null)
                        _txnDetailRow('Accounts', '${t['from_account'] ?? '—'} → ${t['to_account'] ?? '—'}'),
                      if (t['authorization_code'] != null)
                        _txnDetailRow('Auth Code', '${t['authorization_code']}'),
                      if (t['receipt_reference'] != null && (t['receipt_reference'] as String).isNotEmpty)
                        _txnDetailRow('Receipt #', '${t['receipt_reference']}'),
                      if (t['description'] != null && (t['description'] as String).isNotEmpty)
                        _txnDetailRow('Description', '${t['description']}'),
                      if (t['transaction_id'] != null)
                        _txnDetailRow('Transaction ID', '${t['transaction_id']}'),
                      if (t['related_type'] != null)
                        _txnDetailRow('Related', '${t['related_type']} #${t['related_id'] ?? ''}'),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        if (!_txnLoading && totalPages > 1) Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: _txnPage > 0 ? () => _loadTransactions(page: _txnPage - 1) : null),
              Text('Page ${_txnPage + 1} of $totalPages', style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context))),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: _txnPage < totalPages - 1 ? () => _loadTransactions(page: _txnPage + 1) : null),
            ],
          ),
        ),
      ],
    );
  }

  IconData _txnIcon(String? op) {
    switch (op) {
      case 'charge': return Icons.arrow_downward;
      case 'refund': return Icons.undo;
      case 'transfer': return Icons.swap_horiz;
      default: return Icons.receipt;
    }
  }

  Widget _txnDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryOf(context)))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 11, color: AppTheme.textPrimaryOf(context)), overflow: TextOverflow.ellipsis, maxLines: 2)),
        ],
      ),
    );
  }
}
