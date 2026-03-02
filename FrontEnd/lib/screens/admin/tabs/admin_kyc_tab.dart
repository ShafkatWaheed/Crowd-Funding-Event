import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../admin_shared.dart';
import '../../../config/design_tokens.dart';
import '../../../config/theme.dart';
import '../../../repositories/base_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../../widgets/admin/admin_empty_state.dart';

class AdminKycTab extends StatefulWidget {
  const AdminKycTab({super.key, required this.onSnack});

  final void Function(String msg, {bool isError}) onSnack;

  @override
  State<AdminKycTab> createState() => _AdminKycTabState();
}

class _AdminKycTabState extends State<AdminKycTab> {
  List<dynamic> _pendingUsers = [];
  bool _loading = true;
  String _searchText = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> get _filteredUsers {
    if (_searchText.isEmpty) return _pendingUsers;
    final q = _searchText.toLowerCase();
    return _pendingUsers.where((u) {
      final name = (u['display_name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final role = (u['role'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q) || role.contains(q);
    }).toList();
  }

  Future<void> _loadPending() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<UserRepository>().adminGetKycPending();
      if (mounted) setState(() => _pendingUsers = data);
    } catch (e) {
      widget.onSnack(ApiError.extractMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pendingUsers.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadPending,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: 400,
            child: AdminEmptyState(
              icon: Icons.verified_user,
              message: 'No pending KYC submissions',
            ),
          ),
        ),
      );
    }

    final filtered = _filteredUsers;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, email, or role...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchText.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchText = '');
                      },
                    )
                  : null,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            style: TextStyle(
                fontSize: 14, color: AppTheme.textPrimaryOf(context)),
            onChanged: (v) => setState(() => _searchText = v.trim()),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadPending,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final u = filtered[index] as Map<String, dynamic>;
                return _KycUserCard(
                  user: u,
                  onSnack: widget.onSnack,
                  onDone: _loadPending,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _KycUserCard extends StatefulWidget {
  const _KycUserCard({
    required this.user,
    required this.onSnack,
    required this.onDone,
  });

  final Map<String, dynamic> user;
  final void Function(String msg, {bool isError}) onSnack;
  final VoidCallback onDone;

  @override
  State<_KycUserCard> createState() => _KycUserCardState();
}

class _KycUserCardState extends State<_KycUserCard> {
  bool _expanded = false;
  List<dynamic>? _documents;
  bool _loadingDocs = false;
  bool _acting = false;

  Future<void> _loadDocuments() async {
    setState(() => _loadingDocs = true);
    try {
      final docs = await context
          .read<UserRepository>()
          .adminGetUserKycDocuments(widget.user['user_id']);
      if (mounted) setState(() => _documents = docs);
    } catch (e) {
      widget.onSnack(ApiError.extractMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loadingDocs = false);
    }
  }

  Future<void> _approve() async {
    setState(() => _acting = true);
    try {
      await context
          .read<UserRepository>()
          .adminVerifyKyc(widget.user['user_id'], approved: true);
      widget.onSnack('KYC approved');
      widget.onDone();
    } catch (e) {
      widget.onSnack(ApiError.extractMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Reject KYC'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Rejection reason',
              hintText: 'e.g. Document unreadable, ID expired',
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
    if (reason == null || reason.isEmpty) return;
    if (!mounted) return;

    setState(() => _acting = true);
    try {
      await context.read<UserRepository>().adminVerifyKyc(
            widget.user['user_id'],
            approved: false,
            rejectionReason: reason,
          );
      widget.onSnack('KYC rejected');
      widget.onDone();
    } catch (e) {
      widget.onSnack(ApiError.extractMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: roleColor(context, u['role'] ?? ''),
              child: Text(
                (u['display_name'] ?? u['email'] ?? '?')
                    .substring(0, 1)
                    .toUpperCase(),
                style: TextStyle(color: context.onDarkSurface),
              ),
            ),
            title: Text(u['display_name'] ?? u['email'] ?? 'Unknown'),
            subtitle: Text(
              '${u['email']} | ${statusLabel(u['role'] ?? '')} | ${u['document_count'] ?? 0} docs',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_acting)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  IconButton(
                    icon: Icon(Icons.check_circle,
                        color: AppTheme.successOf(context)),
                    tooltip: 'Approve',
                    onPressed: _approve,
                  ),
                  IconButton(
                    icon:
                        Icon(Icons.cancel, color: AppTheme.errorOf(context)),
                    tooltip: 'Reject',
                    onPressed: _reject,
                  ),
                ],
                IconButton(
                  icon: Icon(_expanded
                      ? Icons.expand_less
                      : Icons.expand_more),
                  onPressed: () {
                    setState(() => _expanded = !_expanded);
                    if (_expanded && _documents == null) _loadDocuments();
                  },
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            if (_loadingDocs)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_documents != null && _documents!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: _documents!.map((doc) {
                    final d = doc as Map<String, dynamic>;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        _docTypeIcon(d['document_type'] ?? ''),
                        size: 20,
                      ),
                      title: Text(
                        statusLabel(d['document_type'] ?? ''),
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        d['original_filename'] ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                      trailing: statusChip(
                        context,
                        statusLabel(d['status'] ?? ''),
                        d['status'] == 'approved'
                            ? AppTheme.successOf(context)
                            : d['status'] == 'rejected'
                                ? AppTheme.errorOf(context)
                                : AppTheme.warningOf(context),
                      ),
                    );
                  }).toList(),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No documents uploaded'),
              ),
          ],
        ],
      ),
    );
  }

  IconData _docTypeIcon(String type) {
    switch (type) {
      case 'id_front':
      case 'id_back':
        return Icons.badge;
      case 'proof_of_address':
        return Icons.home;
      case 'selfie':
        return Icons.face;
      case 'tax_id':
        return Icons.receipt_long;
      default:
        return Icons.insert_drive_file;
    }
  }
}
