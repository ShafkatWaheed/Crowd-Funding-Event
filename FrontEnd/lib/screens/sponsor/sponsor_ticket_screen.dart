import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config/theme.dart';
import '../../models/sponsor.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/shimmer_loaders.dart';

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
      appBar: AppBar(title: const Text('Sponsor Tickets')),
      body: _loading
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List.generate(3, (_) => const ShimmerListTile()),
              ),
            )
          : _tickets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceOf(context),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Icon(Icons.confirmation_number_outlined,
                            size: 40,
                            color: AppTheme.textSecondaryOf(context)),
                      ),
                      const SizedBox(height: 16),
                      Text('No sponsor tickets yet',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryOf(context))),
                      const SizedBox(height: 4),
                      Text(
                          'Tickets are created when your bids are accepted.',
                          style: TextStyle(
                              color: AppTheme.textSecondaryOf(context))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tickets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final ticket = _tickets[index];
                      return _SponsorTicketCard(
                        ticket: ticket,
                        onTap: () => _openReceipt(ticket),
                      );
                    },
                  ),
                ),
    );
  }

  void _openReceipt(SponsorTicketModel ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SponsorTicketReceiptPage(ticket: ticket),
      ),
    );
  }
}

class _SponsorTicketCard extends StatelessWidget {
  final SponsorTicketModel ticket;
  final VoidCallback onTap;

  const _SponsorTicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    DateTime? startDt;
    if (ticket.eventStartTime != null) {
      try {
        startDt = DateTime.parse(ticket.eventStartTime!);
      } catch (_) {}
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dividerOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D3B66), Color(0xFF1B5E8A)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.confirmation_number_rounded,
                      color: Colors.white70, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ticket.eventTitle ?? 'Event #${ticket.eventId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'SPONSOR',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (startDt != null)
                    _infoRow(context, Icons.schedule_rounded,
                        DateFormat('EEE, MMM d \u2022 h:mm a').format(startDt)),
                  if (ticket.venueName != null) ...[
                    const SizedBox(height: 4),
                    _infoRow(
                        context,
                        Icons.location_on_rounded,
                        '${ticket.venueName}'
                            '${ticket.venueCity != null ? ', ${ticket.venueCity}' : ''}'),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        ticket.receiptNumber,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondaryOf(context),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const Spacer(),
                      if (ticket.scannedAt != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded,
                                size: 14, color: AppTheme.successColor),
                            const SizedBox(width: 3),
                            Text('Scanned',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.successColor)),
                            if (ticket.scanCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${ticket.scanCount} ${ticket.scanCount == 1 ? 'entry' : 'entries'}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: ticket.categories.map((cat) {
                      final isPaid = cat.status == 'paid';
                      final color =
                          isPaid ? AppTheme.successColor : AppTheme.warningColor;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPaid
                                  ? Icons.check_circle_rounded
                                  : Icons.hourglass_top_rounded,
                              size: 13,
                              color: color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${cat.name} \u2022 ${cat.amountDisplay}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppTheme.textSecondaryOf(context)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Receipt Detail Page ──

class _SponsorTicketReceiptPage extends StatelessWidget {
  final SponsorTicketModel ticket;

  const _SponsorTicketReceiptPage({required this.ticket});

  @override
  Widget build(BuildContext context) {
    DateTime? startDt;
    if (ticket.eventStartTime != null) {
      try {
        startDt = DateTime.parse(ticket.eventStartTime!);
      } catch (_) {}
    }
    DateTime? createdDt;
    if (ticket.createdAt != null) {
      try {
        createdDt = DateTime.parse(ticket.createdAt!);
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sponsor Ticket')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Header ──
            Container(
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
                  const Icon(Icons.workspace_premium_rounded,
                      color: Colors.amber, size: 40),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'SPONSOR PASS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.amber,
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
            ),
            const SizedBox(height: 20),

            // ── QR Code ──
            if (ticket.encryptedQrPayload != null &&
                ticket.encryptedQrPayload!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.cardOf(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.dividerOf(context)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Scan at Event Entry',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardOf(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(
                        data: ticket.encryptedQrPayload!,
                        version: QrVersions.auto,
                        size: 180,
                        gapless: true,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Present this QR code for sponsor verification',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // ── Event Details ──
            _section(
              context,
              title: 'Event Details',
              icon: Icons.event_rounded,
              children: [
                _detailRow(context, 'Event',
                    ticket.eventTitle ?? 'Event #${ticket.eventId}'),
                if (startDt != null)
                  _detailRow(context, 'Date',
                      DateFormat('EEEE, MMMM d, y \u2022 h:mm a').format(startDt)),
                if (ticket.venueName != null)
                  _detailRow(context, 'Venue', ticket.venueName!),
                if (ticket.venueAddress != null)
                  _detailRow(context, 'Address', ticket.venueAddress!),
                if (ticket.venueCity != null)
                  _detailRow(context, 'City', ticket.venueCity!),
              ],
            ),
            const SizedBox(height: 16),

            // ── Sponsorship Spots ──
            _section(
              context,
              title: 'Sponsorship Spots',
              icon: Icons.workspace_premium_rounded,
              children: [
                ...ticket.categories.map((cat) {
                  final isPaid = cat.status == 'paid';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (isPaid
                                ? AppTheme.successColor
                                : AppTheme.warningColor)
                            .withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (isPaid
                                  ? AppTheme.successColor
                                  : AppTheme.warningColor)
                              .withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPaid
                                ? Icons.check_circle_rounded
                                : Icons.hourglass_top_rounded,
                            size: 20,
                            color: isPaid
                                ? AppTheme.successColor
                                : AppTheme.warningColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppTheme.textPrimaryOf(context),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isPaid ? 'Paid' : 'Accepted — Pending Payment',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isPaid
                                        ? AppTheme.successColor
                                        : AppTheme.warningColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            cat.amountDisplay,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AppTheme.textPrimaryOf(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                Divider(height: 1, color: AppTheme.dividerOf(context)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                    Text(
                      ticket.totalAmountDisplay,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Ticket Info ──
            _section(
              context,
              title: 'Ticket Info',
              icon: Icons.info_outline_rounded,
              children: [
                _detailRow(context, 'Receipt', ticket.receiptNumber),
                if (createdDt != null)
                  _detailRow(context, 'Issued',
                      DateFormat('MMM d, y \u2022 h:mm a').format(createdDt)),
                if (ticket.scanCount > 0)
                  _detailRow(context, 'Entries', '${ticket.scanCount}'),
                _detailRow(
                    context,
                    'Status',
                    ticket.scannedAt != null
                        ? 'Scanned'
                        : 'Valid — Not Scanned'),
              ],
            ),
            const SizedBox(height: 16),

            // ── Copy Receipt Number ──
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(
                      ClipboardData(text: ticket.receiptNumber));
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
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.textSecondaryOf(context)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondaryOf(context),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
