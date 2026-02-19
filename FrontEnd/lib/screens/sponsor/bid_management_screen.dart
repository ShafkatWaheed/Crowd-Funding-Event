import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/sponsor.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';

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
          ? const Center(child: CircularProgressIndicator())
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
                                statusColor: _statusColor(bid.status),
                                onAccept:
                                    bid.isPending ? () => _accept(bid) : null,
                                onReject:
                                    bid.isPending ? () => _reject(bid) : null,
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

class _BidCard extends StatelessWidget {
  final SponsorBid bid;
  final Color statusColor;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const _BidCard({
    required this.bid,
    required this.statusColor,
    this.onAccept,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final profile = bid.sponsorProfile;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        style: const TextStyle(fontWeight: FontWeight.w600),
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
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            if (bid.proposalText != null &&
                bid.proposalText!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.06),
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
            if (onAccept != null || onReject != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onReject != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                          side: const BorderSide(color: AppTheme.errorColor),
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                  if (onAccept != null && onReject != null)
                    const SizedBox(width: 12),
                  if (onAccept != null)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                        ),
                        child: const Text('Accept'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
