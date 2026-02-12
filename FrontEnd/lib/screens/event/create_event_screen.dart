import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/venue.dart';
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

  @override
  void initState() {
    super.initState();
    _loadVenues();
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

  Future<void> _pickDateTime(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
    );
    if (time == null) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startTime = dt;
      } else {
        _endTime = dt;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVenueId == null || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final fundingGoal = double.tryParse(_fundingGoalCtrl.text);
    final minPledge = double.tryParse(_minPledgeCtrl.text) ?? 5.0;

    final data = {
      'venue_id': _selectedVenueId,
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'start_time': _startTime!.toUtc().toIso8601String(),
      'end_time': _endTime!.toUtc().toIso8601String(),
      'max_capacity': int.parse(_capacityCtrl.text),
      'registration_type': _registrationType,
      'min_pledge_cents': (minPledge * 100).toInt(),
      'genre': _genre,
      'posts_enabled': _postsEnabled,
      'publish': _publish,
    };

    if (fundingGoal != null && fundingGoal > 0) {
      data['funding_goal_cents'] = (fundingGoal * 100).toInt();
      if (_fundingEndAt != null) {
        data['funding_end_at'] = _fundingEndAt!.toUtc().toIso8601String();
      }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Event')),
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

                  // Venue dropdown
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

                  const SizedBox(height: 16),

                  // Date/time pickers
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDateTime(true),
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(_startTime != null
                              ? '${_startTime!.month}/${_startTime!.day} ${_startTime!.hour}:${_startTime!.minute.toString().padLeft(2, '0')}'
                              : 'Start Time'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDateTime(false),
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(_endTime != null
                              ? '${_endTime!.month}/${_endTime!.day} ${_endTime!.hour}:${_endTime!.minute.toString().padLeft(2, '0')}'
                              : 'End Time'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

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

                  // Funding section
                  Text('Funding (optional)',
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
                  const SizedBox(height: 16),

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
