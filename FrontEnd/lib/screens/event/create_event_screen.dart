import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/venue.dart';
import '../../models/ticket_strategy.dart';
import '../../providers/event_provider.dart';
import '../../services/api_service.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _fundingGoalCtrl = TextEditingController();
  final _minPledgeCtrl = TextEditingController(text: '5.00');

  List<Venue> _venues = [];
  int? _selectedVenueId;
  DateTime? _startTime;
  DateTime? _endTime;
  DateTime? _fundingEndAt;
  String _registrationType = 'open';
  String? _genre;
  bool _postsEnabled = true;
  int _refundDeadlineDays = 7;
  bool _publish = true; // true = Publish Now, false = Save as Draft
  bool _isLoading = false;

  final List<String> _genres = [
    'community', 'music', 'tech', 'sports', 'arts',
    'food', 'charity', 'education', 'business', 'other',
  ];

  // Inline venue creation
  bool _showVenueForm = false;
  bool _creatingVenue = false;
  final _venueNameCtrl = TextEditingController();
  final _venueAddressCtrl = TextEditingController();
  final _venueCityCtrl = TextEditingController();
  final _venueProvinceCtrl = TextEditingController();
  final _venueCapacityCtrl = TextEditingController();

  // Ticket strategy
  List<TicketStrategy> _strategies = [];
  int? _selectedStrategyId;
  bool _showStrategyForm = false;
  bool _creatingStrategy = false;
  final _strategyNameCtrl = TextEditingController();
  final List<_StrategyTierInput> _strategyTiers = [_StrategyTierInput()];

  @override
  void initState() {
    super.initState();
    _loadVenues();
    _loadStrategies();
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

  Future<DateTime?> _pickDateTimeGeneric({DateTime? initial}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: initial != null
          ? TimeOfDay.fromDateTime(initial)
          : const TimeOfDay(hour: 18, minute: 0),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickDateTime(bool isStart) async {
    final dt = await _pickDateTimeGeneric(
        initial: isStart ? _startTime : _endTime);
    if (dt == null) return;
    setState(() {
      if (isStart) {
        _startTime = dt;
      } else {
        _endTime = dt;
      }
    });
  }

  Future<void> _pickFundingDeadline() async {
    final dt = await _pickDateTimeGeneric(initial: _fundingEndAt);
    if (dt == null) return;
    setState(() => _fundingEndAt = dt);
  }

  Future<void> _submit() async {
    // ── Date check first (before form validation) ──
    if (_startTime == null && _fundingEndAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Set at least one of: Event Date or Funding Deadline')),
      );
      return;
    }

    // If start_time set, end_time must also be set
    if (_startTime != null && _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('End time is required when start time is set')),
      );
      return;
    }

    // Event start must be after funding deadline
    if (_startTime != null &&
        _fundingEndAt != null &&
        !_startTime!.isAfter(_fundingEndAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Event start time must be after the funding deadline')),
      );
      return;
    }

    // If no funding, ticket strategy is required
    if (_fundingEndAt == null && _selectedStrategyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Ticket strategy is required when no funding deadline is set')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (_selectedVenueId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a venue')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final fundingGoal = double.tryParse(_fundingGoalCtrl.text);
    final minPledge = double.tryParse(_minPledgeCtrl.text) ?? 5.0;

    final data = <String, dynamic>{
      'venue_id': _selectedVenueId,
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'max_capacity': int.parse(_capacityCtrl.text),
      'registration_type': _registrationType,
      'min_pledge_cents': (minPledge * 100).toInt(),
      'genre': _genre,
      'posts_enabled': _postsEnabled,
      'publish': _publish,
    };

    if (_startTime != null) {
      data['start_time'] = _startTime!.toUtc().toIso8601String();
    }
    if (_endTime != null) {
      data['end_time'] = _endTime!.toUtc().toIso8601String();
    }

    if (_fundingEndAt != null) {
      data['funding_end_at'] = _fundingEndAt!.toUtc().toIso8601String();
      if (_refundDeadlineDays > 0) {
        data['refund_deadline_days'] = _refundDeadlineDays;
      }
    }

    if (fundingGoal != null && fundingGoal > 0) {
      data['funding_goal_cents'] = (fundingGoal * 100).toInt();
    }
    if (_selectedStrategyId != null) {
      data['ticket_strategy_id'] = _selectedStrategyId;
    }

    final selectedVenue = _venues.where((v) => v.id == _selectedVenueId).firstOrNull;
    if (selectedVenue != null) {
      data['lat'] = selectedVenue.lat;
      data['lng'] = selectedVenue.lng;
    }

    final success =
        await context.read<EventProvider>().createEvent(data);

    setState(() => _isLoading = false);

    if (success && mounted) {
      context.go('/');
    }
  }

  Future<void> _createVenueInline() async {
    if (_venueNameCtrl.text.trim().isEmpty ||
        _venueAddressCtrl.text.trim().isEmpty ||
        _venueCityCtrl.text.trim().isEmpty ||
        _venueCapacityCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all venue fields')),
      );
      return;
    }

    setState(() => _creatingVenue = true);

    try {
      final api = context.read<ApiService>();
      final resp = await api.createVenue({
        'name': _venueNameCtrl.text.trim(),
        'address': _venueAddressCtrl.text.trim(),
        'city': _venueCityCtrl.text.trim(),
        'province': _venueProvinceCtrl.text.trim(),
        'max_capacity': int.parse(_venueCapacityCtrl.text.trim()),
      });

      // Reload venues and auto-select the new one
      await _loadVenues();
      final newId = resp['id'] as int?;
      setState(() {
        _selectedVenueId = newId;
        _showVenueForm = false;
        _venueNameCtrl.clear();
        _venueAddressCtrl.clear();
        _venueCityCtrl.clear();
        _venueProvinceCtrl.clear();
        _venueCapacityCtrl.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Venue created and selected!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create venue: $e')),
        );
      }
    }

    setState(() => _creatingVenue = false);
  }

  void _addStrategyTier() => setState(() => _strategyTiers.add(_StrategyTierInput()));

  void _removeStrategyTier(int i) {
    if (_strategyTiers.length > 1) setState(() => _strategyTiers.removeAt(i));
  }

  Future<void> _createStrategyInline() async {
    if (_strategyNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a strategy name')),
      );
      return;
    }
    for (final t in _strategyTiers) {
      if (t.nameCtrl.text.trim().isEmpty || t.priceCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All tier fields must be filled')),
        );
        return;
      }
    }

    setState(() => _creatingStrategy = true);

    try {
      final api = context.read<ApiService>();
      final tiersData = _strategyTiers.asMap().entries.map((e) {
            final data = <String, dynamic>{
              'name': e.value.nameCtrl.text.trim(),
              'price_cents':
                  ((double.tryParse(e.value.priceCtrl.text) ?? 0) * 100).toInt(),
              'quantity': int.tryParse(e.value.quantityCtrl.text) ?? 0,
              'display_order': e.key,
            };
            if (e.value.descCtrl.text.trim().isNotEmpty) {
              data['description'] = e.value.descCtrl.text.trim();
            }
            return data;
          }).toList();

      final resp = await api.createTicketStrategy({
        'name': _strategyNameCtrl.text.trim(),
        'tiers': tiersData,
      });

      await _loadStrategies();
      final newId = resp['id'] as int?;
      setState(() {
        _selectedStrategyId = newId;
        _showStrategyForm = false;
        _strategyNameCtrl.clear();
        _strategyTiers.clear();
        _strategyTiers.add(_StrategyTierInput());
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket strategy created and selected!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }

    setState(() => _creatingStrategy = false);
  }

  Widget _buildSelectedStrategyPreview() {
    final s = _strategies.where((s) => s.id == _selectedStrategyId).firstOrNull;
    if (s == null) return const SizedBox.shrink();

    // Calculate total ticket quantity
    final totalQty = s.tiers.fold<int>(0, (sum, t) => sum + t.quantity);
    final hasUnlimited = s.tiers.any((t) => t.quantity == 0);
    final maxCap = int.tryParse(_capacityCtrl.text) ?? 0;
    final shortfall = maxCap > 0 && !hasUnlimited && totalQty < maxCap
        ? maxCap - totalQty
        : 0;

    return Card(
      margin: const EdgeInsets.only(top: 4),
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
                      Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
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
            const Divider(height: 12),
            // Capacity vs total qty check
            Row(
              children: [
                Icon(
                  shortfall > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                  size: 16,
                  color: shortfall > 0 ? AppTheme.warningColor : AppTheme.successColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hasUnlimited
                        ? 'Total tickets: unlimited (includes unlimited tier)'
                        : shortfall > 0
                            ? 'Total tickets: $totalQty — need $shortfall more to cover capacity ($maxCap)'
                            : 'Total tickets: $totalQty (covers capacity of $maxCap)',
                    style: TextStyle(
                      fontSize: 12,
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
  }

  Widget _buildInlineStrategyForm() {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New Ticket Strategy',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _strategyNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Strategy Name',
                hintText: 'e.g. "Concert Standard"',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.layers, size: 16, color: AppTheme.primaryColor),
                const SizedBox(width: 6),
                Text('Tiers', style: Theme.of(context).textTheme.bodyMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addStrategyTier,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            ...List.generate(_strategyTiers.length, (i) {
              final t = _strategyTiers[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text('Tier ${i + 1}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          const Spacer(),
                          if (_strategyTiers.length > 1)
                            IconButton(
                              onPressed: () => _removeStrategyTier(i),
                              icon: const Icon(Icons.close, size: 16, color: AppTheme.errorColor),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: t.nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                                hintText: 'e.g. Platinum',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: t.priceCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Price (\$)',
                                prefixText: '\$ ',
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: t.quantityCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Qty',
                                hintText: '0',
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: t.descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Description (what this tier provides)',
                          hintText: 'e.g. Front row seating, backstage access',
                          isDense: true,
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: ElevatedButton.icon(
                onPressed: _creatingStrategy ? null : _createStrategyInline,
                icon: _creatingStrategy
                    ? const SizedBox(
                        height: 16, width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check, size: 18),
                label: Text(_creatingStrategy ? 'Creating...' : 'Create & Select Strategy'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _capacityCtrl.dispose();
    _fundingGoalCtrl.dispose();
    _minPledgeCtrl.dispose();
    _venueNameCtrl.dispose();
    _venueAddressCtrl.dispose();
    _venueCityCtrl.dispose();
    _venueProvinceCtrl.dispose();
    _venueCapacityCtrl.dispose();
    _strategyNameCtrl.dispose();
    for (final t in _strategyTiers) {
      t.nameCtrl.dispose();
      t.descCtrl.dispose();
      t.priceCtrl.dispose();
      t.quantityCtrl.dispose();
    }
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
        title: const Text('Create Event'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ═══════════════════════════════════════
                  // SECTION 1: Basic Info
                  // ═══════════════════════════════════════
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(labelText: 'Event Title'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // Genre
                  DropdownButtonFormField<String>(
                    value: _genre,
                    decoration: const InputDecoration(labelText: 'Genre / Category *'),
                    items: _genres.map((g) => DropdownMenuItem(
                      value: g,
                      child: Text(g[0].toUpperCase() + g.substring(1)),
                    )).toList(),
                    onChanged: (v) => setState(() => _genre = v),
                    validator: (v) => v == null ? 'Please select a genre' : null,
                  ),

                  const SizedBox(height: 24),

                  // ═══════════════════════════════════════
                  // SECTION 2: Dates & Funding Deadline
                  // ═══════════════════════════════════════
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (_startTime == null && _fundingEndAt == null)
                          ? AppTheme.warningColor.withValues(alpha: 0.08)
                          : AppTheme.successColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (_startTime == null && _fundingEndAt == null)
                            ? AppTheme.warningColor.withValues(alpha: 0.3)
                            : AppTheme.successColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              (_startTime == null && _fundingEndAt == null)
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline,
                              size: 18,
                              color: (_startTime == null && _fundingEndAt == null)
                                  ? AppTheme.warningColor
                                  : AppTheme.successColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Set at least one: Event Date or Funding Deadline',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: (_startTime == null && _fundingEndAt == null)
                                    ? Colors.grey[800]
                                    : AppTheme.successColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // ── Event Date (optional) ──
                        Text('Event Date',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.grey[700])),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickDateTime(true),
                                icon: Icon(Icons.calendar_today,
                                    size: 18,
                                    color: _startTime != null
                                        ? AppTheme.primaryColor
                                        : Colors.grey),
                                label: Text(
                                  _startTime != null
                                      ? '${_startTime!.month}/${_startTime!.day}/${_startTime!.year} ${_startTime!.hour}:${_startTime!.minute.toString().padLeft(2, '0')}'
                                      : 'Start Date & Time',
                                  style: TextStyle(
                                    color: _startTime != null
                                        ? Colors.black87
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            if (_startTime != null) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                onPressed: () =>
                                    setState(() => _startTime = null),
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickDateTime(false),
                                icon: Icon(Icons.calendar_today,
                                    size: 18,
                                    color: _endTime != null
                                        ? AppTheme.primaryColor
                                        : Colors.grey),
                                label: Text(
                                  _endTime != null
                                      ? '${_endTime!.month}/${_endTime!.day}/${_endTime!.year} ${_endTime!.hour}:${_endTime!.minute.toString().padLeft(2, '0')}'
                                      : 'End Date & Time',
                                  style: TextStyle(
                                    color: _endTime != null
                                        ? Colors.black87
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            if (_endTime != null) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                onPressed: () =>
                                    setState(() => _endTime = null),
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ],
                        ),

                        const Divider(height: 24),

                        // ── Funding Deadline (optional) ──
                        Text('Funding Deadline',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.grey[700])),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickFundingDeadline,
                                icon: Icon(Icons.timer,
                                    size: 18,
                                    color: _fundingEndAt != null
                                        ? Colors.teal
                                        : Colors.grey),
                                label: Text(
                                  _fundingEndAt != null
                                      ? '${_fundingEndAt!.month}/${_fundingEndAt!.day}/${_fundingEndAt!.year} ${_fundingEndAt!.hour}:${_fundingEndAt!.minute.toString().padLeft(2, '0')}'
                                      : 'Set Funding Deadline',
                                  style: TextStyle(
                                    color: _fundingEndAt != null
                                        ? Colors.black87
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            if (_fundingEndAt != null) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                onPressed: () =>
                                    setState(() => _fundingEndAt = null),
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _startTime != null && _fundingEndAt != null
                              ? 'Funding runs until deadline, then tickets go on sale.'
                              : _fundingEndAt != null && _startTime == null
                                  ? 'After funding, you will have a grace period to set an event date.'
                                  : _startTime != null && _fundingEndAt == null
                                      ? 'No funding phase — event goes straight to ticket sales.'
                                      : '',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
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
                            value: _refundDeadlineDays.toDouble().clamp(0, maxDays.toDouble()),
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

                  // ═══════════════════════════════════════
                  // SECTION 3: Capacity & Registration
                  // ═══════════════════════════════════════
                  TextFormField(
                    controller: _capacityCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Max Capacity'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (int.tryParse(v) == null) return 'Enter a number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Registration type
                  DropdownButtonFormField<String>(
                    value: _registrationType,
                    decoration:
                        const InputDecoration(labelText: 'Registration Type'),
                    items: const [
                      DropdownMenuItem(value: 'open', child: Text('Open')),
                      DropdownMenuItem(value: 'closed', child: Text('Closed (Waitlist)')),
                    ],
                    onChanged: (v) =>
                        setState(() => _registrationType = v ?? 'open'),
                  ),

                  const SizedBox(height: 24),

                  // ═══════════════════════════════════════
                  // SECTION 4: Venue
                  // ═══════════════════════════════════════
                  DropdownButtonFormField<int>(
                    value: _selectedVenueId,
                    decoration: const InputDecoration(labelText: 'Venue'),
                    items: _venues
                        .map((v) => DropdownMenuItem(
                            value: v.id, child: Text(v.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedVenueId = v),
                    validator: (v) =>
                        v == null ? 'Please select a venue' : null,
                  ),
                  const SizedBox(height: 8),

                  // "Add new venue" toggle
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showVenueForm = !_showVenueForm),
                    child: Row(
                      children: [
                        Icon(
                          _showVenueForm
                              ? Icons.expand_less
                              : Icons.add_location_alt,
                          size: 20,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _showVenueForm
                              ? 'Hide venue form'
                              : 'Create a new venue',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Inline venue creation card
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Card(
                      margin: const EdgeInsets.only(top: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('New Venue',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                        fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _venueNameCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Venue Name'),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _venueAddressCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Address'),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _venueCityCtrl,
                                    decoration:
                                        const InputDecoration(
                                            labelText: 'City'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _venueProvinceCtrl,
                                    decoration:
                                        const InputDecoration(
                                            labelText: 'Province'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _venueCapacityCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Max Capacity'),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 42,
                              child: ElevatedButton.icon(
                                onPressed: _creatingVenue
                                    ? null
                                    : _createVenueInline,
                                icon: _creatingVenue
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child:
                                            CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white),
                                      )
                                    : const Icon(Icons.check,
                                        size: 18),
                                label: Text(_creatingVenue
                                    ? 'Creating...'
                                    : 'Create & Select Venue'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      AppTheme.secondaryColor,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    crossFadeState: _showVenueForm
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 250),
                  ),

                  const SizedBox(height: 24),

                  // ═══════════════════════════════════════
                  // SECTION 5: Ticket Strategy
                  // ═══════════════════════════════════════
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (_fundingEndAt == null && _selectedStrategyId == null)
                          ? AppTheme.warningColor.withValues(alpha: 0.08)
                          : Colors.grey.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (_fundingEndAt == null && _selectedStrategyId == null)
                            ? AppTheme.warningColor.withValues(alpha: 0.3)
                            : Colors.grey.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.confirmation_number,
                                size: 18,
                                color: _selectedStrategyId != null
                                    ? AppTheme.successColor
                                    : AppTheme.primaryColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _fundingEndAt == null
                                    ? 'Ticket Strategy (Required)'
                                    : 'Ticket Strategy (Optional — can set later)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: _selectedStrategyId != null
                                      ? AppTheme.successColor
                                      : Colors.grey[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          value: _selectedStrategyId,
                          decoration: const InputDecoration(
                            labelText: 'Ticket Strategy',
                            hintText: 'Select a strategy',
                            isDense: true,
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
                          validator: (v) {
                            // Only require strategy when event-date-only (no funding)
                            // The date check itself is handled before form.validate()
                            if (_fundingEndAt == null &&
                                _startTime != null &&
                                v == null) {
                              return 'Required when no funding deadline';
                            }
                            return null;
                          },
                        ),
                        if (_selectedStrategyId != null) ...[
                          const SizedBox(height: 8),
                          _buildSelectedStrategyPreview(),
                        ],
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => setState(
                              () => _showStrategyForm = !_showStrategyForm),
                          child: Row(
                            children: [
                              Icon(
                                _showStrategyForm
                                    ? Icons.expand_less
                                    : Icons.add_circle_outline,
                                size: 20,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _showStrategyForm
                                    ? 'Hide strategy form'
                                    : 'Create a new strategy',
                                style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: _buildInlineStrategyForm(),
                          crossFadeState: _showStrategyForm
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 250),
                        ),
                        if (_fundingEndAt != null && _selectedStrategyId == null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'You can also set up ticketing later during the "Waiting on Event Date" state.',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ═══════════════════════════════════════
                  // SECTION 6: Funding & Settings
                  // ═══════════════════════════════════════
                  if (_fundingEndAt != null) ...[
                    Text('Funding Settings',
                        style: Theme.of(context).textTheme.titleSmall),
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
                    const SizedBox(height: 24),
                  ],

                  // Posts enabled
                  SwitchListTile(
                    title: const Text('Enable event feed / posts',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                        'Registered users can post on the event wall'),
                    value: _postsEnabled,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (v) => setState(() => _postsEnabled = v),
                    contentPadding: EdgeInsets.zero,
                  ),

                  const SizedBox(height: 16),

                  // Publish or Draft
                  SwitchListTile(
                    title: Text(
                      _publish ? 'Publish immediately' : 'Save as draft',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _publish
                          ? 'Event will be visible to everyone right away'
                          : 'You can publish it later from the event detail page',
                    ),
                    value: _publish,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (v) => setState(() => _publish = v),
                    contentPadding: EdgeInsets.zero,
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _publish
                            ? AppTheme.primaryColor
                            : Colors.grey[700],
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_publish
                              ? 'Create & Publish'
                              : 'Save as Draft'),
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
}


class _StrategyTierInput {
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final quantityCtrl = TextEditingController(text: '0');
}
