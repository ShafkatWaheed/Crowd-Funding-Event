import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../services/api_service.dart';
import '../../../../widgets/app_toast.dart';
import '../../admin_shared.dart';

class BankingDisputesSection extends StatelessWidget {
  final List<dynamic> disputes;
  final bool disputesLoading;
  final VoidCallback onReloadDisputes;
  final VoidCallback onReloadBanking;

  const BankingDisputesSection({
    super.key,
    required this.disputes,
    required this.disputesLoading,
    required this.onReloadDisputes,
    required this.onReloadBanking,
  });

  @override
  Widget build(BuildContext context) {
    if (disputesLoading) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator()));
    }
    if (disputes.isEmpty) {
      return Card(
          color: AppTheme.cardOf(context),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No disputes found.',
                  style: TextStyle(
                      color: AppTheme.textSecondaryOf(context)))));
    }
    return Column(
      children: disputes.map<Widget>((d) {
        final status = d['status'] ?? 'open';
        final isOpen = status == 'open' || status == 'evidence_submitted';
        final statusColor = switch (status) {
          'open' => AppTheme.errorColor,
          'evidence_submitted' => AppTheme.warningColor,
          'won' => AppTheme.successColor,
          'lost' => AppTheme.textSecondaryOf(context),
          _ => AppTheme.textSecondaryOf(context),
        };
        return Card(
          color: AppTheme.cardOf(context),
          child: ExpansionTile(
            leading: Icon(Icons.gavel, color: statusColor, size: 20),
            title: Text(
                'Dispute ${d['stripe_dispute_id'] ?? '#${d['id']}'}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryOf(context))),
            subtitle: Text(
                '${centsToStr(d['amount_cents'] ?? 0)} · $status',
                style: TextStyle(fontSize: 12, color: statusColor)),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (d['reason'] != null)
                      Text('Reason: ${d['reason']}',
                          style: TextStyle(
                              fontSize: 12,
                              color:
                                  AppTheme.textSecondaryOf(context))),
                    if (d['created_at'] != null)
                      Text('Opened: ${d['created_at']}',
                          style: TextStyle(
                              fontSize: 12,
                              color:
                                  AppTheme.textSecondaryOf(context))),
                    const SizedBox(height: 8),
                    if (isOpen)
                      Row(
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.upload_file,
                                size: 16),
                            label: const Text('Submit Evidence'),
                            style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                textStyle:
                                    const TextStyle(fontSize: 12)),
                            onPressed: () async {
                              try {
                                await ApiService.instance
                                    .adminSubmitDisputeEvidence(
                                        d['id'] as int);
                                onReloadDisputes();
                                if (context.mounted) {
                                  AppToast.success(
                                      context, 'Evidence submitted');
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  AppToast.fromError(context, e,
                                      fallback:
                                          'Failed to submit evidence');
                                }
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            icon:
                                const Icon(Icons.cancel, size: 16),
                            label: const Text('Accept Loss'),
                            style: TextButton.styleFrom(
                                foregroundColor: AppTheme.errorColor,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                textStyle:
                                    const TextStyle(fontSize: 12)),
                            onPressed: () async {
                              try {
                                await ApiService.instance
                                    .adminAcceptDisputeLoss(
                                        d['id'] as int);
                                onReloadDisputes();
                                onReloadBanking();
                                if (context.mounted) {
                                  AppToast.success(
                                      context, 'Loss accepted');
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  AppToast.fromError(context, e,
                                      fallback:
                                          'Failed to accept loss');
                                }
                              }
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class BankingPayoutSection extends StatelessWidget {
  final List<dynamic> payoutItems;
  final bool payoutLoading;
  final VoidCallback onReloadPayout;

  const BankingPayoutSection({
    super.key,
    required this.payoutItems,
    required this.payoutLoading,
    required this.onReloadPayout,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payout Status',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryOf(context))),
        const SizedBox(height: 8),
        if (payoutLoading)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator())),
        if (!payoutLoading && payoutItems.isEmpty)
          Card(
              color: AppTheme.cardOf(context),
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No pending payouts.',
                      style: TextStyle(
                          color: AppTheme.textSecondaryOf(context))))),
        ...payoutItems.map<Widget>((p) => Card(
              color: AppTheme.cardOf(context),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: (p['has_bank_account'] == true)
                      ? AppTheme.successColor.withOpacity(0.15)
                      : AppTheme.warningColor.withOpacity(0.15),
                  child: Icon(Icons.person,
                      color: (p['has_bank_account'] == true)
                          ? AppTheme.successColor
                          : AppTheme.warningColor,
                      size: 20),
                ),
                title: Text(
                    p['organizer_name'] ??
                        'Organizer #${p['organizer_id']}',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryOf(context))),
                subtitle: Text(
                  'Pending: ${centsToStr(p['pending_amount_cents'] ?? 0)}'
                  '${p['has_bank_account'] != true ? ' · No bank account' : ''}'
                  '${p['payout_schedule'] != null ? ' · ${p['payout_schedule']}' : ''}'
                  '${p['next_payout_date'] != null ? ' · Next: ${p['next_payout_date']}' : ''}',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context)),
                ),
                trailing: (p['has_bank_account'] == true &&
                        (p['pending_amount_cents'] ?? 0) > 0)
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            textStyle: const TextStyle(fontSize: 12)),
                        onPressed: () async {
                          try {
                            await ApiService.instance
                                .adminForcePayout(
                                    p['organizer_id'] as int);
                            onReloadPayout();
                            if (context.mounted) {
                              AppToast.success(
                                  context, 'Payout initiated');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              AppToast.fromError(context, e,
                                  fallback: 'Payout failed');
                            }
                          }
                        },
                        child: const Text('Force Payout'),
                      )
                    : null,
              ),
            )),
      ],
    );
  }
}
