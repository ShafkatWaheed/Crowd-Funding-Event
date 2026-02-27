import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/event_form_models.dart';

class MilestoneSection extends StatefulWidget {
  final List<MilestoneInput> milestones;

  const MilestoneSection({
    super.key,
    required this.milestones,
  });

  @override
  State<MilestoneSection> createState() => _MilestoneSectionState();
}

class _MilestoneSectionState extends State<MilestoneSection> {
  bool _showMilestoneSection = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(
              () => _showMilestoneSection = !_showMilestoneSection),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _showMilestoneSection
                  ? context.reviewAccent.withValues(alpha: 0.08)
                  : AppTheme.cardOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showMilestoneSection
                    ? context.reviewAccent.withValues(alpha: 0.3)
                    : AppTheme.dividerOf(context),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_events_rounded,
                    size: 18,
                    color: _showMilestoneSection
                        ? context.photoAccent
                        : AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Funding Milestones (Optional)',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppTheme.textPrimaryOf(context))),
                ),
                if (widget.milestones.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          context.reviewAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${widget.milestones.length}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.reviewAccent)),
                  ),
                const SizedBox(width: 4),
                Icon(
                  _showMilestoneSection
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.dividerOf(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Define milestones that unlock as your event reaches funding goals.',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context)),
                ),
                const SizedBox(height: 12),
                ...widget.milestones.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final ms = entry.value;
                  return _buildMilestoneCard(idx, ms);
                }),
                GestureDetector(
                  onTap: () => setState(
                      () => widget.milestones.add(MilestoneInput())),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.dividerOf(context)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded,
                            size: 18,
                            color:
                                AppTheme.textSecondaryOf(context)),
                        const SizedBox(width: 6),
                        Text('Add Milestone',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppTheme.textSecondaryOf(
                                    context))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          crossFadeState: _showMilestoneSection
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  Widget _buildMilestoneCard(int idx, MilestoneInput ms) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Milestone ${idx + 1}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 18, color: AppTheme.errorColor),
                onPressed: () =>
                    setState(() => widget.milestones.removeAt(idx)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: ms.titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'e.g. DJ Sound System Upgrade',
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Unlock at:',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context))),
              Expanded(
                child: Slider(
                  value: ms.unlockPercent.toDouble(),
                  min: 1,
                  max: 100,
                  divisions: 99,
                  label: '${ms.unlockPercent}%',
                  onChanged: (v) =>
                      setState(() => ms.unlockPercent = v.round()),
                ),
              ),
              SizedBox(
                width: 42,
                child: Text('${ms.unlockPercent}%',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                    textAlign: TextAlign.right),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: ms.benefitCtrl,
            decoration: const InputDecoration(
              labelText: 'Benefit Description',
              hintText:
                  'e.g. Premium sound system for all attendees',
              isDense: true,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.discount_rounded,
                  size: 14, color: context.fundingAccent),
              const SizedBox(width: 6),
              Text('Discount for early pledgers',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondaryOf(context))),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: ms.discountValueCtrl,
            decoration: const InputDecoration(
              labelText: 'Discount %',
              hintText: '0',
              isDense: true,
              suffixText: '%',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 2),
          Text(
            'Pledgers at this milestone get this % off tickets',
            style: TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondaryOf(context)),
          ),
        ],
      ),
    );
  }
}
