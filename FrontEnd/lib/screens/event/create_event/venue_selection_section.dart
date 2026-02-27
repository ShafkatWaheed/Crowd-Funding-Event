import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/venue.dart';
import '../../../services/mapbox_geocoding_service.dart';
import '../../../widgets/searchable_dropdown.dart';

class VenueSelectionSection extends StatelessWidget {
  final List<Venue> venues;
  final bool venuesLoading;
  final String? venuesError;
  final VoidCallback onReloadVenues;
  final int? selectedVenueId;
  final ValueChanged<int?> onVenueChanged;
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
  final Widget Function(String) buildLoadingChip;
  final Widget Function(String, VoidCallback) buildErrorRetry;

  const VenueSelectionSection({
    super.key,
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
    required this.buildLoadingChip,
    required this.buildErrorRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (venuesLoading)
          buildLoadingChip('Loading venues…')
        else if (venuesError != null)
          buildErrorRetry(venuesError!, onReloadVenues),
        SearchableDropdown<Venue>(
          label: 'Venue *',
          hint: venuesLoading ? 'Loading…' : 'Search venues…',
          items: venues,
          selectedItem: venues
              .where((v) => v.id == selectedVenueId)
              .firstOrNull,
          itemLabel: (v) => v.name,
          itemSubtitle: (v) => 'Capacity: ${v.maxCapacity}',
          filter: (v, q) =>
              v.name.toLowerCase().contains(q.toLowerCase()),
          onSelected: (v) => onVenueChanged(v?.id),
          validator: (_) => selectedVenueId == null
              ? 'Please select a venue'
              : null,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => onShowVenueFormChanged(!showVenueForm),
          child: Row(
            children: [
              Icon(
                showVenueForm
                    ? Icons.expand_less
                    : Icons.add_location_alt,
                size: 20,
                color: AppTheme.primaryOf(context),
              ),
              const SizedBox(width: 6),
              Text(
                showVenueForm
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('New Venue',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: venueNameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Venue Name',
                        prefixIcon:
                            Icon(Icons.business_rounded, size: 20)),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: venueAddressCtrl,
                    decoration: InputDecoration(
                      labelText: 'Address',
                      prefixIcon:
                          const Icon(Icons.place_rounded, size: 20),
                      suffixIcon: venueGeocoding
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                            )
                          : venueLat != null
                              ? const Icon(Icons.check_circle,
                                  color: AppTheme.successColor,
                                  size: 18)
                              : null,
                    ),
                    onChanged: onVenueAddressChanged,
                  ),
                  if (showVenueGeoSuggestions &&
                      geoSuggestions.isNotEmpty)
                    Container(
                      constraints:
                          const BoxConstraints(maxHeight: 160),
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.cardOf(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.dividerOf(context)),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: geoSuggestions.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final s = geoSuggestions[i];
                          return ListTile(
                            dense: true,
                            leading: Icon(
                                Icons.location_on_outlined,
                                size: 18,
                                color:
                                    AppTheme.textSecondaryOf(context)),
                            title: Text(s.fullAddress,
                                style: const TextStyle(fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            onTap: () => onSelectGeoSuggestion(s),
                          );
                        },
                      ),
                    ),
                  if (venueLat != null && venueLng != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Location: ${venueLat!.toStringAsFixed(4)}, ${venueLng!.toStringAsFixed(4)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: venueCityCtrl,
                          decoration: const InputDecoration(
                              labelText: 'City',
                              prefixIcon: Icon(
                                  Icons.location_city_rounded,
                                  size: 20)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: venueProvinceCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Province',
                              prefixIcon: Icon(Icons.map_rounded,
                                  size: 20)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: venueCapacityCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Max Capacity',
                        prefixIcon:
                            Icon(Icons.groups_rounded, size: 20)),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed:
                          creatingVenue ? null : onCreateVenueInline,
                      icon: creatingVenue
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: Text(creatingVenue
                          ? 'Creating...'
                          : 'Create & Select Venue'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          crossFadeState: showVenueForm
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }
}
