import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/design_tokens.dart';
import '../../config/theme.dart';
import '../../models/event.dart';
import '../../providers/event_provider.dart';
import '../../widgets/animated_list_item.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/event_card.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/shimmer_loaders.dart';
import '../home/home_shared.dart';

class CoOrganizedEventsScreen extends StatefulWidget {
  const CoOrganizedEventsScreen({super.key});

  @override
  State<CoOrganizedEventsScreen> createState() =>
      _CoOrganizedEventsScreenState();
}

class _CoOrganizedEventsScreenState extends State<CoOrganizedEventsScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _debounce;

  List<Event> _events = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _selectedStatus;
  String _search = '';
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent * 0.8 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (_search != value) {
        _search = value;
        _load();
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasMore = true;
    });
    try {
      final repo = context.read<EventProvider>();
      final data = await repo.getCoOrganizedEvents(
        status: _selectedStatus,
        search: _search.isEmpty ? null : _search,
        offset: 0,
        limit: _pageSize,
      );
      if (mounted) {
        setState(() {
          _events = data;
          _hasMore = data.length >= _pageSize;
        });
      }
    } catch (e) {
      debugPrint('CoOrganizedEvents load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final repo = context.read<EventProvider>();
      final data = await repo.getCoOrganizedEvents(
        status: _selectedStatus,
        search: _search.isEmpty ? null : _search,
        offset: _events.length,
        limit: _pageSize,
      );
      if (mounted) {
        setState(() {
          _events.addAll(data);
          _hasMore = data.length >= _pageSize;
        });
      }
    } catch (e) {
      debugPrint('CoOrganizedEvents loadMore error: $e');
    }
    if (mounted) setState(() => _loadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceOf(context),
      appBar: AppBar(
        title: const Text('Co-Organized Events'),
        centerTitle: true,
        backgroundColor: AppTheme.cardOf(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            color: AppTheme.cardOf(context),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md,
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by event title\u2026',
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppTheme.textSecondaryOf(context),
                      size: AppIconSize.md,
                    ),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              _search = '';
                              _load();
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: 14,
                    ),
                    filled: true,
                    fillColor: AppTheme.inputFillOf(context),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.md,
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: _onSearchChanged,
                ),
                AppSpacing.vMd,
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: EventStatus.values.map((s) {
                      final isActive = _selectedStatus == s.name;
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: AppChip(
                          label: statusDisplayName(s),
                          selected: isActive,
                          onSelected: (selected) {
                            setState(() {
                              _selectedStatus = selected ? s.name : null;
                            });
                            _load();
                          },
                          chipColor: statusChipColor(context, s),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.dividerOf(context)),
          Expanded(
            child: _loading && _events.isEmpty
                ? SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: ShimmerEventList(count: 3),
                    ),
                  )
                : _events.isEmpty
                    ? EmptyState(
                        icon: Icons.group_work_rounded,
                        title: _search.isNotEmpty || _selectedStatus != null
                            ? 'No matches'
                            : 'No co-organized events',
                        subtitle: _search.isNotEmpty || _selectedStatus != null
                            ? 'Try adjusting your filters'
                            : 'Events you co-organize will appear here',
                      )
                    : RefreshIndicator(
                        color: AppTheme.primaryColor,
                        onRefresh: _load,
                        child: ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.lg,
                            AppSpacing.lg,
                            100,
                          ),
                          itemCount: _events.length + (_loadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _events.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(
                                    vertical: AppSpacing.xl),
                                child: Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              );
                            }
                            final event = _events[index];
                            return Padding(
                              padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md),
                              child: AnimatedListItem(
                                index: index,
                                child: EventCard(
                                  event: event,
                                  imageUrl: event.firstImageUrl,
                                  onTap: () =>
                                      context.push('/events/${event.id}'),
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
