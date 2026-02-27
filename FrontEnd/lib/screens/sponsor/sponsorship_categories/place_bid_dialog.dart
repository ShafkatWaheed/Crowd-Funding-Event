import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/sponsor.dart';

class BidDialogResult {
  final int amountCents;
  final String? proposalText;

  BidDialogResult({
    required this.amountCents,
    this.proposalText,
  });
}

class PlaceBidDialog extends StatefulWidget {
  final int eventId;
  final SponsorshipCategory category;

  const PlaceBidDialog({
    super.key,
    required this.eventId,
    required this.category,
  });

  @override
  State<PlaceBidDialog> createState() => _PlaceBidDialogState();
}

class _PlaceBidDialogState extends State<PlaceBidDialog> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _proposalCtrl;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: (widget.category.minBidCents / 100).toStringAsFixed(2),
    );
    _proposalCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _proposalCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    return amount > 0;
  }

  void _submit() {
    final amount = ((double.tryParse(_amountCtrl.text) ?? 0) * 100).round();
    final proposal = _proposalCtrl.text.trim();
    Navigator.pop(
      context,
      BidDialogResult(
        amountCents: amount,
        proposalText: proposal.isNotEmpty ? proposal : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 480,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bid on "${cat.name}"',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Min bid: ${cat.minBidDisplay}  •  '
                    '${cat.availableSpots} spot${cat.availableSpots == 1 ? "" : "s"} left',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                  ),
                  if (cat.bidCount > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${cat.bidCount} bid${cat.bidCount == 1 ? "" : "s"} placed'
                      '${cat.myBidCount > 0 ? "  •  ${cat.myBidCount} by you" : ""}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _amountCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Bid Amount (\$)',
                        prefixText: '\$ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _proposalCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Proposal (optional)',
                        hintText: 'Why you want to sponsor...',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _canSubmit ? _submit : null,
                    child: const Text('Place Bid'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
