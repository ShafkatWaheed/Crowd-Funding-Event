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
    });
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
        _loadingEvent = false;
      });
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to load event');
        setState(() => _loadingEvent = false);
      }
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
                                            color: Colors.grey[800],
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
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 16),

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
                              _SearchableDropdown<Venue>(
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
                                subtitle: const Text(
                                  'Apply platform community rules (e.g. max ticket price, capacity limits)',
                                ),
                                value: _communityRules,
                                onChanged: (v) =>
                                    setState(() => _communityRules = v),
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
                            _SearchableDropdown<TicketStrategy>(
                              label: 'Ticket Strategy',
                              hint: 'Search strategies…',
                              items: _strategies,
                              selectedItem: _strategies.where((s) => s.id == _selectedStrategyId).firstOrNull,
                              itemLabel: (s) => s.name,
                              itemSubtitle: (s) => s.tiersSummary,
                              filter: (s, q) => s.name.toLowerCase().contains(q.toLowerCase()),
                              onSelected: (s) => setState(() => _selectedStrategyId = s?.id),
                            ),
                            if (_selectedStrategyId != null) ...[
                              const SizedBox(height: 6),
                              Builder(builder: (context) {
                                final s = _strategies.where((s) => s.id == _selectedStrategyId).firstOrNull;
                                if (s == null) return const SizedBox.shrink();
                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ...s.tiers.map((t) => Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(width: 7, height: 7,
                                                    decoration: BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle)),
                                                  const SizedBox(width: 8),
                                                  Expanded(child: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                                                  Text(t.priceFormatted,
                                                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.successColor)),
                                                ],
                                              ),
                                              if (t.description != null && t.description!.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(left: 15, top: 2),
                                                  child: Text(t.description!,
                                                      style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                                                ),
                                            ],
                                          ),
                                        )),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
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
                                        color: Colors.grey[600],
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
                  color: value != null ? Colors.black87 : Colors.grey,
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


// ═══════════════════════════════════════════
// Searchable Dropdown Widget
// ═══════════════════════════════════════════

class _SearchableDropdown<T> extends StatefulWidget {
  final String label;
  final String hint;
  final List<T> items;
  final T? selectedItem;
  final String Function(T) itemLabel;
  final String Function(T)? itemSubtitle;
  final bool Function(T, String) filter;
  final ValueChanged<T?> onSelected;
  final String? Function(T?)? validator;

  const _SearchableDropdown({
    super.key,
    required this.label,
    required this.hint,
    required this.items,
    this.selectedItem,
    required this.itemLabel,
    this.itemSubtitle,
    required this.filter,
    required this.onSelected,
    this.validator,
  });

  @override
  State<_SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<_SearchableDropdown<T>> {
  late TextEditingController _controller;
  final _focusNode = FocusNode();
  bool _isOpen = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.selectedItem != null
          ? widget.itemLabel(widget.selectedItem as T)
          : '',
    );
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() => _isOpen = true);
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      } else {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _isOpen = false);
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant _SearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedItem != oldWidget.selectedItem) {
      _controller.text = widget.selectedItem != null
          ? widget.itemLabel(widget.selectedItem as T)
          : '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<T> get _filteredItems {
    if (_query.isEmpty) return widget.items;
    return widget.items.where((item) => widget.filter(item, _query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      validator: (_) => widget.validator?.call(widget.selectedItem),
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: widget.hint,
                suffixIcon: widget.selectedItem != null
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _controller.clear();
                          widget.onSelected(null);
                          setState(() => _query = '');
                        },
                      )
                    : const Icon(Icons.arrow_drop_down),
                errorText: state.errorText,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            if (_isOpen && _filteredItems.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _filteredItems.length,
                  itemBuilder: (ctx, i) {
                    final item = _filteredItems[i];
                    final isSelected = widget.selectedItem != null &&
                        widget.itemLabel(widget.selectedItem as T) ==
                            widget.itemLabel(item);
                    return ListTile(
                      dense: true,
                      selected: isSelected,
                      title: Text(widget.itemLabel(item),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: widget.itemSubtitle != null
                          ? Text(widget.itemSubtitle!(item),
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[600]))
                          : null,
                      trailing: isSelected
                          ? Icon(Icons.check_circle,
                              size: 18, color: Theme.of(context).primaryColor)
                          : null,
                      onTap: () {
                        widget.onSelected(item);
                        _controller.text = widget.itemLabel(item);
                        _focusNode.unfocus();
                        setState(() {
                          _query = '';
                          _isOpen = false;
                        });
                      },
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
