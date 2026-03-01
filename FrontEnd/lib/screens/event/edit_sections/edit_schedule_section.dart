import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../services/api_service.dart';
import '../../../widgets/app_toast.dart';

class EditScheduleItem {
  int? id;
  DateTime? date;
  TimeOfDay startTime;
  TimeOfDay endTime;
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  String? error;
  EditScheduleItem({this.id})
      : startTime = const TimeOfDay(hour: 9, minute: 0),
        endTime = const TimeOfDay(hour: 10, minute: 0);
}

class EditScheduleSection extends StatefulWidget {
  final int eventId;
  final DateTime startTime;
  final DateTime endTime;
  final bool hasSchedule;
  final ValueChanged<bool> onHasScheduleChanged;

  const EditScheduleSection({
    super.key,
    required this.eventId,
    required this.startTime,
    required this.endTime,
    required this.hasSchedule,
    required this.onHasScheduleChanged,
  });

  @override
  State<EditScheduleSection> createState() => _EditScheduleSectionState();
}

class _EditScheduleSectionState extends State<EditScheduleSection> {
  bool _expanded = false;
  List<EditScheduleItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    try {
      final api = context.read<ApiService>();
      final list = await api.getSchedule(widget.eventId);
      if (mounted) {
        final parsed = <EditScheduleItem>[];
        for (final dayGroup in list) {
          for (final item in (dayGroup['items'] as List)) {
            final si = EditScheduleItem(id: item['id']);
            si.date = DateTime.tryParse(item['date'] ?? '');
            final sParts =
                (item['start_time'] as String? ?? '09:00').split(':');
            si.startTime = TimeOfDay(
                hour: int.parse(sParts[0]),
                minute: int.parse(sParts[1]));
            final eParts =
                (item['end_time'] as String? ?? '10:00').split(':');
            si.endTime = TimeOfDay(
                hour: int.parse(eParts[0]),
                minute: int.parse(eParts[1]));
            si.titleCtrl.text = item['title'] ?? '';
            si.descCtrl.text = item['description'] ?? '';
            parsed.add(si);
          }
        }
        setState(() {
          _items = parsed;
          if (_items.isNotEmpty) _expanded = true;
        });
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _saveItem(EditScheduleItem si) async {
    final title = si.titleCtrl.text.trim();
    if (title.isEmpty || si.date == null) {
      setState(() => si.error = title.isEmpty
          ? 'Title is required'
          : 'Date is required');
      return;
    }
    final api = context.read<ApiService>();
    final dateStr =
        '${si.date!.year}-${si.date!.month.toString().padLeft(2, '0')}-${si.date!.day.toString().padLeft(2, '0')}';
    final startStr =
        '${si.startTime.hour.toString().padLeft(2, '0')}:${si.startTime.minute.toString().padLeft(2, '0')}';
    final endStr =
        '${si.endTime.hour.toString().padLeft(2, '0')}:${si.endTime.minute.toString().padLeft(2, '0')}';
    try {
      if (si.id != null) {
        await api.updateScheduleItem(widget.eventId, si.id!, {
          'date': dateStr,
          'start_time': startStr,
          'end_time': endStr,
          'title': title,
          'description': si.descCtrl.text.trim(),
        });
        if (mounted) {
          setState(() => si.error = null);
          AppToast.success(context, 'Schedule item updated');
        }
      } else {
        final resp = await api.createScheduleItem(widget.eventId, {
          'date': dateStr,
          'start_time': startStr,
          'end_time': endStr,
          'title': title,
          if (si.descCtrl.text.trim().isNotEmpty)
            'description': si.descCtrl.text.trim(),
        });
        si.id = resp['id'] as int;
        if (mounted) {
          setState(() => si.error = null);
          AppToast.success(context, 'Schedule item created');
        }
      }
    } catch (e) {
      if (mounted) {
        final msg = ApiService.extractError(e, fallback: 'Failed to save schedule item');
        setState(() => si.error = msg);
      }
    }
  }

  Future<void> _deleteItem(int idx) async {
    final si = _items[idx];
    if (si.id != null) {
      try {
        final api = context.read<ApiService>();
        await api.deleteScheduleItem(widget.eventId, si.id!);
      } catch (e) {
        if (mounted) {
          AppToast.fromError(context, e,
              fallback: 'Failed to delete schedule item');
        }
        return;
      }
    }
    setState(() => _items.removeAt(idx));
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
                  ? context.feedAccent.withValues(alpha: 0.08)
                  : AppTheme.surfaceOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _expanded
                    ? context.feedAccent.withValues(alpha: 0.3)
                    : AppTheme.dividerOf(context),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded,
                    size: 18,
                    color: _expanded
                        ? context.feedAccent
                        : AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Event Schedule',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                ),
                if (_items.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.feedAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${_items.length}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.feedAccent)),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Use structured schedule',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryOf(context)),
                      ),
                    ),
                    Switch(
                      value: widget.hasSchedule,
                      onChanged: widget.onHasScheduleChanged,
                    ),
                  ],
                ),
                if (widget.hasSchedule) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Add time slots for your event. Save each item individually.',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryOf(context)),
                  ),
                  const SizedBox(height: 12),
                  ..._items.asMap().entries.map((entry) {
                    return _buildScheduleCard(entry.key, entry.value);
                  }),
                  GestureDetector(
                    onTap: () => setState(
                        () => _items.add(EditScheduleItem())),
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
                          Text('Add Schedule Item',
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

  Widget _buildScheduleCard(int idx, EditScheduleItem si) {
    final dateLabel = si.date != null
        ? '${si.date!.month}/${si.date!.day}/${si.date!.year}'
        : 'Select date';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: si.date ?? widget.startTime,
                    firstDate: widget.startTime,
                    lastDate: widget.endTime,
                  );
                  if (picked != null) {
                    setState(() => si.date = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        context.feedAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 14, color: context.feedAccent),
                      const SizedBox(width: 6),
                      Text(dateLabel,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.feedAccent)),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.save_rounded,
                    size: 18, color: AppTheme.successColor),
                onPressed: () => _saveItem(si),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Save',
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 18, color: AppTheme.errorColor),
                onPressed: () => _deleteItem(idx),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Delete',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: si.startTime,
                    );
                    if (t != null) {
                      setState(() => si.startTime = t);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppTheme.dividerOf(context)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(si.startTime.format(context),
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                AppTheme.textPrimaryOf(context))),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8),
                child: Text('–',
                    style: TextStyle(
                        color:
                            AppTheme.textSecondaryOf(context))),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: si.endTime,
                    );
                    if (t != null) {
                      setState(() => si.endTime = t);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppTheme.dividerOf(context)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(si.endTime.format(context),
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                AppTheme.textPrimaryOf(context))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: si.titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'e.g. Opening Keynote',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: si.descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              isDense: true,
            ),
            maxLines: 2,
          ),
          if (si.error != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded,
                      size: 16, color: AppTheme.errorColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      si.error!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.errorColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
