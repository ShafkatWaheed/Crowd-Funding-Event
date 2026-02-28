import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../db/app_database.dart';
import '../../models/sponsor.dart';
import '../../services/api_service.dart';
import '../../services/sync_service.dart';
import '../../widgets/shimmer_loaders.dart';
import 'sponsor_ticket/sponsor_ticket_card.dart';
import 'sponsor_ticket/sponsor_ticket_receipt_page.dart';

class SponsorTicketScreen extends StatefulWidget {
  const SponsorTicketScreen({super.key});

  @override
  State<SponsorTicketScreen> createState() => _SponsorTicketScreenState();
}

class _SponsorTicketScreenState extends State<SponsorTicketScreen> {
  List<SponsorTicketModel> _tickets = [];
  bool _loading = true;
  bool _isOffline = false;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

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
      final api = context.read<ApiService>();
      final data = await api.getMySponsorTickets();
      if (mounted) {
        setState(() {
          _tickets =
              data.map((j) => SponsorTicketModel.fromJson(j)).toList();
          _isOffline = false;
          _loading = false;
        });
        // Background-cache for offline use
        context.read<SyncService>().pullSponsorTickets();
      }
    } catch (_) {
      // Try loading from offline cache
      await _loadFromCache();
      if (mounted && _tickets.isEmpty) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final db = context.read<AppDatabase>();
      final rows = await db.getSponsorTicketsFromCache();
      if (mounted && rows.isNotEmpty) {
        setState(() {
          _tickets = rows.map(_cachedRowToSponsorTicket).toList();
          _isOffline = true;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load sponsor tickets from cache: $e');
    }
  }

  SponsorTicketModel _cachedRowToSponsorTicket(CachedSponsorTicket row) {
    List<SponsorTicketCategory> categories = [];
    try {
      final catList = jsonDecode(row.categoriesJson) as List;
      categories = catList
          .map((e) =>
              SponsorTicketCategory.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {}

    List<String> categoryNames = [];
    try {
      final nameList = jsonDecode(row.categoryNamesJson) as List;
      categoryNames = nameList.map((e) => e.toString()).toList();
    } catch (_) {}

    return SponsorTicketModel(
      id: row.id,
      eventId: row.eventId,
      sponsorUserId: row.sponsorUserId,
      receiptNumber: row.receiptNumber,
      encryptedQrPayload: row.encryptedQrPayload,
      scannedAt: row.scannedAt,
      createdAt: row.createdAt,
      eventTitle: row.eventTitle,
      eventStatus: row.eventStatus,
      eventStartTime: row.eventStartTime,
      venueName: row.venueName,
      venueAddress: row.venueAddress,
      venueCity: row.venueCity,
      categoryCount: row.categoryCount,
      scanCount: row.scanCount,
      categories: categories,
      categoryNames: categoryNames,
    );
  }

  List<SponsorTicketModel> get _filtered {
    if (_searchQuery.isEmpty) return _tickets;
    final q = _searchQuery.toLowerCase();
    return _tickets.where((t) {
      final title = (t.eventTitle ?? '').toLowerCase();
      final venue = (t.venueName ?? '').toLowerCase();
      final receipt = t.receiptNumber.toLowerCase();
      final cats = t.categories.map((c) => c.name.toLowerCase()).join(' ');
      return title.contains(q) ||
          venue.contains(q) ||
          receipt.contains(q) ||
          cats.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(title: const Text('Sponsor Tickets')),
      body: _loading
          ? _buildShimmer()
          : _tickets.isEmpty
              ? _buildEmpty(context)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Column(
                    children: [
                      if (_isOffline)
                        Container(
                          width: double.infinity,
                          color: Colors.orange.shade700.withValues(alpha: 0.12),
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 16),
                          child: Row(
                            children: [
                              Icon(Icons.cloud_off_rounded,
                                  size: 16, color: Colors.orange.shade700),
                              const SizedBox(width: 8),
                              Text(
                                "You're offline \u2014 showing cached tickets",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      _buildSearchBar(context),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text('No matching tickets',
                                    style: TextStyle(
                                        color: AppTheme.textSecondaryOf(
                                            context))),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 16),
                                itemBuilder: (context, index) {
                                  final ticket = filtered[index];
                                  return SponsorTicketCard(
                                    ticket: ticket,
                                    onTap: () => _openReceipt(ticket),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(3, (_) => const ShimmerListTile()),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.surfaceOf(context),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(Icons.confirmation_number_outlined,
                size: 40, color: AppTheme.textSecondaryOf(context)),
          ),
          const SizedBox(height: 16),
          Text('No sponsor tickets yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryOf(context))),
          const SizedBox(height: 4),
          Text('Tickets are created when your bids are accepted.',
              style:
                  TextStyle(color: AppTheme.textSecondaryOf(context))),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search tickets\u2026',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: AppTheme.inputFillOf(context),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          isDense: true,
        ),
        style: TextStyle(
            fontSize: 14, color: AppTheme.textPrimaryOf(context)),
      ),
    );
  }

  void _openReceipt(SponsorTicketModel ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SponsorTicketReceiptPage(ticket: ticket),
      ),
    );
  }
}
