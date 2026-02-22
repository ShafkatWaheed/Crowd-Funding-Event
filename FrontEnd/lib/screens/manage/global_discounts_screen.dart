import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/shimmer_loaders.dart';

class GlobalDiscountsScreen extends StatefulWidget {
  const GlobalDiscountsScreen({super.key});

  @override
  State<GlobalDiscountsScreen> createState() => _GlobalDiscountsScreenState();
}

class _GlobalDiscountsScreenState extends State<GlobalDiscountsScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _strategies = [];
  bool _loading = true;

  // Create form
  final _nameCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  String _discountType = 'ticket_percent';
  String _target = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await context.read<ApiService>().getDiscountStrategies();
      if (mounted) {
        setState(() {
          _strategies = list.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    final value = int.tryParse(_valueCtrl.text.trim());
    if (name.isEmpty || value == null || value <= 0 || value > 100) {
      AppToast.info(context, 'Enter a name and percentage (1-100)');
      return;
    }
    try {
      await context.read<ApiService>().createDiscountStrategy({
        'name': name,
        'discount_type': _discountType,
        'value': value,
        'target': _target,
      });
      _nameCtrl.clear();
      _valueCtrl.clear();
      _load();
      if (mounted) {
        AppToast.success(context, 'Discount created');
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to create discount');
      }
    }
  }

  Future<void> _delete(int id) async {
    try {
      await context.read<ApiService>().deleteDiscountStrategy(id);
      _load();
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to delete discount');
      }
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) return _strategies;
    return _strategies.where((d) {
      final name = (d['name'] ?? '').toString().toLowerCase();
      final type = (d['discount_type'] ?? '').toString().toLowerCase();
      return name.contains(q) || type.contains(q);
    }).toList();
  }

  String _describe(Map<String, dynamic> d) {
    final type = d['discount_type'] as String? ?? '';
    final val = d['value'] ?? 0;
    final tgt = d['target'] ?? 'all';
    String desc;
    switch (type) {
      case 'ticket_percent':
        desc = '$val% off ticket price';
        break;
      case 'pledge_percent':
        desc = '$val% of pledge amount';
        break;
      default:
        desc = '$val%';
    }
    if (tgt == 'pledgers') {
      desc += '  ·  pledgers only';
    } else if (tgt == 'non_pledgers') {
      desc += '  ·  non-pledgers only';
    }
    return desc;
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'ticket_percent':
        return Icons.confirmation_number_rounded;
      case 'pledge_percent':
        return Icons.volunteer_activism_rounded;
      default:
        return Icons.discount_rounded;
    }
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
        title: const Text('Discounts'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: List.generate(3, (_) => const ShimmerListTile()),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Create form ──
                  _buildCreateForm(),
                  const SizedBox(height: 20),

                  // ── Search ──
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search discounts...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.dividerOf(context))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.dividerOf(context))),
                      filled: true,
                      fillColor: AppTheme.inputFillOf(context),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Count ──
                  Text(
                    '${items.length} discount${items.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Attach these to events from the event\'s Discounts page.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondaryOf(context)),
                  ),
                  const SizedBox(height: 8),

                  if (items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppTheme.cardOf(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.discount_outlined,
                              size: 48, color: AppTheme.textSecondaryOf(context)),
                          const SizedBox(height: 8),
                          Text('No discounts yet',
                              style: TextStyle(color: AppTheme.textSecondaryOf(context))),
                        ],
                      ),
                    )
                  else
                    ...items.map((d) => _buildCard(d)),
                ],
              ),
      ),
    );
  }

  Widget _buildCreateForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create Discount',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            style: TextStyle(color: AppTheme.textPrimaryOf(context)),
            decoration: InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Early Bird, Pledger Reward',
              hintStyle: TextStyle(color: AppTheme.textSecondaryOf(context)),
              labelStyle: TextStyle(color: AppTheme.textSecondaryOf(context)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.dividerOf(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.dividerOf(context)),
              ),
              filled: true,
              fillColor: AppTheme.inputFillOf(context),
            ),
          ),
          const SizedBox(height: 12),

          // Type
          Text('Discount Type',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textPrimaryOf(context))),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text('% of Ticket',
                    style: TextStyle(color: AppTheme.textPrimaryOf(context))),
                selected: _discountType == 'ticket_percent',
                onSelected: (_) =>
                    setState(() => _discountType = 'ticket_percent'),
                selectedColor: AppTheme.accentColor.withValues(alpha: 0.35),
                checkmarkColor: Colors.white,
              ),
              ChoiceChip(
                label: Text('% of Pledge',
                    style: TextStyle(color: AppTheme.textPrimaryOf(context))),
                selected: _discountType == 'pledge_percent',
                onSelected: (_) => setState(() {
                  _discountType = 'pledge_percent';
                  if (_target == 'non_pledgers') _target = 'all';
                }),
                selectedColor: AppTheme.accentColor.withValues(alpha: 0.35),
                checkmarkColor: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _valueCtrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: AppTheme.textPrimaryOf(context)),
            decoration: InputDecoration(
              labelText: 'Percentage (1-100)',
              labelStyle: TextStyle(color: AppTheme.textSecondaryOf(context)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.dividerOf(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.dividerOf(context)),
              ),
              filled: true,
              fillColor: AppTheme.inputFillOf(context),
            ),
          ),
          const SizedBox(height: 12),

          // Target
          Text('Who gets this discount?',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textPrimaryOf(context))),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text('Everyone',
                    style: TextStyle(color: AppTheme.textPrimaryOf(context))),
                selected: _target == 'all',
                onSelected: (_) => setState(() => _target = 'all'),
                selectedColor: AppTheme.successColor.withValues(alpha: 0.35),
                checkmarkColor: Colors.white,
              ),
              ChoiceChip(
                label: Text('Pledgers',
                    style: TextStyle(color: AppTheme.textPrimaryOf(context))),
                selected: _target == 'pledgers',
                onSelected: (_) => setState(() => _target = 'pledgers'),
                selectedColor: AppTheme.successColor.withValues(alpha: 0.35),
                checkmarkColor: Colors.white,
              ),
              if (_discountType != 'pledge_percent')
                ChoiceChip(
                  label: Text('Non-Pledgers',
                      style: TextStyle(color: AppTheme.textPrimaryOf(context))),
                  selected: _target == 'non_pledgers',
                  onSelected: (_) =>
                      setState(() => _target = 'non_pledgers'),
                  selectedColor:
                      AppTheme.successColor.withValues(alpha: 0.35),
                  checkmarkColor: Colors.white,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _discountType == 'ticket_percent'
                ? 'Discount = value% off the ticket price.'
                : 'Discount = value% of the customer\'s total pledge amount.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.textSecondaryOf(context)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Discount'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerOf(context)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: context.sponsorAccent.withValues(alpha: 0.15),
          child: Icon(_typeIcon(d['discount_type'] ?? ''),
              color: context.sponsorAccent, size: 20),
        ),
        title: Text(d['name'] ?? 'Discount',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryOf(context))),
        subtitle: Text(_describe(d),
            style: TextStyle(
                fontSize: 13, color: AppTheme.textSecondaryOf(context))),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
          onPressed: () => _delete(d['id']),
        ),
      ),
    );
  }
}
