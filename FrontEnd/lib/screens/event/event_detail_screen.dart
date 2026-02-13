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
  List<EventPost> _posts = [];
  List<EventImage> _images = [];
  bool _loadingPosts = false;
  bool _loadingImages = false;
  final _postCtrl = TextEditingController();
  bool _postingComment = false;

  // Registration state
  bool _isRegistered = false;
  String? _regStatus; // 'registered', 'waitlisted', 'cancelled'
  bool _regLoading = false;

  // Reaction state
  String? _myReaction; // 'like', 'dislike', or null
  bool _reacting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().loadEvent(widget.eventId);
      _loadPosts();
      _loadImages();
      _checkRegistration();
      _loadMyReaction();
    });
  }

  @override
  void dispose() {
    _postCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() => _loadingPosts = true);
    try {
      final api = context.read<ApiService>();
      final data = await api.getEventPosts(widget.eventId);
      setState(() {
        _posts = data.map((p) => EventPost.fromJson(p)).toList();
      });
    } catch (_) {}
    setState(() => _loadingPosts = false);
  }

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

  Future<void> _loadMyReaction() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    try {
      final api = context.read<ApiService>();
      final data = await api.getMyReaction(widget.eventId);
      setState(() => _myReaction = data['reaction']);
    } catch (_) {}
  }

  Future<void> _react(String reaction) async {
    if (_reacting) return;
    setState(() => _reacting = true);
    try {
      final api = context.read<ApiService>();
      await api.reactToEvent(widget.eventId, reaction);
      await _loadMyReaction();
      if (mounted) {
        context.read<EventProvider>().loadEvent(widget.eventId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
    setState(() => _reacting = false);
  }

  Future<void> _submitPost() async {
    if (_postCtrl.text.trim().isEmpty) return;
    setState(() => _postingComment = true);
    try {
      final api = context.read<ApiService>();
      await api.createEventPost(widget.eventId, _postCtrl.text.trim());
      _postCtrl.clear();
      await _loadPosts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post: $e')),
        );
      }
    }
    setState(() => _postingComment = false);
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
          icon: const Icon(Icons.close),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Text(event?.title ?? 'Event Details'),
        actions: [
          if (event != null) ...[
            IconButton(
              icon: const Icon(Icons.calendar_month),
              tooltip: 'Add to calendar',
              onPressed: () => _downloadCalendar(context, event),
            ),
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share event link',
              onPressed: () => _shareEvent(context, event),
            ),
          ],
        ],
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
                                      _statusLabel(event.status),
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    backgroundColor:
                                        _statusColor(event.status),
                                    side: BorderSide.none,
                                  ),
                                ],
                              ),

                              // Lifecycle progress bar
                              const SizedBox(height: 16),
                              EventLifecycleBar(event: event),
                              const SizedBox(height: 12),

                              // Genre badge
                              if (event.genre != null &&
                                  event.genre!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Chip(
                                  avatar: const Icon(Icons.category, size: 16),
                                  label: Text(
                                    event.genre![0].toUpperCase() +
                                        event.genre!.substring(1),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: AppTheme.secondaryColor
                                      .withValues(alpha: 0.15),
                                  side: BorderSide.none,
                                ),
                              ],

                              const SizedBox(height: 16),

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
                                      _infoRow(Icons.calendar_today, 'Event Start',
                                          event.startTime != null
                                              ? dateFormat.format(event.startTime!)
                                              : 'Not set yet'),
                                      const Divider(),
                                      _infoRow(Icons.calendar_today, 'Event End',
                                          event.endTime != null
                                              ? dateFormat.format(event.endTime!)
                                              : 'Not set yet'),
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
                                        const Divider(),
                                        _infoRow(
                                            Icons.trending_up,
                                            'Raised',
                                            event.totalPledgedFormatted),
                                        if (event.fundingDaysLeft != null) ...[
                                          const Divider(),
                                          _infoRow(
                                              Icons.timer_outlined,
                                              'Funding',
                                              event.fundingDaysLeft! > 0
                                                  ? '${event.fundingDaysLeft} days left'
                                                  : 'Ended'),
                                        ],
                                      ],
                                      if (event.fundingEndAt != null) ...[
                                        const Divider(),
                                        _infoRow(
                                            Icons.timer,
                                            'Funding Deadline',
                                            dateFormat.format(event.fundingEndAt!)),
                                      ],
                                      if (event.eventDateDeadline != null) ...[
                                        const Divider(),
                                        _infoRow(
                                            Icons.hourglass_bottom,
                                            'Set Date By',
                                            dateFormat.format(event.eventDateDeadline!)),
                                      ],
                                      if (event.refundDeadlineDays != null) ...[
                                        const Divider(),
                                        _infoRow(
                                            Icons.receipt_long,
                                            'Refund Policy',
                                            event.refundDeadlineDays! > 0
                                                ? 'Refund if cancelled ${event.refundDeadlineDays} day${event.refundDeadlineDays == 1 ? '' : 's'} before funding ends'
                                                : 'No refunds'),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Cancellation reason banner
                              if (event.status == EventStatus.cancelled &&
                                  event.cancellationReason != null &&
                                  event.cancellationReason!.isNotEmpty) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppTheme.errorColor
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: AppTheme.errorColor
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.info_outline,
                                          color: AppTheme.errorColor,
                                          size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Cancellation Reason',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.errorColor,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              event.cancellationReason!,
                                              style: TextStyle(
                                                  color: Colors.grey[800]),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Registration count
                              if (event.registrationCount > 0) ...[
                                Row(
                                  children: [
                                    Icon(Icons.group,
                                        size: 18,
                                        color: AppTheme.primaryColor),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${event.registrationCount} registered',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Like / Dislike buttons (everyone except admin)
                              // Like count is always visible; dislike count hidden (admin sees it in dashboard)
                              if (user != null && !user.isAdmin) ...[
                                Row(
                                  children: [
                                    // Like button
                                    IconButton(
                                      onPressed: _reacting
                                          ? null
                                          : () => _react('like'),
                                      icon: Icon(
                                        _myReaction == 'like'
                                            ? Icons.thumb_up
                                            : Icons.thumb_up_outlined,
                                        color: _myReaction == 'like'
                                            ? AppTheme.primaryColor
                                            : Colors.grey[600],
                                      ),
                                      tooltip: 'Like',
                                    ),
                                    Text(
                                      '${event.likeCount}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Dislike button
                                    IconButton(
                                      onPressed: _reacting
                                          ? null
                                          : () => _react('dislike'),
                                      icon: Icon(
                                        _myReaction == 'dislike'
                                            ? Icons.thumb_down
                                            : Icons.thumb_down_outlined,
                                        color: _myReaction == 'dislike'
                                            ? AppTheme.errorColor
                                            : Colors.grey[600],
                                      ),
                                      tooltip: 'Dislike',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ] else ...[
                                // Admin: just show the like count (no buttons)
                                Row(
                                  children: [
                                    Icon(Icons.thumb_up,
                                        size: 18, color: AppTheme.primaryColor),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${event.likeCount} like${event.likeCount == 1 ? '' : 's'}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Icon(Icons.thumb_down,
                                        size: 18, color: Colors.grey[500]),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${event.dislikeCount} dislike${event.dislikeCount == 1 ? '' : 's'}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],

                              // ─── Ticket Tiers Section ───
                              if (event.ticketStrategyId != null) ...[
                                const SizedBox(height: 16),
                                _sectionTitle(context, 'Ticket Tiers'),
                                const SizedBox(height: 8),
                                _buildTicketTiersSection(event),
                                const SizedBox(height: 16),
                              ],

                              // Your Discounts (customer view)
                              if (user != null) ...[
                                _CustomerDiscountsSection(eventId: event.id),
                              ],

                              // Actions for customers
                              if (user != null && user.isCustomer) ...[
                                _sectionTitle(context, 'Actions'),
                                const SizedBox(height: 8),

                                // State info banners
                                if (event.status == EventStatus.selling_tickets)
                                  _infoBanner('Funding has ended. Tickets are now on sale!', Icons.confirmation_number, Colors.teal),
                                if (event.status == EventStatus.waiting_event_date)
                                  _infoBanner('Funding has ended. Waiting for organizer to set event date.', Icons.hourglass_top, Colors.orange),
                                if (event.status == EventStatus.completed)
                                  _infoBanner('This event has been completed.', Icons.check_circle, Colors.grey),

                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    // Register / Unregister — only during approved state
                                    if (event.canUnregister) ...[
                                      if (_isRegistered && _regStatus == 'registered')
                                        OutlinedButton.icon(
                                          onPressed: _regLoading
                                              ? null
                                              : () => _unregister(context),
                                          icon: const Icon(Icons.person_remove,
                                              color: AppTheme.warningColor),
                                          label: const Text('Unregister',
                                              style: TextStyle(
                                                  color: AppTheme.warningColor)),
                                        )
                                      else
                                        ElevatedButton.icon(
                                          onPressed: _regLoading
                                              ? null
                                              : () => _register(context),
                                          icon: const Icon(Icons.how_to_reg),
                                          label: Text(_regStatus == 'waitlisted'
                                              ? 'Waitlisted'
                                              : 'Register'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppTheme.primaryColor,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                    ],

                                    // Pledge / Unpledge — only during funding period (approved + funding set)
                                    if (event.canPledge) ...[
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _showPledgeDialog(context, event),
                                        icon: const Icon(
                                            Icons.volunteer_activism),
                                        label: const Text('Pledge'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _unpledge(context),
                                        icon: const Icon(
                                            Icons.money_off,
                                            color: AppTheme.warningColor),
                                        label: const Text('Unpledge',
                                            style: TextStyle(
                                                color:
                                                    AppTheme.warningColor)),
                                      ),
                                    ],

                                    // Buy tickets — selling_tickets or live
                                    if (event.status == EventStatus.selling_tickets ||
                                        event.status == EventStatus.live)
                                      ElevatedButton.icon(
                                        onPressed: () => _showBuyTicketDialog(event),
                                        icon: const Icon(Icons.confirmation_number),
                                        label: const Text('Buy Tickets'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
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
                                    // Edit event
                                    if (event.status == EventStatus.draft ||
                                        event.status == EventStatus.pending_approval ||
                                        event.status == EventStatus.approved ||
                                        event.status == EventStatus.live)
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            context.go('/events/${event.id}/edit'),
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
                                            context.go('/events/${event.id}/edit'),
                                        icon: const Icon(Icons.calendar_month, size: 18),
                                        label: const Text('Set Event Date'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
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

                                    // Delete permanently (draft, unpublished, or cancelled)
                                    if (event.status ==
                                            EventStatus.draft ||
                                        event.status ==
                                            EventStatus.pending_approval ||
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

                              // ──────── Event Feed / Posts ────────
                              const SizedBox(height: 32),
                              _buildPostsSection(event, user),
                            ],
                          ),
                        ),
                      ),
                    ),
    );
  }

  // ─── Posts section ───

  Widget _buildPostsSection(Event event, dynamic user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionTitle(context, 'Event Feed'),
            const SizedBox(width: 8),
            if (!event.postsEnabled)
              Chip(
                label: const Text('Disabled', style: TextStyle(fontSize: 11)),
                backgroundColor: Colors.grey.shade200,
                side: BorderSide.none,
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Post input
        if (event.postsEnabled && user != null) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _postCtrl,
                  decoration: InputDecoration(
                    hintText: 'Write something...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  maxLines: 2,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _postingComment ? null : _submitPost,
                icon: _postingComment
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

        if (!event.postsEnabled)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Posts are disabled for this event.',
                  style: TextStyle(color: Colors.grey[500])),
            ),
          )
        else if (_loadingPosts)
          const Center(child: CircularProgressIndicator())
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
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                  child: Text(
                    (post.authorName ?? 'U')[0].toUpperCase(),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor),
                  ),
                ),
                title: Text(
                  post.authorName ?? 'User',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(post.content),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _timeAgo(post.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    if (isAuthor || isAdmin || isOrg) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
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

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'now';
  }

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

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildTicketTiersSection(Event event) {
    return FutureBuilder(
      future: context.read<ApiService>().dio.get('/events/${event.id}/ticket-tiers'),
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
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: tiers.map((t) {
                final name = t['name'] ?? 'Tier';
                final desc = t['description'] as String?;
                final priceCents = t['price_cents'] ?? 0;
                final price = (priceCents / 100).toStringAsFixed(2);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                          Text('\$$price',
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
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
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
                  final priceCents = t['price_cents'] ?? 0;
                  final price = (priceCents / 100).toStringAsFixed(2);
                  final tierId = t['id'];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.confirmation_number, color: Colors.teal),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('\$$price'),
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
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Buy'),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ticket purchased! Code: $ticketCode')),
        );
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
      context.go('/events/$newId/edit');
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

  Future<void> _unpledge(BuildContext context) async {
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

  Future<void> _showPledgeDialog(BuildContext context, Event event) async {
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
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[700]),
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
                final result = await api.pledge(
                    widget.eventId, (amount * 100).toInt());
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
        // Row: Co-organizers, Discounts
        Row(
          children: [
            Expanded(
              child: _mgmtActionCard(
                icon: Icons.group_rounded,
                label: 'Co-Organizers',
                color: AppTheme.accentColor,
                onTap: () => context.push('/events/${event.id}/co-organizers'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _mgmtActionCard(
                icon: Icons.discount_rounded,
                label: 'Discounts',
                color: Colors.deepPurple,
                onTap: () => context.push('/events/${event.id}/discounts'),
              ),
            ),
          ],
        ),
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
            Text('New funding end: ${ext['funding_end_at']}',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          if (ext['start_time'] != null)
            Text('New start time: ${ext['start_time']}',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          if (ext['end_time'] != null)
            Text('New end time: ${ext['end_time']}',
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
  // Extend Funding Dialog
  // ═══════════════════════════════════════════

  Future<void> _showExtendFundingDialog(BuildContext context, Event event) async {
    final fundingCtrl = TextEditingController();
    final startCtrl = TextEditingController();
    final endCtrl = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Extend Funding Period'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This will send a request to admin for approval.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: fundingCtrl,
                decoration: const InputDecoration(
                  labelText: 'New Funding End (ISO)',
                  hintText: '2026-03-01T00:00:00',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: startCtrl,
                decoration: const InputDecoration(
                  labelText: 'New Start Time (ISO, optional)',
                  hintText: '2026-04-01T18:00:00',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: endCtrl,
                decoration: const InputDecoration(
                  labelText: 'New End Time (ISO, optional)',
                  hintText: '2026-04-01T22:00:00',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final data = <String, String>{};
              if (fundingCtrl.text.trim().isNotEmpty) {
                data['funding_end_at'] = fundingCtrl.text.trim();
              }
              if (startCtrl.text.trim().isNotEmpty) {
                data['start_time'] = startCtrl.text.trim();
              }
              if (endCtrl.text.trim().isNotEmpty) {
                data['end_time'] = endCtrl.text.trim();
              }
              Navigator.pop(ctx, data);
            },
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    try {
      await ApiService().extendFunding(event.id, result);
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
// Customer Discounts Section
// ═══════════════════════════════════════════

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
    if (!_loaded || _discounts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            Icon(Icons.local_offer_rounded, size: 20, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Text('Your Discounts',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
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
