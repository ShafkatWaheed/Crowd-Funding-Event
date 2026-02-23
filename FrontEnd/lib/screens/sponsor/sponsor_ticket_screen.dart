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
import 'sponsor_payment_receipt_screen.dart';

class SponsorTicketScreen extends StatefulWidget {
  const SponsorTicketScreen({super.key});

  @override
  State<SponsorTicketScreen> createState() => _SponsorTicketScreenState();
}

class _SponsorTicketScreenState extends State<SponsorTicketScreen> {
  List<SponsorTicketModel> _tickets = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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

  List<SponsorTicketModel> get _filtered {
    if (_searchQuery.isEmpty) return _tickets;
    final q = _searchQuery.toLowerCase();
    return _tickets.where((t) {
      final title = (t.eventTitle ?? '').toLowerCase();
      final venue = (t.venueName ?? '').toLowerCase();
      final receipt = t.receiptNumber.toLowerCase();
      final cats = t.categories.map((c) => c.name.toLowerCase()).join(' ');
      return title.contains(q) ||
          venue.contains(q) ||
          receipt.contains(q) ||
          cats.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

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
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: InputDecoration(
                            hintText: 'Search tickets\u2026',
                            prefixIcon:
                                const Icon(Icons.search_rounded, size: 20),
                            suffixIcon: _searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded,
                                        size: 18),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: AppTheme.inputFillOf(context),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            isDense: true,
                          ),
                          style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textPrimaryOf(context)),
                        ),
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text('No matching tickets',
                                    style: TextStyle(
                                        color: AppTheme.textSecondaryOf(
                                            context))),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 16),
                                itemBuilder: (context, index) {
                                  final ticket = filtered[index];
                                  return _SponsorTicketCard(
                                    ticket: ticket,
                                    onTap: () => _openReceipt(ticket),
                                  );
                                },
                              ),
                      ),
                    ],
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

class _SponsorTicketCard extends StatefulWidget {
  final SponsorTicketModel ticket;
  final VoidCallback onTap;

  const _SponsorTicketCard({required this.ticket, required this.onTap});

  @override
  State<_SponsorTicketCard> createState() => _SponsorTicketCardState();
}

