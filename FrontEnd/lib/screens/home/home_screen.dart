import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../widgets/event_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String? _selectedCity;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().loadEvents();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final filters = <String, dynamic>{};
    if (_searchController.text.isNotEmpty) {
      filters['search'] = _searchController.text;
    }
    if (_selectedCity != null) filters['city'] = _selectedCity;
    if (_selectedStatus != null) filters['status'] = _selectedStatus;

    context.read<EventProvider>().loadEvents(filters: filters);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final events = context.watch<EventProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CrowdFund Events'),
        actions: [
          if (user != null && user.isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              tooltip: 'Admin',
              onPressed: () => context.go('/admin'),
            ),
          if (user != null && user.isOrganizer)
            IconButton(
              icon: const Icon(Icons.location_city),
              tooltip: 'Venues',
              onPressed: () => context.go('/venues'),
            ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => context.go('/profile'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search events...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _applyFilters();
                      },
                    ),
                  ),
                  onSubmitted: (_) => _applyFilters(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('All')),
                          ...EventStatus.values.map((s) =>
                              DropdownMenuItem(
                                  value: s.name,
                                  child: Text(s.name.replaceAll('_', ' ')))),
                        ],
                        onChanged: (v) {
                          setState(() => _selectedStatus = v);
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _applyFilters,
                      icon: const Icon(Icons.filter_list, size: 18),
                      label: const Text('Filter'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Event list
          Expanded(
            child: events.isLoading
                ? const Center(child: CircularProgressIndicator())
                : events.error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline,
                                size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(events.error!),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => events.loadEvents(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : events.events.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.event_busy,
                                    size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  'No events found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => events.loadEvents(),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: events.events.length,
                              itemBuilder: (context, index) {
                                final event = events.events[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: EventCard(
                                    event: event,
                                    onTap: () =>
                                        context.go('/events/${event.id}'),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton:
          user != null && (user.isOrganizer || user.isAdmin)
              ? FloatingActionButton.extended(
                  onPressed: () => context.go('/events/create'),
                  icon: const Icon(Icons.add),
                  label: const Text('New Event'),
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                )
              : null,
    );
  }
}
