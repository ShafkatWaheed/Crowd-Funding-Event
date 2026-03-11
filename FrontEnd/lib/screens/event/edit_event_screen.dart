import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/event.dart';
import '../../models/venue.dart';
import '../../models/ticket_strategy.dart';
import '../../providers/event_provider.dart';
import '../../providers/ticket_provider.dart';
import '../../providers/venue_provider.dart';
import '../../widgets/app_toast.dart';

import 'edit_sections/edit_basic_info_section.dart';
import 'edit_sections/edit_funding_section.dart';
import 'edit_sections/edit_milestones_section.dart';
import 'edit_sections/edit_schedule_section.dart';
import 'edit_sections/edit_tickets_section.dart';
import 'edit_sections/edit_sponsors_section.dart';
import 'create_event/event_policies_section.dart';

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
  bool _hasSchedule = false;
  bool _showTransportInitial = false;

  final _parkingCtrl = TextEditingController();
  final _transitCtrl = TextEditingController();
  final _rideshareCtrl = TextEditingController();
  final _accessibilityCtrl = TextEditingController();
  // Event policy fields
  final _waitlistMaxSizeCtrl = TextEditingController();
  bool _waitlistAutoApprove = true;
  final _eventMaxImagesCtrl = TextEditingController();
  final _maxPostsPerDayCtrl = TextEditingController();
  final _maxCoOrganizersCtrl = TextEditingController();
  final _reservedSpotsReleasePercentCtrl = TextEditingController();
  bool _releaseTierSpotLimits = false;
  Map<String, int> _platformLimits = {};

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
      final repo = context.read<EventProvider>();
      final config = await repo.getPublicConfig();
      if (mounted) {
        setState(() {
          _communityRulesFeatureEnabled =
              config.featureCommunityRulesEnabled;
          _platformLimits = config.platformLimits;
        });
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _loadVenues() async {
    try {
      final repo = context.read<VenueProvider>();
      final data = await repo.getVenues();
      setState(() {
        _venues = data;
      });
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _loadStrategies() async {
    try {
      final ticketRepo = context.read<TicketProvider>();
      final data = await ticketRepo.getTicketStrategies();
      setState(() {
        _strategies = data;
      });
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _loadEvent() async {
    try {
      final eventRepo = context.read<EventProvider>();
      final event = await eventRepo.getEvent(widget.eventId);
      setState(() {
        _event = event;
        _titleCtrl.text = event.title;
        _descCtrl.text = event.description ?? '';
        _capacityCtrl.text = event.maxCapacity.toString();
        _fundingGoalCtrl.text = event.fundingGoalCents != null
            ? (event.fundingGoalCents! / 100).toStringAsFixed(2)
            : '';
        _minPledgeCtrl.text =
            (event.minPledgeCents / 100).toStringAsFixed(2);
        _maxReservedSpotsCtrl.text =
            event.maxReservedSpotsPerUser.toString();
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
        _showTransportInitial = event.hasTransportInfo;
        _hasSchedule = event.hasSchedule;
        // Policy fields
        if (event.waitlistMaxSize != null) _waitlistMaxSizeCtrl.text = event.waitlistMaxSize.toString();
        _waitlistAutoApprove = event.waitlistAutoApprove;
        if (event.eventMaxImages != null) _eventMaxImagesCtrl.text = event.eventMaxImages.toString();
        if (event.maxPostsPerDay != null) _maxPostsPerDayCtrl.text = event.maxPostsPerDay.toString();
        if (event.maxCoOrganizers != null) _maxCoOrganizersCtrl.text = event.maxCoOrganizers.toString();
        if (event.reservedSpotsReleasePercent != null) _reservedSpotsReleasePercentCtrl.text = event.reservedSpotsReleasePercent.toString();
        _releaseTierSpotLimits = event.releaseTierSpotLimits;
        _loadingEvent = false;
      });
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e,
            fallback: 'Failed to load event');
        setState(() => _loadingEvent = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final fundingGoal = double.tryParse(_fundingGoalCtrl.text);
    final minPledge = double.tryParse(_minPledgeCtrl.text) ?? 5.0;
    final wms = int.tryParse(_waitlistMaxSizeCtrl.text.trim());
    final emi = int.tryParse(_eventMaxImagesCtrl.text.trim());
    final mppd = int.tryParse(_maxPostsPerDayCtrl.text.trim());
    final mco = int.tryParse(_maxCoOrganizersCtrl.text.trim());
    final rsp = int.tryParse(_reservedSpotsReleasePercentCtrl.text.trim());

    final data = EventUpdateRequest(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      maxCapacity: int.parse(_capacityCtrl.text),
      registrationType: _registrationType,
      minPledgeCents: (minPledge * 100).toInt(),
      maxReservedSpotsPerUser: int.tryParse(_maxReservedSpotsCtrl.text) ?? 0,
      genre: _genre,
      postsEnabled: _postsEnabled,
      communityRules: _event?.status.name == 'draft' ? _communityRules : null,
      startTime: _startTime?.toUtc().toIso8601String(),
      endTime: _endTime?.toUtc().toIso8601String(),
      fundingEndAt: _fundingEndAt?.toUtc().toIso8601String(),
      refundDeadlineDays: _fundingEndAt != null ? _refundDeadlineDays : null,
      fundingGoalCents: fundingGoal != null && fundingGoal > 0 ? (fundingGoal * 100).toInt() : null,
      ticketStrategyId: _selectedStrategyId,
      venueId: _selectedVenueId != null && _selectedVenueId != _event?.venueId ? _selectedVenueId : null,
      parkingInfo: _parkingCtrl.text.trim().isEmpty ? null : _parkingCtrl.text.trim(),
      transitInfo: _transitCtrl.text.trim().isEmpty ? null : _transitCtrl.text.trim(),
      rideshareInfo: _rideshareCtrl.text.trim().isEmpty ? null : _rideshareCtrl.text.trim(),
      accessibilityInfo: _accessibilityCtrl.text.trim().isEmpty ? null : _accessibilityCtrl.text.trim(),
      hasSchedule: _hasSchedule,
      waitlistMaxSize: wms != null && wms > 0 ? wms : null,
      waitlistAutoApprove: _waitlistAutoApprove,
      eventMaxImages: emi != null && emi > 0 ? emi : null,
      maxPostsPerDay: mppd != null && mppd > 0 ? mppd : null,
      maxCoOrganizers: mco != null && mco > 0 ? mco : null,
      reservedSpotsReleasePercent: rsp,
      releaseTierSpotLimits: _releaseTierSpotLimits,
    );

    try {
      final eventRepo = context.read<EventProvider>();
      final updated = await eventRepo.updateEvent(widget.eventId, data);
      if (mounted) {
        final newStatus = updated.status.name;
        context.read<EventProvider>().loadEvent(widget.eventId);
        if (newStatus == 'pending_approval') {
          AppToast.success(context,
              'Event updated! It now needs admin approval before going live again.');
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
    _waitlistMaxSizeCtrl.dispose();
    _eventMaxImagesCtrl.dispose();
    _maxPostsPerDayCtrl.dispose();
    _maxCoOrganizersCtrl.dispose();
    _reservedSpotsReleasePercentCtrl.dispose();
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
                      constraints:
                          const BoxConstraints(maxWidth: 600),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            if (_event!.status ==
                                    EventStatus.approved ||
                                _event!.status ==
                                    EventStatus.live) ...[
                              Container(
                                padding:
                                    const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.warningColor
                                      .withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppTheme
                                          .warningColor
                                          .withValues(
                                              alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                        Icons.warning_amber,
                                        color: AppTheme
                                            .warningColor),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'This event is currently ${_event!.status.name}. Editing will require admin approval before it goes live again.',
                                        style: TextStyle(
                                            color: AppTheme
                                                .textPrimaryOf(
                                                    context),
                                            fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // ─── Basic Info ───
                            EditBasicInfoSection(
                              titleCtrl: _titleCtrl,
                              descCtrl: _descCtrl,
                              capacityCtrl: _capacityCtrl,
                              registrationType:
                                  _registrationType,
                              genre: _genre,
                              postsEnabled: _postsEnabled,
                              venues: _venues,
                              selectedVenueId:
                                  _selectedVenueId,
                              startTime: _startTime,
                              endTime: _endTime,
                              fundingEndAt: _fundingEndAt,
                              parkingCtrl: _parkingCtrl,
                              transitCtrl: _transitCtrl,
                              rideshareCtrl: _rideshareCtrl,
                              accessibilityCtrl:
                                  _accessibilityCtrl,
                              initialShowTransport:
                                  _showTransportInitial,
                              onRegistrationTypeChanged: (v) =>
                                  setState(() =>
                                      _registrationType = v),
                              onGenreChanged: (v) =>
                                  setState(() => _genre = v),
                              onPostsEnabledChanged: (v) =>
                                  setState(
                                      () => _postsEnabled = v),
                              onVenueChanged: (v) => setState(
                                  () => _selectedVenueId = v),
                              onStartTimeChanged: (v) =>
                                  setState(
                                      () => _startTime = v),
                              onEndTimeChanged: (v) =>
                                  setState(
                                      () => _endTime = v),
                              onFundingEndAtChanged: (v) =>
                                  setState(
                                      () => _fundingEndAt = v),
                            ),
                            const SizedBox(height: 16),

                            // ─── Schedule ───
                            if (_startTime != null &&
                                _endTime != null &&
                                _event != null) ...[
                              EditScheduleSection(
                                eventId: widget.eventId,
                                startTime: _startTime!,
                                endTime: _endTime!,
                                hasSchedule: _hasSchedule,
                                onHasScheduleChanged: (v) =>
                                    setState(() =>
                                        _hasSchedule = v),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // ─── Funding ───
                            EditFundingSection(
                              fundingGoalCtrl:
                                  _fundingGoalCtrl,
                              minPledgeCtrl: _minPledgeCtrl,
                              maxReservedSpotsCtrl:
                                  _maxReservedSpotsCtrl,
                              communityRules: _communityRules,
                              communityRulesFeatureEnabled:
                                  _communityRulesFeatureEnabled,
                              isDraft: _event?.status.name ==
                                  'draft',
                              onCommunityRulesChanged: (v) =>
                                  setState(() =>
                                      _communityRules = v),
                              refundDeadlineDays:
                                  _refundDeadlineDays,
                              onRefundDeadlineDaysChanged:
                                  (v) => setState(() =>
                                      _refundDeadlineDays =
                                          v),
                              fundingEndAt: _fundingEndAt,
                              strategies: _strategies,
                              selectedStrategyId:
                                  _selectedStrategyId,
                              onStrategyChanged: (v) =>
                                  setState(() =>
                                      _selectedStrategyId =
                                          v),
                            ),
                            const SizedBox(height: 16),

                            // ─── Ticket Tiers ───
                            EditTicketsSection(
                                eventId: widget.eventId),
                            const SizedBox(height: 16),

                            // ─── Milestones ───
                            if (_fundingEndAt != null &&
                                _event != null &&
                                [
                                  'draft',
                                  'pending_approval',
                                  'approved'
                                ].contains(
                                    _event!.status.name)) ...[
                              EditMilestonesSection(
                                  eventId: widget.eventId),
                              const SizedBox(height: 16),
                            ],

                            // ─── Sponsorships ───
                            EditSponsorsSection(
                                eventId: widget.eventId),
                            const SizedBox(height: 16),

                            // ─── Event Policies ───
                            EventPoliciesSection(
                              waitlistMaxSizeCtrl: _waitlistMaxSizeCtrl,
                              waitlistAutoApprove: _waitlistAutoApprove,
                              onWaitlistAutoApproveChanged: (v) => setState(() => _waitlistAutoApprove = v),
                              eventMaxImagesCtrl: _eventMaxImagesCtrl,
                              maxPostsPerDayCtrl: _maxPostsPerDayCtrl,
                              maxCoOrganizersCtrl: _maxCoOrganizersCtrl,
                              platformLimits: _platformLimits,
                              maxReservedSpotsPerUser: _event?.maxReservedSpotsPerUser ?? 0,
                              reservedSpotsReleasePercentCtrl: _reservedSpotsReleasePercentCtrl,
                              linkFundingToTiers: _event?.linkFundingToTiers ?? false,
                              releaseTierSpotLimits: _releaseTierSpotLimits,
                              onReleaseTierSpotLimitsChanged: (v) => setState(() => _releaseTierSpotLimits = v),
                            ),
                            const SizedBox(height: 24),

                            // ─── Submit ───
                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : _submit,
                                style:
                                    ElevatedButton.styleFrom(
                                  backgroundColor:
                                      AppTheme.primaryColor,
                                  foregroundColor:
                                      Colors.white,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child:
                                            CircularProgressIndicator(
                                                strokeWidth:
                                                    2,
                                                color: Colors
                                                    .white),
                                      )
                                    : const Text(
                                        'Save Changes'),
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
