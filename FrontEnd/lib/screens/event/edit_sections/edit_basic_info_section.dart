import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../utils/date_time_utils.dart';
import '../../../models/venue.dart';
import '../../../widgets/searchable_dropdown.dart';

const _genres = [
  'community', 'music', 'tech', 'sports', 'arts',
  'food', 'charity', 'education', 'business', 'other',
];

class EditBasicInfoSection extends StatefulWidget {
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final TextEditingController capacityCtrl;
  final String registrationType;
  final String? genre;
  final bool postsEnabled;
  final List<Venue> venues;
  final int? selectedVenueId;
  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime? fundingEndAt;
  final TextEditingController parkingCtrl;
  final TextEditingController transitCtrl;
  final TextEditingController rideshareCtrl;
  final TextEditingController accessibilityCtrl;
  final bool initialShowTransport;
  final ValueChanged<String> onRegistrationTypeChanged;
  final ValueChanged<String?> onGenreChanged;
  final ValueChanged<bool> onPostsEnabledChanged;
  final ValueChanged<int?> onVenueChanged;
  final ValueChanged<DateTime?> onStartTimeChanged;
  final ValueChanged<DateTime?> onEndTimeChanged;
  final ValueChanged<DateTime?> onFundingEndAtChanged;

  const EditBasicInfoSection({
    super.key,
    required this.titleCtrl,
    required this.descCtrl,
    required this.capacityCtrl,
    required this.registrationType,
    required this.genre,
    required this.postsEnabled,
    required this.venues,
    required this.selectedVenueId,
    required this.startTime,
    required this.endTime,
    required this.fundingEndAt,
    required this.parkingCtrl,
    required this.transitCtrl,
    required this.rideshareCtrl,
    required this.accessibilityCtrl,
    this.initialShowTransport = false,
    required this.onRegistrationTypeChanged,
    required this.onGenreChanged,
    required this.onPostsEnabledChanged,
    required this.onVenueChanged,
    required this.onStartTimeChanged,
    required this.onEndTimeChanged,
    required this.onFundingEndAtChanged,
  });

  @override
  State<EditBasicInfoSection> createState() => _EditBasicInfoSectionState();
}

class _EditBasicInfoSectionState extends State<EditBasicInfoSection> {
  late bool _showTransport;

  @override
  void initState() {
    super.initState();
    _showTransport = widget.initialShowTransport;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.titleCtrl,
          decoration: const InputDecoration(labelText: 'Event Title'),
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: widget.descCtrl,
          decoration: const InputDecoration(labelText: 'Description'),
          maxLines: 3,
        ),
        const SizedBox(height: 16),

        Text('Event Dates', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _datePickerTile(
          label: 'Event Start Date',
          value: widget.startTime,
          onPick: () => _pickDateTime(
            initial: widget.startTime,
            onPicked: (dt) => widget.onStartTimeChanged(dt),
          ),
          onClear: () => widget.onStartTimeChanged(null),
        ),
        const SizedBox(height: 8),
        _datePickerTile(
          label: 'Event End Date',
          value: widget.endTime,
          onPick: () => _pickDateTime(
            initial: widget.endTime ?? widget.startTime,
            onPicked: (dt) => widget.onEndTimeChanged(dt),
          ),
          onClear: () => widget.onEndTimeChanged(null),
        ),
        const SizedBox(height: 8),
        _datePickerTile(
          label: 'Funding Deadline',
          value: widget.fundingEndAt,
          onPick: () => _pickDateTime(
            initial: widget.fundingEndAt,
            onPicked: (dt) => widget.onFundingEndAtChanged(dt),
          ),
          onClear: () => widget.onFundingEndAtChanged(null),
        ),
        const SizedBox(height: 8),
        Text(
          'At least one of Event Start Date or Funding Deadline must be set.',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: widget.capacityCtrl,
          decoration: const InputDecoration(labelText: 'Max Capacity'),
          keyboardType: TextInputType.number,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Required';
            if (int.tryParse(v) == null) return 'Enter a number';
            return null;
          },
        ),
        const SizedBox(height: 16),

        DropdownButtonFormField<String>(
          initialValue: widget.registrationType,
          decoration: const InputDecoration(labelText: 'Registration Type'),
          items: const [
            DropdownMenuItem(value: 'open', child: Text('Open')),
            DropdownMenuItem(value: 'closed', child: Text('Closed (Waitlist)')),
          ],
          onChanged: (v) => widget.onRegistrationTypeChanged(v ?? 'open'),
        ),
        const SizedBox(height: 16),

        DropdownButtonFormField<String>(
          initialValue: widget.genre,
          decoration: const InputDecoration(labelText: 'Genre / Category *'),
          items: _genres
              .map((g) => DropdownMenuItem(
                    value: g,
                    child: Text(g[0].toUpperCase() + g.substring(1)),
                  ))
              .toList(),
          onChanged: widget.onGenreChanged,
          validator: (v) => v == null ? 'Please select a genre' : null,
        ),

        if (widget.venues.isNotEmpty) ...[
          const SizedBox(height: 16),
          SearchableDropdown<Venue>(
            label: 'Venue',
            hint: 'Search venues…',
            items: widget.venues,
            selectedItem: widget.venues
                .where((v) => v.id == widget.selectedVenueId)
                .firstOrNull,
            itemLabel: (v) => v.name,
            itemSubtitle: (v) => 'Capacity: ${v.maxCapacity}',
            filter: (v, q) =>
                v.name.toLowerCase().contains(q.toLowerCase()),
            onSelected: (v) => widget.onVenueChanged(v?.id),
          ),
        ],

        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Enable event feed / posts',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle:
              const Text('Registered users can post on the event wall'),
          value: widget.postsEnabled,
          activeTrackColor: AppTheme.primaryColor,
          onChanged: widget.onPostsEnabledChanged,
          contentPadding: EdgeInsets.zero,
        ),

        const SizedBox(height: 16),
        _buildTransportSection(context),
      ],
    );
  }

  // ── Transport (collapsible) ──

  Widget _buildTransportSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(() => _showTransport = !_showTransport),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _showTransport
                  ? AppTheme.primaryColor.withValues(alpha: 0.05)
                  : AppTheme.surfaceOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showTransport
                    ? AppTheme.primaryColor.withValues(alpha: 0.2)
                    : AppTheme.dividerOf(context),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.directions_car_rounded,
                    size: 18,
                    color: _showTransport
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Parking & Transport Info',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                ),
                Icon(
                  _showTransport
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
              color: AppTheme.surfaceOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.dividerOf(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: widget.parkingCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Parking',
                    hintText: 'e.g. Free parking lot behind the venue',
                    prefixIcon:
                        Icon(Icons.local_parking_rounded, size: 20),
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
                    prefixIcon: Icon(Icons.directions_transit_rounded,
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
                    hintText: 'e.g. Drop-off at Gate 3 entrance',
                    prefixIcon:
                        Icon(Icons.local_taxi_rounded, size: 20),
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
                    prefixIcon:
                        Icon(Icons.accessible_rounded, size: 20),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          crossFadeState: _showTransport
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  // ── Date picker helpers ──

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
                    ? AppDateFormat.fullDateTime(value)
                    : 'Not set',
                style: TextStyle(
                  color: value != null
                      ? AppTheme.textPrimaryOf(context)
                      : AppTheme.textSecondaryOf(context),
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
    onPicked(
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }
}
