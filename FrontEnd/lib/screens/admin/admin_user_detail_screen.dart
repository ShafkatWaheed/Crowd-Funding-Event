import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/admin/admin_empty_state.dart';
import 'user_detail_tabs/user_discounts_tab.dart';
import 'user_detail_tabs/user_escrow_tab.dart';
import 'user_detail_tabs/user_events_tab.dart';
import 'user_detail_tabs/user_pledges_tab.dart';
import 'user_detail_tabs/user_sponsor_bids_tab.dart';
import 'user_detail_tabs/user_sponsors_tab.dart';
import 'user_detail_tabs/user_tickets_tab.dart';

class AdminUserDetailScreen extends StatefulWidget {
  const AdminUserDetailScreen({super.key, required this.userId});

  final int userId;

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen>
    with TickerProviderStateMixin {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  Map<String, dynamic>? _detail;
  bool _loading = true;
  String? _error;

  TabController? _tabCtrl;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    _tabCtrl?.dispose();
    super.dispose();
  }

  int _tabCountForRole(String role) {
    switch (role) {
      case 'organizer': return 7;
      case 'customer': return 3;
      case 'sponsor': return 3;
      default: return 1;
    }
  }

  List<String> _tabLabelsForRole(String role) {
    if (_detail != null && role == 'customer') {
      final tickets = _detail!['tickets'] as List<dynamic>? ?? [];
      final pledges = _detail!['pledges'] as List<dynamic>? ?? [];
      final donations = pledges.where((p) => p['is_guest'] == true).length;
      final regularPledges = pledges.length - donations;
      return [
        'Tickets (${tickets.length})',
        'Pledges ($regularPledges)${donations > 0 ? ' · Donations ($donations)' : ''}',
        'Events',
      ];
    }
    switch (role) {
      case 'customer': return ['Tickets', 'Pledges', 'Events'];
      case 'organizer': return ['Events', 'Tickets Sold', 'Pledges Received', 'Sponsors', 'Discounts', 'Sponsor Bids', 'Escrow'];
      case 'sponsor': return ['Sponsorships', 'Tickets', 'Pledges'];
      default: return ['Info'];
    }
  }

  Future<void> _loadDetail() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<ApiService>();
      final data = await api.adminGetUserDetail(widget.userId);
      if (mounted) {
        final role = data['role'] as String? ?? 'customer';
        _tabCtrl?.dispose();
        _tabCtrl = TabController(length: _tabCountForRole(role), vsync: this);
        setState(() { _detail = data; _loading = false; });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = ApiService.extractError(e); _loading = false; });
      }
    }
  }

  Future<void> _refreshDetail() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.adminGetUserDetail(widget.userId);
      if (mounted) {
        final role = data['role'] as String? ?? 'customer';
        final oldLength = _tabCtrl?.length ?? 0;
        final newLength = _tabCountForRole(role);
        if (newLength != oldLength) {
          _tabCtrl?.dispose();
          _tabCtrl = TabController(length: newLength, vsync: this);
        }
        setState(() => _detail = data);
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  void _snack(String msg) {
    if (!mounted) return;
    _messengerKey.currentState
        ?.showSnackBar(SnackBar(content: Text(msg)));
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin': return AppTheme.errorOf(context);
      case 'organizer': return AppTheme.accentOf(context);
      case 'sponsor': return context.sponsorAccent;
      case 'customer': return AppTheme.primaryOf(context);
      default: return AppTheme.textSecondaryOf(context);
    }
  }

  // =========================================================================
  // BUILD
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    PreferredSizeWidget? appBar;
    Widget body;

    if (_loading) {
      appBar = AppBar(title: const Text('User Detail'));
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      appBar = AppBar(title: const Text('User Detail'));
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadDetail, child: const Text('Retry')),
          ],
        ),
      );
    } else {
      final d = _detail!;
      final role = d['role'] as String? ?? 'customer';
      final name = d['display_name'] ?? d['email'] ?? 'User #${widget.userId}';
      final email = d['email'] ?? '';
      final initial = (name.toString().isNotEmpty ? name.toString() : email.toString())
          .substring(0, 1)
          .toUpperCase();
      final tabLabels = _tabLabelsForRole(role);

      appBar = AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _roleColor(role).withValues(alpha: 0.15),
              child: Text(initial, style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _roleColor(role),
              )),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name.toString(), style: const TextStyle(fontSize: 16)),
                  Text(
                    '$email  ·  ${role.toUpperCase()}',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: _tabCtrl != null
            ? TabBar(
                controller: _tabCtrl,
                isScrollable: tabLabels.length > 3,
                tabs: tabLabels.map((l) => Tab(text: l)).toList(),
              )
            : null,
      );
      body = _tabCtrl == null
          ? Center(child: AdminEmptyState(icon: Icons.person, message: 'No data'))
          : TabBarView(
              controller: _tabCtrl,
              children: _buildTabViews(role),
            );
    }

    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(appBar: appBar, body: body),
    );
  }

  // =========================================================================
  // TAB ROUTING
  // =========================================================================

  List<Widget> _buildTabViews(String role) {
    final d = _detail!;
    switch (role) {
      case 'customer':
        return [
          UserTicketsTab(
            userId: widget.userId, detail: d,
            onSnack: _snack, onRefresh: _refreshDetail,
          ),
          UserPledgesTab(
            userId: widget.userId, detail: d,
            onSnack: _snack, onRefresh: _refreshDetail,
          ),
          UserEventsTab(
            userId: widget.userId, detail: d,
            onSnack: _snack, onRefresh: _refreshDetail,
          ),
        ];
      case 'organizer':
        return [
          UserEventsTab(
            userId: widget.userId, detail: d,
            onSnack: _snack, onRefresh: _refreshDetail,
            isOrganizer: true,
          ),
          UserTicketsTab(
            userId: widget.userId, detail: d,
            onSnack: _snack, onRefresh: _refreshDetail,
            isOrganizerSales: true,
          ),
          UserPledgesTab(
            userId: widget.userId, detail: d,
            onSnack: _snack, onRefresh: _refreshDetail,
            isOrganizerPledges: true,
          ),
          UserSponsorsTab(
            userId: widget.userId, detail: d,
            onSnack: _snack, onRefresh: _refreshDetail,
          ),
          UserDiscountsTab(
            userId: widget.userId, detail: d,
            onSnack: _snack, onRefresh: _refreshDetail,
          ),
          UserSponsorBidsTab(
            userId: widget.userId, detail: d,
            onSnack: _snack, onRefresh: _refreshDetail,
          ),
          UserEscrowTab(
            userId: widget.userId, detail: d,
            onSnack: _snack, onRefresh: _refreshDetail,
          ),
        ];
      case 'sponsor':
        return [
          UserSponsorBidsTab(
            userId: widget.userId, detail: d,
            onSnack: _snack, onRefresh: _refreshDetail,
            dataKey: 'sponsorships',
          ),
          UserTicketsTab(
            userId: widget.userId, detail: d,
            onSnack: _snack, onRefresh: _refreshDetail,
          ),
          UserPledgesTab(
            userId: widget.userId, detail: d,
            onSnack: _snack, onRefresh: _refreshDetail,
          ),
        ];
      default:
        return [
          Center(child: AdminEmptyState(
            icon: Icons.person, message: 'No role-specific data')),
        ];
    }
  }
}
