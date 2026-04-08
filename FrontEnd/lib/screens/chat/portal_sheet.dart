import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/design_tokens.dart';
import '../../config/theme.dart';
import '../../models/chat.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_firebase_provider.dart';
import '../../widgets/portal/event_portal_card.dart';

/// Show the Portal sheet with a smooth spring animation.
/// [onFullView] is called when user taps "Full View".
Future<void> showPortalSheet(BuildContext context, {VoidCallback? onFullView}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    useSafeArea: true,
    builder: (ctx) {
      return AnimatedPadding(
        duration: const Duration(milliseconds: 100),
        padding: EdgeInsets.only(top: MediaQuery.of(ctx).size.height * 0.08),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: AppTheme.cardOf(ctx),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.dividerOf(ctx),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Flexible(child: _PortalSheetContent(onFullView: onFullView)),
            ],
          ),
        ),
      );
    },
  );
}

class _PortalSheetContent extends StatefulWidget {
  final VoidCallback? onFullView;

  const _PortalSheetContent({this.onFullView});

  @override
  State<_PortalSheetContent> createState() => _PortalSheetContentState();
}

class _PortalSheetContentState extends State<_PortalSheetContent> {
  String _search = '';
  String? _expandedKey; // single expand across all cards

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      final isOrg = user != null && (user.isOrganizer || user.isAdmin);
      context.read<ChatFirebaseProvider>().loadMyEvents(userId: user?.id, isOrganizer: isOrg);
    });
  }

  List<MyEventCard> get _filtered {
    if (_search.isEmpty) return context.read<ChatFirebaseProvider>().myEventCards;
    final q = _search.toLowerCase();
    return context.read<ChatFirebaseProvider>().myEventCards.where((c) {
      return c.eventTitle.toLowerCase().contains(q) ||
          (c.venueName?.toLowerCase().contains(q) ?? false) ||
          c.tickets.any((t) =>
              (t.tierName?.toLowerCase().contains(q) ?? false) ||
              t.ticketCode.toLowerCase().contains(q));
    }).toList();
  }

  void _toggleExpand(String key) {
    setState(() {
      _expandedKey = _expandedKey == key ? null : key;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatFirebaseProvider>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              Text('My Events',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryOf(context))),
              const Spacer(),
              InkWell(
                onTap: () {
                  Navigator.pop(context); // dismiss sheet
                  widget.onFullView?.call();
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.1),
                    border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Full View ↗',
                      style: TextStyle(fontSize: 10, color: AppTheme.accentColor, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),

        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            style: const TextStyle(fontSize: 11),
            decoration: InputDecoration(
              hintText: 'Search events, tickets...',
              hintStyle: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
              prefixIcon: Icon(Icons.search, size: 16, color: AppTheme.textSecondaryOf(context)),
              prefixIconConstraints: const BoxConstraints(minWidth: 36),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: AppRadius.sm,
                borderSide: BorderSide(color: AppTheme.dividerOf(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.sm,
                borderSide: BorderSide(color: AppTheme.dividerOf(context)),
              ),
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Event cards list
        Flexible(
          child: provider.loadingMyEvents && provider.myEventCards.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
              : _filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_note_outlined, size: 48, color: AppTheme.textSecondaryOf(context)),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _search.isEmpty ? 'No Events Yet' : 'No matching events',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(context)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _search.isEmpty
                                ? 'Your events will appear here once you purchase tickets or make pledges.'
                                : 'Try a different search term.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      shrinkWrap: true,
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        return EventPortalCard(
                          card: _filtered[index],
                          inlineMode: true,
                          expandedKey: _expandedKey,
                          onToggleExpand: _toggleExpand,
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
