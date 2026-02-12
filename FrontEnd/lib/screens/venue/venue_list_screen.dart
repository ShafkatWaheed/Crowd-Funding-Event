import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/venue.dart';
import '../../services/api_service.dart';

class VenueListScreen extends StatefulWidget {
  const VenueListScreen({super.key});

  @override
  State<VenueListScreen> createState() => _VenueListScreenState();
}

class _VenueListScreenState extends State<VenueListScreen> {
  List<Venue> _venues = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVenues();
  }

  Future<void> _loadVenues() async {
    setState(() => _isLoading = true);
    print('[VenueList] _loadVenues called');
    try {
      final api = context.read<ApiService>();
      print('[VenueList] calling api.getVenues()...');
      final data = await api.getVenues();
      print('[VenueList] raw response (${data.length} items): $data');
      final parsed = <Venue>[];
      for (final v in data) {
        print('[VenueList] parsing: $v');
        parsed.add(Venue.fromJson(v));
      }
      print('[VenueList] parsed ${parsed.length} venues OK');
      setState(() {
        _venues = parsed;
      });
    } catch (e, st) {
      print('[VenueList] ERROR: $e');
      print('[VenueList] STACK: $st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load venues: $e')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _deleteVenue(int id) async {
    try {
      final api = context.read<ApiService>();
      await api.deleteVenue(id);
      _loadVenues();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete venue: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Venues')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _venues.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_city,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No venues yet',
                          style: TextStyle(
                              fontSize: 18, color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _venues.length,
                  itemBuilder: (context, index) {
                    final venue = _venues[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppTheme.surfaceColor,
                          child: Icon(Icons.location_city,
                              color: AppTheme.primaryColor),
                        ),
                        title: Text(venue.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(venue.fullAddress),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Cap: ${venue.maxCapacity}',
                                style: TextStyle(color: Colors.grey[600])),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: AppTheme.errorColor),
                              onPressed: () => _deleteVenue(venue.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/venues/create'),
        icon: const Icon(Icons.add),
        label: const Text('Add Venue'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}
