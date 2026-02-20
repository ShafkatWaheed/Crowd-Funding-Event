import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/sponsor.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/shimmer_loaders.dart';

class SponsorshipCategoriesScreen extends StatefulWidget {
  final int eventId;
  const SponsorshipCategoriesScreen({super.key, required this.eventId});

  @override
  State<SponsorshipCategoriesScreen> createState() =>
      _SponsorshipCategoriesScreenState();
}

class _SponsorshipCategoriesScreenState
    extends State<SponsorshipCategoriesScreen> {
  List<SponsorshipCategory> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getSponsorshipCategories(widget.eventId);
      if (mounted) {
        setState(() {
          _categories =
              data.map((j) => SponsorshipCategory.fromJson(j)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, ApiService.extractError(e));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showPlaceBidDialog(SponsorshipCategory cat) async {
    final amountCtrl = TextEditingController(
      text: (cat.minBidCents / 100).toStringAsFixed(2),
    );
    final proposalCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Bid on "${cat.name}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Min bid: ${cat.minBidDisplay}  •  '
              '${cat.availableSpots} spot${cat.availableSpots == 1 ? "" : "s"} left',
              style: TextStyle(
                  fontSize: 13, color: AppTheme.textSecondaryOf(ctx)),
            ),
            if (cat.bidCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${cat.bidCount} bid${cat.bidCount == 1 ? "" : "s"} placed'
                '${cat.myBidCount > 0 ? "  •  ${cat.myBidCount} by you" : ""}',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textSecondaryOf(ctx)),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Bid Amount (\$)',
                prefixText: '\$ ',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: proposalCtrl,
              decoration: const InputDecoration(
                labelText: 'Proposal (optional)',
                hintText: 'Why you want to sponsor...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Place Bid'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final amount =
        ((double.tryParse(amountCtrl.text) ?? 0) * 100).round();
    try {
      final api = context.read<ApiService>();
      await api.placeBid(widget.eventId, cat.id, {
        'amount_cents': amount,
        if (proposalCtrl.text.trim().isNotEmpty)
          'proposal_text': proposalCtrl.text.trim(),
      });
      if (mounted) AppToast.success(context, 'Bid placed!');
      _load();
    } catch (e) {
      if (mounted) AppToast.error(context, ApiService.extractError(e));
    }
  }

  Future<void> _showUploadDocsSheet(SponsorshipCategory cat) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: AppTheme.cardOf(context),
      builder: (ctx) => _SponsorUploadSheet(
        eventId: widget.eventId,
        categoryId: cat.id,
        categoryName: cat.name,
      ),
    );
  }

  Future<void> _showPrerequisitesSheet(SponsorshipCategory cat) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: AppTheme.cardOf(context),
      builder: (ctx) => _PrerequisiteSheet(
        eventId: widget.eventId,
        categoryId: cat.id,
        categoryName: cat.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isSponsor = user?.isSponsor ?? false;
    final isOrganizerOrAdmin = user != null && (user.isOrganizer || user.isAdmin);

    return Scaffold(
      appBar: AppBar(title: const Text('Sponsorship Categories')),
      body: _loading
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List.generate(3, (_) => const ShimmerListTile()),
              ),
            )
          : _categories.isEmpty
              ? LayoutBuilder(
                  builder: (context, constraints) => RefreshIndicator(
                    onRefresh: _load,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Center(
                          child: Text(
                            'No sponsorship categories yet.',
                            style: TextStyle(
                                color: AppTheme.textSecondaryOf(context)),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cat.name,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppTheme.textPrimaryOf(context))),
                            if (cat.description != null &&
                                cat.description!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(cat.description!,
                                  style: TextStyle(
                                      color:
                                          AppTheme.textSecondaryOf(context),
                                      fontSize: 13)),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _infoBadge(
                                    Icons.monetization_on_outlined,
                                    'Min: ${cat.minBidDisplay}'),
                                const SizedBox(width: 12),
                                _infoBadge(Icons.people_outline,
                                    '${cat.filledSpots}/${cat.totalSpots} spots'),
                                const SizedBox(width: 12),
                                _infoBadge(Icons.gavel,
                                    '${cat.bidCount} bid${cat.bidCount == 1 ? "" : "s"}'),
                              ],
                            ),
                            if (isSponsor && cat.canPlaceMoreBids) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _showPlaceBidDialog(cat),
                                  icon: const Icon(Icons.gavel, size: 18),
                                  label: Text(cat.myBidCount > 0
                                      ? 'Place Another Bid (${cat.myBidCount}/${cat.totalSpots})'
                                      : 'Place Bid'),
                                ),
                              ),
                            ],
                            if (isSponsor && cat.myBidCount > 0) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _showUploadDocsSheet(cat),
                                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                                  label: const Text('Upload Documents',
                                      style: TextStyle(fontWeight: FontWeight.w600)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.deepPurple,
                                    side: const BorderSide(color: Colors.deepPurple),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                            if (isOrganizerOrAdmin) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => context.push(
                                        '/events/${widget.eventId}/sponsorships/${cat.id}/bids',
                                      ),
                                      icon: const Icon(Icons.visibility_rounded, size: 18),
                                      label: Text(
                                        'View Bids (${cat.bidCount})',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.teal,
                                        side: const BorderSide(color: Colors.teal),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => _showPrerequisitesSheet(cat),
                                    icon: const Icon(Icons.checklist_rounded, size: 18),
                                    label: const Text('Reqs',
                                        style: TextStyle(fontWeight: FontWeight.w600)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.deepPurple,
                                      side: const BorderSide(color: Colors.deepPurple),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
    );
  }

  Widget _infoBadge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondaryOf(context)),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                fontSize: 12, color: AppTheme.textSecondaryOf(context))),
      ],
    );
  }
}


