import 'package:flutter/material.dart';

class EventPoliciesSection extends StatelessWidget {
  final TextEditingController waitlistMaxSizeCtrl;
  final bool waitlistAutoApprove;
  final ValueChanged<bool> onWaitlistAutoApproveChanged;
  final TextEditingController eventMaxImagesCtrl;
  final TextEditingController maxPostsPerDayCtrl;
  final TextEditingController maxCoOrganizersCtrl;
  final Map<String, int> platformLimits;
  // Reserved spots release policy (only shown when maxReservedSpotsPerUser > 0)
  final int maxReservedSpotsPerUser;
  final TextEditingController reservedSpotsReleasePercentCtrl;
  final bool linkFundingToTiers;
  final bool releaseTierSpotLimits;
  final ValueChanged<bool> onReleaseTierSpotLimitsChanged;

  const EventPoliciesSection({
    super.key,
    required this.waitlistMaxSizeCtrl,
    required this.waitlistAutoApprove,
    required this.onWaitlistAutoApproveChanged,
    required this.eventMaxImagesCtrl,
    required this.maxPostsPerDayCtrl,
    required this.maxCoOrganizersCtrl,
    this.platformLimits = const {},
    this.maxReservedSpotsPerUser = 0,
    required this.reservedSpotsReleasePercentCtrl,
    this.linkFundingToTiers = false,
    this.releaseTierSpotLimits = false,
    required this.onReleaseTierSpotLimitsChanged,
  });

  String _helperText(String key, {String fallback = 'Leave empty for platform default'}) {
    final limit = platformLimits[key];
    if (limit != null) return 'Platform max: $limit';
    return fallback;
  }

  String? _maxValidator(String? value, String limitKey) {
    if (value == null || value.trim().isEmpty) return null;
    final n = int.tryParse(value.trim());
    if (n == null) return 'Enter a valid number';
    if (n < 0) return 'Cannot be negative';
    final limit = platformLimits[limitKey];
    if (limit != null && n > limit) return 'Cannot exceed platform max ($limit)';
    return null;
  }

  String? _percentValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final n = int.tryParse(value.trim());
    if (n == null) return 'Enter a valid number';
    if (n < 0 || n > 100) return 'Must be 0–100';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: ExpansionTile(
        leading: const Icon(Icons.tune, size: 20),
        title: const Text('Event Policies', style: TextStyle(fontWeight: FontWeight.w600)),
        initiallyExpanded: false,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const SizedBox(height: 8),
          TextFormField(
            controller: waitlistMaxSizeCtrl,
            decoration: InputDecoration(
              labelText: 'Waitlist max size',
              helperText: _helperText('waitlist_max_size_limit'),
            ),
            keyboardType: TextInputType.number,
            validator: (v) => _maxValidator(v, 'waitlist_max_size_limit'),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Waitlist auto-approve'),
            subtitle: const Text('Automatically approve waitlisted users when spots open'),
            value: waitlistAutoApprove,
            onChanged: onWaitlistAutoApproveChanged,
            contentPadding: EdgeInsets.zero,
          ),
          TextFormField(
            controller: eventMaxImagesCtrl,
            decoration: InputDecoration(
              labelText: 'Max images',
              helperText: _helperText('event_max_images_limit'),
            ),
            keyboardType: TextInputType.number,
            validator: (v) => _maxValidator(v, 'event_max_images_limit'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: maxPostsPerDayCtrl,
            decoration: InputDecoration(
              labelText: 'Max posts per day',
              helperText: _helperText('max_posts_per_event_limit'),
            ),
            keyboardType: TextInputType.number,
            validator: (v) => _maxValidator(v, 'max_posts_per_event_limit'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: maxCoOrganizersCtrl,
            decoration: InputDecoration(
              labelText: 'Max co-organizers',
              helperText: _helperText('max_co_organizers_limit'),
            ),
            keyboardType: TextInputType.number,
            validator: (v) => _maxValidator(v, 'max_co_organizers_limit'),
          ),
          if (maxReservedSpotsPerUser > 0) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 4),
            const Text(
              'Reserved Spots Release',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: reservedSpotsReleasePercentCtrl,
              decoration: const InputDecoration(
                labelText: 'Release at % of selling window',
                helperText: '0 = release immediately when selling starts; 100 = release at event start (default)',
                suffixText: '%',
              ),
              keyboardType: TextInputType.number,
              validator: _percentValidator,
            ),
            if (linkFundingToTiers) ...[
              const SizedBox(height: 4),
              CheckboxListTile(
                title: const Text('Also retire per-tier spot limits at release'),
                subtitle: const Text('Zeroes max_reserved_spots on each ticket tier'),
                value: releaseTierSpotLimits,
                onChanged: (v) => onReleaseTierSpotLimitsChanged(v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
