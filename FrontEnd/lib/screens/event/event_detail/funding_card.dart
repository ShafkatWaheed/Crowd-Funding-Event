import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../models/event.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../widgets/app_toast.dart';
import '../pledge_receipt_screen.dart';

// ═══════════════════════════════════════════
// Self-contained Funding Card
// Loads its own data, pledge/unpledge only refresh this card
// ═══════════════════════════════════════════

class FundingCard extends StatefulWidget {
  final int eventId;
  final Event event;
  final bool isRegistered;

  const FundingCard({required this.eventId, required this.event, required this.isRegistered});

  @override
  State<FundingCard> createState() => _FundingCardState();
}

class _FundingCardState extends State<FundingCard> {
  int _totalPledgedCents = 0;
  int _backersCount = 0;
  int? _goalCents;
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
          _fundingCommissionPercent = data['funding_commission_percent'] ?? 0;
          _totalReservedSpots = data['total_reserved_spots'] ?? 0;
        });
      }
    } catch (_) {}
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
                      padding: AppSpacing.paddingMd,
                      margin: EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withValues(alpha: 0.1),
                        borderRadius: AppRadius.sm,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: AppIconSize.sm, color: AppTheme.warningColor),
                          AppSpacing.hSm,
                          Expanded(
                            child: Text(
                              'You are not registered. Your pledge will be a guest pledge (non-refundable) and you cannot reserve spots.',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
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
                    AppSpacing.vLg,
                    Text('Reserve Ticket Spots',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.textPrimaryOf(context))),
                    AppSpacing.vXs,
                    Text(
                      'Each spot costs min \$$minPledgeDollars. Up to $maxPerUser per user.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                    ),
                    AppSpacing.vSm,
                    Row(
                      children: [
                        IconButton(
                          onPressed: selectedSpots > 0
                              ? () => setDialogState(() => selectedSpots--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                          iconSize: AppIconSize.xl,
                        ),
                        Text('$selectedSpots',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          onPressed: selectedSpots < maxPerUser
                              ? () => setDialogState(() => selectedSpots++)
                              : null,
                          icon: const Icon(Icons.add_circle_outline),
                          iconSize: AppIconSize.xl,
                        ),
                        AppSpacing.hSm,
                        Text('spot(s)',
                            style: TextStyle(
                                fontSize: 13, color: AppTheme.textSecondaryOf(context))),
                      ],
                    ),
                    if (_totalReservedSpots > 0)
                      Padding(
                        padding: EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          '$_totalReservedSpots spot(s) already reserved for this event',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
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
                child: Text(widget.isRegistered ? 'Continue to Invoice' : 'Continue to Donate'),
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
              Icon(Icons.receipt_long, size: AppIconSize.lg, color: Colors.deepPurple),
              AppSpacing.hSm,
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
                    padding: AppSpacing.paddingMd,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: AppRadius.sm,
                    ),
                    child: Text(previewError, style: const TextStyle(color: Colors.red, fontSize: 12)),
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
                      padding: AppSpacing.paddingMd,
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.08),
                        borderRadius: AppRadius.sm,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event_seat, size: AppIconSize.sm, color: Colors.teal),
                          AppSpacing.hSm,
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
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryOf(context))),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: subtle ? FontWeight.normal : FontWeight.w600,
                  color: subtle ? AppTheme.textSecondaryOf(context) : AppTheme.textPrimaryOf(context))),
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
    final isDark = AppTheme.isDark(context);
    final fundingTimeLeft = event.fundingTimeLeftFormatted;
    final hasTimeLeft = event.fundingHasTimeLeft;
    final user = context.watch<AuthProvider>().user;
    final isOrganizerOrAdmin = user != null && (user.isOrganizer || user.isAdmin);
    final canPledge = event.canPledge && !isOrganizerOrAdmin;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: AppRadius.lg,
        boxShadow: AppShadow.card(isDark),
      ),
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Icon(Icons.attach_money, size: AppIconSize.md, color: AppTheme.accentColor),
              AppSpacing.hSm,
              const Text('Funding',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3)),
              const Spacer(),
              if (event.fundingEndAt != null)
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: hasTimeLeft
                        ? AppTheme.accentColor.withValues(alpha: 0.12)
                        : AppTheme.textSecondaryOf(context).withValues(alpha: 0.12),
                    borderRadius: AppRadius.xl,
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
          AppSpacing.vMd,

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
              AppSpacing.hSm,
              Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.xs),
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
                padding: EdgeInsets.only(bottom: AppSpacing.xs),
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
          AppSpacing.vSm,

          // Progress bar
          ClipRRect(
            borderRadius: AppRadius.sm,
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
              padding: EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Platform fee: $_fundingCommissionPercent% of pledges',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
              ),
            ),
          AppSpacing.vMd,

          // Deadline + Min pledge row
          Row(
            children: [
              if (event.fundingEndAt != null) ...[
                Icon(Icons.timer_outlined,
                    size: AppIconSize.sm, color: AppTheme.textSecondaryOf(context)),
                AppSpacing.hXs,
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
                    size: AppIconSize.sm, color: AppTheme.textSecondaryOf(context)),
                AppSpacing.hXs,
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
            AppSpacing.vSm,
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
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
                      Icon(Icons.event_seat, size: AppIconSize.sm, color: Colors.teal),
                      AppSpacing.hXs,
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
            padding: EdgeInsets.only(top: AppSpacing.sm),
            child: Container(
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                color: AppTheme.accentSurfaceOf(context),
                borderRadius: AppRadius.sm,
                border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Escrow line
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, size: AppIconSize.sm, color: AppTheme.accentColor),
                      AppSpacing.hSm,
                      Expanded(
                        child: Text(
                          'Pledges held in platform escrow until event milestones are met',
                          style: TextStyle(fontSize: 11, color: AppTheme.accentColor),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.vSm,
                  // Trust score line
                  Row(
                    children: [
                      Icon(
                        _trustIcon(event.organizerTrustLabel),
                        size: AppIconSize.sm,
                        color: _trustColor(event.organizerTrustLabel),
                      ),
                      AppSpacing.hSm,
                      Text(
                        'Organizer Trust: ',
                        style: TextStyle(fontSize: 11, color: AppTheme.accentColor),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: _trustColor(event.organizerTrustLabel).withValues(alpha: 0.15),
                          borderRadius: AppRadius.sm,
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
                      AppSpacing.hSm,
                      Text(
                        '${event.organizerCompletedEvents}/${event.organizerPublishedEvents} events',
                        style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryOf(context)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Pledge / Unpledge buttons
          if (canPledge) ...[
            AppSpacing.vMd,
            const Divider(height: 1),
            AppSpacing.vMd,
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: _pledging ? null : _showPledgeDialog,
                      icon: Icon(widget.isRegistered ? Icons.volunteer_activism : Icons.card_giftcard_rounded, size: AppIconSize.md),
                      label: Text(widget.isRegistered ? 'Pledge' : 'Donate',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.md),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
                if (widget.isRegistered) ...[
                  AppSpacing.hMd,
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed: _pledging ? null : _unpledge,
                        icon: Icon(Icons.money_off,
                            size: AppIconSize.md, color: AppTheme.warningColor),
                        label: const Text('Unpledge',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.warningColor)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.warningColor),
                          shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
