import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../repositories/event_repository.dart';
import '../../../widgets/app_toast.dart';

class EditMilestone {
  int? id;
  final titleCtrl = TextEditingController();
  final benefitCtrl = TextEditingController();
  int unlockPercent = 50;
  EditMilestone({this.id});
}

class EditMilestonesSection extends StatefulWidget {
  final int eventId;
  const EditMilestonesSection({super.key, required this.eventId});

  @override
  State<EditMilestonesSection> createState() => _EditMilestonesSectionState();
}

class _EditMilestonesSectionState extends State<EditMilestonesSection> {
  bool _expanded = false;
  List<EditMilestone> _milestones = [];

  @override
  void initState() {
    super.initState();
    _loadMilestones();
  }

  Future<void> _loadMilestones() async {
    try {
      final api = context.read<EventRepository>();
      final list = await api.getMilestones(widget.eventId);
      if (mounted) {
        setState(() {
          _milestones = list.map((j) {
            final ms = EditMilestone(id: j['id']);
            ms.titleCtrl.text = j['title'] ?? '';
            ms.benefitCtrl.text = j['benefit_description'] ?? '';
            ms.unlockPercent = j['unlock_percent'] ?? 50;
            return ms;
          }).toList();
          if (_milestones.isNotEmpty) _expanded = true;
        });
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _saveMilestone(EditMilestone ms) async {
    final title = ms.titleCtrl.text.trim();
    if (title.isEmpty) return;
    final api = context.read<EventRepository>();
    try {
      if (ms.id != null) {
        await api.updateMilestone(widget.eventId, ms.id!, {
          'title': title,
          'unlock_percent': ms.unlockPercent,
          'benefit_description': ms.benefitCtrl.text.trim(),
        });
        if (mounted) AppToast.success(context, 'Milestone updated');
      } else {
        final resp = await api.createMilestone(widget.eventId, {
          'title': title,
          'unlock_percent': ms.unlockPercent,
          if (ms.benefitCtrl.text.trim().isNotEmpty)
            'benefit_description': ms.benefitCtrl.text.trim(),
        });
        ms.id = resp['id'] as int;
        if (mounted) AppToast.success(context, 'Milestone created');
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to save milestone');
      }
    }
  }

  Future<void> _deleteMilestone(int idx) async {
    final ms = _milestones[idx];
    if (ms.id != null) {
      try {
        final api = context.read<EventRepository>();
        await api.deleteMilestone(widget.eventId, ms.id!);
      } catch (e) {
        if (mounted) {
          AppToast.fromError(context, e,
              fallback: 'Failed to delete milestone');
        }
        return;
      }
    }
    setState(() => _milestones.removeAt(idx));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _expanded
                  ? context.photoAccent.withValues(alpha: 0.08)
                  : AppTheme.surfaceOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _expanded
                    ? context.photoAccent.withValues(alpha: 0.3)
                    : AppTheme.dividerOf(context),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_events_rounded,
                    size: 18,
                    color: _expanded
                        ? context.photoAccent
                        : AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Funding Milestones',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                ),
                if (_milestones.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.photoAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${_milestones.length}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.photoAccent)),
                  ),
                const SizedBox(width: 4),
                Icon(
                  _expanded
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
              color: AppTheme.surfaceOf(context),
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
                ..._milestones.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final ms = entry.value;
                  return _buildMilestoneCard(idx, ms);
                }),
                GestureDetector(
                  onTap: () =>
                      setState(() => _milestones.add(EditMilestone())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: AppTheme.dividerOf(context)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded,
                            size: 18,
                            color: AppTheme.textSecondaryOf(context)),
                        const SizedBox(width: 6),
                        Text('Add Milestone',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color:
                                    AppTheme.textSecondaryOf(context))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  Widget _buildMilestoneCard(int idx, EditMilestone ms) {
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
                icon: Icon(Icons.save_rounded,
                    size: 18, color: AppTheme.successColor),
                onPressed: () => _saveMilestone(ms),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Save',
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 18, color: AppTheme.errorColor),
                onPressed: () => _deleteMilestone(idx),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Delete',
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
        ],
      ),
    );
  }
}
