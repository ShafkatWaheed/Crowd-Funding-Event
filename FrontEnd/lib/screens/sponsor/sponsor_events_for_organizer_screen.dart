import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';

class SponsorEventsForOrganizerScreen extends StatefulWidget {
  final int sponsorUserId;
  final String sponsorName;

  const SponsorEventsForOrganizerScreen({
    super.key,
    required this.sponsorUserId,
    required this.sponsorName,
  });

  @override
  State<SponsorEventsForOrganizerScreen> createState() =>
      _SponsorEventsForOrganizerScreenState();
}

class _SponsorEventsForOrganizerScreenState
    extends State<SponsorEventsForOrganizerScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data =
          await _api.getSponsorEventsForOrganizer(widget.sponsorUserId);
      if (!mounted) return;
      setState(() {
        _events = data.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiService.extractError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceOf(context),
      appBar: AppBar(
        title: Text(widget.sponsorName),
        backgroundColor: AppTheme.cardOf(context),
        foregroundColor: AppTheme.textPrimaryOf(context),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_busy_rounded,
                          size: 56,
                          color: AppTheme.textSecondaryOf(context)
                              .withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text('No funded events',
                          style: TextStyle(
                              color: AppTheme.textSecondaryOf(context))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _events.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) =>
                        _EventCard(event: _events[i]),
                  ),
                ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final title = event['title'] ?? 'Untitled';
    final status = event['status'] ?? '';
    final venueName = event['venue_name'];
    final venueCity = event['venue_city'];
    final startTime = event['start_time'];
    final totalCents = event['total_amount_cents'] ?? 0;
    final amount = '\$${(totalCents / 100).toStringAsFixed(2)}';
    final bids = (event['bids'] as List?) ?? [];
    final summary = event['bid_summary'] as Map<String, dynamic>? ?? {};
    final pending = summary['pending'] ?? 0;
    final accepted = summary['accepted'] ?? 0;
    final rejected = summary['rejected'] ?? 0;
    final paid = summary['paid'] ?? 0;

    String dateStr = '';
    if (startTime != null) {
      try {
        final dt = DateTime.parse(startTime);
        dateStr = DateFormat('MMM d, yyyy').format(dt);
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () => context.push('/events/${event['event_id']}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryOf(context))),
                ),
                _statusBadge(context, status),
              ],
            ),
            const SizedBox(height: 8),
            if (dateStr.isNotEmpty || venueName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    if (dateStr.isNotEmpty) ...[
                      Icon(Icons.calendar_today_rounded,
                          size: 14,
                          color: AppTheme.textSecondaryOf(context)),
                      const SizedBox(width: 4),
                      Text(dateStr,
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryOf(context))),
                    ],
                    if (dateStr.isNotEmpty && venueName != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('\u2022',
                            style: TextStyle(
                                color: AppTheme.textSecondaryOf(context),
                                fontSize: 10)),
                      ),
                    if (venueName != null) ...[
                      Icon(Icons.location_on_rounded,
                          size: 14,
                          color: AppTheme.textSecondaryOf(context)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          venueCity != null
                              ? '$venueName, $venueCity'
                              : venueName,
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryOf(context)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            Divider(color: AppTheme.dividerOf(context), height: 16),
            Row(
              children: [
                Text('Total: ',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryOf(context))),
                Text(amount,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.secondaryColor)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (pending > 0)
                  _summaryChip(context, '$pending Under Review', Colors.orange),
                if (accepted > 0)
                  _summaryChip(
                      context, '$accepted Accepted', AppTheme.accentColor),
                if (paid > 0)
                  _summaryChip(
                      context, '$paid Paid', AppTheme.secondaryColor),
                if (rejected > 0)
                  _summaryChip(
                      context, '$rejected Rejected', AppTheme.errorColor),
              ],
            ),
            if (bids.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...bids.map((b) {
                final cat = b['category'] ?? '';
                final cents = b['amount_cents'] ?? 0;
                final bidStatus = b['status'] ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.circle,
                          size: 6, color: _bidStatusColor(bidStatus)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(cat,
                            style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textPrimaryOf(context))),
                      ),
                      Text(
                        '\$${(cents / 100).toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryOf(context)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                          bidStatus == 'pending'
                              ? 'under review'
                              : bidStatus,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _bidStatusColor(bidStatus))),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(BuildContext context, String status) {
    final color = switch (status) {
      'approved' => AppTheme.secondaryColor,
      'live' => const Color(0xFFE11900),
      'selling_tickets' => AppTheme.accentColor,
      'waiting_event_date' => Colors.orange,
      'completed' => Colors.grey,
      'cancelled' => AppTheme.errorColor,
      _ => AppTheme.textSecondaryOf(context),
    };
    final label = switch (status) {
      'approved' => 'Funding',
      'live' => 'Live',
      'selling_tickets' => 'Selling Tickets',
      'waiting_event_date' => 'Awaiting Date',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _summaryChip(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Color _bidStatusColor(String status) {
    return switch (status) {
      'pending' => Colors.orange,
      'accepted' => AppTheme.accentColor,
      'paid' => AppTheme.secondaryColor,
      'rejected' => AppTheme.errorColor,
      _ => Colors.grey,
    };
  }
}
