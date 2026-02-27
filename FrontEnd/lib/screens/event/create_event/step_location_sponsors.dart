import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/event_form_models.dart';
import '../../../models/venue.dart';
import '../../../services/mapbox_geocoding_service.dart';
import 'community_rules_section.dart';
import 'sponsorship_section.dart';
import 'transport_info_section.dart';
import 'venue_selection_section.dart';

class StepLocationSponsors extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                const SizedBox(height: 24),
                VenueSelectionSection(
                  venues: venues,
                  venuesLoading: venuesLoading,
                  venuesError: venuesError,
                  onReloadVenues: onReloadVenues,
                  selectedVenueId: selectedVenueId,
                  onVenueChanged: onVenueChanged,
                  showVenueForm: showVenueForm,
                  onShowVenueFormChanged: onShowVenueFormChanged,
                  creatingVenue: creatingVenue,
                  venueNameCtrl: venueNameCtrl,
                  venueAddressCtrl: venueAddressCtrl,
                  venueCityCtrl: venueCityCtrl,
                  venueProvinceCtrl: venueProvinceCtrl,
                  venueCapacityCtrl: venueCapacityCtrl,
                  venueGeocoding: venueGeocoding,
                  venueLat: venueLat,
                  venueLng: venueLng,
                  geoSuggestions: geoSuggestions,
                  showVenueGeoSuggestions: showVenueGeoSuggestions,
                  onVenueAddressChanged: onVenueAddressChanged,
                  onSelectGeoSuggestion: onSelectGeoSuggestion,
                  onCreateVenueInline: onCreateVenueInline,
                  buildLoadingChip: buildLoadingChip,
                  buildErrorRetry: buildErrorRetry,
                ),
                const SizedBox(height: 24),
                TransportInfoSection(
                  parkingCtrl: parkingCtrl,
                  transitCtrl: transitCtrl,
                  rideshareCtrl: rideshareCtrl,
                  accessibilityCtrl: accessibilityCtrl,
                ),
                const SizedBox(height: 16),
                SponsorshipSection(
                  localCategories: localCategories,
                  sponsorTemplates: sponsorTemplates,
                  templatesLoading: templatesLoading,
                  onToggleSponsorTemplate: onToggleSponsorTemplate,
                  onAddSponsorCategory: onAddSponsorCategory,
                  onRemoveSponsorCategory: onRemoveSponsorCategory,
                  onManageTemplates: onManageTemplates,
                  onMarkDirty: onMarkDirty,
                ),
                if (eventPoliciesSection != null) eventPoliciesSection!,
                const SizedBox(height: 16),
                CommunityRulesSection(
                  communityRules: communityRules,
                  communityRulesFeatureEnabled: communityRulesFeatureEnabled,
                  onCommunityRulesChanged: onCommunityRulesChanged,
                  postsEnabled: postsEnabled,
                  onPostsEnabledChanged: onPostsEnabledChanged,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
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
    );
  }
}