class _PrerequisiteSheet extends StatefulWidget {
  final int eventId;
  final int categoryId;
  final String categoryName;

  const _PrerequisiteSheet({
    required this.eventId,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<_PrerequisiteSheet> createState() => _PrerequisiteSheetState();
}

class _PrerequisiteSheetState extends State<_PrerequisiteSheet> {
  List<Map<String, dynamic>> _prereqs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.listPrerequisites(widget.eventId, widget.categoryId);
      if (mounted) setState(() { _prereqs = data.cast<Map<String, dynamic>>(); _loading = false; });
    } catch (e) {
      if (mounted) {
        AppToast.error(context, ApiService.extractError(e));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _add() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isRequired = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: const Text('Add Requirement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 8),
              CheckboxListTile(
                value: isRequired,
                onChanged: (v) => setInner(() => isRequired = v ?? true),
                title: const Text('Required for bid acceptance'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );

    if (confirmed != true || nameCtrl.text.trim().isEmpty) return;

    try {
      final api = context.read<ApiService>();
      await api.createPrerequisite(
        widget.eventId,
        widget.categoryId,
        name: nameCtrl.text.trim(),
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        isRequired: isRequired,
      );
      if (mounted) AppToast.success(context, 'Requirement added');
      _load();
    } catch (e) {
      if (mounted) AppToast.error(context, ApiService.extractError(e));
    }
  }

  Future<void> _delete(int prereqId) async {
    try {
      final api = context.read<ApiService>();
      await api.deletePrerequisite(widget.eventId, widget.categoryId, prereqId);
      if (mounted) AppToast.success(context, 'Requirement removed');
      _load();
    } catch (e) {
      if (mounted) AppToast.error(context, ApiService.extractError(e));
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
                IconButton(
                  onPressed: _add,
                  icon: Icon(Icons.add_circle_rounded, color: Colors.deepPurple),
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
                            final required_ = p['is_required'] == true;
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
                                    color: required_ ? Colors.deepPurple : AppTheme.textSecondaryOf(context),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p['name'] ?? '',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimaryOf(context),
                                          ),
                                        ),
                                        if (p['description'] != null && (p['description'] as String).isNotEmpty)
                                          Text(
                                            p['description'],
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondaryOf(context),
                                            ),
                                          ),
                                        Text(
                                          required_ ? 'Required' : 'Optional',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: required_ ? Colors.deepPurple : AppTheme.textSecondaryOf(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _delete(p['id']),
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


class _SponsorUploadSheet extends StatefulWidget {
  final int eventId;
  final int categoryId;
  final String categoryName;

  const _SponsorUploadSheet({
    required this.eventId,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<_SponsorUploadSheet> createState() => _SponsorUploadSheetState();
}

class _SponsorUploadSheetState extends State<_SponsorUploadSheet> {
  List<Map<String, dynamic>> _prereqs = [];
  List<Map<String, dynamic>> _bids = [];
  Map<int, List<Map<String, dynamic>>> _uploadsByBid = {};
  bool _loading = true;
  int? _selectedBidId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();
      final prereqs = await api.listPrerequisites(widget.eventId, widget.categoryId);
      final allBids = await api.listBids(widget.eventId, widget.categoryId);
      final myBids = allBids
          .cast<Map<String, dynamic>>()
          .where((b) => b['sponsor_user_id'] != null)
          .toList();

      if (mounted) {
        setState(() {
          _prereqs = prereqs.cast<Map<String, dynamic>>();
          _bids = myBids;
          if (_bids.isNotEmpty && _selectedBidId == null) {
            _selectedBidId = _bids.first['id'];
          }
          _loading = false;
        });
      }
      if (_selectedBidId != null) await _loadUploads(_selectedBidId!);
    } catch (e) {
      if (mounted) {
        AppToast.error(context, ApiService.extractError(e));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadUploads(int bidId) async {
    try {
      final api = context.read<ApiService>();
      final uploads = await api.listBidPrerequisiteUploads(bidId);
      if (mounted) {
        setState(() {
          _uploadsByBid[bidId] = uploads.cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {}
  }

  Future<void> _uploadFile(int prereqId) async {
    if (_selectedBidId == null) return;
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    try {
      final api = context.read<ApiService>();
      await api.uploadPrerequisiteDocument(
        _selectedBidId!,
        prereqId,
        file.path!,
        file.name,
      );
      if (mounted) AppToast.success(context, 'Document uploaded');
      _loadUploads(_selectedBidId!);
    } catch (e) {
      if (mounted) AppToast.error(context, ApiService.extractError(e));
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved': return AppTheme.successColor;
      case 'rejected': return AppTheme.errorColor;
      default: return AppTheme.warningColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploads = _selectedBidId != null ? (_uploadsByBid[_selectedBidId!] ?? []) : <Map<String, dynamic>>[];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
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
            Text(
              'Upload Documents: ${widget.categoryName}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            if (_bids.length > 1) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _bids.map((b) {
                    final isSelected = _selectedBidId == b['id'];
                    final cents = b['amount_cents'] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('Bid \$${(cents / 100).toStringAsFixed(2)}'),
                        selected: isSelected,
                        onSelected: (sel) {
                          if (sel) {
                            setState(() => _selectedBidId = b['id']);
                            _loadUploads(b['id']);
                          }
                        },
                        selectedColor: AppTheme.accentColor,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppTheme.textPrimaryOf(context),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _prereqs.isEmpty
                      ? Center(
                          child: Text(
                            'No requirements for this category.',
                            style: TextStyle(color: AppTheme.textSecondaryOf(context)),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollCtrl,
                          itemCount: _prereqs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final prereq = _prereqs[i];
                            final upload = uploads.cast<Map<String, dynamic>>().where(
                              (u) => u['prerequisite_id'] == prereq['id'],
                            ).toList();
                            final hasUpload = upload.isNotEmpty;
                            final uploadStatus = hasUpload ? (upload.first['status'] ?? 'pending') : null;
                            final isRequired = prereq['is_required'] == true;

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceOf(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.dividerOf(context)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isRequired ? Icons.star_rounded : Icons.star_border_rounded,
                                        size: 16,
                                        color: isRequired ? Colors.deepPurple : AppTheme.textSecondaryOf(context),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          prereq['name'] ?? '',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimaryOf(context),
                                          ),
                                        ),
                                      ),
                                      if (hasUpload)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _statusColor(uploadStatus!).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            uploadStatus.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: _statusColor(uploadStatus),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (prereq['description'] != null && (prereq['description'] as String).isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      prereq['description'],
                                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                                    ),
                                  ],
                                  if (hasUpload && upload.first['reviewer_note'] != null &&
                                      (upload.first['reviewer_note'] as String).isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Note: ${upload.first['reviewer_note']}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                        color: AppTheme.textSecondaryOf(context),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 34,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _uploadFile(prereq['id']),
                                      icon: const Icon(Icons.upload_rounded, size: 16),
                                      label: Text(
                                        hasUpload ? 'Re-upload' : 'Upload',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.deepPurple,
                                        side: const BorderSide(color: Colors.deepPurple),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
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
