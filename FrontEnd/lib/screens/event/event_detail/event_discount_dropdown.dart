import 'package:flutter/material.dart';

import '../../../config/design_tokens.dart';
import '../../../services/api_service.dart';
import '../../../widgets/app_toast.dart';

class EventDiscountDropdown extends StatefulWidget {
  final int eventId;
  const EventDiscountDropdown({required this.eventId});

  @override
  State<EventDiscountDropdown> createState() => _EventDiscountDropdownState();
}

class _EventDiscountDropdownState extends State<EventDiscountDropdown> {
  final _api = ApiService();
  List<Map<String, dynamic>> _allStrategies = [];
  List<Map<String, dynamic>> _attached = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final all = await _api.getDiscountStrategies();
      final attached = await _api.getEventDiscountStrategies(widget.eventId);
      setState(() {
        _allStrategies = all.cast<Map<String, dynamic>>();
        _attached = attached.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Set<int> get _attachedIds => _attached.map((d) => d['id'] as int).toSet();

  Future<void> _attach(int id, {required bool autoApply}) async {
    try {
      await _api.attachDiscountStrategy(widget.eventId, id, autoApply: autoApply);
      await _load();
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to attach');
      }
    }
  }

  Future<void> _detach(int id) async {
    try {
      await _api.detachDiscountStrategy(widget.eventId, id);
      await _load();
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to detach');
      }
    }
  }

  String _label(Map<String, dynamic> d) {
    final name = d['name'] ?? '';
    final type = d['discount_type'] ?? '';
    final val = d['value'] ?? 0;
    final target = d['target'] ?? 'all';
    final typeLabel = type == 'ticket_percent' ? '% ticket' : '% pledge';
    return '$name · $val$typeLabel · $target';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.discount_rounded, color: Colors.deepPurple, size: 20),
              AppSpacing.hSm,
              const Text('Discounts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              if (_loading)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 10),
          // Attached discounts
          if (_attached.isNotEmpty) ...[
            ..._attached.map((d) {
              final autoApply = d['auto_apply'] == true;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.deepPurple.withOpacity(0.4), width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _label(d),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: autoApply
                                    ? Colors.green.withOpacity(0.25)
                                    : Colors.orange.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                autoApply ? 'Auto' : 'Claimable',
                                style: TextStyle(
                                  color: autoApply ? Colors.greenAccent : Colors.orangeAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _detach(d['id'] as int),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 16, color: Colors.white54),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 6),
          ],
          // Search
          TextField(
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search discounts…',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: AppRadius.sm, borderSide: BorderSide.none),
            ),
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
          ),
          const SizedBox(height: 6),
          ..._buildAvailableList(),
        ],
      ),
    );
  }

  List<Widget> _buildAvailableList() {
    final available = _allStrategies.where((d) {
      final id = d['id'] as int;
      if (_attachedIds.contains(id)) return false;
      if (_search.isEmpty) return true;
      return _label(d).toLowerCase().contains(_search);
    }).toList();

    if (available.isEmpty && _search.isNotEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('No matching discounts', style: TextStyle(color: Colors.white38, fontSize: 13)),
        ),
      ];
    }
    if (available.isEmpty) return [];
    return available.take(3).map((d) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(_label(d), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ),
              const SizedBox(width: 6),
              AddButton(
                label: 'Add + Apply',
                color: Colors.green,
                onTap: () => _attach(d['id'] as int, autoApply: true),
              ),
              const SizedBox(width: 6),
              AddButton(
                label: 'Add',
                color: Colors.deepPurple,
                onTap: () => _attach(d['id'] as int, autoApply: false),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}

class AddButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const AddButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.2),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
