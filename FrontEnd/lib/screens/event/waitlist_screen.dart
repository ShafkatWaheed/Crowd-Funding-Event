import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../providers/event_provider.dart';
import '../../widgets/app_toast.dart';

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
  List<dynamic> _fundAll = [];
  List<dynamic> _fundFiltered = [];

  // Ticket waitlist data
  List<dynamic> _ticketAll = [];
  List<dynamic> _ticketFiltered = [];

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
      final api = context.read<ApiService>();

      // Load both in parallel
      final results = await Future.wait([
        api.getRegistrations(widget.eventId),
        api.getWaitlistedTickets(widget.eventId),
      ]);

      final regs = results[0] as List;
      final tickets = results[1] as List;

      setState(() {
        _fundAll = regs.where((r) => r['status'] == 'waitlist').toList();
        _ticketAll = tickets;
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
        final userId = '${r['user_id']}'.toLowerCase();
        final id = '${r['id']}'.toLowerCase();
        return userId.contains(q) || id.contains(q);
      }).toList();
      _ticketFiltered = _ticketAll.where((t) {
        final userId = '${t['user_id']}'.toLowerCase();
        final tierName = (t['tier']?['name'] ?? '').toString().toLowerCase();
        final ticketCode = (t['ticket_code'] ?? '').toString().toLowerCase();
        return userId.contains(q) || tierName.contains(q) || ticketCode.contains(q);
      }).toList();
    }
  }

  // ── Fund Actions ──

  Future<void> _decideFund(int regId, String action) async {
    try {
      final api = context.read<ApiService>();
      await api.decideRegistration(widget.eventId, regId, action);
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
      final api = context.read<ApiService>();
      await api.approveWaitlistedTicket(widget.eventId, ticketId);
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
      final api = context.read<ApiService>();
      await api.rejectWaitlistedTicket(widget.eventId, ticketId);
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

  List<dynamic> get _currentAll =>
      _type == _WaitlistType.fund ? _fundAll : _ticketAll;
  List<dynamic> get _currentFiltered =>
      _type == _WaitlistType.fund ? _fundFiltered : _ticketFiltered;

  String get _emptyLabel => _type == _WaitlistType.fund
      ? 'No pending fund waitlist requests'
      : 'No waitlisted tickets';

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
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.dividerColor),
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
                    '${_currentAll.length} waitlisted',
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
                              itemCount: _currentFiltered.length,
                              itemBuilder: (context, i) {
                                final item = _currentFiltered[i];
                                return _type == _WaitlistType.fund
                                    ? _fundCard(item)
                                    : _ticketCard(item);
                              },
                            ),
                          ),
          ),
        ],
      ),
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
                  color: selected ? Colors.white : Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.grey[600],
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
                        : Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : Colors.grey[600],
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

  Widget _fundCard(dynamic reg) {
    final regId = reg['id'] as int;
    final userId = reg['user_id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
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
                          TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            _approveButton(() => _decideFund(regId, 'approve')),
            const SizedBox(width: 8),
            _rejectButton(() => _decideFund(regId, 'reject')),
          ],
        ),
      ),
    );
  }

  // ── Ticket waitlist card ──

  Widget _ticketCard(dynamic ticket) {
    final ticketId = ticket['id'] as int;
    final userId = ticket['user_id'];
    final tierName = ticket['tier']?['name'] ?? 'Unknown Tier';
    final amountCents = ticket['amount_paid_cents'] ?? 0;
    final price = amountCents == 0
        ? 'Free'
        : '\$${(amountCents / 100).toStringAsFixed(2)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
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
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.confirmation_number,
                  size: 22, color: Colors.orange),
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
                          TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            _approveButton(() => _approveTicket(ticketId)),
            const SizedBox(width: 8),
            _rejectButton(() => _rejectTicket(ticketId)),
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
