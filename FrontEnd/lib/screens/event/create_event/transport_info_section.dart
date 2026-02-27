import 'package:flutter/material.dart';

import '../../../config/theme.dart';

class TransportInfoSection extends StatefulWidget {
  final TextEditingController parkingCtrl;
  final TextEditingController transitCtrl;
  final TextEditingController rideshareCtrl;
  final TextEditingController accessibilityCtrl;

  const TransportInfoSection({
    super.key,
    required this.parkingCtrl,
    required this.transitCtrl,
    required this.rideshareCtrl,
    required this.accessibilityCtrl,
  });

  @override
  State<TransportInfoSection> createState() => _TransportInfoSectionState();
}

class _TransportInfoSectionState extends State<TransportInfoSection> {
  bool _showTransportSection = false;

  @override
  Widget build(BuildContext context) {
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
                  ? AppTheme.primaryOf(context).withValues(alpha: 0.05)
                  : AppTheme.cardOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showTransportSection
                    ? AppTheme.primaryOf(context).withValues(alpha: 0.2)
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
                  child: Text('Parking & Transport Info (Optional)',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppTheme.textPrimaryOf(context))),
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
          crossFadeState: _showTransportSection
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }
}
