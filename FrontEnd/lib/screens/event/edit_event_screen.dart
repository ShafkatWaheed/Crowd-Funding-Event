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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load event: $e')),
        );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Event updated! It now needs admin approval before going live again.'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event updated!')),
          );
        }
        context.go('/events/${widget.eventId}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
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

                            // Venue dropdown
                            if (_venues.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              DropdownButtonFormField<int>(
                                value: _venues.any((v) => v.id == _selectedVenueId)
                                    ? _selectedVenueId
                                    : null,
                                decoration:
                                    const InputDecoration(labelText: 'Venue'),
                                items: _venues
                                    .map((v) => DropdownMenuItem(
                                        value: v.id, child: Text(v.name)))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedVenueId = v),
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
                            const SizedBox(height: 16),

                            // ─── Ticket Strategy ───
                            Text('Ticket Strategy',
                                style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<int>(
                              value: _selectedStrategyId,
                              decoration: const InputDecoration(
                                labelText: 'Ticket Strategy',
                                hintText: 'Select a strategy',
                              ),
                              items: _strategies.map((s) => DropdownMenuItem(
                                value: s.id,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    Text(s.tiersSummary,
                                        style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                  ],
                                ),
                              )).toList(),
                              onChanged: (v) => setState(() => _selectedStrategyId = v),
                            ),
                            if (_selectedStrategyId != null) ...[
                              const SizedBox(height: 6),
                              Builder(builder: (context) {
                                final s = _strategies.where((s) => s.id == _selectedStrategyId).firstOrNull;
                                if (s == null) return const SizedBox.shrink();
                                final totalQty = s.tiers.fold<int>(0, (sum, t) => sum + t.quantity);
                                final hasUnlimited = s.tiers.any((t) => t.quantity == 0);
                                final maxCap = int.tryParse(_capacityCtrl.text) ?? 0;
                                final shortfall = maxCap > 0 && !hasUnlimited && totalQty < maxCap
                                    ? maxCap - totalQty : 0;
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
                                                  if (t.quantity > 0)
                                                    Text('  (${t.quantity})', style: TextStyle(fontSize: 11, color: Colors.grey[500]))
                                                  else
                                                    Text('  (unlimited)', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
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
                                        const Divider(height: 10),
                                        Row(
                                          children: [
                                            Icon(
                                              shortfall > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                                              size: 14,
                                              color: shortfall > 0 ? AppTheme.warningColor : AppTheme.successColor,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                hasUnlimited
                                                    ? 'Total tickets: unlimited'
                                                    : shortfall > 0
                                                        ? 'Total: $totalQty — need $shortfall more for capacity ($maxCap)'
                                                        : 'Total: $totalQty (covers capacity $maxCap)',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: shortfall > 0 ? AppTheme.warningColor : AppTheme.successColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
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
