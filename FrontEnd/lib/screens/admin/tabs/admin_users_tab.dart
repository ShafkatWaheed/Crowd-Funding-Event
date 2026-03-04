import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../admin_shared.dart';
import '../../../config/theme.dart';
import '../../../models/admin.dart';
import '../../../widgets/admin/admin_search_bar.dart';
import '../../../widgets/admin/admin_empty_state.dart';

/// Callback for loading users. Returns typed AdminPage<AdminUserItem>.
typedef AdminUsersLoadCallback = Future<AdminPage<AdminUserItem>> Function(
  int offset,
  int limit, {
  String? search,
  String? role,
});

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({
    super.key,
    required this.users,
    required this.usersTotal,
    required this.onSnack,
    required this.onLoadMore,
  });

  final List<AdminUserItem> users;
  final int usersTotal;
  final void Function(String) onSnack;
  final AdminUsersLoadCallback onLoadMore;

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  String _userSearch = '';
  String _userRoleFilter = 'all';
  final _usersScrollCtrl = ScrollController();
  Timer? _userSearchDebounce;
  List<AdminUserItem> _users = [];
  int _usersTotal = 0;
  bool _usersLoadingMore = false;

  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _users = List.from(widget.users);
    _usersTotal = widget.usersTotal;
    _usersScrollCtrl.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant AdminUsersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.users != widget.users || oldWidget.usersTotal != widget.usersTotal) {
      _users = List.from(widget.users);
      _usersTotal = widget.usersTotal;
    }
  }

  @override
  void dispose() {
    _userSearchDebounce?.cancel();
    _usersScrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_usersScrollCtrl.position.pixels >=
        _usersScrollCtrl.position.maxScrollExtent - 200) {
      _loadMoreUsers();
    }
  }

  List<AdminUserItem> get _filteredUsers {
    var list = _users;
    if (_userRoleFilter != 'all') {
      list = list.where((u) => u.role == _userRoleFilter).toList();
    }
    return list;
  }

  void _onUserSearchChanged(String q) {
    _userSearchDebounce?.cancel();
    _userSearchDebounce = Timer(const Duration(milliseconds: 300), () async {
      _userSearch = q;
      try {
        final resp = await widget.onLoadMore(
          0,
          _pageSize,
          search: q.isEmpty ? null : q,
          role: _userRoleFilter == 'all' ? null : _userRoleFilter,
        );
        if (mounted) {
          setState(() {
            _users = resp.items;
            _usersTotal = resp.total;
          });
        }
      } catch (e) { debugPrint(e.toString()); }
    });
  }

  Future<void> _loadMoreUsers() async {
    if (_usersLoadingMore || _users.length >= _usersTotal) return;
    setState(() => _usersLoadingMore = true);
    try {
      final resp = await widget.onLoadMore(
        _users.length,
        _pageSize,
        search: _userSearch.isEmpty ? null : _userSearch,
        role: _userRoleFilter == 'all' ? null : _userRoleFilter,
      );
      if (mounted) {
        setState(() {
          _users.addAll(resp.items);
          _usersTotal = resp.total;
        });
      }
    } catch (e) { debugPrint(e.toString()); }
    if (mounted) setState(() => _usersLoadingMore = false);
  }

  Future<void> _refresh() async {
    setState(() => _usersLoadingMore = true);
    try {
      final resp = await widget.onLoadMore(
        0,
        _pageSize,
        search: _userSearch.isEmpty ? null : _userSearch,
        role: _userRoleFilter == 'all' ? null : _userRoleFilter,
      );
      if (mounted) {
        setState(() {
          _users = resp.items;
          _usersTotal = resp.total;
          _usersLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _usersLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = ['all', 'customer', 'organizer', 'sponsor', 'admin'];
    final displayList = _filteredUsers;
    final showingCount = displayList.length;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: AdminSearchBar(
              hint: 'Search by name or email...',
              onChanged: _onUserSearchChanged,
              resultCount: showingCount,
              totalCount: _usersTotal,
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: roles.map((role) {
                final selected = _userRoleFilter == role;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      role == 'all'
                          ? 'All'
                          : '${role[0].toUpperCase()}${role.substring(1)}s',
                    ),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _userRoleFilter = role),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: displayList.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: 300,
                      child: AdminEmptyState(
                        icon: Icons.people,
                        message: 'No users found',
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _usersScrollCtrl,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount:
                        displayList.length + (_usersLoadingMore ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i >= displayList.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final user = displayList[i];
                      final name = user.displayName ?? 'No name';
                      final email = user.email;
                      final role = user.role;
                      final initial = (name != 'No name' ? name : email)
                          .substring(0, 1)
                          .toUpperCase();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () =>
                              context.push('/admin/users/${user.id}'),
                          leading: CircleAvatar(
                            backgroundColor:
                                AppTheme.accentOf(context).withValues(alpha: 0.15),
                            foregroundColor: AppTheme.accentOf(context),
                            child: Text(initial),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(email),
                          trailing: statusChip(
                            context,
                            role.toUpperCase(),
                            roleColor(context, role),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
