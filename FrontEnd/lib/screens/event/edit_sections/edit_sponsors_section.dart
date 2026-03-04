import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../models/sponsor.dart';
import '../../../providers/sponsor_provider.dart';
import '../../../widgets/app_toast.dart';

class EditLocalPrereq {
  String name;
  String description;
  bool isRequired;
  bool requiresDocument;
  EditLocalPrereq({
    required this.name,
    this.description = '',
    this.isRequired = true,
    this.requiresDocument = false,
  });
}

class EditSponsorCategory {
  int? id;
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final spotsCtrl = TextEditingController(text: '1');
  final minBidCtrl = TextEditingController(text: '100.00');
  List<EditLocalPrereq> prereqs;
  EditSponsorCategory({this.id}) : prereqs = [];
}

class EditSponsorsSection extends StatefulWidget {
  final int eventId;
  const EditSponsorsSection({super.key, required this.eventId});

  @override
  State<EditSponsorsSection> createState() => _EditSponsorsSectionState();
}

class _EditSponsorsSectionState extends State<EditSponsorsSection> {
  bool _expanded = false;
  bool _loaded = false;
  List<EditSponsorCategory> _categories = [];
  List<SponsorCategoryTemplate> _templates = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  // ── Data loading ──

  Future<void> _loadCategories() async {
    try {
      final api = context.read<SponsorProvider>();
      final list = await api.getSponsorshipCategories(widget.eventId);
      if (mounted) {
        setState(() {
          _categories = list.map((cat) {
            final sc = EditSponsorCategory(id: cat.id);
            sc.nameCtrl.text = cat.name;
            sc.descCtrl.text = cat.description ?? '';
            sc.spotsCtrl.text = cat.totalSpots.toString();
            sc.minBidCtrl.text =
                (cat.minBidCents / 100).toStringAsFixed(2);
            return sc;
          }).toList();
          _loaded = true;
          if (_categories.isNotEmpty) _expanded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  // ── CRUD ──

  Future<void> _saveCategory(EditSponsorCategory sc) async {
    final name = sc.nameCtrl.text.trim();
    if (name.isEmpty) return;
    final spots = int.tryParse(sc.spotsCtrl.text.trim()) ?? 1;
    final minBid =
        ((double.tryParse(sc.minBidCtrl.text.trim()) ?? 0) * 100).round();
    final api = context.read<SponsorProvider>();
    try {
      if (sc.id != null) {
        await api.updateSponsorshipCategory(widget.eventId, sc.id!, {
          'name': name,
          'description': sc.descCtrl.text.trim(),
          'total_spots': spots,
          'min_bid_cents': minBid,
        });
        if (mounted) AppToast.success(context, 'Sponsorship updated');
      } else {
        final created =
            await api.createSponsorshipCategory(widget.eventId, {
          'name': name,
          if (sc.descCtrl.text.trim().isNotEmpty)
            'description': sc.descCtrl.text.trim(),
          'total_spots': spots,
          'min_bid_cents': minBid,
          'sort_order': _categories.indexOf(sc),
        });
        sc.id = created.id;
        if (mounted) AppToast.success(context, 'Sponsorship created');
      }
      if (sc.id != null && sc.prereqs.isNotEmpty) {
        for (final p in sc.prereqs) {
          try {
            await api.createPrerequisite(widget.eventId, sc.id!,
                name: p.name,
                description: p.description,
                isRequired: p.isRequired,
                requiresDocument: p.requiresDocument);
          } catch (e) { debugPrint(e.toString()); }
        }
        setState(() => sc.prereqs.clear());
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e,
            fallback: 'Failed to save sponsorship');
      }
    }
  }

  Future<void> _deleteCategory(int idx) async {
    final sc = _categories[idx];
    if (sc.id != null) {
      try {
        final api = context.read<SponsorProvider>();
        await api.deleteSponsorshipCategory(widget.eventId, sc.id!);
      } catch (e) {
        if (mounted) {
          AppToast.fromError(context, e,
              fallback: 'Failed to delete sponsorship');
        }
        return;
      }
    }
    setState(() => _categories.removeAt(idx));
  }

  // ── Template picker ──

  Future<void> _showTemplatePicker() async {
    final api = context.read<SponsorProvider>();
    try {
      final data = await api.getSponsorCategoryTemplates();
      _templates = data;
    } catch (_) {
      if (mounted) AppToast.error(context, 'Failed to load templates');
      return;
    }
    if (!mounted) return;
    final selected = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final chosen = <int>{};
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.5,
            maxChildSize: 0.85,
            minChildSize: 0.3,
            expand: false,
            builder: (_, scrollCtrl) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Copy from Template',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                      'Select templates to copy as new sponsorships',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryOf(ctx))),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _templates.isEmpty
                        ? Center(
                            child: Text('No templates available',
                                style: TextStyle(
                                    color: AppTheme.textSecondaryOf(
                                        ctx))))
                        : ListView.builder(
                            controller: scrollCtrl,
                            itemCount: _templates.length,
                            itemBuilder: (_, i) {
                              final t = _templates[i];
                              final id = t.id;
                              final isChosen = chosen.contains(id);
                              return CheckboxListTile(
                                value: isChosen,
                                onChanged: (v) =>
                                    setSheetState(() {
                                  if (v == true) {
                                    chosen.add(id);
                                  } else {
                                    chosen.remove(id);
                                  }
                                }),
                                title: Text(t.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                subtitle: Text(
                                  '${t.totalSpots} spots · \$${(t.minBidCents / 100).toStringAsFixed(0)} min bid',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          AppTheme.textSecondaryOf(
                                              ctx)),
                                ),
                                dense: true,
                                activeColor: ctx.ticketAccent,
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: chosen.isEmpty
                        ? null
                        : () =>
                            Navigator.pop(ctx, chosen.toList()),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: ctx.ticketAccent,
                        foregroundColor: Colors.white),
                    child: Text(
                        'Add ${chosen.length} sponsorship${chosen.length == 1 ? '' : 's'}'),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
    if (selected == null || selected.isEmpty) return;
    for (final templateId in selected) {
      final t =
          _templates.firstWhere((t) => t.id == templateId);
      final sc = EditSponsorCategory();
      sc.nameCtrl.text = t.name;
      sc.descCtrl.text = t.description ?? '';
      sc.spotsCtrl.text = '${t.totalSpots}';
      sc.minBidCtrl.text =
          (t.minBidCents / 100).toStringAsFixed(2);
      setState(() => _categories.add(sc));
    }
  }

  // ── Prerequisite bottom sheet ──

  Future<void> _showPrerequisiteSheet(EditSponsorCategory sc) async {
    if (sc.id == null) return;
    final api = context.read<SponsorProvider>();
    List<CategoryPrerequisite> prereqs = [];
    try {
      prereqs =
          await api.listPrerequisites(widget.eventId, sc.id!);
    } catch (e) { debugPrint(e.toString()); }
    if (!mounted) return;

    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isRequired = true;
    bool requiresDocument = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) =>
          StatefulBuilder(builder: (ctx, setSheetState) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          maxChildSize: 0.85,
          minChildSize: 0.3,
          expand: false,
          builder: (_, scrollCtrl) => Padding(
            padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom:
                    MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                    'Prerequisites for "${sc.nameCtrl.text}"',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                            fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Expanded(
                  child: prereqs.isEmpty
                      ? Center(
                          child: Text(
                              'No prerequisites yet',
                              style: TextStyle(
                                  color:
                                      AppTheme.textSecondaryOf(
                                          ctx))))
                      : ListView.builder(
                          controller: scrollCtrl,
                          itemCount: prereqs.length,
                          itemBuilder: (_, i) {
                            final p = prereqs[i];
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                p.isRequired
                                    ? Icons.check_circle
                                    : Icons
                                        .radio_button_unchecked,
                                size: 18,
                                color: p.isRequired
                                    ? ctx.fundingAccent
                                    : AppTheme
                                        .textSecondaryOf(
                                            ctx),
                              ),
                              title: Text(
                                  p.name,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight:
                                          FontWeight.w600)),
                              subtitle: p.description !=
                                          null &&
                                      p.description!
                                          .isNotEmpty
                                  ? Text(
                                      p.description!,
                                      style:
                                          const TextStyle(
                                              fontSize:
                                                  11))
                                  : null,
                              trailing: IconButton(
                                icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: AppTheme
                                        .errorColor),
                                onPressed: () async {
                                  try {
                                    await api
                                        .deletePrerequisite(
                                            widget.eventId,
                                            sc.id!,
                                            p.id);
                                    setSheetState(() =>
                                        prereqs
                                            .removeAt(i));
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      AppToast.fromError(
                                          ctx, e,
                                          fallback:
                                              'Failed to delete');
                                    }
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
                const Divider(),
                Text('Add Prerequisite',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            AppTheme.textPrimaryOf(ctx))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Name *',
                      isDense: true,
                      hintText: 'e.g. Business License'),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Description',
                      isDense: true),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Checkbox(
                      value: isRequired,
                      onChanged: (v) => setSheetState(
                          () => isRequired = v ?? true),
                      activeColor: ctx.fundingAccent,
                    ),
                    const Text('Required',
                        style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    Checkbox(
                      value: requiresDocument,
                      onChanged: (v) => setSheetState(
                          () =>
                              requiresDocument = v ?? false),
                      activeColor: ctx.sponsorAccent,
                    ),
                    const Text('Doc',
                        style: TextStyle(fontSize: 13)),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final name =
                            nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        try {
                          final resp =
                              await api.createPrerequisite(
                            widget.eventId,
                            sc.id!,
                            name: name,
                            description: descCtrl.text
                                    .trim()
                                    .isEmpty
                                ? null
                                : descCtrl.text.trim(),
                            isRequired: isRequired,
                            requiresDocument:
                                requiresDocument,
                          );
                          setSheetState(() {
                            prereqs.add(resp);
                            nameCtrl.clear();
                            descCtrl.clear();
                            isRequired = true;
                            requiresDocument = false;
                          });
                        } catch (e) {
                          if (ctx.mounted) {
                            AppToast.fromError(ctx, e,
                                fallback:
                                    'Failed to add');
                          }
                        }
                      },
                      icon:
                          const Icon(Icons.add, size: 16),
                      label: const Text('Add'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                              ctx.fundingAccent,
                          foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _expanded
                  ? context.ticketAccent.withValues(alpha: 0.08)
                  : AppTheme.surfaceOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _expanded
                    ? context.ticketAccent.withValues(alpha: 0.3)
                    : AppTheme.dividerOf(context),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.storefront_rounded,
                    size: 18,
                    color: _expanded
                        ? context.ticketAccent
                        : AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sponsorships (Optional)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                ),
                if (_categories.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.ticketAccent
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_categories.length}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: context.ticketAccent),
                    ),
                  ),
                const SizedBox(width: 4),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceOf(context),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppTheme.dividerOf(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_loaded)
                  const Center(
                      child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ))
                else ...[
                  for (int i = 0; i < _categories.length; i++) ...[
                    _buildCategoryCard(i),
                    if (i < _categories.length - 1)
                      const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() =>
                              _categories
                                  .add(EditSponsorCategory())),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Sponsorship'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showTemplatePicker,
                          icon: const Icon(Icons.copy_rounded,
                              size: 18),
                          label: const Text('From Template'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  context.ticketAccent),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(int index) {
    final sc = _categories[index];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.ticketAccent.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: context.ticketAccent.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sc.id != null
                      ? 'Sponsorship #${sc.id}'
                      : 'New Sponsorship',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              if (sc.id != null)
                InkWell(
                  onTap: () => _showPrerequisiteSheet(sc),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.fundingAccent
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: context.fundingAccent
                              .withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.checklist_rounded,
                            size: 14,
                            color: context.fundingAccent),
                        const SizedBox(width: 4),
                        Text('Prerequisites',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: context.fundingAccent)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              IconButton(
                icon: Icon(Icons.save, size: 18,
                    color: context.ticketAccent),
                onPressed: () => _saveCategory(sc),
                tooltip: 'Save',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppTheme.errorColor),
                onPressed: () => _deleteCategory(index),
                tooltip: 'Delete',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: sc.nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Sponsorship Name *',
              hintText: 'e.g. Gold Sponsor, Food Stall',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: sc.descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description',
              isDense: true,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: sc.spotsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Total Spots *',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: sc.minBidCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Min Bid (\$) *',
                    isDense: true,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(
                          decimal: true),
                ),
              ),
            ],
          ),
          if (sc.id == null || sc.prereqs.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildPrereqSection(sc),
          ],
        ],
      ),
    );
  }

  Widget _buildPrereqSection(EditSponsorCategory sc) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isRequired = true;
    bool requiresDocument = false;

    return StatefulBuilder(
      builder: (context, setLocal) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.checklist_rounded,
                    size: 16, color: context.ticketAccent),
                const SizedBox(width: 6),
                Text('Prerequisites',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            AppTheme.textPrimaryOf(context))),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: context.ticketAccent
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${sc.prereqs.length}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.ticketAccent)),
                ),
              ],
            ),
            if (sc.prereqs.isNotEmpty) ...[
              const SizedBox(height: 6),
              ...sc.prereqs.asMap().entries.map((entry) {
                final i = entry.key;
                final p = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.arrow_right_rounded,
                                size: 18,
                                color:
                                    AppTheme.textSecondaryOf(
                                        context)),
                            Flexible(
                              child: Text(p.name,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme
                                          .textPrimaryOf(
                                              context))),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1),
                              decoration: BoxDecoration(
                                color: p.isRequired
                                    ? AppTheme
                                        .errorSurfaceOf(
                                            context)
                                    : AppTheme
                                            .textSecondaryOf(
                                                context)
                                        .withValues(
                                            alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(6),
                              ),
                              child: Text(
                                p.isRequired
                                    ? 'Required'
                                    : 'Optional',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight:
                                        FontWeight.w600,
                                    color: p.isRequired
                                        ? AppTheme
                                            .errorColor
                                        : AppTheme
                                            .textSecondaryOf(
                                                context)),
                              ),
                            ),
                            if (p.requiresDocument) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets
                                    .symmetric(
                                    horizontal: 5,
                                    vertical: 1),
                                decoration: BoxDecoration(
                                  color: context
                                      .sponsorAccent
                                      .withValues(
                                          alpha: 0.1),
                                  borderRadius:
                                      BorderRadius
                                          .circular(6),
                                ),
                                child: Text(
                                  'Doc',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight:
                                          FontWeight.w600,
                                      color: context
                                          .sponsorAccent),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(
                              () => sc.prereqs.removeAt(i));
                          setLocal(() {});
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.close,
                              size: 16,
                              color: AppTheme.errorColor),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Prerequisite name',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => setLocal(
                      () => isRequired = !isRequired),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isRequired
                              ? Icons.check_box
                              : Icons
                                  .check_box_outline_blank,
                          size: 18,
                          color: isRequired
                              ? context.ticketAccent
                              : AppTheme.textSecondaryOf(
                                  context),
                        ),
                        const SizedBox(width: 2),
                        Text('Req',
                            style: TextStyle(
                                fontSize: 10,
                                color:
                                    AppTheme.textSecondaryOf(
                                        context))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => setLocal(() =>
                      requiresDocument = !requiresDocument),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          requiresDocument
                              ? Icons.check_box
                              : Icons
                                  .check_box_outline_blank,
                          size: 18,
                          color: requiresDocument
                              ? context.sponsorAccent
                              : AppTheme.textSecondaryOf(
                                  context),
                        ),
                        const SizedBox(width: 2),
                        Text('Doc',
                            style: TextStyle(
                                fontSize: 10,
                                color:
                                    AppTheme.textSecondaryOf(
                                        context))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    setState(() {
                      sc.prereqs.add(EditLocalPrereq(
                        name: name,
                        description: descCtrl.text.trim(),
                        isRequired: isRequired,
                        requiresDocument: requiresDocument,
                      ));
                    });
                    nameCtrl.clear();
                    descCtrl.clear();
                    setLocal(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: context.ticketAccent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.add,
                        size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
