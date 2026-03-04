import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/sponsor.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../repositories/base_repository.dart';
import '../../providers/sponsor_provider.dart';

class SponsorCategoryTemplatesScreen extends StatefulWidget {
  const SponsorCategoryTemplatesScreen({super.key});

  @override
  State<SponsorCategoryTemplatesScreen> createState() =>
      _SponsorCategoryTemplatesScreenState();
}

class _SponsorCategoryTemplatesScreenState
    extends State<SponsorCategoryTemplatesScreen> {
  List<SponsorCategoryTemplate> _templates = [];
  List<SponsorCategoryTemplate> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final api = context.read<SponsorProvider>();
      final data = await api.getSponsorCategoryTemplates();
      if (!mounted) return;
      setState(() {
        _templates = data;
        _applySearch();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppToast.fromError(context, e, fallback: 'Failed to load');
      }
    }
  }

  void _applySearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      _filtered = List.from(_templates);
    } else {
      _filtered = _templates.where((t) {
        return t.name.toLowerCase().contains(q) ||
            (t.description ?? '').toLowerCase().contains(q);
      }).toList();
    }
  }

  Future<void> _delete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Template'),
        content: const Text(
            'This will permanently delete this sponsor category template. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    try {
      final api = context.read<SponsorProvider>();
      await api.deleteSponsorCategoryTemplate(id);
      if (mounted) AppToast.success(context, 'Template deleted');
      _load();
    } catch (e) {
      if (mounted) AppToast.fromError(context, e, fallback: 'Delete failed');
    }
  }

  void _showCreateOrEdit({SponsorCategoryTemplate? existing}) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _TemplateFormScreen(existing: existing),
      ),
    ).then((created) {
      if (created == true) _load();
    });
  }

  void _showPrerequisites(SponsorCategoryTemplate template) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TemplatePrerequisiteSheet(
        templateId: template.id,
        templateName: template.name,
      ),
    );
  }

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
        title: const Text('Sponsor Categories'),
      ),
      backgroundColor: AppTheme.surfaceOf(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('New Category'),
        backgroundColor: AppTheme.accentColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search categories...',
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
                fillColor: AppTheme.cardOf(context),
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
          Expanded(
            child: _loading
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children:
                          List.generate(3, (_) => const ShimmerListTile()),
                    ),
                  )
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.category_outlined,
                                size: 64,
                                color: AppTheme.textSecondaryOf(context)),
                            const SizedBox(height: 16),
                            Text(
                              _searchCtrl.text.isNotEmpty
                                  ? 'No matching categories'
                                  : 'No sponsor categories yet',
                              style: TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.textSecondaryOf(context)),
                            ),
                            if (_searchCtrl.text.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                    'Create reusable sponsor categories with requirements',
                                    style: TextStyle(
                                        color:
                                            AppTheme.textSecondaryOf(context))),
                              ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final t = _filtered[index];
                            return _TemplateCard(
                              template: t,
                              onEdit: () => _showCreateOrEdit(existing: t),
                              onDelete: () => _delete(t.id),
                              onPrereqs: () => _showPrerequisites(t),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final SponsorCategoryTemplate template;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPrereqs;

  const _TemplateCard({
    required this.template,
    required this.onEdit,
    required this.onDelete,
    required this.onPrereqs,
  });

  @override
  Widget build(BuildContext context) {
    final name = template.name;
    final desc = template.description ?? '';
    final spots = template.totalSpots;
    final minBid = template.minBidCents;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.cardOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.dividerOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.sponsorAccent.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.category_rounded,
                      size: 20, color: context.sponsorAccent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'prereqs') onPrereqs();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(
                        value: 'prereqs', child: Text('Requirements')),
                    PopupMenuItem(
                      value: 'delete',
                      child:
                          Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
                    ),
                  ],
                ),
              ],
            ),
            if (desc.toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, color: AppTheme.textSecondaryOf(context)),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _InfoChip(
                    icon: Icons.people_outline_rounded,
                    label: '$spots spots'),
                const SizedBox(width: 12),
                _InfoChip(
                  icon: Icons.monetization_on_outlined,
                  label: '\$${(minBid / 100).toStringAsFixed(2)} min',
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onPrereqs,
                icon: const Icon(Icons.checklist_rounded, size: 18),
                label: const Text('Manage Requirements'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.sponsorAccent,
                  side: BorderSide(color: context.sponsorAccent),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondaryOf(context)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textSecondaryOf(context))),
        ],
      ),
    );
  }
}

