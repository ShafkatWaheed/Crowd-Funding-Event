import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../models/event.dart';
import '../../models/post.dart';
import '../../models/event_image.dart';
import '../../models/venue.dart';
import '../../models/ticket_strategy.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../widgets/event_lifecycle_bar.dart';
import '../../widgets/app_toast.dart';
import '../../services/api_service.dart';
import 'ticket_receipt_screen.dart';
import 'purchase_group_receipt_screen.dart';
import 'pledge_receipt_screen.dart';
import 'venue_picker_screen.dart';
import 'strategy_picker_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final int eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  List<EventImage> _images = [];
  bool _loadingImages = false;

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

  // Reaction state lives in _ReactionBar widget (self-contained)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().loadEvent(widget.eventId);
      _loadImages();
      _checkRegistration();
      _loadMyTicketCount();
      _loadMyReservedSpots();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  // _loadPosts moved into _EventFeed widget

  Future<void> _loadImages() async {
    setState(() => _loadingImages = true);
    try {
      final api = context.read<ApiService>();
      final data = await api.getEventImages(widget.eventId);
      setState(() {
        _images = data.map((i) => EventImage.fromJson(i)).toList();
      });
    } catch (_) {}
    setState(() => _loadingImages = false);
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
    if (auth.user == null) return;
    try {
      final api = context.read<ApiService>();
      final tickets = await api.getMyTickets();
      final myTickets = (tickets as List).where((t) =>
          t['event_id'] == widget.eventId &&
          (t['status'] == 'purchased' || t['status'] == 'waitlisted')).toList();
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
    if (auth.user == null) return;
    try {
      final api = context.read<ApiService>();
      final pledges = await api.getMyPledges();
      final spots = (pledges as List)
          .where((p) => p['event_id'] == widget.eventId && p['status'] == 'pledged')
          .fold<int>(0, (sum, p) => sum + ((p['reserved_spots'] ?? 0) as int));
      if (mounted) setState(() => _myReservedSpots = spots);
    } catch (_) {}
  }

  // _loadMyReaction and _react moved into _ReactionBar widget

  // _submitPost moved into _EventFeed widget

  // _deletePost moved into _EventFeed widget

  Future<void> _togglePosts() async {
    try {
      final api = context.read<ApiService>();
      await api.toggleEventPosts(widget.eventId);
      if (mounted) {
        context.read<EventProvider>().loadEvent(widget.eventId);
      }
    } catch (e) {
      if (mounted) AppToast.fromError(context, e, fallback: 'Failed to toggle posts');
    }
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
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceOf(context),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, size: 18),
          ),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const SizedBox.shrink(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
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
                              ),
                              const SizedBox(height: 12),

                              // Status pill + Genre + Registration count
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _statusPill(event.status),
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
                                  // Trust badge
                                  _trustBadgePill(event),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Lifecycle progress bar
                              EventLifecycleBar(event: event),
                              const SizedBox(height: 16),

                              // ── Quick Action Bar (Register, Share, Calendar) ──
                              _buildQuickActionBar(context, event, user),
                              const SizedBox(height: 20),

                              // Like / Dislike — self-contained widget
                              _ReactionBar(
                                eventId: widget.eventId,
                                initialLikeCount: event.likeCount,
                                initialDislikeCount: event.dislikeCount,
                                isAdmin: user?.isAdmin ?? false,
                              ),
                              const SizedBox(height: 20),

                              // Image gallery
                              if (_images.isNotEmpty) ...[
                                _sectionTitle(context, 'Photos'),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 180,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _images.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 10),
                                    itemBuilder: (ctx, i) {
                                      final img = _images[i];
                                      return ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        child: Stack(
                                          children: [
                                            Image.network(
                                              img.imageUrl,
                                              height: 180,
                                              width: 260,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (_, __, ___) =>
                                                      Container(
                                                height: 180,
                                                width: 260,
                                                color: Colors.grey[200],
                                                child: const Icon(
                                                    Icons.broken_image,
                                                    size: 40),
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
                                            // Delete button for organizer
                                            if (user != null &&
                                                (user.isOrganizer ||
                                                    user.isAdmin))
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
                                                        size: 16,
                                                        color: Colors.white),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                // Add image button for organizer
                                if (user != null &&
                                    (user.isOrganizer || user.isAdmin)) ...[
                                  const SizedBox(height: 8),
                                  _addImageButton(context),
                                ],
                                const SizedBox(height: 24),
                              ] else if (user != null &&
                                  (user.isOrganizer || user.isAdmin)) ...[
                                _sectionTitle(context, 'Photos'),
                                const SizedBox(height: 8),
                                _addImageButton(context),
                                const SizedBox(height: 24),
                              ],

                              // ── Description ──
                              if (event.description != null &&
                                  event.description!.isNotEmpty) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cardOf(context),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppTheme.dividerOf(context)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.article_rounded, size: 18, color: Colors.grey[500]),
                                          const SizedBox(width: 8),
                                          Text('About',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.grey[500],
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
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
                                const SizedBox(height: 20),
                              ],

                              // ── Funding Card (self-contained) ──
                              if (event.fundingGoalCents != null &&
                                  event.fundingGoalCents! > 0) ...[
                                _FundingCard(
                                  eventId: widget.eventId,
                                  event: event,
                                  isRegistered: _isRegistered,
                                ),
                                const SizedBox(height: 24),
                              ],

                              // ── Event Details Grid ──
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardOf(context),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.dividerOf(context)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.info_outline_rounded, size: 18, color: Colors.grey[500]),
                                        const SizedBox(width: 8),
                                        Text('Details',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.grey[500],
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    if (event.startTime != null)
                                      _modernInfoRow(Icons.event_rounded, 'Starts', dateFormat.format(event.startTime!)),
                                    if (event.endTime != null)
                                      _modernInfoRow(Icons.event_available_rounded, 'Ends', dateFormat.format(event.endTime!)),
                                    if (event.startTime == null && event.endTime == null)
                                      _modernInfoRow(Icons.schedule_rounded, 'Date', 'Announced after funding milestone', valueColor: Colors.orange[700]),
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
                                            ? '${event.refundDeadlineDays}d before funding ends'
                                            : 'No refunds',
                                        valueColor: event.refundDeadlineDays! > 0 ? AppTheme.secondaryColor : AppTheme.errorColor,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // ── Getting There (Parking / Transport) ──
                              if (event.hasTransportInfo) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppTheme.dividerOf(context)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.directions_rounded, size: 16, color: Colors.grey[500]),
                                          const SizedBox(width: 8),
                                          Text('Getting There',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.grey[500],
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      if (event.parkingInfo != null && event.parkingInfo!.isNotEmpty)
                                        _modernInfoRow(Icons.local_parking_rounded, 'Parking', event.parkingInfo!),
                                      if (event.transitInfo != null && event.transitInfo!.isNotEmpty)
                                        _modernInfoRow(Icons.directions_transit_rounded, 'Transit', event.transitInfo!),
                                      if (event.rideshareInfo != null && event.rideshareInfo!.isNotEmpty)
                                        _modernInfoRow(Icons.local_taxi_rounded, 'Rideshare', event.rideshareInfo!),
                                      if (event.accessibilityInfo != null && event.accessibilityInfo!.isNotEmpty)
                                        _modernInfoRow(Icons.accessible_rounded, 'Accessibility', event.accessibilityInfo!),
                                      if (event.directionsUrl != null) ...[
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: () async {
                                              final uri = Uri.parse(event.directionsUrl!);
                                              if (await canLaunchUrl(uri)) {
                                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                                              }
                                            },
                                            icon: const Icon(Icons.navigation_rounded, size: 16),
                                            label: const Text('Get Directions'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppTheme.primaryColor,
                                              side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.4)),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],

                              // Pending cancellation banner
                              if (event.pendingCancellation != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.orange.shade200),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(Icons.hourglass_top_rounded, color: Colors.orange.shade800, size: 18),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Cancellation Pending Admin Approval',
                                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.orange.shade800)),
                                            const SizedBox(height: 4),
                                            Text(
                                              event.pendingCancellation!['pledge_percent'] != null
                                                  ? '${event.pendingCancellation!['pledge_percent']}% funded — admin must approve cancellation'
                                                  : 'Organizer requested cancellation — awaiting admin review',
                                              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                            ),
                                            if (event.pendingCancellation!['reason'] != null) ...[
                                              const SizedBox(height: 4),
                                              Text('Reason: ${event.pendingCancellation!['reason']}',
                                                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],

                              // Cancellation reason banner
                              if (event.status == EventStatus.cancelled &&
                                  event.cancellationReason != null &&
                                  event.cancellationReason!.isNotEmpty) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppTheme.errorColor.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.errorColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.cancel_rounded, color: AppTheme.errorColor, size: 18),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Cancellation Reason',
                                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.errorColor)),
                                            const SizedBox(height: 4),
                                            Text(event.cancellationReason!,
                                              style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],

                              // ─── Ticket Tiers Section (customer view only) ───
                              if (event.ticketStrategyId != null &&
                                  (user == null || (!user.isOrganizer && !user.isAdmin))) ...[
                                const SizedBox(height: 16),
                                _sectionTitle(context, 'Ticket Tiers'),
                                const SizedBox(height: 8),
                                _buildTicketTiersSection(event),
                                const SizedBox(height: 16),
                              ],

                              // Your Discounts (customer view only)
                              if (user != null && !user.isOrganizer && !user.isAdmin) ...[
                                _CustomerDiscountsSection(eventId: event.id),
                              ],

                              // State info banners
                              if (event.status == EventStatus.selling_tickets)
                                _infoBanner('Funding has ended. Tickets are now on sale!', Icons.confirmation_number, Colors.teal),
                              if (event.status == EventStatus.waiting_event_date)
                                _infoBanner(
                                  event.startTime != null && event.ticketStrategyId != null
                                      ? 'Funding has ended. Ready to start selling tickets.'
                                      : 'Funding has ended. Set event dates and ticket strategy, then start selling.',
                                  Icons.hourglass_top, Colors.orange),
                              if (event.status == EventStatus.completed)
                                _infoBanner('This event has been completed.', Icons.check_circle, Colors.grey),

                              // Buy tickets (always visible for customers during selling/live)
                              if (user != null &&
                                  user.isCustomer &&
                                  (event.status == EventStatus.selling_tickets ||
                                      event.status == EventStatus.live)) ...[
                                const SizedBox(height: 12),
                                // Waiting approval banner (shown alongside Buy Tickets)
                                if (_regStatus == 'waitlisted') ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.warningColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.hourglass_top_rounded, size: 18, color: AppTheme.warningColor),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Your registration is waiting for approval. Once approved, you can buy tickets.',
                                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                // Show user's tickets for this event
                                if (_myTicketCount > 0) ...[
                                  _buildYourTicketsSection(),
                                  const SizedBox(height: 8),
                                ],
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      if (!_isRegistered || _regStatus != 'registered') {
                                        if (_regStatus == 'waitlisted') {
                                          AppToast.info(context, 'Your registration is waiting for organizer approval. You can buy tickets once approved.');
                                        } else {
                                          AppToast.info(context, 'Please register for this event first to buy tickets.');
                                        }
                                        return;
                                      }
                                      _showBuyTicketDialog(event);
                                    },
                                    icon: const Icon(Icons.confirmation_number),
                                    label: const Text('Buy Tickets',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // ──────── Organizer Actions (modern, status-aware) ────────
                              if (user != null &&
                                  (user.isOrganizer || user.isAdmin)) ...[
                                const SizedBox(height: 24),
                                _sectionTitle(context, 'Organizer Actions'),
                                const SizedBox(height: 12),

                                // ── Primary Action Card (status-specific) ──
                                // Draft → Publish
                                if (event.status == EventStatus.draft)
                                  _primaryActionCard(
                                    icon: Icons.publish_rounded,
                                    color: AppTheme.primaryColor,
                                    title: 'Ready to publish?',
                                    subtitle: event.startTime == null && event.fundingEndAt == null
                                        ? 'Set an event date or funding deadline first.'
                                        : 'Submit your event for review.',
                                    buttonLabel: 'Publish Event',
                                    buttonEnabled: event.startTime != null || event.fundingEndAt != null,
                                    onPressed: () async {
                                      final ok = await eventProvider.publishEvent(event.id);
                                      if (!ok && mounted) {
                                        AppToast.error(context, eventProvider.error ?? 'Failed to publish');
                                      }
                                    },
                                  ),

                                // Cancelled → Reactivate
                                if (event.status == EventStatus.cancelled)
                                  _primaryActionCard(
                                    icon: Icons.restore_rounded,
                                    color: AppTheme.warningColor,
                                    title: 'Reactivate this event?',
                                    subtitle: 'Move it back to draft for editing.',
                                    buttonLabel: 'Move to Draft',
                                    onPressed: () async {
                                      await eventProvider.reactivateEvent(event.id);
                                    },
                                  ),

                                // waiting_event_date → Start Selling
                                if (event.status == EventStatus.waiting_event_date)
                                  _primaryActionCard(
                                    icon: Icons.storefront_rounded,
                                    color: Colors.teal,
                                    title: 'Ready to sell tickets?',
                                    subtitle: event.startTime != null && event.ticketStrategyId != null
                                        ? 'Event date and tickets are set. Start selling now.'
                                        : event.startTime == null
                                            ? 'Set an event date first, then you can start selling.'
                                            : 'Attach a ticket strategy first, then start selling.',
                                    buttonLabel: 'Start Selling Tickets',
                                    buttonEnabled: event.startTime != null && event.ticketStrategyId != null,
                                    onPressed: () => _confirmStartSelling(context, eventProvider, event),
                                  ),

                                // Completed → Clone
                                if (event.status == EventStatus.completed)
                                  _primaryActionCard(
                                    icon: Icons.copy_all_rounded,
                                    color: AppTheme.primaryColor,
                                    title: 'Run this event again?',
                                    subtitle: 'Clone it into a new draft with all settings pre-filled.',
                                    buttonLabel: 'Clone Event',
                                    onPressed: () => _cloneEvent(context, event.id),
                                  ),

                                // ── Setup Grid (waiting_event_date only) ──
                                if (event.status == EventStatus.waiting_event_date) ...[
                                  const SizedBox(height: 14),
                                  GridView.count(
                                    crossAxisCount: 2,
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: 1.55,
                                    children: [
                                      _setupTile(
                                        icon: Icons.calendar_month_rounded,
                                        label: 'Event Date',
                                        subtitle: event.startTime != null
                                            ? DateFormat('MMM d, y – h:mm a').format(event.startTime!)
                                            : 'Not set',
                                        color: Colors.orange,
                                        isSet: event.startTime != null,
                                        onTap: () => _showSetEventDateDialog(context, event),
                                      ),
                                      _setupTile(
                                        icon: Icons.location_on_rounded,
                                        label: 'Venue',
                                        subtitle: event.venue?.name ?? 'Not set',
                                        color: Colors.indigo,
                                        isSet: event.venue != null,
                                        onTap: () => _selectVenueForEvent(context, event),
                                      ),
                                      _setupTile(
                                        icon: Icons.confirmation_number_rounded,
                                        label: 'Ticket Strategy',
                                        subtitle: event.ticketStrategyName ?? 'Not set',
                                        color: Colors.deepPurple,
                                        isSet: event.ticketStrategyId != null,
                                        onTap: () => _selectStrategyForEvent(context, event),
                                      ),
                                      _setupTile(
                                        icon: Icons.people_rounded,
                                        label: 'Max Capacity',
                                        subtitle: '${event.maxCapacity}',
                                        color: Colors.teal,
                                        isSet: true,
                                        onTap: () => _showChangeCapacityDialog(context, event),
                                      ),
                                    ],
                                  ),
                                ],

                                const SizedBox(height: 10),

                                // ── Secondary Actions (menu tiles) ──
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.cardOf(context),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 12,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      // Edit (draft, pending, approved only)
                                      if (event.status == EventStatus.draft ||
                                          event.status == EventStatus.pending_approval ||
                                          event.status == EventStatus.approved)
                                        _menuTile(
                                          icon: Icons.edit_rounded,
                                          iconColor: AppTheme.secondaryColor,
                                          label: 'Edit Event',
                                          trailing: event.status == EventStatus.approved
                                              ? 'Needs approval'
                                              : null,
                                          onTap: () => context.push('/events/${event.id}/edit'),
                                        ),

                                      // Toggle posts (all statuses)
                                      _menuTile(
                                        icon: event.postsEnabled ? Icons.comments_disabled_rounded : Icons.comment_rounded,
                                        iconColor: event.postsEnabled ? Colors.grey : AppTheme.primaryColor,
                                        label: event.postsEnabled ? 'Disable Posts' : 'Enable Posts',
                                        onTap: _togglePosts,
                                      ),

                                      // Change Venue (approved, waiting_event_date, selling_tickets)
                                      if (event.status == EventStatus.approved ||
                                          event.status == EventStatus.waiting_event_date ||
                                          event.status == EventStatus.selling_tickets)
                                        _menuTile(
                                          icon: Icons.location_on_rounded,
                                          iconColor: Colors.indigo,
                                          label: 'Change Venue',
                                          trailing: event.venue?.name,
                                          onTap: () => _selectVenueForEvent(context, event),
                                        ),

                                      // Change Ticket Strategy (approved, waiting_event_date)
                                      if (event.status == EventStatus.approved ||
                                          event.status == EventStatus.waiting_event_date)
                                        _menuTile(
                                          icon: Icons.confirmation_number_rounded,
                                          iconColor: Colors.deepPurple,
                                          label: 'Change Ticket Strategy',
                                          trailing: event.ticketStrategyName,
                                          onTap: () => _selectStrategyForEvent(context, event),
                                        ),

                                      // Increase Capacity (approved, waiting_event_date, selling_tickets, live)
                                      if (event.status == EventStatus.approved ||
                                          event.status == EventStatus.waiting_event_date ||
                                          event.status == EventStatus.selling_tickets ||
                                          event.status == EventStatus.live)
                                        _menuTile(
                                          icon: Icons.group_add_rounded,
                                          iconColor: Colors.teal,
                                          label: 'Increase Capacity',
                                          trailing: '${event.maxCapacity}',
                                          onTap: () => _showChangeCapacityDialog(context, event),
                                        ),

                                      // Extend Funding (waiting_event_date)
                                      if (event.status == EventStatus.waiting_event_date)
                                        _menuTile(
                                          icon: Icons.more_time_rounded,
                                          iconColor: AppTheme.accentColor,
                                          label: 'Extend Funding',
                                          onTap: () => _showExtendFundingDialog(context, event),
                                        ),

                                      // Cancel — organizer or admin for pre-selling
                                      if (event.status == EventStatus.pending_approval ||
                                          event.status == EventStatus.approved ||
                                          event.status == EventStatus.waiting_event_date)
                                        _menuTile(
                                          icon: Icons.cancel_rounded,
                                          iconColor: AppTheme.errorColor,
                                          label: 'Cancel Event',
                                          onTap: () => _confirmCancel(context, eventProvider, event.id),
                                          isDanger: true,
                                        ),

                                      // Cancel — admin only for selling/live
                                      if ((event.status == EventStatus.selling_tickets ||
                                              event.status == EventStatus.live) &&
                                          user != null && user.isAdmin)
                                        _menuTile(
                                          icon: Icons.cancel_rounded,
                                          iconColor: AppTheme.errorColor,
                                          label: 'Cancel Event (Admin)',
                                          onTap: () => _confirmCancel(context, eventProvider, event.id),
                                          isDanger: true,
                                        ),

                                      // Request Cancellation — organizer (not admin) during selling
                                      if (event.status == EventStatus.selling_tickets &&
                                          user != null && !user.isAdmin &&
                                          event.pendingCancellation == null)
                                        _menuTile(
                                          icon: Icons.cancel_outlined,
                                          iconColor: AppTheme.warningColor,
                                          label: 'Request Cancellation',
                                          onTap: () => _requestCancellation(context, eventProvider, event.id),
                                        ),

                                      // Delete (draft or cancelled only)
                                      if (event.status == EventStatus.draft ||
                                          event.status == EventStatus.cancelled)
                                        _menuTile(
                                          icon: Icons.delete_forever_rounded,
                                          iconColor: AppTheme.errorColor,
                                          label: 'Delete Permanently',
                                          onTap: () => _confirmDelete(context, eventProvider, event.id),
                                          isDanger: true,
                                        ),
                                    ],
                                  ),
                                ),
                              ],

                              // ──────── Management shortcuts (organizer) ────────
                              if (user != null &&
                                  (user.isOrganizer || user.isAdmin)) ...[
                                const SizedBox(height: 28),
                                _sectionTitle(context, 'Management'),
                                const SizedBox(height: 12),
                                _buildMgmtButtons(event),
                              ],

                              // ──────── Ticket Tier Management (organizer) ────────
                              if (user != null &&
                                  (user.isOrganizer || user.isAdmin) &&
                                  event.ticketStrategyId != null)
                                _buildTicketTierManagement(event),

                              // ──────── Event Feed / Posts (self-contained) ────────
                              const SizedBox(height: 32),
                              _EventFeed(
                                eventId: widget.eventId,
                                postsEnabled: event.postsEnabled,
                                isRegistered: _isRegistered,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
    );
  }

  // Posts section moved into _EventFeed widget

  // ─── Add image button ───

  Widget _addImageButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _showAddImageDialog(context),
      icon: const Icon(Icons.add_photo_alternate, size: 18),
      label: const Text('Add Image URL'),
    );
  }

  Future<void> _showAddImageDialog(BuildContext context) async {
    final urlCtrl = TextEditingController();
    final captionCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Image'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Image URL',
                hintText: 'https://...',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: captionCtrl,
              decoration: const InputDecoration(
                labelText: 'Caption (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (urlCtrl.text.trim().isEmpty) return;
              try {
                final api = context.read<ApiService>();
                await api.addEventImage(
                  widget.eventId,
                  imageUrl: urlCtrl.text.trim(),
                  caption: captionCtrl.text.trim().isEmpty
                      ? null
                      : captionCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadImages();
              } catch (e) {
                if (context.mounted) {
                  AppToast.fromError(context, e, fallback: 'Image upload failed');
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ───

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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.surfaceOf(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: Colors.grey[600]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: Colors.grey[400], letterSpacing: 0.3)),
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

  Widget _statusPill(EventStatus status) {
    final label = _statusLabel(status);
    final bgColor = _statusColor(status);
    final fgColor = _statusForeground(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
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
        borderRadius: BorderRadius.circular(20),
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

  Widget _trustBadgePill(Event event) {
    final label = event.organizerTrustLabel;
    final score = event.organizerTrustScore;
    final Color color;
    final IconData icon;
    switch (label) {
      case 'Excellent':
        color = const Color(0xFF05944F);
        icon = Icons.verified_rounded;
        break;
      case 'Good':
        color = const Color(0xFF0077B6);
        icon = Icons.verified_outlined;
        break;
      case 'Fair':
        color = Colors.orange;
        icon = Icons.shield_outlined;
        break;
      case 'Low':
        color = Colors.red;
        icon = Icons.warning_amber_rounded;
        break;
      default: // New
        color = Colors.grey;
        icon = Icons.person_outline;
    }
    return Tooltip(
      message: '${event.organizerCompletedEvents} completed / ${event.organizerPublishedEvents} published events',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
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

  Color _statusForeground(EventStatus status) {
    switch (status) {
      case EventStatus.draft:
        return Colors.grey[600]!;
      case EventStatus.pending_approval:
        return Colors.orange[800]!;
      case EventStatus.approved:
        return AppTheme.secondaryColor;
      case EventStatus.selling_tickets:
        return Colors.teal[700]!;
      case EventStatus.waiting_event_date:
        return Colors.orange[700]!;
      case EventStatus.live:
        return AppTheme.accentColor;
      case EventStatus.completed:
        return Colors.grey[500]!;
      case EventStatus.cancelled:
        return AppTheme.errorColor;
    }
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

  // ── Modern Quick Action Bar ──
  Widget _buildQuickActionBar(BuildContext context, Event event, dynamic user) {
    final isCustomer = user != null && user.isCustomer;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerOf(context)),
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
                      color: _regStatus == 'waitlisted' ? AppTheme.warningColor : AppTheme.primaryColor,
                      filled: _regStatus != 'waitlisted',
                      onTap: _regLoading || _regStatus == 'waitlisted' ? null : () => _register(context),
                    ),
            ),

          // Spacer between register and utility actions
          if (isCustomer && event.canUnregister) const SizedBox(width: 6),

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
          const SizedBox(width: 6),

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
    return Material(
      color: filled ? color : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 18,
                  color: filled ? Colors.white : color),
              const SizedBox(width: 6),
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
    );
  }

  Widget _buildTicketTiersSection(Event event) {
    final api = context.read<ApiService>();
    final user = context.read<AuthProvider>().user;
    final isCustomer = user != null && !user.isOrganizer && !user.isAdmin;

    return FutureBuilder(
      future: api.dio.get('/events/${event.id}/ticket-tiers'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Text('Could not load ticket tiers');
        }
        final tiers = snapshot.data!.data as List;
        if (tiers.isEmpty) {
          return Text('No tiers configured yet',
              style: TextStyle(color: Colors.grey[500]));
        }
        return Column(
          children: tiers.map((t) {
            final tierId = t['id'];
            final name = t['name'] ?? 'Tier';
            final desc = t['description'] as String?;
            final priceCents = t['price_cents'] ?? 0;
            final isFree = priceCents == 0;
            final basePrice = isFree ? null : (priceCents / 100).toStringAsFixed(2);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tier name + base price
                    Row(
                      children: [
                        const Icon(Icons.confirmation_number,
                            size: 18, color: Colors.teal),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ),
                        if (isFree)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Text('FREE',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: Colors.green.shade700)),
                          )
                        else
                          Text('\$$basePrice',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.teal)),
                      ],
                    ),
                    if (desc != null && desc.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 28, top: 3),
                        child: Text(desc,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic)),
                      ),
                    // Discount breakdown for logged-in customers
                    if (isCustomer && !isFree)
                      _TicketPriceBreakdown(eventId: event.id, tierId: tierId, basePriceCents: priceCents),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _showBuyTicketDialog(Event event) async {
    // Load ticket tiers for this event
    try {
      final api = context.read<ApiService>();
      final tiersData = await api.dio.get('/events/${event.id}/ticket-tiers');
      final tiers = (tiersData.data as List);
      if (tiers.isEmpty) {
        if (mounted) {
          AppToast.error(context, 'No ticket tiers available for this event');
        }
        return;
      }
      if (!mounted) return;

      // Fetch price previews for each tier in parallel
      final previews = <int, Map<String, dynamic>>{};
      await Future.wait(tiers.map((t) async {
        final tierId = t['id'];
        final baseCents = t['price_cents'] ?? 0;
        if (baseCents > 0) {
          try {
            final resp = await api.dio.get(
              '/events/${event.id}/ticket-price',
              queryParameters: {'ticket_tier_id': tierId},
            );
            previews[tierId] = resp.data;
          } catch (_) {}
        }
      }));
      if (!mounted) return;

      // Step 1: Select a tier
      await showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Select a Ticket Tier'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: tiers.length,
                itemBuilder: (context, i) {
                  final t = tiers[i];
                  final name = t['name'] ?? 'Tier';
                  final desc = t['description'] as String?;
                  final baseCents = t['price_cents'] ?? 0;
                  final tierId = t['id'];
                  final preview = previews[tierId];
                  final finalCents = preview?['final_price_cents'] ?? baseCents;
                  final totalDiscount = preview?['total_discount_cents'] ?? 0;
                  final isFree = finalCents == 0;
                  final basePrice = (baseCents / 100).toStringAsFixed(2);
                  final finalPrice = (finalCents / 100).toStringAsFixed(2);

                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _showInvoiceDialog(event, t, preview);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(Icons.confirmation_number, color: Colors.teal, size: 28),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                  const SizedBox(height: 4),
                                  if (isFree)
                                    Row(
                                      children: [
                                        if (baseCents > 0) ...[
                                          Text('\$$basePrice',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[500],
                                                  decoration: TextDecoration.lineThrough)),
                                          const SizedBox(width: 6),
                                        ],
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.green.shade300),
                                          ),
                                          child: Text('FREE',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 11,
                                                  color: Colors.green.shade700)),
                                        ),
                                      ],
                                    )
                                  else if (totalDiscount > 0)
                                    Row(
                                      children: [
                                        Text('\$$basePrice',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[500],
                                                decoration: TextDecoration.lineThrough)),
                                        const SizedBox(width: 6),
                                        Text('\$$finalPrice',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.teal)),
                                        const SizedBox(width: 4),
                                        Text('(-\$${(totalDiscount / 100).toStringAsFixed(2)})',
                                            style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
                                      ],
                                    )
                                  else
                                    Text('\$$basePrice', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  if (desc != null && desc.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(desc,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                              fontStyle: FontStyle.italic)),
                                    ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondaryOf(context)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to load tiers');
      }
    }
  }

  /// Step 2: Show invoice/price breakdown with quantity counter before confirming purchase.
  Future<void> _showInvoiceDialog(
      Event event, Map<String, dynamic> tier, Map<String, dynamic>? preview) async {
    final tierName = tier['name'] ?? 'Ticket';
    final tierId = tier['id'] as int;
    final baseCents = (tier['price_cents'] ?? 0) as int;
    final commonDisc = (preview?['common_discount_cents'] ?? 0) as int;
    final selectiveDisc = (preview?['selective_discount_cents'] ?? 0) as int;
    final pledgeDisc = (preview?['pledge_discount_cents'] ?? 0) as int;
    final eventDisc = (preview?['event_discount_cents'] ?? 0) as int;
    final totalDiscountPerTicket = (preview?['total_discount_cents'] ?? 0) as int;
    final finalCentsPerTicket = (preview?['final_price_cents'] ?? baseCents) as int;
    final commissionPerTicket = (preview?['commission_cents'] ?? 0) as int;

    String fmtCents(int c) => '\$${(c / 100).toStringAsFixed(2)}';

    int quantity = 1;

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final totalFinal = finalCentsPerTicket * quantity;
          final totalDiscount = totalDiscountPerTicket * quantity;
          final totalCommission = commissionPerTicket * quantity;
          final isFree = finalCentsPerTicket == 0;
          final spotsUsed = _myReservedSpots > 0 ? (_myReservedSpots < quantity ? _myReservedSpots : quantity) : 0;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: EdgeInsets.zero,
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 32),
                        const SizedBox(height: 8),
                        const Text('Invoice',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(event.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13)),
                      ],
                    ),
                  ),

                  // Invoice body
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tier info
                        Row(
                          children: [
                            const Icon(Icons.confirmation_number_rounded,
                                size: 18, color: Colors.teal),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(tierName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 16)),
                            ),
                          ],
                        ),

                        // Quantity selector
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceOf(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.dividerOf(context)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.people_rounded, size: 18, color: Colors.teal[600]),
                              const SizedBox(width: 10),
                              const Text('Quantity',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              const Spacer(),
                              // Minus button
                              GestureDetector(
                                onTap: quantity > 1
                                    ? () => setDialogState(() => quantity--)
                                    : null,
                                child: Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    color: quantity > 1 ? Colors.teal : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.remove, size: 18,
                                      color: quantity > 1 ? Colors.white : Colors.grey[400]),
                                ),
                              ),
                              SizedBox(
                                width: 44,
                                child: Text('$quantity',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 18, fontWeight: FontWeight.w800)),
                              ),
                              // Plus button
                              GestureDetector(
                                onTap: quantity < 10
                                    ? () => setDialogState(() => quantity++)
                                    : null,
                                child: Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    color: quantity < 10 ? Colors.teal : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.add, size: 18,
                                      color: quantity < 10 ? Colors.white : Colors.grey[400]),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (_myTicketCount > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded, size: 15, color: Colors.teal[600]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'You already have $_myTicketCount ticket${_myTicketCount == 1 ? '' : 's'} for this event',
                                    style: TextStyle(fontSize: 12, color: Colors.teal[700], fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (_myReservedSpots > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.event_seat_rounded, size: 15, color: Colors.deepPurple[600]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Using $spotsUsed of your $_myReservedSpots reserved spot${_myReservedSpots == 1 ? '' : 's'} from pledging',
                                    style: TextStyle(fontSize: 12, color: Colors.deepPurple[700], fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Price breakdown
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceOf(context),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              _invoiceRow('Ticket Price', fmtCents(baseCents)),
                              if (commonDisc > 0) ...[
                                const SizedBox(height: 8),
                                _invoiceRow('Common Discount',
                                    '- ${fmtCents(commonDisc)}',
                                    valueColor: AppTheme.successColor),
                              ],
                              if (selectiveDisc > 0) ...[
                                const SizedBox(height: 8),
                                _invoiceRow('Selective Discount',
                                    '- ${fmtCents(selectiveDisc)}',
                                    valueColor: AppTheme.successColor),
                              ],
                              if (pledgeDisc > 0) ...[
                                const SizedBox(height: 8),
                                _invoiceRow('Pledge Discount',
                                    '- ${fmtCents(pledgeDisc)}',
                                    valueColor: AppTheme.successColor),
                              ],
                              if (eventDisc > 0) ...[
                                const SizedBox(height: 8),
                                _invoiceRow('Event Discount',
                                    '- ${fmtCents(eventDisc)}',
                                    valueColor: AppTheme.successColor),
                              ],
                              if (commissionPerTicket > 0) ...[
                                const SizedBox(height: 8),
                                _invoiceRow('Platform Fee',
                                    fmtCents(commissionPerTicket),
                                    valueColor: Colors.grey[500]!),
                              ],
                              if (quantity > 1) ...[
                                const SizedBox(height: 8),
                                Container(height: 1, color: AppTheme.dividerOf(context)),
                                const SizedBox(height: 8),
                                _invoiceRow('Per Ticket',
                                    isFree ? 'FREE' : fmtCents(finalCentsPerTicket)),
                                const SizedBox(height: 4),
                                _invoiceRow('x Quantity', '$quantity'),
                              ],
                              const SizedBox(height: 10),
                              Container(height: 1, color: AppTheme.dividerOf(context)),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(quantity > 1 ? 'Total ($quantity tickets)' : 'Total',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 17)),
                                  Text(
                                    isFree ? 'FREE' : fmtCents(totalFinal),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 20,
                                      letterSpacing: -0.5,
                                      color: isFree
                                          ? AppTheme.successColor
                                          : Colors.teal,
                                    ),
                                  ),
                                ],
                              ),
                              if (totalDiscount > 0) ...[
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.successColor
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'You save ${fmtCents(totalDiscount)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.successColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (totalCommission > 0) ...[
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Includes ${fmtCents(totalCommission)} platform fee',
                                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Buy button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.of(ctx).pop(quantity),
                            icon: Icon(isFree
                                ? Icons.check_circle_rounded
                                : Icons.shopping_cart_rounded),
                            label: Text(
                              isFree
                                  ? (quantity > 1 ? 'Get $quantity Free Tickets' : 'Get Free Ticket')
                                  : (quantity > 1 ? 'Buy $quantity Tickets' : 'Confirm Purchase'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isFree ? Colors.green : Colors.teal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Back to tiers
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => Navigator.of(ctx).pop(0),
                            child: const Text('Back to Tiers'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result != null && result > 0 && mounted) {
      await _purchaseTickets(event.id, tierId, result);
    } else if (result == 0 && mounted) {
      // Go back to tier selection
      _showBuyTicketDialog(event);
    }
  }

  Widget _invoiceRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor)),
      ],
    );
  }

  Future<void> _purchaseTickets(int eventId, int tierId, int quantity) async {
    try {
      final api = context.read<ApiService>();
      final salesList = await api.purchaseTickets(eventId, tierId: tierId, quantity: quantity);
      if (salesList.isEmpty) return;

      final first = salesList[0] as Map<String, dynamic>;
      final status = first['status'] ?? 'purchased';
      final purchaseGroupId = first['purchase_group_id'];

      if (mounted) {
        if (status == 'waitlisted') {
          AppToast.info(context,
              quantity > 1
                  ? 'Event is at capacity — your $quantity tickets are waiting for organizer approval.'
                  : 'Event is at capacity — your ticket is waiting for organizer approval.');
        } else {
          final totalPaid = salesList.fold<int>(0, (sum, s) => sum + ((s['amount_paid_cents'] ?? 0) as int));
          final isFree = totalPaid == 0;
          final ticketWord = quantity > 1 ? '$quantity tickets' : 'ticket';
          final priceStr = isFree
              ? 'Free $ticketWord'
              : 'Paid \$${(totalPaid / 100).toStringAsFixed(2)} for $ticketWord';
          AppToast.success(context, priceStr);
          // Refresh ticket count, reserved spots & event data
          _loadMyTicketCount();
          _loadMyReservedSpots();
          context.read<EventProvider>().loadEvent(eventId);
          // Navigate to receipt
          if (mounted) {
            final event = context.read<EventProvider>().selectedEvent;
            if (quantity > 1 && purchaseGroupId != null) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PurchaseGroupReceiptScreen(
                    eventId: eventId,
                    purchaseGroupId: purchaseGroupId,
                    showBuyAgain: true,
                    onBuyAgain: event != null ? () => _showBuyTicketDialog(event) : null,
                  ),
                ),
              );
            } else {
              final saleId = first['id'] as int;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TicketReceiptScreen(
                    eventId: eventId,
                    saleId: saleId,
                    showBuyAgain: true,
                    onBuyAgain: event != null ? () => _showBuyTicketDialog(event) : null,
                  ),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Purchase failed');
      }
    }
  }

  Widget _buildYourTicketsSection() {
    final scannedCount = _myEventTickets.where((t) => t['scanned_at'] != null).length;
    final dateFmt = DateFormat('MMM d \u2022 h:mm a');
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            child: Row(
              children: [
                const Icon(Icons.confirmation_number_rounded, size: 18, color: Colors.teal),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Tickets ($_myTicketCount)',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.teal),
                      ),
                      if (scannedCount > 0)
                        Text(
                          '$scannedCount of $_myTicketCount scanned',
                          style: TextStyle(fontSize: 11, color: Colors.teal[400]),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/my-tickets?eventId=${widget.eventId}'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          // Ticket mini-cards (max 3 shown, rest collapsed)
          ..._myEventTickets.take(3).map((t) {
            final ticketCode = t['ticket_code'] ?? '';
            final receiptNumber = t['receipt_number'] ?? '';
            final status = t['status'] ?? '';
            final isScanned = t['scanned_at'] != null;
            final saleId = t['id'] as int;
            final createdAt = t['created_at'] != null
                ? dateFmt.format(DateTime.parse(t['created_at']).toLocal())
                : '';
            return GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TicketReceiptScreen(
                    eventId: widget.eventId,
                    saleId: saleId,
                  ),
                ),
              ),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.cardOf(context),
                  borderRadius: BorderRadius.circular(10),
                  border: isScanned
                      ? Border.all(color: AppTheme.successColor.withValues(alpha: 0.25))
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      isScanned ? Icons.check_circle_rounded : Icons.qr_code_rounded,
                      size: 16,
                      color: isScanned ? AppTheme.successColor : Colors.grey[400],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            receiptNumber.isNotEmpty ? receiptNumber : ticketCode,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(createdAt,
                              style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: status == 'purchased'
                            ? AppTheme.successColor.withValues(alpha: 0.1)
                            : AppTheme.warningColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: status == 'purchased' ? AppTheme.successColor : AppTheme.warningColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey[400]),
                  ],
                ),
              ),
            );
          }),
          if (_myTicketCount > 3)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 2),
              child: Text(
                '+${_myTicketCount - 3} more ticket${_myTicketCount - 3 == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _infoBanner(String text, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
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
        return 'UNDER REVIEW';
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
    }
  }

  Color _statusColor(EventStatus status) {
    switch (status) {
      case EventStatus.draft:
        return Colors.grey.withValues(alpha: 0.2);
      case EventStatus.pending_approval:
        return AppTheme.warningColor.withValues(alpha: 0.2);
      case EventStatus.approved:
        return AppTheme.successColor.withValues(alpha: 0.2);
      case EventStatus.selling_tickets:
        return Colors.teal.withValues(alpha: 0.2);
      case EventStatus.waiting_event_date:
        return Colors.orange.withValues(alpha: 0.2);
      case EventStatus.live:
        return AppTheme.secondaryColor.withValues(alpha: 0.2);
      case EventStatus.completed:
        return Colors.grey.withValues(alpha: 0.2);
      case EventStatus.cancelled:
        return AppTheme.errorColor.withValues(alpha: 0.2);
    }
  }

  Future<void> _cloneEvent(BuildContext context, int eventId) async {
    try {
      final api = context.read<ApiService>();
      final data = await api.cloneEvent(eventId);
      if (!mounted) return;
      final newId = data['id'];
      AppToast.success(context, 'Event cloned as draft! Redirecting to edit...');
      context.push('/events/$newId/edit');
    } catch (e) {
      if (!mounted) return;
      AppToast.fromError(context, e, fallback: 'Clone failed');
    }
  }

  Future<void> _confirmStartSelling(
      BuildContext context, EventProvider eventProvider, Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Selling Tickets'),
        content: const Text(
            'Once you start selling, attendees can purchase tickets immediately. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('Start Selling'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final ok = await eventProvider.startSellingTickets(event.id);
      if (ok && mounted) {
        AppToast.success(context, 'Tickets are now on sale!');
      } else if (!ok && mounted) {
        AppToast.error(context, eventProvider.error ?? 'Failed to start selling tickets');
      }
    }
  }

  Future<void> _selectVenueForEvent(BuildContext context, Event event) async {
    final selected = await Navigator.push<Venue>(
      context,
      MaterialPageRoute(
        builder: (_) => VenuePickerScreen(currentVenueId: event.venueId),
      ),
    );
    if (selected != null && mounted) {
      try {
        final api = context.read<ApiService>();
        final eventProvider = context.read<EventProvider>();
        await api.updateEvent(event.id, {'venue_id': selected.id});
        await eventProvider.loadEvent(event.id);
        if (mounted) {
          AppToast.success(context, 'Venue changed to ${selected.name}');
        }
      } catch (e) {
        if (mounted) {
          AppToast.fromError(context, e, fallback: 'Failed to change venue');
        }
      }
    }
  }

  Future<void> _selectStrategyForEvent(BuildContext context, Event event) async {
    final selected = await Navigator.push<TicketStrategy>(
      context,
      MaterialPageRoute(
        builder: (_) => StrategyPickerScreen(currentStrategyId: event.ticketStrategyId),
      ),
    );
    if (selected != null && mounted) {
      try {
        final api = context.read<ApiService>();
        final eventProvider = context.read<EventProvider>();
        await api.updateEvent(event.id, {'ticket_strategy_id': selected.id});
        await eventProvider.loadEvent(event.id);
        if (mounted) {
          AppToast.success(context, 'Strategy changed to ${selected.name}');
        }
      } catch (e) {
        if (mounted) {
          AppToast.fromError(context, e, fallback: 'Failed to change strategy');
        }
      }
    }
  }

  Future<void> _showChangeCapacityDialog(BuildContext context, Event event) async {
    final controller = TextEditingController(text: event.maxCapacity.toString());
    final api = context.read<ApiService>();
    final eventProvider = context.read<EventProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Max Capacity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current capacity: ${event.maxCapacity}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'New Max Capacity',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final val = int.tryParse(controller.text);
      if (val == null || val <= 0) {
        AppToast.error(context, 'Enter a valid number.');
        return;
      }
      try {
        await api.updateEvent(event.id, {'max_capacity': val});
        await eventProvider.loadEvent(event.id);
        if (mounted) {
          AppToast.success(context, 'Capacity updated to $val');
        }
      } catch (e) {
        if (mounted) {
          AppToast.fromError(context, e, fallback: 'Failed to update capacity');
        }
      }
    }
    controller.dispose();
  }

  Future<void> _confirmDelete(
      BuildContext context, EventProvider eventProvider, int eventId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text(
            'This will permanently delete this event. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await eventProvider.deleteEvent(eventId);
      if (success && context.mounted) {
        context.go('/');
      }
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

  Future<void> _confirmCancel(
      BuildContext context, EventProvider eventProvider, int eventId) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'All registered users will be notified. Please provide a reason:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason for cancellation',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Event'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final msg = await eventProvider.cancelEvent(eventId,
          reason: reasonCtrl.text.trim());
      if (context.mounted && msg != null) {
        AppToast.success(context, msg);
      }
    }
  }

  /// Organizer requests admin approval to cancel a selling_tickets event.
  Future<void> _requestCancellation(
      BuildContext context, EventProvider eventProvider, int eventId) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Cancellation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'This event is actively selling tickets. '
                'Your cancellation request will be sent to an admin for review.\n\n'
                'Please provide a reason:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason for cancellation',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final msg = await eventProvider.cancelEvent(eventId,
          reason: reasonCtrl.text.trim());
      if (context.mounted) {
        if (msg != null) {
          AppToast.success(context, msg);
        } else {
          AppToast.error(context, 'Failed to send cancellation request.');
        }
      }
    }
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

  // ═══════════════════════════════════════════
  // Management nav buttons
  // ═══════════════════════════════════════════

  Widget _buildMgmtButtons(Event event) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LiveMgmtStats(event: event),
        const SizedBox(height: 12),
        // Scan QR button (prominent, for selling/live events)
        if (event.status == EventStatus.selling_tickets ||
            event.status == EventStatus.live)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => context.push(
                  '/events/${event.id}/scan?title=${Uri.encodeComponent(event.title)}',
                ),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                label: const Text('Scan Tickets',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        // Co-organizers button
        _mgmtActionCard(
          icon: Icons.group_rounded,
          label: 'Co-Organizers',
          color: AppTheme.accentColor,
          onTap: () => context.push('/events/${event.id}/co-organizers'),
        ),
        const SizedBox(height: 12),
        // Inline discount attach/detach
        _EventDiscountDropdown(eventId: event.id),
        // Pending extension banner
        if (event.pendingExtension != null) ...[
          const SizedBox(height: 12),
          _buildPendingExtensionBanner(event),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════
  // Modern Organizer UI Widgets
  // ═══════════════════════════════════════════

  Widget _primaryActionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onPressed,
    bool buttonEnabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: buttonEnabled ? onPressed : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: color,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.5),
                disabledForegroundColor: color.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(buttonLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _setupTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required bool isSet,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSet
                ? color.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const Spacer(),
                if (isSet)
                  Icon(Icons.check_circle, size: 16, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87)),
            Text(subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    String? trailing,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDanger ? AppTheme.errorColor : Colors.black87,
                  )),
            ),
            if (trailing != null)
              Text(trailing,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right,
                size: 18, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _mgmtActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingExtensionBanner(Event event) {
    final ext = event.pendingExtension!;
    final user = context.read<AuthProvider>().user;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 18, color: AppTheme.warningColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Extension Pending Admin Approval',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.warningColor, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (ext['funding_end_at'] != null)
            Text('New funding deadline: ${ext['funding_end_at']}',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context))),
          if (ext['funding_goal_cents'] != null)
            Text('New funding goal: \$${(ext['funding_goal_cents'] / 100).toStringAsFixed(2)}',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context))),
          if (user != null && user.isAdmin) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _decideExtension(event.id, 'approve'),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.successColor),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _decideExtension(event.id, 'reject'),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorColor),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _decideExtension(int eventId, String action) async {
    try {
      await ApiService().decideExtension(eventId, action);
      if (mounted) {
        AppToast.success(context, 'Extension ${action}d');
        context.read<EventProvider>().loadEvent(eventId);
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Extension decision failed');
      }
    }
  }

  // ═══════════════════════════════════════════
  // Extend Funding Dialog (deadline + goal, admin approval)
  // ═══════════════════════════════════════════

  Future<void> _showExtendFundingDialog(BuildContext context, Event event) async {
    final fundingEndCtrl = TextEditingController();
    final goalCtrl = TextEditingController(
      text: event.fundingGoalCents != null
          ? (event.fundingGoalCents! / 100).toStringAsFixed(2)
          : '',
    );
    DateTime? pickedDeadline;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Extend Funding'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This will send a request to admin for approval.',
                          style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    pickedDeadline != null
                        ? DateFormat('MMM d, y – h:mm a').format(pickedDeadline!)
                        : 'Pick new funding deadline',
                    style: TextStyle(
                      fontSize: 14,
                      color: pickedDeadline != null ? Colors.black : Colors.grey,
                    ),
                  ),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null && ctx.mounted) {
                      final time = await showTimePicker(
                        context: ctx,
                        initialTime: const TimeOfDay(hour: 23, minute: 59),
                      );
                      setDialogState(() {
                        pickedDeadline = DateTime(
                          date.year, date.month, date.day,
                          time?.hour ?? 23, time?.minute ?? 59,
                        );
                        fundingEndCtrl.text = pickedDeadline!.toIso8601String();
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: goalCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'New Funding Goal (\$)',
                    prefixText: '\$ ',
                    helperText: 'Leave empty to keep current goal',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final data = <String, dynamic>{};
                if (fundingEndCtrl.text.trim().isNotEmpty) {
                  data['funding_end_at'] = fundingEndCtrl.text.trim();
                }
                final goalText = goalCtrl.text.trim();
                if (goalText.isNotEmpty) {
                  final parsed = double.tryParse(goalText);
                  if (parsed != null && parsed > 0) {
                    data['funding_goal_cents'] = (parsed * 100).toInt();
                  }
                }
                Navigator.pop(ctx, data);
              },
              child: const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
    if (result == null || result.isEmpty) return;
    try {
      await context.read<ApiService>().extendFunding(event.id, result);
      if (mounted) {
        AppToast.success(context, 'Extension request submitted for admin approval');
        context.read<EventProvider>().loadEvent(event.id);
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to request extension');
      }
    }
  }

  // ═══════════════════════════════════════════
  // Set Event Date Dialog (direct, no admin approval)
  // ═══════════════════════════════════════════

  Future<void> _showSetEventDateDialog(BuildContext context, Event event) async {
    final api = context.read<ApiService>();

    DateTime? pickedStart;
    DateTime? pickedEnd;

    if (!mounted) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final bool canSubmit = pickedStart != null && pickedEnd != null;

          return AlertDialog(
            title: const Text('Set Event Date'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This applies immediately — no admin approval needed.',
                              style: TextStyle(color: Colors.green.shade700, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ── Start time ──
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.play_arrow_rounded, color: Colors.teal),
                      title: Text(
                        pickedStart != null
                            ? DateFormat('MMM d, y – h:mm a').format(pickedStart!)
                            : 'Pick start time',
                        style: TextStyle(
                          fontSize: 14,
                          color: pickedStart != null ? Colors.black : Colors.grey,
                        ),
                      ),
                      subtitle: const Text('Event start', style: TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.edit_calendar),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now().add(const Duration(days: 14)),
                          firstDate: DateTime.now().add(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 730)),
                        );
                        if (date != null && ctx.mounted) {
                          final time = await showTimePicker(
                            context: ctx,
                            initialTime: const TimeOfDay(hour: 18, minute: 0),
                          );
                          setDialogState(() {
                            pickedStart = DateTime(
                              date.year, date.month, date.day,
                              time?.hour ?? 18, time?.minute ?? 0,
                            );
                          });
                        }
                      },
                    ),
                    const Divider(),
                    // ── End time ──
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.stop_rounded, color: Colors.redAccent),
                      title: Text(
                        pickedEnd != null
                            ? DateFormat('MMM d, y – h:mm a').format(pickedEnd!)
                            : 'Pick end time',
                        style: TextStyle(
                          fontSize: 14,
                          color: pickedEnd != null ? Colors.black : Colors.grey,
                        ),
                      ),
                      subtitle: const Text('Event end', style: TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.edit_calendar),
                      onTap: () async {
                        final initialDate = pickedStart?.add(const Duration(hours: 4)) ??
                            DateTime.now().add(const Duration(days: 14));
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: initialDate,
                          firstDate: pickedStart ?? DateTime.now().add(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 730)),
                        );
                        if (date != null && ctx.mounted) {
                          final time = await showTimePicker(
                            context: ctx,
                            initialTime: const TimeOfDay(hour: 22, minute: 0),
                          );
                          setDialogState(() {
                            pickedEnd = DateTime(
                              date.year, date.month, date.day,
                              time?.hour ?? 22, time?.minute ?? 0,
                            );
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'After setting dates, you can start selling tickets from the organizer actions.',
                              style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: canSubmit
                    ? () {
                        final data = <String, dynamic>{
                          'start_time': pickedStart!.toIso8601String(),
                          'end_time': pickedEnd!.toIso8601String(),
                        };
                        Navigator.pop(ctx, data);
                      }
                    : null,
                child: const Text('Set Date'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || result.isEmpty) return;
    try {
      await api.setEventDate(event.id, result);
      if (mounted) {
        AppToast.success(context, 'Event date set!');
        context.read<EventProvider>().loadEvent(event.id);
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to set event date');
      }
    }
  }

  // ═══════════════════════════════════════════
  // Ticket Tier Management (Edit / Delete)
  // ═══════════════════════════════════════════

  Widget _buildTicketTierManagement(Event event) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        _sectionTitle(context, 'Manage Ticket Tiers'),
        const SizedBox(height: 12),
        FutureBuilder<List<dynamic>>(
          future:
              context.read<ApiService>().dio.get('/events/${event.id}/ticket-tiers').then((r) => r.data as List),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Could not load tiers',
                  style: TextStyle(color: Colors.grey[500]));
            }
            final tiers = snapshot.data ?? [];
            if (tiers.isEmpty) {
              return Text('No tiers configured',
                  style: TextStyle(color: Colors.grey[500]));
            }
            return Column(
              children: tiers.map((tier) {
                final tierId = tier['id'];
                final name = tier['name'] ?? '';
                final desc = tier['description'] ?? '';
                final priceCents = tier['price_cents'] ?? 0;
                final price =
                    '\$${(priceCents / 100).toStringAsFixed(2)}';
                final canDelete = event.status != EventStatus.selling_tickets &&
                    event.status != EventStatus.live;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.cardOf(context),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15)),
                            if (desc.isNotEmpty)
                              Text(desc,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600])),
                            Text(price,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.successColor)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Edit tier',
                        onPressed: () => _showEditTierDialog(
                            event.id, tierId, name, desc, priceCents),
                      ),
                      if (canDelete)
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 20, color: AppTheme.errorColor),
                          tooltip: 'Delete tier',
                          onPressed: () =>
                              _confirmDeleteTier(event.id, tierId, name),
                        ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Future<void> _showEditTierDialog(int eventId, int tierId, String name,
      String description, int priceCents) async {
    final nameCtrl = TextEditingController(text: name);
    final descCtrl = TextEditingController(text: description);
    final priceCtrl = TextEditingController(
        text: (priceCents / 100).toStringAsFixed(2));

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Tier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Tier Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceCtrl,
              decoration: const InputDecoration(
                  labelText: 'Price', prefixText: '\$ '),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final price = double.tryParse(priceCtrl.text);
              if (nameCtrl.text.trim().isEmpty || price == null) return;
              try {
                final api = context.read<ApiService>();
                await api.updateTicketTier(eventId, tierId, {
                  'name': nameCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'price_cents': (price * 100).toInt(),
                });
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  AppToast.fromError(ctx, e, fallback: 'Failed to update tier');
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      setState(() {});
      AppToast.success(context, 'Tier updated!');
    }
  }

  Future<void> _confirmDeleteTier(
      int eventId, int tierId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Tier'),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child:
                const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final api = context.read<ApiService>();
        await api.deleteTicketTier(eventId, tierId);
        if (mounted) {
          setState(() {});
          AppToast.success(context, 'Tier deleted.');
        }
      } catch (e) {
        if (mounted) {
          AppToast.fromError(context, e, fallback: 'Failed to delete tier');
        }
      }
    }
  }

  // ═══════════════════════════════════════════
}

