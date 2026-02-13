import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/event.dart';
import '../../models/post.dart';
import '../../models/event_image.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../widgets/event_lifecycle_bar.dart';
import '../../services/api_service.dart';

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

  // Reaction state lives in _ReactionBar widget (self-contained)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().loadEvent(widget.eventId);
      _loadImages();
      _checkRegistration();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle posts: $e')),
        );
      }
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
              color: Colors.grey[100],
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
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.8,
                                  height: 1.15,
                                  color: AppTheme.textPrimary,
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
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppTheme.dividerColor),
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
                                        style: const TextStyle(
                                          fontSize: 15,
                                          height: 1.5,
                                          color: AppTheme.textPrimary,
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
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.dividerColor),
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
                                    _modernInfoRow(Icons.people_alt_rounded, 'Capacity', '${event.maxCapacity}'),
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
                                              '${event.pendingCancellation!['pledge_percent'] ?? '?'}% funded — admin must approve cancellation',
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

                              // Buy tickets (shown for everyone when selling)
                              if (user != null &&
                                  user.isCustomer &&
                                  (event.status == EventStatus.selling_tickets ||
                                      event.status == EventStatus.live)) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showBuyTicketDialog(event),
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
                                    // Edit event
                                    if (event.status == EventStatus.draft ||
                                        event.status == EventStatus.pending_approval ||
                                        event.status == EventStatus.approved ||
                                        event.status == EventStatus.live)
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            context.push('/events/${event.id}/edit'),
                                        icon: const Icon(Icons.edit, size: 18),
                                        label: Text(
                                          event.status == EventStatus.draft ||
                                                  event.status ==
                                                      EventStatus.pending_approval
                                              ? 'Edit'
                                              : 'Edit (needs approval)',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppTheme.secondaryColor,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),

                                    // Draft → Publish
                                    if (event.status == EventStatus.draft)
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          await eventProvider
                                              .publishEvent(event.id);
                                        },
                                        icon: const Icon(Icons.publish,
                                            size: 18),
                                        label: const Text('Publish'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppTheme.primaryColor,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),

                                    // Cancelled → Move to Draft
                                    if (event.status ==
                                        EventStatus.cancelled)
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          await eventProvider
                                              .reactivateEvent(event.id);
                                        },
                                        icon: const Icon(Icons.restore,
                                            size: 18),
                                        label:
                                            const Text('Move to Draft'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppTheme.warningColor,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),

                                    // Set Event Date (waiting_event_date → set dates)
                                    if (event.status == EventStatus.waiting_event_date)
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            _showSetEventDateDialog(context, event),
                                        icon: const Icon(Icons.calendar_month, size: 18),
                                        label: const Text('Set Event Date'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),

                                    // Start Selling Tickets (waiting_event_date, dates + strategy set)
                                    if (event.status == EventStatus.waiting_event_date &&
                                        event.startTime != null &&
                                        event.ticketStrategyId != null)
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          final ok = await eventProvider.startSellingTickets(event.id);
                                          if (ok && mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Tickets are now on sale!')),
                                            );
                                          } else if (!ok && mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(eventProvider.error ?? 'Failed to start selling tickets')),
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.storefront_rounded, size: 18),
                                        label: const Text('Start Selling Tickets'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),

                                    // Extend Funding (waiting_event_date)
                                    if (event.status == EventStatus.waiting_event_date)
                                      OutlinedButton.icon(
                                        onPressed: () => _showExtendFundingDialog(context, event),
                                        icon: const Icon(Icons.more_time_rounded, size: 18),
                                        label: const Text('Extend Funding'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.accentColor,
                                        ),
                                      ),

                                    // Clone (completed events only)
                                    if (event.status == EventStatus.completed)
                                      ElevatedButton.icon(
                                        onPressed: () => _cloneEvent(context, event.id),
                                        icon: const Icon(Icons.copy_all, size: 18),
                                        label: const Text('Clone Event'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primaryColor,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),

                                    // Cancel (published, unpublished, selling_tickets, waiting, or live events)
                                    if (event.status ==
                                            EventStatus.pending_approval ||
                                        event.status ==
                                            EventStatus.approved ||
                                        event.status == EventStatus.selling_tickets ||
                                        event.status == EventStatus.waiting_event_date ||
                                        event.status ==
                                            EventStatus.live)
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _confirmCancel(
                                                context,
                                                eventProvider,
                                                event.id),
                                        icon: const Icon(Icons.cancel,
                                            size: 18,
                                            color: AppTheme.errorColor),
                                        label: const Text(
                                            'Cancel Event',
                                            style: TextStyle(
                                                color:
                                                    AppTheme.errorColor)),
                                      ),

                                    // Delete permanently (draft or cancelled only)
                                    if (event.status ==
                                            EventStatus.draft ||
                                        event.status ==
                                            EventStatus.cancelled)
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _confirmDelete(
                                                context, eventProvider,
                                                event.id),
                                        icon: const Icon(
                                            Icons.delete_forever,
                                            size: 18,
                                            color: AppTheme.errorColor),
                                        label: const Text(
                                            'Delete Permanently',
                                            style: TextStyle(
                                                color:
                                                    AppTheme.errorColor)),
                                      ),

                                    // Toggle posts
                                    OutlinedButton.icon(
                                      onPressed: _togglePosts,
                                      icon: Icon(
                                        event.postsEnabled
                                            ? Icons.comments_disabled
                                            : Icons.comment,
                                        size: 18,
                                      ),
                                      label: Text(event.postsEnabled
                                          ? 'Disable Posts'
                                          : 'Enable Posts'),
                                    ),
                                  ],
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
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

  Widget _modernInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.grey[100],
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
                        color: valueColor ?? AppTheme.textPrimary)),
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
        return AppTheme.primaryColor;
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
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
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
                      label: _regStatus == 'waitlisted' ? 'Waitlisted' : 'Register',
                      color: _regStatus == 'waitlisted' ? AppTheme.warningColor : AppTheme.primaryColor,
                      filled: _regStatus != 'waitlisted',
                      onTap: _regLoading ? null : () => _register(context),
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
              color: Colors.grey[700]!,
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
              color: Colors.grey[700]!,
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
            final quantity = t['quantity'] ?? 0;
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
                        if (quantity > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text('$quantity left',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No ticket tiers available for this event')),
          );
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
                    child: ListTile(
                      leading: const Icon(Icons.confirmation_number, color: Colors.teal),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                            Text('\$$basePrice'),
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
                      trailing: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await _purchaseTicket(event.id, tierId);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFree ? Colors.green : Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(isFree ? 'Get Ticket' : 'Buy \$$finalPrice'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load tiers: $e')),
        );
      }
    }
  }

  Future<void> _purchaseTicket(int eventId, int tierId) async {
    try {
      final api = context.read<ApiService>();
      final resp = await api.dio.post('/events/$eventId/purchase-ticket', data: {'tier_id': tierId});
      final ticketCode = resp.data['ticket_code'] ?? '';
      final amountPaid = resp.data['amount_paid_cents'] ?? 0;
      final commission = resp.data['commission_cents'] ?? 0;
      final status = resp.data['status'] ?? 'purchased';
      final isFree = amountPaid == 0;
      if (mounted) {
        if (status == 'waitlisted') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Event/tier is at capacity — you have been added to the ticket waitlist.'),
              duration: Duration(seconds: 4),
            ),
          );
        } else {
          final priceStr = isFree
              ? 'Free ticket'
              : 'Paid \$${(amountPaid / 100).toStringAsFixed(2)}'
                '${commission > 0 ? ' (incl. \$${(commission / 100).toStringAsFixed(2)} platform fee)' : ''}';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$priceStr — Code: $ticketCode')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $e')),
        );
      }
    }
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
        return 'UNPUBLISHED';
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
        return Colors.grey.shade200;
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
        return AppTheme.primaryColor.withValues(alpha: 0.2);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event cloned as draft! Redirecting to edit...')),
      );
      context.push('/events/$newId/edit');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Clone failed: $e')),
      );
    }
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
      await api.register(widget.eventId);
      await _checkRegistration();
      if (context.mounted) {
        context.read<EventProvider>().loadEvent(widget.eventId);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unregister failed: $e')),
        );
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
      await eventProvider.cancelEvent(eventId,
          reason: reasonCtrl.text.trim());
    }
  }

  // _unpledge moved into _FundingCard widget

  Future<void> _shareEvent(BuildContext context, Event event) async {
    final uri = Uri.base.resolve('/events/${event.id}');
    final shareText = '${event.title}\n$uri';

    await Clipboard.setData(ClipboardData(text: shareText));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event link copied to clipboard!'),
          duration: Duration(seconds: 2),
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Calendar link copied! Paste in browser to download .ics file.'),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
          duration: const Duration(seconds: 4),
        ),
      );
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
        _LiveMgmtStats(eventId: event.id),
        const SizedBox(height: 12),
        // Co-organizers button
        _mgmtActionCard(
          icon: Icons.group_rounded,
          label: 'Co-Organizers',
          color: AppTheme.accentColor,
          onTap: () => context.push('/events/${event.id}/co-organizers'),
        ),
        const SizedBox(height: 12),
        // Ticket waitlist button
        _mgmtActionCard(
          icon: Icons.confirmation_number_rounded,
          label: 'Ticket Waitlist',
          color: Colors.orange,
          onTap: () => context.push('/events/${event.id}/ticket-waitlist'),
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
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          if (ext['funding_goal_cents'] != null)
            Text('New funding goal: \$${(ext['funding_goal_cents'] / 100).toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Extension ${action}d')),
        );
        context.read<EventProvider>().loadEvent(eventId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Extension request submitted for admin approval')),
        );
        context.read<EventProvider>().loadEvent(event.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event date set!')),
        );
        context.read<EventProvider>().loadEvent(event.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
                final quantity = tier['quantity'] ?? 0;
                final price =
                    '\$${(priceCents / 100).toStringAsFixed(2)}';
                final qtyLabel = quantity > 0 ? '$quantity tickets' : 'Unlimited';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                            Row(
                              children: [
                                Text(price,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.successColor)),
                                const SizedBox(width: 8),
                                Text('· $qtyLabel',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500])),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Edit tier',
                        onPressed: () => _showEditTierDialog(
                            event.id, tierId, name, desc, priceCents, quantity),
                      ),
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
      String description, int priceCents, [int quantity = 0]) async {
    final nameCtrl = TextEditingController(text: name);
    final descCtrl = TextEditingController(text: description);
    final priceCtrl = TextEditingController(
        text: (priceCents / 100).toStringAsFixed(2));
    final quantityCtrl = TextEditingController(text: quantity.toString());

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
            const SizedBox(height: 8),
            TextField(
              controller: quantityCtrl,
              decoration: const InputDecoration(
                labelText: 'Quantity (0 = unlimited)',
                hintText: '0',
              ),
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
                  'quantity': int.tryParse(quantityCtrl.text) ?? 0,
                });
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tier updated!')),
      );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tier deleted.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e')),
          );
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
  final int eventId;
  const _LiveMgmtStats({required this.eventId});

  @override
  State<_LiveMgmtStats> createState() => _LiveMgmtStatsState();
}

