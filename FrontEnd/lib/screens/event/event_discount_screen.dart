import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';

class EventDiscountScreen extends StatefulWidget {
  final int eventId;
  const EventDiscountScreen({super.key, required this.eventId});

  @override
  State<EventDiscountScreen> createState() => _EventDiscountScreenState();
}

class _EventDiscountScreenState extends State<EventDiscountScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _discounts = [];
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
      final list = await _api.getEventDiscounts(widget.eventId);
      setState(() {
        _discounts = list.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    final value = int.tryParse(_valueCtrl.text.trim());
    if (name.isEmpty || value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill in name and a valid value')),
      );
      return;
    }
    try {
      await _api.createEventDiscount(widget.eventId, {
        'name': name,
        'discount_type': _discountType,
        'value': value,
        'target': _target,
      });
      _nameCtrl.clear();
      _valueCtrl.clear();
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Discount created')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _delete(int id) async {
    try {
      await _api.deleteEventDiscount(widget.eventId, id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  String _describeDiscount(Map<String, dynamic> d) {
    final type = d['discount_type'] as String? ?? '';
    final val = d['value'] ?? 0;
    final tgt = d['target'] ?? 'all';
    String desc;
    switch (type) {
      case 'ticket_percent':
        desc = '$val% off ticket price';
        break;
      case 'pledge_percent':
        desc = '$val% of pledge amount as discount';
        break;
      case 'fixed_cents':
        desc = '\$${(val / 100).toStringAsFixed(2)} flat discount';
        break;
      default:
        desc = '$val';
    }
    if (tgt == 'pledgers') {
      desc += ' (pledgers only)';
    } else if (tgt == 'non_pledgers') {
      desc += ' (non-pledgers only)';
    }
    return desc;
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'ticket_percent':
        return Icons.percent_rounded;
      case 'pledge_percent':
        return Icons.volunteer_activism_rounded;
      case 'fixed_cents':
        return Icons.attach_money_rounded;
      default:
        return Icons.discount_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
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
        title: const Text('Event Discounts'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Create form
                  _buildCreateForm(),
                  const SizedBox(height: 20),

                  // Existing discounts
                  Text('Active Discounts (${_discounts.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (_discounts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.discount_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text('No discounts yet', style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    )
                  else
                    ..._discounts.map((d) => _buildDiscountCard(d)),
                ],
              ),
      ),
    );
  }

  Widget _buildCreateForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create Discount', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Discount Name',
              hintText: 'e.g. Early Bird, Pledger Reward',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: AppTheme.surfaceColor,
            ),
          ),
          const SizedBox(height: 12),

          // Type
          Text('Discount Type', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('% of Ticket'),
                selected: _discountType == 'ticket_percent',
                onSelected: (_) => setState(() => _discountType = 'ticket_percent'),
                selectedColor: AppTheme.accentColor.withOpacity(0.15),
              ),
              ChoiceChip(
                label: const Text('% of Pledge'),
                selected: _discountType == 'pledge_percent',
                onSelected: (_) => setState(() => _discountType = 'pledge_percent'),
                selectedColor: AppTheme.accentColor.withOpacity(0.15),
              ),
              ChoiceChip(
                label: const Text('Fixed \$'),
                selected: _discountType == 'fixed_cents',
                onSelected: (_) => setState(() => _discountType = 'fixed_cents'),
                selectedColor: AppTheme.accentColor.withOpacity(0.15),
              ),
            ],
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _valueCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _discountType == 'fixed_cents' ? 'Amount (cents)' : 'Percentage (1-100)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: AppTheme.surfaceColor,
            ),
          ),
          const SizedBox(height: 12),

          // Target
          Text('Who gets this discount?', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Everyone'),
                selected: _target == 'all',
                onSelected: (_) => setState(() => _target = 'all'),
                selectedColor: AppTheme.successColor.withOpacity(0.15),
              ),
              ChoiceChip(
                label: const Text('Pledgers'),
                selected: _target == 'pledgers',
                onSelected: (_) => setState(() => _target = 'pledgers'),
                selectedColor: AppTheme.successColor.withOpacity(0.15),
              ),
              ChoiceChip(
                label: const Text('Non-Pledgers'),
                selected: _target == 'non_pledgers',
                onSelected: (_) => setState(() => _target = 'non_pledgers'),
                selectedColor: AppTheme.successColor.withOpacity(0.15),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _discountType == 'ticket_percent'
                ? 'Discount = value% off the ticket price.'
                : _discountType == 'pledge_percent'
                    ? 'Discount = value% of the customer\'s total pledge amount.'
                    : 'Flat discount in cents subtracted from ticket price.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Discount is capped: total discount cannot exceed ticket price.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.warningColor,
                  fontWeight: FontWeight.w600,
                ),
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

  Widget _buildDiscountCard(Map<String, dynamic> d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.accentColor.withOpacity(0.1),
          child: Icon(_typeIcon(d['discount_type'] ?? ''), color: AppTheme.accentColor, size: 20),
        ),
        title: Text(d['name'] ?? 'Discount', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          _describeDiscount(d),
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
          onPressed: () => _delete(d['id']),
        ),
      ),
    );
  }
}
