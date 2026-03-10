import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../utils/date_time_utils.dart';
import '../../models/ticket.dart';
import '../../providers/ticket_provider.dart';
import '../event/receipts/ticket_receipt_screen.dart';
import '../../widgets/shimmer_loaders.dart';

/// Shows ticket sales across ALL organiser events.
/// [scannedOnly] toggles between all-sales and scanned-only view.
class GlobalTicketSalesScreen extends StatefulWidget {
  final bool scannedOnly;
  final String? eventStatus;
  final String? genre;
  final int? eventId;
  final String? eventTitle;
  const GlobalTicketSalesScreen({super.key, this.scannedOnly = false, this.eventStatus, this.genre, this.eventId, this.eventTitle});

  @override
  State<GlobalTicketSalesScreen> createState() =>
      _GlobalTicketSalesScreenState();
}

class _GlobalTicketSalesScreenState extends State<GlobalTicketSalesScreen> {
  static const _pageSize = 20;

  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<TicketSale> _all = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent * 0.8 &&
        !_loadingMore &&
        _hasMore &&
        !_loading) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _hasMore = true;
    });
    try {
      final repo = context.read<TicketProvider>();
      final sales = await repo.getOrganizerTicketSales(
        scannedOnly: widget.scannedOnly,
        eventStatus: widget.eventStatus,
        genre: widget.genre,
        eventId: widget.eventId,
        offset: 0,
        limit: _pageSize,
      );

      setState(() {
        _all = sales;
        _hasMore = sales.length >= _pageSize;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final repo = context.read<TicketProvider>();
      final sales = await repo.getOrganizerTicketSales(
        scannedOnly: widget.scannedOnly,
        eventStatus: widget.eventStatus,
        genre: widget.genre,
        eventId: widget.eventId,
        offset: _all.length,
        limit: _pageSize,
      );
      if (mounted) {
        setState(() {
          _all.addAll(sales);
          _hasMore = sales.length >= _pageSize;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<TicketSale> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((s) {
      final attendee = (s.attendeeDisplayName ?? '').toLowerCase();
      final tier = (s.tierName ?? '').toLowerCase();
      final code = s.ticketCode.toLowerCase();
      final event = (s.eventTitle ?? '').toLowerCase();
      return attendee.contains(q) ||
          tier.contains(q) ||
          code.contains(q) ||
          event.contains(q);
    }).toList();
  }

  int get _totalRevenue =>
      _all.fold<int>(0, (s, e) => s + e.amountPaidCents);

  int get _totalCommission =>
      _all.fold<int>(0, (s, e) => s + e.commissionCents);

  int get _totalNetToOrganizer =>
      _all.fold<int>(0, (s, e) => s + e.netToOrganizerCents);

  @override
  Widget build(BuildContext context) {
    final title =
        widget.scannedOnly ? 'All Scanned Tickets' : 'All Ticket Sales';
    final filtered = _filtered;

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            if (widget.eventStatus != null || widget.genre != null || widget.eventId != null)
              Text(
                [
                  if (widget.eventStatus != null) widget.eventStatus!.replaceAll('_', ' '),
                  if (widget.genre != null) widget.genre!,
                  if (widget.eventTitle != null) widget.eventTitle!
                  else if (widget.eventId != null) 'Event #${widget.eventId}',
                ].join(' · '),
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
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
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.cardOf(context),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: AppTheme.dividerOf(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: AppTheme.dividerOf(context)),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
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
                      : AppTheme.accentColor,
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
                    '${filtered.length} match${filtered.length == 1 ? '' : 'es'}',
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
          Expanded(
            child: _loading
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: List.generate(
                          4, (_) => const ShimmerListTile()),
                    ),
                  )
                : _error != null
                    ? _errorWidget()
                    : filtered.isEmpty
                        ? _emptyWidget()
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              controller: _scrollCtrl,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              itemCount: filtered.length +
                                  (_loadingMore ? 1 : 0),
                              itemBuilder: (_, i) {
                                if (i >= filtered.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(
                                        vertical: 20),
                                    child: Center(
                                        child:
                                            CircularProgressIndicator(
                                                strokeWidth: 2)),
                                  );
                                }
                                return _card(filtered[i]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _card(TicketSale sale) {
    final saleId = sale.id;
    final eventId = sale.eventId;
    final tier = sale.tierName ?? 'Unknown';
    final attendee =
        sale.attendeeDisplayName ?? 'User #${sale.userId}';
    final code = sale.ticketCode;
    final amount = sale.amountPaidCents;
    final commission = sale.commissionCents;
    final netAmount = sale.netToOrganizerCents;
    final scannedBy = sale.scannedByDisplayName;
    final isScanned = sale.isScanned;
    final eventTitle = sale.eventTitle ?? '';
    final createdAt = AppDateFormat.isoFull(sale.createdAt.toIso8601String());

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TicketReceiptScreen(
                    eventId: eventId,
                    saleId: saleId,
                    isOrganizer: true,
                  ),
                ),
              ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isScanned
                ? AppTheme.successColor.withValues(alpha: 0.25)
                : AppTheme.dividerOf(context),
          ),
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
                      : AppTheme.surfaceOf(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isScanned
                      ? Icons.check_circle_rounded
                      : Icons.confirmation_number_rounded,
                  size: 20,
                  color: isScanned
                      ? AppTheme.successColor
                      : AppTheme.textSecondaryOf(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(attendee,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppTheme.textPrimaryOf(context))),
                    const SizedBox(height: 2),
                    Text(eventTitle,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.accentColor)),
                    Text('$tier  •  $code',
                        style: TextStyle(
                            fontSize: 11,
                            color:
                                AppTheme.textSecondaryOf(context))),
                    if (createdAt.isNotEmpty)
                      Text(createdAt,
                          style: TextStyle(
                              fontSize: 11,
                              color:
                                  AppTheme.textSecondaryOf(context))),
                    if (isScanned)
                      Row(
                        children: [
                          Icon(Icons.qr_code_scanner,
                              size: 12,
                              color: AppTheme.successColor),
                          const SizedBox(width: 3),
                          Text(
                            'Scanned${scannedBy != null ? ' by $scannedBy' : ''}',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.successColor),
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
                    amount == 0
                        ? 'FREE'
                        : '\$${(amount / 100).toStringAsFixed(2)}',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: amount == 0
                            ? AppTheme.successColor
                            : AppTheme.textPrimaryOf(context)),
                  ),
                  if (commission > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Net \$${(netAmount / 100).toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondaryOf(context)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon, Color c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = (isDark && (c.r * 255.0).round() < 50 && (c.g * 255.0).round() < 50 && (c.b * 255.0).round() < 50)
        ? AppTheme.accentColor
        : c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.cardOf(context)
            : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: color.withValues(alpha: isDark ? 0.4 : 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.textPrimaryOf(context)
                      : color)),
        ],
      ),
    );
  }

  Widget _errorWidget() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: AppTheme.textSecondaryOf(context)),
            const SizedBox(height: 12),
            Text('Failed to load',
                style: TextStyle(
                    color: AppTheme.textSecondaryOf(context))),
            const SizedBox(height: 8),
            OutlinedButton(
                onPressed: _load, child: const Text('Retry')),
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
              color: AppTheme.textSecondaryOf(context),
            ),
            const SizedBox(height: 12),
            Text(
              _searchCtrl.text.isNotEmpty
                  ? 'No matching tickets'
                  : widget.scannedOnly
                      ? 'No scanned tickets yet'
                      : 'No ticket sales yet',
              style: TextStyle(
                  color: AppTheme.textSecondaryOf(context),
                  fontSize: 15),
            ),
          ],
        ),
      );
}
