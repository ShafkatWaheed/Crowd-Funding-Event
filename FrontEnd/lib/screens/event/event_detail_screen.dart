import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_animate/flutter_animate.dart';

import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../config/design_tokens.dart';
import '../../models/event.dart';
import '../../models/event_image.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../widgets/animated_list_item.dart';
import '../../widgets/press_feedback.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/event_lifecycle_bar.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/fullscreen_image_viewer.dart';
import '../../services/api_service.dart';
import 'event_detail/event_detail.dart';

class EventDetailScreen extends StatefulWidget {
  final int eventId;

  final Event? previewEvent;
  final List<Uint8List>? previewImages;

  /// When true (e.g. from admin user detail), hide edit/delete and organizer actions.
  final bool readOnly;

  bool get isPreview => previewEvent != null;

  const EventDetailScreen({
    super.key,
    required this.eventId,
    this.previewEvent,
    this.previewImages,
    this.readOnly = false,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  List<EventImage> _images = [];
  final ScrollController _scrollCtrl = ScrollController();
  bool _scrolledPastHero = false;
  static const double _heroHeight = 300;

  // Registration state
  bool _isRegistered = false;
  String? _regStatus; // 'registered', 'waitlisted', 'cancelled'
  bool _regLoading = false;

  // My ticket count for this event
  int _myTicketCount = 0;
  // My actual tickets for this event (for "Your Tickets" section)
  List<Map<String, dynamic>> _myEventTickets = [];
  // My reserved spots for this event (from pledges)
  int _myReservedSpots = 0;

  // Revenue (organizer only)
  int _revenueCents = 0;

  // Bookmark state
  bool _bookmarked = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    if (!widget.isPreview) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<EventProvider>().loadEvent(widget.eventId);
        _loadImages();
        _checkRegistration();
        _loadMyTicketCount();
        _loadMyReservedSpots();
        _loadRevenue();
        _checkBookmark();
      });
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final past = _scrollCtrl.offset > _heroHeight - kToolbarHeight;
    if (past != _scrolledPastHero) setState(() => _scrolledPastHero = past);
  }

  Future<void> _checkBookmark() async {
    try {
      final api = context.read<ApiService>();
      final res = await api.checkBookmarks([widget.eventId]);
      final ids = (res['bookmarked_ids'] as List?)?.cast<int>() ?? [];
      if (mounted) setState(() => _bookmarked = ids.contains(widget.eventId));
    } catch (_) {}
  }

  Future<void> _toggleBookmark() async {
    try {
      final api = context.read<ApiService>();
      final res = await api.toggleBookmark(widget.eventId);
      if (mounted) setState(() => _bookmarked = res['bookmarked'] == true);
    } catch (_) {}
  }

  Future<void> _refreshAll() async {
    final eventProvider = context.read<EventProvider>();
    await Future.wait([
      eventProvider.loadEvent(widget.eventId),
      _loadImages(),
      _checkRegistration(),
      _loadMyTicketCount(),
      _loadMyReservedSpots(),
      _loadRevenue(),
    ]);
  }

  // _loadPosts moved into _EventFeed widget

  Future<void> _loadImages() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getEventImages(widget.eventId);
      setState(() {
        _images = data.map((i) => EventImage.fromJson(i)).toList();
      });
    } catch (_) {}
  }

  Future<void> _checkRegistration() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    try {
      final api = context.read<ApiService>();
      final data = await api.getMyRegistration(widget.eventId);
      setState(() {
        _isRegistered = data['registered'] == true;
        _regStatus = data['status'];
      });
    } catch (_) {}
  }

  Future<void> _loadMyTicketCount() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null || !user.isCustomer) return;
    try {
      final api = context.read<ApiService>();
      final tickets = await api.getMyTickets();
      final myTickets = tickets.where((t) =>
          t['event_id'] == widget.eventId &&
          (t['status'] == 'purchased' || t['status'] == 'waitlisted' || t['status'] == 'refund_requested')).toList();
      if (mounted) {
        setState(() {
          _myTicketCount = myTickets.length;
          _myEventTickets = myTickets.cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMyReservedSpots() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null || !(user.isCustomer || user.isSponsor)) return;
    try {
      final api = context.read<ApiService>();
      final pledges = await api.getMyPledges();
      final spots = pledges
          .where((p) => p['event_id'] == widget.eventId && p['status'] == 'pledged')
          .fold<int>(0, (sum, p) => sum + ((p['reserved_spots'] ?? 0) as int));
      if (mounted) setState(() => _myReservedSpots = spots);
    } catch (_) {}
  }

  Future<void> _loadRevenue() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null || (!user.isOrganizer && !user.isAdmin)) return;
    try {
      final api = context.read<ApiService>();
      final sales = await api.getTicketSales(widget.eventId);
      final total = sales.fold<int>(
          0, (s, e) => s + ((e['amount_paid_cents'] ?? 0) as int));
      if (mounted) setState(() => _revenueCents = total);
    } catch (_) {}
  }

  // _loadMyReaction and _react moved into ReactionBar widget

  // _submitPost moved into _EventFeed widget

  // _deletePost moved into _EventFeed widget

  @override
  Widget build(BuildContext context) {
    final eventProvider = widget.isPreview ? null : context.watch<EventProvider>();
    final auth = context.watch<AuthProvider>();
    final event = widget.isPreview ? widget.previewEvent : eventProvider!.selectedEvent;
    final user = widget.isPreview ? null : auth.user;
    final isDark = AppTheme.isDark(context);
    final dateFormat = DateFormat('MMM dd, yyyy h:mm a');

    final hasPreviewImages = widget.isPreview && widget.previewImages != null && widget.previewImages!.isNotEmpty;
    final heroUrl = !widget.isPreview && _images.isNotEmpty ? _images.first.imageUrl : null;
    final hasHero = heroUrl != null || hasPreviewImages;

    return Scaffold(
      bottomNavigationBar: !widget.isPreview && event != null && _scrolledPastHero
          ? AnimatedSlide(
              offset: _scrolledPastHero ? Offset.zero : const Offset(0, 1),
              duration: AppDuration.fast,
              curve: AppCurve.enter,
              child: AnimatedOpacity(
                opacity: _scrolledPastHero ? 1.0 : 0.0,
                duration: AppDuration.fast,
                child: Container(
                  padding: EdgeInsets.only(
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                    top: AppSpacing.sm,
                    bottom: MediaQuery.of(context).padding.bottom + AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceOf(context),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: _buildQuickActionBar(context, event, user),
                ),
              ),
            )
          : null,
      body: !widget.isPreview && eventProvider!.isLoading
          ? const ShimmerDetailHeader()
          : !widget.isPreview && eventProvider!.error != null
              ? ErrorState(
                  message: eventProvider.error!,
                  onRetry: () => eventProvider.loadEvent(widget.eventId),
                )
              : event == null
                  ? const EmptyState(
                      icon: Icons.event_busy_rounded,
                      title: 'Event not found',
                    )
                  : RefreshIndicator(
                      onRefresh: _refreshAll,
                      child: CustomScrollView(
                        controller: _scrollCtrl,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverAppBar(
                            expandedHeight: hasHero ? _heroHeight : 0,
                            pinned: true,
                            stretch: hasHero,
                            backgroundColor: AppTheme.surfaceOf(context),
                            surfaceTintColor: Colors.transparent,
                            leading: IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(AppSpacing.xs),
                                decoration: BoxDecoration(
                                  color: _scrolledPastHero || !hasHero
                                      ? Colors.transparent
                                      : AppTheme.surfaceOf(context).withValues(alpha: 0.7),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: AppIconSize.sm),
                              ),
                              onPressed: () {
                                if (Navigator.of(context).canPop()) {
                                  context.pop();
                                } else {
                                  context.go('/');
                                }
                              },
                            ),
                            title: AnimatedOpacity(
                              opacity: _scrolledPastHero || !hasHero ? 1.0 : 0.0,
                              duration: AppDuration.fast,
                              child: Row(
                                children: [
                                  if (widget.isPreview || widget.readOnly) ...[
                                    if (widget.readOnly)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppTheme.accentColor.withValues(alpha: 0.15),
                                          borderRadius: AppRadius.pill,
                                          border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.4)),
                                        ),
                                        child: Text('VIEW ONLY (ADMIN)',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                                            color: AppTheme.accentColor, letterSpacing: 0.5)),
                                      ),
                                    if (widget.isPreview)
                                      Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.warningColor.withValues(alpha: 0.15),
                                        borderRadius: AppRadius.pill,
                                        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.4)),
                                      ),
                                        child: Text('PREVIEW',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                                            color: AppTheme.warningColor, letterSpacing: 0.5)),
                                      ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: Text(
                                      event.title,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            actions: [
                              if (!widget.isPreview) ...[
                                IconButton(
                                  icon: Container(
                                    padding: const EdgeInsets.all(AppSpacing.xs),
                                    decoration: BoxDecoration(
                                      color: _scrolledPastHero || !hasHero
                                          ? Colors.transparent
                                          : AppTheme.surfaceOf(context).withValues(alpha: 0.7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                      size: AppIconSize.sm,
                                      color: _bookmarked ? AppTheme.accentColor : null,
                                    ),
                                  ),
                                  onPressed: _toggleBookmark,
                                ),
                                AppSpacing.hXs,
                              ],
                            ],
                            flexibleSpace: hasHero
                                ? FlexibleSpaceBar(
                                    collapseMode: CollapseMode.parallax,
                                    stretchModes: const [StretchMode.zoomBackground],
                                    background: GestureDetector(
                                      onTap: widget.isPreview ? null : () => _openImageViewer(0),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (hasPreviewImages)
                                            Image.memory(widget.previewImages!.first, fit: BoxFit.cover)
                                          else
                                            Image.network(
                                              ApiConfig.imageUrl(heroUrl!),
                                              fit: BoxFit.cover,
                                              loadingBuilder: (context, child, progress) {
                                                if (progress == null) return child;
                                                return Container(
                                                  color: AppTheme.cardOf(context),
                                                  child: const Center(
                                                    child: CircularProgressIndicator(strokeWidth: 2),
                                                  ),
                                                );
                                              },
                                              errorBuilder: (_, __, ___) => Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [
                                                      AppTheme.accentColor.withValues(alpha: 0.15),
                                                      AppTheme.secondaryColor.withValues(alpha: 0.15),
                                                    ],
                                                  ),
                                                ),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.image_rounded, size: 48,
                                                        color: AppTheme.textSecondaryOf(context)),
                                                    AppSpacing.vSm,
                                                    Text('Image could not be loaded',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: AppTheme.textSecondaryOf(context),
                                                        )),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          const DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [Colors.black26, Colors.transparent, Colors.black38],
                                                stops: [0.0, 0.4, 1.0],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: AppSpacing.paddingXl,
                              child: Center(
                                child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 700),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                              // ── Hero Header ──
                              Text(
                                event.title,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.8,
                                  height: 1.15,
                                  color: AppTheme.textPrimaryOf(context),
                                ),
                              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, duration: 400.ms, curve: AppCurve.enter),
                              AppSpacing.vMd,

                              // Status pill + Genre + Registration count
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _statusPill(context, event.status),
                                  if (event.genre != null && event.genre!.isNotEmpty)
                                    _tagPill(
                                      icon: Icons.category_rounded,
                                      label: event.genre![0].toUpperCase() + event.genre!.substring(1),
                                      color: AppTheme.secondaryColor,
                                    ),
                                  if (event.registrationCount > 0)
                                    _tagPill(
                                      icon: Icons.group_rounded,
                                      label: '${event.registrationCount} joined',
                                      color: AppTheme.accentColor,
                                    ),
                                  // Organizer name + Trust badge (tappable)
                                  if (event.organizerName != null && event.organizerName!.isNotEmpty)
                                    GestureDetector(
                                      onTap: () => _showOrganizerBottomSheet(event),
                                      child: _tagPill(
                                        icon: Icons.person_rounded,
                                        label: event.organizerName!,
                                        color: AppTheme.accentColor,
                                      ),
                                    ),
                                  GestureDetector(
                                    onTap: () => _showOrganizerBottomSheet(event),
                                    child: _trustBadgePill(context, event),
                                  ),
                                  if (_revenueCents > 0 && user != null &&
                                      (user.isOrganizer || user.isAdmin) &&
                                      !widget.readOnly)
                                    _tagPill(
                                      icon: Icons.paid_rounded,
                                      label: '\$${(_revenueCents / 100).toStringAsFixed(0)} revenue',
                                      color: context.ticketAccent,
                                    ),
                                ],
                              ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideX(begin: -0.05, duration: 300.ms),
                              AppSpacing.vLg,

                              // Preview info banner
                              if (widget.isPreview) ...[
                                _previewBanner(context),
                                AppSpacing.vLg,
                              ],

                              // Lifecycle progress bar
                              EventLifecycleBar(event: event),
                              AppSpacing.vLg,

                              // ── Quick Action Bar (Register, Share, Calendar) ──
                              if (!widget.isPreview) ...[
                                _buildQuickActionBar(context, event, user),
                                AppSpacing.vXl,
                              ],

                              // Like / Dislike — self-contained widget
                              if (!widget.isPreview) ...[
                                ReactionBar(
                                  eventId: widget.eventId,
                                  initialLikeCount: event.likeCount,
                                  initialDislikeCount: event.dislikeCount,
                                  isAdmin: user?.isAdmin ?? false,
                                ),
                                AppSpacing.vXl,
                              ],

                              // Image gallery (preview: local bytes; normal: network images)
                              if (widget.isPreview && widget.previewImages != null && widget.previewImages!.length > 1) ...[
                                _sectionTitle(context, 'Photos', icon: Icons.photo_library_rounded, iconColor: context.photoAccent),
                                AppSpacing.vSm,
                                SizedBox(
                                  height: 180,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: widget.previewImages!.length,
                                    separatorBuilder: (_, __) => AppSpacing.hSm,
                                    itemBuilder: (ctx, i) {
                                      return ClipRRect(
                                        borderRadius: AppRadius.md,
                                        child: Image.memory(
                                          widget.previewImages![i],
                                          height: 180,
                                          width: 260,
                                          fit: BoxFit.cover,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                AppSpacing.vXxl,
                              ] else if (!widget.isPreview && _images.isNotEmpty) ...[
                                _sectionTitle(context, 'Photos', icon: Icons.photo_library_rounded, iconColor: context.photoAccent),
                                AppSpacing.vSm,
                                SizedBox(
                                  height: 180,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _images.length,
                                    separatorBuilder: (_, __) =>
                                        AppSpacing.hSm,
                                    itemBuilder: (ctx, i) {
                                      final img = _images[i];
                                      return GestureDetector(
                                        onTap: () => _openImageViewer(i),
                                        child: ClipRRect(
                                          borderRadius: AppRadius.md,
                                          child: Stack(
                                            children: [
                                              Hero(
                                                tag: 'event-image-$i',
                                                child: Image.network(
                                                  ApiConfig.imageUrl(img.imageUrl),
                                                  height: 180,
                                                  width: 260,
                                                  fit: BoxFit.cover,
                                                  loadingBuilder: (context, child, progress) {
                                                    if (progress == null) return child;
                                                    return Container(
                                                      height: 180,
                                                      width: 260,
                                                      color: AppTheme.cardOf(context),
                                                      child: const Center(
                                                        child: CircularProgressIndicator(strokeWidth: 2),
                                                      ),
                                                    );
                                                  },
                                                  errorBuilder:
                                                      (_, __, ___) =>
                                                          Container(
                                                    height: 180,
                                                    width: 260,
                                                    color: AppTheme.cardOf(context),
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(Icons.broken_image_rounded,
                                                            size: 32, color: AppTheme.textSecondaryOf(context)),
                                                        AppSpacing.vXs,
                                                        Text('Failed to load',
                                                            style: TextStyle(fontSize: 11,
                                                                color: AppTheme.textSecondaryOf(context))),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              if (img.caption != null &&
                                                  img.caption!.isNotEmpty)
                                                Positioned(
                                                  bottom: 0,
                                                  left: 0,
                                                  right: 0,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    color: Colors.black54,
                                                    child: Text(
                                                      img.caption!,
                                                      style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                              if (user != null &&
                                                  (user.isOrganizer ||
                                                      user.isAdmin) &&
                                                  !widget.readOnly)
                                                Positioned(
                                                  top: 4,
                                                  right: 4,
                                                  child: GestureDetector(
                                                    onTap: () async {
                                                      final api =
                                                          context.read<
                                                              ApiService>();
                                                      await api
                                                          .deleteEventImage(
                                                              widget.eventId,
                                                              img.id);
                                                      _loadImages();
                                                    },
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              4),
                                                      decoration:
                                                          const BoxDecoration(
                                                        color: Colors.black54,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                          Icons.close,
                                                          size: AppIconSize.sm,
                                                          color: Colors.white),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                if (user != null &&
                                    (user.isOrganizer || user.isAdmin) &&
                                    !widget.readOnly) ...[
                                  AppSpacing.vSm,
                                  _addImageButton(context),
                                ],
                                AppSpacing.vXxl,
                              ] else if (!widget.isPreview && user != null &&
                                  (user.isOrganizer || user.isAdmin) &&
                                  !widget.readOnly) ...[
                                _sectionTitle(context, 'Photos', icon: Icons.photo_library_rounded, iconColor: context.photoAccent),
                                AppSpacing.vSm,
                                _addImageButton(context),
                                AppSpacing.vXxl,
                              ],

                              // ── Description ──
                              if (event.description != null &&
                                  event.description!.isNotEmpty) ...[
                                AnimatedListItem(
                                  index: 0,
                                  child: Container(
                                  width: double.infinity,
                                  padding: AppSpacing.paddingLg,
                                  decoration: BoxDecoration(
                                    color: AppTheme.cardOf(context),
                                    borderRadius: AppRadius.lg,
                                    boxShadow: AppShadow.card(isDark),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.article_rounded, size: AppIconSize.sm, color: AppTheme.textSecondaryOf(context)),
                                          AppSpacing.hSm,
                                          Text('About',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.textSecondaryOf(context),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      AppSpacing.vSm,
                                      Text(
                                        event.description!,
                                        style: TextStyle(
                                          fontSize: 15,
                                          height: 1.5,
                                          color: AppTheme.textPrimaryOf(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ),
                                AppSpacing.vXl,
                              ],

                              // ── Funding Card (self-contained) ──
                              if (event.fundingGoalCents != null &&
                                  event.fundingGoalCents! > 0) ...[
                                if (widget.isPreview) ...[
                                  _previewPlaceholder(context, 'Funding progress will appear after publishing', Icons.attach_money_rounded),
                                  AppSpacing.vXxl,
                                  _previewPlaceholder(context, 'Milestones will appear after publishing', Icons.flag_rounded),
                                  AppSpacing.vXxl,
                                ] else ...[
                                  AnimatedListItem(
                                    index: 1,
                                    child: FundingCard(
                                      eventId: widget.eventId,
                                      event: event,
                                      isRegistered: _isRegistered,
                                    ),
                                  ),
                                  AppSpacing.vXxl,
                                  AnimatedListItem(
                                    index: 2,
                                    child: MilestoneTimeline(
                                      eventId: widget.eventId,
                                      event: event,
                                    ),
                                  ),
                                  AppSpacing.vXxl,
                                ],
                              ],

                              // ── Event Schedule (self-contained) ──
                              if (widget.isPreview)
                                _previewPlaceholder(context, 'Schedule will appear after publishing', Icons.schedule_rounded)
                              else
                                AnimatedListItem(
                                  index: 3,
                                  child: EventScheduleSection(
                                    eventId: widget.eventId,
                                    event: event,
                                  ),
                                ),

                              // ── Event Details Grid ──
                              AnimatedListItem(
                                index: 4,
                                child: Container(
                                width: double.infinity,
                                padding: AppSpacing.paddingLg,
                                decoration: BoxDecoration(
                                  color: AppTheme.cardOf(context),
                                  borderRadius: AppRadius.lg,
                                  boxShadow: AppShadow.card(isDark),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.info_outline_rounded, size: AppIconSize.sm, color: AppTheme.textSecondaryOf(context)),
                                        AppSpacing.hSm,
                                        Text('Details',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textSecondaryOf(context),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    AppSpacing.vMd,
                                    if (event.startTime != null)
                                      _modernInfoRow(Icons.event_rounded, 'Starts', dateFormat.format(event.startTime!)),
                                    if (event.endTime != null)
                                      _modernInfoRow(Icons.event_available_rounded, 'Ends', dateFormat.format(event.endTime!)),
                                    if (event.startTime == null && event.endTime == null)
                                      _modernInfoRow(Icons.schedule_rounded, 'Date', 'Announced after funding milestone', valueColor: context.fundingAccent),
                                    _modernInfoRow(
                                      Icons.people_alt_rounded,
                                      'Capacity',
                                      event.maxCapacity > 0
                                          ? _capacityLabel(event)
                                          : '${event.registrationCount} registered',
                                      valueColor: event.maxCapacity > 0 && _capacityUsed(event) >= event.maxCapacity
                                          ? AppTheme.errorColor
                                          : null,
                                    ),
                                    _modernInfoRow(Icons.badge_rounded, 'Registration', event.registrationType.name.replaceAll('_', ' ')),
                                    if (event.eventDateDeadline != null)
                                      _modernInfoRow(Icons.hourglass_bottom_rounded, 'Set Event Date By', dateFormat.format(event.eventDateDeadline!)),
                                    if (event.ticketStrategyName != null)
                                      _modernInfoRow(Icons.confirmation_number_rounded, 'Ticket Strategy', event.ticketStrategyName!),
                                    if (event.refundDeadlineDays != null)
                                      _modernInfoRow(
                                        Icons.shield_rounded,
                                        'Refund',
                                        event.refundDeadlineDays! > 0
                                            ? '${event.refundDeadlineDays}d before event starts'
                                            : 'Until event starts',
                                        valueColor: AppTheme.secondaryColor,
                                      ),
                                  ],
                                ),
                              ),
                              ),
                              AppSpacing.vXl,

                              // ── Getting There (Venue Address / Parking / Transport) ──
                              if (event.venue != null || event.hasTransportInfo) ...[
                                AnimatedListItem(
                                  index: 5,
                                  child: Container(
                                  width: double.infinity,
                                  padding: AppSpacing.paddingLg,
                                  decoration: BoxDecoration(
                                    color: AppTheme.cardOf(context),
                                    borderRadius: AppRadius.lg,
                                    boxShadow: AppShadow.card(isDark),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.directions_rounded, size: AppIconSize.sm, color: AppTheme.textSecondaryOf(context)),
                                          AppSpacing.hSm,
                                          Text('Getting There',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.textSecondaryOf(context),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      AppSpacing.vMd,
                                      if (event.venue != null) ...[
                                        _modernInfoRow(Icons.place_rounded, 'Venue', event.venue!.name),
                                        _modernInfoRow(Icons.map_outlined, 'Address', event.venue!.fullAddress),
                                      ],
                                      if (event.parkingInfo != null && event.parkingInfo!.isNotEmpty)
                                        _modernInfoRow(Icons.local_parking_rounded, 'Parking', event.parkingInfo!),
                                      if (event.transitInfo != null && event.transitInfo!.isNotEmpty)
                                        _modernInfoRow(Icons.directions_transit_rounded, 'Transit', event.transitInfo!),
                                      if (event.rideshareInfo != null && event.rideshareInfo!.isNotEmpty)
                                        _modernInfoRow(Icons.local_taxi_rounded, 'Rideshare', event.rideshareInfo!),
                                      if (event.accessibilityInfo != null && event.accessibilityInfo!.isNotEmpty)
                                        _modernInfoRow(Icons.accessible_rounded, 'Accessibility', event.accessibilityInfo!),
                                      if (event.directionsUrl != null) ...[
                                        AppSpacing.vMd,
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: () async {
                                              final uri = Uri.parse(event.directionsUrl!);
                                              if (await canLaunchUrl(uri)) {
                                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                                              }
                                            },
                                            icon: const Icon(Icons.navigation_rounded, size: AppIconSize.sm),
                                            label: const Text('Get Directions'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppTheme.primaryOf(context),
                                              side: BorderSide(color: AppTheme.primaryOf(context).withOpacity(0.4)),
                                              shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                ),
                                AppSpacing.vXl,
                              ],

                              // Pending cancellation banner
                              if (event.pendingCancellation != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: AppSpacing.paddingLg,
                                  decoration: BoxDecoration(
                                    color: AppTheme.warningSurfaceOf(context),
                                    borderRadius: AppRadius.lg,
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(AppSpacing.xs),
                                        decoration: BoxDecoration(
                                          color: AppTheme.warningColor.withValues(alpha: 0.15),
                                          borderRadius: AppRadius.sm,
                                        ),
                                        child: Icon(Icons.hourglass_top_rounded, color: context.fundingAccent, size: AppIconSize.sm),
                                      ),
                                      AppSpacing.hMd,
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Cancellation Pending Admin Approval',
                                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: context.fundingAccent)),
                                            AppSpacing.vXs,
                                            Text(
                                              event.pendingCancellation!['pledge_percent'] != null
                                                  ? '${event.pendingCancellation!['pledge_percent']}% funded — admin must approve cancellation'
                                                  : 'Organizer requested cancellation — awaiting admin review',
                                              style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context)),
                                            ),
                                            if (event.pendingCancellation!['reason'] != null) ...[
                                              AppSpacing.vXs,
                                              Text('Reason: ${event.pendingCancellation!['reason']}',
                                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context), fontStyle: FontStyle.italic)),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AppSpacing.vXl,
                              ],

                              // Cancellation reason banner
                              if (event.status == EventStatus.cancelled &&
                                  event.cancellationReason != null &&
                                  event.cancellationReason!.isNotEmpty) ...[
                                Container(
                                  width: double.infinity,
                                  padding: AppSpacing.paddingLg,
                                  decoration: BoxDecoration(
                                    color: AppTheme.errorSurfaceOf(context),
                                    borderRadius: AppRadius.lg,
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(AppSpacing.xs),
                                        decoration: BoxDecoration(
                                          color: AppTheme.errorColor.withValues(alpha: 0.12),
                                          borderRadius: AppRadius.sm,
                                        ),
                                        child: const Icon(Icons.cancel_rounded, color: AppTheme.errorColor, size: AppIconSize.sm),
                                      ),
                                      AppSpacing.hMd,
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Cancellation Reason',
                                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.errorColor)),
                                            AppSpacing.vXs,
                                            Text(event.cancellationReason!,
                                              style: TextStyle(fontSize: 14, color: AppTheme.textSecondaryOf(context), height: 1.4)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AppSpacing.vXl,
                              ],

                              // Under review banner
                              if (event.status == EventStatus.under_review &&
                                  event.reviewNotes != null &&
                                  event.reviewNotes!.isNotEmpty) ...[
                                Container(
                                  width: double.infinity,
                                  padding: AppSpacing.paddingLg,
                                  decoration: BoxDecoration(
                                    color: AppTheme.warningSurfaceOf(context),
                                    borderRadius: AppRadius.lg,
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(AppSpacing.xs),
                                        decoration: BoxDecoration(
                                          color: AppTheme.warningColor.withValues(alpha: 0.18),
                                          borderRadius: AppRadius.sm,
                                        ),
                                        child: const Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor, size: AppIconSize.sm),
                                      ),
                                      AppSpacing.hMd,
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Under Review',
                                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.warningColor)),
                                            AppSpacing.vXs,
                                            Text(event.reviewNotes!,
                                              style: TextStyle(fontSize: 14, color: AppTheme.textSecondaryOf(context), height: 1.4)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AppSpacing.vXl,
                              ],

                              // ─── Ticket Tiers + Buy + Your Tickets (customer view) ───
                              if (!widget.isPreview) ...[
                                if (event.ticketStrategyId != null &&
                                    (user == null || (!user.isOrganizer && !user.isAdmin) || widget.readOnly)) ...[
                                  AppSpacing.vLg,
                                  _sectionTitle(context, 'Ticket Tiers', icon: Icons.confirmation_number_rounded, iconColor: context.sponsorAccent),
                                  AppSpacing.vSm,
                                ],
                                TicketTiersSection(
                                  event: event,
                                  myTicketCount: _myTicketCount,
                                  myReservedSpots: _myReservedSpots,
                                  myEventTickets: _myEventTickets,
                                  isOrganizer: widget.readOnly ? false : (user?.isOrganizer ?? false),
                                  isAdmin: widget.readOnly ? false : (user?.isAdmin ?? false),
                                  isRegistered: _isRegistered && _regStatus == 'registered',
                                  onPurchaseComplete: () {
                                    _loadMyTicketCount();
                                    _loadMyReservedSpots();
                                  },
                                ),

                                // Your Discounts (customer view only)
                                if (user != null && user.isCustomer) ...[
                                  CustomerDiscountsSection(
                                    eventId: event.id,
                                    onDiscountsChanged: () => setState(() {}),
                                  ),
                                ],
                              ] else ...[
                                if (event.ticketStrategyId != null) ...[
                                  AppSpacing.vLg,
                                  _previewPlaceholder(context, 'Ticket tiers and purchasing will appear after publishing', Icons.confirmation_number_rounded),
                                ],
                              ],

                              // State info banners
                              if (!widget.isPreview) ...[
                                if (event.status == EventStatus.selling_tickets)
                                  _infoBanner('Tickets are now on sale! Grab yours before they sell out.', Icons.confirmation_number, context.ticketAccent),
                                if (event.status == EventStatus.waiting_event_date)
                                  _infoBanner(
                                    'The funding phase is complete. The organizer is finalizing event details — stay tuned for ticket sales!',
                                    Icons.event_note_rounded, context.fundingAccent),
                                if (event.status == EventStatus.completed)
                                  _infoBanner('This event has ended. Thanks for being part of it!', Icons.check_circle, AppTheme.textSecondaryOf(context)),

                                // Sponsor: sponsorship categories access
                                if (user != null &&
                                    user.isSponsor &&
                                    (event.status == EventStatus.approved ||
                                        event.status == EventStatus.waiting_event_date ||
                                        event.status == EventStatus.selling_tickets)) ...[
                                  AppSpacing.vMd,
                                  Container(
                                    width: double.infinity,
                                    padding: AppSpacing.paddingLg,
                                    decoration: BoxDecoration(
                                      color: context.ticketSurface,
                                      borderRadius: AppRadius.lg,
                                      boxShadow: AppShadow.soft(isDark),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          'As a sponsor, you can bid on sponsorships for this event.',
                                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context)),
                                          textAlign: TextAlign.center,
                                        ),
                                        AppSpacing.vSm,
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: () => context.push('/events/${widget.eventId}/sponsorships'),
                                            icon: const Icon(Icons.storefront_rounded, size: AppIconSize.sm),
                                            label: const Text('View Sponsorships'),
                                            style: ElevatedButton.styleFrom(backgroundColor: context.ticketAccent),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AppSpacing.vLg,
                                ],

                                // ──────── Organizer Actions + Management ────────
                                if (user != null &&
                                    (user.isOrganizer || user.isAdmin) &&
                                    !widget.readOnly)
                                  OrganizerManagementSection(
                                    event: event,
                                    isAdmin: user.isAdmin,
                                    isOrganizer: user.isOrganizer,
                                    revenueCents: _revenueCents,
                                    onRefresh: _refreshAll,
                                  ),

                                // ──────── Ticket Tier Management (organizer) ────────
                                if (user != null &&
                                    (user.isOrganizer || user.isAdmin) &&
                                    !widget.readOnly &&
                                    event.ticketStrategyId != null)
                                  TicketTierManagement(
                                      event: event, onTiersChanged: _refreshAll),
                              ],

                              // ──────── Sponsor Carousel (public) ────────
                              if (widget.isPreview)
                                _previewPlaceholder(context, 'Sponsors will appear after publishing', Icons.storefront_rounded)
                              else
                                SponsorCarousel(eventId: widget.eventId),

                              // ──────── Reviews (completed events) ────────
                              if (!widget.isPreview && event.status == EventStatus.completed)
                                ReviewsSection(
                                  eventId: widget.eventId,
                                  organizerId: event.organizerId,
                                )
                              else if (widget.isPreview)
                                _previewPlaceholder(context, 'Reviews will appear after publishing', Icons.rate_review_rounded),

                              // ──────── Event Feed / Posts (self-contained) ────────
                              AppSpacing.vXxxl,
                              if (widget.isPreview)
                                _previewPlaceholder(context, 'Event feed will appear after publishing', Icons.forum_rounded)
                              else
                                EventFeedSection(
                                  eventId: widget.eventId,
                                  postsEnabled: event.postsEnabled,
                                  isRegistered: _isRegistered,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Posts section moved into _EventFeed widget

  // ─── Image viewer ───

  void _openImageViewer(int index) {
    final urls = _images.map((i) => ApiConfig.imageUrl(i.imageUrl)).toList();
    final captions = _images.map((i) => i.caption).toList();
    FullscreenImageViewer.open(
      context,
      imageUrls: urls,
      captions: captions,
      initialIndex: index,
    );
  }

  // ─── Add image button ───

  bool _uploadingImages = false;

  Widget _addImageButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _uploadingImages ? null : () => _pickAndUploadImages(context),
      icon: _uploadingImages
          ? const SizedBox(
              width: AppIconSize.sm,
              height: AppIconSize.sm,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.add_photo_alternate, size: AppIconSize.sm),
      label: Text(_uploadingImages ? 'Uploading...' : 'Add Photos'),
    );
  }

  Future<void> _pickAndUploadImages(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage();
      if (picked.isEmpty) return;

      setState(() => _uploadingImages = true);
      final api = context.read<ApiService>();
      int order = _images.length;

      for (final xFile in picked) {
        final Uint8List bytes = await xFile.readAsBytes();
        await api.uploadEventImage(
          widget.eventId,
          fileBytes: bytes,
          fileName: xFile.name,
          displayOrder: order++,
        );
      }

      await _loadImages();
      if (mounted) {
        AppToast.success(context, '${picked.length} photo${picked.length == 1 ? '' : 's'} added');
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Image upload failed');
      }
    } finally {
      if (mounted) setState(() => _uploadingImages = false);
    }
  }
  // ─── Preview helpers ───

  Widget _previewBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.08),
        borderRadius: AppRadius.md,
        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_rounded, size: AppIconSize.sm, color: AppTheme.warningColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This is a preview. Some sections appear after publishing.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context), height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _previewPlaceholder(BuildContext context, String message, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        borderRadius: AppRadius.md,
        color: AppTheme.surfaceOf(context),
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondaryOf(context), size: AppIconSize.md),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
              style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ───

  /// Total capacity used = reserved spots (unredeemed) + tickets sold.
  /// When a reserved-spot holder buys a ticket their reserved spot is
  /// decremented and tickets_sold incremented, keeping the sum stable.
  /// Once all reserved spots are redeemed, new ticket purchases grow the total.
  int _capacityUsed(Event event) =>
      event.totalReservedSpots + event.ticketsSoldCount;

  /// Human-readable capacity label, e.g. "42 / 100".
  String _capacityLabel(Event event) {
    final used = _capacityUsed(event);
    return '$used / ${event.maxCapacity}';
  }

  Widget _modernInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.surfaceOf(context),
              borderRadius: AppRadius.sm,
            ),
            child: Icon(icon, size: AppIconSize.sm, color: AppTheme.textSecondaryOf(context)),
          ),
          AppSpacing.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryOf(context), letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                        color: valueColor ?? AppTheme.textPrimaryOf(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(BuildContext context, EventStatus status) {
    final label = _statusLabel(status);
    final bgColor = _statusColor(context, status);
    final fgColor = _statusForeground(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: fgColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fgColor, letterSpacing: 0.3)),
        ],
      ),
    );
  }

  Widget _tagPill({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.2)),
        ],
      ),
    );
  }

  void _showOrganizerBottomSheet(Event event) {
    final name = event.organizerName ?? 'Organizer';
    final label = event.organizerTrustLabel;
    final score = event.organizerTrustScore;
    final completed = event.organizerCompletedEvents;
    final published = event.organizerPublishedEvents;
    final pct = (score * 100).toInt();

    Color trustColor;
    IconData trustIcon;
    switch (label) {
      case 'Excellent':
        trustColor = context.trustHigh;
        trustIcon = Icons.verified_rounded;
      case 'Good':
        trustColor = AppTheme.accentColor;
        trustIcon = Icons.verified_outlined;
      case 'Fair':
        trustColor = context.trustMedium;
        trustIcon = Icons.shield_outlined;
      default:
        trustColor = AppTheme.textSecondaryOf(context);
        trustIcon = Icons.person_outline;
    }

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.topXxl,
      ),
      backgroundColor: AppTheme.cardOf(context),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.dividerOf(ctx), borderRadius: AppRadius.sm),
            ),
            AppSpacing.vXl,
            CircleAvatar(
              radius: 30,
              backgroundColor: AppTheme.accentColor.withValues(alpha: 0.15),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.accentColor),
              ),
            ),
            AppSpacing.vMd,
            Text(name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimaryOf(ctx))),
            AppSpacing.vSm,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(trustIcon, size: AppIconSize.sm, color: trustColor),
                AppSpacing.hSm,
                Text('$label ($pct%)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: trustColor)),
              ],
            ),
            AppSpacing.vXs,
            Text('$completed completed of $published published events',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(ctx))),
            AppSpacing.vXl,
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/users/${event.organizerId}/profile');
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
                ),
                child: const Text('View Full Profile', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trustBadgePill(BuildContext context, Event event) {
    final label = event.organizerTrustLabel;
    final score = event.organizerTrustScore;
    final Color color;
    final IconData icon;
    switch (label) {
      case 'Excellent':
        color = context.trustHigh;
        icon = Icons.verified_rounded;
        break;
      case 'Good':
        color = AppTheme.accentColor;
        icon = Icons.verified_outlined;
        break;
      case 'Fair':
        color = context.trustMedium;
        icon = Icons.shield_outlined;
        break;
      case 'Low':
        color = context.trustLow;
        icon = Icons.warning_amber_rounded;
        break;
      default: // New
        color = AppTheme.textSecondaryOf(context);
        icon = Icons.person_outline;
    }
    return Tooltip(
      message: '${event.organizerCompletedEvents} completed / ${event.organizerPublishedEvents} published events',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AppRadius.pill,
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              '$label ${(score * 100).toInt()}%',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.2),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusForeground(BuildContext context, EventStatus status) {
    switch (status) {
      case EventStatus.draft:
        return AppTheme.textSecondaryOf(context);
      case EventStatus.pending_approval:
        return context.statusPending;
      case EventStatus.approved:
        return AppTheme.secondaryColor;
      case EventStatus.selling_tickets:
        return context.statusSelling;
      case EventStatus.waiting_event_date:
        return context.statusWaiting;
      case EventStatus.live:
        return AppTheme.accentColor;
      case EventStatus.completed:
        return context.statusCompleted;
      case EventStatus.cancelled:
        return AppTheme.errorColor;
      case EventStatus.under_review:
        return AppTheme.warningColor;
    }
  }

  Widget _sectionTitle(BuildContext context, String title, {IconData? icon, Color? iconColor}) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: (iconColor ?? AppTheme.primaryColor).withValues(alpha: 0.1),
              borderRadius: AppRadius.sm,
            ),
            child: Icon(icon, size: AppIconSize.sm, color: iconColor ?? AppTheme.primaryColor),
          ),
          AppSpacing.hSm,
        ],
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimaryOf(context),
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }

  // ── Modern Quick Action Bar ──
  Widget _buildQuickActionBar(BuildContext context, Event event, dynamic user) {
    final isCustomer = user != null && user.isCustomer;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: AppRadius.lg,
      ),
      child: Row(
        children: [
          // ── Register / Unregister (customers only) ──
          if (isCustomer && event.canUnregister)
            Expanded(
              flex: 3,
              child: _isRegistered && _regStatus == 'registered'
                  ? _quickActionBtn(
                      icon: Icons.check_circle,
                      label: 'Registered',
                      color: AppTheme.successColor,
                      filled: true,
                      onTap: _regLoading ? null : () => _unregister(context),
                      trailing: Icon(Icons.close, size: 14, color: Colors.white.withValues(alpha: 0.7)),
                    )
                  : _quickActionBtn(
                      icon: _regStatus == 'waitlisted' ? Icons.hourglass_top : Icons.how_to_reg,
                      label: _regStatus == 'waitlisted' ? 'Waiting Approval' : 'Register',
                      color: _regStatus == 'waitlisted' ? AppTheme.warningColor : AppTheme.accentColor,
                      filled: _regStatus != 'waitlisted',
                      onTap: _regLoading || _regStatus == 'waitlisted' ? null : () => _register(context),
                    ),
            ),

          // Spacer between register and utility actions
          if (isCustomer && event.canUnregister) AppSpacing.hXs,

          // ── Share ──
          Expanded(
            flex: 2,
            child: _quickActionBtn(
              icon: Icons.share_rounded,
              label: 'Share',
              color: AppTheme.textSecondaryOf(context),
              filled: false,
              onTap: () => _shareEvent(context, event),
            ),
          ),
          AppSpacing.hXs,

          // ── Calendar ──
          Expanded(
            flex: 2,
            child: _quickActionBtn(
              icon: Icons.calendar_month_rounded,
              label: 'Calendar',
              color: AppTheme.textSecondaryOf(context),
              filled: false,
              onTap: () => _downloadCalendar(context, event),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required bool filled,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return PressFeedback(
      child: Material(
        color: filled ? color : Colors.transparent,
        borderRadius: AppRadius.md,
        child: InkWell(
        borderRadius: AppRadius.md,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: AppIconSize.sm,
                  color: filled ? Colors.white : color),
              AppSpacing.hXs,
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: filled ? Colors.white : color,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 4),
                trailing,
              ],
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _infoBanner(String text, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.md,
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: AppIconSize.md),
          AppSpacing.hSm,
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _statusLabel(EventStatus status) {
    switch (status) {
      case EventStatus.draft:
        return 'DRAFT';
      case EventStatus.pending_approval:
        return 'WAITING APPROVAL';
      case EventStatus.approved:
        return 'PUBLISHED';
      case EventStatus.selling_tickets:
        return 'SELLING TICKETS';
      case EventStatus.waiting_event_date:
        return 'AWAITING EVENT DATE';
      case EventStatus.live:
        return 'LIVE';
      case EventStatus.completed:
        return 'COMPLETED';
      case EventStatus.cancelled:
        return 'CANCELLED';
      case EventStatus.under_review:
        return 'UNDER REVIEW';
    }
  }

  Color _statusColor(BuildContext context, EventStatus status) {
    switch (status) {
      case EventStatus.draft:
        return AppTheme.textSecondaryOf(context).withValues(alpha: 0.2);
      case EventStatus.pending_approval:
        return AppTheme.warningColor.withValues(alpha: 0.2);
      case EventStatus.approved:
        return AppTheme.successColor.withValues(alpha: 0.2);
      case EventStatus.selling_tickets:
        return context.ticketAccent.withValues(alpha: 0.2);
      case EventStatus.waiting_event_date:
        return context.fundingAccent.withValues(alpha: 0.2);
      case EventStatus.live:
        return AppTheme.secondaryColor.withValues(alpha: 0.2);
      case EventStatus.completed:
        return AppTheme.textSecondaryOf(context).withValues(alpha: 0.2);
      case EventStatus.cancelled:
        return AppTheme.errorColor.withValues(alpha: 0.2);
      case EventStatus.under_review:
        return AppTheme.warningColor.withValues(alpha: 0.2);
    }
  }

  Future<void> _register(BuildContext context) async {
    setState(() => _regLoading = true);
    try {
      final api = context.read<ApiService>();
      final result = await api.register(widget.eventId);
      await _checkRegistration();
      if (context.mounted) {
        context.read<EventProvider>().loadEvent(widget.eventId);
        final status = result['status'] as String?;
        final event = context.read<EventProvider>().selectedEvent;
        final isSelling = event?.status == EventStatus.selling_tickets ||
            event?.status == EventStatus.live;
        if (status == 'waitlisted') {
          AppToast.info(context, isSelling
              ? 'Event is at capacity. Once the organizer approves, you can buy tickets.'
              : 'Event is at capacity. Your registration is waiting for organizer approval.');
        } else {
          AppToast.success(context, isSelling
              ? 'Registered! You can now buy tickets.'
              : 'Registered successfully!');
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.fromError(context, e, fallback: 'Registration failed');
      }
    }
    setState(() => _regLoading = false);
  }

  Future<void> _unregister(BuildContext context) async {
    final event = context.read<EventProvider>().selectedEvent;
    final bool refundEligible = event?.isRefundEligible ?? true;
    final deadlineDays = event?.refundDeadlineDays ?? 7;

    String message;
    if (refundEligible) {
      message =
          'Are you sure you want to unregister? Your pledged amount will be fully refunded.';
    } else {
      message =
          'The refund deadline has passed (${deadlineDays} day${deadlineDays == 1 ? '' : 's'} before event start).\n\n'
          'If you unregister now, your pledged amount will NOT be refunded.\n\n'
          'Are you sure you want to proceed?';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unregister'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: refundEligible
                  ? AppTheme.warningColor
                  : AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: Text(refundEligible
                ? 'Unregister'
                : 'Unregister (No Refund)'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _regLoading = true);
    try {
      final api = context.read<ApiService>();
      final result = await api.unregister(widget.eventId);
      await _checkRegistration();
      if (context.mounted) {
        context.read<EventProvider>().loadEvent(widget.eventId);
        final refunded = result['refunded_cents'] ?? 0;
        final pledges = result['pledges_refunded'] ?? 0;
        final wasRefunded = result['refund_eligible'] ?? true;
        String msg;
        if (wasRefunded && pledges > 0) {
          msg =
              'Unregistered successfully. Refunded \$${(refunded / 100).toStringAsFixed(2)} from $pledges pledge(s).';
        } else if (!wasRefunded) {
          msg =
              'Unregistered successfully. No refund — the refund deadline had passed.';
        } else {
          msg = 'Unregistered successfully.';
        }
        AppToast.success(context, msg);
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.fromError(context, e, fallback: 'Unregister failed');
      }
    }
    setState(() => _regLoading = false);
  }

  // _unpledge moved into _FundingCard widget

  Future<void> _shareEvent(BuildContext context, Event event) async {
    final uri = Uri.base.resolve('/events/${event.id}');
    final shareText = '${event.title}\n$uri';

    await Clipboard.setData(ClipboardData(text: shareText));
    if (context.mounted) {
      AppToast.success(context, 'Event link copied to clipboard!');
    }
  }

  // _showPledgeDialog moved into _FundingCard widget

  // ═══════════════════════════════════════════
  // Add to Calendar
  // ═══════════════════════════════════════════

  Future<void> _downloadCalendar(BuildContext context, Event event) async {
    final api = context.read<ApiService>();
    final url = api.calendarUrl(event.id);
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      AppToast.success(context, 'Calendar link copied! Paste in browser to download .ics file.');
    }
  }

  // ═══════════════════════════════════════════
  // Waitlist Management
  // ═══════════════════════════════════════════

}

