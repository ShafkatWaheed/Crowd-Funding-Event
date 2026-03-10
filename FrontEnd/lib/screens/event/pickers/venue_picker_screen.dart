import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../widgets/app_toast.dart';
import '../../../models/venue.dart';
import '../../../providers/venue_provider.dart';

/// Full-page venue picker. Returns the selected [Venue] via Navigator.pop.
/// Highlights the currently active venue when [currentVenueId] is provided.
class VenuePickerScreen extends StatefulWidget {
  final int? currentVenueId;
  const VenuePickerScreen({super.key, this.currentVenueId});

  @override
  State<VenuePickerScreen> createState() => _VenuePickerScreenState();
}

class _VenuePickerScreenState extends State<VenuePickerScreen> {
  List<Venue> _venues = [];
  List<Venue> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = context.read<VenueProvider>();
      final data = await repo.getVenues();
      if (mounted) {
        setState(() {
          _venues = data;
          _applySearch();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppToast.fromError(context, e, fallback: 'Failed to load venues');
      }
    }
  }

  void _applySearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      _filtered = List.from(_venues);
    } else {
      _filtered = _venues.where((v) {
        return v.name.toLowerCase().contains(q) ||
            v.fullAddress.toLowerCase().contains(q);
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Venue'),
      ),
      body: Column(
        children: [
          // ── Search ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name or address…',
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
                fillColor: AppTheme.cardOf(context),
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

          // ── List ──
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_off_rounded,
                                size: 56, color: AppTheme.textSecondaryOf(context)),
                            const SizedBox(height: 12),
                            Text(
                              _searchCtrl.text.isNotEmpty
                                  ? 'No matching venues'
                                  : 'No venues available',
                              style: TextStyle(
                                  fontSize: 16, color: AppTheme.textSecondaryOf(context)),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          itemCount: _filtered.length,
                          itemBuilder: (context, i) {
                            final v = _filtered[i];
                            final isActive = v.id == widget.currentVenueId;
                            final accentClr = AppTheme.accentColor;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              color: AppTheme.cardOf(context),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: isActive
                                    ? BorderSide(color: accentClr, width: 2)
                                    : BorderSide(color: AppTheme.dividerOf(context)),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => Navigator.pop(context, v),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? accentClr.withValues(alpha: 0.15)
                                              : accentClr.withValues(alpha: 0.08),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.location_on_rounded,
                                          color: accentClr,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(v.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                  color: AppTheme.textPrimaryOf(context),
                                                )),
                                            const SizedBox(height: 3),
                                            Text(v.fullAddress,
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: AppTheme.textSecondaryOf(context))),
                                            const SizedBox(height: 2),
                                            Text(
                                                'Capacity: ${v.maxCapacity}',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppTheme.textSecondaryOf(context))),
                                          ],
                                        ),
                                      ),
                                      if (isActive)
                                        Icon(Icons.check_circle,
                                            color: accentClr,
                                            size: 24),
                                    ],
                                  ),
                                ),
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
