import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class CoOrganizerScreen extends StatefulWidget {
  final int eventId;
  const CoOrganizerScreen({super.key, required this.eventId});

  @override
  State<CoOrganizerScreen> createState() => _CoOrganizerScreenState();
}

class _CoOrganizerScreenState extends State<CoOrganizerScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _organizers = [];
  bool _loading = true;
  bool _isMainOrganizer = false;
  bool _isCoOrganizer = false;

  final _searchCtrl = TextEditingController();
  String _selectedPermission = 'read';
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  Timer? _debounce;
  int? _selectedUserId;
  String? _selectedUserLabel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _api.getEventOrganizers(widget.eventId);
      final user = context.read<AuthProvider>().user;
      final mainOrg = list.firstWhere((o) => o['is_main'] == true, orElse: () => {});
      _isMainOrganizer = user != null &&
          (mainOrg['user_id'] == user.id || user.isAdmin);
      _isCoOrganizer = user != null &&
          list.any((o) => o['user_id'] == user.id && o['is_main'] != true);
      setState(() {
        _organizers = list.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to load organizers');
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _searching = true);
      try {
        final results = await _api.searchOrganizers(value.trim());
        if (mounted) {
          setState(() {
            _searchResults = results.cast<Map<String, dynamic>>();
            _searching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  void _selectUser(Map<String, dynamic> user) {
    setState(() {
      _selectedUserId = user['id'];
      _selectedUserLabel = user['display_name'] ?? user['email'] ?? 'User ${user['id']}';
      _searchCtrl.text = _selectedUserLabel!;
      _searchResults = [];
    });
  }

  Future<void> _addOrganizer() async {
    if (_selectedUserId == null) {
      AppToast.error(context, 'Search and select a user first');
      return;
    }
    try {
      await _api.addEventOrganizer(widget.eventId, {
        'user_id': _selectedUserId,
        'permission': _selectedPermission,
      });
      _searchCtrl.clear();
      _selectedUserId = null;
      _selectedUserLabel = null;
      _load();
      if (mounted) AppToast.success(context, 'Invitation sent');
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to invite co-organizer');
      }
    }
  }

  Future<void> _updatePermission(int userId, String currentPerm) async {
    final newPerm = currentPerm == 'read' ? 'full' : 'read';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Permission?'),
        content: Text('Change to ${newPerm == "full" ? "Full Access" : "Read Only"}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Update')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.updateOrganizerPermission(widget.eventId, userId, newPerm);
      _load();
      if (mounted) AppToast.success(context, 'Permission updated');
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to update permission');
      }
    }
  }

  Future<void> _respondToInvitation(bool accept) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    try {
      await _api.respondToInvitation(widget.eventId, user.id, accept);
      _load();
      if (mounted) {
        AppToast.success(context, accept ? 'Invitation accepted' : 'Invitation declined');
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to respond');
      }
    }
  }

  Future<void> _selfRemove() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Event?'),
        content: const Text('You will lose co-organizer access to this event.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.selfRemoveFromEvent(widget.eventId);
      if (mounted) {
        AppToast.success(context, 'You have left this event');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to leave event');
      }
    }
  }

  Future<void> _removeOrganizer(int userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove co-organizer?'),
        content: const Text('This will revoke their access to this event.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.removeEventOrganizer(widget.eventId, userId);
      _load();
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to remove co-organizer');
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return AppTheme.successColor;
      case 'pending':
        return AppTheme.warningColor;
      case 'declined':
        return AppTheme.errorColor;
      default:
        return AppTheme.accentColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final myPendingInvite = user != null
        ? _organizers.where((o) =>
            o['user_id'] == user.id &&
            o['is_main'] != true &&
            o['invitation_status'] == 'pending').firstOrNull
        : null;

    return Scaffold(
      backgroundColor: AppTheme.surfaceOf(context),
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
        title: const Text('Co-Organizers'),
        centerTitle: true,
        actions: [
          if (_isCoOrganizer)
            IconButton(
              icon: const Icon(Icons.exit_to_app_rounded),
              tooltip: 'Leave Event',
              onPressed: _selfRemove,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: List.generate(3, (_) => const ShimmerListTile()),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Pending invitation banner
                  if (myPendingInvite != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('You have a pending invitation',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimaryOf(context))),
                          const SizedBox(height: 4),
                          Text(
                            'Permission: ${myPendingInvite['permission'] == 'full' ? 'Full Access' : 'Read Only'}',
                            style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _respondToInvitation(false),
                                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorColor),
                                  child: const Text('Decline'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => _respondToInvitation(true),
                                  child: const Text('Accept'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Add form (main organizer only)
                  if (_isMainOrganizer) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardOf(context),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Invite Co-Organizer',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _searchCtrl,
                            style: TextStyle(color: AppTheme.textPrimaryOf(context)),
                            onChanged: (v) {
                              _selectedUserId = null;
                              _onSearchChanged(v);
                            },
                            decoration: InputDecoration(
                              labelText: 'Search by email or name',
                              labelStyle: TextStyle(color: AppTheme.textSecondaryOf(context)),
                              hintText: 'Type to search organizers...',
                              hintStyle: TextStyle(color: AppTheme.textSecondaryOf(context)),
                              prefixIcon: Icon(Icons.search, color: AppTheme.textSecondaryOf(context)),
                              suffixIcon: _searching
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                    )
                                  : _selectedUserId != null
                                      ? Icon(Icons.check_circle, color: AppTheme.successColor)
                                      : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: AppTheme.dividerOf(context)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: AppTheme.dividerOf(context)),
                              ),
                              filled: true,
                              fillColor: AppTheme.surfaceOf(context),
                            ),
                          ),
                          if (_searchResults.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 180),
                              decoration: BoxDecoration(
                                color: AppTheme.cardOf(context),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.dividerOf(context)),
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _searchResults.length,
                                itemBuilder: (ctx, i) {
                                  final r = _searchResults[i];
                                  return ListTile(
                                    dense: true,
                                    leading: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppTheme.accentColor.withValues(alpha: 0.2),
                                      child: Text(
                                        (r['display_name'] ?? r['email'] ?? '?')[0].toUpperCase(),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    title: Text(r['display_name'] ?? 'User #${r['id']}',
                                        style: TextStyle(color: AppTheme.textPrimaryOf(context), fontSize: 14)),
                                    subtitle: Text(r['email'] ?? '',
                                        style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 12)),
                                    onTap: () => _selectUser(r),
                                  );
                                },
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Text('Permission',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textPrimaryOf(context))),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              ChoiceChip(
                                label: Text('Read Only',
                                    style: TextStyle(color: AppTheme.textPrimaryOf(context))),
                                selected: _selectedPermission == 'read',
                                onSelected: (_) => setState(() => _selectedPermission = 'read'),
                                selectedColor: AppTheme.accentColor.withValues(alpha: 0.25),
                                checkmarkColor: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: Text('Full Access',
                                    style: TextStyle(color: AppTheme.textPrimaryOf(context))),
                                selected: _selectedPermission == 'full',
                                onSelected: (_) => setState(() => _selectedPermission = 'full'),
                                selectedColor: AppTheme.successColor.withValues(alpha: 0.25),
                                checkmarkColor: Colors.white,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _selectedPermission == 'read'
                                ? 'Can view management data, scan tickets, but cannot edit.'
                                : 'Full organizer access — edit, manage discounts, images, etc.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondaryOf(context)),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _selectedUserId != null ? _addOrganizer : null,
                              icon: const Icon(Icons.send_rounded),
                              label: const Text('Send Invitation'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // List
                  Text('Team (${_organizers.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ..._organizers.map((o) {
                    final isMain = o['is_main'] == true;
                    final perm = o['permission'] ?? 'full';
                    final status = o['invitation_status'] ?? 'accepted';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.cardOf(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.dividerOf(context)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isMain ? AppTheme.accentColor : AppTheme.accentColor.withValues(alpha: 0.7),
                          child: Icon(
                            isMain ? Icons.star_rounded : Icons.person_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          o['display_name'] ?? o['email'] ?? 'User ${o['user_id']}',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryOf(context)),
                        ),
                        subtitle: Row(
                          children: [
                            Text(
                              isMain ? 'Main Organizer' : 'Co-Organizer',
                              style: TextStyle(
                                color: isMain ? AppTheme.successColor : AppTheme.textSecondaryOf(context),
                                fontSize: 13,
                              ),
                            ),
                            if (!isMain) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _statusColor(status).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(fontSize: 11, color: _statusColor(status), fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceOf(context),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  perm,
                                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: isMain
                            ? Chip(
                                label: Text('Owner',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textPrimaryOf(context))),
                                backgroundColor: AppTheme.surfaceOf(context),
                                side: BorderSide.none,
                                padding: EdgeInsets.zero,
                              )
                            : _isMainOrganizer
                                ? PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert, color: AppTheme.textSecondaryOf(context)),
                                    onSelected: (action) {
                                      if (action == 'permission') {
                                        _updatePermission(o['user_id'], perm);
                                      } else if (action == 'remove') {
                                        _removeOrganizer(o['user_id']);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        value: 'permission',
                                        child: Text(perm == 'read' ? 'Set Full Access' : 'Set Read Only'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'remove',
                                        child: Text('Remove', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  )
                                : null,
                      ),
                    );
                  }),
                ],
              ),
      ),
    );
  }
}
