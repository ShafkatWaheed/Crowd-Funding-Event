import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/event.dart';
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
  EventStatus? _eventStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([
        api.getSponsorshipCategories(widget.eventId),
        api.getEvent(widget.eventId),
      ]);
      final data = results[0] as List;
      final eventData = results[1] as Map<String, dynamic>;
      final statusStr = eventData['status'] as String? ?? 'draft';
      if (mounted) {
        setState(() {
          _categories =
              data.map((j) => SponsorshipCategory.fromJson(j as Map<String, dynamic>)).toList();
          _eventStatus = EventStatus.values.firstWhere(
            (e) => e.name == statusStr,
            orElse: () => EventStatus.draft,
          );
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
    final result = await showDialog<_BidDialogResult>(
      context: context,
      builder: (ctx) => _PlaceBidDialog(
        eventId: widget.eventId,
        category: cat,
      ),
    );

    if (result == null || !mounted) return;

    try {
      final api = context.read<ApiService>();
      await api.placeBid(widget.eventId, cat.id, {
        'amount_cents': result.amountCents,
        if (result.proposalText != null)
          'proposal_text': result.proposalText,
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
    final locked = _eventStatus == EventStatus.live ||
        _eventStatus == EventStatus.completed ||
        _eventStatus == EventStatus.cancelled;
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
        readOnly: locked,
      ),
    );
  }

  Future<void> _showAddSponsorshipDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final spotsCtrl = TextEditingController(text: '1');
    final minBidCtrl = TextEditingController(text: '100.00');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Sponsorship'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Sponsorship Name *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: spotsCtrl,
                decoration: const InputDecoration(labelText: 'Total Spots *'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: minBidCtrl,
                decoration: const InputDecoration(
                  labelText: 'Minimum Bid (\$) *',
                  hintText: '100.00',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );

    if (confirmed != true) return;
    final name = nameCtrl.text.trim();
    final spots = int.tryParse(spotsCtrl.text.trim());
    final minBid = double.tryParse(minBidCtrl.text.trim());
    if (name.isEmpty || spots == null || spots < 1 || minBid == null || minBid <= 0) {
      if (mounted) AppToast.error(context, 'Please fill in all required fields correctly.');
      return;
    }

    try {
      final api = context.read<ApiService>();
      await api.createSponsorshipCategory(widget.eventId, {
        'name': name,
        'description': descCtrl.text.trim(),
        'total_spots': spots,
        'min_bid_cents': (minBid * 100).round(),
      });
      if (mounted) AppToast.success(context, 'Sponsorship created');
      _load();
    } catch (e) {
      if (mounted) AppToast.error(context, ApiService.extractError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isSponsor = user?.isSponsor ?? false;
    final isOrganizerOrAdmin = user != null && (user.isOrganizer || user.isAdmin);
    final canCreate = isOrganizerOrAdmin &&
        _eventStatus != null &&
        _eventStatus != EventStatus.live &&
        _eventStatus != EventStatus.completed &&
        _eventStatus != EventStatus.cancelled;

    return Scaffold(
      appBar: AppBar(title: const Text('Sponsorships')),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _showAddSponsorshipDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Sponsorship'),
              backgroundColor: context.sponsorAccent,
              foregroundColor: Colors.white,
            )
          : null,
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
                            'No sponsorships yet.',
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
                            if (cat.bidAmounts.length >= 2) ...[
                              const SizedBox(height: 12),
                              _BidLeaderboard(bidAmounts: cat.bidAmounts),
                            ],
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
                            if (isSponsor && cat.myBids.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              ...cat.myBids.map((b) => _MyBidActions(
                                bid: b,
                                eventId: widget.eventId,
                                categoryId: cat.id,
                                onDone: _load,
                              )),
                            ],
                            if (isSponsor && cat.prereqCount > 0) ...[
                              const SizedBox(height: 10),
                              _CategoryRequirements(
                                eventId: widget.eventId,
                                categoryId: cat.id,
                                categoryName: cat.name,
                                myBids: cat.myBids,
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
                                        foregroundColor: context.ticketAccent,
                                        side: BorderSide(color: context.ticketAccent),
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
                                      foregroundColor: context.sponsorAccent,
                                      side: BorderSide(color: context.sponsorAccent),
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
  final bool readOnly;

  const _PrerequisiteSheet({
    required this.eventId,
    required this.categoryId,
    required this.categoryName,
    this.readOnly = false,
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

    try {
      final api = context.read<ApiService>();
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
                                    color: required_ ? context.sponsorAccent : AppTheme.textSecondaryOf(context),
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
                                            if (p['requires_document'] == true) ...[
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
                                        color: isRequired ? context.sponsorAccent : AppTheme.textSecondaryOf(context),
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
                                        foregroundColor: context.sponsorAccent,
                                        side: BorderSide(color: context.sponsorAccent),
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


class _MyBidActions extends StatefulWidget {
  final Map<String, dynamic> bid;
  final int eventId;
  final int categoryId;
  final VoidCallback onDone;

  const _MyBidActions({
    required this.bid,
    required this.eventId,
    required this.categoryId,
    required this.onDone,
  });

  @override
  State<_MyBidActions> createState() => _MyBidActionsState();
}

class _MyBidActionsState extends State<_MyBidActions> {
  bool _busy = false;

  String get _status => widget.bid['status'] ?? '';
  int get _bidId => widget.bid['id'];
  int get _amountCents => widget.bid['amount_cents'] ?? 0;
  String get _amountDisplay => '\$${(_amountCents / 100).toStringAsFixed(2)}';

  Future<void> _withdraw() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw Bid?'),
        content: Text('Withdraw your $_amountDisplay bid? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final api = context.read<ApiService>();
      await api.withdrawBid(widget.eventId, widget.categoryId, _bidId);
      if (mounted) AppToast.success(context, 'Bid withdrawn');
      widget.onDone();
    } catch (e) {
      if (mounted) AppToast.error(context, ApiService.extractError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pay for Sponsorship'),
        content: Text('Confirm payment of $_amountDisplay for this sponsorship?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Pay Now'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final api = context.read<ApiService>();
      await api.payBid(widget.eventId, widget.categoryId, _bidId);
      if (mounted) AppToast.success(context, 'Payment successful!');
      widget.onDone();
    } catch (e) {
      if (mounted) AppToast.error(context, ApiService.extractError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color get _statusColor => switch (_status) {
    'accepted' => AppTheme.successColor,
    'rejected' => AppTheme.errorColor,
    'paid' => AppTheme.accentColor,
    _ => AppTheme.warningColor,
  };

  String get _statusLabel => switch (_status) {
    'pending' => 'Under Review',
    'accepted' => 'Accepted',
    'paid' => 'Paid',
    'rejected' => 'Rejected',
    _ => _status,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _statusColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_amountDisplay, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimaryOf(context))),
                const SizedBox(height: 2),
                Text(_statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor)),
              ],
            ),
          ),
          if (_busy)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            if (_status == 'pending')
              SizedBox(
                height: 32,
                child: OutlinedButton(
                  onPressed: _withdraw,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    side: const BorderSide(color: AppTheme.errorColor),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Withdraw'),
                ),
              ),
            if (_status == 'accepted')
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: _pay,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Pay Now'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}


class _BidLeaderboard extends StatelessWidget {
  final List<int> bidAmounts;

  const _BidLeaderboard({required this.bidAmounts});

  @override
  Widget build(BuildContext context) {
    final sorted = List<int>.from(bidAmounts)..sort((a, b) => b.compareTo(a));
    final top = sorted.take(5).toList();
    final maxAmount = top.first;

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
              const Icon(Icons.emoji_events_rounded, size: 16, color: Color(0xFFD4A017)),
              const SizedBox(width: 6),
              Text(
                'Top Bids',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondaryOf(context),
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Text(
                '${bidAmounts.length} total',
                style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryOf(context)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(top.length, (i) {
            final cents = top[i];
            final amount = '\$${(cents / 100).toStringAsFixed(2)}';
            final fraction = maxAmount > 0 ? cents / maxAmount : 0.0;

            final (IconData? icon, Color color) = switch (i) {
              0 => (Icons.emoji_events_rounded, const Color(0xFFD4A017)),
              1 => (Icons.emoji_events_rounded, const Color(0xFF9E9E9E)),
              2 => (Icons.emoji_events_rounded, const Color(0xFFCD7F32)),
              _ => (null, AppTheme.textSecondaryOf(context)),
            };

            return Padding(
              padding: EdgeInsets.only(bottom: i < top.length - 1 ? 6 : 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: icon != null
                        ? Icon(icon, size: 16, color: color)
                        : Text(
                            '#${i + 1}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    amount,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w600,
                      color: i == 0
                          ? AppTheme.textPrimaryOf(context)
                          : AppTheme.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 6,
                        backgroundColor: AppTheme.dividerOf(context),
                        valueColor: AlwaysStoppedAnimation(
                          i == 0
                              ? const Color(0xFFD4A017)
                              : i == 1
                                  ? const Color(0xFF9E9E9E)
                                  : i == 2
                                      ? const Color(0xFFCD7F32)
                                      : AppTheme.accentColor.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}


class _CategoryRequirements extends StatefulWidget {
  final int eventId;
  final int categoryId;
  final String categoryName;
  final List<Map<String, dynamic>> myBids;

  const _CategoryRequirements({
    required this.eventId,
    required this.categoryId,
    required this.categoryName,
    required this.myBids,
  });

  @override
  State<_CategoryRequirements> createState() => _CategoryRequirementsState();
}

class _CategoryRequirementsState extends State<_CategoryRequirements> {
  bool _expanded = false;
  bool _loading = false;
  List<Map<String, dynamic>> _prereqs = [];
  Map<int, Map<String, dynamic>> _uploads = {};
  final Map<int, bool> _uploading = {};

  bool get _hasBid => widget.myBids.isNotEmpty;

  Future<void> _loadData() async {
    if (_prereqs.isNotEmpty) return;
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final prereqs = await api.listPrerequisites(widget.eventId, widget.categoryId);

      Map<int, Map<String, dynamic>> uploads = {};
      if (widget.myBids.isNotEmpty) {
        final latestBidId = widget.myBids.first['id'] as int;
        final bidUploads = await api.listBidPrerequisiteUploads(latestBidId);
        for (final u in bidUploads.cast<Map<String, dynamic>>()) {
          uploads[u['prerequisite_id'] as int] = u;
        }
      }

      if (mounted) {
        setState(() {
          _prereqs = prereqs.cast<Map<String, dynamic>>();
          _uploads = uploads;
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

  Future<void> _uploadFile(int prereqId) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null && file.path == null) return;

    setState(() => _uploading[prereqId] = true);
    try {
      final api = context.read<ApiService>();
      final resp = await api.uploadCategoryPrerequisite(
        widget.eventId, widget.categoryId, prereqId,
        filePath: file.path,
        fileName: file.name,
        fileBytes: file.bytes,
      );
      if (mounted) {
        setState(() {
          _uploads[prereqId] = {
            'id': resp['id'],
            'file_url': resp['file_url'],
            'status': resp['status'],
            'prerequisite_id': prereqId,
          };
          _uploading[prereqId] = false;
        });
        AppToast.success(context, 'Document uploaded');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, ApiService.extractError(e));
        setState(() => _uploading[prereqId] = false);
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved': return AppTheme.successColor;
      case 'rejected': return AppTheme.errorColor;
      default: return AppTheme.warningColor;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved': return 'Approved';
      case 'rejected': return 'Rejected';
      default: return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() => _expanded = !_expanded);
              if (_expanded) _loadData();
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.checklist_rounded, size: 18, color: context.sponsorAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Requirements',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 20,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: AppTheme.dividerOf(context)),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else if (_prereqs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No requirements.', style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13)),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Column(
                  children: [
                    if (!_hasBid && _prereqs.any((p) => p['requires_document'] == true))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.warningColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Place a bid first to upload documents.',
                                style: TextStyle(fontSize: 11, color: AppTheme.warningColor, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ..._prereqs.map((p) {
                    final prereqId = p['id'] as int;
                    final name = p['name'] as String? ?? '';
                    final desc = p['description'] as String? ?? '';
                    final requiresDoc = p['requires_document'] == true;
                    final upload = _uploads[prereqId];
                    final hasUpload = upload != null;
                    final isUploading = _uploading[prereqId] == true;
                    final status = upload?['status'] ?? 'pending';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              hasUpload ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                              size: 16,
                              color: hasUpload ? _statusColor(status) : AppTheme.textSecondaryOf(context),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textPrimaryOf(context),
                                  ),
                                ),
                                if (desc.isNotEmpty)
                                  Text(desc, style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
                                if (hasUpload)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Row(
                                      children: [
                                        Icon(Icons.attach_file_rounded, size: 12, color: _statusColor(status)),
                                        const SizedBox(width: 3),
                                        Text(
                                          'File attached',
                                          style: TextStyle(fontSize: 11, color: _statusColor(status), fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: _statusColor(status).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _statusLabel(status),
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _statusColor(status)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (_hasBid && requiresDoc) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 30,
                              child: isUploading
                                  ? const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 1.5)),
                                    )
                                  : Material(
                                      color: context.sponsorAccent.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        onTap: () => _uploadFile(prereqId),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                hasUpload ? Icons.sync_rounded : Icons.upload_file_rounded,
                                                size: 16,
                                                color: context.sponsorAccent,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                hasUpload ? 'Replace' : 'Upload',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: context.sponsorAccent,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}


class _BidDialogResult {
  final int amountCents;
  final String? proposalText;

  _BidDialogResult({
    required this.amountCents,
    this.proposalText,
  });
}


class _PlaceBidDialog extends StatefulWidget {
  final int eventId;
  final SponsorshipCategory category;

  const _PlaceBidDialog({
    required this.eventId,
    required this.category,
  });

  @override
  State<_PlaceBidDialog> createState() => _PlaceBidDialogState();
}

class _PlaceBidDialogState extends State<_PlaceBidDialog> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _proposalCtrl;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: (widget.category.minBidCents / 100).toStringAsFixed(2),
    );
    _proposalCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _proposalCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    return amount > 0;
  }

  void _submit() {
    final amount = ((double.tryParse(_amountCtrl.text) ?? 0) * 100).round();
    final proposal = _proposalCtrl.text.trim();
    Navigator.pop(
      context,
      _BidDialogResult(
        amountCents: amount,
        proposalText: proposal.isNotEmpty ? proposal : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 480,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bid on "${cat.name}"',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Min bid: ${cat.minBidDisplay}  •  '
                    '${cat.availableSpots} spot${cat.availableSpots == 1 ? "" : "s"} left',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                  ),
                  if (cat.bidCount > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${cat.bidCount} bid${cat.bidCount == 1 ? "" : "s"} placed'
                      '${cat.myBidCount > 0 ? "  •  ${cat.myBidCount} by you" : ""}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _amountCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Bid Amount (\$)',
                        prefixText: '\$ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _proposalCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Proposal (optional)',
                        hintText: 'Why you want to sponsor...',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _canSubmit ? _submit : null,
                    child: const Text('Place Bid'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
