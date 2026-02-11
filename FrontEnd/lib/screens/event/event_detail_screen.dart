import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../services/api_service.dart';

class EventDetailScreen extends StatefulWidget {
  final int eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().loadEvent(widget.eventId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();
    final auth = context.watch<AuthProvider>();
    final event = eventProvider.selectedEvent;
    final user = auth.user;
    final dateFormat = DateFormat('MMM dd, yyyy h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Text(event?.title ?? 'Event Details'),
      ),
      body: eventProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : eventProvider.error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(eventProvider.error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () =>
                            eventProvider.loadEvent(widget.eventId),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : event == null
                  ? const Center(child: Text('Event not found'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 700),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title & Status
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      event.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      event.status.name
                                          .replaceAll('_', ' ')
                                          .toUpperCase(),
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    backgroundColor: _statusColor(event.status),
                                    side: BorderSide.none,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Description
                              if (event.description != null &&
                                  event.description!.isNotEmpty) ...[
                                Text(
                                  event.description!,
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.grey[700]),
                                ),
                                const SizedBox(height: 24),
                              ],

                              // Info cards
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      _infoRow(Icons.calendar_today, 'Start',
                                          dateFormat.format(event.startTime)),
                                      const Divider(),
                                      _infoRow(Icons.calendar_today, 'End',
                                          dateFormat.format(event.endTime)),
                                      const Divider(),
                                      _infoRow(Icons.people, 'Capacity',
                                          '${event.maxCapacity}'),
                                      const Divider(),
                                      _infoRow(
                                          Icons.how_to_reg,
                                          'Registration',
                                          event.registrationType.name
                                              .replaceAll('_', ' ')),
                                      if (event.fundingGoalCents != null &&
                                          event.fundingGoalCents! > 0) ...[
                                        const Divider(),
                                        _infoRow(
                                            Icons.attach_money,
                                            'Funding Goal',
                                            '\$${(event.fundingGoalCents! / 100).toStringAsFixed(2)}'),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Actions for customers
                              if (user != null && user.isCustomer) ...[
                                _sectionTitle(context, 'Actions'),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () =>
                                            _register(context),
                                        icon: const Icon(Icons.how_to_reg),
                                        label: const Text('Register'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppTheme.primaryColor,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                    if (event.fundingGoalCents != null &&
                                        event.fundingGoalCents! > 0) ...[
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _showPledgeDialog(context),
                                          icon: const Icon(
                                              Icons.volunteer_activism),
                                          label: const Text('Pledge'),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],

                              // Actions for organizers
                              if (user != null &&
                                  (user.isOrganizer || user.isAdmin)) ...[
                                const SizedBox(height: 24),
                                _sectionTitle(context, 'Organizer Actions'),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (event.status == EventStatus.draft)
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          await eventProvider
                                              .submitEvent(event.id);
                                        },
                                        icon:
                                            const Icon(Icons.send, size: 18),
                                        label: const Text(
                                            'Submit for Approval'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppTheme.primaryColor,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        await eventProvider
                                            .cancelEvent(event.id);
                                      },
                                      icon: const Icon(Icons.cancel,
                                          size: 18,
                                          color: AppTheme.errorColor),
                                      label: const Text('Cancel Event',
                                          style: TextStyle(
                                              color: AppTheme.errorColor)),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.grey[700])),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Color _statusColor(EventStatus status) {
    switch (status) {
      case EventStatus.draft:
        return Colors.grey.shade200;
      case EventStatus.pending_approval:
        return AppTheme.warningColor.withValues(alpha: 0.2);
      case EventStatus.approved:
        return AppTheme.successColor.withValues(alpha: 0.2);
      case EventStatus.live:
        return AppTheme.secondaryColor.withValues(alpha: 0.2);
      case EventStatus.ended:
        return AppTheme.primaryColor.withValues(alpha: 0.2);
      case EventStatus.cancelled:
        return AppTheme.errorColor.withValues(alpha: 0.2);
    }
  }

  Future<void> _register(BuildContext context) async {
    try {
      final api = context.read<ApiService>();
      await api.register(widget.eventId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registered successfully!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $e')),
        );
      }
    }
  }

  Future<void> _showPledgeDialog(BuildContext context) async {
    final amountController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Make a Pledge'),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount (\$)',
            prefixText: '\$ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) return;

              try {
                final api = context.read<ApiService>();
                await api.pledge(widget.eventId, (amount * 100).toInt());
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Pledged \$${amount.toStringAsFixed(2)}!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Pledge failed: $e')),
                  );
                }
              }
            },
            child: const Text('Pledge'),
          ),
        ],
      ),
    );
  }
}
