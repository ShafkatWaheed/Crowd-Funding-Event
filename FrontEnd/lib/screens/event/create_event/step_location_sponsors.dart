import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/event_form_models.dart';
import '../../../models/venue.dart';
import '../../../services/mapbox_geocoding_service.dart';
import '../../../widgets/searchable_dropdown.dart';

class StepLocationSponsors extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  // Venue
  final List<Venue> venues;
  final bool venuesLoading;
  final String? venuesError;
  final VoidCallback onReloadVenues;
  final int? selectedVenueId;
  final ValueChanged<int?> onVenueChanged;
  // Venue creation
  final bool showVenueForm;
  final ValueChanged<bool> onShowVenueFormChanged;
  final bool creatingVenue;
  final TextEditingController venueNameCtrl;
  final TextEditingController venueAddressCtrl;
  final TextEditingController venueCityCtrl;
  final TextEditingController venueProvinceCtrl;
  final TextEditingController venueCapacityCtrl;
  final bool venueGeocoding;
  final double? venueLat;
  final double? venueLng;
  final List<GeocodingResult> geoSuggestions;
  final bool showVenueGeoSuggestions;
  final ValueChanged<String> onVenueAddressChanged;
  final ValueChanged<GeocodingResult> onSelectGeoSuggestion;
  final Future<void> Function() onCreateVenueInline;
  // Transport
  final TextEditingController parkingCtrl;
  final TextEditingController transitCtrl;
  final TextEditingController rideshareCtrl;
  final TextEditingController accessibilityCtrl;
  // Community
  final bool communityRules;
  final bool communityRulesFeatureEnabled;
  final ValueChanged<bool> onCommunityRulesChanged;
  final bool postsEnabled;
  final ValueChanged<bool> onPostsEnabledChanged;
  // Sponsorship
  final List<EditableSponsorCategory> localCategories;
  final List<Map<String, dynamic>> sponsorTemplates;
  final bool templatesLoading;
  final ValueChanged<Map<String, dynamic>> onToggleSponsorTemplate;
  final VoidCallback onAddSponsorCategory;
  final ValueChanged<EditableSponsorCategory> onRemoveSponsorCategory;
  final VoidCallback onManageTemplates;
  // Helpers
  final VoidCallback onMarkDirty;
  final Widget Function(String) buildLoadingChip;
  final Widget Function(String, VoidCallback) buildErrorRetry;
  final Widget? eventPoliciesSection;

  const StepLocationSponsors({
    super.key,
    required this.formKey,
    required this.venues,
    required this.venuesLoading,
    this.venuesError,
    required this.onReloadVenues,
    this.selectedVenueId,
    required this.onVenueChanged,
    required this.showVenueForm,
    required this.onShowVenueFormChanged,
    required this.creatingVenue,
    required this.venueNameCtrl,
    required this.venueAddressCtrl,
    required this.venueCityCtrl,
    required this.venueProvinceCtrl,
    required this.venueCapacityCtrl,
    required this.venueGeocoding,
    this.venueLat,
    this.venueLng,
    required this.geoSuggestions,
    required this.showVenueGeoSuggestions,
    required this.onVenueAddressChanged,
    required this.onSelectGeoSuggestion,
    required this.onCreateVenueInline,
    required this.parkingCtrl,
    required this.transitCtrl,
    required this.rideshareCtrl,
    required this.accessibilityCtrl,
    required this.communityRules,
    this.communityRulesFeatureEnabled = true,
    required this.onCommunityRulesChanged,
    required this.postsEnabled,
    required this.onPostsEnabledChanged,
    required this.localCategories,
    required this.sponsorTemplates,
    required this.templatesLoading,
    required this.onToggleSponsorTemplate,
    required this.onAddSponsorCategory,
    required this.onRemoveSponsorCategory,
    required this.onManageTemplates,
    required this.onMarkDirty,
    required this.buildLoadingChip,
    required this.buildErrorRetry,
    this.eventPoliciesSection,
  });

  @override
  State<StepLocationSponsors> createState() => _StepLocationSponsorsState();
}

