import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/venue.dart';
import '../../models/ticket_strategy.dart';
import '../../services/api_service.dart';
import '../../services/mapbox_geocoding_service.dart';
import '../../widgets/app_toast.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  // ── Wizard state ──
  int _currentStep = 0;
  final List<GlobalKey<FormState>> _formKeys =
      List.generate(5, (_) => GlobalKey<FormState>());
  static const _stepLabels = [
    'Basics',
    'Funding',
    'Dates & Tickets',
    'Location & Sponsors',
    'Review',
  ];
  static const _stepIcons = [
    Icons.edit_note_rounded,
    Icons.attach_money_rounded,
    Icons.event_rounded,
    Icons.location_on_rounded,
    Icons.check_circle_rounded,
  ];

  // ── Form fields ──
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _fundingGoalCtrl = TextEditingController();
  final _minPledgeCtrl = TextEditingController(text: '5.00');
  final _maxReservedSpotsCtrl = TextEditingController(text: '0');

  List<Venue> _venues = [];
  int? _selectedVenueId;
  DateTime? _startTime;
  DateTime? _endTime;
  DateTime? _fundingEndAt;
  String _registrationType = 'open';
  String? _genre;
  bool _communityRules = false;
  bool _postsEnabled = true;
  int _refundDeadlineDays = 7;
  bool _publish = true;
  bool _isLoading = false;
  bool _isDirty = false;
  final Set<int> _stepsWithErrors = {};

  bool _venuesLoading = true;
  bool _strategiesLoading = true;
  bool _discountsLoading = true;
  String? _venuesError;
  String? _strategiesError;
  String? _discountsError;

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

  // Venue geocoding
  double? _venueLat;
  double? _venueLng;
  List<GeocodingResult> _venueGeoSuggestions = [];
  bool _showVenueGeoSuggestions = false;
  bool _venueGeocoding = false;
  Timer? _venueGeoDebounce;

  // Ticket strategy
  List<TicketStrategy> _strategies = [];
  int? _selectedStrategyId;
  bool _showStrategyForm = false;
  bool _creatingStrategy = false;
  final _strategyNameCtrl = TextEditingController();
  final List<_StrategyTierInput> _strategyTiers = [_StrategyTierInput()];

  // Discount strategies
  List<Map<String, dynamic>> _discountStrategies = [];
  final Map<int, bool> _selectedDiscounts = {};
  String _discountSearch = '';

  // Parking & Transport
  bool _showTransportSection = false;
  final _parkingCtrl = TextEditingController();
  final _transitCtrl = TextEditingController();
  final _rideshareCtrl = TextEditingController();
  final _accessibilityCtrl = TextEditingController();

  // Funding Milestones
  bool _showMilestoneSection = false;
  final List<_MilestoneInput> _milestones = [];

  // Event Schedule
  bool _showScheduleSection = false;
  bool _hasSchedule = false;
  final List<_ScheduleDayInput> _scheduleDays = [];

  // Sponsorship Categories
  bool _showSponsorshipSection = false;
  final List<_SponsorCategoryInput> _sponsorCategories = [];

  // Event Images
  final List<XFile> _pickedImages = [];
  final Map<int, Uint8List> _imageBytes = {};
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadVenues();
    _loadStrategies();
    _loadDiscounts();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _capacityCtrl.dispose();
    _fundingGoalCtrl.dispose();
    _minPledgeCtrl.dispose();
    _maxReservedSpotsCtrl.dispose();
    _venueGeoDebounce?.cancel();
    _venueNameCtrl.dispose();
    _venueAddressCtrl.dispose();
    _venueCityCtrl.dispose();
    _venueProvinceCtrl.dispose();
    _venueCapacityCtrl.dispose();
    _strategyNameCtrl.dispose();
    _parkingCtrl.dispose();
    _transitCtrl.dispose();
    _rideshareCtrl.dispose();
    _accessibilityCtrl.dispose();
    for (final t in _strategyTiers) {
      t.nameCtrl.dispose();
      t.descCtrl.dispose();
      t.priceCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadVenues() async {
    setState(() { _venuesLoading = true; _venuesError = null; });
    try {
      final api = context.read<ApiService>();
      final data = await api.getVenues();
      if (mounted) setState(() { _venues = data.map((v) => Venue.fromJson(v)).toList(); _venuesLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _venuesError = 'Failed to load venues'; _venuesLoading = false; });
    }
  }

  Future<void> _loadStrategies() async {
    setState(() { _strategiesLoading = true; _strategiesError = null; });
    try {
      final api = context.read<ApiService>();
      final data = await api.getTicketStrategies();
      if (mounted) setState(() { _strategies = data.map((d) => TicketStrategy.fromJson(d)).toList(); _strategiesLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _strategiesError = 'Failed to load strategies'; _strategiesLoading = false; });
    }
  }

  Future<void> _loadDiscounts() async {
    setState(() { _discountsLoading = true; _discountsError = null; });
    try {
      final api = context.read<ApiService>();
      final data = await api.getDiscountStrategies();
      if (mounted) setState(() { _discountStrategies = data.cast<Map<String, dynamic>>(); _discountsLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _discountsError = 'Failed to load discounts'; _discountsLoading = false; });
    }
  }

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  bool get _hasAnyInput =>
      _titleCtrl.text.trim().isNotEmpty ||
      _descCtrl.text.trim().isNotEmpty ||
      _genre != null ||
      _pickedImages.isNotEmpty ||
      _fundingEndAt != null ||
      _startTime != null ||
      _endTime != null ||
      _selectedVenueId != null ||
      _selectedStrategyId != null;

  Future<bool> _confirmDiscard() async {
    if (!_isDirty && !_hasAnyInput) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to leave?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Editing')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _pickImages({bool singleMode = false}) async {
    try {
      List<XFile> picked;
      if (singleMode) {
        final single =
            await _imagePicker.pickImage(source: ImageSource.gallery);
        picked = single != null ? [single] : [];
      } else {
        picked = await _imagePicker.pickMultiImage();
      }
      if (picked.isEmpty) return;
      for (final xFile in picked) {
        final bytes = await xFile.readAsBytes();
        final idx = _pickedImages.length;
        _pickedImages.add(xFile);
        _imageBytes[idx] = bytes;
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) AppToast.error(context, 'Could not pick images: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _pickedImages.removeAt(index);
      final newBytes = <int, Uint8List>{};
      for (int i = 0; i < _pickedImages.length; i++) {
        final oldIdx = i >= index ? i + 1 : i;
        if (_imageBytes.containsKey(oldIdx)) newBytes[i] = _imageBytes[oldIdx]!;
      }
      _imageBytes
        ..clear()
        ..addAll(newBytes);
    });
  }

  void _onVenueAddressChanged(String query) {
    _venueLat = null;
    _venueLng = null;
    _venueGeoDebounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _venueGeoSuggestions = [];
        _showVenueGeoSuggestions = false;
      });
      return;
    }
    _venueGeoDebounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _venueGeocoding = true);
      final results = await MapboxGeocodingService.search(query);
      if (mounted) {
        setState(() {
          _venueGeoSuggestions = results;
          _showVenueGeoSuggestions = results.isNotEmpty;
          _venueGeocoding = false;
        });
      }
    });
  }

  void _selectVenueGeoSuggestion(GeocodingResult result) {
    setState(() {
      _venueAddressCtrl.text = result.fullAddress;
      if (result.city != null && result.city!.isNotEmpty) {
        _venueCityCtrl.text = result.city!;
      }
      if (result.province != null && result.province!.isNotEmpty) {
        _venueProvinceCtrl.text = result.province!;
      }
      _venueLat = result.lat;
      _venueLng = result.lng;
      _showVenueGeoSuggestions = false;
      _venueGeoSuggestions = [];
    });
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
    final dt =
        await _pickDateTimeGeneric(initial: isStart ? _startTime : _endTime);
    if (dt == null) return;
    _markDirty();
    setState(() {
      if (isStart) {
        _startTime = dt;
        if (_endTime != null && !_endTime!.isAfter(dt)) {
          AppToast.error(context, 'End time must be after start time');
        }
      } else {
        _endTime = dt;
        if (_startTime != null && !dt.isAfter(_startTime!)) {
          AppToast.error(context, 'End time must be after start time');
        }
      }
      if (_fundingEndAt != null && _startTime != null && !_startTime!.isAfter(_fundingEndAt!)) {
        AppToast.error(context, 'Start time should be after funding deadline');
      }
    });
  }

  Future<void> _pickFundingDeadline() async {
    final dt = await _pickDateTimeGeneric(initial: _fundingEndAt);
    if (dt == null) return;
    _markDirty();
    setState(() {
      _fundingEndAt = dt;
      if (_startTime != null && !_startTime!.isAfter(dt)) {
        AppToast.error(context, 'Event start should be after funding deadline');
      }
    });
  }

  Future<void> _createVenueInline() async {
    if (_venueNameCtrl.text.trim().isEmpty ||
        _venueAddressCtrl.text.trim().isEmpty ||
        _venueCityCtrl.text.trim().isEmpty ||
        _venueCapacityCtrl.text.trim().isEmpty) {
      AppToast.error(context, 'Please fill in all venue fields');
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
        if (_venueLat != null) 'lat': _venueLat,
        if (_venueLng != null) 'lng': _venueLng,
      });
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
        _venueLat = null;
        _venueLng = null;
      });
      if (mounted) AppToast.success(context, 'Venue created and selected!');
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to create venue');
      }
    }
    setState(() => _creatingVenue = false);
  }

  void _addStrategyTier() =>
      setState(() => _strategyTiers.add(_StrategyTierInput()));

  void _removeStrategyTier(int i) {
    if (_strategyTiers.length > 1) setState(() => _strategyTiers.removeAt(i));
  }

  Future<void> _createStrategyInline() async {
    if (_strategyNameCtrl.text.trim().isEmpty) {
      AppToast.error(context, 'Please enter a strategy name');
      return;
    }
    for (final t in _strategyTiers) {
      if (t.nameCtrl.text.trim().isEmpty || t.priceCtrl.text.trim().isEmpty) {
        AppToast.error(context, 'All tier fields must be filled');
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
        AppToast.success(context, 'Ticket strategy created and selected!');
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e,
            fallback: 'Failed to create ticket strategy');
      }
    }
    setState(() => _creatingStrategy = false);
  }

  String _discountLabel(Map<String, dynamic> d) {
    final name = d['name'] ?? '';
    final type = d['discount_type'] ?? '';
    final val = d['value'] ?? 0;
    final target = d['target'] ?? 'all';
    final typeLabel = type == 'ticket_percent' ? '% ticket' : '% pledge';
    return '$name · $val$typeLabel · $target';
  }

  List<Widget> _buildAvailableDiscountList() {
    final available = _discountStrategies.where((d) {
      final id = d['id'] as int;
      if (_selectedDiscounts.containsKey(id)) return false;
      if (_discountSearch.isEmpty) return true;
      return _discountLabel(d).toLowerCase().contains(_discountSearch);
    }).toList();
    if (available.isEmpty && _discountSearch.isNotEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('No matching discounts',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textSecondaryOf(context))),
        ),
      ];
    }
    if (available.isEmpty) return [];
    return available.take(3).map((d) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.deepPurple.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(_discountLabel(d),
                    style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 6),
              _CreateDiscountBtn(
                label: 'Add + Apply',
                color: Colors.green,
                onTap: () =>
                    setState(() => _selectedDiscounts[d['id'] as int] = true),
              ),
              const SizedBox(width: 6),
              _CreateDiscountBtn(
                label: 'Add',
                color: Colors.deepPurple,
                onTap: () =>
                    setState(() => _selectedDiscounts[d['id'] as int] = false),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  void _goToStep(int step) {
    if (step >= 0 && step < _stepLabels.length) {
      setState(() => _currentStep = step);
    }
  }

  void _nextStep() {
    if (!_validateCurrentStep()) return;
    setState(() {
      _stepsWithErrors.remove(_currentStep);
      if (_currentStep < _stepLabels.length - 1) _currentStep++;
    });
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  bool _validateCurrentStep() {
    bool fail(String msg) {
      AppToast.error(context, msg);
      setState(() => _stepsWithErrors.add(_currentStep));
      return false;
    }
    bool pass() {
      setState(() => _stepsWithErrors.remove(_currentStep));
      return true;
    }

    final formState = _formKeys[_currentStep].currentState;
    if (formState != null && !formState.validate()) return fail('Please fix the highlighted fields');

    switch (_currentStep) {
      case 0:
        if (_titleCtrl.text.trim().isEmpty) return fail('Event title is required');
        if (_genre == null) return fail('Please select a genre');
        return pass();
      case 1:
        return pass();
      case 2:
        if (_fundingEndAt == null && (_startTime == null || _endTime == null)) {
          return fail('Set both start & end dates, or go back and set a funding deadline');
        }
        if (_startTime != null && _endTime == null) return fail('End time is required when start time is set');
        if (_startTime != null && _endTime != null && !_endTime!.isAfter(_startTime!)) {
          return fail('End time must be after start time');
        }
        if (_startTime != null && _fundingEndAt != null && !_startTime!.isAfter(_fundingEndAt!)) {
          return fail('Event start must be after funding deadline');
        }
        return pass();
      case 3:
        if (_selectedVenueId == null) return fail('Please select a venue');
        if (_capacityCtrl.text.trim().isEmpty || int.tryParse(_capacityCtrl.text.trim()) == null) {
          return fail('Please enter a valid max capacity');
        }
        return pass();
      case 4:
        return pass();
    }
    return pass();
  }

  String _fmtDt(DateTime dt) =>
      '${dt.month}/${dt.day}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';

  Widget _buildLoadingChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
        ],
      ),
    );
  }

  Widget _buildErrorRetry(String message, VoidCallback onRetry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: AppTheme.errorColor),
          const SizedBox(width: 6),
          Expanded(child: Text(message, style: TextStyle(fontSize: 12, color: AppTheme.errorColor))),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: const Text('Retry', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_fundingEndAt == null &&
        (_startTime == null || _endTime == null)) {
      AppToast.error(
          context, 'Set funding deadline or both start & end dates');
      setState(() => _currentStep = 2);
      return;
    }
    if (_startTime != null && _endTime == null) {
      AppToast.error(context, 'End time is required when start time is set');
      setState(() => _currentStep = 2);
      return;
    }
    if (_startTime != null &&
        _fundingEndAt != null &&
        !_startTime!.isAfter(_fundingEndAt!)) {
      AppToast.error(
          context, 'Event start time must be after the funding deadline');
      setState(() => _currentStep = 2);
      return;
    }
    if (_fundingEndAt == null && _selectedStrategyId == null) {
      AppToast.error(context,
          'Ticket strategy is required when no funding deadline is set');
      setState(() => _currentStep = 2);
      return;
    }
    if (_selectedVenueId == null) {
      AppToast.error(context, 'Please select a venue');
      setState(() => _currentStep = 3);
      return;
    }
    final capVal = int.tryParse(_capacityCtrl.text.trim());
    if (capVal == null) {
      AppToast.error(context, 'Please enter a valid max capacity');
      setState(() => _currentStep = 3);
      return;
    }

    setState(() => _isLoading = true);

    final fundingGoal = double.tryParse(_fundingGoalCtrl.text);
    final minPledge = double.tryParse(_minPledgeCtrl.text) ?? 5.0;

    final data = <String, dynamic>{
      'venue_id': _selectedVenueId,
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'max_capacity': capVal,
      'registration_type': _registrationType,
      'min_pledge_cents': (minPledge * 100).toInt(),
      'max_reserved_spots_per_user':
          int.tryParse(_maxReservedSpotsCtrl.text) ?? 0,
      'genre': _genre,
      'community_rules': _communityRules,
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
    final selectedVenue =
        _venues.where((v) => v.id == _selectedVenueId).firstOrNull;
    if (selectedVenue != null) {
      data['lat'] = selectedVenue.lat;
      data['lng'] = selectedVenue.lng;
    }
    if (_parkingCtrl.text.trim().isNotEmpty) {
      data['parking_info'] = _parkingCtrl.text.trim();
    }
    if (_transitCtrl.text.trim().isNotEmpty) {
      data['transit_info'] = _transitCtrl.text.trim();
    }
    if (_rideshareCtrl.text.trim().isNotEmpty) {
      data['rideshare_info'] = _rideshareCtrl.text.trim();
    }
    if (_accessibilityCtrl.text.trim().isNotEmpty) {
      data['accessibility_info'] = _accessibilityCtrl.text.trim();
    }
    if (_hasSchedule) data['has_schedule'] = true;

    try {
      final api = context.read<ApiService>();
      final resp = await api.createEvent(data);
      final eventId = resp['id'] as int;

      for (final entry in _selectedDiscounts.entries) {
        try {
          await api.attachDiscountStrategy(eventId, entry.key,
              autoApply: entry.value);
        } catch (_) {}
      }

      for (final ms in _milestones) {
        final title = ms.titleCtrl.text.trim();
        if (title.isEmpty) continue;
        try {
          await api.createMilestone(eventId, {
            'title': title,
            'unlock_percent': ms.unlockPercent,
            if (ms.benefitCtrl.text.trim().isNotEmpty)
              'benefit_description': ms.benefitCtrl.text.trim(),
          });
        } catch (_) {}
      }

      if (_hasSchedule && _scheduleDays.isNotEmpty) {
        final scheduleItems = <Map<String, dynamic>>[];
        for (final day in _scheduleDays) {
          if (day.date == null) continue;
          final dateStr =
              '${day.date!.year}-${day.date!.month.toString().padLeft(2, '0')}-${day.date!.day.toString().padLeft(2, '0')}';
          for (int i = 0; i < day.slots.length; i++) {
            final slot = day.slots[i];
            final title = slot.titleCtrl.text.trim();
            if (title.isEmpty) continue;
            scheduleItems.add({
              'date': dateStr,
              'start_time':
                  '${slot.startTime.hour.toString().padLeft(2, '0')}:${slot.startTime.minute.toString().padLeft(2, '0')}',
              'end_time':
                  '${slot.endTime.hour.toString().padLeft(2, '0')}:${slot.endTime.minute.toString().padLeft(2, '0')}',
              'title': title,
              if (slot.descCtrl.text.trim().isNotEmpty)
                'description': slot.descCtrl.text.trim(),
              'sort_order': i,
            });
          }
        }
        if (scheduleItems.isNotEmpty) {
          try {
            await api.bulkCreateSchedule(eventId, scheduleItems);
          } catch (_) {}
        }
      }

      for (final sc in _sponsorCategories) {
        final name = sc.nameCtrl.text.trim();
        if (name.isEmpty) continue;
        final spotsText = sc.spotsCtrl.text.trim();
        final minBidText = sc.minBidCtrl.text.trim();
        if (spotsText.isEmpty || minBidText.isEmpty) continue;
        try {
          await api.createSponsorshipCategory(eventId, {
            'name': name,
            if (sc.descCtrl.text.trim().isNotEmpty)
              'description': sc.descCtrl.text.trim(),
            'total_spots': int.parse(spotsText),
            'min_bid_cents': (double.parse(minBidText) * 100).round(),
            'sort_order': _sponsorCategories.indexOf(sc),
          });
        } catch (_) {}
      }

      for (int i = 0; i < _pickedImages.length; i++) {
        try {
          final bytes =
              _imageBytes[i] ?? await _pickedImages[i].readAsBytes();
          await api.uploadEventImage(
            eventId,
            fileBytes: bytes,
            fileName: _pickedImages[i].name,
            displayOrder: i,
          );
        } catch (_) {}
      }

      setState(() => _isLoading = false);
      if (mounted) context.pop(true);
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            if (await _confirmDiscard()) {
              if (!context.mounted) return;
              if (Navigator.of(context).canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            }
          },
        ),
        title: const Text('Create Event'),
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: IndexedStack(
              index: _currentStep,
              children: [
                _buildStep1Basics(),
                _buildStep2Funding(),
                _buildStep3DatesTickets(),
                _buildStep4LocationSponsors(),
                _buildStep5Review(),
              ],
            ),
          ),
          _buildBottomNav(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        border:
            Border(bottom: BorderSide(color: AppTheme.dividerOf(context))),
      ),
      child: Row(
        children: List.generate(_stepLabels.length * 2 - 1, (i) {
          if (i.isOdd) {
            final stepBefore = i ~/ 2;
            return Expanded(
              child: Container(
                height: 2,
                color: stepBefore < _currentStep
                    ? AppTheme.accentColor
                    : AppTheme.dividerOf(context),
              ),
            );
          }
          final step = i ~/ 2;
          final isCompleted = step < _currentStep;
          final isCurrent = step == _currentStep;
          final hasError = _stepsWithErrors.contains(step);
          return GestureDetector(
            onTap: () => _goToStep(step),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: isCurrent ? 32 : 26,
                      height: isCurrent ? 32 : 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasError
                            ? AppTheme.errorColor
                            : isCompleted || isCurrent
                                ? AppTheme.accentColor
                                : AppTheme.surfaceOf(context),
                        border: Border.all(
                          color: hasError
                              ? AppTheme.errorColor
                              : isCompleted || isCurrent
                                  ? AppTheme.accentColor
                                  : AppTheme.dividerOf(context),
                          width: isCurrent ? 2.5 : 1.5,
                        ),
                      ),
                      child: Center(
                        child: hasError
                            ? const Icon(Icons.priority_high, size: 14, color: Colors.white)
                            : isCompleted
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : Icon(
                                    _stepIcons[step],
                                    size: isCurrent ? 16 : 13,
                                    color: isCurrent
                                        ? Colors.white
                                        : AppTheme.textSecondaryOf(context),
                                  ),
                      ),
                    ),
                    if (hasError)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.cardOf(context), width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _stepLabels[step],
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight:
                        isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color: hasError
                        ? AppTheme.errorColor
                        : isCurrent
                            ? AppTheme.accentColor
                            : isCompleted
                                ? AppTheme.textPrimaryOf(context)
                                : AppTheme.textSecondaryOf(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomNav() {
    final isLast = _currentStep == _stepLabels.length - 1;
    final isFirst = _currentStep == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        border:
            Border(top: BorderSide(color: AppTheme.dividerOf(context))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (!isFirst)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _prevStep,
                  icon:
                      const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                        color: AppTheme.dividerOf(context)),
                  ),
                ),
              )
            else
              const Spacer(),
            const SizedBox(width: 12),
            Expanded(
              flex: isFirst ? 2 : 1,
              child: isLast
                  ? ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submit,
                      icon: _isLoading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_rounded,
                              size: 18),
                      label: Text(_isLoading
                          ? 'Creating...'
                          : _publish
                              ? 'Create & Publish'
                              : 'Save as Draft'),
                      style: ElevatedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: _publish
                            ? AppTheme.accentColor
                            : AppTheme.textSecondaryOf(context),
                        foregroundColor: Colors.white,
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _nextStep,
                      icon: const Icon(Icons.arrow_forward_rounded,
                          size: 18),
                      label: Text(_currentStep < _stepLabels.length - 1
                          ? 'Next: ${_stepLabels[_currentStep + 1]}'
                          : 'Next'),
                      style: ElevatedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppTheme.accentColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1Basics() {
    return Form(
      key: _formKeys[0],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Tell us about your event',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _titleCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Event Title *'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                  onChanged: (_) => _markDirty(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descCtrl,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    counterText: '${_descCtrl.text.length} / 2000',
                    counterStyle: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                  ),
                  maxLines: 3,
                  maxLength: 2000,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  onChanged: (_) { _markDirty(); setState(() {}); },
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.cardOf(context),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppTheme.dividerOf(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.photo_library_rounded,
                              size: 20, color: AppTheme.accentColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Event Images',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: AppTheme.textPrimaryOf(
                                        context))),
                          ),
                          Text('${_pickedImages.length} selected',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondaryOf(
                                      context))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_pickedImages.isNotEmpty) ...[
                        SizedBox(
                          height: 120,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _pickedImages.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, i) {
                              final bytes = _imageBytes[i];
                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    child: bytes != null
                                        ? Image.memory(bytes,
                                            width: 120,
                                            height: 120,
                                            fit: BoxFit.cover)
                                        : Container(
                                            width: 120,
                                            height: 120,
                                            color: AppTheme.dividerOf(
                                                context),
                                            child: const Icon(
                                                Icons.image,
                                                size: 32)),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => _removeImage(i),
                                      child: Container(
                                        padding:
                                            const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.6),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close,
                                            size: 14,
                                            color: Colors.white),
                                      ),
                                    ),
                                  ),
                                  if (i == 0)
                                    Positioned(
                                      bottom: 4,
                                      left: 4,
                                      child: Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2),
                                        decoration: BoxDecoration(
                                          color:
                                              AppTheme.primaryOf(context),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: const Text('Cover',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight:
                                                    FontWeight.w600)),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickImages(),
                              icon: const Icon(
                                  Icons.photo_library_rounded,
                                  size: 18),
                              label: const Text('Select Multiple'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    AppTheme.primaryOf(context),
                                side: BorderSide(
                                    color: AppTheme.primaryOf(context)
                                        .withValues(alpha: 0.4)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _pickImages(singleMode: true),
                              icon: const Icon(
                                  Icons.add_photo_alternate_rounded,
                                  size: 18),
                              label: const Text('Pick One'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    AppTheme.textSecondaryOf(context),
                                side: BorderSide(
                                    color:
                                        AppTheme.dividerOf(context)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_pickedImages.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Add photos to make your event stand out. The first image will be the cover.',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondaryOf(
                                    context)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _genre,
                  decoration: const InputDecoration(
                      labelText: 'Genre / Category *'),
                  items: _genres
                      .map((g) => DropdownMenuItem(
                          value: g,
                          child: Text(
                              g[0].toUpperCase() + g.substring(1))))
                      .toList(),
                  onChanged: (v) => setState(() => _genre = v),
                  validator: (v) =>
                      v == null ? 'Please select a genre' : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep2Funding() {
    return Form(
      key: _formKeys[1],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Funding Settings',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  'Set a funding deadline to run a crowdfunding phase before your event. If skipped, start & end dates become required in the next step.',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context)),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _fundingEndAt != null
                        ? AppTheme.successColor.withValues(alpha: 0.06)
                        : AppTheme.cardOf(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _fundingEndAt != null
                          ? AppTheme.successColor.withValues(alpha: 0.25)
                          : AppTheme.dividerOf(context),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.timer,
                              size: 18,
                              color: _fundingEndAt != null
                                  ? Colors.teal
                                  : AppTheme.textSecondaryOf(context)),
                          const SizedBox(width: 8),
                          Text('Funding Deadline',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppTheme.textPrimaryOf(context))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickFundingDeadline,
                              icon: Icon(Icons.timer,
                                  size: 18,
                                  color: _fundingEndAt != null
                                      ? Colors.teal
                                      : AppTheme.textSecondaryOf(context)),
                              label: Text(
                                _fundingEndAt != null
                                    ? _fmtDt(_fundingEndAt!)
                                    : 'Set Funding Deadline',
                                style: TextStyle(
                                  color: _fundingEndAt != null
                                      ? AppTheme.textPrimaryOf(context)
                                      : AppTheme.textSecondaryOf(context),
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
                    ],
                  ),
                ),
                if (_fundingEndAt != null) ...[
                  const SizedBox(height: 16),
                  Builder(builder: (context) {
                    final fundDuration =
                        _fundingEndAt!.difference(DateTime.now()).inDays;
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
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Max $maxDays days (20% of funding duration). Customers can get a refund if they unregister before this cutoff.',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryOf(context)),
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
                          activeColor: AppTheme.accentColor,
                          onChanged: (v) => setState(
                              () => _refundDeadlineDays = v.round()),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _fundingGoalCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Funding Goal (\$)',
                        prefixText: '\$ '),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _minPledgeCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Minimum Pledge (\$)',
                        prefixText: '\$ '),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _maxReservedSpotsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Max Reserved Spots Per User',
                      helperText:
                          'How many ticket spots each pledger can reserve (0 = disabled)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),
                  _buildMilestoneSection(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMilestoneSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(
              () => _showMilestoneSection = !_showMilestoneSection),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _showMilestoneSection
                  ? Colors.amber.withValues(alpha: 0.08)
                  : AppTheme.cardOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showMilestoneSection
                    ? Colors.amber.withValues(alpha: 0.3)
                    : AppTheme.dividerOf(context),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_events_rounded,
                    size: 18,
                    color: _showMilestoneSection
                        ? Colors.amber[700]
                        : AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Funding Milestones (Optional)',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppTheme.textPrimaryOf(context))),
                ),
                if (_milestones.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${_milestones.length}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber[800])),
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
                ..._milestones.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final ms = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
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
                            Text('Milestone ${idx + 1}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            const Spacer(),
                            IconButton(
                              icon: Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red[400]),
                              onPressed: () => setState(
                                  () => _milestones.removeAt(idx)),
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
                                    color:
                                        AppTheme.textSecondaryOf(
                                            context))),
                            Expanded(
                              child: Slider(
                                value:
                                    ms.unlockPercent.toDouble(),
                                min: 1,
                                max: 100,
                                divisions: 99,
                                label: '${ms.unlockPercent}%',
                                onChanged: (v) => setState(() =>
                                    ms.unlockPercent = v.round()),
                              ),
                            ),
                            SizedBox(
                              width: 42,
                              child: Text(
                                  '${ms.unlockPercent}%',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13),
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
                }),
                GestureDetector(
                  onTap: () => setState(
                      () => _milestones.add(_MilestoneInput())),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.dividerOf(context)),
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded,
                            size: 18,
                            color: AppTheme.textSecondaryOf(
                                context)),
                        const SizedBox(width: 6),
                        Text('Add Milestone',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color:
                                    AppTheme.textSecondaryOf(
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

  Widget _buildStep3DatesTickets() {
    final needsDates = _fundingEndAt == null;
    final hasDates = _startTime != null && _endTime != null;
    return Form(
      key: _formKeys[2],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Dates & Tickets',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: (needsDates && !hasDates)
                        ? AppTheme.warningColor.withValues(alpha: 0.08)
                        : AppTheme.successColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (needsDates && !hasDates)
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
                            (needsDates && !hasDates)
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_outline,
                            size: 18,
                            color: (needsDates && !hasDates)
                                ? AppTheme.warningColor
                                : AppTheme.successColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              needsDates
                                  ? 'Start & end dates are required (no funding deadline set)'
                                  : 'Event dates (optional — funding deadline is set)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: (needsDates && !hasDates)
                                    ? AppTheme.textPrimaryOf(context)
                                    : AppTheme.successColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text('Event Date',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.textSecondaryOf(context))),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickDateTime(true),
                              icon: Icon(Icons.calendar_today,
                                  size: 18,
                                  color: _startTime != null
                                      ? AppTheme.primaryOf(context)
                                      : AppTheme.textSecondaryOf(context)),
                              label: Text(
                                _startTime != null
                                    ? _fmtDt(_startTime!)
                                    : 'Start Date & Time',
                                style: TextStyle(
                                  color: _startTime != null
                                      ? AppTheme.textPrimaryOf(context)
                                      : AppTheme.textSecondaryOf(context),
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
                                      ? AppTheme.primaryOf(context)
                                      : AppTheme.textSecondaryOf(context)),
                              label: Text(
                                _endTime != null
                                    ? _fmtDt(_endTime!)
                                    : 'End Date & Time',
                                style: TextStyle(
                                  color: _endTime != null
                                      ? AppTheme.textPrimaryOf(context)
                                      : AppTheme.textSecondaryOf(context),
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
                            color: AppTheme.textSecondaryOf(context),
                            fontStyle: FontStyle.italic),
                      ),
                      if (_startTime != null && _endTime != null && !_endTime!.isAfter(_startTime!))
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(children: [
                            Icon(Icons.error_outline, size: 14, color: AppTheme.errorColor),
                            const SizedBox(width: 4),
                            Text('End time must be after start time',
                                style: TextStyle(fontSize: 11, color: AppTheme.errorColor, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      if (_startTime != null && _fundingEndAt != null && !_startTime!.isAfter(_fundingEndAt!))
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(children: [
                            Icon(Icons.error_outline, size: 14, color: AppTheme.errorColor),
                            const SizedBox(width: 4),
                            Text('Start time should be after funding deadline',
                                style: TextStyle(fontSize: 11, color: AppTheme.errorColor, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
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
                const SizedBox(height: 24),
                _buildTicketStrategySection(),
                if (_selectedStrategyId != null) ...[
                  const SizedBox(height: 16),
                  _buildDiscountSection(),
                ],
                if (_startTime != null && _endTime != null) ...[
                  const SizedBox(height: 24),
                  _buildScheduleSection(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTicketStrategySection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (_fundingEndAt == null && _selectedStrategyId == null)
            ? AppTheme.warningColor.withValues(alpha: 0.08)
            : AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (_fundingEndAt == null && _selectedStrategyId == null)
              ? AppTheme.warningColor.withValues(alpha: 0.3)
              : AppTheme.dividerOf(context),
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
                      : AppTheme.primaryOf(context)),
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
                        : AppTheme.textPrimaryOf(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_strategiesLoading)
            _buildLoadingChip('Loading strategies…')
          else if (_strategiesError != null)
            _buildErrorRetry(_strategiesError!, _loadStrategies),
          _SearchableDropdown<TicketStrategy>(
            label: 'Ticket Strategy',
            hint: _strategiesLoading ? 'Loading…' : 'Search strategies…',
            items: _strategies,
            selectedItem: _strategies
                .where((s) => s.id == _selectedStrategyId)
                .firstOrNull,
            itemLabel: (s) => s.name,
            itemSubtitle: (s) => s.tiersSummary,
            filter: (s, q) =>
                s.name.toLowerCase().contains(q.toLowerCase()),
            onSelected: (s) =>
                setState(() => _selectedStrategyId = s?.id),
            validator: (_) {
              if (_fundingEndAt == null &&
                  _startTime != null &&
                  _selectedStrategyId == null) {
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
                  color: AppTheme.primaryOf(context),
                ),
                const SizedBox(width: 6),
                Text(
                  _showStrategyForm
                      ? 'Hide strategy form'
                      : 'Create a new strategy',
                  style: TextStyle(
                    color: AppTheme.primaryOf(context),
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
          if (_fundingEndAt != null &&
              _selectedStrategyId == null) ...[
            const SizedBox(height: 6),
            Text(
              'You can also set up ticketing later during the "Waiting on Event Date" state.',
              style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondaryOf(context),
                  fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiscountSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.deepPurple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.discount_rounded,
                  size: 18, color: Colors.deepPurple),
              const SizedBox(width: 8),
              Text('Discounts (Optional)',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.textPrimaryOf(context))),
            ],
          ),
          if (_discountsLoading)
            _buildLoadingChip('Loading discounts…')
          else if (_discountsError != null)
            _buildErrorRetry(_discountsError!, _loadDiscounts),
          const SizedBox(height: 8),
          if (_selectedDiscounts.isNotEmpty) ...[
            ..._selectedDiscounts.entries.map((entry) {
              final d = _discountStrategies.firstWhere(
                (s) => s['id'] == entry.key,
                orElse: () => {
                  'name': '?',
                  'discount_type': '',
                  'value': 0,
                  'target': ''
                },
              );
              final autoApply = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple
                              .withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.deepPurple
                                  .withValues(alpha: 0.3),
                              width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                  _discountLabel(d),
                                  style:
                                      const TextStyle(
                                          fontSize: 12)),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2),
                              decoration: BoxDecoration(
                                color: autoApply
                                    ? Colors.green
                                        .withValues(
                                            alpha: 0.15)
                                    : Colors.orange
                                        .withValues(
                                            alpha: 0.15),
                                borderRadius:
                                    BorderRadius.circular(4),
                              ),
                              child: Text(
                                autoApply
                                    ? 'Auto'
                                    : 'Claimable',
                                style: TextStyle(
                                  color: autoApply
                                      ? Colors.green
                                      : Colors.orange,
                                  fontSize: 10,
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => setState(() =>
                          _selectedDiscounts
                              .remove(entry.key)),
                      child: Icon(Icons.close,
                          size: 16,
                          color: AppTheme.textSecondaryOf(
                              context)),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
          ],
          TextField(
            decoration: InputDecoration(
              hintText: 'Search discounts…',
              hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryOf(context)),
              prefixIcon: Icon(Icons.search,
                  color: AppTheme.textSecondaryOf(context),
                  size: 20),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: AppTheme.dividerOf(context)),
              ),
            ),
            onChanged: (v) => setState(
                () => _discountSearch = v.toLowerCase()),
          ),
          ..._buildAvailableDiscountList(),
        ],
      ),
    );
  }

  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(
              () => _showScheduleSection = !_showScheduleSection),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _showScheduleSection
                  ? Colors.blue.withValues(alpha: 0.08)
                  : AppTheme.cardOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showScheduleSection
                    ? Colors.blue.withValues(alpha: 0.3)
                    : AppTheme.dividerOf(context),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded,
                    size: 18,
                    color: _showScheduleSection
                        ? Colors.blue
                        : AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Event Schedule (Optional)',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color:
                              AppTheme.textPrimaryOf(context))),
                ),
                if (_scheduleDays.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                        '${_scheduleDays.fold<int>(0, (sum, d) => sum + d.slots.length)}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryOf(context))),
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
              color: AppTheme.cardOf(context),
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
                      child: Text('Use structured schedule',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryOf(
                                  context))),
                    ),
                    Switch(
                      value: _hasSchedule,
                      onChanged: (v) =>
                          setState(() => _hasSchedule = v),
                    ),
                  ],
                ),
                if (_hasSchedule) ...[
                  const SizedBox(height: 8),
                  Text('Add time slots for each day of your event.',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryOf(
                              context))),
                  const SizedBox(height: 12),
                  ..._scheduleDays
                      .asMap()
                      .entries
                      .map((dayEntry) {
                    final dayIdx = dayEntry.key;
                    final day = dayEntry.value;
                    final dateLabel = day.date != null
                        ? '${day.date!.month}/${day.date!.day}/${day.date!.year}'
                        : 'Select date';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.blue
                                .withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  final picked =
                                      await showDatePicker(
                                    context: context,
                                    initialDate:
                                        day.date ??
                                            _startTime!,
                                    firstDate:
                                        _startTime!,
                                    lastDate: _endTime!,
                                  );
                                  if (picked != null) {
                                    setState(() =>
                                        day.date =
                                            picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets
                                      .symmetric(
                                      horizontal: 10,
                                      vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue
                                        .withValues(
                                            alpha: 0.08),
                                    borderRadius:
                                        BorderRadius
                                            .circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize:
                                        MainAxisSize.min,
                                    children: [
                                      const Icon(
                                          Icons
                                              .calendar_today_rounded,
                                          size: 14,
                                          color:
                                              Colors.blue),
                                      const SizedBox(
                                          width: 6),
                                      Text(dateLabel,
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight:
                                                  FontWeight
                                                      .w600,
                                              color: Colors
                                                      .blue[
                                                  700])),
                                    ],
                                  ),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color:
                                        Colors.red[400]),
                                onPressed: () => setState(
                                    () => _scheduleDays
                                        .removeAt(
                                            dayIdx)),
                                padding: EdgeInsets.zero,
                                constraints:
                                    const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...day.slots
                              .asMap()
                              .entries
                              .map((slotEntry) {
                            final slotIdx =
                                slotEntry.key;
                            final slot =
                                slotEntry.value;
                            return Container(
                              margin:
                                  const EdgeInsets.only(
                                      bottom: 8),
                              padding:
                                  const EdgeInsets.all(
                                      10),
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.surfaceOf(
                                        context),
                                borderRadius:
                                    BorderRadius
                                        .circular(8),
                                border: Border.all(
                                    color: AppTheme
                                        .dividerOf(
                                            context)),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .stretch,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                          'Slot ${slotIdx + 1}',
                                          style: TextStyle(
                                              fontWeight:
                                                  FontWeight
                                                      .w600,
                                              fontSize:
                                                  12,
                                              color: AppTheme
                                                  .textSecondaryOf(
                                                      context))),
                                      const Spacer(),
                                      IconButton(
                                        icon: Icon(
                                            Icons
                                                .delete_outline,
                                            size: 16,
                                            color: Colors
                                                    .red[
                                                400]),
                                        onPressed: () =>
                                            setState(() =>
                                                day.slots
                                                    .removeAt(
                                                        slotIdx)),
                                        padding:
                                            EdgeInsets
                                                .zero,
                                        constraints:
                                            const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                      height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child:
                                            GestureDetector(
                                          onTap:
                                              () async {
                                            final t = await showTimePicker(
                                                context:
                                                    context,
                                                initialTime:
                                                    slot.startTime);
                                            if (t !=
                                                null) {
                                              setState(() =>
                                                  slot.startTime =
                                                      t);
                                            }
                                          },
                                          child:
                                              Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal:
                                                    10,
                                                vertical:
                                                    8),
                                            decoration:
                                                BoxDecoration(
                                              border: Border.all(
                                                  color:
                                                      AppTheme.dividerOf(context)),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      8),
                                            ),
                                            child: Text(
                                                slot.startTime
                                                    .format(
                                                        context),
                                                style: TextStyle(
                                                    fontSize:
                                                        12,
                                                    color:
                                                        AppTheme.textPrimaryOf(context))),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets
                                            .symmetric(
                                            horizontal:
                                                8),
                                        child: Text(
                                            '–',
                                            style: TextStyle(
                                                color: AppTheme
                                                    .textSecondaryOf(
                                                        context))),
                                      ),
                                      Expanded(
                                        child:
                                            GestureDetector(
                                          onTap:
                                              () async {
                                            final t = await showTimePicker(
                                                context:
                                                    context,
                                                initialTime:
                                                    slot.endTime);
                                            if (t !=
                                                null) {
                                              setState(() =>
                                                  slot.endTime =
                                                      t);
                                            }
                                          },
                                          child:
                                              Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal:
                                                    10,
                                                vertical:
                                                    8),
                                            decoration:
                                                BoxDecoration(
                                              border: Border.all(
                                                  color:
                                                      AppTheme.dividerOf(context)),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      8),
                                            ),
                                            child: Text(
                                                slot.endTime
                                                    .format(
                                                        context),
                                                style: TextStyle(
                                                    fontSize:
                                                        12,
                                                    color:
                                                        AppTheme.textPrimaryOf(context))),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                      height: 8),
                                  TextFormField(
                                    controller:
                                        slot.titleCtrl,
                                    decoration:
                                        const InputDecoration(
                                      labelText:
                                          'Title',
                                      hintText:
                                          'e.g. Opening Keynote',
                                      isDense: true,
                                    ),
                                  ),
                                  const SizedBox(
                                      height: 8),
                                  TextFormField(
                                    controller:
                                        slot.descCtrl,
                                    decoration:
                                        const InputDecoration(
                                      labelText:
                                          'Description (optional)',
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
                                day.slots.add(
                                    _ScheduleSlotInput())),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(
                                        8),
                                border: Border.all(
                                    color: AppTheme
                                        .dividerOf(
                                            context)),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,
                                children: [
                                  Icon(Icons.add_rounded,
                                      size: 16,
                                      color: AppTheme
                                          .textSecondaryOf(
                                              context)),
                                  const SizedBox(width: 4),
                                  Text('Add Time Slot',
                                      style: TextStyle(
                                          fontWeight:
                                              FontWeight
                                                  .w600,
                                          fontSize: 12,
                                          color: AppTheme
                                              .textSecondaryOf(
                                                  context))),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  GestureDetector(
                    onTap: () => setState(() =>
                        _scheduleDays
                            .add(_ScheduleDayInput())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                AppTheme.dividerOf(context)),
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded,
                              size: 18,
                              color:
                                  AppTheme.textSecondaryOf(
                                      context)),
                          const SizedBox(width: 6),
                          Text('Add Date',
                              style: TextStyle(
                                  fontWeight:
                                      FontWeight.w600,
                                  fontSize: 13,
                                  color: AppTheme
                                      .textSecondaryOf(
                                          context))),
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
      ],
    );
  }

  Widget _buildStep4LocationSponsors() {
    return Form(
      key: _formKeys[3],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Location & Sponsors',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                if (_venuesLoading)
                  _buildLoadingChip('Loading venues…')
                else if (_venuesError != null)
                  _buildErrorRetry(_venuesError!, _loadVenues),
                _SearchableDropdown<Venue>(
                  label: 'Venue *',
                  hint: _venuesLoading ? 'Loading…' : 'Search venues…',
                  items: _venues,
                  selectedItem: _venues
                      .where((v) => v.id == _selectedVenueId)
                      .firstOrNull,
                  itemLabel: (v) => v.name,
                  itemSubtitle: (v) => 'Capacity: ${v.maxCapacity}',
                  filter: (v, q) =>
                      v.name.toLowerCase().contains(q.toLowerCase()),
                  onSelected: (v) =>
                      setState(() => _selectedVenueId = v?.id),
                  validator: (_) => _selectedVenueId == null
                      ? 'Please select a venue'
                      : null,
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(
                      () => _showVenueForm = !_showVenueForm),
                  child: Row(
                    children: [
                      Icon(
                        _showVenueForm
                            ? Icons.expand_less
                            : Icons.add_location_alt,
                        size: 20,
                        color: AppTheme.primaryOf(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _showVenueForm
                            ? 'Hide venue form'
                            : 'Create a new venue',
                        style: TextStyle(
                          color: AppTheme.primaryOf(context),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Card(
                    margin: const EdgeInsets.only(top: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          Text('New Venue',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                      fontWeight:
                                          FontWeight.bold)),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _venueNameCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Venue Name'),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _venueAddressCtrl,
                            decoration: InputDecoration(
                              labelText: 'Address',
                              suffixIcon: _venueGeocoding
                                  ? const Padding(
                                      padding:
                                          EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child:
                                            CircularProgressIndicator(
                                                strokeWidth:
                                                    2),
                                      ),
                                    )
                                  : _venueLat != null
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: AppTheme
                                              .successColor,
                                          size: 18)
                                      : null,
                            ),
                            onChanged: _onVenueAddressChanged,
                          ),
                          if (_showVenueGeoSuggestions &&
                              _venueGeoSuggestions.isNotEmpty)
                            Container(
                              constraints:
                                  const BoxConstraints(
                                      maxHeight: 160),
                              margin:
                                  const EdgeInsets.only(
                                      top: 2),
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.cardOf(context),
                                borderRadius:
                                    BorderRadius.circular(
                                        10),
                                border: Border.all(
                                    color: AppTheme
                                        .dividerColor),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withValues(
                                            alpha: 0.06),
                                    blurRadius: 8,
                                    offset:
                                        const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount:
                                    _venueGeoSuggestions
                                        .length,
                                separatorBuilder:
                                    (_, __) =>
                                        const Divider(
                                            height: 1),
                                itemBuilder: (context, i) {
                                  final s =
                                      _venueGeoSuggestions[
                                          i];
                                  return ListTile(
                                    dense: true,
                                    leading: Icon(
                                        Icons
                                            .location_on_outlined,
                                        size: 18,
                                        color: AppTheme
                                            .textSecondaryOf(
                                                context)),
                                    title: Text(
                                        s.fullAddress,
                                        style:
                                            const TextStyle(
                                                fontSize:
                                                    12),
                                        maxLines: 2,
                                        overflow:
                                            TextOverflow
                                                .ellipsis),
                                    onTap: () =>
                                        _selectVenueGeoSuggestion(
                                            s),
                                  );
                                },
                              ),
                            ),
                          if (_venueLat != null &&
                              _venueLng != null)
                            Padding(
                              padding:
                                  const EdgeInsets.only(
                                      top: 4),
                              child: Text(
                                'Location: ${_venueLat!.toStringAsFixed(4)}, ${_venueLng!.toStringAsFixed(4)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme
                                      .successColor,
                                  fontWeight:
                                      FontWeight.w500,
                                ),
                              ),
                            ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller:
                                      _venueCityCtrl,
                                  decoration:
                                      const InputDecoration(
                                          labelText:
                                              'City'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller:
                                      _venueProvinceCtrl,
                                  decoration:
                                      const InputDecoration(
                                          labelText:
                                              'Province'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller:
                                _venueCapacityCtrl,
                            decoration:
                                const InputDecoration(
                                    labelText:
                                        'Max Capacity'),
                            keyboardType:
                                TextInputType.number,
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
                                              strokeWidth:
                                                  2,
                                              color: Colors
                                                  .white),
                                    )
                                  : const Icon(
                                      Icons.check,
                                      size: 18),
                              label: Text(_creatingVenue
                                  ? 'Creating...'
                                  : 'Create & Select Venue'),
                              style:
                                  ElevatedButton.styleFrom(
                                backgroundColor: AppTheme
                                    .secondaryColor,
                                foregroundColor:
                                    Colors.white,
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
                TextFormField(
                  controller: _capacityCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Max Capacity *'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (int.tryParse(v) == null) {
                      return 'Enter a number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                _buildTransportSection(),
                const SizedBox(height: 16),
                _buildSponsorshipSection(),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _communityRules
                        ? Colors.orange.withValues(alpha: 0.08)
                        : AppTheme.cardOf(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _communityRules
                            ? Colors.orange
                                .withValues(alpha: 0.4)
                            : AppTheme.dividerOf(context)),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Row(
                          children: [
                            Icon(Icons.groups_rounded,
                                size: 20,
                                color: _communityRules
                                    ? Colors.orange
                                    : AppTheme
                                        .textSecondaryOf(
                                            context)),
                            const SizedBox(width: 8),
                            const Text(
                                'Community Event Rules',
                                style: TextStyle(
                                    fontWeight:
                                        FontWeight.w600,
                                    fontSize: 14)),
                          ],
                        ),
                        subtitle: const Text(
                          'Enables max duration, ticket price caps, and listing fee',
                          style: TextStyle(fontSize: 11),
                        ),
                        value: _communityRules,
                        activeColor: Colors.orange,
                        onChanged: (v) => setState(
                            () => _communityRules = v),
                      ),
                      if (_communityRules) ...[
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 4, bottom: 10),
                          child: Text(
                            '\u2022 Max duration: configurable (default 14 days)\n'
                            '\u2022 Max ticket price: configurable (default \$50)\n'
                            '\u2022 Listing fee charged on publish\n'
                            '\u2022 Rules are set by platform admin in Settings',
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    AppTheme.textSecondaryOf(
                                        context),
                                height: 1.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text(
                      'Enable event feed / posts',
                      style: TextStyle(
                          fontWeight: FontWeight.w600)),
                  subtitle: const Text(
                      'Registered users can post on the event wall'),
                  value: _postsEnabled,
                  activeColor: AppTheme.accentColor,
                  onChanged: (v) =>
                      setState(() => _postsEnabled = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(
              () => _showTransportSection = !_showTransportSection),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _showTransportSection
                  ? AppTheme.primaryOf(context)
                      .withValues(alpha: 0.05)
                  : AppTheme.cardOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showTransportSection
                    ? AppTheme.primaryOf(context)
                        .withValues(alpha: 0.2)
                    : AppTheme.dividerOf(context),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.directions_car_rounded,
                    size: 18,
                    color: _showTransportSection
                        ? AppTheme.primaryOf(context)
                        : AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      'Parking & Transport Info (Optional)',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color:
                              AppTheme.textPrimaryOf(context))),
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
              color: AppTheme.cardOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.dividerOf(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _parkingCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Parking',
                    hintText:
                        'e.g. Free parking lot behind the venue',
                    prefixIcon: Icon(
                        Icons.local_parking_rounded,
                        size: 20),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _transitCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Public Transit',
                    hintText:
                        'e.g. Take the Blue Line to Central Station',
                    prefixIcon: Icon(
                        Icons.directions_transit_rounded,
                        size: 20),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _rideshareCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Rideshare / Taxi',
                    hintText:
                        'e.g. Drop-off at Gate 3 entrance',
                    prefixIcon: Icon(
                        Icons.local_taxi_rounded,
                        size: 20),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _accessibilityCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Accessibility',
                    hintText:
                        'e.g. Wheelchair ramp at main entrance',
                    prefixIcon: Icon(
                        Icons.accessible_rounded,
                        size: 20),
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
      ],
    );
  }

  Widget _buildSponsorshipSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(() =>
              _showSponsorshipSection = !_showSponsorshipSection),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _showSponsorshipSection
                  ? Colors.teal.withValues(alpha: 0.08)
                  : AppTheme.cardOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showSponsorshipSection
                    ? Colors.teal.withValues(alpha: 0.3)
                    : AppTheme.dividerOf(context),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.storefront_rounded,
                    size: 18,
                    color: _showSponsorshipSection
                        ? Colors.teal
                        : AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      'Sponsorship Categories (Optional)',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color:
                              AppTheme.textPrimaryOf(context))),
                ),
                if (_sponsorCategories.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          Colors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                        '${_sponsorCategories.length}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal)),
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
              color: AppTheme.cardOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.dividerOf(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0;
                    i < _sponsorCategories.length;
                    i++) ...[
                  _buildSponsorCategoryCard(i),
                  if (i < _sponsorCategories.length - 1)
                    const SizedBox(height: 10),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() =>
                        _sponsorCategories
                            .add(_SponsorCategoryInput())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Category'),
                  ),
                ),
              ],
            ),
          ),
          crossFadeState: _showSponsorshipSection
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  Widget _buildStep5Review() {
    final venueName = _venues
        .where((v) => v.id == _selectedVenueId)
        .firstOrNull
        ?.name;
    final strategyName = _strategies
        .where((s) => s.id == _selectedStrategyId)
        .firstOrNull
        ?.name;

    return Form(
      key: _formKeys[4],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Review & Publish',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  'Review your event details. Tap any section to edit.',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context)),
                ),
                const SizedBox(height: 20),
                _reviewCard(
                  step: 0,
                  icon: Icons.edit_note_rounded,
                  color: Colors.indigo,
                  title: 'Basics',
                  items: {
                    'Title': _titleCtrl.text.trim(),
                    'Genre': _genre ?? '',
                    'Images': _pickedImages.isEmpty
                        ? ''
                        : '${_pickedImages.length} selected',
                  },
                ),
                _reviewCard(
                  step: 1,
                  icon: Icons.attach_money_rounded,
                  color: Colors.teal,
                  title: 'Funding',
                  items: {
                    'Deadline': _fundingEndAt != null
                        ? _fmtDt(_fundingEndAt!)
                        : 'Not set',
                    if (_fundingEndAt != null) ...{
                      'Goal': _fundingGoalCtrl.text.isNotEmpty
                          ? '\$${_fundingGoalCtrl.text}'
                          : 'Not set',
                      'Min Pledge': '\$${_minPledgeCtrl.text}',
                      'Milestones': _milestones.isEmpty
                          ? 'None'
                          : '${_milestones.length}',
                    },
                  },
                ),
                _reviewCard(
                  step: 2,
                  icon: Icons.event_rounded,
                  color: Colors.blue,
                  title: 'Dates & Tickets',
                  items: {
                    'Start': _startTime != null
                        ? _fmtDt(_startTime!)
                        : 'Not set',
                    'End': _endTime != null
                        ? _fmtDt(_endTime!)
                        : 'Not set',
                    'Registration':
                        _registrationType == 'open'
                            ? 'Open'
                            : 'Closed (Waitlist)',
                    'Ticket Strategy':
                        strategyName ?? 'Not set',
                    'Discounts': _selectedDiscounts.isEmpty
                        ? 'None'
                        : '${_selectedDiscounts.length} selected',
                  },
                ),
                _reviewCard(
                  step: 3,
                  icon: Icons.location_on_rounded,
                  color: Colors.orange,
                  title: 'Location & Sponsors',
                  items: {
                    'Venue': venueName ?? 'Not set',
                    'Capacity': _capacityCtrl.text.isNotEmpty
                        ? _capacityCtrl.text
                        : 'Not set',
                    'Sponsors': _sponsorCategories.isEmpty
                        ? 'None'
                        : '${_sponsorCategories.length} categories',
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: Text(
                    _publish
                        ? 'Publish immediately'
                        : 'Save as draft',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _publish
                        ? 'Event will be visible to everyone right away'
                        : 'You can publish it later from the event detail page',
                  ),
                  value: _publish,
                  activeColor: AppTheme.accentColor,
                  onChanged: (v) =>
                      setState(() => _publish = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _reviewCard({
    required int step,
    required IconData icon,
    required Color color,
    required String title,
    required Map<String, String> items,
  }) {
    return GestureDetector(
      onTap: () => _goToStep(step),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: color)),
                ),
                Text('Edit',
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                Icon(Icons.chevron_right,
                    size: 16, color: color),
              ],
            ),
            const SizedBox(height: 10),
            ...items.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(e.key,
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    AppTheme.textSecondaryOf(
                                        context))),
                      ),
                      Expanded(
                        child: Text(
                          e.value.isNotEmpty
                              ? e.value
                              : 'Not set',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: e.value.isNotEmpty
                                ? FontWeight.w500
                                : FontWeight.normal,
                            color: e.value.isNotEmpty
                                ? AppTheme.textPrimaryOf(
                                    context)
                                : AppTheme.textSecondaryOf(
                                    context),
                            fontStyle: e.value.isNotEmpty
                                ? FontStyle.normal
                                : FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedStrategyPreview() {
    final s = _strategies
        .where((s) => s.id == _selectedStrategyId)
        .firstOrNull;
    if (s == null) return const SizedBox.shrink();
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
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(t.name,
                                  style: const TextStyle(
                                      fontWeight:
                                          FontWeight.w500))),
                          Text(t.priceFormatted,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme
                                      .successColor)),
                        ],
                      ),
                      if (t.description != null &&
                          t.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 15, top: 2),
                          child: Text(t.description!,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme
                                      .textSecondaryOf(
                                          context),
                                  fontStyle:
                                      FontStyle.italic)),
                        ),
                    ],
                  ),
                )),
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
                Icon(Icons.layers,
                    size: 16,
                    color: AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 6),
                Text('Tiers',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addStrategyTier,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add',
                      style: TextStyle(fontSize: 12)),
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
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text('Tier ${i + 1}',
                              style: const TextStyle(
                                  fontWeight:
                                      FontWeight.w600,
                                  fontSize: 12)),
                          const Spacer(),
                          if (_strategyTiers.length > 1)
                            IconButton(
                              onPressed: () =>
                                  _removeStrategyTier(i),
                              icon: const Icon(Icons.close,
                                  size: 16,
                                  color:
                                      AppTheme.errorColor),
                              padding: EdgeInsets.zero,
                              constraints:
                                  const BoxConstraints(),
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
                              decoration:
                                  const InputDecoration(
                                labelText: 'Name',
                                hintText:
                                    'e.g. Platinum',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: t.priceCtrl,
                              decoration:
                                  const InputDecoration(
                                labelText: 'Price (\$)',
                                prefixText: '\$ ',
                                isDense: true,
                              ),
                              keyboardType:
                                  TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: t.descCtrl,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Description (what this tier provides)',
                          hintText:
                              'e.g. Front row seating, backstage access',
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
                onPressed: _creatingStrategy
                    ? null
                    : _createStrategyInline,
                icon: _creatingStrategy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white),
                      )
                    : const Icon(Icons.check, size: 18),
                label: Text(_creatingStrategy
                    ? 'Creating...'
                    : 'Create & Select Strategy'),
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

  Widget _buildSponsorCategoryCard(int index) {
    final sc = _sponsorCategories[index];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: Colors.teal.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Category ${index + 1}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(
                    () => _sponsorCategories.removeAt(index)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: sc.nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Category Name *',
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
                      const TextInputType.numberWithOptions(
                          decimal: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StrategyTierInput {
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
}

class _MilestoneInput {
  final titleCtrl = TextEditingController();
  final benefitCtrl = TextEditingController();
  int unlockPercent = 50;
}

class _ScheduleDayInput {
  DateTime? date;
  final List<_ScheduleSlotInput> slots = [];
}

class _ScheduleSlotInput {
  TimeOfDay startTime;
  TimeOfDay endTime;
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  _ScheduleSlotInput()
      : startTime = const TimeOfDay(hour: 9, minute: 0),
        endTime = const TimeOfDay(hour: 10, minute: 0);
}

class _SponsorCategoryInput {
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final spotsCtrl = TextEditingController(text: '1');
  final minBidCtrl = TextEditingController(text: '100.00');
}

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
                  color: AppTheme.cardOf(context),
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
                                  fontSize: 11,
                                  color: AppTheme.textSecondaryOf(context)))
                          : null,
                      trailing: isSelected
                          ? Icon(Icons.check_circle,
                              size: 18,
                              color: Theme.of(context).primaryColor)
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

class _CreateDiscountBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CreateDiscountBtn(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
