import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/admin.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/app_toast.dart';
import 'tabs/banking/banking_escrow_pipeline.dart';

class AdminEscrowPipelineScreen extends StatefulWidget {
  const AdminEscrowPipelineScreen({super.key});

  @override
  State<AdminEscrowPipelineScreen> createState() =>
      _AdminEscrowPipelineScreenState();
}

class _AdminEscrowPipelineScreenState extends State<AdminEscrowPipelineScreen> {
  List<AdminEscrowItem> _fundEscrows = [];
  List<AdminEscrowItem> _ticketEscrows = [];
  List<AdminEscrowItem> _sponsorEscrows = [];
  bool _pipelineLoading = true;
  String _typeFilter = 'all';

  AdminEventEscrows? _selectedEventEscrows;
  int? _selectedEventId;

  String _searchText = '';
  final _searchController = TextEditingController();

  List<AdminEscrowItem> _filterEscrows(List<AdminEscrowItem> items) {
    if (_searchText.isEmpty) return items;
    final q = _searchText.toLowerCase();
    return items.where((e) {
      final title = (e.eventTitle ?? '').toLowerCase();
      final id = e.eventId.toString();
      final status = e.status.toLowerCase();
      return title.contains(q) || id.contains(q) || status.contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadPipeline();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPipeline() async {
    setState(() => _pipelineLoading = true);
    try {
      final admin = context.read<AdminProvider>();
      final results = await Future.wait([
        admin.getEscrows(type: 'fund'),
        admin.getEscrows(type: 'ticket'),
        admin.getEscrows(type: 'sponsor'),
      ]);
      if (mounted) {
        setState(() {
          _fundEscrows = results[0].items;
          _ticketEscrows = results[1].items;
          _sponsorEscrows = results[2].items;
          _pipelineLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _pipelineLoading = false);
    }
  }

  Future<void> _loadEventEscrowDetail(int eventId) async {
    try {
      final admin = context.read<AdminProvider>();
      final data = await admin.getEventEscrows(eventId);
      if (mounted) {
        setState(() {
          _selectedEventEscrows = data;
          _selectedEventId = eventId;
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _refreshAll() async {
    await _loadPipeline();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escrow Pipeline'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshAll,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by event name, ID, or status...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchText.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchText = '');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                style: TextStyle(
                    fontSize: 14, color: AppTheme.textPrimaryOf(context)),
                onChanged: (v) => setState(() => _searchText = v.trim()),
              ),
              const SizedBox(height: 12),
              BankingEscrowPipelineSection(
                fundEscrows: _filterEscrows(_fundEscrows),
                ticketEscrows: _filterEscrows(_ticketEscrows),
                sponsorEscrows: _filterEscrows(_sponsorEscrows),
                pipelineLoading: _pipelineLoading,
                pipelineTypeFilter: _typeFilter,
                onTypeFilterChanged: (v) => setState(() => _typeFilter = v),
                onRefresh: _loadPipeline,
                selectedPipelineEventId: _selectedEventId,
                selectedEventEscrows: _selectedEventEscrows,
                onLoadEventDetail: _loadEventEscrowDetail,
                onClearSelection: () => setState(() {
                  _selectedEventEscrows = null;
                  _selectedEventId = null;
                }),
                onSnack: (msg) {
                  if (mounted) AppToast.info(context, msg);
                },
                onReloadEventDetail: _loadEventEscrowDetail,
                onReloadPipeline: _loadPipeline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
