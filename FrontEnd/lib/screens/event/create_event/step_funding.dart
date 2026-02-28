import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/event_form_models.dart';
import 'funding_deadline_cards.dart';
import 'funding_discount_cap_section.dart';
import 'funding_early_bird_section.dart';
import 'funding_milestone_section.dart';
import 'funding_tier_section.dart';

class StepFunding extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController fundingGoalCtrl;
  final TextEditingController minPledgeCtrl;
  final TextEditingController maxReservedSpotsCtrl;
  final DateTime? fundingEndAt;
  final DateTime? startTime;
  final VoidCallback onPickFundingDeadline;
  final VoidCallback onClearFundingDeadline;
  final int refundDeadlineDays;
  final ValueChanged<int> onRefundDeadlineDaysChanged;
  final List<MilestoneInput> milestones;
  final VoidCallback onMarkDirty;
  final String Function(DateTime) fmtDt;
  final bool linkFundingToTiers;
  final ValueChanged<bool> onLinkFundingToTiersChanged;
  final List<EditableTier> localTiers;
  final int maxDiscountPercent;
  final ValueChanged<int> onMaxDiscountPercentChanged;
  final List<EarlyBirdInput> earlyBirdDiscounts;

  const StepFunding({
    super.key,
    required this.formKey,
    required this.fundingGoalCtrl,
    required this.minPledgeCtrl,
    required this.maxReservedSpotsCtrl,
    required this.fundingEndAt,
    this.startTime,
    required this.onPickFundingDeadline,
    required this.onClearFundingDeadline,
    required this.refundDeadlineDays,
    required this.onRefundDeadlineDaysChanged,
    required this.milestones,
    required this.onMarkDirty,
    required this.fmtDt,
    required this.linkFundingToTiers,
    required this.onLinkFundingToTiersChanged,
    required this.localTiers,
    required this.maxDiscountPercent,
    required this.onMaxDiscountPercentChanged,
    required this.earlyBirdDiscounts,
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
                FundingDeadlineCard(
                  fundingEndAt: fundingEndAt,
                  onPickFundingDeadline: onPickFundingDeadline,
                  onClearFundingDeadline: onClearFundingDeadline,
                  fmtDt: fmtDt,
                ),
                if (fundingEndAt != null) ...[
                  const SizedBox(height: 20),
                  RefundDeadlineCard(
                    fundingEndAt: fundingEndAt!,
                    refundDeadlineDays: refundDeadlineDays,
                    onRefundDeadlineDaysChanged: onRefundDeadlineDaysChanged,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: fundingGoalCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Funding Goal (\$)',
                        prefixIcon: Icon(Icons.flag_rounded, size: 20),
                        prefixText: '\$ '),
                    keyboardType: TextInputType.number,
                  ),

                  if (localTiers.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    FundingTierLinkCard(
                      linkFundingToTiers: linkFundingToTiers,
                      onLinkFundingToTiersChanged: onLinkFundingToTiersChanged,
                      onMarkDirty: onMarkDirty,
                    ),
                    if (linkFundingToTiers) ...[
                      const SizedBox(height: 16),
                      PerTierReservationConfig(
                        localTiers: localTiers,
                        onMarkDirty: onMarkDirty,
                      ),
                      const SizedBox(height: 16),
                      FundingSpotLimitToggle(
                        maxReservedSpotsCtrl: maxReservedSpotsCtrl,
                        onMarkDirty: onMarkDirty,
                      ),
                    ],
                  ],

                  if (!linkFundingToTiers) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: minPledgeCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Minimum Pledge (\$)',
                          prefixIcon: Icon(Icons.savings_rounded, size: 20),
                          prefixText: '\$ '),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    FundingSpotLimitToggle(
                      maxReservedSpotsCtrl: maxReservedSpotsCtrl,
                      onMarkDirty: onMarkDirty,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FundingMilestoneSection(
                    milestones: milestones,
                  ),
                  const SizedBox(height: 16),
                  FundingEarlyBirdSection(
                    earlyBirdDiscounts: earlyBirdDiscounts,
                    onMarkDirty: onMarkDirty,
                    fmtDt: fmtDt,
                    fundingEndAt: fundingEndAt,
                    startTime: startTime,
                  ),
                  const SizedBox(height: 16),
                  FundingDiscountCapSection(
                    maxDiscountPercent: maxDiscountPercent,
                    onMaxDiscountPercentChanged: onMaxDiscountPercentChanged,
                    onMarkDirty: onMarkDirty,
                  ),
                ],
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
            context.fundingAccent.withValues(alpha: 0.08),
            context.fundingAccent.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.fundingAccent.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.fundingAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.attach_money_rounded,
                size: 24, color: context.fundingAccent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Funding Settings',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimaryOf(context),
                        letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Text(
                  'Set a funding deadline to run a crowdfunding phase. If skipped, dates become required next.',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
