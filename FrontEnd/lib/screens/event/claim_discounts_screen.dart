import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/shimmer_loaders.dart';

/// Customer-facing page where they can search, view, and claim
/// non-auto-apply discounts that the organizer added to an event.
class ClaimDiscountsScreen extends StatefulWidget {
  final int eventId;
  const ClaimDiscountsScreen({super.key, required this.eventId});

  @override
  State<ClaimDiscountsScreen> createState() => _ClaimDiscountsScreenState();
}

class _ClaimDiscountsScreenState extends State<ClaimDiscountsScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _discounts = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().user;
    if (user == null || !(user.isCustomer || user.isOrganizer || user.isAdmin)) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await _api.getClaimableDiscounts(widget.eventId);
      setState(() {
        _discounts = data.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _claim(int linkId) async {
    try {
      await _api.claimDiscount(widget.eventId, linkId);
      await _load();
      if (mounted) {
        AppToast.success(context, 'Discount claimed!');
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to claim discount');
      }
    }
  }

  Future<void> _unclaim(int linkId) async {
    try {
      await _api.unclaimDiscount(widget.eventId, linkId);
      await _load();
      if (mounted) {
        AppToast.success(context, 'Discount removed');
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to remove discount');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _discounts.where((d) {
      if (_search.isEmpty) return true;
      final name = (d['name'] ?? '').toString().toLowerCase();
      final type = (d['discount_type'] ?? '').toString().toLowerCase();
      return name.contains(_search) || type.contains(_search);
    }).toList();

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
        title: const Text('Event Discounts'),
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
            : Column(
                children: [
                  // Search
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search available discounts…',
                        hintStyle: TextStyle(color: AppTheme.textSecondaryOf(context)),
                        prefixIcon: Icon(Icons.search, size: 20, color: AppTheme.textSecondaryOf(context)),
                        isDense: true,
                        filled: true,
                        fillColor: AppTheme.inputFillOf(context),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.dividerOf(context)),
                        ),
                      ),
                      onChanged: (v) => setState(() => _search = v.toLowerCase()),
                    ),
                  ),
                  // Info banner
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.sponsorSurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: context.sponsorAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Claim discounts here. Once claimed, they apply automatically when you purchase a ticket.',
                              style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // List
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.discount_outlined, size: 48, color: AppTheme.textSecondaryOf(context)),
                                const SizedBox(height: 8),
                                Text(
                                  _discounts.isEmpty ? 'No claimable discounts' : 'No matches',
                                  style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final d = filtered[i];
                              final claimed = d['claimed'] == true;
                              final linkId = d['link_id'] as int;
                              return Container(
                                decoration: BoxDecoration(
                                  color: claimed
                                      ? AppTheme.successSurfaceOf(context)
                                      : AppTheme.cardOf(context),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: claimed
                                        ? AppTheme.successColor.withValues(alpha: 0.4)
                                        : AppTheme.dividerOf(context),
                                  ),
                                ),
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Icon(
                                      claimed ? Icons.check_circle : Icons.discount_outlined,
                                      color: claimed ? AppTheme.successColor : context.sponsorAccent,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            d['name'] ?? '',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: AppTheme.textPrimaryOf(context),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _descLine(d),
                                            style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (claimed)
                                      OutlinedButton(
                                        onPressed: () => _unclaim(linkId),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.errorColor,
                                          side: BorderSide(color: AppTheme.errorColor, width: 0.5),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          minimumSize: Size.zero,
                                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                        ),
                                        child: const Text('Remove'),
                                      )
                                    else
                                      ElevatedButton(
                                        onPressed: () => _claim(linkId),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primaryColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                          minimumSize: Size.zero,
                                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                        ),
                                        child: const Text('Claim'),
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

  String _descLine(Map<String, dynamic> d) {
    final type = d['discount_type'] ?? '';
    final val = d['value'] ?? 0;
    final target = d['target'] ?? 'all';
    if (type == 'ticket_percent') {
      return '$val% off ticket price · for $target';
    } else {
      return '$val% of pledge amount · for $target';
    }
  }
}
