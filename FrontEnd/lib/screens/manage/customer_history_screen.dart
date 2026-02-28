import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/shimmer_loaders.dart';

class CustomerHistoryScreen extends StatefulWidget {
  const CustomerHistoryScreen({super.key});

  @override
  State<CustomerHistoryScreen> createState() => _CustomerHistoryScreenState();
}

class _CustomerHistoryScreenState extends State<CustomerHistoryScreen> {
  static const _pageSize = 20;

  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _customers = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent * 0.8 &&
        !_loadingMore &&
        _hasMore &&
        !_loading) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasMore = true;
    });
    try {
      final api = context.read<ApiService>();
      final list = await api.getOrganizerCustomers(offset: 0, limit: _pageSize);
      if (mounted) {
        setState(() {
          _customers = list.cast<Map<String, dynamic>>();
          _hasMore = list.length >= _pageSize;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final api = context.read<ApiService>();
      final list = await api.getOrganizerCustomers(
        offset: _customers.length,
        limit: _pageSize,
      );
      if (mounted) {
        setState(() {
          _customers.addAll(list.cast<Map<String, dynamic>>());
          _hasMore = list.length >= _pageSize;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) return _customers;
    return _customers.where((c) {
      final name = (c['customer_name'] ?? '').toString().toLowerCase();
      return name.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Scaffold(
      backgroundColor: AppTheme.surfaceOf(context),
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
        title: const Text('My Customers'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List.generate(4, (_) => const ShimmerListTile()),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search customers...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: AppTheme.cardOf(context),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _statChip(Icons.people_rounded,
                            '${items.length} customers', AppTheme.accentColor),
                        const SizedBox(width: 8),
                        _statChip(
                          Icons.event_repeat_rounded,
                          '${items.where((c) => (c['events_attended'] ?? 0) > 1).length} repeat',
                          AppTheme.successColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_outline,
                                    size: 64,
                                    color: AppTheme.textSecondaryOf(context)),
                                const SizedBox(height: 12),
                                Text('No customers yet',
                                    style: TextStyle(
                                        color: AppTheme.textSecondaryOf(
                                            context))),
                                const SizedBox(height: 4),
                                Text(
                                  'Customers appear here when their tickets are scanned',
                                  style: TextStyle(
                                      color:
                                          AppTheme.textSecondaryOf(context),
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollCtrl,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            itemCount:
                                items.length + (_loadingMore ? 1 : 0),
                            itemBuilder: (ctx, i) {
                              if (i >= items.length) {
                                return const Padding(
                                  padding:
                                      EdgeInsets.symmetric(vertical: 20),
                                  child: Center(
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                                );
                              }
                              return _buildCustomerCard(items[i]);
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> c) {
    final eventsAttended = c['events_attended'] ?? 0;
    final isRepeat = eventsAttended > 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha:0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isRepeat ? AppTheme.successColor : AppTheme.accentColor,
          child: Icon(
            isRepeat ? Icons.loyalty_rounded : Icons.person_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          c['customer_name'] ?? 'Customer ${c['customer_id']}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '$eventsAttended event${eventsAttended == 1 ? '' : 's'} attended',
          style: TextStyle(
              fontSize: 13, color: AppTheme.textSecondaryOf(context)),
        ),
        trailing: isRepeat
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Loyal',
                  style: TextStyle(
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha:0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
