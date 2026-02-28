import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../utils/date_time_utils.dart';
import '../../../config/design_tokens.dart';
import '../../../models/event.dart';
import '../../../providers/event_provider.dart';
import '../../../services/api_service.dart';
import '../../../widgets/app_toast.dart';

class ScheduleMilestoneDialogs {
  ScheduleMilestoneDialogs._();

  // ═══════════════════════════════════════════
  // Flatten schedule day-groups into a sorted flat list
  // ═══════════════════════════════════════════

  static List<Map<String, dynamic>> flattenScheduleDays(List<dynamic> dayGroups) {
    final flat = <Map<String, dynamic>>[];
    for (final group in dayGroups) {
      final items = group['items'] as List? ?? [];
      for (final item in items) {
        flat.add(Map<String, dynamic>.from(item as Map));
      }
    }
    flat.sort((a, b) {
      final dc = (a['date'] ?? '').compareTo(b['date'] ?? '');
      if (dc != 0) return dc;
      return (a['start_time'] ?? '').compareTo(b['start_time'] ?? '');
    });
    return flat;
  }

  // ═══════════════════════════════════════════
  // Manage Schedule (bottom sheet)
  // ═══════════════════════════════════════════

  static Future<void> showManageScheduleSheet(
    BuildContext context, Event event, VoidCallback onRefresh,
  ) async {
    final api = context.read<ApiService>();
    List<Map<String, dynamic>> items = [];
    bool loading = true;

    final eventStart = event.startTime;
    final eventEnd = event.endTime;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.topXl,
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          if (loading) {
            api.getSchedule(event.id).then((list) {
              setSheetState(() {
                items = flattenScheduleDays(list);
                loading = false;
              });
            }).catchError((_) {
              setSheetState(() => loading = false);
            });
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.92,
            expand: false,
            builder: (_, scrollCtrl) {
              return Padding(
                padding: EdgeInsets.only(
                  left: AppSpacing.xl, right: AppSpacing.xl, top: AppSpacing.lg,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.dividerOf(ctx),
                        borderRadius: AppRadius.sm,
                      ),
                    ),
                    AppSpacing.vLg,
                    Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, color: AppTheme.accentColor),
                        AppSpacing.hSm,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Manage Schedule',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimaryOf(ctx))),
                              if (eventStart != null)
                                Text(
                                  'Event: ${AppDateFormat.dateOnly(eventStart)}'
                                  '${eventEnd != null ? ' \u2013 ${AppDateFormat.dateOnly(eventEnd)}' : ''}',
                                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(ctx)),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle_rounded, color: AppTheme.accentColor, size: 28),
                          onPressed: () => showScheduleItemEditor(ctx, api, event, null, (newItem) {
                            setSheetState(() => items.add(Map<String, dynamic>.from(newItem)));
                            onRefresh();
                          }),
                        ),
                      ],
                    ),
                    AppSpacing.vMd,
                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                          : items.isEmpty
                              ? Center(child: Text('No schedule items yet.\nTap + to add one.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppTheme.textSecondaryOf(ctx))))
                              : ListView.separated(
                                  controller: scrollCtrl,
                                  itemCount: items.length,
                                  separatorBuilder: (_, __) => AppSpacing.vSm,
                                  itemBuilder: (_, i) {
                                    final item = items[i];
                                    return Container(
                                      padding: AppSpacing.paddingMd,
                                      decoration: BoxDecoration(
                                        color: AppTheme.inputFillOf(ctx),
                                        borderRadius: AppRadius.md,
                                        border: Border.all(color: AppTheme.dividerOf(ctx)),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(item['title'] ?? '',
                                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                                                        color: AppTheme.textPrimaryOf(ctx))),
                                                AppSpacing.vXs,
                                                Text(
                                                  '${item['date'] ?? ''} • ${item['start_time'] ?? ''} – ${item['end_time'] ?? ''}',
                                                  style: TextStyle(fontSize: 12, color: AppTheme.accentColor),
                                                ),
                                                if (item['description'] != null && (item['description'] as String).isNotEmpty)
                                                  Padding(
                                                    padding: EdgeInsets.only(top: AppSpacing.xs),
                                                    child: Text(item['description'],
                                                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(ctx))),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.edit_rounded, size: 18, color: AppTheme.accentColor),
                                            onPressed: () => showScheduleItemEditor(ctx, api, event, item, (updated) {
                                              setSheetState(() => items[i] = Map<String, dynamic>.from(updated));
                                              onRefresh();
                                            }),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete_rounded, size: AppIconSize.sm, color: AppTheme.errorColor),
                                            onPressed: () async {
                                              try {
                                                await api.deleteScheduleItem(event.id, item['id']);
                                                setSheetState(() => items.removeAt(i));
                                                onRefresh();
                                              } catch (e) {
                                                if (ctx.mounted) AppToast.fromError(ctx, e, fallback: 'Delete failed');
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              );
            },
          );
        });
      },
    );
  }

  // ═══════════════════════════════════════════
  // Schedule Item Editor (dialog)
  // ═══════════════════════════════════════════

  static Future<void> showScheduleItemEditor(
    BuildContext parentCtx, ApiService api, Event event,
    Map<String, dynamic>? existing, Function(Map<String, dynamic>) onSaved,
  ) async {
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');

    final eventStart = event.startTime;
    final eventEnd = event.endTime;
    final firstDate = eventStart ?? DateTime.now();
    final lastDate = eventEnd ?? (eventStart?.add(const Duration(days: 7)) ?? DateTime.now().add(const Duration(days: 730)));

    DateTime? date;
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);

    if (existing != null) {
      try { date = DateTime.parse(existing['date']); } catch (e) { debugPrint(e.toString()); }
      try {
        final sp = (existing['start_time'] as String).split(':');
        startTime = TimeOfDay(hour: int.parse(sp[0]), minute: int.parse(sp[1]));
        final ep = (existing['end_time'] as String).split(':');
        endTime = TimeOfDay(hour: int.parse(ep[0]), minute: int.parse(ep[1]));
      } catch (e) { debugPrint(e.toString()); }
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: parentCtx,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDlgState) {
          String fmtTime(TimeOfDay t) =>
              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
          String fmtDate(DateTime? d) =>
              d != null ? AppDateFormat.dateOnly(d) : 'Pick date';

          return AlertDialog(
            title: Text(existing != null ? 'Edit Session' : 'Add Session'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (eventStart != null)
                    Container(
                      width: double.infinity,
                      padding: AppSpacing.paddingMd,
                      margin: EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withValues(alpha: 0.08),
                        borderRadius: AppRadius.sm,
                      ),
                      child: Text(
                        'Event window: ${AppDateFormat.dateOnly(firstDate)}'
                        ' \u2013 ${AppDateFormat.dateOnly(lastDate)}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.accentColor),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  AppSpacing.vMd,
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description (optional)'),
                    maxLines: 2,
                  ),
                  AppSpacing.vMd,
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.calendar_today, color: AppTheme.accentColor),
                    title: Text(fmtDate(date),
                        style: TextStyle(color: date != null ? AppTheme.textPrimaryOf(ctx) : AppTheme.textSecondaryOf(ctx))),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: date ?? firstDate,
                        firstDate: firstDate,
                        lastDate: lastDate,
                      );
                      if (picked != null) setDlgState(() => date = picked);
                    },
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.play_arrow_rounded, size: AppIconSize.md, color: ctx.scheduleAccent),
                          title: Text(fmtTime(startTime), style: const TextStyle(fontSize: 14)),
                          subtitle: const Text('Start', style: TextStyle(fontSize: 11)),
                          onTap: () async {
                            final t = await showTimePicker(context: ctx, initialTime: startTime);
                            if (t != null) setDlgState(() => startTime = t);
                          },
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.stop_rounded, size: AppIconSize.md, color: ctx.discountAccent),
                          title: Text(fmtTime(endTime), style: const TextStyle(fontSize: 14)),
                          subtitle: const Text('End', style: TextStyle(fontSize: 11)),
                          onTap: () async {
                            final t = await showTimePicker(context: ctx, initialTime: endTime);
                            if (t != null) setDlgState(() => endTime = t);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (titleCtrl.text.trim().isEmpty || date == null) return;
                  Navigator.pop(ctx, {
                    'title': titleCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'date': AppDateFormat.apiDate(date!),
                    'start_time': fmtTime(startTime),
                    'end_time': fmtTime(endTime),
                  });
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );

    if (result != null) {
      try {
        Map<String, dynamic> resp;
        if (existing != null && existing['id'] != null) {
          resp = await api.updateScheduleItem(event.id, existing['id'], result);
        } else {
          resp = await api.createScheduleItem(event.id, result);
        }
        onSaved(resp);
        if (parentCtx.mounted) AppToast.success(parentCtx, existing != null ? 'Session updated' : 'Session added');
      } catch (e) {
        if (parentCtx.mounted) AppToast.fromError(parentCtx, e, fallback: 'Failed to save session');
      }
    }
  }

  // ═══════════════════════════════════════════
  // Manage Milestones (bottom sheet)
  // ═══════════════════════════════════════════

  static Future<void> showManageMilestonesSheet(
    BuildContext context, Event event, VoidCallback onRefresh,
  ) async {
    final api = context.read<ApiService>();
    List<Map<String, dynamic>> items = [];
    bool loading = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.topXl,
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          if (loading) {
            api.getMilestones(event.id).then((list) {
              setSheetState(() {
                items = List<Map<String, dynamic>>.from(list);
                loading = false;
              });
            }).catchError((_) {
              setSheetState(() => loading = false);
            });
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.3,
            maxChildSize: 0.85,
            expand: false,
            builder: (_, scrollCtrl) {
              return Padding(
                padding: EdgeInsets.only(
                  left: AppSpacing.xl, right: AppSpacing.xl, top: AppSpacing.lg,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.dividerOf(ctx),
                        borderRadius: AppRadius.sm,
                      ),
                    ),
                    AppSpacing.vLg,
                    Row(
                      children: [
                        Icon(Icons.flag_rounded, color: ctx.fundingAccent),
                        AppSpacing.hSm,
                        Text('Manage Milestones',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimaryOf(ctx))),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.add_circle_rounded, color: ctx.fundingAccent, size: AppIconSize.xl),
                          onPressed: () => showMilestoneEditor(ctx, api, event.id, null, (newItem) {
                            setSheetState(() => items.add(newItem));
                            onRefresh();
                          }),
                        ),
                      ],
                    ),
                    AppSpacing.vMd,
                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                          : items.isEmpty
                              ? Center(child: Text('No milestones yet.\nTap + to add one.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppTheme.textSecondaryOf(ctx))))
                              : ListView.separated(
                                  controller: scrollCtrl,
                                  itemCount: items.length,
                                  separatorBuilder: (_, __) => AppSpacing.vSm,
                                  itemBuilder: (_, i) {
                                    final item = items[i];
                                    return Container(
                                      padding: AppSpacing.paddingMd,
                                      decoration: BoxDecoration(
                                        color: AppTheme.inputFillOf(ctx),
                                        borderRadius: AppRadius.md,
                                        border: Border.all(color: AppTheme.dividerOf(ctx)),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 42, height: 42,
                                            decoration: BoxDecoration(
                                              color: ctx.fundingAccent.withValues(alpha: 0.15),
                                              borderRadius: AppRadius.sm,
                                            ),
                                            child: Center(
                                              child: Text('${item['unlock_percent'] ?? 0}%',
                                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ctx.fundingAccent)),
                                            ),
                                          ),
                                          AppSpacing.hMd,
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(item['title'] ?? '',
                                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                                                        color: AppTheme.textPrimaryOf(ctx))),
                                                if (item['benefit'] != null && (item['benefit'] as String).isNotEmpty)
                                                  Padding(
                                                    padding: EdgeInsets.only(top: AppSpacing.xs),
                                                    child: Text(item['benefit'],
                                                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(ctx))),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.edit_rounded, size: AppIconSize.sm, color: AppTheme.accentColor),
                                            onPressed: () => showMilestoneEditor(ctx, api, event.id, item, (updated) {
                                              setSheetState(() => items[i] = updated);
                                              onRefresh();
                                            }),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete_rounded, size: AppIconSize.sm, color: AppTheme.errorColor),
                                            onPressed: () async {
                                              try {
                                                await api.deleteMilestone(event.id, item['id']);
                                                setSheetState(() => items.removeAt(i));
                                                onRefresh();
                                              } catch (e) {
                                                if (ctx.mounted) AppToast.fromError(ctx, e, fallback: 'Delete failed');
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              );
            },
          );
        });
      },
    );
  }

  // ═══════════════════════════════════════════
  // Milestone Editor (dialog)
  // ═══════════════════════════════════════════

  static Future<void> showMilestoneEditor(
    BuildContext parentCtx, ApiService api, int eventId,
    Map<String, dynamic>? existing, Function(Map<String, dynamic>) onSaved,
  ) async {
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final benefitCtrl = TextEditingController(text: existing?['benefit'] ?? '');
    int unlockPercent = existing?['unlock_percent'] ?? 50;

    final result = await showDialog<Map<String, dynamic>>(
      context: parentCtx,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDlgState) {
          return AlertDialog(
            title: Text(existing != null ? 'Edit Milestone' : 'Add Milestone'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  AppSpacing.vMd,
                  TextField(
                    controller: benefitCtrl,
                    decoration: const InputDecoration(labelText: 'Benefit / what unlocks'),
                    maxLines: 2,
                  ),
                  AppSpacing.vLg,
                  Row(
                    children: [
                      Text('Unlock at:', style: TextStyle(color: AppTheme.textSecondaryOf(ctx))),
                      AppSpacing.hSm,
                      Text('$unlockPercent%',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ctx.fundingAccent)),
                    ],
                  ),
                  Slider(
                    value: unlockPercent.toDouble(),
                    min: 10, max: 100, divisions: 18,
                    activeColor: ctx.fundingAccent,
                    label: '$unlockPercent%',
                    onChanged: (v) => setDlgState(() => unlockPercent = v.round()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (titleCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx, {
                    'title': titleCtrl.text.trim(),
                    'benefit': benefitCtrl.text.trim(),
                    'unlock_percent': unlockPercent,
                  });
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );

    if (result != null) {
      try {
        if (existing != null && existing['id'] != null) {
          final resp = await api.updateMilestone(eventId, existing['id'], result);
          onSaved(resp);
        } else {
          final resp = await api.createMilestone(eventId, result);
          onSaved(resp);
        }
        if (parentCtx.mounted) AppToast.success(parentCtx, existing != null ? 'Milestone updated' : 'Milestone added');
      } catch (e) {
        if (parentCtx.mounted) AppToast.fromError(parentCtx, e, fallback: 'Failed to save milestone');
      }
    }
  }

  // ═══════════════════════════════════════════
  // Extend Funding Dialog (deadline + goal, admin approval)
  // ═══════════════════════════════════════════

  static Future<void> showExtendFundingDialog(
    BuildContext context, Event event, VoidCallback onRefresh,
  ) async {
    final fundingEndCtrl = TextEditingController();
    final goalCtrl = TextEditingController(
      text: event.fundingGoalCents != null
          ? (event.fundingGoalCents! / 100).toStringAsFixed(2)
          : '',
    );
    DateTime? pickedDeadline;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Extend Funding'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: AppSpacing.paddingMd,
                  decoration: BoxDecoration(
                    color: AppTheme.accentSurfaceOf(ctx),
                    borderRadius: AppRadius.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: AppIconSize.sm, color: AppTheme.accentColor),
                      AppSpacing.hSm,
                      Expanded(
                        child: Text(
                          'This will send a request to admin for approval.',
                          style: TextStyle(color: AppTheme.accentColor, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.vLg,
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    pickedDeadline != null
                        ? AppDateFormat.fullDateTime(pickedDeadline!)
                        : 'Pick new funding deadline',
                    style: TextStyle(
                      fontSize: 14,
                      color: pickedDeadline != null ? AppTheme.textPrimaryOf(ctx) : AppTheme.textSecondaryOf(ctx),
                    ),
                  ),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null && ctx.mounted) {
                      final time = await showTimePicker(
                        context: ctx,
                        initialTime: const TimeOfDay(hour: 23, minute: 59),
                      );
                      setDialogState(() {
                        pickedDeadline = DateTime(
                          date.year, date.month, date.day,
                          time?.hour ?? 23, time?.minute ?? 59,
                        );
                        fundingEndCtrl.text = pickedDeadline!.toIso8601String();
                      });
                    }
                  },
                ),
                AppSpacing.vMd,
                TextField(
                  controller: goalCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'New Funding Goal (\$)',
                    prefixText: '\$ ',
                    helperText: 'Leave empty to keep current goal',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final data = <String, dynamic>{};
                if (fundingEndCtrl.text.trim().isNotEmpty) {
                  data['funding_end_at'] = fundingEndCtrl.text.trim();
                }
                final goalText = goalCtrl.text.trim();
                if (goalText.isNotEmpty) {
                  final parsed = double.tryParse(goalText);
                  if (parsed != null && parsed > 0) {
                    data['funding_goal_cents'] = (parsed * 100).toInt();
                  }
                }
                Navigator.pop(ctx, data);
              },
              child: const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
    if (result == null || result.isEmpty) return;
    if (!context.mounted) return;
    try {
      await context.read<ApiService>().extendFunding(event.id, result);
      if (context.mounted) {
        AppToast.success(context, 'Extension request submitted for admin approval');
        context.read<EventProvider>().loadEvent(event.id);
        onRefresh();
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to request extension');
      }
    }
  }

  // ═══════════════════════════════════════════
  // Set Event Date Dialog (direct, no admin approval)
  // ═══════════════════════════════════════════

  static Future<void> showSetEventDateDialog(
    BuildContext context, Event event, VoidCallback onRefresh,
  ) async {
    final api = context.read<ApiService>();

    DateTime? pickedStart;
    DateTime? pickedEnd;

    if (!context.mounted) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final bool canSubmit = pickedStart != null && pickedEnd != null;

          return AlertDialog(
            title: const Text('Set Event Date'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: AppSpacing.paddingMd,
                      decoration: BoxDecoration(
                        color: AppTheme.successSurfaceOf(ctx),
                        borderRadius: AppRadius.sm,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, size: AppIconSize.sm, color: AppTheme.successColor),
                          AppSpacing.hSm,
                          Expanded(
                            child: Text(
                              'This applies immediately — no admin approval needed.',
                              style: TextStyle(color: AppTheme.successColor, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.vLg,
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.play_arrow_rounded, color: ctx.scheduleAccent),
                      title: Text(
                        pickedStart != null
                            ? AppDateFormat.fullDateTime(pickedStart!)
                            : 'Pick start time',
                        style: TextStyle(
                          fontSize: 14,
                          color: pickedStart != null ? AppTheme.textPrimaryOf(ctx) : AppTheme.textSecondaryOf(ctx),
                        ),
                      ),
                      subtitle: const Text('Event start', style: TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.edit_calendar),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now().add(const Duration(days: 14)),
                          firstDate: DateTime.now().add(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 730)),
                        );
                        if (date != null && ctx.mounted) {
                          final time = await showTimePicker(
                            context: ctx,
                            initialTime: const TimeOfDay(hour: 18, minute: 0),
                          );
                          setDialogState(() {
                            pickedStart = DateTime(
                              date.year, date.month, date.day,
                              time?.hour ?? 18, time?.minute ?? 0,
                            );
                          });
                        }
                      },
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.stop_rounded, color: ctx.discountAccent),
                      title: Text(
                        pickedEnd != null
                            ? AppDateFormat.fullDateTime(pickedEnd!)
                            : 'Pick end time',
                        style: TextStyle(
                          fontSize: 14,
                          color: pickedEnd != null ? AppTheme.textPrimaryOf(ctx) : AppTheme.textSecondaryOf(ctx),
                        ),
                      ),
                      subtitle: const Text('Event end', style: TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.edit_calendar),
                      onTap: () async {
                        final initialDate = pickedStart?.add(const Duration(hours: 4)) ??
                            DateTime.now().add(const Duration(days: 14));
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: initialDate,
                          firstDate: pickedStart ?? DateTime.now().add(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 730)),
                        );
                        if (date != null && ctx.mounted) {
                          final time = await showTimePicker(
                            context: ctx,
                            initialTime: const TimeOfDay(hour: 22, minute: 0),
                          );
                          setDialogState(() {
                            pickedEnd = DateTime(
                              date.year, date.month, date.day,
                              time?.hour ?? 22, time?.minute ?? 0,
                            );
                          });
                        }
                      },
                    ),
                    AppSpacing.vSm,
                    Container(
                      padding: AppSpacing.paddingMd,
                      decoration: BoxDecoration(
                        color: AppTheme.accentSurfaceOf(ctx),
                        borderRadius: AppRadius.sm,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: AppIconSize.sm, color: AppTheme.accentColor),
                          AppSpacing.hSm,
                          Expanded(
                            child: Text(
                              'After setting dates, you can start selling tickets from the organizer actions.',
                              style: TextStyle(color: AppTheme.accentColor, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: canSubmit
                    ? () {
                        final data = <String, dynamic>{
                          'start_time': pickedStart!.toIso8601String(),
                          'end_time': pickedEnd!.toIso8601String(),
                        };
                        Navigator.pop(ctx, data);
                      }
                    : null,
                child: const Text('Set Date'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || result.isEmpty) return;
    try {
      await api.setEventDate(event.id, result);
      if (context.mounted) {
        AppToast.success(context, 'Event date set!');
        context.read<EventProvider>().loadEvent(event.id);
        onRefresh();
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to set event date');
      }
    }
  }
}
