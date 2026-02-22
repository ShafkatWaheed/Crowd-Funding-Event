import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../models/event.dart';
import '../../../models/venue.dart';
import '../../../models/ticket_strategy.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/event_provider.dart';
import '../../../services/api_service.dart';
import '../../../widgets/app_toast.dart';
import '../../../widgets/press_feedback.dart';
import '../venue_picker_screen.dart';
import '../strategy_picker_screen.dart';
import 'live_mgmt_stats.dart';
import 'event_discount_dropdown.dart';
import 'schedule_milestone_dialogs.dart';

class OrganizerManagementSection extends StatefulWidget {
  final Event event;
  final bool isAdmin;
  final bool isOrganizer;
  final int? revenueCents;
  final VoidCallback onRefresh;

  const OrganizerManagementSection({
    super.key,
    required this.event,
    required this.isAdmin,
    required this.isOrganizer,
    this.revenueCents,
    required this.onRefresh,
  });

  @override
  State<OrganizerManagementSection> createState() =>
      _OrganizerManagementSectionState();
}

class _OrganizerManagementSectionState
    extends State<OrganizerManagementSection> {
  Event get _event => widget.event;

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();
    final user = context.watch<AuthProvider>().user;
    final isDark = AppTheme.isDark(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSpacing.vXxl,
        _sectionTitle(context, 'Organizer Actions',
            icon: Icons.admin_panel_settings_rounded,
            iconColor: AppTheme.accentColor),
        AppSpacing.vMd,

        // ── Primary Action Card (status-specific) ──
        // Draft → Publish
        if (_event.status == EventStatus.draft)
          _primaryActionCard(
            icon: Icons.publish_rounded,
            color: AppTheme.accentColor,
            title: 'Ready to publish?',
            subtitle: _event.startTime == null && _event.fundingEndAt == null
                ? 'Set an event date or funding deadline first.'
                : 'Submit your event for review.',
            buttonLabel: 'Publish Event',
            buttonEnabled: _event.startTime != null || _event.fundingEndAt != null,
            onPressed: () async {
              final ok = await eventProvider.publishEvent(_event.id);
              if (!ok && mounted) {
                AppToast.error(
                    context, eventProvider.error ?? 'Failed to publish');
              }
            },
          ),

        // Cancelled → Reactivate
        if (_event.status == EventStatus.cancelled)
          _primaryActionCard(
            icon: Icons.restore_rounded,
            color: AppTheme.warningColor,
            title: 'Reactivate this event?',
            subtitle: 'Move it back to draft for editing.',
            buttonLabel: 'Move to Draft',
            onPressed: () async {
              await eventProvider.reactivateEvent(_event.id);
            },
          ),

        // waiting_event_date → Start Selling
        if (_event.status == EventStatus.waiting_event_date)
          _primaryActionCard(
            icon: Icons.storefront_rounded,
            color: context.ticketAccent,
            title: 'Funding complete — next steps',
            subtitle: _event.startTime != null && _event.ticketStrategyId != null
                ? 'Everything is set. You can start selling tickets now!'
                : _event.startTime == null && _event.ticketStrategyId == null
                    ? 'Set an event date and attach a ticket strategy to begin selling.'
                    : _event.startTime == null
                        ? 'Set an event date to proceed.'
                        : 'Attach a ticket strategy to proceed.',
            buttonLabel: 'Start Selling Tickets',
            buttonEnabled:
                _event.startTime != null && _event.ticketStrategyId != null,
            onPressed: () =>
                _confirmStartSelling(context, eventProvider, _event),
          ),

        // Completed → Clone
        if (_event.status == EventStatus.completed)
          _primaryActionCard(
            icon: Icons.copy_all_rounded,
            color: AppTheme.accentColor,
            title: 'Run this event again?',
            subtitle: 'Clone it into a new draft with all settings pre-filled.',
            buttonLabel: 'Clone Event',
            onPressed: () => _cloneEvent(context, _event.id),
          ),

        // ── Setup Grid (waiting_event_date only) ──
        if (_event.status == EventStatus.waiting_event_date) ...[
          AppSpacing.vLg,
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.45,
            children: [
              _setupTile(
                icon: Icons.calendar_month_rounded,
                label: 'Event Date',
                subtitle: _event.startTime != null
                    ? DateFormat('MMM d, y – h:mm a').format(_event.startTime!)
                    : 'Not set',
                color: context.fundingAccent,
                isSet: _event.startTime != null,
                onTap: () => ScheduleMilestoneDialogs.showSetEventDateDialog(
                    context, _event, widget.onRefresh),
              ),
              _setupTile(
                icon: Icons.location_on_rounded,
                label: 'Venue',
                subtitle: _event.venue?.name ?? 'Not set',
                color: context.managementAccent,
                isSet: _event.venue != null,
                onTap: () => _selectVenueForEvent(context, _event),
              ),
              _setupTile(
                icon: Icons.confirmation_number_rounded,
                label: 'Ticket Strategy',
                subtitle: _event.ticketStrategyName ?? 'Not set',
                color: context.sponsorAccent,
                isSet: _event.ticketStrategyId != null,
                onTap: () => _selectStrategyForEvent(context, _event),
              ),
              _setupTile(
                icon: Icons.people_rounded,
                label: 'Max Capacity',
                subtitle: '${_event.maxCapacity}',
                color: context.ticketAccent,
                isSet: true,
                onTap: () => _showChangeCapacityDialog(context, _event),
              ),
            ],
          ),
        ],

        AppSpacing.vMd,

        // ── Secondary Actions (menu tiles) ──
        ClipRRect(
          borderRadius: AppRadius.lg,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardOf(context),
              borderRadius: AppRadius.lg,
              boxShadow: AppShadow.card(isDark),
            ),
            child: Column(
              children: [
                // Edit (draft, pending, approved only)
                if (_event.status == EventStatus.draft ||
                    _event.status == EventStatus.pending_approval ||
                    _event.status == EventStatus.approved)
                  _menuTile(
                    icon: Icons.edit_rounded,
                    iconColor: AppTheme.secondaryColor,
                    label: 'Edit Event',
                    trailing: _event.status == EventStatus.approved
                        ? 'Needs approval'
                        : null,
                    onTap: () => context.push('/events/${_event.id}/edit'),
                  ),

                // Manage Schedule (all statuses)
                _menuTile(
                  icon: Icons.calendar_month_rounded,
                  iconColor: AppTheme.accentColor,
                  label: 'Manage Schedule',
                  onTap: () =>
                      ScheduleMilestoneDialogs.showManageScheduleSheet(
                          context, _event, widget.onRefresh),
                ),

                // Manage Milestones (funding phase only)
                if (_event.status == EventStatus.approved)
                  _menuTile(
                    icon: Icons.flag_rounded,
                    iconColor: context.fundingAccent,
                    label: 'Manage Milestones',
                    onTap: () =>
                        ScheduleMilestoneDialogs.showManageMilestonesSheet(
                            context, _event, widget.onRefresh),
                  ),

                // Toggle posts (all statuses)
                _menuTile(
                  icon: _event.postsEnabled
                      ? Icons.comments_disabled_rounded
                      : Icons.comment_rounded,
                  iconColor: _event.postsEnabled
                      ? AppTheme.textSecondaryOf(context)
                      : AppTheme.accentColor,
                  label: _event.postsEnabled ? 'Disable Posts' : 'Enable Posts',
                  onTap: _togglePosts,
                ),

                // Change Venue (approved, waiting_event_date, selling_tickets)
                if (_event.status == EventStatus.approved ||
                    _event.status == EventStatus.waiting_event_date ||
                    _event.status == EventStatus.selling_tickets)
                  _menuTile(
                    icon: Icons.location_on_rounded,
                    iconColor: context.managementAccent,
                    label: 'Change Venue',
                    trailing: _event.venue?.name,
                    onTap: () => _selectVenueForEvent(context, _event),
                  ),

                // Change Ticket Strategy (approved, waiting_event_date)
                if (_event.status == EventStatus.approved ||
                    _event.status == EventStatus.waiting_event_date)
                  _menuTile(
                    icon: Icons.confirmation_number_rounded,
                    iconColor: context.sponsorAccent,
                    label: 'Change Ticket Strategy',
                    trailing: _event.ticketStrategyName,
                    onTap: () => _selectStrategyForEvent(context, _event),
                  ),

                // Increase Capacity (approved, waiting_event_date, selling_tickets, live)
                if (_event.status == EventStatus.approved ||
                    _event.status == EventStatus.waiting_event_date ||
                    _event.status == EventStatus.selling_tickets ||
                    _event.status == EventStatus.live)
                  _menuTile(
                    icon: Icons.group_add_rounded,
                    iconColor: context.ticketAccent,
                    label: 'Increase Capacity',
                    trailing: '${_event.maxCapacity}',
                    onTap: () => _showChangeCapacityDialog(context, _event),
                  ),

                // Extend Funding (waiting_event_date)
                if (_event.status == EventStatus.waiting_event_date)
                  _menuTile(
                    icon: Icons.more_time_rounded,
                    iconColor: AppTheme.accentColor,
                    label: 'Extend Funding',
                    onTap: () =>
                        ScheduleMilestoneDialogs.showExtendFundingDialog(
                            context, _event, widget.onRefresh),
                  ),

                // Cancel — organizer or admin for pre-selling
                if (_event.status == EventStatus.pending_approval ||
                    _event.status == EventStatus.approved ||
                    _event.status == EventStatus.waiting_event_date)
                  _menuTile(
                    icon: Icons.cancel_rounded,
                    iconColor: AppTheme.errorColor,
                    label: 'Cancel Event',
                    onTap: () =>
                        _confirmCancel(context, eventProvider, _event.id),
                    isDanger: true,
                  ),

                // Cancel — admin only for selling/live
                if ((_event.status == EventStatus.selling_tickets ||
                        _event.status == EventStatus.live) &&
                    user != null &&
                    user.isAdmin)
                  _menuTile(
                    icon: Icons.cancel_rounded,
                    iconColor: AppTheme.errorColor,
                    label: 'Cancel Event (Admin)',
                    onTap: () =>
                        _confirmCancel(context, eventProvider, _event.id),
                    isDanger: true,
                  ),

                // Request Cancellation — organizer (not admin) during selling
                if (_event.status == EventStatus.selling_tickets &&
                    user != null &&
                    !user.isAdmin &&
                    _event.pendingCancellation == null)
                  _menuTile(
                    icon: Icons.cancel_outlined,
                    iconColor: AppTheme.warningColor,
                    label: 'Request Cancellation',
                    onTap: () => _requestCancellation(
                        context, eventProvider, _event.id),
                  ),

                // Delete (draft or cancelled only)
                if (_event.status == EventStatus.draft ||
                    _event.status == EventStatus.cancelled)
                  _menuTile(
                    icon: Icons.delete_forever_rounded,
                    iconColor: AppTheme.errorColor,
                    label: 'Delete Permanently',
                    onTap: () =>
                        _confirmDelete(context, eventProvider, _event.id),
                    isDanger: true,
                  ),
              ],
            ),
          ),
        ),

        // ── Management shortcuts ──
        AppSpacing.vXxl,
        _sectionTitle(context, 'Management',
            icon: Icons.dashboard_rounded, iconColor: context.managementAccent),
        AppSpacing.vMd,
        _buildMgmtButtons(_event),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // Section title helper
  // ═══════════════════════════════════════════

  Widget _sectionTitle(BuildContext context, String title,
      {IconData? icon, Color? iconColor}) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: (iconColor ?? AppTheme.primaryColor)
                  .withValues(alpha: 0.1),
              borderRadius: AppRadius.sm,
            ),
            child: Icon(icon,
                size: AppIconSize.sm,
                color: iconColor ?? AppTheme.primaryColor),
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

  // ═══════════════════════════════════════════
  // Management action methods
  // ═══════════════════════════════════════════

  Future<void> _cloneEvent(BuildContext context, int eventId) async {
    try {
      final api = context.read<ApiService>();
      final data = await api.cloneEvent(eventId);
      if (!mounted) return;
      final newId = data['id'];
      AppToast.success(
          context, 'Event cloned as draft! Redirecting to edit...');
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
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: context.ticketAccent),
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
        AppToast.error(
            context,
            eventProvider.error ?? 'Failed to start selling tickets');
      }
    }
  }

  Future<void> _selectVenueForEvent(
      BuildContext context, Event event) async {
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

  Future<void> _selectStrategyForEvent(
      BuildContext context, Event event) async {
    final selected = await Navigator.push<TicketStrategy>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            StrategyPickerScreen(currentStrategyId: event.ticketStrategyId),
      ),
    );
    if (selected != null && mounted) {
      try {
        final api = context.read<ApiService>();
        final eventProvider = context.read<EventProvider>();
        await api.updateEvent(
            event.id, {'ticket_strategy_id': selected.id});
        await eventProvider.loadEvent(event.id);
        if (mounted) {
          AppToast.success(
              context, 'Strategy changed to ${selected.name}');
        }
      } catch (e) {
        if (mounted) {
          AppToast.fromError(
              context, e, fallback: 'Failed to change strategy');
        }
      }
    }
  }

  Future<void> _showChangeCapacityDialog(
      BuildContext context, Event event) async {
    final controller =
        TextEditingController(text: event.maxCapacity.toString());
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
                style: TextStyle(
                    color: AppTheme.textSecondaryOf(context), fontSize: 13)),
            AppSpacing.vMd,
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
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
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
          AppToast.fromError(
              context, e, fallback: 'Failed to update capacity');
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
            AppSpacing.vMd,
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
            AppSpacing.vMd,
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

  Future<void> _togglePosts() async {
    try {
      final api = context.read<ApiService>();
      await api.toggleEventPosts(_event.id);
      if (mounted) {
        context.read<EventProvider>().loadEvent(_event.id);
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to toggle posts');
      }
    }
  }

  // ═══════════════════════════════════════════
  // Management nav buttons
  // ═══════════════════════════════════════════

  Widget _buildMgmtButtons(Event event) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LiveMgmtStats(event: event),
        AppSpacing.vLg,

        if (event.status == EventStatus.selling_tickets ||
            event.status == EventStatus.live) ...[
          PressFeedback(
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () => context.push(
                  '/events/${event.id}/scan?title=${Uri.encodeComponent(event.title)}',
                ),
                icon: const Icon(Icons.qr_code_scanner_rounded,
                    size: AppIconSize.lg),
                label: const Text('Scan Tickets',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
                  elevation: 0,
                ),
              ),
            ),
          ),
          AppSpacing.vLg,
        ],

        Row(
          children: [
            Expanded(
              child: _mgmtActionCard(
                icon: Icons.group_rounded,
                label: 'Co-Organizers',
                color: AppTheme.accentColor,
                onTap: () =>
                    context.push('/events/${event.id}/co-organizers'),
              ),
            ),
            AppSpacing.hMd,
            Expanded(
              child: _mgmtActionCard(
                icon: Icons.storefront_rounded,
                label: 'Sponsorships',
                color: context.ticketAccent,
                onTap: () =>
                    context.push('/events/${event.id}/sponsorships'),
              ),
            ),
          ],
        ),
        AppSpacing.vMd,

        EventDiscountDropdown(eventId: event.id),

        if (event.pendingExtension != null) ...[
          AppSpacing.vMd,
          _buildPendingExtensionBanner(event),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════
  // UI builder widgets
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
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.xl,
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
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: AppRadius.md,
                ),
                child: Icon(icon, color: Colors.white, size: AppIconSize.lg),
              ),
              const Spacer(),
            ],
          ),
          AppSpacing.vMd,
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
          AppSpacing.vXs,
          Text(subtitle,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13)),
          AppSpacing.vLg,
          SizedBox(
            width: double.infinity,
            child: PressFeedback(
              child: ElevatedButton(
                onPressed: buttonEnabled ? onPressed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: color,
                  disabledBackgroundColor:
                      Colors.white.withValues(alpha: 0.5),
                  disabledForegroundColor: color.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape:
                      RoundedRectangleBorder(borderRadius: AppRadius.md),
                  elevation: 0,
                ),
                child: Text(buttonLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ),
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
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: AppRadius.lg,
          border: Border.all(
            color: isSet
                ? color.withValues(alpha: 0.3)
                : AppTheme.dividerOf(context),
            width: 1.5,
          ),
          boxShadow: AppShadow.soft(AppTheme.isDark(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: AppRadius.sm,
                  ),
                  child: Icon(icon, size: AppIconSize.sm, color: color),
                ),
                const Spacer(),
                if (isSet)
                  Icon(Icons.check_circle,
                      size: AppIconSize.sm, color: color),
              ],
            ),
            AppSpacing.vSm,
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryOf(context))),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondaryOf(context)),
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
    bool isLast = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: isLast
              ? const BorderRadius.vertical(
                  bottom: Radius.circular(AppRadius.lgValue))
              : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: 15),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: AppRadius.md,
                  ),
                  child:
                      Icon(icon, size: AppIconSize.md, color: iconColor),
                ),
                AppSpacing.hMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDanger
                                ? AppTheme.errorColor
                                : AppTheme.textPrimaryOf(context),
                          )),
                      if (trailing != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(trailing,
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      AppTheme.textSecondaryOf(context)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ),
                AppSpacing.hSm,
                Icon(Icons.chevron_right_rounded,
                    size: 20,
                    color: AppTheme.textSecondaryOf(context)),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
              height: 1,
              indent: 60,
              color: AppTheme.dividerOf(context)),
      ],
    );
  }

  Widget _mgmtActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    final dark = AppTheme.isDark(context);
    return Material(
      color: dark
          ? AppTheme.cardOf(context)
          : color.withValues(alpha: 0.06),
      borderRadius: AppRadius.lg,
      child: InkWell(
        borderRadius: AppRadius.lg,
        onTap: onTap,
        child: Container(
          padding: AppSpacing.paddingLg,
          decoration: BoxDecoration(
            borderRadius: AppRadius.lg,
            border: Border.all(
                color: color.withValues(alpha: dark ? 0.3 : 0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.md,
                ),
                child: Icon(icon, size: AppIconSize.md, color: color),
              ),
              AppSpacing.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: AppTheme.textPrimaryOf(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle,
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    AppTheme.textSecondaryOf(context))),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20,
                  color: AppTheme.textSecondaryOf(context)),
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
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: AppTheme.warningSurfaceOf(context),
        borderRadius: AppRadius.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded,
                  size: AppIconSize.sm, color: AppTheme.warningColor),
              AppSpacing.hSm,
              Expanded(
                child: Text(
                  'Extension Pending Admin Approval',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.warningColor,
                      fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (ext['funding_end_at'] != null)
            Text('New funding deadline: ${ext['funding_end_at']}',
                style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondaryOf(context))),
          if (ext['funding_goal_cents'] != null)
            Text(
                'New funding goal: \$${(ext['funding_goal_cents'] / 100).toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondaryOf(context))),
          if (user != null && user.isAdmin) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        _decideExtension(event.id, 'approve'),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.successColor),
                  ),
                ),
                AppSpacing.hSm,
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _decideExtension(event.id, 'reject'),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor),
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
        AppToast.fromError(
            context, e, fallback: 'Extension decision failed');
      }
    }
  }
}
