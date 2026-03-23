import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/design_tokens.dart';
import '../../config/theme.dart';
import '../../providers/poll_provider.dart';
import '../../widgets/event/live_poll_card.dart';

/// Full-screen poll view for attendees — navigated to from LivePollCard.
/// Re-uses PollProvider which is already polling when this screen opens.
class LivePollScreen extends StatelessWidget {
  final int eventId;
  const LivePollScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Poll')),
      body: Consumer<PollProvider>(
        builder: (context, provider, _) {
          final poll = provider.activePoll;

          if (poll == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.poll_rounded,
                      size: 56, color: AppTheme.textSecondaryOf(context)),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No active poll right now',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: LivePollCard(poll: poll, eventId: eventId),
          );
        },
      ),
    );
  }
}
