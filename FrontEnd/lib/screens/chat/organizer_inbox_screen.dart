import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/design_tokens.dart';
import '../../config/theme.dart';
import '../../providers/event_provider.dart';

/// Organizer's chat inbox: shows their events, tap to open event chat hub.
class OrganizerInboxScreen extends StatefulWidget {
  const OrganizerInboxScreen({super.key});

  @override
  State<OrganizerInboxScreen> createState() => _OrganizerInboxScreenState();
}

class _OrganizerInboxScreenState extends State<OrganizerInboxScreen> {
  @override
  void initState() {
    super.initState();
    // EventProvider already has the organizer's events loaded
  }

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();
    final events = eventProvider.events
        .where((e) => e.status.name != 'draft' && e.status.name != 'pending_approval')
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.surfaceOf(context),
      appBar: AppBar(
        title: const Text('Chat Inbox'),
        backgroundColor: AppTheme.cardOf(context),
      ),
      body: events.isEmpty
          ? Center(
              child: Text(
                'No events with chat',
                style: TextStyle(color: AppTheme.textSecondaryOf(context)),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppTheme.cardOf(context),
                    borderRadius: AppRadius.md,
                    border: Border.all(color: AppTheme.dividerOf(context)),
                  ),
                  child: ListTile(
                    onTap: () => context.push('/chat/organizer-hub/${event.id}'),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.event_rounded,
                          color: AppTheme.accentColor, size: 20),
                    ),
                    title: Text(
                      event.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                    subtitle: Text(
                      event.status.name.replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                    trailing: Icon(Icons.chevron_right_rounded,
                        color: AppTheme.textSecondaryOf(context)),
                  ),
                );
              },
            ),
    );
  }
}
