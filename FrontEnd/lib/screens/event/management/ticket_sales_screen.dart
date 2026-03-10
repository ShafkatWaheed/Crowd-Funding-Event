import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../models/ticket.dart';
import '../../../models/sponsor.dart';
import '../../../utils/date_time_utils.dart';
import '../../../providers/ticket_provider.dart';
import '../../../providers/sponsor_provider.dart';
import '../../../widgets/shimmer_loaders.dart';
import '../receipts/ticket_receipt_screen.dart';

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
  static const _pageSize = 20;

  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<TicketSale> _all = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _totalSold = 0;
  int _totalScanned = 0;

  // Scanned-view filter: 0 = All, 1 = Customer, 2 = Sponsor
  int _scannedFilter = 0;
  List<ScannedSponsorTicket> _sponsorScanned = [];
  bool _sponsorLoading = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _load();
    if (widget.scannedOnly) _loadSponsorScanned();
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
      final data = widget.scannedOnly
          ? await repo.getScannedTickets(widget.eventId, offset: 0, limit: _pageSize)
          : await repo.getTicketSales(widget.eventId, offset: 0, limit: _pageSize);
      try {
        final stats = await repo.getTicketSalesStats(widget.eventId);
        _totalSold = stats.totalSold;
        _totalScanned = stats.totalScanned;
      } catch (e) { debugPrint(e.toString()); }
      setState(() {
        _all = data;
        _hasMore = data.length >= _pageSize;
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
      final data = widget.scannedOnly
          ? await repo.getScannedTickets(widget.eventId, offset: _all.length, limit: _pageSize)
          : await repo.getTicketSales(widget.eventId, offset: _all.length, limit: _pageSize);
      if (mounted) {
        setState(() {
          _all.addAll(data);
          _hasMore = data.length >= _pageSize;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadSponsorScanned() async {
    setState(() => _sponsorLoading = true);
    try {
      final repo = context.read<SponsorProvider>();
      final data = await repo.getScannedSponsorTickets(widget.eventId);
      if (mounted) {
        setState(() {
          _sponsorScanned = data;
          _sponsorLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _sponsorLoading = false);
    }
  }

  List<TicketSale> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((s) {
      final tierName = (s.tierName ?? '').toLowerCase();
      final code = s.ticketCode.toLowerCase();
      final userId = '${s.userId}'.toLowerCase();
      final attendee = (s.attendeeDisplayName ?? '').toLowerCase();
      return tierName.contains(q) ||
          code.contains(q) ||
          userId.contains(q) ||
          attendee.contains(q);
    }).toList();
  }

  int get _totalRevenue =>
      _all.fold<int>(0, (s, e) => s + e.amountPaidCents);

  int get _totalCommission =>
      _all.fold<int>(0, (s, e) => s + e.commissionCents);

  int get _totalNetToOrganizer =>
      _all.fold<int>(
          0, (s, e) => s + (e.amountPaidCents - e.commissionCents));

  @override
  Widget build(BuildContext context) {
    final title =
        widget.scannedOnly ? 'Scanned Tickets' : 'Event Ticket Sales';
    final filtered = _filtered;

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
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.inputFillOf(context),
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
          if (widget.scannedOnly)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  _filterChip('All', 0),
                  const SizedBox(width: 8),
                  _filterChip('Customer', 1),
                  const SizedBox(width: 8),
                  _filterChip('Sponsor', 2),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                if (_totalSold > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color:
                            AppTheme.successColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.successColor
                                .withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.qr_code_scanner_rounded,
                              size: 18, color: AppTheme.successColor),
                          const SizedBox(width: 10),
                          Text(
                            '$_totalScanned scanned / $_totalSold total sold',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.successColor,
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: 60,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _totalSold > 0
                                    ? _totalScanned / _totalSold
                                    : 0,
                                backgroundColor: AppTheme.successColor
                                    .withValues(alpha: 0.15),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.successColor),
                                minHeight: 6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Row(
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
                    const SizedBox(width: 8),
                    if (_totalCommission > 0)
                      _statChip(
                        'Net \$${(_totalNetToOrganizer / 100).toStringAsFixed(2)}',
                        Icons.account_balance_wallet_rounded,
                        Colors.deepPurple,
                      ),
                    if (_searchCtrl.text.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _statChip(
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
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline,
                                size: 48,
                                color: AppTheme.textSecondaryOf(context)),
                            const SizedBox(height: 12),
                            Text('Failed to load',
                                style: TextStyle(
                                    color:
                                        AppTheme.textSecondaryOf(context))),
                            const SizedBox(height: 8),
                            OutlinedButton(
                                onPressed: _load,
                                child: const Text('Retry')),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.scannedOnly
                                      ? Icons.qr_code_scanner_rounded
                                      : Icons
                                          .confirmation_number_outlined,
                                  size: 56,
                                  color:
                                      AppTheme.textSecondaryOf(context),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _searchCtrl.text.isNotEmpty
                                      ? 'No matching tickets'
                                      : widget.scannedOnly
                                          ? 'No scanned tickets yet'
                                          : 'No ticket sales yet',
                                  style: TextStyle(
                                      color: AppTheme.textSecondaryOf(
                                          context),
                                      fontSize: 15),
                                ),
                              ],
                            ),
                          )
                        : _scannedFilter == 2
                        ? _buildSponsorList()
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              controller: _scrollCtrl,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              itemCount: _scannedFilter == 0
                                  ? filtered.length + _sponsorScanned.length + (_loadingMore ? 1 : 0)
                                  : filtered.length + (_loadingMore ? 1 : 0),
                              itemBuilder: (context, i) {
                                if (_scannedFilter == 0) {
                                  if (i < filtered.length) {
                                    return _buildCard(filtered[i]);
                                  }
                                  final si = i - filtered.length;
                                  if (si < _sponsorScanned.length) {
                                    return _buildSponsorCard(_sponsorScanned[si]);
                                  }
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  );
                                }
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
                                return _buildCard(filtered[i]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(TicketSale sale) {
    final saleId = sale.id;
    final tierName = sale.tierName ?? 'Unknown';
    final attendee = sale.attendeeDisplayName ?? 'User #${sale.userId}';
    final code = sale.ticketCode;
    final amount = sale.amountPaidCents;
    final commission = sale.commissionCents;
    final netAmount = amount - commission;
    final isScanned = sale.isScanned;
    final createdAt = AppDateFormat.shortDateTime(sale.createdAt);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TicketReceiptScreen(
            eventId: widget.eventId,
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
          border: isScanned
              ? Border.all(
                  color:
                      AppTheme.successColor.withValues(alpha: 0.25))
              : Border.all(color: AppTheme.dividerOf(context)),
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
              Container(
                width: 44,
                height: 44,
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
                  size: 22,
                  color: isScanned
                      ? AppTheme.successColor
                      : AppTheme.textSecondaryOf(context),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(attendee,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text('$tierName  •  $code',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryOf(context))),
                    if (createdAt.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('Purchased $createdAt',
                          style: TextStyle(
                              fontSize: 11,
                              color:
                                  AppTheme.textSecondaryOf(context))),
                    ],
                    if (isScanned) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.qr_code_scanner,
                              size: 13, color: AppTheme.successColor),
                          const SizedBox(width: 4),
                          Text(
                            sale.scannedByDisplayName != null
                                ? 'Scanned by ${sale.scannedByDisplayName}'
                                : 'Scanned',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.successColor),
                          ),
                        ],
                      ),
                    ],
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
                        fontSize: 15,
                        letterSpacing: -0.3,
                        color:
                            amount == 0 ? AppTheme.successColor : null),
                  ),
                  if (commission > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Net \$${(netAmount / 100).toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 11,
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

  Widget _statChip(String label, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark && _isNearBlack(color) ? AppTheme.accentColor : color;
    final textC = isDark ? AppTheme.textPrimaryOf(context) : c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:
            isDark ? AppTheme.cardOf(context) : c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: c.withValues(alpha: isDark ? 0.4 : 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textC)),
        ],
      ),
    );
  }

  bool _isNearBlack(Color c) => c.r < 0.15 && c.g < 0.15 && c.b < 0.15;

  Widget _filterChip(String label, int value) {
    final selected = _scannedFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      )),
      selected: selected,
      onSelected: (_) {
        setState(() => _scannedFilter = value);
      },
      selectedColor: AppTheme.accentColor.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: selected ? AppTheme.accentColor : AppTheme.textSecondaryOf(context),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide(
        color: selected ? AppTheme.accentColor.withValues(alpha: 0.4) : AppTheme.dividerOf(context),
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildSponsorList() {
    if (_sponsorLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_sponsorScanned.isEmpty) {
      return Center(
        child: Text('No scanned sponsor tickets',
          style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 15)),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadSponsorScanned,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: _sponsorScanned.length,
        itemBuilder: (_, i) => _buildSponsorCard(_sponsorScanned[i]),
      ),
    );
  }

  Widget _buildSponsorCard(ScannedSponsorTicket ticket) {
    final companyName = ticket.companyName;
    final contactName = ticket.contactName;
    final receipt = ticket.receiptNumber;
    final scanCount = ticket.scanCount;
    final totalDelegates = ticket.totalDelegates;
    final checkedIn = ticket.checkedInCount;
    final scannedAt = ticket.scannedAt;
    final delegates = ticket.delegates;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF1B5E8A).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D3B66), Color(0xFF1B5E8A)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.storefront_rounded, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(companyName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
                      if (contactName.isNotEmpty)
                        Text(contactName,
                          style: TextStyle(fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('SPONSOR',
                    style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: 0.5)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt_outlined, size: 14,
                      color: AppTheme.textSecondaryOf(context)),
                    const SizedBox(width: 6),
                    Text(receipt,
                      style: TextStyle(fontSize: 12,
                        color: AppTheme.textSecondaryOf(context),
                        fontFamily: 'monospace')),
                    const Spacer(),
                    if (scannedAt != null)
                      Text(AppDateFormat.isoShort(scannedAt),
                        style: TextStyle(fontSize: 11,
                          color: AppTheme.textSecondaryOf(context))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, size: 14,
                      color: AppTheme.successColor),
                    const SizedBox(width: 6),
                    Text('$scanCount scan${scanCount == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.successColor)),
                    if (totalDelegates > 0) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.people_rounded, size: 14,
                        color: AppTheme.accentColor),
                      const SizedBox(width: 4),
                      Text('$checkedIn/$totalDelegates delegates',
                        style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentColor)),
                    ],
                  ],
                ),
                if (delegates.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...delegates.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Icon(
                          d.checkedIn
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 14,
                          color: d.checkedIn
                              ? AppTheme.successColor
                              : AppTheme.textSecondaryOf(context),
                        ),
                        const SizedBox(width: 6),
                        Text(d.name,
                          style: TextStyle(fontSize: 12,
                            color: AppTheme.textPrimaryOf(context))),
                        if (d.checkedIn && d.checkedInAt != null) ...[
                          const Spacer(),
                          Text(AppDateFormat.isoShort(d.checkedInAt!),
                            style: TextStyle(fontSize: 10,
                              color: AppTheme.textSecondaryOf(context))),
                        ],
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
