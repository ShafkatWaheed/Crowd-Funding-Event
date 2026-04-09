import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/design_tokens.dart';
import '../../config/theme.dart';
import '../../models/chat.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_firebase_provider.dart';
import '../../widgets/portal/event_portal_card.dart';

/// Show the Portal sheet with premium design.
Future<void> showPortalSheet(BuildContext context, {VoidCallback? onFullView}) {
  final isDark = AppTheme.isDark(context);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.6),
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
            // Gradient header: card fades to surface
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: const Alignment(0, 0.3),
              colors: [
                isDark ? const Color(0xFF1A1A2E) : AppTheme.cardOf(ctx),
                AppTheme.surfaceOf(ctx),
              ],
            ),
            borderRadius: AppRadius.topXxl,
            boxShadow: AppShadow.elevated(isDark),
          ),
          child: Column(
            children: [
              // Drag handle — wider, subtle glow
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.3),
                    borderRadius: AppRadius.pill,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentColor.withValues(alpha: 0.1),
                        blurRadius: 8,
                      ),
                    ],
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
  String? _expandedKey;

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
      children: [
        // ── Header ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
          child: Row(
            children: [
              // Title with accent underline effect
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Portal',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimaryOf(context), letterSpacing: -0.3)),
                  const SizedBox(height: 2),
                  Container(
                    width: 24, height: 2,
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor,
                      borderRadius: AppRadius.pill,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Full View pill button with glow
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  widget.onFullView?.call();
                },
                borderRadius: AppRadius.pill,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.1),
                    border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.25)),
                    borderRadius: AppRadius.pill,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentColor.withValues(alpha: 0.12),
                        blurRadius: 10,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Full View',
                          style: TextStyle(fontSize: 11, color: AppTheme.accentColor, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 3),
                      Icon(Icons.open_in_new_rounded, size: 12, color: AppTheme.accentColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xs),

        // ── Search bar — filled style ───────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            style: TextStyle(fontSize: 12, color: AppTheme.textPrimaryOf(context)),
            decoration: InputDecoration(
              hintText: 'Search events, tickets...',
              hintStyle: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.6)),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: Icon(Icons.search_rounded, size: 18, color: AppTheme.accentColor.withValues(alpha: 0.6)),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0),
              isDense: true,
              filled: true,
              fillColor: AppTheme.inputFillOf(context),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: AppRadius.md,
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.md,
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.md,
                borderSide: BorderSide(color: AppTheme.accentColor.withValues(alpha: 0.3), width: 1),
              ),
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // ── Event cards ─────────────────────────────────
        Flexible(
          child: provider.loadingMyEvents && provider.myEventCards.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.accentColor.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Loading events...',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
                    ],
                  ),
                )
              : _filtered.isEmpty
                  ? _emptyState(context)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      shrinkWrap: true,
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        // Stagger animation per card
                        return _StaggeredCard(
                          index: index,
                          child: EventPortalCard(
                            card: _filtered[index],
                            inlineMode: true,
                            expandedKey: _expandedKey,
                            onToggleExpand: _toggleExpand,
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event_note_rounded, size: 32, color: AppTheme.accentColor.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            _search.isEmpty ? 'No Events Yet' : 'No matching events',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryOf(context)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _search.isEmpty
                ? 'Your events will appear here once you\npurchase tickets or make pledges.'
                : 'Try a different search term.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context), height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Stagger-in animation for each card in the list.
class _StaggeredCard extends StatefulWidget {
  final int index;
  final Widget child;

  const _StaggeredCard({required this.index, required this.child});

  @override
  State<_StaggeredCard> createState() => _StaggeredCardState();
}

class _StaggeredCardState extends State<_StaggeredCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // Stagger delay: 60ms per card, max 300ms
    final delay = Duration(milliseconds: (widget.index * 60).clamp(0, 300));
    Future.delayed(delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _opacity,
        child: widget.child,
      ),
    );
  }
}
