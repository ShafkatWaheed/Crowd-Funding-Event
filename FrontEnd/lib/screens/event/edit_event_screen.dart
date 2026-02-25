import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/event.dart';
import '../../models/venue.dart';
import '../../models/ticket_strategy.dart';
import '../../providers/event_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/searchable_dropdown.dart';

class _EditMilestone {
  int? id;
  final titleCtrl = TextEditingController();
  final benefitCtrl = TextEditingController();
  int unlockPercent = 50;
  _EditMilestone({this.id});
}

class _EditScheduleItem {
  int? id;
  DateTime? date;
  TimeOfDay startTime;
  TimeOfDay endTime;
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  _EditScheduleItem({this.id})
      : startTime = const TimeOfDay(hour: 9, minute: 0),
        endTime = const TimeOfDay(hour: 10, minute: 0);
}

class _EditLocalPrereq {
  String name;
  String description;
  bool isRequired;
  bool requiresDocument;
  _EditLocalPrereq({required this.name, this.description = '', this.isRequired = true, this.requiresDocument = false});
}

class _EditSponsorCategory {
  int? id;
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final spotsCtrl = TextEditingController(text: '1');
  final minBidCtrl = TextEditingController(text: '100.00');
  List<_EditLocalPrereq> prereqs;
  _EditSponsorCategory({this.id}) : prereqs = [];
}

class _EditTier {
  int? id;
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController(text: '0.00');
  final descCtrl = TextEditingController();
  _EditTier({this.id});
}

class EditEventScreen extends StatefulWidget {
  final int eventId;
  const EditEventScreen({super.key, required this.eventId});

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _fundingGoalCtrl = TextEditingController();
  final _minPledgeCtrl = TextEditingController();
  final _maxReservedSpotsCtrl = TextEditingController(text: '0');

  // _refundDeadlineCtrl removed — now using slider

  String _registrationType = 'open';
  String? _genre;
  bool _communityRules = false;
  bool _communityRulesFeatureEnabled = true;
  bool _postsEnabled = true;
  int _refundDeadlineDays = 0;
  bool _isLoading = false;
  bool _loadingEvent = true;
  Event? _event;
  DateTime? _startTime;
  DateTime? _endTime;
  DateTime? _fundingEndAt;
  List<TicketStrategy> _strategies = [];
  int? _selectedStrategyId;
  List<Venue> _venues = [];
  int? _selectedVenueId;

  // Parking & Transport
  bool _showTransportSection = false;
  final _parkingCtrl = TextEditingController();
  final _transitCtrl = TextEditingController();
  final _rideshareCtrl = TextEditingController();
  final _accessibilityCtrl = TextEditingController();

  // Milestones (live CRUD)
  bool _showMilestoneSection = false;
  List<_EditMilestone> _milestones = [];

  // Schedule (live CRUD)
  bool _showScheduleSection = false;
  bool _hasSchedule = false;
  List<_EditScheduleItem> _scheduleItems = [];

  // Ticket Tiers (live CRUD)
  bool _showTierSection = false;
  List<_EditTier> _tiers = [];
  bool _tiersLoaded = false;

  // Sponsorship Categories (live CRUD)
  bool _showSponsorshipSection = false;
  List<_EditSponsorCategory> _sponsorCategories = [];
  bool _sponsorCategoriesLoaded = false;
  List<Map<String, dynamic>> _sponsorTemplates = [];

