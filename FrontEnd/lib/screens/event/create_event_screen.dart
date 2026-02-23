import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/event.dart';
import '../../models/venue.dart';
import '../../models/ticket_strategy.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/mapbox_geocoding_service.dart';
import '../../widgets/app_toast.dart';
import '../../models/event_form_models.dart';
import 'create_event/step_basics.dart';
import 'create_event/step_dates_registration.dart';
import 'create_event/step_tickets_funding.dart';
import 'create_event/step_discounts_milestones.dart';
import 'create_event/step_location_sponsors.dart';
import 'create_event/step_review.dart';
import 'event_detail_screen.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  // ── Wizard state ──
  int _currentStep = 0;
  final List<GlobalKey<FormState>> _formKeys =
      List.generate(6, (_) => GlobalKey<FormState>());
  static const _stepLabels = [
    'Basics',
    'Dates',
    'Tickets',
    'Discounts',
    'Location',
    'Review',
  ];
  static const _stepIcons = [
    Icons.edit_note_rounded,
    Icons.event_rounded,
    Icons.confirmation_number_rounded,
    Icons.discount_rounded,
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
  bool _linkFundingToTiers = false;
  int _maxDiscountPercent = 100;
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
  List<EditableTier> _localTiers = [];
  bool _creatingStrategy = false;
  final _strategyNameCtrl = TextEditingController();
  final List<StrategyTierInput> _strategyTiers = [StrategyTierInput()];

  // Discount strategies
  List<Map<String, dynamic>> _discountStrategies = [];
  final Map<int, bool> _selectedDiscounts = {};

  // Parking & Transport
  final _parkingCtrl = TextEditingController();
  final _transitCtrl = TextEditingController();
  final _rideshareCtrl = TextEditingController();
  final _accessibilityCtrl = TextEditingController();

  // Funding Milestones
  final List<MilestoneInput> _milestones = [];

  // Early Bird Discounts
  final List<EarlyBirdInput> _earlyBirdDiscounts = [];

  // Event Schedule
  bool _hasSchedule = false;
  final List<ScheduleDayInput> _scheduleDays = [];

  // Sponsorship Categories (template-based)
  List<Map<String, dynamic>> _sponsorTemplates = [];
  List<EditableSponsorCategory> _localCategories = [];
  bool _loadingTemplates = false;

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
    _loadSponsorTemplates();
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

  Future<void> _loadSponsorTemplates() async {
    setState(() => _loadingTemplates = true);
    try {
      final api = context.read<ApiService>();
      final data = await api.getSponsorCategoryTemplates();
      if (mounted) setState(() { _sponsorTemplates = data.cast<Map<String, dynamic>>(); _loadingTemplates = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingTemplates = false);
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
      setState(() => _strategyTiers.add(StrategyTierInput()));

  void _removeStrategyTier(int i) {
    if (_strategyTiers.length > 1) setState(() => _strategyTiers.removeAt(i));
  }

  void _addLocalTier() => setState(() => _localTiers.add(EditableTier()));

  void _removeLocalTier(int i) {
    if (_localTiers.length > 1) setState(() => _localTiers.removeAt(i));
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
      final newStrategy = _strategies.where((s) => s.id == newId).firstOrNull;
      setState(() {
        _selectedStrategyId = newId;
        _localTiers = (newStrategy?.tiers ?? []).map((t) {
          final lt = EditableTier();
          lt.nameCtrl.text = t.name;
          lt.priceCtrl.text = (t.priceCents / 100).toStringAsFixed(2);
          lt.descCtrl.text = t.description ?? '';
          return lt;
        }).toList();
        _strategyNameCtrl.clear();
        _strategyTiers.clear();
        _strategyTiers.add(StrategyTierInput());
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

  void _goToStep(int step) {
    if (step >= 0 && step < _stepLabels.length && step <= _currentStep) {
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
        if (_fundingEndAt == null && (_startTime == null || _endTime == null)) {
          return fail('Set both start & end dates, or set a funding deadline');
        }
        if (_startTime != null && _endTime == null) return fail('End time is required when start time is set');
        if (_startTime != null && _endTime != null && !_endTime!.isAfter(_startTime!)) {
          return fail('End time must be after start time');
        }
        if (_startTime != null && _fundingEndAt != null && !_startTime!.isAfter(_fundingEndAt!)) {
          return fail('Event start must be after funding deadline');
        }
        return pass();
      case 2:
        if (_capacityCtrl.text.trim().isEmpty || int.tryParse(_capacityCtrl.text.trim()) == null) {
          return fail('Please enter a valid max capacity');
        }
        return pass();
      case 3:
        return pass();
      case 4:
        if (_selectedVenueId == null) return fail('Please select a venue');
        return pass();
      case 5:
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
      setState(() => _currentStep = 1);
      return;
    }
    if (_startTime != null && _endTime == null) {
      AppToast.error(context, 'End time is required when start time is set');
      setState(() => _currentStep = 1);
      return;
    }
    if (_startTime != null &&
        _fundingEndAt != null &&
        !_startTime!.isAfter(_fundingEndAt!)) {
      AppToast.error(
          context, 'Event start time must be after the funding deadline');
      setState(() => _currentStep = 1);
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
      setState(() => _currentStep = 4);
      return;
    }
    final capVal = int.tryParse(_capacityCtrl.text.trim());
    if (capVal == null) {
      AppToast.error(context, 'Please enter a valid max capacity');
      setState(() => _currentStep = 2);
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
    if (_linkFundingToTiers) data['link_funding_to_tiers'] = true;
    if (_maxDiscountPercent != 100) {
      data['max_discount_percent'] = _maxDiscountPercent;
    }

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

      if (_localTiers.isNotEmpty) {
        for (int i = 0; i < _localTiers.length; i++) {
          final t = _localTiers[i];
          final name = t.nameCtrl.text.trim();
          if (name.isEmpty) continue;
          try {
            final tierData = <String, dynamic>{
              'name': name,
              'price_cents': ((double.tryParse(t.priceCtrl.text) ?? 0) * 100).toInt(),
              'display_order': i,
              if (t.descCtrl.text.trim().isNotEmpty)
                'description': t.descCtrl.text.trim(),
              if (t.maxReservedSpots > 0)
                'max_reserved_spots': t.maxReservedSpots,
            };
            await api.createTicketTier(eventId, tierData);
          } catch (_) {}
        }
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
        // Create milestone discount rule if a discount value is set
        final discVal = int.tryParse(ms.discountValueCtrl.text.trim()) ?? 0;
        if (discVal > 0) {
          try {
            await api.createEventDiscount(eventId, {
              'name': 'Milestone ${ms.unlockPercent}% discount',
              'discount_type': 'funding_milestone',
              'value': discVal,
              'target': 'pledgers',
              'milestone_percent': ms.unlockPercent,
              'milestone_discount_value': discVal,
            });
          } catch (_) {}
        }
      }

      // Create early bird discounts
      for (final eb in _earlyBirdDiscounts) {
        final val = int.tryParse(eb.valueCtrl.text.trim()) ?? 0;
        if (val <= 0 || eb.windowEnd == null) continue;
        try {
          await api.createEarlyBirdDiscount(eventId, {
            'applies_to': eb.appliesTo,
            'discount_type': eb.discountType,
            'value': val,
            'window_end': eb.windowEnd!.toUtc().toIso8601String(),
          });
        } catch (_) {}
      }

      if (_hasSchedule && _scheduleDays.isNotEmpty) {
        final scheduleItems = <Map<String, dynamic>>[];
        final slotsWithImages = <int, ScheduleSlotInput>{};
        for (final day in _scheduleDays) {
          if (day.date == null) continue;
          final dateStr =
              '${day.date!.year}-${day.date!.month.toString().padLeft(2, '0')}-${day.date!.day.toString().padLeft(2, '0')}';
          for (int i = 0; i < day.slots.length; i++) {
            final slot = day.slots[i];
            final title = slot.titleCtrl.text.trim();
            if (title.isEmpty) continue;
            final itemIdx = scheduleItems.length;
            scheduleItems.add({
              'date': dateStr,
              'start_time':
                  '${slot.startTime.hour.toString().padLeft(2, '0')}:${slot.startTime.minute.toString().padLeft(2, '0')}',
              'end_time':
                  '${slot.endTime.hour.toString().padLeft(2, '0')}:${slot.endTime.minute.toString().padLeft(2, '0')}',
              'title': title,
              if (slot.descCtrl.text.trim().isNotEmpty)
                'description': slot.descCtrl.text.trim(),
              if (slot.pickedImageBytes == null &&
                  slot.imageUrlCtrl.text.trim().isNotEmpty)
                'image_url': slot.imageUrlCtrl.text.trim(),
              if (slot.imageCaptionCtrl.text.trim().isNotEmpty)
                'image_caption': slot.imageCaptionCtrl.text.trim(),
              if (slot.linkUrlCtrl.text.trim().isNotEmpty)
                'link_url': slot.linkUrlCtrl.text.trim(),
              'sort_order': i,
            });
            if (slot.pickedImageBytes != null) {
              slotsWithImages[itemIdx] = slot;
            }
          }
        }
        if (scheduleItems.isNotEmpty) {
          try {
            final created =
                await api.bulkCreateSchedule(eventId, scheduleItems);
            for (final entry in slotsWithImages.entries) {
              final idx = entry.key;
              final slot = entry.value;
              if (idx < created.length) {
                final itemId = created[idx]['id'] as int;
                try {
                  await api.uploadScheduleImage(
                    eventId,
                    itemId,
                    slot.pickedImageBytes!,
                    slot.pickedImageName ?? 'image.png',
                    caption: slot.imageCaptionCtrl.text.trim().isNotEmpty
                        ? slot.imageCaptionCtrl.text.trim()
                        : null,
                  );
                } catch (_) {}
              }
            }
          } catch (_) {}
        }
      }

      for (final cat in _localCategories) {
        final name = cat.nameCtrl.text.trim();
        if (name.isEmpty) continue;
        try {
          final catResp = await api.createSponsorshipCategory(eventId, {
            'name': name,
            'description': cat.descCtrl.text.trim(),
            'total_spots': int.tryParse(cat.spotsCtrl.text) ?? 1,
            'min_bid_cents': ((double.tryParse(cat.minBidCtrl.text) ?? 0) * 100).round(),
          });
          final catId = catResp['id'] as int;
          for (final p in cat.prereqs) {
            try {
              await api.createPrerequisite(eventId, catId,
                  name: p.name, description: p.description, isRequired: p.isRequired, requiresDocument: p.requiresDocument);
            } catch (_) {}
          }
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
                _buildStep0Basics(),
                _buildStep1DatesRegistration(),
                _buildStep2TicketsFunding(),
                _buildStep3DiscountsMilestones(),
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
          final canTap = step < _currentStep;
          return GestureDetector(
            onTap: canTap ? () => _goToStep(step) : null,
            child: Opacity(
              opacity: step > _currentStep ? 0.45 : 1.0,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (!isFirst) ...[
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep0Basics() {
    return StepBasics(
      formKey: _formKeys[0],
      titleCtrl: _titleCtrl,
      descCtrl: _descCtrl,
      genre: _genre,
      genres: _genres,
      onGenreChanged: (v) => setState(() => _genre = v),
      imageCount: _pickedImages.length,
      imageBytes: _imageBytes,
      onPickImages: () => _pickImages(),
      onPickSingleImage: () => _pickImages(singleMode: true),
      onRemoveImage: _removeImage,
      onMarkDirty: () { _markDirty(); setState(() {}); },
    );
  }

  Widget _buildStep1DatesRegistration() {
    return StepDatesRegistration(
      formKey: _formKeys[1],
      startTime: _startTime,
      endTime: _endTime,
      onPickStartTime: () => _pickDateTime(true),
      onPickEndTime: () => _pickDateTime(false),
      onClearStartTime: () => setState(() => _startTime = null),
      onClearEndTime: () => setState(() => _endTime = null),
      registrationType: _registrationType,
      onRegistrationTypeChanged: (v) => setState(() => _registrationType = v ?? 'open'),
      fundingEndAt: _fundingEndAt,
      onPickFundingDeadline: _pickFundingDeadline,
      onClearFundingDeadline: () => setState(() => _fundingEndAt = null),
      refundDeadlineDays: _refundDeadlineDays,
      onRefundDeadlineDaysChanged: (v) =>
          setState(() => _refundDeadlineDays = v),
      milestones: _milestones,
      hasSchedule: _hasSchedule,
      onHasScheduleChanged: (v) => setState(() => _hasSchedule = v),
      scheduleDays: _scheduleDays,
      onMarkDirty: () => setState(() {}),
      fmtDt: _fmtDt,
    );
  }

  Widget _buildStep2TicketsFunding() {
    return StepTicketsFunding(
      formKey: _formKeys[2],
      capacityCtrl: _capacityCtrl,
      strategies: _strategies,
      strategiesLoading: _strategiesLoading,
      strategiesError: _strategiesError,
      onReloadStrategies: _loadStrategies,
      selectedStrategyId: _selectedStrategyId,
      onStrategyChanged: (id) => setState(() {
        _selectedStrategyId = id;
        final s = _strategies.where((s) => s.id == id).firstOrNull;
        _localTiers = (s?.tiers ?? []).map((t) {
          final lt = EditableTier();
          lt.nameCtrl.text = t.name;
          lt.priceCtrl.text = (t.priceCents / 100).toStringAsFixed(2);
          lt.descCtrl.text = t.description ?? '';
          return lt;
        }).toList();
      }),
      localTiers: _localTiers,
      onAddLocalTier: _addLocalTier,
      onRemoveLocalTier: _removeLocalTier,
      strategyTiers: _strategyTiers,
      onAddStrategyTier: _addStrategyTier,
      onRemoveStrategyTier: _removeStrategyTier,
      creatingStrategy: _creatingStrategy,
      strategyNameCtrl: _strategyNameCtrl,
      onCreateStrategyInline: _createStrategyInline,
      fundingEndAt: _fundingEndAt,
      fundingGoalCtrl: _fundingGoalCtrl,
      minPledgeCtrl: _minPledgeCtrl,
      maxReservedSpotsCtrl: _maxReservedSpotsCtrl,
      linkFundingToTiers: _linkFundingToTiers,
      onLinkFundingToTiersChanged: (v) => setState(() => _linkFundingToTiers = v),
      onMarkDirty: _markDirty,
      buildLoadingChip: _buildLoadingChip,
      buildErrorRetry: _buildErrorRetry,
    );
  }

  Widget _buildStep3DiscountsMilestones() {
    return StepDiscountsMilestones(
      formKey: _formKeys[3],
      discounts: _discountStrategies,
      discountsLoading: _discountsLoading,
      discountsError: _discountsError,
      onReloadDiscounts: _loadDiscounts,
      selectedDiscounts: _selectedDiscounts,
      onAddDiscount: (id, autoApply) => setState(() => _selectedDiscounts[id] = autoApply),
      onRemoveDiscount: (id) => setState(() => _selectedDiscounts.remove(id)),
      earlyBirdDiscounts: _earlyBirdDiscounts,
      maxDiscountPercent: _maxDiscountPercent,
      onMaxDiscountPercentChanged: (v) => setState(() => _maxDiscountPercent = v),
      fundingEndAt: _fundingEndAt,
      selectedStrategyId: _selectedStrategyId,
      onMarkDirty: _markDirty,
      fmtDt: _fmtDt,
      buildLoadingChip: _buildLoadingChip,
      buildErrorRetry: _buildErrorRetry,
    );
  }

  Widget _buildStep4LocationSponsors() {
    return StepLocationSponsors(
      formKey: _formKeys[4],
      venues: _venues,
      venuesLoading: _venuesLoading,
      venuesError: _venuesError,
      onReloadVenues: _loadVenues,
      selectedVenueId: _selectedVenueId,
      onVenueChanged: (id) => setState(() => _selectedVenueId = id),
      showVenueForm: _showVenueForm,
      onShowVenueFormChanged: (v) => setState(() => _showVenueForm = v),
      creatingVenue: _creatingVenue,
      venueNameCtrl: _venueNameCtrl,
      venueAddressCtrl: _venueAddressCtrl,
      venueCityCtrl: _venueCityCtrl,
      venueProvinceCtrl: _venueProvinceCtrl,
      venueCapacityCtrl: _venueCapacityCtrl,
      venueGeocoding: _venueGeocoding,
      venueLat: _venueLat,
      venueLng: _venueLng,
      geoSuggestions: _venueGeoSuggestions,
      showVenueGeoSuggestions: _showVenueGeoSuggestions,
      onVenueAddressChanged: _onVenueAddressChanged,
      onSelectGeoSuggestion: _selectVenueGeoSuggestion,
      onCreateVenueInline: _createVenueInline,
      parkingCtrl: _parkingCtrl,
      transitCtrl: _transitCtrl,
      rideshareCtrl: _rideshareCtrl,
      accessibilityCtrl: _accessibilityCtrl,
      communityRules: _communityRules,
      onCommunityRulesChanged: (v) => setState(() => _communityRules = v),
      postsEnabled: _postsEnabled,
      onPostsEnabledChanged: (v) => setState(() => _postsEnabled = v),
      localCategories: _localCategories,
      sponsorTemplates: _sponsorTemplates,
      templatesLoading: _loadingTemplates,
      onToggleSponsorTemplate: _toggleSponsorTemplate,
      onAddSponsorCategory: () {
        final cat = EditableSponsorCategory(expanded: true);
        cat.spotsCtrl.text = '1';
        cat.minBidCtrl.text = '100.00';
        setState(() {
          _localCategories.add(cat);
          _markDirty();
        });
      },
      onRemoveSponsorCategory: (cat) => setState(() {
        _localCategories.remove(cat);
        _markDirty();
      }),
      onManageTemplates: () async {
        await context.push('/sponsor-category-templates');
        _loadSponsorTemplates();
      },
      onMarkDirty: _markDirty,
      buildLoadingChip: _buildLoadingChip,
      buildErrorRetry: _buildErrorRetry,
    );
  }

  Future<void> _toggleSponsorTemplate(Map<String, dynamic> t) async {
    final id = t['id'] as int;
    final idx = _localCategories.indexWhere((c) => c.templateId == id);
    if (idx >= 0) {
      setState(() {
        _localCategories.removeAt(idx);
        _markDirty();
      });
      return;
    }
    final cat = EditableSponsorCategory(templateId: id, expanded: true);
    cat.nameCtrl.text = t['name'] ?? '';
    cat.descCtrl.text = (t['description'] as String?) ?? '';
    cat.spotsCtrl.text = '${t['total_spots'] ?? 1}';
    final minBid = t['min_bid_cents'] ?? 0;
    cat.minBidCtrl.text = (minBid / 100).toStringAsFixed(2);
    try {
      final prereqs = await Provider.of<ApiService>(context, listen: false)
          .listTemplatePrerequisites(id);
      for (final p in prereqs) {
        cat.prereqs.add(LocalPrerequisite(
          name: (p['name'] as String?) ?? '',
          description: (p['description'] as String?) ?? '',
          isRequired: p['is_required'] as bool? ?? true,
          requiresDocument: p['requires_document'] as bool? ?? false,
        ));
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _localCategories.add(cat);
      _markDirty();
    });
  }

  Event _buildPreviewEvent() {
    final user = context.read<AuthProvider>().user;
    final venue = _venues.where((v) => v.id == _selectedVenueId).firstOrNull;

    int parseCents(String text) {
      final val = double.tryParse(text) ?? 0;
      return (val * 100).round();
    }

    return Event(
      id: 0,
      organizerId: user?.id ?? 0,
      organizerName: user?.displayName ?? 'You',
      venueId: _selectedVenueId ?? 0,
      title: _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : 'Untitled Event',
      description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      startTime: _startTime,
      endTime: _endTime,
      fundingGoalCents: _fundingEndAt != null ? parseCents(_fundingGoalCtrl.text) : null,
      fundingEndAt: _fundingEndAt,
      minPledgeCents: parseCents(_minPledgeCtrl.text),
      status: EventStatus.draft,
      registrationType: _registrationType == 'open' ? RegistrationType.open : RegistrationType.closed,
      maxCapacity: int.tryParse(_capacityCtrl.text) ?? 0,
      commonDiscountPercent: 0,
      pledgeDiscountPercent: 0,
      genre: _genre,
      communityRules: _communityRules,
      postsEnabled: _postsEnabled,
      refundDeadlineDays: _refundDeadlineDays,
      ticketStrategyId: _selectedStrategyId,
      ticketStrategyName: _strategies.where((s) => s.id == _selectedStrategyId).firstOrNull?.name,
      venue: venue,
      hasSchedule: _hasSchedule && _scheduleDays.isNotEmpty,
      linkFundingToTiers: _linkFundingToTiers,
      createdAt: DateTime.now(),
    );
  }

  void _openPreview() {
    final previewImages = _imageBytes.values.toList();
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => EventDetailScreen(
          eventId: 0,
          previewEvent: _buildPreviewEvent(),
          previewImages: previewImages.isNotEmpty ? previewImages : null,
        ),
      ),
    );
  }

  Widget _buildStep5Review() {
    return StepReview(
      formKey: _formKeys[5],
      publishImmediately: _publish,
      onPublishChanged: (v) => setState(() => _publish = v),
      onGoToStep: _goToStep,
      onPreview: _openPreview,
      title: _titleCtrl.text,
      genre: _genre,
      imageCount: _pickedImages.length,
      fundingEndAt: _fundingEndAt,
      fundingGoal: _fundingGoalCtrl.text,
      minPledge: _minPledgeCtrl.text,
      linkFundingToTiers: _linkFundingToTiers,
      milestones: _milestones,
      startTime: _startTime,
      endTime: _endTime,
      registrationType: _registrationType,
      selectedStrategyName: _strategies
          .where((s) => s.id == _selectedStrategyId)
          .firstOrNull
          ?.name,
      localTiers: _localTiers,
      selectedDiscountCount: _selectedDiscounts.length,
      selectedVenueName: _venues
          .where((v) => v.id == _selectedVenueId)
          .firstOrNull
          ?.name,
      capacity: _capacityCtrl.text,
      localCategories: _localCategories,
    );
  }

}
