import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/event.dart';
import '../../models/ticket.dart';
import '../../providers/event_provider.dart';
import '../../providers/ticket_provider.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/shimmer_loaders.dart';

enum _WaitlistType { fund, ticket }

class WaitlistScreen extends StatefulWidget {
  final int eventId;
  /// When true, opens with the Ticket Waitlist tab active.
  final bool initialTicketView;

  const WaitlistScreen({
    super.key,
    required this.eventId,
    this.initialTicketView = false,
  });

  @override
  State<WaitlistScreen> createState() => _WaitlistScreenState();
}

class _WaitlistScreenState extends State<WaitlistScreen> {
  final _searchCtrl = TextEditingController();
  late _WaitlistType _type;

  // Fund waitlist data
  List<Registration> _fundAll = [];
  List<Registration> _fundFiltered = [];

  // Ticket waitlist data
  List<TicketSale> _ticketAll = [];
  List<TicketSale> _ticketFiltered = [];

  // Capacity info
  int _maxCapacity = 0;
  int _ticketsSold = 0;
  int _totalReservedSpots = 0;
  int _registrationCount = 0;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _type = widget.initialTicketView ? _WaitlistType.ticket : _WaitlistType.fund;
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final eventRepo = context.read<EventProvider>();
      final ticketRepo = context.read<TicketProvider>();

      // Load waitlists + capacity in parallel
      final regsFuture = eventRepo.getRegistrations(widget.eventId);
      final ticketsFuture = ticketRepo.getWaitlistedTickets(widget.eventId);
      final capFuture = eventRepo.getCapacityInfo(widget.eventId);
      final results = await Future.wait([regsFuture, capFuture]);

      final regs = results[0] as List<Registration>;
      final tickets = await ticketsFuture;
      final cap = results[1] as CapacityInfo;

      setState(() {
        _fundAll = regs.where((r) => r.status == 'waitlist').toList();
        _ticketAll = tickets;
        _maxCapacity = cap.maxCapacity;
        _ticketsSold = cap.ticketsSold;
        _totalReservedSpots = cap.totalReservedSpots;
        _registrationCount = cap.registrationCount;
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
      _fundFiltered = List.from(_fundAll);
      _ticketFiltered = List.from(_ticketAll);
    } else {
      _fundFiltered = _fundAll.where((r) {
        final userId = '${r.userId}'.toLowerCase();
        final id = '${r.id}'.toLowerCase();
        return userId.contains(q) || id.contains(q);
      }).toList();
      _ticketFiltered = _ticketAll.where((t) {
        final userId = '${t.userId}'.toLowerCase();
        final tierName = (t.tierName ?? '').toLowerCase();
        final ticketCode = t.ticketCode.toLowerCase();
        return userId.contains(q) || tierName.contains(q) || ticketCode.contains(q);
      }).toList();
    }
  }

  // ── Fund Actions ──

  Future<void> _decideFund(int regId, String action) async {
    try {
      final repo = context.read<EventProvider>();
      await repo.decideRegistration(widget.eventId, regId, action);
      if (mounted) {
        AppToast.success(context, action == 'approve'
            ? 'Registration approved!'
            : 'Registration rejected.');
        context.read<EventProvider>().loadEvent(widget.eventId);
        _load();
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to update registration');
      }
    }
  }

  // ── Ticket Actions ──

  Future<void> _approveTicket(int ticketId) async {
    try {
      final repo = context.read<TicketProvider>();
      await repo.approveWaitlistedTicket(widget.eventId, ticketId);
      if (mounted) {
        AppToast.success(context, 'Ticket approved!');
        context.read<EventProvider>().loadEvent(widget.eventId);
        _load();
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to approve ticket');
      }
    }
  }

  Future<void> _rejectTicket(int ticketId) async {
    try {
      final repo = context.read<TicketProvider>();
      await repo.rejectWaitlistedTicket(widget.eventId, ticketId);
      if (mounted) {
        AppToast.success(context, 'Ticket rejected.');
        context.read<EventProvider>().loadEvent(widget.eventId);
        _load();
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to reject ticket');
      }
    }
  }

  // ── Helpers ──

  List<Object> get _currentAll =>
      _type == _WaitlistType.fund ? _fundAll : _ticketAll;
  List<Object> get _currentFiltered =>
      _type == _WaitlistType.fund ? _fundFiltered : _ticketFiltered;

  String get _emptyLabel => _type == _WaitlistType.fund
      ? 'No pending fund waitlist requests'
      : 'No tickets waiting approval';