// ═══════════════════════════════════════════
// Live Management Stats — clickable stat chips
// (sold, scanned, waitlist, revenue)
// ═══════════════════════════════════════════

class _LiveMgmtStats extends StatefulWidget {
  final Event event;
  const _LiveMgmtStats({required this.event});

  @override
  State<_LiveMgmtStats> createState() => _LiveMgmtStatsState();
}

class _LiveMgmtStatsState extends State<_LiveMgmtStats> {
  int _soldCount = 0;
  int _scannedCount = 0;
  int _fundingWaitlistCount = 0;
  int _ticketWaitlistCount = 0;
  int _revenueCents = 0;
  bool _loading = true;

  Event get _event => widget.event;
  int get _eventId => _event.id;

  bool get _isEarlyPhase =>
      _event.status == EventStatus.draft ||
      _event.status == EventStatus.pending_approval ||
      _event.status == EventStatus.approved ||
      _event.status == EventStatus.waiting_event_date;

  bool get _isTicketPhase =>
      _event.status == EventStatus.selling_tickets ||
      _event.status == EventStatus.live;

  bool get _isCompleted => _event.status == EventStatus.completed;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();

      if (_isEarlyPhase) {
        // Only need registrations for early phases
        final regs = await api.getRegistrations(_eventId);
        final waitlisted =
            regs.where((r) => r['status'] == 'waitlist').length;
        if (mounted) {
          setState(() {
            _fundingWaitlistCount = waitlisted;
            _loading = false;
          });
        }
      } else {
        // Ticket & completed phases: load everything
        final results = await Future.wait([
          api.getTicketSales(_eventId),
          api.getScannedTickets(_eventId),
          api.getRegistrations(_eventId),
          api.getWaitlistedTickets(_eventId),
        ]);
        final allSales = results[0] as List;
        final scanned = results[1] as List;
        final regs = results[2] as List;
        final ticketWaitlist = results[3] as List;
        final revenue = allSales.fold<int>(
            0, (s, e) => s + ((e['amount_paid_cents'] ?? 0) as int));
        final fundingWaitlisted =
            regs.where((r) => r['status'] == 'waitlist').length;
        if (mounted) {
          setState(() {
            _soldCount = allSales.length;
            _scannedCount = scanned.length;
            _fundingWaitlistCount = fundingWaitlisted;
            _ticketWaitlistCount = ticketWaitlist.length;
            _revenueCents = revenue;
            _loading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final regCount = _event.registrationCount;
    final reservedCount = _event.totalReservedSpots;
    final soldCount = _event.ticketsSoldCount;
    final filledCount = reservedCount + soldCount; // capacity used = reserved + sold
    final maxCap = _event.maxCapacity;
    final isFull = maxCap > 0 && filledCount >= maxCap;

    // ── Early Phases ──
    if (_isEarlyPhase) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _statChip(
                  icon: Icons.people_rounded,
                  label: '$regCount registered',
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statChip(
                  icon: Icons.hourglass_top_rounded,
                  label: '$_fundingWaitlistCount fund waitlist',
                  color: AppTheme.warningColor,
                  onTap: () => context.push('/events/$_eventId/waitlist'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _capacityBadge(filledCount, maxCap, isFull),
        ],
      );
    }

    // ── Selling Tickets / Live ──
    if (_isTicketPhase) {
      return Column(
        children: [
          _capacityBadge(filledCount, maxCap, isFull),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _statChip(
                  icon: Icons.confirmation_number_rounded,
                  label: '$_soldCount sold',
                  color: AppTheme.primaryColor,
                  onTap: () => context.push('/events/$_eventId/ticket-sales'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statChip(
                  icon: Icons.qr_code_scanner_rounded,
                  label: '$_scannedCount scanned',
                  color: AppTheme.successColor,
                  onTap: () => context.push('/events/$_eventId/scanned-tickets'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _statChip(
                  icon: Icons.event_seat_rounded,
                  label: '$_ticketWaitlistCount ticket waitlist',
                  color: Colors.orange,
                  onTap: () => context.push('/events/$_eventId/ticket-waitlist'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statChip(
                  icon: Icons.attach_money_rounded,
                  label: '\$${(_revenueCents / 100).toStringAsFixed(0)} revenue',
                  color: Colors.teal,
                  onTap: () => context.push('/events/$_eventId/ticket-sales'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // ── Completed ── (read-only summary)
    if (_isCompleted) {
      return Column(
        children: [
          _capacityBadge(filledCount, maxCap, isFull),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _statChip(
                  icon: Icons.confirmation_number_rounded,
                  label: '$_soldCount sold',
                  color: AppTheme.primaryColor,
                  onTap: () => context.push('/events/$_eventId/ticket-sales'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statChip(
                  icon: Icons.qr_code_scanner_rounded,
                  label: '$_scannedCount scanned',
                  color: AppTheme.successColor,
                  onTap: () => context.push('/events/$_eventId/scanned-tickets'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _statChip(
                  icon: Icons.hourglass_top_rounded,
                  label: '$_fundingWaitlistCount fund wl',
                  color: AppTheme.warningColor,
                  onTap: () => context.push('/events/$_eventId/waitlist'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statChip(
                  icon: Icons.event_seat_rounded,
                  label: '$_ticketWaitlistCount ticket wl',
                  color: Colors.orange,
                  onTap: () => context.push('/events/$_eventId/ticket-waitlist'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _statChip(
            icon: Icons.attach_money_rounded,
            label: '\$${(_revenueCents / 100).toStringAsFixed(0)} total revenue',
            color: Colors.teal,
            onTap: () => context.push('/events/$_eventId/ticket-sales'),
          ),
        ],
      );
    }

    // Fallback (cancelled / unknown)
    return const SizedBox.shrink();
  }

  // ── Capacity badge ──
  Widget _capacityBadge(int registered, int maxCap, bool isFull) {
    final color = isFull ? AppTheme.errorColor : AppTheme.primaryColor;
    final label = maxCap > 0
        ? '$registered / $maxCap capacity'
        : '$registered registered';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFull ? Icons.warning_rounded : Icons.people_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (isFull) ...[
            const SizedBox(width: 6),
            Text('FULL',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: 1)),
          ],
        ],
      ),
    );
  }

  // ── Stat chip (tappable) ──
  Widget _statChip({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ═══════════════════════════════════════════
// Event Discount Dropdown (inline attach / detach)
// ═══════════════════════════════════════════

class _EventDiscountDropdown extends StatefulWidget {
  final int eventId;
  const _EventDiscountDropdown({required this.eventId});

  @override
  State<_EventDiscountDropdown> createState() => _EventDiscountDropdownState();
}

class _EventDiscountDropdownState extends State<_EventDiscountDropdown> {
  final _api = ApiService();
  List<Map<String, dynamic>> _allStrategies = [];
  List<Map<String, dynamic>> _attached = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final all = await _api.getDiscountStrategies();
      final attached = await _api.getEventDiscountStrategies(widget.eventId);
      setState(() {
        _allStrategies = all.cast<Map<String, dynamic>>();
        _attached = attached.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Set<int> get _attachedIds => _attached.map((d) => d['id'] as int).toSet();

  Future<void> _attach(int id, {required bool autoApply}) async {
    try {
      await _api.attachDiscountStrategy(widget.eventId, id, autoApply: autoApply);
      await _load();
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to attach');
      }
    }
  }

  Future<void> _detach(int id) async {
    try {
      await _api.detachDiscountStrategy(widget.eventId, id);
      await _load();
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to detach');
      }
    }
  }

  String _label(Map<String, dynamic> d) {
    final name = d['name'] ?? '';
    final type = d['discount_type'] ?? '';
    final val = d['value'] ?? 0;
    final target = d['target'] ?? 'all';
    final typeLabel = type == 'ticket_percent' ? '% ticket' : '% pledge';
    return '$name · $val$typeLabel · $target';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.discount_rounded, color: Colors.deepPurple, size: 20),
              const SizedBox(width: 8),
              const Text('Discounts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              if (_loading)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 10),
          // Attached discounts
          if (_attached.isNotEmpty) ...[
            ..._attached.map((d) {
              final autoApply = d['auto_apply'] == true;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.deepPurple.withOpacity(0.4), width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _label(d),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: autoApply
                                    ? Colors.green.withOpacity(0.25)
                                    : Colors.orange.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                autoApply ? 'Auto' : 'Claimable',
                                style: TextStyle(
                                  color: autoApply ? Colors.greenAccent : Colors.orangeAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _detach(d['id'] as int),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 16, color: Colors.white54),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 6),
          ],
          // Search
          TextField(
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search discounts…',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
          ),
          const SizedBox(height: 6),
          ..._buildAvailableList(),
        ],
      ),
    );
  }

  List<Widget> _buildAvailableList() {
    final available = _allStrategies.where((d) {
      final id = d['id'] as int;
      if (_attachedIds.contains(id)) return false;
      if (_search.isEmpty) return true;
      return _label(d).toLowerCase().contains(_search);
    }).toList();

    if (available.isEmpty && _search.isNotEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('No matching discounts', style: TextStyle(color: Colors.white38, fontSize: 13)),
        ),
      ];
    }
    if (available.isEmpty) return [];
    return available.take(3).map((d) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(_label(d), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ),
              const SizedBox(width: 6),
              _AddButton(
                label: 'Add + Apply',
                color: Colors.green,
                onTap: () => _attach(d['id'] as int, autoApply: true),
              ),
              const SizedBox(width: 6),
              _AddButton(
                label: 'Add',
                color: Colors.deepPurple,
                onTap: () => _attach(d['id'] as int, autoApply: false),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AddButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.2),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Customer Discounts Section
// ═══════════════════════════════════════════

// ═══════════════════════════════════════════
// Ticket Price Breakdown (fetches discount info per tier)
// ═══════════════════════════════════════════

class _TicketPriceBreakdown extends StatefulWidget {
  final int eventId;
  final int tierId;
  final int basePriceCents;

  const _TicketPriceBreakdown({
    required this.eventId,
    required this.tierId,
    required this.basePriceCents,
  });

  @override
  State<_TicketPriceBreakdown> createState() => _TicketPriceBreakdownState();
}

class _TicketPriceBreakdownState extends State<_TicketPriceBreakdown> {
  Map<String, dynamic>? _preview;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    try {
      final api = context.read<ApiService>();
      final resp = await api.dio.get(
        '/events/${widget.eventId}/ticket-price',
        queryParameters: {'ticket_tier_id': widget.tierId},
      );
      if (mounted) {
        setState(() {
          _preview = resp.data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  String _cents(int c) => '\$${(c / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(left: 28, top: 6),
        child: SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_error != null || _preview == null) return const SizedBox.shrink();

    final totalDiscount = _preview!['total_discount_cents'] ?? 0;
    if (totalDiscount == 0) return const SizedBox.shrink();

    final tierPrice = _preview!['tier_price_cents'] ?? 0;
    final commonDisc = _preview!['common_discount_cents'] ?? 0;
    final selectiveDisc = _preview!['selective_discount_cents'] ?? 0;
    final pledgeDisc = _preview!['pledge_discount_cents'] ?? 0;
    final eventDisc = _preview!['event_discount_cents'] ?? 0;
    final finalPrice = _preview!['final_price_cents'] ?? 0;

    return Padding(
      padding: const EdgeInsets.only(left: 28, top: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.teal.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Price Breakdown',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.teal.shade800)),
            const SizedBox(height: 6),
            _breakdownRow('Base price', _cents(tierPrice), isBold: false),
            if (commonDisc > 0)
              _breakdownRow('Common discount', '- ${_cents(commonDisc)}', color: Colors.green.shade700),
            if (selectiveDisc > 0)
              _breakdownRow('Selective discount', '- ${_cents(selectiveDisc)}', color: Colors.green.shade700),
            if (pledgeDisc > 0)
              _breakdownRow('Pledge discount', '- ${_cents(pledgeDisc)}', color: Colors.green.shade700),
            if (eventDisc > 0)
              _breakdownRow('Event discount', '- ${_cents(eventDisc)}', color: Colors.green.shade700),
            const Divider(height: 10),
            _breakdownRow(
              'You pay',
              finalPrice == 0 ? 'FREE' : _cents(finalPrice),
              isBold: true,
              color: finalPrice == 0 ? Colors.green.shade700 : Colors.teal.shade900,
            ),
          ],
        ),
      ),
    );
  }

  Widget _breakdownRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.w700 : FontWeight.w400, color: color ?? Colors.grey.shade700)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500, color: color ?? Colors.grey.shade700)),
        ],
      ),
    );
  }
}


class _CustomerDiscountsSection extends StatefulWidget {
  final int eventId;
  const _CustomerDiscountsSection({required this.eventId});

  @override
  State<_CustomerDiscountsSection> createState() => _CustomerDiscountsSectionState();
}

class _CustomerDiscountsSectionState extends State<_CustomerDiscountsSection> {
  List<Map<String, dynamic>> _discounts = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ApiService().getMyDiscounts(widget.eventId);
      if (mounted) {
        setState(() {
          _discounts = list.cast<Map<String, dynamic>>();
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  String _describe(Map<String, dynamic> d) {
    final type = d['discount_type'] ?? '';
    final val = d['value'] ?? 0;
    switch (type) {
      case 'ticket_percent':
        return '$val% off ticket price';
      case 'pledge_percent':
        final pledged = d['total_pledged_cents'] ?? 0;
        final amount = pledged * val ~/ 100;
        return '\$${(amount / 100).toStringAsFixed(2)} (${val}% of your pledge)';
      case 'fixed_cents':
        return '\$${(val / 100).toStringAsFixed(2)} flat discount';
      default:
        return '$val';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            Icon(Icons.local_offer_rounded, size: 20, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Your Discounts',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            TextButton.icon(
              onPressed: () => context.push('/events/${widget.eventId}/discounts'),
              icon: const Icon(Icons.search, size: 16),
              label: const Text('Browse', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_discounts.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No discounts applied yet. Tap Browse to see available discounts you can claim.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          )
        else
          ..._discounts.map((d) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.discount_rounded, size: 16, color: Colors.deepPurple),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d['name'] ?? 'Discount',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimaryOf(context))),
                          Text(_describe(d),
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ═══════════════════════════════════════════
// Self-contained Reaction Bar (like / dislike)
// Only refreshes itself, not the whole page
// ═══════════════════════════════════════════

class _ReactionBar extends StatefulWidget {
  final int eventId;
  final int initialLikeCount;
  final int initialDislikeCount;
  final bool isAdmin;

  const _ReactionBar({
    required this.eventId,
    required this.initialLikeCount,
    required this.initialDislikeCount,
    required this.isAdmin,
  });

  @override
  State<_ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends State<_ReactionBar> {
  String? _myReaction;
  bool _reacting = false;
  late int _likeCount;
  late int _dislikeCount;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.initialLikeCount;
    _dislikeCount = widget.initialDislikeCount;
    _loadMyReaction();
  }

  Future<void> _loadMyReaction() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    try {
      final api = context.read<ApiService>();
      final data = await api.getMyReaction(widget.eventId);
      if (mounted) setState(() => _myReaction = data['reaction']);
    } catch (_) {}
  }

  Future<void> _react(String reaction) async {
    if (_reacting) return;
    setState(() => _reacting = true);
    try {
      final api = context.read<ApiService>();
      final resp = await api.reactToEvent(widget.eventId, reaction);
      if (mounted) {
        setState(() {
          // Update reaction state based on action
          final action = resp['action'];
          if (action == 'removed') {
            _myReaction = null;
          } else {
            _myReaction = reaction;
          }
          // Update counts from server response
          _likeCount = resp['like_count'] ?? _likeCount;
          _dislikeCount = resp['dislike_count'] ?? _dislikeCount;
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Reaction failed');
      }
    }
    if (mounted) setState(() => _reacting = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isAdmin) {
      // Admin: read-only counters (both like + dislike visible)
      return Row(
        children: [
          Icon(Icons.thumb_up, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 6),
          Text(
            '$_likeCount like${_likeCount == 1 ? '' : 's'}',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
          ),
          const SizedBox(width: 20),
          Icon(Icons.thumb_down, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Text(
            '$_dislikeCount dislike${_dislikeCount == 1 ? '' : 's'}',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[500]),
          ),
        ],
      );
    }

    // Everyone else: interactive like/dislike buttons
    return Row(
      children: [
        // Like button
        Material(
          color: _myReaction == 'like'
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _reacting ? null : () => _react('like'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _myReaction == 'like' ? Icons.thumb_up : Icons.thumb_up_outlined,
                    size: 20,
                    color: _myReaction == 'like' ? AppTheme.primaryColor : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$_likeCount',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: _myReaction == 'like' ? AppTheme.primaryColor : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Dislike button
        Material(
          color: _myReaction == 'dislike'
              ? AppTheme.errorColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _reacting ? null : () => _react('dislike'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _myReaction == 'dislike' ? Icons.thumb_down : Icons.thumb_down_outlined,
                    size: 20,
                    color: _myReaction == 'dislike' ? AppTheme.errorColor : Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════
// Self-contained Funding Card
// Loads its own data, pledge/unpledge only refresh this card
// ═══════════════════════════════════════════

class _FundingCard extends StatefulWidget {
  final int eventId;
  final Event event;
  final bool isRegistered;

  const _FundingCard({required this.eventId, required this.event, required this.isRegistered});

  @override
  State<_FundingCard> createState() => _FundingCardState();
}

class _FundingCardState extends State<_FundingCard> {
  int _totalPledgedCents = 0;
  int _backersCount = 0;
  int? _goalCents;
  bool _goalMet = false;
  bool _loading = true;
  bool _pledging = false;
  int _fundingCommissionPercent = 0;
  int _totalReservedSpots = 0;

  Event get event => widget.event;

  @override
  void initState() {
    super.initState();
    // Seed from event data while we load fresh numbers
    _totalPledgedCents = event.totalPledgedCents ?? 0;
    _goalCents = event.fundingGoalCents;
    _totalReservedSpots = event.totalReservedSpots;
    _loadFunding();
  }

  Future<void> _loadFunding() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getFundingSummary(widget.eventId);
      if (mounted) {
        setState(() {
          _totalPledgedCents = data['total_pledged_cents'] ?? 0;
          _backersCount = data['backers_count'] ?? 0;
          _goalCents = data['goal_cents'];
          _goalMet = data['goal_met'] ?? false;
          _fundingCommissionPercent = data['funding_commission_percent'] ?? 0;
          _totalReservedSpots = data['total_reserved_spots'] ?? 0;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Trust score helpers ──
  static Color _trustColor(String label) {
    switch (label) {
      case 'Excellent': return const Color(0xFF05944F); // green
      case 'Good':      return const Color(0xFF0077B6); // blue
      case 'Fair':      return Colors.orange;
      case 'Low':       return Colors.red;
      default:          return Colors.grey;               // New
    }
  }

  static IconData _trustIcon(String label) {
    switch (label) {
      case 'Excellent': return Icons.verified_rounded;
      case 'Good':      return Icons.verified_outlined;
      case 'Fair':      return Icons.shield_outlined;
      case 'Low':       return Icons.warning_amber_rounded;
      default:          return Icons.person_outline;       // New
    }
  }

  double get _progress {
    if (_goalCents == null || _goalCents == 0) return 0;
    return _totalPledgedCents / _goalCents!;
  }

  String get _totalFormatted =>
      '\$${(_totalPledgedCents / 100).toStringAsFixed(2)}';

  String get _goalFormatted {
    if (_goalCents == null) return 'N/A';
    return '\$${(_goalCents! / 100).toStringAsFixed(2)}';
  }

  // ── Step 1: Pledge dialog (amount + spot selector) ──
  Future<void> _showPledgeDialog() async {
    final amountController = TextEditingController();
    int selectedSpots = 0;
    final maxPerUser = event.maxReservedSpotsPerUser;
    final minPledgeDollars = (event.minPledgeCents / 100).toStringAsFixed(2);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final minRequired = selectedSpots * event.minPledgeCents;
          final minRequiredDollars = (minRequired / 100).toStringAsFixed(2);
          return AlertDialog(
            title: const Text('Make a Pledge'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.isRegistered)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 18, color: AppTheme.warningColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You are not registered. Your pledge will be a guest pledge (non-refundable) and you cannot reserve spots.',
                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Amount (\$)',
                      prefixText: '\$ ',
                      helperText: selectedSpots > 0
                          ? 'Min \$$minRequiredDollars for $selectedSpots spot(s)'
                          : 'Min pledge: \$$minPledgeDollars',
                    ),
                  ),
                  if (maxPerUser > 0 && widget.isRegistered) ...[
                    const SizedBox(height: 16),
                    Text('Reserve Ticket Spots',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.grey[800])),
                    const SizedBox(height: 4),
                    Text(
                      'Each spot costs min \$$minPledgeDollars. Up to $maxPerUser per user.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          onPressed: selectedSpots > 0
                              ? () => setDialogState(() => selectedSpots--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                          iconSize: 28,
                        ),
                        Text('$selectedSpots',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          onPressed: selectedSpots < maxPerUser
                              ? () => setDialogState(() => selectedSpots++)
                              : null,
                          icon: const Icon(Icons.add_circle_outline),
                          iconSize: 28,
                        ),
                        const SizedBox(width: 8),
                        Text('spot(s)',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600])),
                      ],
                    ),
                    if (_totalReservedSpots > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '$_totalReservedSpots spot(s) already reserved for this event',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(amountController.text);
                  if (amount == null || amount <= 0) return;
                  Navigator.pop(ctx);
                  _showPledgeInvoice((amount * 100).toInt(), selectedSpots);
                },
                child: const Text('Continue to Invoice'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Step 2: Pledge invoice ──
  Future<void> _showPledgeInvoice(int amountCents, int reservedSpots) async {
    Map<String, dynamic>? preview;
    bool loadingPreview = true;
    String? previewError;

    try {
      final api = context.read<ApiService>();
      preview = await api.getPledgePreview(widget.eventId, amountCents, reservedSpots);
      loadingPreview = false;
    } catch (e) {
      loadingPreview = false;
      previewError = ApiService.extractError(e);
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final amountDollars = (amountCents / 100).toStringAsFixed(2);
        final platformCut = preview?['platform_cut_cents'] ?? 0;
        final netToOrganizer = preview?['net_to_organizer_cents'] ?? 0;
        final commissionPct = preview?['funding_commission_percent'] ?? 0;

        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.receipt_long, size: 22, color: Colors.deepPurple),
              const SizedBox(width: 8),
              const Text('Pledge Invoice'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (previewError != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(previewError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  )
                else if (loadingPreview)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  _invoiceRow('Pledge Amount', '\$$amountDollars'),
                  if (reservedSpots > 0)
                    _invoiceRow('Reserved Spots', '$reservedSpots spot(s)'),
                  const Divider(height: 20),
                  _invoiceRow(
                    'Platform Fee ($commissionPct%)',
                    '\$${(platformCut / 100).toStringAsFixed(2)}',
                    subtle: true,
                  ),
                  _invoiceRow(
                    'Net to Organizer',
                    '\$${(netToOrganizer / 100).toStringAsFixed(2)}',
                  ),
                  if (reservedSpots > 0) ...[
                    const Divider(height: 20),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_seat, size: 16, color: Colors.teal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$reservedSpots spot(s) will be reserved for your future ticket purchase.',
                              style: const TextStyle(fontSize: 12, color: Colors.teal),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx, false);
                _showPledgeDialog(); // go back to step 1
              },
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: previewError != null
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('Confirm Pledge'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _executePledge(amountCents, reservedSpots);
    }
  }

  Widget _invoiceRow(String label, String value, {bool subtle = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: subtle ? Colors.grey[500] : Colors.grey[800])),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: subtle ? FontWeight.normal : FontWeight.w600,
                  color: subtle ? Colors.grey[500] : null)),
        ],
      ),
    );
  }

  // ── Step 3: Execute pledge and show receipt ──
  Future<void> _executePledge(int amountCents, int reservedSpots) async {
    setState(() => _pledging = true);
    try {
      final api = context.read<ApiService>();
      final result = await api.pledge(widget.eventId, amountCents,
          reservedSpots: reservedSpots);
      if (mounted) {
        final isGuest = result['is_guest'] == true;
        final pledgeId = result['id'] as int;
        AppToast.success(context, isGuest
            ? 'Guest pledge (non-refundable)'
            : 'Pledge confirmed!');
        _loadFunding();
        // Navigate to receipt
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PledgeReceiptScreen(
            eventId: widget.eventId,
            pledgeId: pledgeId,
          ),
        ));
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Pledge failed');
      }
    } finally {
      if (mounted) setState(() => _pledging = false);
    }
  }

  // ── Unpledge ──
  Future<void> _unpledge() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unpledge'),
        content: const Text(
            'Your refundable pledges will be returned. Guest pledges (made before registering) are non-refundable.\n\nContinue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unpledge'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final api = context.read<ApiService>();
        final result = await api.unpledge(widget.eventId);
        if (context.mounted) {
          final refunded = result['refunded_cents'] ?? 0;
          final guest = result['guest_non_refundable_cents'] ?? 0;
          var msg = 'Refunded \$${(refunded / 100).toStringAsFixed(2)}';
          if (guest > 0) {
            msg +=
                ' (\$${(guest / 100).toStringAsFixed(2)} guest pledges non-refundable)';
          }
          AppToast.success(context, msg);
          // Refresh only this card
          _loadFunding();
        }
      } catch (e) {
        if (context.mounted) {
          AppToast.fromError(context, e, fallback: 'Unpledge failed');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fundingTimeLeft = event.fundingTimeLeftFormatted;
    final hasTimeLeft = event.fundingHasTimeLeft;
    final user = context.watch<AuthProvider>().user;
    final isOrganizerOrAdmin = user != null && (user.isOrganizer || user.isAdmin);
    final canPledge = event.canPledge && !isOrganizerOrAdmin;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              const Icon(Icons.attach_money, size: 20, color: AppTheme.accentColor),
              const SizedBox(width: 8),
              const Text('Funding',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3)),
              const Spacer(),
              if (event.fundingEndAt != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasTimeLeft
                        ? AppTheme.accentColor.withValues(alpha: 0.12)
                        : AppTheme.textSecondaryOf(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    fundingTimeLeft,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: hasTimeLeft
                          ? AppTheme.accentColor
                          : AppTheme.textSecondaryOf(context),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Raised / Goal
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _totalFormatted,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: _progress >= 1.0
                      ? AppTheme.successColor
                      : AppTheme.textPrimaryOf(context),
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'of $_goalFormatted',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryOf(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${(_progress * 100).clamp(0, 999).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _progress >= 1.0
                        ? AppTheme.successColor
                        : AppTheme.accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _progress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: AppTheme.dividerOf(context),
              valueColor: AlwaysStoppedAnimation(
                _progress >= 1.0
                    ? AppTheme.successColor
                    : AppTheme.accentColor,
              ),
            ),
          ),
          if (_fundingCommissionPercent > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Platform fee: $_fundingCommissionPercent% of pledges',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ),
          const SizedBox(height: 12),

          // Deadline + Min pledge row
          Row(
            children: [
              if (event.fundingEndAt != null) ...[
                Icon(Icons.timer_outlined,
                    size: 14, color: AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 4),
                Text(
                  'Deadline: ${DateFormat('MMM d, y – h:mm a').format(event.fundingEndAt!.toLocal())}',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context),
                      fontWeight: FontWeight.w500),
                ),
              ],
              const Spacer(),
              if (event.minPledgeCents > 0) ...[
                Icon(Icons.arrow_downward,
                    size: 14, color: AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 4),
                Text(
                  'Min: \$${(event.minPledgeCents / 100).toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context),
                      fontWeight: FontWeight.w500),
                ),
              ],
            ],
          ),

          // Backers count + reserved spots
          if (_backersCount > 0 || _totalReservedSpots > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (_backersCount > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        '$_backersCount backer${_backersCount == 1 ? '' : 's'}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                if (_totalReservedSpots > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_seat, size: 14, color: Colors.teal),
                      const SizedBox(width: 4),
                      Text(
                        '$_totalReservedSpots spot${_totalReservedSpots == 1 ? '' : 's'} reserved',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.teal,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
              ],
            ),
          ],

          // Escrow + Organizer Trust indicator
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Escrow line
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 14, color: Colors.blue.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Pledges held in platform escrow until event milestones are met',
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Trust score line
                  Row(
                    children: [
                      Icon(
                        _trustIcon(event.organizerTrustLabel),
                        size: 14,
                        color: _trustColor(event.organizerTrustLabel),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Organizer Trust: ',
                        style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _trustColor(event.organizerTrustLabel).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${event.organizerTrustLabel} (${(event.organizerTrustScore * 100).toInt()}%)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _trustColor(event.organizerTrustLabel),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${event.organizerCompletedEvents}/${event.organizerPublishedEvents} events',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Pledge / Unpledge buttons
          if (canPledge) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: _pledging ? null : _showPledgeDialog,
                      icon: const Icon(Icons.volunteer_activism, size: 18),
                      label: const Text('Pledge',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: _pledging ? null : _unpledge,
                      icon: const Icon(Icons.money_off,
                          size: 18, color: AppTheme.warningColor),
                      label: const Text('Unpledge',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.warningColor)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.warningColor),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Self-contained Event Feed
// Loads its own posts, submit/delete only refresh this widget
// ═══════════════════════════════════════════

class _EventFeed extends StatefulWidget {
  final int eventId;
  final bool postsEnabled;
  final bool isRegistered;

  const _EventFeed({required this.eventId, required this.postsEnabled, required this.isRegistered});

  @override
  State<_EventFeed> createState() => _EventFeedState();
}

class _EventFeedState extends State<_EventFeed> {
  List<EventPost> _posts = [];
  bool _loading = true;
  bool _posting = false;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final data = await api.getEventPosts(widget.eventId);
      if (mounted) {
        setState(() {
          _posts = data.map((p) => EventPost.fromJson(p)).toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submitPost() async {
    if (_ctrl.text.trim().isEmpty) return;
    if (!widget.isRegistered) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Registration Required'),
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: AppTheme.warningColor),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Please register for this event before posting in the feed.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => _posting = true);
    try {
      final api = context.read<ApiService>();
      await api.createEventPost(widget.eventId, _ctrl.text.trim());
      _ctrl.clear();
      await _loadPosts();
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        if (msg.contains('403') || msg.toLowerCase().contains('forbidden') || msg.toLowerCase().contains('registered')) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Registration Required'),
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.warningColor),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Please register for this event before posting in the feed.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          AppToast.fromError(context, e, fallback: 'Failed to post');
        }
      }
    }
    if (mounted) setState(() => _posting = false);
  }

  Future<void> _deletePost(int postId) async {
    try {
      final api = context.read<ApiService>();
      await api.deleteEventPost(widget.eventId, postId);
      await _loadPosts();
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to delete post');
      }
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'now';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with title + refresh button
        Row(
          children: [
            Icon(Icons.forum_rounded,
                size: 18, color: AppTheme.textPrimaryOf(context)),
            const SizedBox(width: 8),
            const Text(
              'Event Feed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 8),
            if (!widget.postsEnabled)
              Chip(
                label:
                    const Text('Disabled', style: TextStyle(fontSize: 11)),
                backgroundColor: AppTheme.dividerOf(context),
                side: BorderSide.none,
              ),
            const Spacer(),
            // Refresh button
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _loading ? null : _loadPosts,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.refresh_rounded,
                          size: 20, color: AppTheme.textSecondaryOf(context)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Post input
        if (widget.postsEnabled && user != null) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  decoration: InputDecoration(
                    hintText: 'Write something...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  maxLines: 2,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _posting ? null : _submitPost,
                icon: _posting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Content
        if (!widget.postsEnabled)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Posts are disabled for this event.',
                  style: TextStyle(color: Colors.grey[500])),
            ),
          )
        else if (_loading && _posts.isEmpty)
          const Center(
              child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(strokeWidth: 2),
          ))
        else if (_posts.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No posts yet. Be the first to share!',
                  style: TextStyle(color: Colors.grey[500])),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _posts.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final post = _posts[i];
              final isAuthor = user != null && user.id == post.userId;
              final isAdmin = user != null && user.isAdmin;
              final isOrg = user != null && user.isOrganizer;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      AppTheme.primaryColor.withValues(alpha: 0.15),
                  child: Text(
                    (post.authorName ?? 'U')[0].toUpperCase(),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor),
                  ),
                ),
                title: Text(
                  post.authorName ?? 'User',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(post.content),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _timeAgo(post.createdAt),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500]),
                    ),
                    if (isAuthor || isAdmin || isOrg) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 18),
                        onPressed: () => _deletePost(post.id),
                        tooltip: 'Delete post',
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