class _LiveMgmtStatsState extends State<_LiveMgmtStats> {
  int _soldCount = 0;
  int _scannedCount = 0;
  int _waitlistCount = 0;
  int _revenueCents = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([
        api.getTicketSales(widget.eventId),
        api.getScannedTickets(widget.eventId),
        api.getRegistrations(widget.eventId),
      ]);
      final allSales = results[0];
      final scanned = results[1];
      final regs = results[2];
      final revenue = allSales.fold<int>(
          0, (s, e) => s + ((e['amount_paid_cents'] ?? 0) as int));
      final waitlisted =
          regs.where((r) => r['status'] == 'waitlist').length;
      if (mounted) {
        setState(() {
          _soldCount = allSales.length;
          _scannedCount = scanned.length;
          _waitlistCount = waitlisted;
          _revenueCents = revenue;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Column(
      children: [
        // Row 1: sold, scanned
        Row(
          children: [
            Expanded(
              child: _tapChip(
                icon: Icons.confirmation_number_rounded,
                label: '$_soldCount sold',
                color: AppTheme.primaryColor,
                onTap: () =>
                    context.push('/events/${widget.eventId}/ticket-sales'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _tapChip(
                icon: Icons.qr_code_scanner_rounded,
                label: '$_scannedCount scanned',
                color: AppTheme.successColor,
                onTap: () =>
                    context.push('/events/${widget.eventId}/scanned-tickets'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Row 2: waitlist, revenue
        Row(
          children: [
            Expanded(
              child: _tapChip(
                icon: Icons.hourglass_top_rounded,
                label: '$_waitlistCount waitlisted',
                color: AppTheme.warningColor,
                onTap: () =>
                    context.push('/events/${widget.eventId}/waitlist'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _tapChip(
                icon: Icons.attach_money_rounded,
                label: '\$${(_revenueCents / 100).toStringAsFixed(0)}',
                color: Colors.teal,
                onTap: () =>
                    context.push('/events/${widget.eventId}/ticket-sales'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _tapChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to attach: $e')),
        );
      }
    }
  }

  Future<void> _detach(int id) async {
    try {
      await _api.detachDiscountStrategy(widget.eventId, id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to detach: $e')),
        );
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
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.white38),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No discounts applied yet. Tap Browse to see available discounts you can claim.',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
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
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          Text(_describe(d),
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
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

  Event get event => widget.event;

  @override
  void initState() {
    super.initState();
    // Seed from event data while we load fresh numbers
    _totalPledgedCents = event.totalPledgedCents ?? 0;
    _goalCents = event.fundingGoalCents;
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
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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

  // ── Pledge dialog ──
  Future<void> _showPledgeDialog() async {
    final amountController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Make a Pledge'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
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
                      'If you are not registered for this event, your pledge is treated as a guest pledge and is non-refundable.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount (\$)',
                prefixText: '\$ ',
                helperText:
                    'Min pledge: \$${(event.minPledgeCents / 100).toStringAsFixed(2)}',
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
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) return;
              try {
                final api = context.read<ApiService>();
                final result =
                    await api.pledge(widget.eventId, (amount * 100).toInt());
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  final isGuest = result['is_guest'] == true;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isGuest
                          ? 'Guest pledge of \$${amount.toStringAsFixed(2)} (non-refundable)'
                          : 'Pledged \$${amount.toStringAsFixed(2)}!'),
                    ),
                  );
                  // Refresh only this card
                  _loadFunding();
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
          // Refresh only this card
          _loadFunding();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unpledge failed: $e')),
          );
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
        color: Colors.white,
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
                        : AppTheme.textSecondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    fundingTimeLeft,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: hasTimeLeft
                          ? AppTheme.accentColor
                          : AppTheme.textSecondary,
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
                      : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'of $_goalFormatted',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
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
              backgroundColor: AppTheme.dividerColor,
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
                const Icon(Icons.timer_outlined,
                    size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Deadline: ${DateFormat('MMM d, y – h:mm a').format(event.fundingEndAt!.toLocal())}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500),
                ),
              ],
              const Spacer(),
              if (event.minPledgeCents > 0) ...[
                const Icon(Icons.arrow_downward,
                    size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Min: \$${(event.minPledgeCents / 100).toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ],
          ),

          // Backers count
          if (_backersCount > 0) ...[
            const SizedBox(height: 8),
            Row(
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
          ],

          // Escrow trust indicator
          if (_totalPledgedCents > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to post: $e')),
          );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete post: $e')),
        );
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
            const Icon(Icons.forum_rounded,
                size: 18, color: AppTheme.textPrimary),
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
                backgroundColor: Colors.grey.shade200,
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
                          size: 20, color: Colors.grey[600]),
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
                  backgroundColor: AppTheme.primaryColor,
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
