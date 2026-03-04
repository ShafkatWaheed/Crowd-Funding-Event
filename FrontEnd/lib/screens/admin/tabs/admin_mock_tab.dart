import 'package:flutter/material.dart';

import '../admin_shared.dart';
import '../../../config/theme.dart';
import '../../../models/admin.dart';
import 'package:provider/provider.dart';

import '../../../providers/admin_provider.dart';

class AdminMockTab extends StatefulWidget {
  final void Function(String) onSnack;
  final List<PlatformSetting> settings;
  final void Function(String key, String value) onUpdateSetting;
  final VoidCallback? onSettingsReload;

  const AdminMockTab({
    super.key,
    required this.onSnack,
    required this.settings,
    required this.onUpdateSetting,
    this.onSettingsReload,
  });

  @override
  State<AdminMockTab> createState() => _AdminMockTabState();
}

class _AdminMockTabState extends State<AdminMockTab> {
  AdminMockOverview? _mockData;
  bool _mockLoading = false;
  final Map<String, String> _sliderOverrides = {};

  final _feePercentCtrl = TextEditingController();
  final _feeFixedCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(AdminMockTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) _syncControllers();
  }

  void _syncControllers() {
    _feePercentCtrl.text = _settingVal('mock_stripe_fee_percent');
    _feeFixedCtrl.text = _settingVal('mock_stripe_fee_fixed_cents');
  }

  @override
  void dispose() {
    _feePercentCtrl.dispose();
    _feeFixedCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMockData() async {
    setState(() => _mockLoading = true);
    try {
      final admin = context.read<AdminProvider>();
      final data = await admin.getMockOverview();
      if (mounted) setState(() { _mockData = data; _mockLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _mockLoading = false);
    }
  }

  String _settingVal(String key) {
    final s = widget.settings.cast<PlatformSetting?>().firstWhere(
      (s) => s?.key == key, orElse: () => null,
    );
    return s?.value ?? '';
  }

  static String _centsToStr(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

  Widget _buildMockSection() {
    if (_mockData == null && !_mockLoading) _loadMockData();
    if (_mockLoading || _mockData == null) return const Center(child: CircularProgressIndicator());
    final d = _mockData!;

    return RefreshIndicator(
      onRefresh: _loadMockData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _settingVal('payment_mock_enabled') == 'true'
                    ? AppTheme.warningSurface
                    : AppTheme.successOf(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _settingVal('payment_mock_enabled') == 'true'
                        ? Icons.science_outlined
                        : Icons.payments,
                    color: _settingVal('payment_mock_enabled') == 'true'
                        ? AppTheme.warningColor
                        : AppTheme.successOf(context),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _settingVal('payment_mock_enabled') == 'true'
                          ? 'Mock Mode — All payments are simulated'
                          : 'Live Mode — Real payment gateway active',
                      style: TextStyle(
                        color: AppTheme.textPrimaryOf(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Switch(
                    value: _settingVal('payment_mock_enabled') == 'true',
                    activeTrackColor: AppTheme.warningColor,
                    onChanged: (on) {
                      widget.onUpdateSetting('payment_mock_enabled', on ? 'true' : 'false');
                    },
                  ),
                ],
              ),
            ),
            Text('Mock Stats', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                infoCard(context, 'Transactions', '${d.totalTransactions}', Icons.receipt, AppTheme.accentColor),
                infoCard(context, 'Volume', _centsToStr(d.totalVolumeCents), Icons.attach_money, AppTheme.successColor),
                infoCard(context, 'Success Rate', '${d.successRate}%', Icons.check_circle, AppTheme.successColor),
                infoCard(context, 'Emails', '${d.totalEmails}', Icons.email, AppTheme.accentColor),
                infoCard(context, 'Bounce Rate', '${d.emailBounceRate}%', Icons.error_outline, AppTheme.warningColor),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              color: AppTheme.cardOf(context),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(child: Text('Last Transaction: ${d.lastTransactionAt ?? 'N/A'}', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)))),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Last Email: ${d.lastEmailAt ?? 'N/A'}', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: const Text('Clear All Mock Data'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor, foregroundColor: Colors.white),
                  onPressed: () async {
                    final admin = context.read<AdminProvider>();
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Clear Mock Data?'),
                        content: const Text('This will delete all mock transactions and emails. This cannot be undone.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await admin.clearMockData();
                      _loadMockData();
                    }
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Settle All Pending'),
                  onPressed: () async {
                    await context.read<AdminProvider>().settleAllPending();
                    _loadMockData();
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.error_outline, size: 18),
                  label: const Text('Fail Next Charge'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningColor, foregroundColor: Colors.white),
                  onPressed: () async {
                    await context.read<AdminProvider>().failNextCharge();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Next charge will fail')));
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('Reset to Defaults'),
                  onPressed: () async {
                    final admin = context.read<AdminProvider>();
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Reset Mock Settings?'),
                        content: const Text('All mock parameters will be reset to their default values.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await admin.resetMockDefaults();
                      widget.onSettingsReload?.call();
                      _loadMockData();
                      if (mounted) widget.onSnack('Mock settings reset to defaults');
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildMockTuneables(),
            const SizedBox(height: 16),
            Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: 8),
            ...(d.recentTransactions.map((t) => Card(
              color: AppTheme.cardOf(context),
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: Icon(_mockOpIcon(t.operation), color: _mockStatusColor(t.status), size: 24),
                title: Text('${t.operation} — ${_centsToStr(t.amountCents)}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimaryOf(context))),
                subtitle: Text('${t.fromAccount ?? ''} → ${t.toAccount ?? ''}\n${t.status}${t.failureReason != null ? ' (${t.failureReason})' : ''}',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
                trailing: Text(t.authorizationCode ?? '', style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryOf(context))),
                isThreeLine: true,
              ),
            ))),
            const SizedBox(height: 16),
            Text('Recent Emails', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: 8),
            ...(d.recentEmails.map((e) => Card(
              color: AppTheme.cardOf(context),
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: Icon(e.status == 'bounced' ? Icons.error : Icons.check_circle,
                  color: e.status == 'bounced' ? AppTheme.errorColor : AppTheme.successColor, size: 20),
                title: Text(e.subject ?? '', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimaryOf(context))),
                subtitle: Text('To: ${e.toEmail ?? ''} — ${e.templateKey ?? 'custom'}',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
              ),
            ))),
          ],
        ),
      ),
    );
  }

  IconData _mockOpIcon(String? op) {
    switch (op) {
      case 'charge': return Icons.credit_card;
      case 'transfer': return Icons.swap_horiz;
      case 'refund': return Icons.replay;
      case 'hold': return Icons.lock;
      case 'release': return Icons.lock_open;
      default: return Icons.receipt;
    }
  }

  Color _mockStatusColor(String? status) {
    switch (status) {
      case 'completed': case 'settled': return AppTheme.successColor;
      case 'failed': return AppTheme.errorColor;
      case 'processing': case 'settlement_pending': return AppTheme.warningColor;
      default: return AppTheme.accentColor;
    }
  }

  Widget _buildMockTuneables() {
    final feePercent = double.tryParse(_settingVal('mock_stripe_fee_percent')) ?? 2.9;
    final feeFixed = int.tryParse(_settingVal('mock_stripe_fee_fixed_cents')) ?? 30;
    final sampleFee = (5000 * feePercent / 100).round() + feeFixed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment Simulation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
        const SizedBox(height: 8),
        Card(
          color: AppTheme.cardOf(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _mockSliderRow('Charge Latency Min (ms)', 'mock_charge_latency_min_ms', 0, 10000),
                _mockSliderRow('Charge Latency Max (ms)', 'mock_charge_latency_max_ms', 100, 15000),
                const Divider(),
                _mockSliderRow('Transfer Latency Min (ms)', 'mock_transfer_latency_min_ms', 0, 10000),
                _mockSliderRow('Transfer Latency Max (ms)', 'mock_transfer_latency_max_ms', 100, 15000),
                const Divider(),
                _mockSliderRow('Refund Latency Min (ms)', 'mock_refund_latency_min_ms', 0, 10000),
                _mockSliderRow('Refund Latency Max (ms)', 'mock_refund_latency_max_ms', 100, 15000),
                const Divider(),
                _mockSliderRow('Failure Rate (%)', 'mock_failure_rate_percent', 0, 50),
                _mockSliderRow('Settlement Delay (s)', 'mock_settlement_delay_seconds', 0, 86400),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6, runSpacing: 4,
                  children: [
                    _presetChip('Instant', 'mock_settlement_delay_seconds', '0'),
                    _presetChip('Fast (5s)', 'mock_settlement_delay_seconds', '5'),
                    _presetChip('Realistic (30s)', 'mock_settlement_delay_seconds', '30'),
                    _presetChip('Production (1d)', 'mock_settlement_delay_seconds', '86400'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Fee Simulation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
        const SizedBox(height: 8),
        Card(
          color: AppTheme.cardOf(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _mockInputRow('Fee Percent', 'mock_stripe_fee_percent', _feePercentCtrl),
                _mockInputRow('Fixed Fee (cents)', 'mock_stripe_fee_fixed_cents', _feeFixedCtrl),
                const SizedBox(height: 8),
                Text('Preview: on a \$50.00 charge, fee = \$${(sampleFee / 100).toStringAsFixed(2)}, net = \$${((5000 - sampleFee) / 100).toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context), fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Email Simulation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
        const SizedBox(height: 8),
        Card(
          color: AppTheme.cardOf(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _mockSliderRow('Bounce Rate (%)', 'mock_email_bounce_rate_percent', 0, 50),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _mockSliderRow(String label, String key, double min, double max) {
    final displayVal = _sliderOverrides[key] ?? _settingVal(key);
    final val = double.tryParse(displayVal) ?? min;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 180, child: Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(context)))),
          Expanded(
            child: Slider(
              value: val.clamp(min, max),
              min: min, max: max,
              divisions: ((max - min) / (max > 1000 ? 100 : 1)).round().clamp(1, 500),
              label: val.round().toString(),
              activeColor: AppTheme.accentOf(context),
              onChanged: (v) {
                setState(() => _sliderOverrides[key] = v.round().toString());
              },
              onChangeEnd: (v) {
                setState(() => _sliderOverrides.remove(key));
                widget.onUpdateSetting(key, v.round().toString());
              },
            ),
          ),
          SizedBox(width: 50, child: Text(val.round().toString(), textAlign: TextAlign.end,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.accentOf(context)))),
        ],
      ),
    );
  }

  Widget _presetChip(String label, String key, String value) {
    final current = _settingVal(key);
    final selected = current == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      selectedColor: AppTheme.accentOf(context).withValues(alpha: 0.2),
      onSelected: (_) => widget.onUpdateSetting(key, value),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _mockInputRow(String label, String key, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 180, child: Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(context)))),
          SizedBox(
            width: 120,
            child: TextField(
              controller: controller,
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

  @override
  Widget build(BuildContext context) {
    return _buildMockSection();
  }
}
