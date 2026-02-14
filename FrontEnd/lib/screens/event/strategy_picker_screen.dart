import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../widgets/app_toast.dart';
import '../../models/ticket_strategy.dart';
import '../../services/api_service.dart';

/// Full-page ticket strategy picker. Returns the selected [TicketStrategy]
/// via Navigator.pop. Highlights the currently active strategy when
/// [currentStrategyId] is provided.
class StrategyPickerScreen extends StatefulWidget {
  final int? currentStrategyId;
  const StrategyPickerScreen({super.key, this.currentStrategyId});

  @override
  State<StrategyPickerScreen> createState() => _StrategyPickerScreenState();
}

class _StrategyPickerScreenState extends State<StrategyPickerScreen> {
  List<TicketStrategy> _strategies = [];
  List<TicketStrategy> _filtered = [];
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
      final api = context.read<ApiService>();
      final data = await api.getTicketStrategies();
      final parsed = data.map((d) => TicketStrategy.fromJson(d)).toList();
      if (mounted) {
        setState(() {
          _strategies = parsed;
          _applySearch();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppToast.fromError(context, e, fallback: 'Failed to load strategies');
      }
    }
  }

  void _applySearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      _filtered = List.from(_strategies);
    } else {
      _filtered = _strategies.where((s) {
        if (s.name.toLowerCase().contains(q)) return true;
        for (final t in s.tiers) {
          if (t.name.toLowerCase().contains(q)) return true;
        }
        return false;
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Ticket Strategy'),
      ),
      body: Column(
        children: [
          // ── Search ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by strategy or tier name…',
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
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppTheme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppTheme.dividerColor),
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
                            Icon(Icons.confirmation_number_outlined,
                                size: 56, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(
                              _searchCtrl.text.isNotEmpty
                                  ? 'No matching strategies'
                                  : 'No strategies available',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey[500]),
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
                            final s = _filtered[i];
                            final isActive =
                                s.id == widget.currentStrategyId;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: isActive
                                    ? BorderSide(
                                        color: AppTheme.primaryColor,
                                        width: 2)
                                    : BorderSide.none,
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => Navigator.pop(context, s),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Header
                                      Row(
                                        children: [
                                          Container(
                                            width: 42,
                                            height: 42,
                                            decoration: BoxDecoration(
                                              color: isActive
                                                  ? AppTheme.primaryColor
                                                      .withValues(alpha: 0.12)
                                                  : Colors.deepPurple
                                                      .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(11),
                                            ),
                                            child: Icon(
                                              Icons
                                                  .confirmation_number_rounded,
                                              color: isActive
                                                  ? AppTheme.primaryColor
                                                  : Colors.deepPurple,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(s.name,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 15,
                                                      color: isActive
                                                          ? AppTheme
                                                              .primaryColor
                                                          : Colors.black87,
                                                    )),
                                                Text(
                                                    '${s.tiers.length} tier${s.tiers.length == 1 ? '' : 's'}',
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            Colors.grey[500])),
                                              ],
                                            ),
                                          ),
                                          if (isActive)
                                            Icon(Icons.check_circle,
                                                color: AppTheme.primaryColor,
                                                size: 24),
                                        ],
                                      ),
                                      // Tiers
                                      if (s.tiers.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        ...s.tiers.map((t) => Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 54, bottom: 4),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 7,
                                                    height: 7,
                                                    decoration: BoxDecoration(
                                                      color: AppTheme
                                                          .primaryColor,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(t.name,
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w500,
                                                            fontSize: 13)),
                                                  ),
                                                  Text(t.priceFormatted,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 13,
                                                          color: AppTheme
                                                              .successColor)),
                                                ],
                                              ),
                                            )),
                                      ],
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
