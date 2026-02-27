import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/sponsor.dart';

class ReceiptHeaderCard extends StatelessWidget {
  final SponsorTicketModel ticket;

  const ReceiptHeaderCard({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D3B66), Color(0xFF1B5E8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.workspace_premium_rounded,
              color: context.reviewAccent, size: 40),
          const SizedBox(height: 10),
          Text(
            ticket.eventTitle ?? 'Sponsor Ticket',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: context.reviewAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'SPONSOR PASS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: context.reviewAccent,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ticket.receiptNumber,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