  final List<String> _genres = [
    'community', 'music', 'tech', 'sports', 'arts',
    'food', 'charity', 'education', 'business', 'other',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEvent();
      _loadStrategies();
      _loadVenues();
      _loadFeatureFlags();
    });
  }

  Future<void> _loadFeatureFlags() async {
    try {
      final api = context.read<ApiService>();
      final flags = await api.getFeatureFlags();
      if (mounted) {
        setState(() {
          _communityRulesFeatureEnabled = flags['feature_community_rules_enabled'] ?? true;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadVenues() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getVenues();
      setState(() {
        _venues = data.map((v) => Venue.fromJson(v)).toList();
      });
    } catch (_) {}
  }

  Future<void> _loadStrategies() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getTicketStrategies();
      setState(() {
        _strategies = data.map((d) => TicketStrategy.fromJson(d)).toList();
      });
    } catch (_) {}
  }

  Future<void> _loadEvent() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getEvent(widget.eventId);
      final event = Event.fromJson(data);
      setState(() {
        _event = event;
        _titleCtrl.text = event.title;
        _descCtrl.text = event.description ?? '';
        _capacityCtrl.text = event.maxCapacity.toString();
        _fundingGoalCtrl.text = event.fundingGoalCents != null
            ? (event.fundingGoalCents! / 100).toStringAsFixed(2)
            : '';
        _minPledgeCtrl.text = (event.minPledgeCents / 100).toStringAsFixed(2);
        _maxReservedSpotsCtrl.text = event.maxReservedSpotsPerUser.toString();
        _registrationType = event.registrationType.name;
        _genre = event.genre;
        _communityRules = event.communityRules;
        _postsEnabled = event.postsEnabled;
        _refundDeadlineDays = event.refundDeadlineDays ?? 0;
        _startTime = event.startTime;
        _endTime = event.endTime;
        _fundingEndAt = event.fundingEndAt;
        _selectedStrategyId = event.ticketStrategyId;
        _selectedVenueId = event.venueId;
        _parkingCtrl.text = event.parkingInfo ?? '';
        _transitCtrl.text = event.transitInfo ?? '';
        _rideshareCtrl.text = event.rideshareInfo ?? '';
        _accessibilityCtrl.text = event.accessibilityInfo ?? '';
        _showTransportSection = event.hasTransportInfo;
        _hasSchedule = event.hasSchedule;
        _loadingEvent = false;
      });
      _loadMilestones();
      _loadSchedule();
      _loadTiers();
      _loadSponsorCategories();
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to load event');
        setState(() => _loadingEvent = false);
      }
    }
  }

  Future<void> _loadMilestones() async {
    try {
      final api = context.read<ApiService>();
      final list = await api.getMilestones(widget.eventId);
      if (mounted) {
        setState(() {
          _milestones = list.map((j) {
            final ms = _EditMilestone(id: j['id']);
            ms.titleCtrl.text = j['title'] ?? '';
            ms.benefitCtrl.text = j['benefit_description'] ?? '';
            ms.unlockPercent = j['unlock_percent'] ?? 50;
            return ms;
          }).toList();
          if (_milestones.isNotEmpty) _showMilestoneSection = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveMilestone(_EditMilestone ms) async {
    final title = ms.titleCtrl.text.trim();
    if (title.isEmpty) return;
    final api = context.read<ApiService>();
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
      if (mounted) AppToast.fromError(context, e, fallback: 'Failed to save milestone');
    }
  }

  Future<void> _deleteMilestone(int idx) async {
    final ms = _milestones[idx];
    if (ms.id != null) {
      try {
        final api = context.read<ApiService>();
        await api.deleteMilestone(widget.eventId, ms.id!);
      } catch (e) {
        if (mounted) AppToast.fromError(context, e, fallback: 'Failed to delete milestone');
        return;
      }
    }
    setState(() => _milestones.removeAt(idx));
  }

  Future<void> _loadSchedule() async {
    try {
      final api = context.read<ApiService>();
      final list = await api.getSchedule(widget.eventId);
      if (mounted) {
        final items = <_EditScheduleItem>[];
        for (final dayGroup in list) {
          for (final item in (dayGroup['items'] as List)) {
            final si = _EditScheduleItem(id: item['id']);
            si.date = DateTime.tryParse(item['date'] ?? '');
            final sParts = (item['start_time'] as String? ?? '09:00').split(':');
            si.startTime = TimeOfDay(hour: int.parse(sParts[0]), minute: int.parse(sParts[1]));
            final eParts = (item['end_time'] as String? ?? '10:00').split(':');
            si.endTime = TimeOfDay(hour: int.parse(eParts[0]), minute: int.parse(eParts[1]));
            si.titleCtrl.text = item['title'] ?? '';
            si.descCtrl.text = item['description'] ?? '';
            items.add(si);
          }
        }
        setState(() {
          _scheduleItems = items;
          if (_scheduleItems.isNotEmpty) _showScheduleSection = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveScheduleItem(_EditScheduleItem si) async {
    final title = si.titleCtrl.text.trim();
    if (title.isEmpty || si.date == null) return;
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
        if (mounted) AppToast.success(context, 'Schedule item updated');
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
        if (mounted) AppToast.success(context, 'Schedule item created');
      }
    } catch (e) {
      if (mounted) AppToast.fromError(context, e, fallback: 'Failed to save schedule item');
    }
  }

  Future<void> _deleteScheduleItem(int idx) async {
    final si = _scheduleItems[idx];
    if (si.id != null) {
      try {
        final api = context.read<ApiService>();
        await api.deleteScheduleItem(widget.eventId, si.id!);
      } catch (e) {
        if (mounted) AppToast.fromError(context, e, fallback: 'Failed to delete schedule item');
        return;
      }
    }
    setState(() => _scheduleItems.removeAt(idx));
  }

  Widget _buildEditSponsorCategoryCard(int index) {
    final sc = _sponsorCategories[index];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.ticketAccent.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.ticketAccent.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sc.id != null ? 'Sponsorship #${sc.id}' : 'New Sponsorship',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              if (sc.id != null)
                InkWell(
                  onTap: () => _showPrerequisiteSheet(sc),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.fundingAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.fundingAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.checklist_rounded, size: 14, color: context.fundingAccent),
                        const SizedBox(width: 4),
                        Text('Prerequisites', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.fundingAccent)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              IconButton(
                icon: Icon(Icons.save, size: 18, color: context.ticketAccent),
                onPressed: () => _saveSponsorCategory(sc),
                tooltip: 'Save',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.errorColor),
                onPressed: () => _deleteSponsorCategory(index),
                tooltip: 'Delete',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: sc.nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Sponsorship Name *',
              hintText: 'e.g. Gold Sponsor, Food Stall',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: sc.descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description',
              isDense: true,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: sc.spotsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Total Spots *',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: sc.minBidCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Min Bid (\$) *',
                    isDense: true,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          if (sc.id == null || sc.prereqs.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildEditPrereqSection(sc),
          ],
        ],
      ),
    );
  }

  Widget _buildEditPrereqSection(_EditSponsorCategory sc) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isRequired = true;
    bool requiresDocument = false;

    return StatefulBuilder(
      builder: (context, setLocal) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.checklist_rounded, size: 16, color: context.ticketAccent),
                const SizedBox(width: 6),
                Text('Prerequisites',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryOf(context))),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: context.ticketAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${sc.prereqs.length}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.ticketAccent)),
                ),
              ],
            ),
            if (sc.prereqs.isNotEmpty) ...[
              const SizedBox(height: 6),
              ...sc.prereqs.asMap().entries.map((entry) {
                final i = entry.key;
                final p = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.arrow_right_rounded, size: 18,
                                color: AppTheme.textSecondaryOf(context)),
                            Flexible(
                              child: Text(p.name,
                                  style: TextStyle(fontSize: 12,
                                      color: AppTheme.textPrimaryOf(context))),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: p.isRequired
                                    ? AppTheme.errorSurfaceOf(context)
                                    : AppTheme.textSecondaryOf(context).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                p.isRequired ? 'Required' : 'Optional',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                    color: p.isRequired ? AppTheme.errorColor : AppTheme.textSecondaryOf(context)),
                              ),
                            ),
                            if (p.requiresDocument) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: context.sponsorAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Doc',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                      color: context.sponsorAccent),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() => sc.prereqs.removeAt(i));
                          setLocal(() {});
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.close, size: 16, color: AppTheme.errorColor),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Prerequisite name',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => setLocal(() => isRequired = !isRequired),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isRequired ? Icons.check_box : Icons.check_box_outline_blank,
                          size: 18,
                          color: isRequired ? context.ticketAccent : AppTheme.textSecondaryOf(context),
                        ),
                        const SizedBox(width: 2),
                        Text('Req', style: TextStyle(fontSize: 10,
                            color: AppTheme.textSecondaryOf(context))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => setLocal(() => requiresDocument = !requiresDocument),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          requiresDocument ? Icons.check_box : Icons.check_box_outline_blank,
                          size: 18,
                          color: requiresDocument ? context.sponsorAccent : AppTheme.textSecondaryOf(context),
                        ),
                        const SizedBox(width: 2),
                        Text('Doc', style: TextStyle(fontSize: 10,
                            color: AppTheme.textSecondaryOf(context))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    setState(() {
                      sc.prereqs.add(_EditLocalPrereq(
                        name: name,
                        description: descCtrl.text.trim(),
                        isRequired: isRequired,
                        requiresDocument: requiresDocument,
                      ));
                    });
                    nameCtrl.clear();
                    descCtrl.clear();
                    setLocal(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: context.ticketAccent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.add, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPrerequisiteSheet(_EditSponsorCategory sc) async {
    if (sc.id == null) return;
    final api = context.read<ApiService>();
    List<Map<String, dynamic>> prereqs = [];
    try {
      final data = await api.listPrerequisites(widget.eventId, sc.id!);
      prereqs = data.cast<Map<String, dynamic>>();
    } catch (_) {}
    if (!mounted) return;

    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isRequired = true;
    bool requiresDocument = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          maxChildSize: 0.85,
          minChildSize: 0.3,
          expand: false,
          builder: (_, scrollCtrl) => Padding(
            padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Prerequisites for "${sc.nameCtrl.text}"',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Expanded(
                  child: prereqs.isEmpty
                      ? Center(child: Text('No prerequisites yet', style: TextStyle(color: AppTheme.textSecondaryOf(ctx))))
                      : ListView.builder(
                          controller: scrollCtrl,
                          itemCount: prereqs.length,
                          itemBuilder: (_, i) {
                            final p = prereqs[i];
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                p['is_required'] == true ? Icons.check_circle : Icons.radio_button_unchecked,
                                size: 18,
                                color: p['is_required'] == true ? ctx.fundingAccent : AppTheme.textSecondaryOf(ctx),
                              ),
                              title: Text(p['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: p['description'] != null && (p['description'] as String).isNotEmpty
                                  ? Text(p['description'], style: const TextStyle(fontSize: 11))
                                  : null,
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.errorColor),
                                onPressed: () async {
                                  try {
                                    await api.deletePrerequisite(widget.eventId, sc.id!, p['id']);
                                    setSheetState(() => prereqs.removeAt(i));
                                  } catch (e) {
                                    if (ctx.mounted) AppToast.fromError(ctx, e, fallback: 'Failed to delete');
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
                const Divider(),
                Text('Add Prerequisite', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(ctx))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name *', isDense: true, hintText: 'e.g. Business License'),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description', isDense: true),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Checkbox(
                      value: isRequired,
                      onChanged: (v) => setSheetState(() => isRequired = v ?? true),
                      activeColor: ctx.fundingAccent,
                    ),
                    const Text('Required', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    Checkbox(
                      value: requiresDocument,
                      onChanged: (v) => setSheetState(() => requiresDocument = v ?? false),
                      activeColor: ctx.sponsorAccent,
                    ),
                    const Text('Doc', style: TextStyle(fontSize: 13)),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        try {
                          final resp = await api.createPrerequisite(
                            widget.eventId, sc.id!,
                            name: name,
                            description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                            isRequired: isRequired,
                            requiresDocument: requiresDocument,
                          );
                          setSheetState(() {
                            prereqs.add(resp);
                            nameCtrl.clear();
                            descCtrl.clear();
                            isRequired = true;
                            requiresDocument = false;
                          });
                        } catch (e) {
                          if (ctx.mounted) AppToast.fromError(ctx, e, fallback: 'Failed to add');
                        }
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add'),
                      style: ElevatedButton.styleFrom(backgroundColor: ctx.fundingAccent, foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ── Ticket Tiers (live CRUD) ──

  Future<void> _loadTiers() async {
    try {
      final api = context.read<ApiService>();
      final list = await api.getTicketTiers(widget.eventId);
      if (mounted) {
        setState(() {
          _tiers = list.map((j) {
            final t = _EditTier(id: j['id']);
            t.nameCtrl.text = j['name'] ?? '';
            t.priceCtrl.text = ((j['price_cents'] ?? 0) / 100).toStringAsFixed(2);
            t.descCtrl.text = j['description'] ?? '';
            return t;
          }).toList();
          _tiersLoaded = true;
          if (_tiers.isNotEmpty) _showTierSection = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _tiersLoaded = true);
    }
  }

  Future<void> _saveTier(_EditTier t) async {
    final name = t.nameCtrl.text.trim();
    if (name.isEmpty) return;
    final priceCents = ((double.tryParse(t.priceCtrl.text.trim()) ?? 0) * 100).toInt();
    final api = context.read<ApiService>();
    try {
      if (t.id != null) {
        await api.updateTicketTier(widget.eventId, t.id!, {
          'name': name,
          'price_cents': priceCents,
          if (t.descCtrl.text.trim().isNotEmpty) 'description': t.descCtrl.text.trim(),
        });
        if (mounted) AppToast.success(context, 'Tier updated');
      } else {
        final resp = await api.createTicketTier(widget.eventId, {
          'name': name,
          'price_cents': priceCents,
          'display_order': _tiers.indexOf(t),
          if (t.descCtrl.text.trim().isNotEmpty) 'description': t.descCtrl.text.trim(),
        });
        t.id = resp['id'] as int;
        if (mounted) AppToast.success(context, 'Tier created');
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to save tier');
      }
    }
  }

  Future<void> _deleteTier(int idx) async {
    final t = _tiers[idx];
    if (t.id != null) {
      try {
        final api = context.read<ApiService>();
        await api.deleteTicketTier(widget.eventId, t.id!);
      } catch (e) {
        if (mounted) {
          AppToast.fromError(context, e, fallback: 'Failed to delete tier');
        }
        return;
      }
    }
    setState(() => _tiers.removeAt(idx));
  }

  Widget _buildEditTierCard(int index) {
    final t = _tiers[index];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.feedAccent.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.feedAccent.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                t.id != null ? 'Tier #${t.id}' : 'New Tier',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.save, size: 18, color: context.feedAccent),
                onPressed: () => _saveTier(t),
                tooltip: 'Save',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.errorColor),
                onPressed: () => _deleteTier(index),
                tooltip: 'Delete',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: t.nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tier Name *',
                    hintText: 'e.g. VIP, General',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: t.priceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Price (\$) *',
                    prefixText: '\$ ',
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: t.descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'What this tier includes',
              isDense: true,
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // ── Sponsorship Categories (live CRUD) ──

  Future<void> _loadSponsorCategories() async {
    try {
      final api = context.read<ApiService>();
      final list = await api.getSponsorshipCategories(widget.eventId);
      if (mounted) {
        setState(() {
          _sponsorCategories = list.map((j) {
            final sc = _EditSponsorCategory(id: j['id']);
            sc.nameCtrl.text = j['name'] ?? '';
            sc.descCtrl.text = j['description'] ?? '';
            sc.spotsCtrl.text = (j['total_spots'] ?? 1).toString();
            sc.minBidCtrl.text =
                ((j['min_bid_cents'] ?? 0) / 100).toStringAsFixed(2);
            return sc;
          }).toList();
          _sponsorCategoriesLoaded = true;
          if (_sponsorCategories.isNotEmpty) _showSponsorshipSection = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _sponsorCategoriesLoaded = true);
    }
  }

  Future<void> _saveSponsorCategory(_EditSponsorCategory sc) async {
    final name = sc.nameCtrl.text.trim();
    if (name.isEmpty) return;
    final spots = int.tryParse(sc.spotsCtrl.text.trim()) ?? 1;
    final minBid =
        ((double.tryParse(sc.minBidCtrl.text.trim()) ?? 0) * 100).round();
    final api = context.read<ApiService>();
    try {
      if (sc.id != null) {
        await api.updateSponsorshipCategory(widget.eventId, sc.id!, {
          'name': name,
          'description': sc.descCtrl.text.trim(),
          'total_spots': spots,
          'min_bid_cents': minBid,
        });
        if (mounted) AppToast.success(context, 'Sponsorship updated');
      } else {
        final resp = await api.createSponsorshipCategory(widget.eventId, {
          'name': name,
          if (sc.descCtrl.text.trim().isNotEmpty)
            'description': sc.descCtrl.text.trim(),
          'total_spots': spots,
          'min_bid_cents': minBid,
          'sort_order': _sponsorCategories.indexOf(sc),
        });
        sc.id = resp['id'] as int;
        if (mounted) AppToast.success(context, 'Sponsorship created');
      }
      if (sc.id != null && sc.prereqs.isNotEmpty) {
        for (final p in sc.prereqs) {
          try {
            await api.createPrerequisite(widget.eventId, sc.id!,
                name: p.name, description: p.description, isRequired: p.isRequired, requiresDocument: p.requiresDocument);
          } catch (_) {}
        }
        setState(() => sc.prereqs.clear());
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to save sponsorship');
      }
    }
  }

  Future<void> _deleteSponsorCategory(int idx) async {
    final sc = _sponsorCategories[idx];
    if (sc.id != null) {
      try {
        final api = context.read<ApiService>();
        await api.deleteSponsorshipCategory(widget.eventId, sc.id!);
      } catch (e) {
        if (mounted) {
          AppToast.fromError(context, e,
              fallback: 'Failed to delete sponsorship');
        }
        return;
      }
    }
    setState(() => _sponsorCategories.removeAt(idx));
  }

  Future<void> _showTemplatePicker() async {
    final api = context.read<ApiService>();
    try {
      final data = await api.getSponsorCategoryTemplates();
      _sponsorTemplates = data.cast<Map<String, dynamic>>();
    } catch (_) {
      if (mounted) AppToast.error(context, 'Failed to load templates');
      return;
    }
    if (!mounted) return;
    final selected = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final chosen = <int>{};
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.5,
            maxChildSize: 0.85,
            minChildSize: 0.3,
            expand: false,
            builder: (_, scrollCtrl) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Copy from Template',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Select templates to copy as new sponsorships',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(ctx))),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _sponsorTemplates.isEmpty
                        ? Center(child: Text('No templates available', style: TextStyle(color: AppTheme.textSecondaryOf(ctx))))
                        : ListView.builder(
                            controller: scrollCtrl,
                            itemCount: _sponsorTemplates.length,
                            itemBuilder: (_, i) {
                              final t = _sponsorTemplates[i];
                              final id = t['id'] as int;
                              final isChosen = chosen.contains(id);
                              return CheckboxListTile(
                                value: isChosen,
                                onChanged: (v) => setSheetState(() {
                                  if (v == true) chosen.add(id); else chosen.remove(id);
                                }),
                                title: Text(t['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                subtitle: Text(
                                  '${t['total_spots'] ?? 0} spots · \$${((t['min_bid_cents'] ?? 0) / 100).toStringAsFixed(0)} min bid',
                                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(ctx)),
                                ),
                                dense: true,
                                activeColor: ctx.ticketAccent,
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: chosen.isEmpty ? null : () => Navigator.pop(ctx, chosen.toList()),
                    style: ElevatedButton.styleFrom(backgroundColor: ctx.ticketAccent, foregroundColor: Colors.white),
                    child: Text('Add ${chosen.length} sponsorship${chosen.length == 1 ? '' : 's'}'),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
    if (selected == null || selected.isEmpty) return;
    for (final templateId in selected) {
      final t = _sponsorTemplates.firstWhere((t) => t['id'] == templateId);
      final sc = _EditSponsorCategory();
      sc.nameCtrl.text = t['name'] ?? '';
      sc.descCtrl.text = (t['description'] as String?) ?? '';
      sc.spotsCtrl.text = '${t['total_spots'] ?? 1}';
      sc.minBidCtrl.text = ((t['min_bid_cents'] ?? 0) / 100).toStringAsFixed(2);
      setState(() => _sponsorCategories.add(sc));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final fundingGoal = double.tryParse(_fundingGoalCtrl.text);
    final minPledge = double.tryParse(_minPledgeCtrl.text) ?? 5.0;

    final data = <String, dynamic>{
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'max_capacity': int.parse(_capacityCtrl.text),
      'registration_type': _registrationType,
      'min_pledge_cents': (minPledge * 100).toInt(),
      'max_reserved_spots_per_user': int.tryParse(_maxReservedSpotsCtrl.text) ?? 0,
      'genre': _genre,
      'posts_enabled': _postsEnabled,
      if (_event?.status.name == 'draft') 'community_rules': _communityRules,
    };

    if (_startTime != null) {
      data['start_time'] = _startTime!.toUtc().toIso8601String();
    }
    if (_endTime != null) {
      data['end_time'] = _endTime!.toUtc().toIso8601String();
    }
    if (_fundingEndAt != null) {
      data['funding_end_at'] = _fundingEndAt!.toUtc().toIso8601String();
      data['refund_deadline_days'] = _refundDeadlineDays;
    }

    if (fundingGoal != null && fundingGoal > 0) {
      data['funding_goal_cents'] = (fundingGoal * 100).toInt();
    }
    if (_selectedStrategyId != null) {
      data['ticket_strategy_id'] = _selectedStrategyId;
    }
    if (_selectedVenueId != null && _selectedVenueId != _event?.venueId) {
      data['venue_id'] = _selectedVenueId;
    }

    // Transport info (always send — empty string clears)
    data['parking_info'] = _parkingCtrl.text.trim().isEmpty ? null : _parkingCtrl.text.trim();
    data['transit_info'] = _transitCtrl.text.trim().isEmpty ? null : _transitCtrl.text.trim();
    data['rideshare_info'] = _rideshareCtrl.text.trim().isEmpty ? null : _rideshareCtrl.text.trim();
    data['accessibility_info'] = _accessibilityCtrl.text.trim().isEmpty ? null : _accessibilityCtrl.text.trim();
    data['has_schedule'] = _hasSchedule;

    try {
      final api = context.read<ApiService>();
      final updated = await api.updateEvent(widget.eventId, data);
      if (mounted) {
        final newStatus = updated['status'];
        context.read<EventProvider>().loadEvent(widget.eventId);
        if (newStatus == 'pending_approval') {
          AppToast.success(context, 'Event updated! It now needs admin approval before going live again.');
        } else {
          AppToast.success(context, 'Event updated!');
        }
        context.go('/events/${widget.eventId}');
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Update failed');
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _capacityCtrl.dispose();
    _fundingGoalCtrl.dispose();
    _minPledgeCtrl.dispose();
    _maxReservedSpotsCtrl.dispose();
    _parkingCtrl.dispose();
    _transitCtrl.dispose();
    _rideshareCtrl.dispose();
    _accessibilityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('Edit Event'),
      ),
      body: _loadingEvent
          ? const Center(child: CircularProgressIndicator())
          : _event == null
              ? const Center(child: Text('Event not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Warning for live/approved events
                            if (_event!.status == EventStatus.approved ||
                                _event!.status == EventStatus.live) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.warningColor
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppTheme.warningColor
                                          .withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber,
                                        color: AppTheme.warningColor),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'This event is currently ${_event!.status.name}. Editing will require admin approval before it goes live again.',
                                        style: TextStyle(
                                            color: AppTheme.textPrimaryOf(context),
                                            fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            TextFormField(
                              controller: _titleCtrl,
                              decoration:
                                  const InputDecoration(labelText: 'Event Title'),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descCtrl,
                              decoration:
                                  const InputDecoration(labelText: 'Description'),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 16),

                            // ─── Date pickers ───
                            Text('Event Dates',
                                style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 8),
                            _datePickerTile(
                              label: 'Event Start Date',
                              value: _startTime,
                              onPick: () => _pickDateTime(
                                  initial: _startTime,
                                  onPicked: (dt) =>
                                      setState(() => _startTime = dt)),
                              onClear: () =>
                                  setState(() => _startTime = null),
                            ),
                            const SizedBox(height: 8),
                            _datePickerTile(
                              label: 'Event End Date',
                              value: _endTime,
                              onPick: () => _pickDateTime(
                                  initial: _endTime ?? _startTime,
                                  onPicked: (dt) =>
                                      setState(() => _endTime = dt)),
                              onClear: () =>
                                  setState(() => _endTime = null),
                            ),
                            const SizedBox(height: 8),
                            _datePickerTile(
                              label: 'Funding Deadline',
                              value: _fundingEndAt,
                              onPick: () => _pickDateTime(
                                  initial: _fundingEndAt,
                                  onPicked: (dt) =>
                                      setState(() => _fundingEndAt = dt)),
                              onClear: () =>
                                  setState(() => _fundingEndAt = null),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'At least one of Event Start Date or Funding Deadline must be set.',
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                            ),
                            const SizedBox(height: 16),

                            // ─── Event Schedule (collapsible, live CRUD) ───
                            if (_startTime != null &&
                                _endTime != null &&
                                _event != null) ...[
                              GestureDetector(
                                onTap: () => setState(() =>
                                    _showScheduleSection =
                                        !_showScheduleSection),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _showScheduleSection
                                        ? context.feedAccent.withValues(alpha: 0.08)
                                        : AppTheme.surfaceOf(context),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _showScheduleSection
                                          ? context.feedAccent.withValues(alpha: 0.3)
                                          : AppTheme.dividerOf(context),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_month_rounded,
                                          size: 18,
                                          color: _showScheduleSection
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
                                      if (_scheduleItems.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: context.feedAccent.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text('${_scheduleItems.length}',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: context.feedAccent)),
                                        ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        _showScheduleSection
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
                                    border: Border.all(
                                        color: AppTheme.dividerOf(context)),
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
                                            value: _hasSchedule,
                                            onChanged: (v) => setState(() => _hasSchedule = v),
                                          ),
                                        ],
                                      ),
                                      if (_hasSchedule) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'Add time slots for your event. Save each item individually.',
                                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                                        ),
                                        const SizedBox(height: 12),
                                        ..._scheduleItems.asMap().entries.map((entry) {
                                          final idx = entry.key;
                                          final si = entry.value;
                                          final dateLabel = si.date != null
                                              ? '${si.date!.month}/${si.date!.day}/${si.date!.year}'
                                              : 'Select date';
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 10),
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                  color: AppTheme.dividerOf(context)),
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
                                                          initialDate: si.date ?? _startTime!,
                                                          firstDate: _startTime!,
                                                          lastDate: _endTime!,
                                                        );
                                                        if (picked != null) {
                                                          setState(() => si.date = picked);
                                                        }
                                                      },
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(
                                                            horizontal: 10, vertical: 6),
                                                        decoration: BoxDecoration(
                                                          color: context.feedAccent.withValues(alpha: 0.08),
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
                                                      onPressed: () => _saveScheduleItem(si),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      tooltip: 'Save',
                                                    ),
                                                    const SizedBox(width: 8),
                                                    IconButton(
                                                      icon: Icon(Icons.delete_outline,
                                                          size: 18, color: AppTheme.errorColor),
                                                      onPressed: () => _deleteScheduleItem(idx),
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
                                                                  color: AppTheme.textPrimaryOf(context))),
                                                        ),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                                    child: Text('–',
                                                        style: TextStyle(color: AppTheme.textSecondaryOf(context))),
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
                                                                  color: AppTheme.textPrimaryOf(context))),
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
                                              ],
                                            ),
                                          );
                                        }),
                                        GestureDetector(
                                          onTap: () => setState(
                                              () => _scheduleItems.add(_EditScheduleItem())),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: AppTheme.dividerOf(context),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.add_rounded,
                                                    size: 18, color: AppTheme.textSecondaryOf(context)),
                                                const SizedBox(width: 6),
                                                Text('Add Schedule Item',
                                                    style: TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 13,
                                                        color: AppTheme.textSecondaryOf(context))),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                crossFadeState: _showScheduleSection
                                    ? CrossFadeState.showSecond
                                    : CrossFadeState.showFirst,
                                duration: const Duration(milliseconds: 250),
                              ),
                              const SizedBox(height: 16),
                            ],

                            TextFormField(
                              controller: _capacityCtrl,
                              decoration:
                                  const InputDecoration(labelText: 'Max Capacity'),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (int.tryParse(v) == null) {
                                  return 'Enter a number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            DropdownButtonFormField<String>(
                              value: _registrationType,
                              decoration: const InputDecoration(
                                  labelText: 'Registration Type'),
                              items: const [
                                DropdownMenuItem(
                                    value: 'open', child: Text('Open')),
                                DropdownMenuItem(
                                    value: 'closed',
                                    child: Text('Closed (Waitlist)')),
                              ],
                              onChanged: (v) => setState(
                                  () => _registrationType = v ?? 'open'),
                            ),
                            const SizedBox(height: 16),

                            // Genre
                            DropdownButtonFormField<String>(
                              value: _genre,
                              decoration: const InputDecoration(
                                  labelText: 'Genre / Category *'),
                              items: _genres
                                  .map((g) => DropdownMenuItem(
                                        value: g,
                                        child: Text(g[0].toUpperCase() +
                                            g.substring(1)),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() => _genre = v),
                              validator: (v) =>
                                  v == null ? 'Please select a genre' : null,
                            ),
                            const SizedBox(height: 16),

                            // Venue dropdown (searchable)
                            if (_venues.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              SearchableDropdown<Venue>(
                                label: 'Venue',
                                hint: 'Search venues…',
                                items: _venues,
                                selectedItem: _venues.where((v) => v.id == _selectedVenueId).firstOrNull,
                                itemLabel: (v) => v.name,
                                itemSubtitle: (v) => 'Capacity: ${v.maxCapacity}',
                                filter: (v, q) => v.name.toLowerCase().contains(q.toLowerCase()),
                                onSelected: (v) => setState(() => _selectedVenueId = v?.id),
                              ),
                            ],

                            // Community Rules toggle — only in draft
                            if (_event?.status.name == 'draft')
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Community Event Rules'),
                                subtitle: Text(
                                  _communityRulesFeatureEnabled
                                      ? 'Apply platform community rules (e.g. max ticket price, capacity limits)'
                                      : 'Community rules are currently disabled by the platform',
                                ),
                                value: _communityRules,
                                onChanged: _communityRulesFeatureEnabled
                                    ? (v) => setState(() => _communityRules = v)
                                    : null,
                              ),
                            if (_event?.status.name == 'draft')
                              const SizedBox(height: 16),

                            // Funding
                            Text('Funding',
                                style:
                                    Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _fundingGoalCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Funding Goal (\$)',
                                prefixText: '\$ ',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _minPledgeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Minimum Pledge (\$)',
                                prefixText: '\$ ',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _maxReservedSpotsCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Max Reserved Spots Per User',
                                helperText: 'How many ticket spots each pledger can reserve (0 = disabled)',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),

                            // ─── Ticket Strategy (searchable) ───
                            Text('Ticket Strategy',
                                style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 8),
                            SearchableDropdown<TicketStrategy>(
                              label: 'Ticket Strategy',
                              hint: 'Search strategies…',
                              items: _strategies,
                              selectedItem: _strategies.where((s) => s.id == _selectedStrategyId).firstOrNull,
                              itemLabel: (s) => s.name,
                              itemSubtitle: (s) => s.tiersSummary,
                              filter: (s, q) => s.name.toLowerCase().contains(q.toLowerCase()),
                              onSelected: (s) => setState(() => _selectedStrategyId = s?.id),
                            ),
                            const SizedBox(height: 16),

                            // ─── Ticket Tiers (collapsible, live CRUD) ───
                            GestureDetector(
                              onTap: () => setState(() => _showTierSection = !_showTierSection),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: _showTierSection
                                      ? context.feedAccent.withValues(alpha: 0.08)
                                      : AppTheme.surfaceOf(context),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _showTierSection
                                        ? context.feedAccent.withValues(alpha: 0.3)
                                        : AppTheme.dividerOf(context),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.layers_rounded, size: 18,
                                        color: _showTierSection ? context.feedAccent : AppTheme.textSecondaryOf(context)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text('Ticket Tiers',
                                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                                              color: AppTheme.textPrimaryOf(context))),
                                    ),
                                    if (_tiers.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: context.feedAccent.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text('${_tiers.length}',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.feedAccent)),
                                      ),
                                    const SizedBox(width: 4),
                                    Icon(_showTierSection ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                        color: AppTheme.textSecondaryOf(context)),
                                  ],
                                ),
                              ),
                            ),
                            AnimatedCrossFade(
                              firstChild: const SizedBox.shrink(),
                              secondChild: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (!_tiersLoaded)
                                      const Center(child: Padding(
                                        padding: EdgeInsets.all(16),
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ))
                                    else ...[
                                      ...List.generate(_tiers.length, (i) => Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: _buildEditTierCard(i),
                                      )),
                                      OutlinedButton.icon(
                                        onPressed: () => setState(() => _tiers.add(_EditTier())),
                                        icon: const Icon(Icons.add, size: 18),
                                        label: const Text('Add Tier'),
                                        style: OutlinedButton.styleFrom(foregroundColor: context.feedAccent),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              crossFadeState: _showTierSection ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                              duration: const Duration(milliseconds: 250),
                            ),
                            const SizedBox(height: 16),

                            // ─── Funding Milestones (collapsible, live CRUD) ───
                            if (_fundingEndAt != null &&
                                _event != null &&
                                ['draft', 'pending_approval', 'approved']
                                    .contains(_event!.status.name)) ...[
                              GestureDetector(
                                onTap: () => setState(() =>
                                    _showMilestoneSection =
                                        !_showMilestoneSection),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _showMilestoneSection
                                        ? context.photoAccent.withValues(alpha: 0.08)
                                        : AppTheme.surfaceOf(context),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _showMilestoneSection
                                          ? context.photoAccent
                                              .withValues(alpha: 0.3)
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
                                            color: context.photoAccent
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text('${_milestones.length}',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: context.photoAccent)),
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
                                    color: AppTheme.surfaceOf(context),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: AppTheme.dividerOf(context)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Define milestones that unlock as your event reaches funding goals.',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondaryOf(context)),
                                      ),
                                      const SizedBox(height: 12),
                                      ..._milestones
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                        final idx = entry.key;
                                        final ms = entry.value;
                                        return Container(
                                          margin: const EdgeInsets.only(
                                              bottom: 12),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                                color: AppTheme.dividerOf(context)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                      'Milestone ${idx + 1}',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 13)),
                                                  const Spacer(),
                                                  IconButton(
                                                    icon: Icon(
                                                        Icons.save_rounded,
                                                        size: 18,
                                                        color: AppTheme
                                                            .successColor),
                                                    onPressed: () =>
                                                        _saveMilestone(ms),
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                    tooltip: 'Save',
                                                  ),
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    icon: Icon(
                                                        Icons.delete_outline,
                                                        size: 18,
                                                        color:
                                                            AppTheme.errorColor),
                                                    onPressed: () =>
                                                        _deleteMilestone(idx),
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                    tooltip: 'Delete',
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              TextFormField(
                                                controller: ms.titleCtrl,
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: 'Title',
                                                  hintText:
                                                      'e.g. DJ Sound System Upgrade',
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
                                                      value: ms.unlockPercent
                                                          .toDouble(),
                                                      min: 1,
                                                      max: 100,
                                                      divisions: 99,
                                                      label:
                                                          '${ms.unlockPercent}%',
                                                      onChanged: (v) =>
                                                          setState(() =>
                                                              ms.unlockPercent =
                                                                  v.round()),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 42,
                                                    child: Text(
                                                        '${ms.unlockPercent}%',
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 13),
                                                        textAlign:
                                                            TextAlign.right),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              TextFormField(
                                                controller: ms.benefitCtrl,
                                                decoration:
                                                    const InputDecoration(
                                                  labelText:
                                                      'Benefit Description',
                                                  hintText:
                                                      'e.g. Premium sound system for all attendees',
                                                  isDense: true,
                                                ),
                                                maxLines: 2,
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                      GestureDetector(
                                        onTap: () => setState(() =>
                                            _milestones
                                                .add(_EditMilestone())),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: AppTheme.dividerOf(context),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.add_rounded,
                                                  size: 18,
                                                  color: AppTheme.textSecondaryOf(context)),
                                              const SizedBox(width: 6),
                                              Text('Add Milestone',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
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
                                crossFadeState: _showMilestoneSection
                                    ? CrossFadeState.showSecond
                                    : CrossFadeState.showFirst,
                                duration: const Duration(milliseconds: 250),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // ═══════════════════════════════════════
                            // Sponsorship Categories (collapsible, live CRUD)
                            // ═══════════════════════════════════════
                            GestureDetector(
                              onTap: () => setState(() =>
                                  _showSponsorshipSection =
                                      !_showSponsorshipSection),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: _showSponsorshipSection
                                      ? context.ticketAccent.withValues(alpha: 0.08)
                                      : AppTheme.surfaceOf(context),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _showSponsorshipSection
                                        ? context.ticketAccent.withValues(alpha: 0.3)
                                        : AppTheme.dividerOf(context),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.storefront_rounded,
                                        size: 18,
                                        color: _showSponsorshipSection
                                            ? context.ticketAccent
                                            : AppTheme.textSecondaryOf(context)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Sponsorships (Optional)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppTheme.textPrimaryOf(context),
                                        ),
                                      ),
                                    ),
                                    if (_sponsorCategories.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: context.ticketAccent
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${_sponsorCategories.length}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: context.ticketAccent),
                                        ),
                                      ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      _showSponsorshipSection
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
                                  border: Border.all(
                                      color:
                                          AppTheme.dividerOf(context)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!_sponsorCategoriesLoaded)
                                      const Center(
                                          child: Padding(
                                        padding: EdgeInsets.all(16),
                                        child: CircularProgressIndicator(),
                                      ))
                                    else ...[
                                      for (int i = 0;
                                          i < _sponsorCategories.length;
                                          i++) ...[
                                        _buildEditSponsorCategoryCard(i),
                                        if (i < _sponsorCategories.length - 1)
                                          const SizedBox(height: 10),
                                      ],
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () => setState(() => _sponsorCategories.add(_EditSponsorCategory())),
                                              icon: const Icon(Icons.add, size: 18),
                                              label: const Text('Add Sponsorship'),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: _showTemplatePicker,
                                              icon: const Icon(Icons.copy_rounded, size: 18),
                                              label: const Text('From Template'),
                                              style: OutlinedButton.styleFrom(foregroundColor: context.ticketAccent),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              crossFadeState: _showSponsorshipSection
                                  ? CrossFadeState.showSecond
                                  : CrossFadeState.showFirst,
                              duration: const Duration(milliseconds: 250),
                            ),
                            const SizedBox(height: 16),

                            // Posts toggle
                            SwitchListTile(
                              title: const Text('Enable event feed / posts',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: const Text(
                                  'Registered users can post on the event wall'),
                              value: _postsEnabled,
                              activeColor: AppTheme.primaryColor,
                              onChanged: (v) =>
                                  setState(() => _postsEnabled = v),
                              contentPadding: EdgeInsets.zero,
                            ),
                            // Refund deadline — only when funding deadline is set
                            if (_fundingEndAt != null) ...[
                              const SizedBox(height: 16),
                              Builder(builder: (context) {
                                final fundDuration = _fundingEndAt!
                                    .difference(DateTime.now())
                                    .inDays;
                                final maxDays =
                                    (fundDuration * 0.2).ceil().clamp(1, 365);
                                if (_refundDeadlineDays > maxDays) {
                                  _refundDeadlineDays = maxDays;
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Refund Deadline: $_refundDeadlineDays day${_refundDeadlineDays == 1 ? '' : 's'} before funding ends',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Max $maxDays days (20% of funding duration). Customers can get a refund if they unregister before this cutoff.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondaryOf(context),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Slider(
                                      value: _refundDeadlineDays
                                          .toDouble()
                                          .clamp(0, maxDays.toDouble()),
                                      min: 0,
                                      max: maxDays.toDouble(),
                                      divisions: maxDays > 0 ? maxDays : 1,
                                      label: '$_refundDeadlineDays days',
                                      activeColor: AppTheme.primaryColor,
                                      onChanged: (v) {
                                        setState(() {
                                          _refundDeadlineDays = v.round();
                                        });
                                      },
                                    ),
                                  ],
                                );
                              }),
                            ],

                            const SizedBox(height: 16),

                            // ─── Parking & Transport (collapsible) ───
                            GestureDetector(
                              onTap: () => setState(() => _showTransportSection = !_showTransportSection),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: _showTransportSection
                                      ? AppTheme.primaryColor.withValues(alpha: 0.05)
                                      : AppTheme.surfaceOf(context),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _showTransportSection
                                        ? AppTheme.primaryColor.withValues(alpha: 0.2)
                                        : AppTheme.dividerOf(context),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.directions_car_rounded,
                                        size: 18,
                                        color: _showTransportSection
                                            ? AppTheme.primaryColor
                                            : AppTheme.textSecondaryOf(context)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Parking & Transport Info',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppTheme.textPrimaryOf(context),
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      _showTransportSection
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
                                    TextFormField(
                                      controller: _parkingCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Parking',
                                        hintText: 'e.g. Free parking lot behind the venue',
                                        prefixIcon: Icon(Icons.local_parking_rounded, size: 20),
                                        isDense: true,
                                      ),
                                      maxLines: 2,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _transitCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Public Transit',
                                        hintText: 'e.g. Take the Blue Line to Central Station',
                                        prefixIcon: Icon(Icons.directions_transit_rounded, size: 20),
                                        isDense: true,
                                      ),
                                      maxLines: 2,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _rideshareCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Rideshare / Taxi',
                                        hintText: 'e.g. Drop-off at Gate 3 entrance',
                                        prefixIcon: Icon(Icons.local_taxi_rounded, size: 20),
                                        isDense: true,
                                      ),
                                      maxLines: 2,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _accessibilityCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Accessibility',
                                        hintText: 'e.g. Wheelchair ramp at main entrance',
                                        prefixIcon: Icon(Icons.accessible_rounded, size: 20),
                                        isDense: true,
                                      ),
                                      maxLines: 2,
                                    ),
                                  ],
                                ),
                              ),
                              crossFadeState: _showTransportSection
                                  ? CrossFadeState.showSecond
                                  : CrossFadeState.showFirst,
                              duration: const Duration(milliseconds: 250),
                            ),

                            const SizedBox(height: 24),

                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Text('Save Changes'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _datePickerTile({
    required String label,
    required DateTime? value,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onPick,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
              ),
              child: Text(
                value != null
                    ? DateFormat('MMM d, y  h:mm a').format(value)
                    : 'Not set',
                style: TextStyle(
                  color: value != null ? AppTheme.textPrimaryOf(context) : AppTheme.textSecondaryOf(context),
                ),
              ),
            ),
          ),
        ),
        if (value != null)
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.clear, size: 20),
          ),
      ],
    );
  }

  Future<void> _pickDateTime({
    DateTime? initial,
    required void Function(DateTime) onPicked,
  }) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: initial != null
          ? TimeOfDay.fromDateTime(initial)
          : TimeOfDay.now(),
    );
    if (time == null || !mounted) return;
    onPicked(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }
}
