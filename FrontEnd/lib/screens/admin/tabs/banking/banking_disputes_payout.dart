import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../../../models/admin.dart';
import '../../../../providers/admin_provider.dart';
import '../../../../widgets/app_toast.dart';
import '../../admin_shared.dart';

class BankingDisputesSection extends StatelessWidget {
  final List<AdminDispute> disputes;
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
        final status = d.status.isEmpty ? 'open' : d.status;
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
                'Dispute ${d.stripeDisputeId ?? '#${d.id}'}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryOf(context))),
            subtitle: Text(
                '${centsToStr(d.amountCents)} · $status',
                style: TextStyle(fontSize: 12, color: statusColor)),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (d.reason != null)
                      Text('Reason: ${d.reason}',
                          style: TextStyle(
                              fontSize: 12,
                              color:
                                  AppTheme.textSecondaryOf(context))),
                    if (d.createdAt != null)
                      Text('Opened: ${d.createdAt}',
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
                                await context
                                    .read<AdminProvider>()
                                    .submitDisputeEvidence(d.id);
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
                                await context
                                    .read<AdminProvider>()
                                    .acceptDisputeLoss(d.id);
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
