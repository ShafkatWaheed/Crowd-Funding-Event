import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/sponsor.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/shimmer_loaders.dart';
import '../profile/sponsor_profile_screen.dart';

class BidManagementScreen extends StatefulWidget {
  final int eventId;
  final int categoryId;
  final String? categoryName;

  const BidManagementScreen({
    super.key,
    required this.eventId,
    required this.categoryId,
    this.categoryName,
  });

  @override
  State<BidManagementScreen> createState() => _BidManagementScreenState();
}

class _BidManagementScreenState extends State<BidManagementScreen> {
  List<SponsorBid> _bids = [];
  bool _loading = true;
  String _search = '';
  String? _statusFilter;

  static const _filterOptions = ['pending', 'accepted', 'rejected', 'paid'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.listBids(widget.eventId, widget.categoryId);
      if (mounted) {
        setState(() {
          _bids = data.map((j) => SponsorBid.fromJson(j)).toList();
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

  List<SponsorBid> get _filtered {
    return _bids.where((bid) {
      if (_statusFilter != null && bid.status != _statusFilter) return false;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        final name = bid.sponsorProfile?.companyName.toLowerCase() ?? '';
        final profession = bid.sponsorProfile?.profession.toLowerCase() ?? '';
        final proposal = bid.proposalText?.toLowerCase() ?? '';
        return name.contains(q) ||
            profession.contains(q) ||
            proposal.contains(q);
      }
      return true;
    }).toList();
  }

  Future<void> _accept(SponsorBid bid) async {
    try {
      final api = context.read<ApiService>();
      await api.acceptBid(widget.eventId, widget.categoryId, bid.id);
      if (mounted) AppToast.success(context, 'Bid accepted');
      _load();
    } catch (e) {
      if (mounted) AppToast.error(context, ApiService.extractError(e));
    }
  }

  Future<void> _reject(SponsorBid bid) async {
    try {
      final api = context.read<ApiService>();
      await api.rejectBid(widget.eventId, widget.categoryId, bid.id);
      if (mounted) AppToast.success(context, 'Bid rejected');
      _load();
    } catch (e) {
      if (mounted) AppToast.error(context, ApiService.extractError(e));
    }
  }

  Future<void> _refund(SponsorBid bid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refund Sponsorship?'),
        content: Text('Refund ${bid.amountDisplay} to the sponsor? This will revoke their sponsorship.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Refund'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final api = context.read<ApiService>();
      await api.refundBid(widget.eventId, widget.categoryId, bid.id);
      if (mounted) AppToast.success(context, 'Bid refunded');
      _load();
    } catch (e) {
      if (mounted) AppToast.error(context, ApiService.extractError(e));
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return AppTheme.successColor;
      case 'rejected':
      case 'withdrawn':
        return AppTheme.errorColor;
      case 'paid':
        return AppTheme.accentColor;
      default:
        return AppTheme.warningColor;
    }
  }

  String _statusLabel(String status) {
    if (status == 'pending') return 'Under Review';
    return status[0].toUpperCase() + status.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final counts = <String, int>{};
    for (final b in _bids) {
      counts[b.status] = (counts[b.status] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName != null
            ? 'Bids: ${widget.categoryName}'
            : 'Bid Management'),
      ),
      body: _loading
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List.generate(4, (_) => const ShimmerListTile()),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search sponsors…',
                      prefixIcon: Icon(Icons.search,
                          color: AppTheme.textSecondaryOf(context), size: 22),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: AppTheme.inputFillOf(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: _filterOptions.map((s) {
                      final isActive = _statusFilter == s;
                      final color = _statusColor(s);
                      final count = counts[s] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${_statusLabel(s)} ($count)'),
                          selected: isActive,
                          onSelected: (selected) {
                            setState(() {
                              _statusFilter = selected ? s : null;
                            });
                          },
                          selectedColor: color,
                          backgroundColor: AppTheme.cardOf(context),
                          side: BorderSide(
                            color: isActive
                                ? color
                                : AppTheme.dividerOf(context),
                          ),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? Colors.white
                                : AppTheme.textPrimaryOf(context),
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            _bids.isEmpty
                                ? 'No bids yet.'
                                : 'No bids match your filters.',
                            style: TextStyle(
                                color: AppTheme.textSecondaryOf(context)),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final bid = filtered[index];
                              return _BidCard(
                                bid: bid,
                                eventId: widget.eventId,
                                categoryId: widget.categoryId,
                                statusColor: _statusColor(bid.status),
                                onAccept:
                                    bid.isPending ? () => _accept(bid) : null,
                                onReject:
                                    bid.isPending ? () => _reject(bid) : null,
                                onRefund:
                                    bid.isPaid ? () => _refund(bid) : null,
                                onReload: _load,
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

class _BidCard extends StatefulWidget {
  final SponsorBid bid;
  final int eventId;
  final int categoryId;
  final Color statusColor;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onRefund;
  final VoidCallback? onReload;

  const _BidCard({
    required this.bid,
    required this.eventId,
    required this.categoryId,
    required this.statusColor,
    this.onAccept,
    this.onReject,
    this.onRefund,
    this.onReload,
  });

  @override
  State<_BidCard> createState() => _BidCardState();
}

class _BidCardState extends State<_BidCard> {
  bool _docsExpanded = false;
  List<Map<String, dynamic>>? _uploads;
  List<Map<String, dynamic>>? _prereqs;
  bool _loadingDocs = false;

  Future<void> _loadDocs() async {
    if (_loadingDocs) return;
    setState(() => _loadingDocs = true);
    try {
      final api = context.read<ApiService>();
      final uploads = await api.listBidPrerequisiteUploads(widget.bid.id);
      final prereqs = await api.listPrerequisites(widget.eventId, widget.categoryId);
      if (mounted) {
        setState(() {
          _uploads = uploads.cast<Map<String, dynamic>>();
          _prereqs = prereqs.cast<Map<String, dynamic>>();
          _loadingDocs = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingDocs = false);
    }
  }

  void _toggleDocs() {
    setState(() => _docsExpanded = !_docsExpanded);
    if (_docsExpanded && _uploads == null) _loadDocs();
  }

  Future<void> _reviewUpload(int prereqId, String newStatus) async {
    try {
      final api = context.read<ApiService>();
      await api.reviewPrerequisiteUpload(widget.bid.id, prereqId, status: newStatus);
      if (mounted) AppToast.success(context, 'Document $newStatus');
      _loadDocs();
    } catch (e) {
      if (mounted) AppToast.error(context, ApiService.extractError(e));
    }
  }

  Color _uploadStatusColor(String status) {
    switch (status) {
      case 'approved': return AppTheme.successColor;
      case 'rejected': return AppTheme.errorColor;
      default: return AppTheme.warningColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bid = widget.bid;
    final profile = bid.sponsorProfile;
    final statusColor = widget.statusColor;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SponsorProfileScreen(
                        userId: bid.sponsorUserId,
                        isOrganizerView: true,
                      ),
                    )),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              AppTheme.accentColor.withValues(alpha: 0.1),
                          child: Text(
                            profile?.companyName.substring(0, 1).toUpperCase() ?? '?',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile?.companyName ?? 'Unknown Sponsor',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.accentColor,
                                ),
                              ),
                              if (profile?.profession != null)
                                Text(
                                  profile!.profession,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondaryOf(context)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    bid.status == 'pending'
                        ? 'UNDER REVIEW'
                        : bid.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.monetization_on,
                    size: 16, color: AppTheme.successColor),
                const SizedBox(width: 4),
                Text(bid.amountDisplay,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.textPrimaryOf(context))),
              ],
            ),
            if (bid.proposalText != null &&
                bid.proposalText!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.inputFillOf(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  bid.proposalText!,
                  style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondaryOf(context)),
                ),
              ),
            ],
            const SizedBox(height: 8),
            InkWell(
              onTap: _toggleDocs,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.checklist_rounded, size: 16, color: context.sponsorAccent),
                    const SizedBox(width: 6),
                    Text('Prerequisites',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.sponsorAccent)),
                    const Spacer(),
                    Icon(
                      _docsExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                  ],
                ),
              ),
            ),
            if (_docsExpanded) ...[
              if (_loadingDocs)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                )
              else if (_prereqs != null && _prereqs!.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('No requirements for this category.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
                )
              else if (_prereqs != null)
                ..._prereqs!.map((prereq) {
                  final upload = _uploads?.firstWhere(
                    (u) => u['prerequisite_id'] == prereq['id'],
                    orElse: () => <String, dynamic>{},
                  );
                  final hasUpload = upload != null && upload.isNotEmpty;
                  final uploadStatus = hasUpload ? (upload['status'] ?? 'pending') : null;
                  final isRequired = prereq['is_required'] == true;

                  return Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceOf(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.dividerOf(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isRequired ? Icons.star_rounded : Icons.star_border_rounded,
                              size: 14,
                              color: isRequired ? context.sponsorAccent : AppTheme.textSecondaryOf(context),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                prereq['name'] ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimaryOf(context),
                                ),
                              ),
                            ),
                            if (hasUpload)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _uploadStatusColor(uploadStatus!).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  uploadStatus.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _uploadStatusColor(uploadStatus),
                                  ),
                                ),
                              )
                            else
                              Text('Not uploaded',
                                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
                          ],
                        ),
                        if (hasUpload && uploadStatus == 'pending') ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 30,
                                  child: OutlinedButton(
                                    onPressed: () => _reviewUpload(prereq['id'], 'rejected'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.errorColor,
                                      side: const BorderSide(color: AppTheme.errorColor),
                                      padding: EdgeInsets.zero,
                                      textStyle: const TextStyle(fontSize: 12),
                                    ),
                                    child: const Text('Reject'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SizedBox(
                                  height: 30,
                                  child: ElevatedButton(
                                    onPressed: () => _reviewUpload(prereq['id'], 'approved'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.successColor,
                                      padding: EdgeInsets.zero,
                                      textStyle: const TextStyle(fontSize: 12),
                                    ),
                                    child: const Text('Approve'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (hasUpload && upload['reviewer_note'] != null && (upload['reviewer_note'] as String).isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Note: ${upload['reviewer_note']}',
                              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textSecondaryOf(context))),
                        ],
                      ],
                    ),
                  );
                }),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final name = widget.bid.sponsorProfile?.companyName ?? 'Sponsor';
                  final writable = widget.bid.status == 'pending' ||
                      widget.bid.status == 'accepted' ||
                      widget.bid.status == 'paid';
                  context.push(
                    '/chat/bid/${widget.bid.id}?name=${Uri.encodeComponent(name)}&writable=$writable',
                  );
                },
                icon: const Icon(Icons.chat_outlined, size: 18),
                label: const Text('Chat'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentColor,
                  side: const BorderSide(color: AppTheme.accentColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            if (widget.onAccept != null || widget.onReject != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (widget.onReject != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                          side: const BorderSide(color: AppTheme.errorColor),
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                  if (widget.onAccept != null && widget.onReject != null)
                    const SizedBox(width: 12),
                  if (widget.onAccept != null)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: widget.onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                        ),
                        child: const Text('Accept'),
                      ),
                    ),
                ],
              ),
            ],
            if (widget.onRefund != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.onRefund,
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: const Text('Refund Sponsor'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    side: BorderSide(color: AppTheme.errorColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
