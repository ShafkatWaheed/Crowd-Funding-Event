import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/venue.dart';
import '../../providers/venue_provider.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/shimmer_loaders.dart';
import 'create_venue_screen.dart';

class VenueListScreen extends StatefulWidget {
  const VenueListScreen({super.key});

  @override
  State<VenueListScreen> createState() => _VenueListScreenState();
}

class _VenueListScreenState extends State<VenueListScreen> {
  List<Venue> _venues = [];
  List<Venue> _filtered = [];
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVenues();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVenues() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<VenueProvider>();
      final data = await repo.getVenues();
      setState(() {
        _venues = data;
        _applySearch();
      });
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to load venues');
      }
    }
    setState(() => _isLoading = false);
  }

  void _applySearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      _filtered = List.from(_venues);
    } else {
      _filtered = _venues.where((v) {
        return v.name.toLowerCase().contains(q) ||
            v.fullAddress.toLowerCase().contains(q) ||
            '${v.maxCapacity}'.contains(q);
      }).toList();
    }
  }

  Future<void> _deleteVenue(int id) async {
    try {
      final repo = context.read<VenueProvider>();
      await repo.deleteVenue(id);
      _loadVenues();
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to delete venue');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('My Venues'),
      ),
      body: Column(
        children: [
          // ── Search bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search venues…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _applySearch());
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.inputFillOf(context),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppTheme.dividerOf(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppTheme.dividerOf(context)),
                ),
              ),
              onChanged: (_) => setState(() => _applySearch()),
            ),
          ),

          // ── Content ──
          Expanded(
            child: _isLoading
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: List.generate(3, (_) => const ShimmerListTile()),
                    ),
                  )
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_city,
                                size: 64, color: AppTheme.textSecondaryOf(context)),
                            const SizedBox(height: 16),
                            Text(
                              _searchCtrl.text.isNotEmpty
                                  ? 'No matching venues'
                                  : 'No venues yet',
                              style: TextStyle(
                                  fontSize: 18, color: AppTheme.textSecondaryOf(context)),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadVenues,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final venue = _filtered[index];
                            return Card(
                              color: AppTheme.cardOf(context),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.accentColor.withValues(alpha: 0.15),
                                  child: const Icon(Icons.location_city,
                                      color: AppTheme.accentColor),
                                ),
                                title: Text(venue.name,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimaryOf(context))),
                                subtitle: Text(venue.fullAddress,
                                    style: TextStyle(
                                        color: AppTheme.textSecondaryOf(context))),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Cap: ${venue.maxCapacity}',
                                        style:
                                            TextStyle(color: AppTheme.textSecondaryOf(context))),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: Icon(Icons.edit_outlined,
                                          color: AppTheme.accentColor),
                                      onPressed: () async {
                                        final updated = await Navigator.push<bool>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => CreateVenueScreen(venue: venue),
                                          ),
                                        );
                                        if (updated == true) _loadVenues();
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: AppTheme.errorColor),
                                      onPressed: () =>
                                          _deleteVenue(venue.id),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await context.push<bool>('/venues/create');
          if (created == true && mounted) _loadVenues();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Venue'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}
