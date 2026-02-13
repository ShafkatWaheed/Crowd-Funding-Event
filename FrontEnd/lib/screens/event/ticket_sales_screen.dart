import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';

/// Full-page ticket sales list.
/// [scannedOnly] = false → all sales, true → only scanned tickets.
class TicketSalesScreen extends StatefulWidget {
  final int eventId;
  final bool scannedOnly;

  const TicketSalesScreen({
    super.key,
    required this.eventId,
    this.scannedOnly = false,
  });

  @override
  State<TicketSalesScreen> createState() => _TicketSalesScreenState();
}

class _TicketSalesScreenState extends State<TicketSalesScreen> {
  final _searchCtrl = TextEditingController();
  List<dynamic> _all = [];
  List<dynamic> _filtered = [];
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
      final data = widget.scannedOnly
          ? await api.getScannedTickets(widget.eventId)
          : await api.getTicketSales(widget.eventId);
      setState(() {
        _all = data;
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
        final tierName = (s['tier_name'] ?? '').toString().toLowerCase();
        final code = (s['ticket_code'] ?? '').toString().toLowerCase();
        final userId = '${s['user_id']}'.toLowerCase();
        return attendee.contains(q) ||
            tierName.contains(q) ||
            code.contains(q) ||
            userId.contains(q);
      }).toList();
    }
  }

  int get _totalRevenue =>
      _all.fold<int>(0, (s, e) => s + ((e['amount_paid_cents'] ?? 0) as int));

  @override
  Widget build(BuildContext context) {
    final title = widget.scannedOnly ? 'Scanned Tickets' : 'All Ticket Sales';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(title),
      ),
      body: Column(
        children: [
          // ── Search bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search attendee, tier, code…',
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

          // ── Stats row ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _statChip(
                  '${_all.length} ${widget.scannedOnly ? 'scanned' : 'sold'}',
                  widget.scannedOnly
                      ? Icons.qr_code_scanner_rounded
                      : Icons.confirmation_number_rounded,
                  widget.scannedOnly
                      ? AppTheme.successColor
                      : AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                _statChip(
                  '\$${(_totalRevenue / 100).toStringAsFixed(2)}',
                  Icons.attach_money_rounded,
                  Colors.teal,
                ),
                if (_searchCtrl.text.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _statChip(
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

          // ── Content ──
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline,
                                size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text('Failed to load',
                                style: TextStyle(color: Colors.grey[500])),
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
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 15),
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
                              itemBuilder: (context, i) =>
                                  _buildCard(_filtered[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(dynamic sale) {
    final tierName = sale['tier_name'] ?? 'Unknown';
    final attendee =
        sale['attendee_display_name'] ?? 'User #${sale['user_id']}';
    final code = sale['ticket_code'] ?? '';
    final amount = (sale['amount_paid_cents'] ?? 0) as int;
    final scannedAt = sale['scanned_at'];
    final scannedBy = sale['scanned_by_display_name'];
    final isScanned = scannedAt != null;
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
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
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
                size: 22,
                color: isScanned
                    ? AppTheme.successColor
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 14),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(attendee,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 3),
                  Text('$tierName  •  $code',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[500])),
                  if (createdAt.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('Purchased $createdAt',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[400])),
                  ],
                  if (isScanned) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.qr_code_scanner,
                            size: 13, color: AppTheme.successColor),
                        const SizedBox(width: 4),
                        Text(
                          'Scanned${scannedBy != null ? ' by $scannedBy' : ''}',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.successColor),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Amount
            Text(
              '\$${(amount / 100).toStringAsFixed(2)}',
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: -0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, IconData icon, Color color) {
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
}