class _StepLocationSponsorsState extends State<StepLocationSponsors> {
  bool _showTransportSection = false;
  bool _showSponsorshipSection = false;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        context.sponsorAccent.withValues(alpha: 0.08),
                        context.sponsorAccent.withValues(alpha: 0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: context.sponsorAccent.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: context.sponsorAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.location_on_rounded,
                            size: 24, color: context.sponsorAccent),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Location & Sponsors',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimaryOf(context),
                                    letterSpacing: -0.3)),
                            const SizedBox(height: 2),
                            Text('Pick a venue and set up sponsorship tiers.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondaryOf(context))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (widget.venuesLoading)
                  widget.buildLoadingChip('Loading venues…')
                else if (widget.venuesError != null)
                  widget.buildErrorRetry(widget.venuesError!, widget.onReloadVenues),
                SearchableDropdown<Venue>(
                  label: 'Venue *',
                  hint: widget.venuesLoading ? 'Loading…' : 'Search venues…',
                  items: widget.venues,
                  selectedItem: widget.venues
                      .where((v) => v.id == widget.selectedVenueId)
                      .firstOrNull,
                  itemLabel: (v) => v.name,
                  itemSubtitle: (v) => 'Capacity: ${v.maxCapacity}',
                  filter: (v, q) =>
                      v.name.toLowerCase().contains(q.toLowerCase()),
                  onSelected: (v) => widget.onVenueChanged(v?.id),
                  validator: (_) => widget.selectedVenueId == null
                      ? 'Please select a venue'
                      : null,
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => widget.onShowVenueFormChanged(!widget.showVenueForm),
                  child: Row(
                    children: [
                      Icon(
                        widget.showVenueForm
                            ? Icons.expand_less
                            : Icons.add_location_alt,
                        size: 20,
                        color: AppTheme.primaryOf(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.showVenueForm
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
                            controller: widget.venueNameCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Venue Name',
                                prefixIcon: Icon(Icons.business_rounded, size: 20)),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: widget.venueAddressCtrl,
                            decoration: InputDecoration(
                              labelText: 'Address',
                              prefixIcon: const Icon(Icons.place_rounded, size: 20),
                              suffixIcon: widget.venueGeocoding
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
                                  : widget.venueLat != null
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: AppTheme
                                              .successColor,
                                          size: 18)
                                      : null,
                            ),
                            onChanged: widget.onVenueAddressChanged,
                          ),
                          if (widget.showVenueGeoSuggestions &&
                              widget.geoSuggestions.isNotEmpty)
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
                                        .dividerOf(context)),
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
                                    widget.geoSuggestions
                                        .length,
                                separatorBuilder:
                                    (_, __) =>
                                        const Divider(
                                            height: 1),
                                itemBuilder: (context, i) {
                                  final s =
                                      widget.geoSuggestions[
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
                                        widget.onSelectGeoSuggestion(
                                            s),
                                  );
                                },
                              ),
                            ),
                          if (widget.venueLat != null &&
                              widget.venueLng != null)
                            Padding(
                              padding:
                                  const EdgeInsets.only(
                                      top: 4),
                              child: Text(
                                'Location: ${widget.venueLat!.toStringAsFixed(4)}, ${widget.venueLng!.toStringAsFixed(4)}',
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
                                      widget.venueCityCtrl,
                                  decoration:
                                      const InputDecoration(
                                          labelText:
                                              'City',
                                          prefixIcon: Icon(Icons.location_city_rounded, size: 20)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller:
                                      widget.venueProvinceCtrl,
                                  decoration:
                                      const InputDecoration(
                                          labelText:
                                              'Province',
                                          prefixIcon: Icon(Icons.map_rounded, size: 20)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller:
                                widget.venueCapacityCtrl,
                            decoration:
                                const InputDecoration(
                                    labelText:
                                        'Max Capacity',
                                    prefixIcon: Icon(Icons.groups_rounded, size: 20)),
                            keyboardType:
                                TextInputType.number,
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 42,
                            child: ElevatedButton.icon(
                              onPressed: widget.creatingVenue
                                  ? null
                                  : widget.onCreateVenueInline,
                              icon: widget.creatingVenue
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
                              label: Text(widget.creatingVenue
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
                  crossFadeState: widget.showVenueForm
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 250),
                ),
                const SizedBox(height: 24),
                _buildTransportSection(),
                const SizedBox(height: 16),
                _buildSponsorshipSection(),
                if (widget.eventPoliciesSection != null) widget.eventPoliciesSection!,
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                  color: widget.communityRules
                        ? context.fundingAccent.withValues(alpha: 0.08)
                        : AppTheme.cardOf(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: widget.communityRules
                            ? context.fundingAccent
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
                                color: widget.communityRules
                                    ? context.fundingAccent
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
                        subtitle: Text(
                          widget.communityRulesFeatureEnabled
                              ? 'Enables max duration, ticket price caps, and listing fee'
                              : 'Community rules are currently disabled by the platform',
                          style: const TextStyle(fontSize: 11),
                        ),
                        value: widget.communityRules,
                        activeColor: context.fundingAccent,
                        onChanged: widget.communityRulesFeatureEnabled
                            ? widget.onCommunityRulesChanged
                            : null,
                      ),
                      if (widget.communityRules) ...[
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
                  value: widget.postsEnabled,
                  activeColor: AppTheme.accentColor,
                  onChanged: widget.onPostsEnabledChanged,
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
                  controller: widget.parkingCtrl,
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
                  controller: widget.transitCtrl,
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
                  controller: widget.rideshareCtrl,
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
                  controller: widget.accessibilityCtrl,
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

  Widget _buildPrereqSection(EditableSponsorCategory cat) {
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
                  child: Text('${cat.prereqs.length}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.ticketAccent)),
                ),
              ],
            ),
            if (cat.prereqs.isNotEmpty) ...[
              const SizedBox(height: 6),
              ...cat.prereqs.asMap().entries.map((entry) {
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
                                    ? context.discountAccent.withValues(alpha: 0.1)
                                    : AppTheme.textSecondaryOf(context).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                p.isRequired ? 'Required' : 'Optional',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                    color: p.isRequired ? context.discountAccent : AppTheme.textSecondaryOf(context)),
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
                          setState(() => cat.prereqs.removeAt(i));
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
                      cat.prereqs.add(LocalPrerequisite(
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

  Widget _buildDirectSponsorCard(EditableSponsorCategory cat) {
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
              const Expanded(
                child: Text('New Sponsorship',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.errorColor),
                onPressed: () {
                  widget.onRemoveSponsorCategory(cat);
                },
                tooltip: 'Remove',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: cat.nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Sponsorship Name *',
              hintText: 'e.g. Gold Sponsor, Food Stall',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: cat.descCtrl,
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
                  controller: cat.spotsCtrl,
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
                  controller: cat.minBidCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Min Bid (\$) *',
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPrereqSection(cat),
        ],
      ),
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
                  ? context.ticketAccent.withValues(alpha: 0.08)
                  : AppTheme.cardOf(context),
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
                          color:
                              AppTheme.textPrimaryOf(context))),
                ),
                if (widget.localCategories.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        context.ticketAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                      '${widget.localCategories.length}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: context.ticketAccent)),
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
                if (widget.templatesLoading)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ))
                else if (widget.sponsorTemplates.isEmpty && widget.localCategories.where((c) => c.templateId == null).isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text('No sponsorships yet',
                              style: TextStyle(color: AppTheme.textSecondaryOf(context))),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: widget.onAddSponsorCategory,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Sponsorship'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: widget.onManageTemplates,
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                label: const Text('From Template'),
                                style: OutlinedButton.styleFrom(foregroundColor: context.ticketAccent),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                else if (widget.sponsorTemplates.isEmpty && widget.localCategories.where((c) => c.templateId == null).isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...widget.localCategories.where((c) => c.templateId == null).map((cat) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _buildDirectSponsorCard(cat),
                        );
                      }),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: widget.onAddSponsorCategory,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Sponsorship'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: widget.onManageTemplates,
                              icon: const Icon(Icons.settings, size: 16),
                              label: const Text('Manage Templates'),
                              style: TextButton.styleFrom(foregroundColor: context.ticketAccent),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else ...[
                  Text('Select sponsorships to attach:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryOf(context))),
                  const SizedBox(height: 4),
                  Text('Tap to select, then customize fields for this event.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context), fontStyle: FontStyle.italic)),
                  const SizedBox(height: 8),
                  ...widget.sponsorTemplates.map((t) {
                    final id = t['id'] as int;
                    final localCat = widget.localCategories.where((c) => c.templateId == id).firstOrNull;
                    final selected = localCat != null;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => widget.onToggleSponsorTemplate(t),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? context.ticketAccent.withValues(alpha: 0.08)
                                    : AppTheme.surfaceOf(context),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(10),
                                  topRight: const Radius.circular(10),
                                  bottomLeft: Radius.circular(selected && localCat.expanded ? 0 : 10),
                                  bottomRight: Radius.circular(selected && localCat.expanded ? 0 : 10),
                                ),
                                border: Border.all(
                                  color: selected
                                      ? context.ticketAccent.withValues(alpha: 0.4)
                                      : AppTheme.dividerOf(context),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                                    size: 20,
                                    color: selected ? context.ticketAccent : AppTheme.textSecondaryOf(context),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(t['name'] ?? '',
                                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                                            color: AppTheme.textPrimaryOf(context))),
                                  ),
                                  if (selected)
                                    IconButton(
                                      onPressed: () => setState(() => localCat.expanded = !localCat.expanded),
                                      icon: Icon(localCat.expanded ? Icons.expand_less : Icons.expand_more, size: 20),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      color: context.ticketAccent,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (selected && localCat.expanded)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.ticketAccent.withValues(alpha: 0.03),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(10),
                                  bottomRight: Radius.circular(10),
                                ),
                                border: Border.all(color: context.ticketAccent.withValues(alpha: 0.4)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    controller: localCat.nameCtrl,
                                    decoration: const InputDecoration(labelText: 'Sponsorship Name', isDense: true),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: localCat.descCtrl,
                                    decoration: const InputDecoration(labelText: 'Description (optional)', isDense: true),
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: localCat.spotsCtrl,
                                          decoration: const InputDecoration(labelText: 'Total Spots', isDense: true),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextFormField(
                                          controller: localCat.minBidCtrl,
                                          decoration: const InputDecoration(labelText: 'Min Bid (\$)', prefixText: '\$ ', isDense: true),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildPrereqSection(localCat),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  ...widget.localCategories.where((c) => c.templateId == null).toList().asMap().entries.map((entry) {
                    final cat = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _buildDirectSponsorCard(cat),
                    );
                  }),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onAddSponsorCategory,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Sponsorship'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: widget.onManageTemplates,
                          icon: const Icon(Icons.settings, size: 16),
                          label: const Text('Manage Templates'),
                          style: TextButton.styleFrom(foregroundColor: context.ticketAccent),
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
      ],
    );
  }
}
