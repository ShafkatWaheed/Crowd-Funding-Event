import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/ticket.dart';
import '../../providers/event_provider.dart';
import '../../providers/ticket_provider.dart';
import '../../widgets/app_toast.dart';

typedef _TicketEntry = ({TicketSale ticket, String eventTitle});

/// Shows waitlisted tickets across ALL organiser events.
class GlobalTicketWaitlistScreen extends StatefulWidget {
  const GlobalTicketWaitlistScreen({super.key});

  @override
  State<GlobalTicketWaitlistScreen> createState() =>
      _GlobalTicketWaitlistScreenState();
}

class _GlobalTicketWaitlistScreenState
    extends State<GlobalTicketWaitlistScreen> {
  final _searchCtrl = TextEditingController();
  List<_TicketEntry> _all = [];
  List<_TicketEntry> _filtered = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final eventRepo = context.read<EventProvider>();
      final ticketRepo = context.read<TicketProvider>();
      final events = await eventRepo.getMyEvents();
      final List<_TicketEntry> combined = [];

      for (final evt in events) {
        final eventTitle = evt.title;
        try {
          final tickets = await ticketRepo.getWaitlistedTickets(evt.id);
          for (final t in tickets) {
            combined.add((ticket: t, eventTitle: eventTitle));
          }
        } catch (_) {
          // skip events we can't access
        }
      }

      setState(() {
        _all = combined;
        _applySearch();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applySearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      _filtered = List.from(_all);
    } else {
      _filtered = _all.where((entry) {
        final event = entry.eventTitle.toLowerCase();
        final userId = '${entry.ticket.userId}'.toLowerCase();
        final tierName = (entry.ticket.tierName ?? '').toLowerCase();
        return event.contains(q) || userId.contains(q) || tierName.contains(q);
      }).toList();
    }
  }

  Future<void> _approve(int eventId, int ticketId) async {
    try {
      final repo = context.read<TicketProvider>();
      await repo.approveWaitlistedTicket(eventId, ticketId);
      if (mounted) {
        AppToast.success(context, 'Ticket approved!');
        _load();
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to approve ticket');
      }
    }
  }

  Future<void> _reject(int eventId, int ticketId) async {
    try {
      final repo = context.read<TicketProvider>();
      await repo.rejectWaitlistedTicket(eventId, ticketId);
      if (mounted) {
        AppToast.success(context, 'Ticket rejected.');
        _load();
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to reject ticket');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('All Ticket Waitlists'),
      ),
      body: Column(
        children: [
          // ── Search ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by event, user ID, or tier…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _applySearch());
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.inputFillOf(context),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppTheme.dividerOf(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppTheme.dividerOf(context)),
                ),
              ),
              onChanged: (_) => setState(() => _applySearch()),
            ),
          ),

          // ── Count ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.fundingAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_all.length} waitlisted',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.fundingAccent,
                    ),
                  ),
                ),
                if (_searchCtrl.text.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_filtered.length} match${_filtered.length == 1 ? '' : 'es'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentColor,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _load,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // ── List ──
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline,
                                size: 48, color: AppTheme.textSecondaryOf(context)),
                            const SizedBox(height: 12),
                            Text('Failed to load',
                                style: TextStyle(color: AppTheme.textSecondaryOf(context))),
                            const SizedBox(height: 8),
                            OutlinedButton(
                                onPressed: _load,
                                child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_outline,
                                    size: 56,
                                    color: AppTheme.successColor
                                        .withValues(alpha: 0.5)),
                                const SizedBox(height: 12),
                                Text(
                                  _searchCtrl.text.isNotEmpty
                                      ? 'No matching tickets'
                                      : 'No waitlisted tickets',
                                  style: TextStyle(
                                      color: AppTheme.textSecondaryOf(context), fontSize: 15),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              itemCount: _filtered.length,
                              itemBuilder: (_, i) => _card(_filtered[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _card(_TicketEntry entry) {
    final ticket = entry.ticket;
    final tierName = ticket.tierName ?? 'Unknown Tier';
    final amountCents = ticket.amountPaidCents;
    final price = amountCents == 0
        ? 'Free'
        : '\$${(amountCents / 100).toStringAsFixed(2)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.fundingAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.confirmation_number,
                  size: 22, color: context.fundingAccent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('User #${ticket.userId}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(entry.eventTitle,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.accentColor)),
                  Text('$tierName · $price',
                      style:
                          TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: () => _approve(ticket.eventId, ticket.id),
              style: FilledButton.styleFrom(
                backgroundColor:
                    AppTheme.successColor.withValues(alpha: 0.12),
                foregroundColor: AppTheme.successColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Approve', style: TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: () => _reject(ticket.eventId, ticket.id),
              style: FilledButton.styleFrom(
                backgroundColor:
                    AppTheme.errorColor.withValues(alpha: 0.1),
                foregroundColor: AppTheme.errorColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Reject', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}
