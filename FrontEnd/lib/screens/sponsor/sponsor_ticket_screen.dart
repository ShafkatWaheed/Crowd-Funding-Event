import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config/theme.dart';
import '../../models/sponsor.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';

class SponsorTicketScreen extends StatefulWidget {
  const SponsorTicketScreen({super.key});

  @override
  State<SponsorTicketScreen> createState() => _SponsorTicketScreenState();
}

class _SponsorTicketScreenState extends State<SponsorTicketScreen> {
  List<SponsorTicketModel> _tickets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getMySponsorTickets();
      if (mounted) {
        setState(() {
          _tickets =
              data.map((j) => SponsorTicketModel.fromJson(j)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, ApiService.extractError(e));
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Sponsor Tickets')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tickets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.confirmation_number_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No sponsor tickets yet.',
                          style: TextStyle(
                              color: AppTheme.textSecondaryOf(context))),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tickets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) =>
                      _buildTicketCard(_tickets[index]),
                ),
    );
  }

  Widget _buildTicketCard(SponsorTicketModel ticket) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Event #${ticket.eventId}',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              ticket.receiptNumber,
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textSecondaryOf(context)),
            ),
            const SizedBox(height: 16),
            if (ticket.encryptedQrPayload != null &&
                ticket.encryptedQrPayload!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: ticket.encryptedQrPayload!,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${ticket.categoryCount} categor${ticket.categoryCount == 1 ? "y" : "ies"} won',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  if (ticket.categoryNames.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    ...ticket.categoryNames.map(
                      (name) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle,
                                size: 14, color: AppTheme.successColor),
                            const SizedBox(width: 6),
                            Text(name, style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (ticket.scannedAt != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified, size: 16, color: AppTheme.successColor),
                  const SizedBox(width: 4),
                  Text(
                    'Scanned',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.successColor),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
