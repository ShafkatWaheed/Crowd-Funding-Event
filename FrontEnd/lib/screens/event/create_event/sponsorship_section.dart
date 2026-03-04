import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/event_form_models.dart';
import '../../../models/sponsor.dart';

class SponsorshipSection extends StatefulWidget {
  final List<EditableSponsorCategory> localCategories;
  final List<SponsorCategoryTemplate> sponsorTemplates;
  final bool templatesLoading;
  final ValueChanged<SponsorCategoryTemplate> onToggleSponsorTemplate;
  final VoidCallback onAddSponsorCategory;
  final ValueChanged<EditableSponsorCategory> onRemoveSponsorCategory;
  final VoidCallback onManageTemplates;
  final VoidCallback onMarkDirty;

  const SponsorshipSection({
    super.key,
    required this.localCategories,
    required this.sponsorTemplates,
    required this.templatesLoading,
    required this.onToggleSponsorTemplate,
    required this.onAddSponsorCategory,
    required this.onRemoveSponsorCategory,
    required this.onManageTemplates,
    required this.onMarkDirty,
  });

  @override
  State<SponsorshipSection> createState() => _SponsorshipSectionState();
}

class _SponsorshipSectionState extends State<SponsorshipSection> {
  bool _showSponsorshipSection = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(
              () => _showSponsorshipSection = !_showSponsorshipSection),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _showSponsorshipSection
                  ? context.ticketAccent.withValues(alpha: 0.08)
                  : AppTheme.cardOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showSponsorshipSection
                    ? context.ticketAccent.withValues(alpha: 0.3)
                    : AppTheme.dividerOf(context),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.storefront_rounded,
                    size: 18,
                    color: _showSponsorshipSection
                        ? context.ticketAccent
                        : AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Sponsorships (Optional)',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppTheme.textPrimaryOf(context))),
                ),
                if (widget.localCategories.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.ticketAccent
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                        '${widget.localCategories.length}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: context.ticketAccent)),
                  ),
                const SizedBox(width: 4),
                Icon(
                  _showSponsorshipSection
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
              color: AppTheme.cardOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.dividerOf(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.templatesLoading)
                  const Center(
                      child: Padding(
                    padding: EdgeInsets.all(16),
                    child:
                        CircularProgressIndicator(strokeWidth: 2),
                  ))
                else if (widget.sponsorTemplates.isEmpty &&
                    widget.localCategories
                        .where((c) => c.templateId == null)
                        .isEmpty)
                  _buildEmptyState(context)
                else if (widget.sponsorTemplates.isEmpty &&
                    widget.localCategories
                        .where((c) => c.templateId == null)
                        .isNotEmpty)
                  _buildDirectOnlyList(context)
                else
                  _buildTemplateList(context),
              ],
            ),
          ),
          crossFadeState: _showSponsorshipSection
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('No sponsorships yet',
                style: TextStyle(
                    color: AppTheme.textSecondaryOf(context))),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: widget.onAddSponsorCategory,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Sponsorship'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: widget.onManageTemplates,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('From Template'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: context.ticketAccent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectOnlyList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...widget.localCategories
            .where((c) => c.templateId == null)
            .map((cat) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _buildDirectSponsorCard(cat),
          );
        }),
        const SizedBox(height: 6),
        _buildActionButtons(context),
      ],
    );
  }

  Widget _buildTemplateList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select sponsorships to attach:',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryOf(context))),
        const SizedBox(height: 4),
        Text(
            'Tap to select, then customize fields for this event.',
            style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondaryOf(context),
                fontStyle: FontStyle.italic)),
        const SizedBox(height: 8),
        ...widget.sponsorTemplates.map((t) {
          final id = t.id;
          final localCat = widget.localCategories
              .where((c) => c.templateId == id)
              .firstOrNull;
          final selected = localCat != null;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              children: [
                _buildTemplateHeader(context, t, selected, localCat),
                if (selected && localCat.expanded)
                  _buildTemplateExpanded(context, localCat),
              ],
            ),
          );
        }),
        ...widget.localCategories
            .where((c) => c.templateId == null)
            .toList()
            .asMap()
            .entries
            .map((entry) {
          final cat = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _buildDirectSponsorCard(cat),
          );
        }),
        const SizedBox(height: 6),
        _buildActionButtons(context),
      ],
    );
  }

  Widget _buildTemplateHeader(BuildContext context,
      SponsorCategoryTemplate t, bool selected, EditableSponsorCategory? localCat) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => widget.onToggleSponsorTemplate(t),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? context.ticketAccent.withValues(alpha: 0.08)
              : AppTheme.surfaceOf(context),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(10),
            topRight: const Radius.circular(10),
            bottomLeft: Radius.circular(
                selected && localCat!.expanded ? 0 : 10),
            bottomRight: Radius.circular(
                selected && localCat!.expanded ? 0 : 10),
          ),
          border: Border.all(
            color: selected
                ? context.ticketAccent.withValues(alpha: 0.4)
                : AppTheme.dividerOf(context),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              size: 20,
              color: selected
                  ? context.ticketAccent
                  : AppTheme.textSecondaryOf(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(t.name,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.textPrimaryOf(context))),
            ),
            if (selected)
              IconButton(
                onPressed: () => setState(
                    () => localCat.expanded = !localCat.expanded),
                icon: Icon(
                    localCat!.expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: context.ticketAccent,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateExpanded(
      BuildContext context, EditableSponsorCategory localCat) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.ticketAccent.withValues(alpha: 0.03),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
        border: Border.all(
            color: context.ticketAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: localCat.nameCtrl,
            decoration: const InputDecoration(
                labelText: 'Sponsorship Name', isDense: true),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: localCat.descCtrl,
            decoration: const InputDecoration(
                labelText: 'Description (optional)',
                isDense: true),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: localCat.spotsCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Total Spots', isDense: true),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: localCat.minBidCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Min Bid (\$)',
                      prefixText: '\$ ',
                      isDense: true),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPrereqSection(localCat),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: widget.onAddSponsorCategory,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Sponsorship'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextButton.icon(
            onPressed: widget.onManageTemplates,
            icon: const Icon(Icons.settings, size: 16),
            label: const Text('Manage Templates'),
            style: TextButton.styleFrom(
                foregroundColor: context.ticketAccent),
          ),
        ),
      ],
    );
  }

  Widget _buildDirectSponsorCard(EditableSponsorCategory cat) {
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
              const Expanded(
                child: Text('New Sponsorship',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppTheme.errorColor),
                onPressed: () =>
                    widget.onRemoveSponsorCategory(cat),
                tooltip: 'Remove',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: cat.nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Sponsorship Name *',
              hintText: 'e.g. Gold Sponsor, Food Stall',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: cat.descCtrl,
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
                  controller: cat.spotsCtrl,
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
                  controller: cat.minBidCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Min Bid (\$) *',
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPrereqSection(cat),
        ],
      ),
    );
  }

  Widget _buildPrereqSection(EditableSponsorCategory cat) {
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
                        color: AppTheme.textPrimaryOf(context))),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: context.ticketAccent
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${cat.prereqs.length}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.ticketAccent)),
                ),
              ],
            ),
            if (cat.prereqs.isNotEmpty) ...[
              const SizedBox(height: 6),
              ...cat.prereqs.asMap().entries.map((entry) {
                final i = entry.key;
                final p = entry.value;
                return _buildPrereqRow(context, cat, i, p, setLocal);
              }),
            ],
            const SizedBox(height: 8),
            _buildPrereqAddRow(
              context,
              cat,
              nameCtrl,
              descCtrl,
              isRequired,
              requiresDocument,
              setLocal,
              (val) => isRequired = val,
              (val) => requiresDocument = val,
            ),
          ],
        );
      },
    );
  }

  Widget _buildPrereqRow(BuildContext context, EditableSponsorCategory cat,
      int i, LocalPrerequisite p, StateSetter setLocal) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(Icons.arrow_right_rounded,
                    size: 18,
                    color: AppTheme.textSecondaryOf(context)),
                Flexible(
                  child: Text(p.name,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimaryOf(context))),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: p.isRequired
                        ? context.discountAccent
                            .withValues(alpha: 0.1)
                        : AppTheme.textSecondaryOf(context)
                            .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    p.isRequired ? 'Required' : 'Optional',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: p.isRequired
                            ? context.discountAccent
                            : AppTheme.textSecondaryOf(context)),
                  ),
                ),
                if (p.requiresDocument) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: context.sponsorAccent
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Doc',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: context.sponsorAccent),
                    ),
                  ),
                ],
              ],
            ),
          ),
          InkWell(
            onTap: () {
              setState(() => cat.prereqs.removeAt(i));
              setLocal(() {});
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close,
                  size: 16, color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrereqAddRow(
    BuildContext context,
    EditableSponsorCategory cat,
    TextEditingController nameCtrl,
    TextEditingController descCtrl,
    bool isRequired,
    bool requiresDocument,
    StateSetter setLocal,
    ValueChanged<bool> onIsRequiredChanged,
    ValueChanged<bool> onRequiresDocumentChanged,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Prerequisite name',
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            style: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          onTap: () {
            onIsRequiredChanged(!isRequired);
            setLocal(() {});
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isRequired
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 18,
                  color: isRequired
                      ? context.ticketAccent
                      : AppTheme.textSecondaryOf(context),
                ),
                const SizedBox(width: 2),
                Text('Req',
                    style: TextStyle(
                        fontSize: 10,
                        color:
                            AppTheme.textSecondaryOf(context))),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          onTap: () {
            onRequiresDocumentChanged(!requiresDocument);
            setLocal(() {});
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  requiresDocument
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 18,
                  color: requiresDocument
                      ? context.sponsorAccent
                      : AppTheme.textSecondaryOf(context),
                ),
                const SizedBox(width: 2),
                Text('Doc',
                    style: TextStyle(
                        fontSize: 10,
                        color:
                            AppTheme.textSecondaryOf(context))),
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
              cat.prereqs.add(LocalPrerequisite(
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
    );
  }
}