class _TemplateFormScreen extends StatefulWidget {
  final SponsorCategoryTemplate? existing;
  const _TemplateFormScreen({this.existing});

  @override
  State<_TemplateFormScreen> createState() => _TemplateFormScreenState();
}

class _TemplateFormScreenState extends State<_TemplateFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _spotsCtrl;
  late final TextEditingController _minBidCtrl;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _descCtrl =
        TextEditingController(text: widget.existing?.description ?? '');
    _spotsCtrl = TextEditingController(
        text: widget.existing != null ? widget.existing!.totalSpots.toString() : '');
    final minBidCents = widget.existing?.minBidCents ?? 0;
    _minBidCtrl = TextEditingController(
        text: minBidCents > 0 ? (minBidCents / 100).toStringAsFixed(2) : '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _spotsCtrl.dispose();
    _minBidCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = {
      'name': _nameCtrl.text.trim(),
      'description':
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'total_spots': int.parse(_spotsCtrl.text.trim()),
      'min_bid_cents': (double.parse(_minBidCtrl.text.trim()) * 100).round(),
    };

    try {
      final api = context.read<SponsorProvider>();
      if (_isEditing) {
        await api.updateSponsorCategoryTemplate(
            widget.existing!.id, data);
      } else {
        await api.createSponsorCategoryTemplate(data);
      }
      if (mounted) {
        AppToast.success(
            context, _isEditing ? 'Category updated' : 'Category created');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.fromError(context, e, fallback: 'Save failed');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Category' : 'New Sponsor Category'),
      ),
      backgroundColor: AppTheme.surfaceOf(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Category Name *',
                  hintText: 'e.g. Gold Sponsor, Stage Banner',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What does this sponsorship include?',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _spotsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Total Spots *',
                  hintText: 'How many sponsors can fill this category',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final n = int.tryParse(v.trim());
                  if (n == null || n < 1) return 'Must be at least 1';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _minBidCtrl,
                decoration: const InputDecoration(
                  labelText: 'Minimum Bid (\$) *',
                  hintText: '0.00',
                  prefixText: '\$ ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final n = double.tryParse(v.trim());
                  if (n == null || n <= 0) return 'Must be greater than 0';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(_isEditing ? 'Update Category' : 'Create Category',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplatePrerequisiteSheet extends StatefulWidget {
  final int templateId;
  final String templateName;

  const _TemplatePrerequisiteSheet({
    required this.templateId,
    required this.templateName,
  });

  @override
  State<_TemplatePrerequisiteSheet> createState() =>
      _TemplatePrerequisiteSheetState();
}

class _TemplatePrerequisiteSheetState
    extends State<_TemplatePrerequisiteSheet> {
  List<TemplatePrerequisite> _prereqs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<SponsorProvider>();
      final data = await api.listTemplatePrerequisites(widget.templateId);
      if (mounted) {
        setState(() {
          _prereqs = data;
          _loading = false;
        });
      }
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
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add')),
          ],
        ),
      ),
    );

    if (confirmed != true || nameCtrl.text.trim().isEmpty) return;
    if (!mounted) return;

    try {
      final api = context.read<SponsorProvider>();
      await api.createTemplatePrerequisite(
        widget.templateId,
        name: nameCtrl.text.trim(),
        description:
            descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
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
    try {
      final api = context.read<SponsorProvider>();
      await api.deleteTemplatePrerequisite(widget.templateId, prereqId);
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
              width: 40,
              height: 4,
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
                    'Requirements: ${widget.templateName}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _add,
                  icon: Icon(Icons.add_circle_rounded,
                      color: context.sponsorAccent),
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
                            style: TextStyle(
                                color: AppTheme.textSecondaryOf(context)),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollCtrl,
                          itemCount: _prereqs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final p = _prereqs[i];
                            final isReq = p.isRequired;
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceOf(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppTheme.dividerOf(context)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isReq
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    size: 18,
                                    color: isReq
                                        ? context.sponsorAccent
                                        : AppTheme.textSecondaryOf(context),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimaryOf(
                                                context),
                                          ),
                                        ),
                                        if (p.description != null &&
                                            p.description!.isNotEmpty)
                                          Text(
                                            p.description!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  AppTheme.textSecondaryOf(
                                                      context),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        _delete(p.id),
                                    icon: Icon(Icons.delete_outline,
                                        size: 18, color: AppTheme.errorColor),
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