  String get _searchEmptyLabel => _type == _WaitlistType.fund
      ? 'No matching registrations'
      : 'No matching tickets';

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const Text('Waitlist'),
      ),
      body: Column(
        children: [
          // ── Filter Toggle ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceOf(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.dividerOf(context)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  _filterChip(
                    label: 'Fund Waitlist',
                    icon: Icons.hourglass_top,
                    count: _fundAll.length,
                    selected: _type == _WaitlistType.fund,
                    onTap: () => setState(() => _type = _WaitlistType.fund),
                  ),
                  const SizedBox(width: 4),
                  _filterChip(
                    label: 'Ticket Waitlist',
                    icon: Icons.confirmation_number,
                    count: _ticketAll.length,
                    selected: _type == _WaitlistType.ticket,
                    onTap: () => setState(() => _type = _WaitlistType.ticket),
                  ),
                ],
              ),
            ),
          ),

          // ── Search ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: _type == _WaitlistType.fund
                    ? 'Search by user ID…'
                    : 'Search by user ID, tier, or code…',
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

          // ── Count badge ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_currentAll.length} waiting approval',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warningColor,
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
                      '${_currentFiltered.length} match${_currentFiltered.length == 1 ? '' : 'es'}',
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

          // ── Capacity Summary Bar ──
          if (!_loading && _maxCapacity > 0) _buildCapacityBar(),

          // ── Content ──
          Expanded(
            child: _loading
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: List.generate(4, (_) => const ShimmerListTile()),
                    ),
                  )
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
                    : _currentFiltered.isEmpty
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
                                      ? _searchEmptyLabel
                                      : _emptyLabel,
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
                              itemCount: _currentFiltered.length,
                              itemBuilder: (context, i) {
                                return _type == _WaitlistType.fund
                                    ? _fundCard(_fundFiltered[i])
                                    : _ticketCard(_ticketFiltered[i]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  // ── Capacity bar ──

  int get _occupied => _ticketsSold + _totalReservedSpots;
  int get _available => (_maxCapacity - _occupied).clamp(0, _maxCapacity);

  Widget _buildCapacityBar() {
    final pct = _maxCapacity > 0 ? (_occupied / _maxCapacity).clamp(0.0, 1.0) : 0.0;
    final barColor = _available <= 0
        ? AppTheme.errorColor
        : pct > 0.85
            ? AppTheme.warningColor
            : AppTheme.successColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.dividerOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people_alt_rounded, size: 16, color: AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 6),
                Text(
                  'Capacity',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
                const Spacer(),
                Text(
                  '$_occupied / $_maxCapacity occupied',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: AppTheme.dividerOf(context),
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              children: [
                _capLabel(context, 'Tickets sold', _ticketsSold, context.feedAccent),
                if (_totalReservedSpots > 0)
                  _capLabel(context, 'Reserved spots', _totalReservedSpots, context.sponsorAccent),
                _capLabel(context, 'Available', _available, AppTheme.successColor),
                if (_type == _WaitlistType.fund)
                  _capLabel(context, 'Registered', _registrationCount, context.ticketAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _capLabel(BuildContext context, String label, int value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$value $label',
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
        ),
      ],
    );
  }

  // ── Filter chip widget ──

  Widget _filterChip({
    required String label,
    required IconData icon,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.white : AppTheme.textSecondaryOf(context)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppTheme.textSecondaryOf(context),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.25)
                        : AppTheme.dividerOf(context).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppTheme.textSecondaryOf(context),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Fund waitlist card ──

  Widget _fundCard(Registration reg) {
    final regId = reg.id;
    final userId = reg.userId;
    // After approving a fund registration, the user becomes registered –
    // registration_count increases by 1 but capacity math unchanged.
    final newRegCount = _registrationCount + 1;

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
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.hourglass_top,
                      size: 22, color: AppTheme.warningColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('User #$userId',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text('Registration #$regId',
                          style:
                              TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
                    ],
                  ),
                ),
                _approveButton(() => _decideFund(regId, 'approve')),
                const SizedBox(width: 8),
                _rejectButton(() => _decideFund(regId, 'reject')),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.ticketSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'If approved: Registered $newRegCount / $_maxCapacity',
                style: TextStyle(fontSize: 11, color: context.ticketAccent, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Ticket waitlist card ──

  Widget _ticketCard(TicketSale ticket) {
    final ticketId = ticket.id;
    final userId = ticket.userId;
    final tierName = ticket.tierName ?? 'Unknown Tier';
    final amountCents = ticket.amountPaidCents;
    final price = amountCents == 0
        ? 'Free'
        : '\$${(amountCents / 100).toStringAsFixed(2)}';

    // Preview: approving this ticket uses 1 capacity slot
    final newOccupied = _occupied + 1;
    final wouldExceed = newOccupied > _maxCapacity;

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
        child: Column(
          children: [
            Row(
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
                      Text('User #$userId',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text('$tierName · $price',
                          style:
                              TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
                    ],
                  ),
                ),
                _approveButton(() => _approveTicket(ticketId)),
                const SizedBox(width: 8),
                _rejectButton(() => _rejectTicket(ticketId)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: wouldExceed
                    ? AppTheme.errorColor.withValues(alpha: 0.08)
                    : context.feedAccent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  if (wouldExceed)
                    Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.errorColor),
                  if (wouldExceed) const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      wouldExceed
                          ? 'If approved: $newOccupied / $_maxCapacity — exceeds capacity!'
                          : 'If approved: $newOccupied / $_maxCapacity occupied',
                      style: TextStyle(
                        fontSize: 11,
                        color: wouldExceed ? AppTheme.errorColor : context.feedAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared action buttons ──

  Widget _approveButton(VoidCallback onPressed) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.successColor.withValues(alpha: 0.12),
        foregroundColor: AppTheme.successColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text('Approve', style: TextStyle(fontSize: 13)),
    );
  }

  Widget _rejectButton(VoidCallback onPressed) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.errorColor.withValues(alpha: 0.1),
        foregroundColor: AppTheme.errorColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text('Reject', style: TextStyle(fontSize: 13)),
    );
  }
}
