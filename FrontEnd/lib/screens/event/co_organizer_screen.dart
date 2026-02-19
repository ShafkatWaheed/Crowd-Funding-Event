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
  final _userIdCtrl = TextEditingController();
  String _selectedPermission = 'read';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _api.getEventOrganizers(widget.eventId);
      final user = context.read<AuthProvider>().user;
      final mainOrg = list.firstWhere((o) => o['is_main'] == true, orElse: () => {});
      _isMainOrganizer = user != null &&
          (mainOrg['user_id'] == user.id || user.isAdmin);
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

  Future<void> _addOrganizer() async {
    final id = int.tryParse(_userIdCtrl.text.trim());
    if (id == null) {
      AppToast.error(context, 'Enter a valid user ID');
      return;
    }
    try {
      await _api.addEventOrganizer(widget.eventId, {
        'user_id': id,
        'permission': _selectedPermission,
      });
      _userIdCtrl.clear();
      _load();
      if (mounted) {
        AppToast.success(context, 'Co-organizer added');
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to add co-organizer');
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

  @override
  Widget build(BuildContext context) {
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
                          Text('Add Co-Organizer',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _userIdCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: AppTheme.textPrimaryOf(context)),
                            decoration: InputDecoration(
                              labelText: 'User ID',
                              labelStyle: TextStyle(color: AppTheme.textSecondaryOf(context)),
                              hintText: 'Enter user ID',
                              hintStyle: TextStyle(color: AppTheme.textSecondaryOf(context)),
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
                                ? 'Can view event info, management stats, and scan tickets.'
                                : 'Full organizer access — can edit, manage discounts, etc.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondaryOf(context)),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _addOrganizer,
                              icon: const Icon(Icons.person_add_rounded),
                              label: const Text('Add'),
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
                        subtitle: Text(
                          isMain ? 'Main Organizer' : 'Co-Organizer  •  $perm',
                          style: TextStyle(
                            color: isMain ? AppTheme.successColor : AppTheme.textSecondaryOf(context),
                            fontSize: 13,
                          ),
                        ),
                        trailing: (!isMain && _isMainOrganizer)
                            ? IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: AppTheme.errorColor),
                                onPressed: () => _removeOrganizer(o['user_id']),
                              )
                            : isMain
                                ? Chip(
                                    label: Text('Owner',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textPrimaryOf(context))),
                                    backgroundColor: AppTheme.surfaceOf(context),
                                    side: BorderSide.none,
                                    padding: EdgeInsets.zero,
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
