import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../admin_shared.dart';

class BankingEscrowConfigSection extends StatefulWidget {
  final String Function(String key) settingVal;
  final void Function(String key, String value) onUpdateSetting;

  const BankingEscrowConfigSection({
    super.key,
    required this.settingVal,
    required this.onUpdateSetting,
  });

  @override
  State<BankingEscrowConfigSection> createState() =>
      _BankingEscrowConfigSectionState();
}

class _BankingEscrowConfigSectionState
    extends State<BankingEscrowConfigSection> {
  Map<String, String> _sliderOverrides = {};

  String _val(String key) {
    if (_sliderOverrides.containsKey(key)) return _sliderOverrides[key]!;
    return widget.settingVal(key);
  }

  @override
  Widget build(BuildContext context) {
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

    int fundSum = fundStages.fold(0, (s, st) => s + (int.tryParse(_val(st['pct']!)) ?? 0));
    int ticketSum = ticketStages.fold(0, (s, st) => s + (int.tryParse(_val(st['pct']!)) ?? 0));
    int sponsorSum = sponsorStages.fold(0, (s, st) => s + (int.tryParse(_val(st['pct']!)) ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Escrow Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
        const SizedBox(height: 8),
        _escrowConfigTile('Fund Escrow', '${_val('escrow_stage1_percent')}% / ${_val('escrow_stage2_percent')}% / ${_val('escrow_stage3_percent')}%',
          fundSum, context.fundingAccent, fundStages.map((st) => _escrowStageRow(st['label']!, st['pct']!)).toList()),
        const SizedBox(height: 8),
        _escrowConfigTile(
          'Ticket Escrow',
          '${_val('ticket_escrow_stage1_percent')}% / ${_val('ticket_escrow_stage2_percent')}% / ${_val('ticket_escrow_stage3_percent')}%',
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
          '${_val('sponsor_escrow_stage1_percent')}% / ${_val('sponsor_escrow_stage2_percent')}% / ${_val('sponsor_escrow_stage3_percent')}%',
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
    final val = double.tryParse(_val(key)) ?? 0;
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
    final val = _val(key) == 'true';
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
    final val = _val(key);
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
              controller: TextEditingController(text: _val(key)),
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
}
