import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/discount.dart';
import '../../models/event_form_models.dart';
import '../../models/sponsor.dart';
import '../../models/venue.dart';
import '../../models/ticket_strategy.dart';
import '../../providers/event_provider.dart';
import '../../providers/ticket_provider.dart';
import '../../providers/sponsor_provider.dart';
import '../../providers/venue_provider.dart';
import '../../services/mapbox_geocoding_service.dart';
import '../../widgets/app_toast.dart';
import 'package:provider/provider.dart';
import 'create_event/bottom_nav.dart';
import 'create_event/create_event_actions.dart';
import 'create_event/create_event_helpers.dart';
import 'create_event/create_event_submit.dart';
import 'create_event/event_policies_section.dart';
import 'create_event/step_basics.dart';
import 'create_event/step_dates_registration.dart';
import 'create_event/step_discounts_milestones.dart';
import 'create_event/step_indicator.dart';
import 'create_event/step_location_sponsors.dart';
import 'create_event/step_review.dart';
import 'create_event/step_tickets_funding.dart';
import 'event_detail_screen.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  int _currentStep = 0;
  final List<GlobalKey<FormState>> _formKeys = List.generate(6, (_) => GlobalKey<FormState>());
  static const _stepLabels = ['Basics', 'Dates', 'Tickets', 'Discounts', 'Location', 'Review'];
  static const _stepIcons = [
    Icons.edit_note_rounded, Icons.event_rounded, Icons.confirmation_number_rounded,
    Icons.discount_rounded, Icons.location_on_rounded, Icons.check_circle_rounded,
  ];

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
  bool _communityRulesFeatureEnabled = true;
  bool _postsEnabled = true;
  int _refundDeadlineDays = 7;
  bool _linkFundingToTiers = false;
  int _maxDiscountPercent = 100;
  bool _ageRestricted = false;
  int _minAge = 18;

  final _waitlistMaxSizeCtrl = TextEditingController();
  bool _waitlistAutoApprove = true;
  final _eventMaxImagesCtrl = TextEditingController();
  final _maxPostsPerDayCtrl = TextEditingController();
  final _maxCoOrganizersCtrl = TextEditingController();
  Map<String, int> _platformLimits = {};
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

  bool _showVenueForm = false;
  bool _creatingVenue = false;
  final _venueNameCtrl = TextEditingController();
  final _venueAddressCtrl = TextEditingController();
  final _venueCityCtrl = TextEditingController();
  final _venueProvinceCtrl = TextEditingController();
  final _venueCapacityCtrl = TextEditingController();

  double? _venueLat;
  double? _venueLng;
  List<GeocodingResult> _venueGeoSuggestions = [];
  bool _showVenueGeoSuggestions = false;
  bool _venueGeocoding = false;
  Timer? _venueGeoDebounce;

  List<TicketStrategy> _strategies = [];
  int? _selectedStrategyId;
  List<EditableTier> _localTiers = [];
  bool _creatingStrategy = false;
  final _strategyNameCtrl = TextEditingController();
  final List<StrategyTierInput> _strategyTiers = [StrategyTierInput()];

  List<DiscountStrategy> _discountStrategies = [];
  final Map<int, bool> _selectedDiscounts = {};

  final _parkingCtrl = TextEditingController();
  final _transitCtrl = TextEditingController();
  final _rideshareCtrl = TextEditingController();
  final _accessibilityCtrl = TextEditingController();

  final List<MilestoneInput> _milestones = [];
  final List<EarlyBirdInput> _earlyBirdDiscounts = [];
  bool _hasSchedule = false;
  final List<ScheduleDayInput> _scheduleDays = [];

  List<SponsorCategoryTemplate> _sponsorTemplates = [];
  final List<EditableSponsorCategory> _localCategories = [];
  bool _loadingTemplates = false;

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
    _loadFeatureFlags();
  }

  @override
  void dispose() {
    for (final c in [_titleCtrl, _descCtrl, _capacityCtrl, _fundingGoalCtrl, _minPledgeCtrl,
        _maxReservedSpotsCtrl, _venueNameCtrl, _venueAddressCtrl, _venueCityCtrl,
        _venueProvinceCtrl, _venueCapacityCtrl, _strategyNameCtrl, _parkingCtrl, _transitCtrl,
        _rideshareCtrl, _accessibilityCtrl, _waitlistMaxSizeCtrl, _eventMaxImagesCtrl,
        _maxPostsPerDayCtrl, _maxCoOrganizersCtrl]) {
      c.dispose();
    }
    _venueGeoDebounce?.cancel();
    for (final t in _strategyTiers) { t.nameCtrl.dispose(); t.descCtrl.dispose(); t.priceCtrl.dispose(); }
    super.dispose();
  }

  // ── Data loading ──

  Future<void> _loadFeatureFlags() async {
    try {
      final repo = context.read<EventProvider>();
      final config = await repo.getPublicConfig();
      if (mounted) { setState(() {
        _communityRulesFeatureEnabled = config['feature_community_rules_enabled'] == true;
        if (!_communityRulesFeatureEnabled) { _communityRules = false; }
        _platformLimits = {
          for (final key in [
            'waitlist_max_size_limit', 'event_max_images_limit',
            'max_posts_per_event_limit', 'max_co_organizers_limit',
          ])
            if (config[key] is int) key: config[key] as int,
        };
      }); }
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _loadVenues() async {
    setState(() { _venuesLoading = true; _venuesError = null; });
    try {
      final data = await context.read<VenueProvider>().getVenues();
      if (mounted) setState(() { _venues = data; _venuesLoading = false; });
    } catch (e) { if (mounted) setState(() { _venuesError = 'Failed to load venues'; _venuesLoading = false; }); }
  }

  Future<void> _loadStrategies() async {
    setState(() { _strategiesLoading = true; _strategiesError = null; });
    try {
      final data = await context.read<TicketProvider>().getTicketStrategies();
      if (mounted) setState(() { _strategies = data; _strategiesLoading = false; });
    } catch (e) { if (mounted) setState(() { _strategiesError = 'Failed to load strategies'; _strategiesLoading = false; }); }
  }

  Future<void> _loadDiscounts() async {
    setState(() { _discountsLoading = true; _discountsError = null; });
    try {
      final data = await context.read<TicketProvider>().getDiscountStrategies();
      if (mounted) setState(() { _discountStrategies = data; _discountsLoading = false; });
    } catch (e) { if (mounted) setState(() { _discountsError = 'Failed to load discounts'; _discountsLoading = false; }); }
  }

  Future<void> _loadSponsorTemplates() async {
    setState(() => _loadingTemplates = true);
    try {
      final data = await context.read<SponsorProvider>().getSponsorCategoryTemplates();
      if (mounted) setState(() { _sponsorTemplates = data; _loadingTemplates = false; });
    } catch (_) { if (mounted) setState(() => _loadingTemplates = false); }
  }

  // ── Helpers ──

  void _markDirty() { if (!_isDirty) setState(() => _isDirty = true); }

  bool get _hasAnyInput =>
      _titleCtrl.text.trim().isNotEmpty || _descCtrl.text.trim().isNotEmpty ||
      _genre != null || _pickedImages.isNotEmpty || _fundingEndAt != null ||
      _startTime != null || _endTime != null || _selectedVenueId != null || _selectedStrategyId != null;

  // ── Actions (delegated to create_event_actions.dart) ──

  Future<void> _pickImages({bool singleMode = false}) async {
    try {
      final picked = await pickEventImages(_imagePicker, singleMode: singleMode);
      if (picked.isEmpty) return;
      for (final xFile in picked) {
        final bytes = await xFile.readAsBytes();
        _imageBytes[_pickedImages.length] = bytes;
        _pickedImages.add(xFile);
      }
      if (mounted) setState(() {});
    } catch (e) { if (mounted) AppToast.error(context, 'Could not pick images: $e'); }
  }

  void _removeImage(int index) {
    setState(() => removeEventImage(index, _pickedImages, _imageBytes));
  }

  void _onVenueAddressChanged(String query) {
    _venueLat = null; _venueLng = null;
    onVenueAddressChanged(query,
      getDebounce: () => _venueGeoDebounce,
      setDebounce: (t) => _venueGeoDebounce = t,
      updateState: ({suggestions, showSuggestions, geocoding}) {
        if (!mounted) return;
        setState(() {
          if (suggestions != null) _venueGeoSuggestions = suggestions;
          if (showSuggestions != null) _showVenueGeoSuggestions = showSuggestions;
          if (geocoding != null) _venueGeocoding = geocoding;
        });
      },
    );
  }

  void _selectVenueGeoSuggestion(GeocodingResult result) {
    selectVenueGeoSuggestion(result,
      addressCtrl: _venueAddressCtrl, cityCtrl: _venueCityCtrl, provinceCtrl: _venueProvinceCtrl,
      onLatLng: (lat, lng) { _venueLat = lat; _venueLng = lng; },
      onClear: () {},
    );
    setState(() { _showVenueGeoSuggestions = false; _venueGeoSuggestions = []; });
  }

  Future<void> _pickDateTime(bool isStart) async {
    await pickEventDateTime(context,
      isStart: isStart, currentStartTime: _startTime, currentEndTime: _endTime, fundingEndAt: _fundingEndAt,
      onPicked: (dt, isStartPicked) { _markDirty(); setState(() { if (isStartPicked) { _startTime = dt; } else { _endTime = dt; } }); },
    );
  }

  Future<void> _pickFundingDeadline() async {
    final dt = await pickFundingDeadline(context, current: _fundingEndAt, startTime: _startTime);
    if (dt != null) { _markDirty(); setState(() => _fundingEndAt = dt); }
  }

  Future<void> _createVenueInline() async {
    setState(() => _creatingVenue = true);
    final newId = await createVenueInline(context,
      nameCtrl: _venueNameCtrl, addressCtrl: _venueAddressCtrl, cityCtrl: _venueCityCtrl,
      provinceCtrl: _venueProvinceCtrl, capacityCtrl: _venueCapacityCtrl, lat: _venueLat, lng: _venueLng);
    if (newId != null) {
      await _loadVenues();
      setState(() {
        _selectedVenueId = newId; _showVenueForm = false;
        _venueNameCtrl.clear(); _venueAddressCtrl.clear(); _venueCityCtrl.clear();
        _venueProvinceCtrl.clear(); _venueCapacityCtrl.clear(); _venueLat = null; _venueLng = null;
      });
    }
    setState(() => _creatingVenue = false);
  }

  void _addStrategyTier() => setState(() => _strategyTiers.add(StrategyTierInput()));
  void _removeStrategyTier(int i) { if (_strategyTiers.length > 1) setState(() => _strategyTiers.removeAt(i)); }
  void _addLocalTier() => setState(() => _localTiers.add(EditableTier()));
  void _removeLocalTier(int i) { if (_localTiers.length > 1) setState(() => _localTiers.removeAt(i)); }

  Future<void> _createStrategyInline() async {
    setState(() => _creatingStrategy = true);
    final newId = await createStrategyInline(context, nameCtrl: _strategyNameCtrl, tiers: _strategyTiers);
    if (newId != null) {
      await _loadStrategies();
      final s = _strategies.where((s) => s.id == newId).firstOrNull;
      setState(() {
        _selectedStrategyId = newId;
        _localTiers = (s?.tiers ?? []).map((t) {
          final lt = EditableTier(); lt.nameCtrl.text = t.name;
          lt.priceCtrl.text = (t.priceCents / 100).toStringAsFixed(2); lt.descCtrl.text = t.description ?? '';
          return lt;
        }).toList();
        _strategyNameCtrl.clear(); _strategyTiers.clear(); _strategyTiers.add(StrategyTierInput());
      });
    }
    setState(() => _creatingStrategy = false);
  }

  Future<void> _toggleSponsorTemplate(SponsorCategoryTemplate t) async {
    await toggleSponsorTemplate(context, t,
      localCategories: _localCategories, onChanged: () { if (mounted) setState(() => _markDirty()); });
  }

  // ── Navigation ──

  void _goToStep(int step) {
    if (step >= 0 && step < _stepLabels.length && step <= _currentStep) setState(() => _currentStep = step);
  }

  void _nextStep() {
    final valid = validateCreateEventStep(
      context: context, currentStep: _currentStep, formKey: _formKeys[_currentStep],
      title: _titleCtrl.text, genre: _genre, fundingEndAt: _fundingEndAt,
      startTime: _startTime, endTime: _endTime, capacityText: _capacityCtrl.text,
      selectedVenueId: _selectedVenueId,
      onStepError: (s) => setState(() => _stepsWithErrors.add(s)),
      onStepClear: (s) => setState(() => _stepsWithErrors.remove(s)),
    );
    if (!valid) return;
    setState(() { if (_currentStep < _stepLabels.length - 1) _currentStep++; });
  }

  void _prevStep() { if (_currentStep > 0) setState(() => _currentStep--); }

  void _openPreview() {
    final preview = buildPreviewEvent(
      context: context, title: _titleCtrl.text, description: _descCtrl.text,
      startTime: _startTime, endTime: _endTime, fundingEndAt: _fundingEndAt,
      fundingGoalText: _fundingGoalCtrl.text, minPledgeText: _minPledgeCtrl.text,
      capacityText: _capacityCtrl.text, registrationType: _registrationType, genre: _genre,
      communityRules: _communityRules, postsEnabled: _postsEnabled, refundDeadlineDays: _refundDeadlineDays,
      selectedStrategyId: _selectedStrategyId, strategies: _strategies,
      selectedVenueId: _selectedVenueId, venues: _venues,
      hasSchedule: _hasSchedule, scheduleDays: _scheduleDays,
      linkFundingToTiers: _linkFundingToTiers, ageRestricted: _ageRestricted, minAge: _minAge,
    );
    final previewImages = _imageBytes.values.toList();
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => EventDetailScreen(eventId: 0, previewEvent: preview,
        previewImages: previewImages.isNotEmpty ? previewImages : null),
    ));
  }

  // ── Submit ──

  Future<void> _submit() async {
    if (_fundingEndAt == null && (_startTime == null || _endTime == null)) {
      AppToast.error(context, 'Set funding deadline or both start & end dates');
      setState(() => _currentStep = 1); return;
    }
    if (_startTime != null && _endTime == null) {
      AppToast.error(context, 'End time is required when start time is set');
      setState(() => _currentStep = 1); return;
    }
    if (_startTime != null && _fundingEndAt != null && !_startTime!.isAfter(_fundingEndAt!)) {
      AppToast.error(context, 'Event start time must be after the funding deadline');
      setState(() => _currentStep = 1); return;
    }
    if (_fundingEndAt == null && _selectedStrategyId == null) {
      AppToast.error(context, 'Ticket strategy is required when no funding deadline is set');
      setState(() => _currentStep = 2); return;
    }
    if (_selectedVenueId == null) { AppToast.error(context, 'Please select a venue'); setState(() => _currentStep = 4); return; }
    final capVal = int.tryParse(_capacityCtrl.text.trim());
    if (capVal == null) { AppToast.error(context, 'Please enter a valid max capacity'); setState(() => _currentStep = 2); return; }

    setState(() => _isLoading = true);
    try {
      final payload = buildCreateEventPayload(
        selectedVenueId: _selectedVenueId!, title: _titleCtrl.text, description: _descCtrl.text,
        maxCapacity: capVal, registrationType: _registrationType,
        minPledge: double.tryParse(_minPledgeCtrl.text) ?? 5.0,
        maxReservedSpotsPerUser: int.tryParse(_maxReservedSpotsCtrl.text) ?? 0,
        genre: _genre, communityRules: _communityRules, postsEnabled: _postsEnabled, publish: _publish,
        startTime: _startTime, endTime: _endTime, fundingEndAt: _fundingEndAt,
        refundDeadlineDays: _refundDeadlineDays, fundingGoal: double.tryParse(_fundingGoalCtrl.text),
        selectedStrategyId: _selectedStrategyId, venues: _venues,
        parkingInfo: _parkingCtrl.text.trim(), transitInfo: _transitCtrl.text.trim(),
        rideshareInfo: _rideshareCtrl.text.trim(), accessibilityInfo: _accessibilityCtrl.text.trim(),
        hasSchedule: _hasSchedule, linkFundingToTiers: _linkFundingToTiers,
        maxDiscountPercent: _maxDiscountPercent, ageRestricted: _ageRestricted, minAge: _minAge,
        waitlistMaxSize: int.tryParse(_waitlistMaxSizeCtrl.text.trim()),
        waitlistAutoApprove: _waitlistAutoApprove,
        eventMaxImages: int.tryParse(_eventMaxImagesCtrl.text.trim()),
        maxPostsPerDay: int.tryParse(_maxPostsPerDayCtrl.text.trim()),
        maxCoOrganizers: int.tryParse(_maxCoOrganizersCtrl.text.trim()),
      );
      await executeCreateEventSubmission(
        sponsorRepo: context.read<SponsorProvider>(), eventRepo: context.read<EventProvider>(),
        ticketRepo: context.read<TicketProvider>(),
        eventData: payload,
        selectedDiscounts: _selectedDiscounts, localTiers: _localTiers,
        milestones: _milestones, earlyBirdDiscounts: _earlyBirdDiscounts,
        hasSchedule: _hasSchedule, scheduleDays: _scheduleDays,
        localCategories: _localCategories, pickedImages: _pickedImages, imageBytes: _imageBytes,
      );
      setState(() => _isLoading = false);
      if (mounted) context.pop(true);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) AppToast.fromError(context, e, fallback: 'Failed to create event');
    }
  }

  Future<void> _handleClose() async {
    if (!_isDirty && !_hasAnyInput || await confirmDiscardDialog(context)) {
      if (!mounted) return;
      Navigator.of(context).canPop() ? context.pop() : context.go('/');
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: _handleClose),
        title: const Text('Create Event'),
      ),
      body: Column(children: [
        CreateEventStepIndicator(stepLabels: _stepLabels, stepIcons: _stepIcons,
          currentStep: _currentStep, stepsWithErrors: _stepsWithErrors, onGoToStep: _goToStep),
        Expanded(child: IndexedStack(index: _currentStep, children: [
          _buildStep0(), _buildStep1(), _buildStep2(), _buildStep3(), _buildStep4(), _buildStep5(),
        ])),
        CreateEventBottomNav(currentStep: _currentStep, stepCount: _stepLabels.length,
          stepLabels: _stepLabels, isLoading: _isLoading, publish: _publish,
          onPrevStep: _prevStep, onNextStep: _nextStep, onSubmit: _submit),
      ]),
    );
  }

  Widget _buildStep0() => StepBasics(
    formKey: _formKeys[0], titleCtrl: _titleCtrl, descCtrl: _descCtrl,
    genre: _genre, genres: _genres, onGenreChanged: (v) => setState(() => _genre = v),
    imageCount: _pickedImages.length, imageBytes: _imageBytes,
    onPickImages: () => _pickImages(), onPickSingleImage: () => _pickImages(singleMode: true),
    onRemoveImage: _removeImage, onMarkDirty: () { _markDirty(); setState(() {}); },
    ageRestricted: _ageRestricted, minAge: _minAge,
    onAgeRestrictedChanged: (v) => setState(() => _ageRestricted = v),
    onMinAgeChanged: (v) => setState(() => _minAge = v),
  );

  Widget _buildStep1() => StepDatesRegistration(
    formKey: _formKeys[1], startTime: _startTime, endTime: _endTime,
    onPickStartTime: () => _pickDateTime(true), onPickEndTime: () => _pickDateTime(false),
    onClearStartTime: () => setState(() => _startTime = null),
    onClearEndTime: () => setState(() => _endTime = null),
    registrationType: _registrationType,
    onRegistrationTypeChanged: (v) => setState(() => _registrationType = v ?? 'open'),
    fundingEndAt: _fundingEndAt, onPickFundingDeadline: _pickFundingDeadline,
    onClearFundingDeadline: () => setState(() => _fundingEndAt = null),
    refundDeadlineDays: _refundDeadlineDays,
    onRefundDeadlineDaysChanged: (v) => setState(() => _refundDeadlineDays = v),
    milestones: _milestones, hasSchedule: _hasSchedule,
    onHasScheduleChanged: (v) => setState(() => _hasSchedule = v),
    scheduleDays: _scheduleDays, onMarkDirty: () => setState(() {}), fmtDt: fmtDt,
  );

  Widget _buildStep2() => StepTicketsFunding(
    formKey: _formKeys[2], capacityCtrl: _capacityCtrl,
    strategies: _strategies, strategiesLoading: _strategiesLoading,
    strategiesError: _strategiesError, onReloadStrategies: _loadStrategies,
    selectedStrategyId: _selectedStrategyId,
    onStrategyChanged: (id) => setState(() {
      _selectedStrategyId = id;
      final s = _strategies.where((s) => s.id == id).firstOrNull;
      _localTiers = (s?.tiers ?? []).map((t) {
        final lt = EditableTier(); lt.nameCtrl.text = t.name;
        lt.priceCtrl.text = (t.priceCents / 100).toStringAsFixed(2); lt.descCtrl.text = t.description ?? '';
        return lt;
      }).toList();
    }),
    localTiers: _localTiers, onAddLocalTier: _addLocalTier, onRemoveLocalTier: _removeLocalTier,
    strategyTiers: _strategyTiers, onAddStrategyTier: _addStrategyTier,
    onRemoveStrategyTier: _removeStrategyTier, creatingStrategy: _creatingStrategy,
    strategyNameCtrl: _strategyNameCtrl, onCreateStrategyInline: _createStrategyInline,
    fundingEndAt: _fundingEndAt, fundingGoalCtrl: _fundingGoalCtrl,
    minPledgeCtrl: _minPledgeCtrl, maxReservedSpotsCtrl: _maxReservedSpotsCtrl,
    linkFundingToTiers: _linkFundingToTiers,
    onLinkFundingToTiersChanged: (v) => setState(() => _linkFundingToTiers = v),
    onMarkDirty: _markDirty,
    buildLoadingChip: (l) => buildLoadingChip(context, l),
    buildErrorRetry: (m, r) => buildErrorRetry(context, m, r),
  );

  Widget _buildStep3() => StepDiscountsMilestones(
    formKey: _formKeys[3], discounts: _discountStrategies,
    discountsLoading: _discountsLoading, discountsError: _discountsError,
    onReloadDiscounts: _loadDiscounts, selectedDiscounts: _selectedDiscounts,
    onAddDiscount: (id, auto) => setState(() => _selectedDiscounts[id] = auto),
    onRemoveDiscount: (id) => setState(() => _selectedDiscounts.remove(id)),
    earlyBirdDiscounts: _earlyBirdDiscounts, maxDiscountPercent: _maxDiscountPercent,
    onMaxDiscountPercentChanged: (v) => setState(() => _maxDiscountPercent = v),
    fundingEndAt: _fundingEndAt, startTime: _startTime,
    selectedStrategyId: _selectedStrategyId,
    onMarkDirty: _markDirty, fmtDt: fmtDt,
    buildLoadingChip: (l) => buildLoadingChip(context, l),
    buildErrorRetry: (m, r) => buildErrorRetry(context, m, r),
  );

  Widget _buildStep4() => StepLocationSponsors(
    formKey: _formKeys[4], venues: _venues, venuesLoading: _venuesLoading,
    venuesError: _venuesError, onReloadVenues: _loadVenues,
    selectedVenueId: _selectedVenueId, onVenueChanged: (id) => setState(() => _selectedVenueId = id),
    showVenueForm: _showVenueForm, onShowVenueFormChanged: (v) => setState(() => _showVenueForm = v),
    creatingVenue: _creatingVenue, venueNameCtrl: _venueNameCtrl, venueAddressCtrl: _venueAddressCtrl,
    venueCityCtrl: _venueCityCtrl, venueProvinceCtrl: _venueProvinceCtrl,
    venueCapacityCtrl: _venueCapacityCtrl, venueGeocoding: _venueGeocoding,
    venueLat: _venueLat, venueLng: _venueLng, geoSuggestions: _venueGeoSuggestions,
    showVenueGeoSuggestions: _showVenueGeoSuggestions,
    onVenueAddressChanged: _onVenueAddressChanged, onSelectGeoSuggestion: _selectVenueGeoSuggestion,
    onCreateVenueInline: _createVenueInline,
    parkingCtrl: _parkingCtrl, transitCtrl: _transitCtrl,
    rideshareCtrl: _rideshareCtrl, accessibilityCtrl: _accessibilityCtrl,
    communityRules: _communityRules, communityRulesFeatureEnabled: _communityRulesFeatureEnabled,
    onCommunityRulesChanged: (v) => setState(() => _communityRules = v),
    postsEnabled: _postsEnabled, onPostsEnabledChanged: (v) => setState(() => _postsEnabled = v),
    localCategories: _localCategories, sponsorTemplates: _sponsorTemplates,
    templatesLoading: _loadingTemplates, onToggleSponsorTemplate: _toggleSponsorTemplate,
    onAddSponsorCategory: () { final c = EditableSponsorCategory(expanded: true); c.spotsCtrl.text = '1'; c.minBidCtrl.text = '100.00';
      setState(() { _localCategories.add(c); _markDirty(); }); },
    onRemoveSponsorCategory: (c) => setState(() { _localCategories.remove(c); _markDirty(); }),
    onManageTemplates: () async { await context.push('/sponsor-category-templates'); _loadSponsorTemplates(); },
    onMarkDirty: _markDirty,
    buildLoadingChip: (l) => buildLoadingChip(context, l),
    buildErrorRetry: (m, r) => buildErrorRetry(context, m, r),
    eventPoliciesSection: EventPoliciesSection(
      waitlistMaxSizeCtrl: _waitlistMaxSizeCtrl, waitlistAutoApprove: _waitlistAutoApprove,
      onWaitlistAutoApproveChanged: (v) => setState(() => _waitlistAutoApprove = v),
      eventMaxImagesCtrl: _eventMaxImagesCtrl, maxPostsPerDayCtrl: _maxPostsPerDayCtrl,
      maxCoOrganizersCtrl: _maxCoOrganizersCtrl,
      platformLimits: _platformLimits),
  );

  Widget _buildStep5() => StepReview(
    formKey: _formKeys[5], publishImmediately: _publish,
    onPublishChanged: (v) => setState(() => _publish = v),
    onGoToStep: _goToStep, onPreview: _openPreview,
    title: _titleCtrl.text, genre: _genre, imageCount: _pickedImages.length,
    fundingEndAt: _fundingEndAt, fundingGoal: _fundingGoalCtrl.text,
    minPledge: _minPledgeCtrl.text, linkFundingToTiers: _linkFundingToTiers,
    milestones: _milestones, startTime: _startTime, endTime: _endTime,
    registrationType: _registrationType,
    selectedStrategyName: _strategies.where((s) => s.id == _selectedStrategyId).firstOrNull?.name,
    localTiers: _localTiers, selectedDiscountCount: _selectedDiscounts.length,
    selectedVenueName: _venues.where((v) => v.id == _selectedVenueId).firstOrNull?.name,
    capacity: _capacityCtrl.text, localCategories: _localCategories,
  );
}
