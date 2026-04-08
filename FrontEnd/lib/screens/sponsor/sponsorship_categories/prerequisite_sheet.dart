import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../models/sponsor.dart';
import '../../../repositories/base_repository.dart';
import '../../../providers/sponsor_provider.dart';
import '../../../widgets/app_toast.dart';
import '../../event/create_event/create_event_actions.dart' show confirmDelete;

class PrerequisiteSheet extends StatefulWidget {
  final int eventId;
  final int categoryId;
  final String categoryName;
  final bool readOnly;

  const PrerequisiteSheet({
    super.key,
    required this.eventId,
    required this.categoryId,
    required this.categoryName,
    this.readOnly = false,
  });

  @override
  State<PrerequisiteSheet> createState() => _PrerequisiteSheetState();
}

class _PrerequisiteSheetState extends State<PrerequisiteSheet> {
  List<CategoryPrerequisite> _prereqs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<SponsorProvider>();
      final data = await api.listPrerequisites(widget.eventId, widget.categoryId);
      if (mounted) setState(() { _prereqs = data; _loading = false; });
    } catch (e) {
      if (mounted) {
        AppToast.error(context, ApiError.extractMessage(e));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _add() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isRequired = true;
    bool requiresDocument = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: const Text('Add Requirement'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name *'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => setInner(() => isRequired = !isRequired),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24, height: 24,
                          child: Checkbox(
                            value: isRequired,
                            onChanged: (v) => setInner(() => isRequired = v ?? true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('Required for bid acceptance')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setInner(() => requiresDocument = !requiresDocument),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24, height: 24,
                          child: Checkbox(
                            value: requiresDocument,
                            onChanged: (v) => setInner(() => requiresDocument = v ?? false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('Requires document upload')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );

    if (confirmed != true || nameCtrl.text.trim().isEmpty) return;
    if (!mounted) return;

    try {
      final api = context.read<SponsorProvider>();
      await api.createPrerequisite(
        widget.eventId,
        widget.categoryId,
        name: nameCtrl.text.trim(),
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        isRequired: isRequired,
        requiresDocument: requiresDocument,
      );
      if (mounted) AppToast.success(context, 'Requirement added');
      _load();
    } catch (e) {
      if (mounted) AppToast.error(context, ApiError.extractMessage(e));
    }
  }

  Future<void> _delete(int prereqId) async {
    if (!await confirmDelete(context, 'requirement')) return;
    if (!mounted) return;
    try {
      final api = context.read<SponsorProvider>();
      await api.deletePrerequisite(widget.eventId, widget.categoryId, prereqId);
      if (mounted) AppToast.success(context, 'Requirement removed');
      _load();
    } catch (e) {
      if (mounted) AppToast.error(context, ApiError.extractMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (ctx, scrollCtrl) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerOf(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Requirements: ${widget.categoryName}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                ),
                if (!widget.readOnly)
                  IconButton(
                    onPressed: _add,
                    icon: Icon(Icons.add_circle_rounded, color: context.sponsorAccent),
                    tooltip: 'Add requirement',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _prereqs.isEmpty
                      ? Center(
                          child: Text(
                            'No requirements yet.\nTap + to add one.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondaryOf(context)),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollCtrl,
                          itemCount: _prereqs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final p = _prereqs[i];
                            final required_ = p.isRequired;
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceOf(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.dividerOf(context)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    required_ ? Icons.star_rounded : Icons.star_border_rounded,
                                    size: 18,
                                    color: required_ ? context.sponsorAccent : AppTheme.textSecondaryOf(context),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimaryOf(context),
                                          ),
                                        ),
                                        if (p.description != null && p.description!.isNotEmpty)
                                          Text(
                                            p.description!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondaryOf(context),
                                            ),
                                          ),
                                        Row(
                                          children: [
                                            Text(
                                              required_ ? 'Required' : 'Optional',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: required_ ? context.sponsorAccent : AppTheme.textSecondaryOf(context),
                                              ),
                                            ),
                                            if (p.requiresDocument) ...[
                                              const SizedBox(width: 8),
                                              Icon(Icons.upload_file_rounded, size: 13, color: context.sponsorAccent),
                                              const SizedBox(width: 2),
                                              Text(
                                                'Doc required',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: context.sponsorAccent,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!widget.readOnly)
                                    IconButton(
                                      onPressed: () => _delete(p.id),
                                      icon: Icon(Icons.delete_outline_rounded,
                                          color: AppTheme.errorColor, size: 20),
                                      tooltip: 'Remove',
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
