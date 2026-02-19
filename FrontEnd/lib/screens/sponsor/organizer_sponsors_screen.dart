import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../services/api_service.dart';

class OrganizerSponsorsScreen extends StatefulWidget {
  const OrganizerSponsorsScreen({super.key});

  @override
  State<OrganizerSponsorsScreen> createState() =>
      _OrganizerSponsorsScreenState();
}

class _OrganizerSponsorsScreenState extends State<OrganizerSponsorsScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _sponsors = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.getOrganizerSponsors();
      if (!mounted) return;
      setState(() {
        _sponsors = data.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiService.extractError(e))),
      );
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _sponsors;
    final q = _search.toLowerCase();
    return _sponsors.where((s) {
      final name = (s['company_name'] ?? '').toString().toLowerCase();
      final contact = (s['contact_name'] ?? '').toString().toLowerCase();
      return name.contains(q) || contact.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: AppTheme.surfaceOf(context),
      appBar: AppBar(
        title: const Text('My Sponsors'),
        backgroundColor: AppTheme.cardOf(context),
        foregroundColor: AppTheme.textPrimaryOf(context),
        elevation: 0,
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
                      hintText: 'Search sponsors\u2026',
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Text(
                        '${filtered.length} sponsor${filtered.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.handshake_outlined,
                                  size: 56,
                                  color: AppTheme.textSecondaryOf(context)
                                      .withValues(alpha: 0.4)),
                              const SizedBox(height: 12),
                              Text(
                                _sponsors.isEmpty
                                    ? 'No sponsors yet'
                                    : 'No sponsors match your search',
                                style: TextStyle(
                                    color:
                                        AppTheme.textSecondaryOf(context)),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final s = filtered[i];
                              return _SponsorCard(
                                sponsor: s,
                                onTap: () => context.push(
                                  '/manage/sponsors/${s['sponsor_user_id']}/events',
                                  extra: s['company_name'] ?? 'Sponsor',
                                ),
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

class _SponsorCard extends StatelessWidget {
  final Map<String, dynamic> sponsor;
  final VoidCallback onTap;

  const _SponsorCard({required this.sponsor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = sponsor['company_name'] ?? 'Unknown';
    final contact = sponsor['contact_name'] ?? '';
    final logo = sponsor['logo_url'];
    final totalBids = sponsor['total_bids'] ?? 0;
    final totalCents = sponsor['total_amount_cents'] ?? 0;
    final amount = '\$${(totalCents / 100).toStringAsFixed(2)}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: logo != null && logo.toString().isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(logo, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                              Icons.business_rounded,
                              color: AppTheme.accentColor,
                              size: 26)),
                    )
                  : Icon(Icons.business_rounded,
                      color: AppTheme.accentColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryOf(context))),
                  if (contact.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(contact,
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondaryOf(context))),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _chip(context, '$totalBids bid${totalBids == 1 ? '' : 's'}',
                          AppTheme.accentColor),
                      const SizedBox(width: 8),
                      _chip(context, amount, AppTheme.secondaryColor),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppTheme.textSecondaryOf(context), size: 24),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
