import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flutter_animate/flutter_animate.dart';

import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../config/design_tokens.dart';
import '../../models/event.dart';
import '../../models/event_image.dart';
import '../../models/funding.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../models/ticket.dart';
import '../../providers/pledge_provider.dart';
import '../../providers/ticket_provider.dart';
import '../../widgets/animated_list_item.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/event/event_bottom_strip.dart';
import '../../widgets/event/event_lifecycle_bar.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../services/sync_service.dart';
import '../../widgets/share_bottom_sheet.dart';
import '../../widgets/calendar_bottom_sheet.dart';
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
  // Hero image height. The title card overlaps the hero bottom by _heroOverlap dp,
  // rendering on top via Stack z-order (card is above hero in the SliverToBoxAdapter Stack).
  static const double _heroHeight = 300;
  static const double _heroOverlap = 28;

  bool _isRegistered = false;
  String? _regStatus;
  bool _registrationSeeded = false;
  int _myTicketCount = 0;
  List<TicketSale> _myEventTickets = [];
  int _myReservedSpots = 0;
  int _revenueCents = 0;
  bool _bookmarked = false;
  bool _offlineCached = false;

  bool _isUserAgeBlocked(Event event) {
    if (!event.ageRestricted) return false;
    final user = context.read<AuthProvider>().user;
    if (user == null) return false;
    // Organizer is never blocked from viewing their own event
    if (user.id == event.organizerId) return false;
    if (user.birthday == null) return true;
    try {
      final bd = DateTime.parse(user.birthday!);
      final now = DateTime.now();
      int age = now.year - bd.year;
      if (now.month < bd.month ||
          (now.month == bd.month && now.day < bd.day)) { age--; }
      return age < event.minAge;
    } catch (_) {
      return true;
    }
  }

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
      final repo = context.read<EventProvider>();
      final res = await repo.checkBookmarks([widget.eventId]);
      if (mounted) setState(() => _bookmarked = res[widget.eventId] ?? false);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _toggleBookmark() async {
    try {
      final repo = context.read<EventProvider>();
      final res = await repo.toggleBookmark(widget.eventId);
      if (mounted) setState(() => _bookmarked = res.bookmarked);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _loadImages() async {
    try {
      final repo = context.read<EventProvider>();
      final data = await repo.getEventImages(widget.eventId);
      if (mounted) {
        setState(() {
          _images = data;
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    }
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

  Future<void> _checkRegistration() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    try {
      final repo = context.read<EventProvider>();
      final data = await repo.getMyRegistration(widget.eventId);
      if (mounted) {
        setState(() {
          _isRegistered = data != null;
          _regStatus = data?.status;
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _loadMyTicketCount() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null || !user.isCustomer) return;
    try {
      final ticketRepo = context.read<TicketProvider>();
      final result = await ticketRepo.getMyTickets();
      final myTickets = result.items
          .where((t) =>
              t.eventId == widget.eventId &&
              (t.status == 'purchased' ||
                  t.status == 'waitlisted' ||
                  t.status == 'refund_requested'))
          .toList();
      if (mounted) {
        setState(() {
          _myTicketCount = myTickets.length;
          _myEventTickets = myTickets;
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _loadMyReservedSpots() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null || !(user.isCustomer || user.isSponsor)) return;
    try {
      final repo = context.read<PledgeProvider>();
      final result = await repo.getMyPledges();
      final spots = result.items
          .where((p) =>
              p.eventId == widget.eventId && p.status == PledgeStatus.pledged)
          .fold<int>(
              0, (sum, p) => sum + p.reservedSpots);
      if (mounted) setState(() => _myReservedSpots = spots);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _cacheForOffline(Event event) {
    if (_offlineCached) return;
    _offlineCached = true;
    final syncService = context.read<SyncService>();
    // Cache transport info for offline directions
    if (event.hasTransportInfo || event.directionsUrl != null) {
      syncService.cacheTransportForEvent(
        eventId: event.id,
        parkingInfo: event.parkingInfo,
        transitInfo: event.transitInfo,
        rideshareInfo: event.rideshareInfo,
        accessibilityInfo: event.accessibilityInfo,
        directionsUrl: event.directionsUrl,
      );
    }
    // Cache schedule for offline viewing
    if (event.hasSchedule) {
      syncService.cacheScheduleForEvent(event.id);
    }
  }

  Future<void> _loadRevenue() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null || (!user.isOrganizer && !user.isAdmin)) {
      final event = context.read<EventProvider>().selectedEvent;
      if (event == null || !event.viewerIsCoOrganizer) return;
    }
    try {
      final ticketRepo = context.read<TicketProvider>();
      final sales = await ticketRepo.getTicketSales(widget.eventId);
      final total = sales.fold<int>(0, (s, t) => s + t.amountPaidCents);
      if (mounted) setState(() => _revenueCents = total);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventProvider =
        widget.isPreview ? null : context.watch<EventProvider>();
    final auth = context.watch<AuthProvider>();
    final event =
        widget.isPreview ? widget.previewEvent : eventProvider!.selectedEvent;
    final user = widget.isPreview ? null : auth.user;
    final isDark = AppTheme.isDark(context);

    // Seed registration state from event model (avoids flash of "unregistered")
    if (!_registrationSeeded && event?.viewerIsRegistered != null) {
      _registrationSeeded = true;
      _isRegistered = event!.viewerIsRegistered!;
      _regStatus = event.viewerRegistrationStatus;
    }

    // Cache transport + schedule for offline use when event is loaded
    if (!widget.isPreview && event != null) {
      _cacheForOffline(event);
    }

    final hasPreviewImages = widget.isPreview &&
        widget.previewImages != null &&
        widget.previewImages!.isNotEmpty;
    final heroUrl =
        !widget.isPreview && _images.isNotEmpty ? _images.first.imageUrl : null;
    final hasHero = heroUrl != null || hasPreviewImages;

    return Scaffold(
      bottomNavigationBar: !widget.isPreview && event != null
          ? EventBottomStrip(
              event: event,
              isRegistered: _isRegistered,
              regStatus: _regStatus,
              ageBlocked: _isUserAgeBlocked(event),
              onRegistrationChanged: (isRegistered, status) {
                setState(() {
                  _isRegistered = isRegistered;
                  _regStatus = status;
                });
                _loadMyTicketCount();
                _loadMyReservedSpots();
              },
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
                          _buildSliverAppBar(context, event, hasHero),
                          _buildHeroSliver(context, event, user, hasHero,
                              hasPreviewImages, heroUrl, isDark),
                          SliverToBoxAdapter(
                            child: Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 700),
                                child: _buildContent(
                                    context, event, user, isDark),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, Event event, bool hasHero) {
    return SliverAppBar(
      pinned: true,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.15),
                    borderRadius: AppRadius.pill,
                    border: Border.all(
                        color: AppTheme.accentColor.withValues(alpha: 0.4)),
                  ),
                  child: Text('VIEW ONLY (ADMIN)',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accentColor,
                          letterSpacing: 0.5)),
                ),
              if (widget.isPreview)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.15),
                    borderRadius: AppRadius.pill,
                    border: Border.all(
                        color:
                            AppTheme.warningColor.withValues(alpha: 0.4)),
                  ),
                  child: Text('PREVIEW',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.warningColor,
                          letterSpacing: 0.5)),
                ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                event.title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16),
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
              child: Icon(Icons.ios_share_rounded, size: AppIconSize.sm),
            ),
            onPressed: () => showShareSheet(context, event),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: _scrolledPastHero || !hasHero
                    ? Colors.transparent
                    : AppTheme.surfaceOf(context).withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.calendar_today_rounded, size: AppIconSize.sm),
            ),
            onPressed: () => showCalendarSheet(context, event),
          ),
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
                _bookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                size: AppIconSize.sm,
                color: _bookmarked ? AppTheme.accentColor : null,
              ),
            ),
            onPressed: _toggleBookmark,
          ),
          AppSpacing.hXs,
        ],
      ],
    );
  }

  /// Hero image + floating title card in a Stack so the card renders on top
  /// of the image (correct z-order — SliverToBoxAdapter children stack normally).
  Widget _buildHeroSliver(BuildContext context, Event event, dynamic user,
      bool hasHero, bool hasPreviewImages, String? heroUrl, bool isDark) {
    final titleCard = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: AppRadius.xxl,
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.60),
                    blurRadius: 36,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.30),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.11),
                    blurRadius: 36,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.7,
                      height: 1.2,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.08, duration: 400.ms, curve: AppCurve.enter),
                ),
                if (!widget.isPreview && !(user?.isAdmin ?? false))
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ReactionBar(
                      eventId: widget.eventId,
                      initialLikeCount: event.likeCount,
                      initialDislikeCount: event.dislikeCount,
                      isAdmin: false,
                      compact: true,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                EventDetailHelpers.statusPill(context, event.status),
                if (event.genre != null && event.genre!.isNotEmpty)
                  EventDetailHelpers.tagPill(
                    icon: Icons.category_rounded,
                    label: event.genre![0].toUpperCase() +
                        event.genre!.substring(1),
                    color: AppTheme.secondaryColor,
                  ),
                if (event.registrationCount > 0 &&
                    event.status != EventStatus.approved &&
                    event.status != EventStatus.waiting_event_date)
                  EventDetailHelpers.tagPill(
                    icon: Icons.group_rounded,
                    label:
                        '${event.registrationCount} ${(event.status == EventStatus.selling_tickets || event.status == EventStatus.live) ? 'engaged' : 'joined'}',
                    color: AppTheme.accentColor,
                  ),
                if (event.organizerName != null &&
                    event.organizerName!.isNotEmpty)
                  GestureDetector(
                    onTap: () => _showOrganizerBottomSheet(event),
                    child: EventDetailHelpers.tagPill(
                      icon: Icons.person_rounded,
                      label: event.organizerName!,
                      color: AppTheme.accentColor,
                    ),
                  ),
                if (event.status != EventStatus.approved &&
                    event.status != EventStatus.waiting_event_date)
                  GestureDetector(
                    onTap: () => _showOrganizerBottomSheet(event),
                    child: EventDetailHelpers.trustBadgePill(context, event),
                  ),
                if (_revenueCents > 0 &&
                    user != null &&
                    (user.isOrganizer ||
                        user.isAdmin ||
                        event.viewerIsCoOrganizer) &&
                    !widget.readOnly)
                  EventDetailHelpers.tagPill(
                    icon: Icons.paid_rounded,
                    label:
                        '\$${(_revenueCents / 100).toStringAsFixed(0)} revenue',
                    color: context.ticketAccent,
                  ),
              ],
            )
                .animate()
                .fadeIn(duration: 300.ms, delay: 80.ms)
                .slideX(begin: -0.04, duration: 300.ms),
            const SizedBox(height: 16),
            EventLifecycleBreadcrumb(event: event),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.06, duration: 350.ms, curve: AppCurve.enter);

    if (!hasHero) {
      return SliverToBoxAdapter(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 0),
              child: titleCard,
            ),
          ),
        ),
      );
    }

    final heroImage = Stack(
      fit: StackFit.expand,
      children: [
        if (hasPreviewImages)
          Image.memory(widget.previewImages!.first, fit: BoxFit.cover)
        else
          CachedNetworkImage(
            imageUrl: ApiConfig.imageUrl(heroUrl!),
            fit: BoxFit.cover,
            imageBuilder: (context, imageProvider) => Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: imageProvider,
                  fit: BoxFit.cover,
                ),
              ),
            )
                .animate()
                .fadeIn(duration: AppDuration.normal, curve: AppCurve.enter)
                .scale(
                  begin: const Offset(0.95, 0.95),
                  end: const Offset(1.0, 1.0),
                  duration: AppDuration.slow,
                  curve: AppCurve.enter,
                ),
            progressIndicatorBuilder: (context, url, progress) =>
                ShimmerImagePlaceholder(
                  width: double.infinity,
                  height: _heroHeight,
                ),
            errorWidget: (_, __, ___) => Container(
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
                  Icon(Icons.image_rounded,
                      size: 48, color: AppTheme.textSecondaryOf(context)),
                  AppSpacing.vSm,
                  Text('Image could not be loaded',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryOf(context))),
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
    );

    return SliverToBoxAdapter(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Stack(
            children: [
              // ① Hero image — bottom z-order
              Positioned(
                top: 0, left: 0, right: 0,
                height: _heroHeight,
                child: heroImage,
              ),
              // ② Title card — top z-order, floats over hero bottom
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: _heroHeight - _heroOverlap),
                  titleCard,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, Event event, dynamic user, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Stats row ──
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: _buildStatsRow(context, event, isDark),
        ),

        // ── Content sections ──
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

        if (widget.isPreview) ...[
          EventDetailHelpers.previewBanner(context),
          AppSpacing.vLg,
        ],

        // Reaction Bar (admin read-only counters only)
        if (!widget.isPreview && (user?.isAdmin ?? false)) ...[
          ReactionBar(
            eventId: widget.eventId,
            initialLikeCount: event.likeCount,
            initialDislikeCount: event.dislikeCount,
            isAdmin: true,
          ),
          AppSpacing.vXl,
        ],

        // Image Gallery
        EventImageGallery(
          eventId: widget.eventId,
          isPreview: widget.isPreview,
          previewImages: widget.previewImages,
          images: _images,
          onImagesChanged: _loadImages,
          canManage: !widget.isPreview &&
              !widget.readOnly &&
              user != null &&
              (user.isOrganizer ||
                  user.isAdmin ||
                  event.viewerHasFullCoOrganizerAccess),
        ),

        // Age Restriction
        AgeRestrictionBanner(
          event: event,
          isBlocked: _isUserAgeBlocked(event),
          isOwnEvent: user != null && user.id == event.organizerId,
        ),

        // About
        if (event.description != null && event.description!.isNotEmpty) ...[
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
                      Icon(Icons.article_rounded,
                          size: AppIconSize.sm,
                          color: AppTheme.textSecondaryOf(context)),
                      AppSpacing.hSm,
                      Text(
                        'About',
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

        // Funding Card + Milestones
        if (event.fundingGoalCents != null &&
            event.fundingGoalCents! > 0) ...[
          if (widget.isPreview) ...[
            EventDetailHelpers.previewPlaceholder(context,
                'Funding progress will appear after publishing', Icons.attach_money_rounded),
            AppSpacing.vXxl,
            EventDetailHelpers.previewPlaceholder(context,
                'Milestones will appear after publishing', Icons.flag_rounded),
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

        // Schedule
        if (widget.isPreview)
          EventDetailHelpers.previewPlaceholder(context,
              'Schedule will appear after publishing', Icons.schedule_rounded)
        else
          AnimatedListItem(
            index: 3,
            child: EventScheduleSection(
              eventId: widget.eventId,
              event: event,
            ),
          ),

        // Details Card
        EventDetailsCard(
          event: event,
          isOrganizerOrAdmin: user != null &&
              (user.isOrganizer || user.isAdmin),
        ),
        AppSpacing.vXl,

        // Getting There
        GettingThereCard(event: event),

        // Status Banners
        if (event.pendingCancellation != null)
          PendingCancellationBanner(data: event.pendingCancellation!),

        if (event.status == EventStatus.cancelled &&
            event.cancellationReason != null &&
            event.cancellationReason!.isNotEmpty)
          CancellationReasonBanner(reason: event.cancellationReason!),

        if (event.status == EventStatus.under_review &&
            event.reviewNotes != null &&
            event.reviewNotes!.isNotEmpty)
          UnderReviewBanner(notes: event.reviewNotes!),

        // Ticket Tiers + Buy + Your Tickets
        if (!widget.isPreview) ...[
          if (event.ticketStrategyId != null &&
              (user == null ||
                  (!user.isOrganizer && !user.isAdmin) ||
                  widget.readOnly)) ...[
            AppSpacing.vLg,
            EventDetailHelpers.sectionTitle(context, 'Ticket Tiers',
                icon: Icons.confirmation_number_rounded,
                iconColor: context.sponsorAccent),
            AppSpacing.vSm,
          ],
          TicketTiersSection(
            event: event,
            myTicketCount: _myTicketCount,
            myReservedSpots: _myReservedSpots,
            myEventTickets: _myEventTickets,
            isOrganizer:
                widget.readOnly ? false : (user?.isOrganizer ?? false),
            isAdmin: widget.readOnly ? false : (user?.isAdmin ?? false),
            isRegistered: _isRegistered && _regStatus == 'registered',
            onPurchaseComplete: () {
              _loadMyTicketCount();
              _loadMyReservedSpots();
            },
          ),
          if (user != null && user.isCustomer)
            CustomerDiscountsSection(
              eventId: event.id,
              onDiscountsChanged: () => setState(() {}),
            ),
        ] else ...[
          if (event.ticketStrategyId != null) ...[
            AppSpacing.vLg,
            EventDetailHelpers.previewPlaceholder(
                context,
                'Ticket tiers and purchasing will appear after publishing',
                Icons.confirmation_number_rounded),
          ],
        ],

        // State info banners
        if (!widget.isPreview) ...[
          if (event.status == EventStatus.selling_tickets)
            EventDetailHelpers.infoBanner(
                'Tickets are now on sale! Grab yours before they sell out.',
                Icons.confirmation_number,
                context.ticketAccent),
          if (event.status == EventStatus.waiting_event_date)
            EventDetailHelpers.infoBanner(
                'The funding phase is complete. The organizer is finalizing event details — stay tuned for ticket sales!',
                Icons.event_note_rounded,
                context.fundingAccent),
          if (event.status == EventStatus.completed)
            EventDetailHelpers.infoBanner(
                'This event has ended. Thanks for being part of it!',
                Icons.check_circle,
                AppTheme.textSecondaryOf(context)),

          // Sponsor access
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
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryOf(context)),
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.vSm,
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context
                          .push('/events/${widget.eventId}/sponsorships'),
                      icon: const Icon(Icons.storefront_rounded,
                          size: AppIconSize.sm),
                      label: const Text('View Sponsorships'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: context.ticketAccent),
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.vLg,
          ],

          // Organizer Management
          if (user != null &&
              (user.isOrganizer ||
                  user.isAdmin ||
                  event.viewerIsCoOrganizer) &&
              !widget.readOnly)
            OrganizerManagementSection(
              event: event,
              isAdmin: user.isAdmin,
              isOrganizer: user.isOrganizer ||
                  event.viewerHasFullCoOrganizerAccess,
              coOrganizerPermission: event.viewerCoOrganizerPermission,
              revenueCents: _revenueCents,
              onRefresh: _refreshAll,
            ),

          // Ticket Tier Management
          if (user != null &&
              (user.isOrganizer ||
                  user.isAdmin ||
                  event.viewerHasFullCoOrganizerAccess) &&
              !widget.readOnly &&
              event.ticketStrategyId != null)
            TicketTierManagement(
                event: event, onTiersChanged: _refreshAll),
        ],

        // Sponsor Carousel
        if (widget.isPreview)
          EventDetailHelpers.previewPlaceholder(context,
              'Sponsors will appear after publishing', Icons.storefront_rounded)
        else
          SponsorCarousel(eventId: widget.eventId),

        // Reviews
        if (!widget.isPreview && event.status == EventStatus.completed)
          ReviewsSection(
            eventId: widget.eventId,
            organizerId: event.organizerId,
          )
        else if (widget.isPreview)
          EventDetailHelpers.previewPlaceholder(context,
              'Reviews will appear after publishing', Icons.rate_review_rounded),

        // Event Feed
        AppSpacing.vXxxl,
        if (widget.isPreview)
          EventDetailHelpers.previewPlaceholder(context,
              'Event feed will appear after publishing', Icons.forum_rounded)
        else
          EventFeedSection(
            eventId: widget.eventId,
            postsEnabled: event.postsEnabled,
            isRegistered: _isRegistered,
          ),

            ], // end inner Column children
          ),   // end inner Column
        ),     // end inner Padding
      ],
    );
  }

  // ── Stats row: registered count / funding days / capacity ──
  Widget _buildStatsRow(BuildContext context, Event event, bool isDark) {
    final items = <({String val, String lbl})>[];

    if (event.registrationCount > 0 && !event.isFunding &&
        event.status != EventStatus.waiting_event_date &&
        event.status != EventStatus.selling_tickets &&
        event.status != EventStatus.live) {
      items.add((val: '${event.registrationCount}', lbl: 'Joined'));
    }


    if (event.totalReservedSpots > 0 && !event.isFunding) {
      items.add((val: '${event.totalReservedSpots}', lbl: 'Backers'));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final item = items[i];
          return Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                border: i < items.length - 1
                    ? Border(
                        right: BorderSide(color: AppTheme.dividerOf(context)),
                      )
                    : null,
              ),
              child: Column(
                children: [
                  Text(
                    item.val,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimaryOf(context),
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.lbl.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.07 * 9,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
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
      shape: RoundedRectangleBorder(borderRadius: AppRadius.topXxl),
      backgroundColor: AppTheme.cardOf(context),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.dividerOf(ctx),
                  borderRadius: AppRadius.sm),
            ),
            AppSpacing.vXl,
            CircleAvatar(
              radius: 30,
              backgroundColor: AppTheme.accentColor.withValues(alpha: 0.15),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accentColor),
              ),
            ),
            AppSpacing.vMd,
            Text(name,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimaryOf(ctx))),
            AppSpacing.vSm,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(trustIcon, size: AppIconSize.sm, color: trustColor),
                AppSpacing.hSm,
                Text('$label ($pct%)',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: trustColor)),
              ],
            ),
            AppSpacing.vXs,
            Text(
                '$completed completed of $published published events',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryOf(ctx))),
            AppSpacing.vXl,
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/users/${event.organizerId}/profile');
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg),
                  shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.lg),
                ),
                child: const Text('View Full Profile',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