class _SponsorTicketCardState extends State<_SponsorTicketCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    DateTime? startDt;
    if (ticket.eventStartTime != null) {
      try {
        startDt = DateTime.parse(ticket.eventStartTime!);
      } catch (_) {}
    }

    final paidCount = ticket.categories.where((c) => c.isPaid).length;
    final refundedCount = ticket.categories.where((c) => c.isRefunded).length;
    final pendingCount = ticket.categories.length - paidCount - refundedCount;

    return Container(
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dividerOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: widget.onTap,
              child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D3B66), Color(0xFF1B5E8A)],
                ),
                borderRadius: _expanded
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      )
                    : BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.confirmation_number_rounded,
                      color: Colors.white70, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket.eventTitle ?? 'Event #${ticket.eventId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (startDt != null) ...[
                              Icon(Icons.schedule_rounded,
                                  size: 12, color: Colors.white60),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('MMM d, y').format(startDt),
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white60),
                              ),
                              if (ticket.venueName != null)
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 5),
                                  child: Text('\u2022',
                                      style: TextStyle(
                                          fontSize: 8, color: Colors.white38)),
                                ),
                            ],
                            if (ticket.venueName != null) ...[
                              Icon(Icons.location_on_rounded,
                                  size: 12, color: Colors.white60),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  ticket.venueName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.white60),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _headerChip(
                                '${ticket.categories.length} categor${ticket.categories.length == 1 ? "y" : "ies"}',
                                Colors.white24,
                                Colors.white70),
                            const SizedBox(width: 6),
                            if (paidCount > 0)
                              _headerChip('$paidCount paid',
                                  AppTheme.successColor.withValues(alpha: 0.3),
                                  Colors.white),
                            if (paidCount > 0 && refundedCount > 0)
                              const SizedBox(width: 6),
                            if (refundedCount > 0)
                              _headerChip('$refundedCount refunded',
                                  AppTheme.errorColor.withValues(alpha: 0.3),
                                  Colors.white),
                            if ((paidCount > 0 || refundedCount > 0) &&
                                pendingCount > 0)
                              const SizedBox(width: 6),
                            if (pendingCount > 0)
                              _headerChip('$pendingCount pending',
                                  AppTheme.warningColor.withValues(alpha: 0.3),
                                  Colors.white),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'SPONSOR',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (ticket.scannedAt != null) ...[
                        const SizedBox(height: 6),
                        Icon(Icons.verified_rounded,
                            size: 16, color: AppTheme.successColor),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceOf(context),
                    border: Border(
                      top: BorderSide(color: AppTheme.dividerOf(context)),
                      bottom: _expanded
                          ? BorderSide(color: AppTheme.dividerOf(context))
                          : BorderSide.none,
                    ),
                    borderRadius: _expanded
                        ? BorderRadius.zero
                        : const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                  ),
                  child: Row(
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
                      Text(
                        _expanded ? 'Hide categories' : 'Show categories',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            size: 20, color: AppTheme.accentColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...ticket.categories.map((cat) {
                      final isRefunded = cat.isRefunded;
                      final isPaid = cat.isPaid;
                      final hasReceipt = cat.paymentId != null;
                      final color = isRefunded
                          ? AppTheme.errorColor
                          : isPaid
                              ? AppTheme.successColor
                              : AppTheme.warningColor;
                      final icon = isRefunded
                          ? Icons.undo_rounded
                          : isPaid
                              ? Icons.check_circle_rounded
                              : Icons.hourglass_top_rounded;
                      final statusLabel = isRefunded
                          ? 'Refunded'
                          : isPaid
                              ? 'Paid'
                              : 'Pending';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: color.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: hasReceipt
                                ? () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            SponsorPaymentReceiptScreen(
                                                paymentId: cat.paymentId!),
                                      ),
                                    )
                                : null,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: color.withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(icon, size: 16, color: color),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          cat.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: AppTheme.textPrimaryOf(
                                                context),
                                            decoration: isRefunded
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        isRefunded
                                            ? '-${cat.amountDisplay}'
                                            : cat.amountDisplay,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: isRefunded
                                              ? AppTheme.errorColor
                                              : AppTheme.textPrimaryOf(
                                                  context),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const SizedBox(width: 24),
                                      Text(
                                        statusLabel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: color,
                                        ),
                                      ),
                                      if (cat.paymentReceiptNumber !=
                                          null) ...[
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6),
                                          child: Text('\u2022',
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  color:
                                                      AppTheme.textSecondaryOf(
                                                          context))),
                                        ),
                                        Icon(Icons.receipt_long_rounded,
                                            size: 11,
                                            color: AppTheme.textSecondaryOf(
                                                context)),
                                        const SizedBox(width: 3),
                                        Expanded(
                                          child: Text(
                                            cat.paymentReceiptNumber!,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color:
                                                  AppTheme.textSecondaryOf(
                                                      context),
                                              fontFamily: 'monospace',
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                      if (hasReceipt) ...[
                                        const SizedBox(width: 4),
                                        Icon(Icons.chevron_right_rounded,
                                            size: 16,
                                            color: AppTheme.textSecondaryOf(
                                                context)),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
    );
  }

  Widget _headerChip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: fg)),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
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
                  final isRefunded = cat.isRefunded;
                  final isPaid = cat.isPaid;
                  final statusColor = isRefunded
                      ? AppTheme.errorColor
                      : isPaid
                          ? AppTheme.successColor
                          : AppTheme.warningColor;
                  final statusIcon = isRefunded
                      ? Icons.undo_rounded
                      : isPaid
                          ? Icons.check_circle_rounded
                          : Icons.hourglass_top_rounded;
                  final statusLabel = isRefunded
                      ? 'Refunded'
                      : isPaid
                          ? 'Paid'
                          : 'Accepted — Pending Payment';
                  final hasReceipt = cat.paymentId != null;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: statusColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: hasReceipt
                            ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SponsorPaymentReceiptScreen(
                                        paymentId: cat.paymentId!),
                                  ),
                                )
                            : null,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.2),
                            ),
                          ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(statusIcon, size: 20, color: statusColor),
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
                                          color: isRefunded
                                              ? AppTheme.textSecondaryOf(context)
                                              : AppTheme.textPrimaryOf(context),
                                          decoration: isRefunded
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        statusLabel,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: statusColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  isRefunded ? '-${cat.amountDisplay}' : cat.amountDisplay,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: isRefunded
                                        ? AppTheme.errorColor
                                        : AppTheme.textPrimaryOf(context),
                                    decoration: isRefunded
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            if (cat.paymentReceiptNumber != null) ...[
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.only(left: 30),
                                child: Row(
                                  children: [
                                    Icon(Icons.receipt_long_rounded, size: 12,
                                        color: AppTheme.textSecondaryOf(context)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        cat.paymentReceiptNumber!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondaryOf(context),
                                          fontFamily: 'monospace',
                                        ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (cat.prerequisites.isNotEmpty && !isRefunded) ...[
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.only(left: 30),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Requirements',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textSecondaryOf(context),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  ...cat.prerequisites.map((prereq) {
                                    final uploaded = prereq.isUploaded;
                                    final uploadColor = uploaded
                                        ? (prereq.uploadStatus == 'approved'
                                            ? AppTheme.successColor
                                            : prereq.uploadStatus == 'rejected'
                                                ? AppTheme.errorColor
                                                : AppTheme.warningColor)
                                        : AppTheme.textSecondaryOf(context);
                                    final uploadLabel = uploaded
                                        ? (prereq.uploadStatus == 'approved'
                                            ? 'Approved'
                                            : prereq.uploadStatus == 'rejected'
                                                ? 'Rejected'
                                                : 'Pending')
                                        : 'Not uploaded';
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          Icon(
                                            uploaded ? Icons.check_circle_outline_rounded : Icons.radio_button_unchecked_rounded,
                                            size: 14,
                                            color: uploadColor,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              prereq.name,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: AppTheme.textPrimaryOf(context),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: uploadColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              uploadLabel,
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                color: uploadColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            if (hasReceipt) ...[
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.only(left: 30),
                                child: Row(
                                  children: [
                                    Icon(Icons.open_in_new_rounded, size: 12,
                                        color: statusColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      isRefunded ? 'View Refund Receipt' : 'View Payment Receipt',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: statusColor,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(Icons.chevron_right_rounded,
                                        size: 16, color: statusColor),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  ),
                  );
                }),
                Divider(height: 1, color: AppTheme.dividerOf(context)),
                const SizedBox(height: 10),
                if (ticket.hasRefunds) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subtotal',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                      Text(
                        ticket.totalAmountDisplay,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Refunded',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.errorColor,
                        ),
                      ),
                      Text(
                        '-${ticket.refundedTotalDisplay}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.errorColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Divider(height: 1, color: AppTheme.dividerOf(context)),
                  const SizedBox(height: 6),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ticket.hasRefunds ? 'Net Total' : 'Total',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                    Text(
                      ticket.hasRefunds
                          ? ticket.activeTotalDisplay
                          : ticket.totalAmountDisplay,
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

            // ── Payment History ──
            if (ticket.categories.any((c) => c.paymentReceiptNumber != null))
              ...[
                _section(
                  context,
                  title: 'Payment History',
                  icon: Icons.receipt_long_rounded,
                  children: [
                    ...ticket.categories
                        .where((c) => c.paymentReceiptNumber != null)
                        .map((cat) {
                      DateTime? payDt;
                      if (cat.paymentCreatedAt != null) {
                        try { payDt = DateTime.parse(cat.paymentCreatedAt!); } catch (_) {}
                      }
                      final isRefund = cat.isRefunded;
                      final payColor = isRefund ? AppTheme.errorColor : AppTheme.successColor;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: payColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: cat.paymentId != null
                                ? () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SponsorPaymentReceiptScreen(
                                            paymentId: cat.paymentId!),
                                      ),
                                    )
                                : null,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: payColor.withValues(alpha: 0.15),
                                ),
                              ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isRefund ? Icons.undo_rounded : Icons.payment_rounded,
                                      size: 18,
                                      color: payColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isRefund ? 'Refund — ${cat.name}' : 'Payment — ${cat.name}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: AppTheme.textPrimaryOf(context),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      isRefund ? '-${cat.amountDisplay}' : cat.amountDisplay,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: payColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const SizedBox(width: 26),
                                    Icon(Icons.tag_rounded, size: 11,
                                        color: AppTheme.textSecondaryOf(context)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        cat.paymentReceiptNumber!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondaryOf(context),
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                    if (cat.paymentId != null)
                                      Icon(Icons.chevron_right_rounded, size: 16,
                                          color: AppTheme.textSecondaryOf(context)),
                                  ],
                                ),
                                if (payDt != null) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const SizedBox(width: 26),
                                      Icon(Icons.access_time_rounded, size: 11,
                                          color: AppTheme.textSecondaryOf(context)),
                                      const SizedBox(width: 4),
                                      Text(
                                        DateFormat('MMM d, y \u2022 h:mm a').format(payDt),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondaryOf(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 16),
              ],

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
