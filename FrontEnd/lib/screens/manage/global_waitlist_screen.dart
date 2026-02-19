import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/shimmer_loaders.dart';

enum _WaitlistType { fund, ticket }

/// Shows waitlisted registrations AND waitlisted tickets across ALL organiser events,
/// with a segmented toggle to switch between the two views.
class GlobalWaitlistScreen extends StatefulWidget {
  /// When true, opens with the Ticket Waitlist tab active.
  final bool initialTicketView;

  const GlobalWaitlistScreen({super.key, this.initialTicketView = false});

  @override
  State<GlobalWaitlistScreen> createState() => _GlobalWaitlistScreenState();
}

class _GlobalWaitlistScreenState extends State<GlobalWaitlistScreen> {
  final _searchCtrl = TextEditingController();
  late _WaitlistType _type;

  // Fund waitlist data (registrations with status == 'waitlist')
  List<Map<String, dynamic>> _fundAll = [];
  List<Map<String, dynamic>> _fundFiltered = [];

  // Ticket waitlist data (tickets with status == 'waitlisted')
  List<Map<String, dynamic>> _ticketAll = [];
  List<Map<String, dynamic>> _ticketFiltered = [];

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
      final events = await api.getMyEvents();

      final List<Map<String, dynamic>> fundCombined = [];
      final List<Map<String, dynamic>> ticketCombined = [];

      for (final evt in events) {
        final eventId = evt['id'] as int;
        final eventTitle = evt['title'] ?? 'Event #$eventId';

        // Fund waitlist
        try {
          final regs = await api.getRegistrations(eventId);
          for (final r in regs) {
            if (r['status'] == 'waitlist') {
              fundCombined.add({
                ...Map<String, dynamic>.from(r),
                '_event_title': eventTitle,
                '_event_id': eventId,
              });
            }
          }
        } catch (_) {}

        // Ticket waitlist
        try {
          final tickets = await api.getWaitlistedTickets(eventId);
          for (final t in tickets) {
            ticketCombined.add({
              ...Map<String, dynamic>.from(t),
              '_event_title': eventTitle,
              '_event_id': eventId,
            });
          }
        } catch (_) {}
      }

      setState(() {
        _fundAll = fundCombined;
        _ticketAll = ticketCombined;
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
        final event = (r['_event_title'] ?? '').toString().toLowerCase();
        final userId = '${r['user_id']}'.toLowerCase();
        return event.contains(q) || userId.contains(q);
      }).toList();
      _ticketFiltered = _ticketAll.where((t) {
        final event = (t['_event_title'] ?? '').toString().toLowerCase();
        final userId = '${t['user_id']}'.toLowerCase();
        final tierName = (t['tier']?['name'] ?? '').toString().toLowerCase();
        return event.contains(q) || userId.contains(q) || tierName.contains(q);
      }).toList();
    }
  }

  // ── Fund Actions ──

  Future<void> _decideFund(int eventId, int regId, String action) async {
    try {
      final api = context.read<ApiService>();
      await api.decideRegistration(eventId, regId, action);
      if (mounted) {
        AppToast.success(context, action == 'approve'
            ? 'Registration approved!'
            : 'Registration rejected.');
        _load();
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to update registration');
      }
    }
  }

  // ── Ticket Actions ──

  Future<void> _approveTicket(int eventId, int ticketId) async {
    try {
      final api = context.read<ApiService>();
      await api.approveWaitlistedTicket(eventId, ticketId);
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

  Future<void> _rejectTicket(int eventId, int ticketId) async {
    try {
      final api = context.read<ApiService>();
      await api.rejectWaitlistedTicket(eventId, ticketId);
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

  // ── Helpers ──

  List<Map<String, dynamic>> get _currentAll =>
      _type == _WaitlistType.fund ? _fundAll : _ticketAll;
  List<Map<String, dynamic>> get _currentFiltered =>
      _type == _WaitlistType.fund ? _fundFiltered : _ticketFiltered;

  String get _emptyLabel => _type == _WaitlistType.fund
      ? 'No pending fund waitlist requests'
      : 'No waitlisted tickets';

  String get _searchEmptyLabel => _type == _WaitlistType.fund
      ? 'No matching waitlist entries'
      : 'No matching tickets';

  // ── Build ─────────────────────────────────────────────────────

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
        title: const Text('All Waitlists'),
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
                    ? 'Search by event or user ID…'
                    : 'Search by event, user ID, or tier…',
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

          // ── List ──
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
                              itemBuilder: (_, i) {
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

  // ── Filter chip ──

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
                        : Colors.grey.withValues(alpha: 0.15),
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

  Widget _fundCard(Map<String, dynamic> reg) {
    final regId = reg['id'] as int;
    final eventId = reg['_event_id'] as int;
    final eventTitle = reg['_event_title'] ?? '';
    final userId = reg['user_id'];

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
                  Text(eventTitle,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.accentColor)),
                  Text('Registration #$regId',
                      style:
                          TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
                ],
              ),
            ),
            _approveButton(() => _decideFund(eventId, regId, 'approve')),
            const SizedBox(width: 8),
            _rejectButton(() => _decideFund(eventId, regId, 'reject')),
          ],
        ),
      ),
    );
  }

  // ── Ticket waitlist card ──

  Widget _ticketCard(Map<String, dynamic> ticket) {
    final ticketId = ticket['id'] as int;
    final eventId = ticket['_event_id'] as int;
    final eventTitle = ticket['_event_title'] ?? '';
    final userId = ticket['user_id'];
    final tierName = ticket['tier']?['name'] ?? 'Unknown Tier';
    final amountCents = ticket['amount_paid_cents'] ?? 0;
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
                  Text(eventTitle,
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
            _approveButton(() => _approveTicket(eventId, ticketId)),
            const SizedBox(width: 8),
            _rejectButton(() => _rejectTicket(eventId, ticketId)),
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
