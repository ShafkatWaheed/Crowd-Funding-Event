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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName != null
            ? 'Bids: ${widget.categoryName}'
            : 'Bid Management'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bids.isEmpty
              ? Center(
                  child: Text('No bids yet.',
                      style: TextStyle(
                          color: AppTheme.textSecondaryOf(context))),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bids.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final bid = _bids[index];
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
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        profile?.companyName ?? 'Unknown Sponsor',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      if (profile?.profession != null)
                                        Text(
                                          profile!.profession,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  AppTheme.textSecondaryOf(
                                                      context)),
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _statusColor(bid.status)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    bid.status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _statusColor(bid.status),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.monetization_on,
                                    size: 16,
                                    color: AppTheme.successColor),
                                const SizedBox(width: 4),
                                Text(bid.amountDisplay,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
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
                                      color:
                                          AppTheme.textSecondaryOf(context)),
                                ),
                              ),
                            ],
                            if (bid.isPending) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _reject(bid),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.errorColor,
                                        side: const BorderSide(
                                            color: AppTheme.errorColor),
                                      ),
                                      child: const Text('Reject'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _accept(bid),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppTheme.successColor,
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
                  },
                ),
    );
  }
}
