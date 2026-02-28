import 'package:flutter/material.dart';

import '../../../../config/theme.dart';

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
  final Map<String, String> _sliderOverrides = {};

  String _val(String key) {
    if (_sliderOverrides.containsKey(key)) return _sliderOverrides[key]!;
    return widget.settingVal(key);
  }

  @override
  Widget build(BuildContext context) {
    int fundSum = (int.tryParse(_val('escrow_stage1_percent')) ?? 0)
        + (int.tryParse(_val('escrow_stage2_percent')) ?? 0)
        + (int.tryParse(_val('escrow_stage3_percent')) ?? 0);
    int ticketSum = (int.tryParse(_val('ticket_escrow_stage1_percent')) ?? 0)
        + (int.tryParse(_val('ticket_escrow_stage2_percent')) ?? 0)
        + (int.tryParse(_val('ticket_escrow_stage3_percent')) ?? 0);
    int sponsorSum = (int.tryParse(_val('sponsor_escrow_stage1_percent')) ?? 0)
        + (int.tryParse(_val('sponsor_escrow_stage2_percent')) ?? 0)
        + (int.tryParse(_val('sponsor_escrow_stage3_percent')) ?? 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Escrow Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
        const SizedBox(height: 4),
        Text(
          'Controls when and how much of collected funds are released to the organizer. '
          'All three stages must sum to 100%.',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
        ),
        const SizedBox(height: 8),

        // ── Fund Escrow ──
        _escrowConfigTile(
          'Fund Escrow',
          '${_val('escrow_stage1_percent')}% / ${_val('escrow_stage2_percent')}% / ${_val('escrow_stage3_percent')}%',
          'Holds crowd-funded pledge money. Released in 3 stages as the event progresses toward delivery.',
          fundSum, context.fundingAccent,
          [
            _stageHeader(context, 'Stage 1 — Planning',
                'Released when the configured trigger condition is met during the ticket-selling phase.'),
            _escrowStageRow('Payout %', 'escrow_stage1_percent'),
            _escrowBoolRow('Auto-release', 'escrow_stage1_trigger_enabled',
                hint: 'When ON, Stage 1 releases automatically when the trigger fires. When OFF, admin must release manually.'),
            _escrowModeRow('Trigger mode', 'escrow_stage1_trigger_mode',
                hints: {
                  'ticket_percent': 'Release when X% of tickets have been sold.',
                  'funding_end': 'Release as soon as the funding period ends successfully.',
                  'selling_started': 'Release the moment ticket selling begins.',
                }),
            _mockInputRow('Ticket sold %', 'escrow_stage1_ticket_percent',
                hint: 'Only used when trigger is "ticket percent". E.g. 50 = release when 50% of tickets are sold.'),

            _stageHeader(context, 'Stage 2 — Ready',
                'Released based on ticket sales progress or time elapsed toward the event date.'),
            _escrowStageRow('Payout %', 'escrow_stage2_percent'),
            _escrowBoolRow('Auto-release', 'escrow_stage2_trigger_enabled',
                hint: 'When ON, Stage 2 releases automatically when the trigger fires. When OFF, admin must release manually.'),
            _escrowModeRow('Trigger mode', 'escrow_stage2_trigger_mode',
                hints: {
                  'ticket_percent': 'Release when X% of total ticket capacity has been sold.',
                  'days_percent': 'Release when X% of the window from ticket-selling start to event date has elapsed.',
                }),
            _mockInputRow('Ticket sold %', 'escrow_stage2_ticket_percent',
                hint: 'Only used when trigger is "ticket percent". E.g. 75 = release when 75% of tickets are sold.'),
            _mockInputRow('Days elapsed %', 'escrow_stage2_days_percent',
                hint: 'Only used when trigger is "days percent". E.g. 50 = release when 50% of the selling-to-event window has passed.'),

            _stageHeader(context, 'Stage 3 — Completion',
                'Final payout after the event ends. Released by time elapsed or ticket scan rate.'),
            _escrowStageRow('Payout %', 'escrow_stage3_percent'),
            _escrowBoolRow('Auto-release', 'escrow_stage3_trigger_enabled',
                hint: 'When ON, Stage 3 releases automatically when the trigger fires. When OFF, admin must release manually.'),
            _escrowModeRow('Trigger mode', 'escrow_stage3_trigger_mode',
                hints: {
                  'days_after': 'Release X days after the event end date.',
                  'scan_threshold': 'Release once the event is complete and X% of tickets have been scanned at the door.',
                }),
            _mockInputRow('Days after event', 'escrow_stage3_days_after_event',
                hint: 'Only used when trigger is "days after". Number of days after the event ends before auto-release fires.'),
            _mockInputRow('Scan threshold (%)', 'scan_threshold_percent',
                hint: 'Only used when trigger is "scan threshold". Minimum % of tickets that must be scanned at the door.'),
            _mockInputRow('Grace days', 'stage3_grace_days',
                hint: 'Days to hold Stage 3 funds for admin review before automatic release fires (applies to all trigger modes).'),
          ],
        ),
        const SizedBox(height: 8),

        // ── Ticket Escrow ──
        _escrowConfigTile(
          'Ticket Escrow',
          '${_val('ticket_escrow_stage1_percent')}% / ${_val('ticket_escrow_stage2_percent')}% / ${_val('ticket_escrow_stage3_percent')}%',
          'Holds ticket sale revenue. Released after the event, with refund and dispute guards on later stages.',
          ticketSum, context.ticketAccent,
          [
            _stageHeader(context, 'Stage 1 — Early payout',
                'Released X days after the event ends. No conditions — early goodwill payout to the organizer.'),
            _escrowStageRow('Payout %', 'ticket_escrow_stage1_percent'),
            _mockInputRow('Days after event', 'ticket_escrow_stage1_days_after_event',
                hint: 'How many days after the event before this stage is released.'),

            _stageHeader(context, 'Stage 2 — Refund window close',
                'Released X days after event, but only if the refund rate is below the configured threshold.'),
            _escrowStageRow('Payout %', 'ticket_escrow_stage2_percent'),
            _mockInputRow('Days after event', 'ticket_escrow_stage2_days_after_event',
                hint: 'How many days after the event before this stage is released.'),
            _mockInputRow('Max refund rate (%)', 'ticket_escrow_stage2_max_refund_rate',
                hint: 'Maximum % of tickets refunded before this release is blocked (e.g. 10 = block if >10% refunded).'),

            _stageHeader(context, 'Stage 3 — Final settlement',
                'Final payout X days after the event. Optionally blocked if any active disputes exist.'),
            _escrowStageRow('Payout %', 'ticket_escrow_stage3_percent'),
            _mockInputRow('Days after event', 'ticket_escrow_stage3_days_after_event',
                hint: 'How many days after the event before final settlement is released.'),
            _escrowBoolRow('Require no disputes', 'ticket_escrow_stage3_require_no_disputes',
                hint: 'When ON, this stage is blocked until all disputes for the event are resolved.'),
          ],
        ),
        const SizedBox(height: 8),

        // ── Sponsor Escrow ──
        _escrowConfigTile(
          'Sponsor Escrow',
          '${_val('sponsor_escrow_stage1_percent')}% / ${_val('sponsor_escrow_stage2_percent')}% / ${_val('sponsor_escrow_stage3_percent')}%',
          'Holds sponsor payment funds. Each stage has a configurable trigger so release timing aligns with event milestones.',
          sponsorSum, context.sponsorAccent,
          [
            _stageHeader(context, 'Stage 1 — Pre-event',
                'Released when the event goes live OR a set number of days before the event.'),
            _escrowStageRow('Payout %', 'sponsor_escrow_stage1_percent'),
            _escrowModeRow('Trigger', 'sponsor_escrow_stage1_trigger_mode',
                hints: {'event_live': 'Release when the event is published and live.', 'days_before_event': 'Release X days before the event starts.'}),
            _mockInputRow('Days before event', 'sponsor_escrow_stage1_days_before_event',
                hint: 'Only used when trigger is "days before event".'),

            _stageHeader(context, 'Stage 2 — Event underway',
                'Released when the event starts OR when a target % of tickets have been sold.'),
            _escrowStageRow('Payout %', 'sponsor_escrow_stage2_percent'),
            _escrowModeRow('Trigger', 'sponsor_escrow_stage2_trigger_mode',
                hints: {'event_started': 'Release when the event start time is reached.', 'ticket_percent': 'Release when X% of tickets are sold.'}),
            _mockInputRow('Ticket sold %', 'sponsor_escrow_stage2_ticket_percent',
                hint: 'Only used when trigger is "ticket percent". E.g. 50 = release when 50% of tickets sold.'),

            _stageHeader(context, 'Stage 3 — Post-event',
                'Final payout X days after the event ends OR once the sponsor confirms delivery.'),
            _escrowStageRow('Payout %', 'sponsor_escrow_stage3_percent'),
            _escrowModeRow('Trigger', 'sponsor_escrow_stage3_trigger_mode',
                hints: {'days_after_event': 'Release X days after the event end date.', 'sponsor_confirmed': 'Release when the sponsor manually confirms deliverables were met.'}),
            _mockInputRow('Days after event', 'sponsor_escrow_stage3_days_after_event',
                hint: 'Only used when trigger is "days after event".'),
          ],
        ),
      ],
    );
  }

  Widget _escrowConfigTile(String title, String subtitle, String description, int sum, Color color, List<Widget> children) {
    final valid = sum == 100;
    return Card(
      color: AppTheme.cardOf(context),
      child: ExpansionTile(
        leading: Icon(Icons.lock_clock, color: color),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context))),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, style: TextStyle(color: valid ? AppTheme.textSecondaryOf(context) : AppTheme.errorColor)),
            Text(description, style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
          ],
        ),
        trailing: valid
            ? Icon(Icons.check_circle, color: AppTheme.successColor, size: 20)
            : Text('$sum% (must = 100)', style: const TextStyle(color: AppTheme.errorColor, fontSize: 12)),
        children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Column(children: children)),
        ],
      ),
    );
  }

  Widget _stageHeader(BuildContext context, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(context))),
          Text(description, style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
          const Divider(height: 8),
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

  Widget _escrowBoolRow(String label, String key, {String? hint}) {
    final val = _val(key) == 'true';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: 180, child: Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(context)))),
              Switch(value: val, activeTrackColor: AppTheme.successOf(context),
                onChanged: (on) => widget.onUpdateSetting(key, on ? 'true' : 'false')),
            ],
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(hint, style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
            ),
        ],
      ),
    );
  }

  Widget _escrowModeRow(String label, String key, {Map<String, String>? hints}) {
    final val = _val(key);
    const options = {
      'escrow_stage1_trigger_mode': ['ticket_percent', 'funding_end', 'selling_started'],
      'escrow_stage2_trigger_mode': ['ticket_percent', 'days_percent'],
      'escrow_stage3_trigger_mode': ['days_after', 'scan_threshold'],
      'sponsor_escrow_stage1_trigger_mode': ['event_live', 'days_before_event'],
      'sponsor_escrow_stage2_trigger_mode': ['event_started', 'ticket_percent'],
      'sponsor_escrow_stage3_trigger_mode': ['days_after_event', 'sponsor_confirmed'],
    };
    final opts = options[key] ?? [val];
    final currentVal = opts.contains(val) ? val : opts.first;
    final currentHint = hints?[currentVal];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(context)))),
              DropdownButton<String>(
                value: currentVal,
                underline: const SizedBox.shrink(),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.accentOf(context)),
                items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o.replaceAll('_', ' ')))).toList(),
                onChanged: (v) { if (v != null) widget.onUpdateSetting(key, v); },
              ),
            ],
          ),
          if (currentHint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(currentHint, style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
            ),
        ],
      ),
    );
  }

  Widget _mockInputRow(String label, String key, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(hint, style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
            ),
        ],
      ),
    );
  }
}
