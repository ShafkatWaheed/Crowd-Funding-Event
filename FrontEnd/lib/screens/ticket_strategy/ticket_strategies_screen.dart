import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../widgets/app_toast.dart';
import '../../models/ticket_strategy.dart';
import '../../services/api_service.dart';

class TicketStrategiesScreen extends StatefulWidget {
  const TicketStrategiesScreen({super.key});

  @override
  State<TicketStrategiesScreen> createState() => _TicketStrategiesScreenState();
}

class _TicketStrategiesScreenState extends State<TicketStrategiesScreen> {
  List<TicketStrategy> _strategies = [];
  List<TicketStrategy> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

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
      final data = await api.getTicketStrategies();
      setState(() {
        _strategies = data.map((d) => TicketStrategy.fromJson(d)).toList();
        _applySearch();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppToast.fromError(context, e, fallback: 'Failed to load');
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
          if (t.description != null &&
              t.description!.toLowerCase().contains(q)) {
            return true;
          }
        }
        return false;
      }).toList();
    }
  }

  Future<void> _delete(int id) async {
    try {
      final api = context.read<ApiService>();
      await api.deleteTicketStrategy(id);
      _load();
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Delete failed');
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
        title: const Text('Ticket Strategies'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateTicketStrategyScreen(),
            ),
          );
          if (created == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Strategy'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── Search bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search strategies or tiers…',
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

          // ── Content ──
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.confirmation_number_outlined,
                                size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              _searchCtrl.text.isNotEmpty
                                  ? 'No matching strategies'
                                  : 'No ticket strategies yet',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey[500]),
                            ),
                            if (_searchCtrl.text.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                    'Create a strategy with tiers to use in events'),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final s = _filtered[index];
                          return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.confirmation_number,
                                    color: AppTheme.primaryColor),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(s.name,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600)),
                                ),
                                IconButton(
                                  onPressed: () => _delete(s.id),
                                  icon: const Icon(Icons.delete_outline,
                                      color: AppTheme.errorColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...s.tiers.map((t) => Padding(
                                  padding:
                                      const EdgeInsets.only(left: 36, bottom: 6),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(t.name,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w500)),
                                          ),
                                          Text(t.priceFormatted,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.successColor)),
                                        ],
                                      ),
                                      if (t.description != null && t.description!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 16, top: 2),
                                          child: Text(t.description!,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                  fontStyle: FontStyle.italic)),
                                        ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}


// ── Inline Create Strategy Screen ──

class CreateTicketStrategyScreen extends StatefulWidget {
  const CreateTicketStrategyScreen({super.key});

  @override
  State<CreateTicketStrategyScreen> createState() =>
      _CreateTicketStrategyScreenState();
}

class _CreateTicketStrategyScreenState
    extends State<CreateTicketStrategyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final List<_TierInput> _tiers = [_TierInput()];
  bool _saving = false;

  void _addTier() => setState(() => _tiers.add(_TierInput()));

  void _removeTier(int index) {
    if (_tiers.length > 1) setState(() => _tiers.removeAt(index));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final tiersData = _tiers.asMap().entries.map((e) {
      final i = e.key;
      final t = e.value;
      final data = <String, dynamic>{
        'name': t.nameCtrl.text.trim(),
        'price_cents': ((double.tryParse(t.priceCtrl.text) ?? 0) * 100).toInt(),
        'display_order': i,
      };
      if (t.descCtrl.text.trim().isNotEmpty) {
        data['description'] = t.descCtrl.text.trim();
      }
      return data;
    }).toList();

    try {
      final api = context.read<ApiService>();
      await api.createTicketStrategy({
        'name': _nameCtrl.text.trim(),
        'tiers': tiersData,
      });
      if (mounted) {
        AppToast.success(context, 'Ticket strategy created!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed');
      }
    }
    setState(() => _saving = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final t in _tiers) {
      t.nameCtrl.dispose();
      t.descCtrl.dispose();
      t.priceCtrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Ticket Strategy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Strategy Name',
                      hintText: 'e.g. "Concert Standard", "Gala VIP"',
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      const Icon(Icons.layers,
                          color: AppTheme.primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Text('Tiers',
                          style: Theme.of(context).textTheme.titleSmall),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _addTier,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Tier'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  ...List.generate(_tiers.length, (i) {
                    final t = _tiers[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text('Tier ${i + 1}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                const Spacer(),
                                if (_tiers.length > 1)
                                  IconButton(
                                    onPressed: () => _removeTier(i),
                                    icon: const Icon(Icons.close,
                                        size: 18,
                                        color: AppTheme.errorColor),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: t.nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Tier Name',
                                hintText:
                                    'e.g. Platinum, Diamond, General',
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: t.descCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Description (what this tier provides)',
                                hintText:
                                    'e.g. Front row seating, backstage access, free drinks',
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: t.priceCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Price (\$)',
                                prefixText: '\$ ',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Required';
                                }
                                if (double.tryParse(v) == null) {
                                  return 'Invalid';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Create Strategy'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _TierInput {
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
}
