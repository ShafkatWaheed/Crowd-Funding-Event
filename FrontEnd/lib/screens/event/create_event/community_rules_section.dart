import 'package:flutter/material.dart';

import '../../../config/theme.dart';

class CommunityRulesSection extends StatelessWidget {
  final bool communityRules;
  final bool communityRulesFeatureEnabled;
  final ValueChanged<bool> onCommunityRulesChanged;
  final bool postsEnabled;
  final ValueChanged<bool> onPostsEnabledChanged;
  final bool faqEnabled;
  final ValueChanged<bool> onFaqEnabledChanged;

  const CommunityRulesSection({
    super.key,
    required this.communityRules,
    this.communityRulesFeatureEnabled = true,
    required this.onCommunityRulesChanged,
    required this.postsEnabled,
    required this.onPostsEnabledChanged,
    this.faqEnabled = false,
    required this.onFaqEnabledChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: communityRules
                ? context.fundingAccent.withValues(alpha: 0.08)
                : AppTheme.cardOf(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: communityRules
                    ? context.fundingAccent.withValues(alpha: 0.4)
                    : AppTheme.dividerOf(context)),
          ),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    Icon(Icons.groups_rounded,
                        size: 20,
                        color: communityRules
                            ? context.fundingAccent
                            : AppTheme.textSecondaryOf(context)),
                    const SizedBox(width: 8),
                    const Text('Community Event Rules',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ],
                ),
                subtitle: Text(
                  communityRulesFeatureEnabled
                      ? 'Enables max duration, ticket price caps, and listing fee'
                      : 'Community rules are currently disabled by the platform',
                  style: const TextStyle(fontSize: 11),
                ),
                value: communityRules,
                activeTrackColor: context.fundingAccent,
                onChanged: communityRulesFeatureEnabled
                    ? onCommunityRulesChanged
                    : null,
              ),
              if (communityRules) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 10),
                  child: Text(
                    '\u2022 Max duration: configurable (default 14 days)\n'
                    '\u2022 Max ticket price: configurable (default \$50)\n'
                    '\u2022 Listing fee charged on publish\n'
                    '\u2022 Rules are set by platform admin in Settings',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryOf(context),
                        height: 1.5),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Enable event feed / posts',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle:
              const Text('Registered users can post on the event wall'),
          value: postsEnabled,
          activeTrackColor: AppTheme.accentColor,
          onChanged: onPostsEnabledChanged,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          title: const Text('Enable FAQ',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle:
              const Text('Show your FAQ library on this event page'),
          value: faqEnabled,
          activeTrackColor: AppTheme.accentColor,
          onChanged: onFaqEnabledChanged,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}
