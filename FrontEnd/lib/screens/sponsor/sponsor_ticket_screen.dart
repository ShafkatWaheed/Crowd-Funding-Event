import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/sponsor.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';
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
