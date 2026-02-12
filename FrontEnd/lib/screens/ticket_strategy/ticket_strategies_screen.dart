import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/ticket_strategy.dart';
import '../../services/api_service.dart';

class TicketStrategiesScreen extends StatefulWidget {
  const TicketStrategiesScreen({super.key});

  @override
  State<TicketStrategiesScreen> createState() => _TicketStrategiesScreenState();
}

class _TicketStrategiesScreenState extends State<TicketStrategiesScreen> {
  List<TicketStrategy> _strategies = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getTicketStrategies();
      setState(() {
        _strategies = data.map((d) => TicketStrategy.fromJson(d)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load: $e')),
        );
      }
    }
  }

  Future<void> _delete(int id) async {
    try {
      final api = context.read<ApiService>();
      await api.deleteTicketStrategy(id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ticket Strategies')),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _strategies.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.confirmation_number_outlined,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No ticket strategies yet',
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey[500])),
                      const SizedBox(height: 8),
                      const Text(
                          'Create a strategy with tiers to use in events'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _strategies.length,
                  itemBuilder: (context, index) {
                    final s = _strategies[index];
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
                                          if (t.quantity > 0) ...[
                                            const SizedBox(width: 8),
                                            Text('(${t.quantity} tickets)',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[500])),
                                          ],
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
        'quantity': int.tryParse(t.quantityCtrl.text) ?? 0,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket strategy created!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
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
      t.quantityCtrl.dispose();
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
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
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
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: t.quantityCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Quantity',
                                      hintText: '0 = unlimited',
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
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
  final quantityCtrl = TextEditingController(text: '0');
}
