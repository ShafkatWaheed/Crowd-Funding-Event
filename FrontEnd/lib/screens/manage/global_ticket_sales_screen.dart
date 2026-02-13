import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';

/// Shows ticket sales across ALL organiser events.
/// [scannedOnly] toggles between all-sales and scanned-only view.
class GlobalTicketSalesScreen extends StatefulWidget {
  final bool scannedOnly;
  const GlobalTicketSalesScreen({super.key, this.scannedOnly = false});

  @override
  State<GlobalTicketSalesScreen> createState() =>
      _GlobalTicketSalesScreenState();
}

class _GlobalTicketSalesScreenState extends State<GlobalTicketSalesScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
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
      final api = context.read<ApiService>();
      // Get organiser's events
      final events = await api.getMyEvents();
      final List<Map<String, dynamic>> combined = [];

      for (final evt in events) {
        final eventId = evt['id'] as int;
        final eventTitle = evt['title'] ?? 'Event #$eventId';
        try {
          final sales = widget.scannedOnly
              ? await api.getScannedTickets(eventId)
              : await api.getTicketSales(eventId);
          for (final s in sales) {
            combined.add({
              ...Map<String, dynamic>.from(s),
              '_event_title': eventTitle,
              '_event_id': eventId,
            });
          }
        } catch (_) {
          // skip events we can't fetch sales for
        }
      }

      // Sort newest first
      combined.sort((a, b) {
        final ac = a['created_at'] ?? '';
        final bc = b['created_at'] ?? '';
        return bc.toString().compareTo(ac.toString());
      });

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
      _filtered = _all.where((s) {
        final attendee =
            (s['attendee_display_name'] ?? '').toString().toLowerCase();
        final tier = (s['tier_name'] ?? '').toString().toLowerCase();
        final code = (s['ticket_code'] ?? '').toString().toLowerCase();
        final event = (s['_event_title'] ?? '').toString().toLowerCase();
        return attendee.contains(q) ||
            tier.contains(q) ||
            code.contains(q) ||
            event.contains(q);
      }).toList();
    }
  }

  int get _totalRevenue =>
      _all.fold<int>(0, (s, e) => s + ((e['amount_paid_cents'] ?? 0) as int));

  int get _totalCommission =>
      _all.fold<int>(0, (s, e) => s + ((e['commission_cents'] ?? 0) as int));

  int get _totalNetToOrganizer =>
      _all.fold<int>(0, (s, e) => s + ((e['net_to_organizer_cents'] ?? 0) as int));

  @override
  Widget build(BuildContext context) {
    final title =
        widget.scannedOnly ? 'All Scanned Tickets' : 'All Ticket Sales';

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
        title: Text(title),
      ),
      body: Column(
        children: [
          // ── Search ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search attendee, event, tier, code…',
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
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppTheme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppTheme.dividerColor),
                ),
              ),
              onChanged: (_) => setState(() => _applySearch()),
            ),
          ),

          // ── Stats ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _chip(
                  '${_all.length} ${widget.scannedOnly ? 'scanned' : 'sold'}',
                  widget.scannedOnly
                      ? Icons.qr_code_scanner_rounded
                      : Icons.confirmation_number_rounded,
                  widget.scannedOnly
                      ? AppTheme.successColor
                      : AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                _chip(
                  '\$${(_totalRevenue / 100).toStringAsFixed(2)}',
                  Icons.attach_money_rounded,
                  Colors.teal,
                ),
                if (_totalCommission > 0) ...[
                  const SizedBox(width: 8),
                  _chip(
                    'Net \$${(_totalNetToOrganizer / 100).toStringAsFixed(2)}',
                    Icons.account_balance_wallet_rounded,
                    Colors.deepPurple,
                  ),
                ],
                if (_searchCtrl.text.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _chip(
                    '${_filtered.length} match${_filtered.length == 1 ? '' : 'es'}',
                    Icons.filter_list_rounded,
                    AppTheme.accentColor,
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
                    ? _errorWidget()
                    : _filtered.isEmpty
                        ? _emptyWidget()
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

  Widget _card(Map<String, dynamic> sale) {
    final tier = sale['tier_name'] ?? 'Unknown';
    final attendee =
        sale['attendee_display_name'] ?? 'User #${sale['user_id']}';
    final code = sale['ticket_code'] ?? '';
    final amount = (sale['amount_paid_cents'] ?? 0) as int;
    final commission = (sale['commission_cents'] ?? 0) as int;
    final netAmount = (sale['net_to_organizer_cents'] ?? 0) as int;
    final scannedAt = sale['scanned_at'];
    final scannedBy = sale['scanned_by_display_name'];
    final isScanned = scannedAt != null;
    final eventTitle = sale['_event_title'] ?? '';
    final createdAt = sale['created_at'] != null
        ? DateFormat.yMMMd()
            .add_jm()
            .format(DateTime.parse(sale['created_at']).toLocal())
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isScanned
            ? Border.all(
                color: AppTheme.successColor.withValues(alpha: 0.25))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isScanned
                    ? AppTheme.successColor.withValues(alpha: 0.1)
                    : AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isScanned
                    ? Icons.check_circle_rounded
                    : Icons.confirmation_number_rounded,
                size: 20,
                color: isScanned
                    ? AppTheme.successColor
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(attendee,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(eventTitle,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.accentColor)),
                  Text('$tier  •  $code',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[500])),
                  if (createdAt.isNotEmpty)
                    Text(createdAt,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[400])),
                  if (isScanned)
                    Row(
                      children: [
                        Icon(Icons.qr_code_scanner,
                            size: 12, color: AppTheme.successColor),
                        const SizedBox(width: 3),
                        Text(
                          'Scanned${scannedBy != null ? ' by $scannedBy' : ''}',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.successColor),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount == 0 ? 'FREE' : '\$${(amount / 100).toStringAsFixed(2)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: amount == 0 ? Colors.green.shade700 : null),
                ),
                if (commission > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Net \$${(netAmount / 100).toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _errorWidget() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('Failed to load',
                style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );

  Widget _emptyWidget() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.scannedOnly
                  ? Icons.qr_code_scanner_rounded
                  : Icons.confirmation_number_outlined,
              size: 56,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 12),
            Text(
              _searchCtrl.text.isNotEmpty
                  ? 'No matching tickets'
                  : widget.scannedOnly
                      ? 'No scanned tickets yet'
                      : 'No ticket sales yet',
              style: TextStyle(color: Colors.grey[500], fontSize: 15),
            ),
          ],
        ),
      );
}
