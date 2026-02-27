import 'package:flutter/material.dart';

class EventPoliciesSection extends StatelessWidget {
  final TextEditingController waitlistMaxSizeCtrl;
  final bool waitlistAutoApprove;
  final ValueChanged<bool> onWaitlistAutoApproveChanged;
  final TextEditingController eventMaxImagesCtrl;
  final TextEditingController maxPostsPerDayCtrl;
  final TextEditingController maxCoOrganizersCtrl;
  final TextEditingController refundDeadlinePercentCtrl;

  const EventPoliciesSection({
    super.key,
    required this.waitlistMaxSizeCtrl,
    required this.waitlistAutoApprove,
    required this.onWaitlistAutoApproveChanged,
    required this.eventMaxImagesCtrl,
    required this.maxPostsPerDayCtrl,
    required this.maxCoOrganizersCtrl,
    required this.refundDeadlinePercentCtrl,
  });

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
            decoration: const InputDecoration(labelText: 'Waitlist max size', helperText: 'Leave empty for platform default'),
            keyboardType: TextInputType.number,
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
            decoration: const InputDecoration(labelText: 'Max images', helperText: 'Leave empty for platform default'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: maxPostsPerDayCtrl,
            decoration: const InputDecoration(labelText: 'Max posts per day', helperText: 'Leave empty for platform default'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: maxCoOrganizersCtrl,
            decoration: const InputDecoration(labelText: 'Max co-organizers', helperText: 'Leave empty for platform default'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: refundDeadlinePercentCtrl,
            decoration: const InputDecoration(labelText: 'Refund deadline %', helperText: 'Percentage of funding duration', suffixText: '%'),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }
}
