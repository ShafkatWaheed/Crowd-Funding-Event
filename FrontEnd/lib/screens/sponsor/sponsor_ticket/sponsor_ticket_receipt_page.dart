import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/sponsor.dart';
import '../../../utils/date_time_utils.dart';
import '../../../widgets/app_toast.dart';
import 'delegates_card.dart';
import 'payment_history_card.dart';
import 'receipt_header_card.dart';
import 'receipt_qr_card.dart';
import 'receipt_section_helpers.dart';
import 'sponsorship_spots_card.dart';

class SponsorTicketReceiptPage extends StatelessWidget {
  final SponsorTicketModel ticket;

  const SponsorTicketReceiptPage({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    DateTime? startDt;
    if (ticket.eventStartTime != null) {
      try {
        startDt = DateTime.parse(ticket.eventStartTime!);
      } catch (e) {
        debugPrint(e.toString());
      }
    }
    DateTime? createdDt;
    if (ticket.createdAt != null) {
      try {
        createdDt = DateTime.parse(ticket.createdAt!);
      } catch (e) {
        debugPrint(e.toString());
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sponsor Ticket')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ReceiptHeaderCard(ticket: ticket),
            const SizedBox(height: 20),

            if (ticket.encryptedQrPayload != null &&
                ticket.encryptedQrPayload!.isNotEmpty) ...[
              ReceiptQrCard(qrPayload: ticket.encryptedQrPayload!),
              const SizedBox(height: 16),
            ],

            _eventDetailsSection(context, startDt),
            const SizedBox(height: 16),

            SponsorshipSpotsCard(ticket: ticket),
            const SizedBox(height: 16),

            PaymentHistoryCard(ticket: ticket),
            if (ticket.categories
                .any((c) => c.paymentReceiptNumber != null))
              const SizedBox(height: 16),

            _ticketInfoSection(context, createdDt),
            const SizedBox(height: 16),

            DelegatesCard(ticketId: ticket.id),
            const SizedBox(height: 16),

            _copyReceiptButton(context),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _eventDetailsSection(BuildContext context, DateTime? startDt) {
    return SectionCard(
      title: 'Event Details',
      icon: Icons.event_rounded,
      children: [
        DetailRow(
            label: 'Event',
            value: ticket.eventTitle ?? 'Event #${ticket.eventId}'),
        if (startDt != null)
          DetailRow(
              label: 'Date', value: AppDateFormat.eventCard(startDt)),
        if (ticket.venueName != null)
          DetailRow(label: 'Venue', value: ticket.venueName!),
        if (ticket.venueAddress != null)
          DetailRow(label: 'Address', value: ticket.venueAddress!),
        if (ticket.venueCity != null)
          DetailRow(label: 'City', value: ticket.venueCity!),
      ],
    );
  }

  Widget _ticketInfoSection(BuildContext context, DateTime? createdDt) {
    return SectionCard(
      title: 'Ticket Info',
      icon: Icons.info_outline_rounded,
      children: [
        DetailRow(label: 'Receipt', value: ticket.receiptNumber),
        if (createdDt != null)
          DetailRow(
              label: 'Issued',
              value: AppDateFormat.fullDateTime(createdDt)),
        if (ticket.scanCount > 0)
          DetailRow(label: 'Entries', value: '${ticket.scanCount}'),
        DetailRow(
          label: 'Status',
          value: ticket.scannedAt != null
              ? 'Scanned'
              : 'Valid — Not Scanned',
        ),
      ],
    );
  }

  Widget _copyReceiptButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Clipboard.setData(ClipboardData(text: ticket.receiptNumber));
          AppToast.success(context, 'Receipt number copied');
        },
        icon: const Icon(Icons.copy_rounded, size: 18),
        label: const Text('Copy Receipt Number'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
