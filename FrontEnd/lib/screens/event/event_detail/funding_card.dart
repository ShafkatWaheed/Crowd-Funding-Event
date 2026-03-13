import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../models/discount.dart';
import '../../../models/event.dart';
import '../../../models/funding.dart';
import '../../../models/milestone.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/event_provider.dart';
import '../../../repositories/base_repository.dart';
import '../../../providers/pledge_provider.dart';
import '../../../providers/ticket_provider.dart';
import '../../../providers/config_provider.dart';
import '../../../widgets/app_toast.dart';
import '../receipts/pledge_receipt_screen.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'funding_card_helpers.dart';

// ═══════════════════════════════════════════
// Self-contained Funding Card
// Loads its own data, pledge/unpledge only refresh this card
// ═══════════════════════════════════════════

class FundingCard extends StatefulWidget {
  final int eventId;
  final Event event;
  final bool isRegistered;
  final void Function(bool isRegistered, String? status)? onRegistrationChanged;

  const FundingCard({
    super.key,
    required this.eventId,
    required this.event,
    required this.isRegistered,
    this.onRegistrationChanged,
  });

  @override
  State<FundingCard> createState() => _FundingCardState();
}

class _FundingCardState extends State<FundingCard> {
  int _totalPledgedCents = 0;
  int _backersCount = 0;
  int? _goalCents;
  bool _pledging = false;
  bool _registering = false;
  int _fundingCommissionPercent = 0;
  int _totalReservedSpots = 0;
  List<EarlyBirdDiscount> _earlyBirdDiscounts = [];
  List<FundingMilestone> _milestones = [];
  bool _refundProcessing = false;
  Timer? _refundPollTimer;

  Event get event => widget.event;

  @override
  void initState() {
    super.initState();
    _totalPledgedCents = event.totalPledgedCents ?? 0;
    _goalCents = event.fundingGoalCents;
    _totalReservedSpots = event.totalReservedSpots;
    _loadFunding();
    _loadEarlyBirdDiscounts();
    _loadMilestones();
  }

  @override
  void dispose() {
    _refundPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadEarlyBirdDiscounts() async {
    try {
      final ticketRepo = context.read<TicketProvider>();
      final data = await ticketRepo.getEarlyBirdDiscounts(widget.eventId);
      if (mounted) setState(() => _earlyBirdDiscounts = data);
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _loadMilestones() async {
    try {
      final milestones = await context.read<EventProvider>().getMilestones(widget.eventId);
      if (mounted) setState(() => _milestones = milestones);
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _loadFunding() async {
    try {
      final repo = context.read<PledgeProvider>();
      final data = await repo.getFundingSummary(widget.eventId);
      if (mounted) {
        setState(() {
          _totalPledgedCents = data.totalPledgedCents;
          _backersCount = data.backersCount;
          _goalCents = data.goalCents > 0 ? data.goalCents : null;
          _fundingCommissionPercent = data.fundingCommissionPercent;
          _totalReservedSpots = data.totalReservedSpots;
        });
      }
    } catch (e) { debugPrint(e.toString()); }
  }


  double get _progress {
    if (_goalCents == null || _goalCents == 0) return 0;
    return _totalPledgedCents / _goalCents!;
  }

  String get _goalFormatted {
    if (_goalCents == null) return 'N/A';
    return '\$${(_goalCents! / 100).toStringAsFixed(2)}';
  }

  String get _avgPledgeFormatted {
    if (_backersCount == 0) return '\$—';
    return '\$${(_totalPledgedCents / _backersCount / 100).toStringAsFixed(0)}';
  }

  String get _timeLeftFormatted {
    if (event.fundingEndAt == null) return '';
    final diff = event.fundingEndAt!.difference(DateTime.now().toUtc());
    if (diff.isNegative) return 'Ended';
    if (diff.inDays >= 1) return '${diff.inDays}d ${diff.inHours % 24}h';
    if (diff.inHours >= 1) return '${diff.inHours}h ${diff.inMinutes % 60}m';
    return '< 1h';
  }

  Future<void> _register() async {
    setState(() => _registering = true);
    try {
      final result = await context.read<EventProvider>().register(widget.eventId);
      widget.onRegistrationChanged?.call(true, result.status);
      if (!mounted) return;
      context.read<EventProvider>().patchRegistrationCount(widget.eventId, 1);
      AppToast.success(context, 'Registered successfully!');
    } catch (e) {
      if (!mounted) return;
      AppToast.fromError(context, e, fallback: 'Registration failed');
    }
    if (mounted) setState(() => _registering = false);
  }

  Future<void> _unregisterFromCard() async {
    setState(() => _registering = true);
    try {
      final result = await context.read<EventProvider>().unregister(widget.eventId);
      widget.onRegistrationChanged?.call(false, null);
      if (!mounted) return;
      context.read<EventProvider>().patchRegistrationCount(widget.eventId, -1);
      AppToast.success(context, result.refundedCents > 0 ? 'Unregistered. Refund initiated.' : 'Unregistered.');
    } catch (e) {
      if (!mounted) return;
      AppToast.fromError(context, e, fallback: 'Unregister failed');
    }
    if (mounted) setState(() => _registering = false);
  }

  // ── Step 1: Pledge dialog (amount + spot selector) ──
  Future<void> _showPledgeDialog() async {
    final amountController = TextEditingController();
    int selectedSpots = 0;
    final maxPerUser = event.maxReservedSpotsPerUser;
    final minPledgeDollars = (event.minPledgeCents / 100).toStringAsFixed(2);
    final isTierLinked = event.linkFundingToTiers;

    // Per-tier spot allocation for tier-linked mode
    Map<int, int> tierSpots = {};
    List<TierAvailability> tierAvailability = [];
    bool loadingTiers = isTierLinked;
    int availableSpotsForUser = maxPerUser;

    if (isTierLinked) {
      try {
        final repo = context.read<PledgeProvider>();
        final preview = await repo.getPledgePreview(widget.eventId, 0, 0);
        tierAvailability = preview.tierAvailability;
        availableSpotsForUser = preview.availableSpotsForUser;
        for (final t in tierAvailability) {
          tierSpots[t.tierId] = 0;
        }
        loadingTiers = false;
      } catch (_) {
        loadingTiers = false;
      }
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          int totalTierSpots = tierSpots.values.fold(0, (a, b) => a + b);
          int minTierCost = 0;
          for (final t in tierAvailability) {
            final tid = t.tierId;
            final price = t.priceCents;
            minTierCost += price * (tierSpots[tid] ?? 0);
          }
          final minRequired = isTierLinked
              ? minTierCost
              : selectedSpots * event.minPledgeCents;
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
                      helperText: (isTierLinked ? totalTierSpots : selectedSpots) > 0
                          ? 'Min \$$minRequiredDollars for ${isTierLinked ? totalTierSpots : selectedSpots} spot(s)'
                          : isTierLinked
                              ? 'Select tiers below to reserve spots'
                              : 'Min pledge: \$$minPledgeDollars',
                    ),
                  ),

                  // ── Tier-linked spot selection ──
                  if (isTierLinked && widget.isRegistered) ...[
                    AppSpacing.vLg,
                    Row(
                      children: [
                        Expanded(
                          child: Text('Reserve Spots by Tier',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppTheme.textPrimaryOf(context))),
                        ),
                        if (maxPerUser > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: totalTierSpots >= availableSpotsForUser
                                  ? AppTheme.errorColor.withValues(alpha: 0.1)
                                  : ctx.fundingAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$totalTierSpots / $availableSpotsForUser spots',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: totalTierSpots >= availableSpotsForUser
                                    ? AppTheme.errorColor
                                    : ctx.fundingAccent,
                              ),
                            ),
                          ),
                      ],
                    ),
                    AppSpacing.vXs,
                    Text(
                      maxPerUser > 0
                          ? 'Min pledge = tier price × spots. Max $maxPerUser spot${maxPerUser == 1 ? '' : 's'} per person.'
                          : 'Min pledge = tier price × spots reserved.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                    ),
                    AppSpacing.vSm,
                    if (loadingTiers)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ))
                    else
                      ...tierAvailability.map((t) {
                        final tid = t.tierId;
                        final name = t.tierName;
                        final price = t.priceCents;
                        final available = t.available;
                        final spots = tierSpots[tid] ?? 0;
                        final bool userLimitReached = maxPerUser > 0 && totalTierSpots >= availableSpotsForUser;
                        final bool canAdd = spots < available && !userLimitReached;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: AppRadius.sm,
                            border: Border.all(
                              color: spots > 0
                                  ? ctx.ticketAccent.withValues(alpha: 0.4)
                                  : AppTheme.dividerOf(ctx),
                            ),
                            color: spots > 0
                                ? ctx.ticketSurface
                                : null,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: AppTheme.textPrimaryOf(ctx))),
                                    Text(
                                      '\$${(price / 100).toStringAsFixed(2)}/spot · $available available',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondaryOf(ctx)),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: spots > 0
                                    ? () => setDialogState(() => tierSpots[tid] = spots - 1)
                                    : null,
                                icon: const Icon(Icons.remove_circle_outline),
                                iconSize: 22,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text('$spots',
                                    style: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                              IconButton(
                                onPressed: canAdd
                                    ? () => setDialogState(() => tierSpots[tid] = spots + 1)
                                    : null,
                                icon: const Icon(Icons.add_circle_outline),
                                iconSize: 22,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        );
                      }),
                    if (totalTierSpots > 0) ...[
                      AppSpacing.vSm,
                      Container(
                        padding: AppSpacing.paddingMd,
                        decoration: BoxDecoration(
                          color: ctx.fundingSurface,
                          borderRadius: AppRadius.sm,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...tierAvailability.where((t) => (tierSpots[t.tierId] ?? 0) > 0).map((t) {
                              final tid = t.tierId;
                              final name = t.tierName;
                              final price = t.priceCents;
                              final spots = tierSpots[tid]!;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('$name ($spots × \$${(price / 100).toStringAsFixed(2)})',
                                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(ctx))),
                                    Text('\$${(price * spots / 100).toStringAsFixed(2)}',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(ctx))),
                                  ],
                                ),
                              );
                            }),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Minimum pledge',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(ctx))),
                                Text('\$$minRequiredDollars',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ctx.fundingAccent)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],

                  // ── Global spot selection (non-tier-linked) ──
                  if (!isTierLinked && maxPerUser > 0 && widget.isRegistered) ...[
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
                  final totalSpots = isTierLinked ? totalTierSpots : selectedSpots;
                  final reservations = isTierLinked
                      ? tierSpots.entries
                          .where((e) => e.value > 0)
                          .map((e) {
                            final ta = tierAvailability.firstWhere((t) => t.tierId == e.key);
                            return TierReservationInput(tierId: e.key, tierName: ta.tierName, spots: e.value);
                          })
                          .toList()
                      : null;
                  _showPledgeInvoice(
                    (amount * 100).toInt(),
                    totalSpots,
                    tierReservations: reservations,
                  );
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
  Future<void> _showPledgeInvoice(int amountCents, int reservedSpots,
      {List<TierReservationInput>? tierReservations}) async {
    PledgePreview? preview;
    bool loadingPreview = true;
    String? previewError;

    try {
      final repo = context.read<PledgeProvider>();
      preview = await repo.getPledgePreview(widget.eventId, amountCents, reservedSpots);
      loadingPreview = false;
    } catch (e) {
      loadingPreview = false;
      previewError = ApiError.extractMessage(e);
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final amountDollars = (amountCents / 100).toStringAsFixed(2);
        final platformCut = preview?.platformCutCents ?? 0;
        final netToOrganizer = preview?.netToOrganizerCents ?? 0;
        final commissionPct = preview?.fundingCommissionPercent ?? 0;

        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.receipt_long, size: AppIconSize.lg, color: ctx.sponsorAccent),
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
                      color: AppTheme.errorSurfaceOf(ctx),
                      borderRadius: AppRadius.sm,
                    ),
                    child: Text(previewError, style: TextStyle(color: AppTheme.errorColor, fontSize: 12)),
                  )
                else if (loadingPreview)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  _invoiceRow('Pledge Amount', '\$$amountDollars'),
                  if (reservedSpots > 0)
                    _invoiceRow('Reserved Spots', '$reservedSpots spot(s)'),
                  if (tierReservations != null && tierReservations.isNotEmpty) ...[
                    const Divider(height: 12),
                    ...tierReservations.map((tr) {
                      final name = tr.tierName ?? 'Tier #${tr.tierId}';
                      return _invoiceRow('  $name', '${tr.spots} spot(s)', subtle: true);
                    }),
                  ],
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
                        color: ctx.ticketSurface,
                        borderRadius: AppRadius.sm,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event_seat, size: AppIconSize.sm, color: ctx.ticketAccent),
                          AppSpacing.hSm,
                          Expanded(
                            child: Text(
                              '$reservedSpots spot(s) will be reserved for your future ticket purchase.',
                              style: TextStyle(fontSize: 12, color: ctx.ticketAccent),
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
      await _executePledge(amountCents, reservedSpots,
          tierReservations: tierReservations);
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
  Future<void> _executePledge(int amountCents, int reservedSpots,
      {List<TierReservationInput>? tierReservations}) async {
    setState(() => _pledging = true);
    _showPaymentProcessing();
    try {
      final config = context.read<ConfigProvider>();
      final repo = context.read<PledgeProvider>();

      // Stripe Payment Sheet flow when Stripe is enabled
      if (config.stripeEnabled) {
        final intent = await config.createPaymentIntent(
          amountCents: amountCents,
          description: 'Pledge for event ${widget.eventId}',
        );
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: intent.clientSecret,
            merchantDisplayName: 'CrowdFund Event',
          ),
        );
        await Stripe.instance.presentPaymentSheet();
      }

      final result = await repo.pledge(widget.eventId, amountCents,
          reservedSpots: reservedSpots,
          tierReservations: tierReservations);
      _dismissPaymentProcessing();
      if (mounted) {
        final isGuest = result.isGuest;
        final pledgeId = result.id;
        AppToast.success(context, isGuest
            ? 'Guest pledge (non-refundable)'
            : 'Pledge confirmed!');
        setState(() {
          _totalPledgedCents += result.amountCents;
          _totalReservedSpots += result.reservedSpots;
          _backersCount += 1;
        });
        context.read<EventProvider>().patchViewerData(
              widget.eventId,
              pledgeDelta: result.amountCents,
            );
        _loadFunding(); // background sync for accurate totals
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PledgeReceiptScreen(
            eventId: widget.eventId,
            pledgeId: pledgeId,
          ),
        ));
      }
    } catch (e) {
      _dismissPaymentProcessing();
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Pledge failed');
      }
    } finally {
      if (mounted) setState(() => _pledging = false);
    }
  }

  void _showPaymentProcessing() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            decoration: BoxDecoration(
              color: AppTheme.cardOf(context),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 48, height: 48,
                  child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.accentColor),
                ),
                const SizedBox(height: 20),
                Text('Processing pledge...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(context))),
                const SizedBox(height: 8),
                Text('Please wait while we process your transaction',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _dismissPaymentProcessing() {
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
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

    if (confirmed != true || !mounted) return;
    try {
      final repo = context.read<PledgeProvider>();
      final result = await repo.unpledge(widget.eventId);
      if (!mounted) return;
      final refunded = result.refundedCents;
      final guest = result.guestNonRefundableCents;
      final status = result.status;

      setState(() {
        _totalPledgedCents = (_totalPledgedCents - result.unpledgedAmountCents).clamp(0, _totalPledgedCents);
        if (result.remainingPledges == 0) {
          _backersCount = (_backersCount - 1).clamp(0, _backersCount);
        }
      });
      if (status == 'refund_processing') {
        setState(() => _refundProcessing = true);
        var msg = 'Refund of \$${(refunded / 100).toStringAsFixed(2)} is processing';
        if (guest > 0) {
          msg += ' (\$${(guest / 100).toStringAsFixed(2)} guest pledges non-refundable)';
        }
        AppToast.info(context, msg);
        _startRefundPolling();
      } else {
        var msg = 'Refunded \$${(refunded / 100).toStringAsFixed(2)}';
        if (guest > 0) {
          msg += ' (\$${(guest / 100).toStringAsFixed(2)} guest pledges non-refundable)';
        }
        AppToast.success(context, msg);
      }
      _loadFunding(); // background sync for accurate totals
    } catch (e) {
      if (!mounted) return;
      AppToast.fromError(context, e, fallback: 'Unpledge failed');
    }
  }

  void _startRefundPolling() {
    _refundPollTimer?.cancel();
    _refundPollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final repo = context.read<PledgeProvider>();
        final result = await repo.getRefundStatus(widget.eventId);
        final status = result.status;

        if (status == 'completed') {
          _refundPollTimer?.cancel();
          if (mounted) {
            setState(() => _refundProcessing = false);
            AppToast.success(context, 'Refund completed');
            _loadFunding();
          }
        } else if (status == 'failed') {
          _refundPollTimer?.cancel();
          if (mounted) {
            setState(() => _refundProcessing = false);
            AppToast.error(context, 'Refund failed — contact support');
            _loadFunding();
          }
        }
      } catch (e) { debugPrint(e.toString()); }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final user = context.watch<AuthProvider>().user;
    final isOrganizerOrAdmin = user != null && (user.isOrganizer || user.isAdmin);
    final canPledge = event.canPledge && !isOrganizerOrAdmin;

    // ── Sort milestones by unlockPercent ──
    final sorted = List<FundingMilestone>.from(_milestones)
      ..sort((a, b) => a.unlockPercent.compareTo(b.unlockPercent));
    final progressPct = (_progress * 100).clamp(0, 999);
    // index of first not-yet-unlocked milestone
    final nextIdx = sorted.indexWhere((m) => progressPct < m.unlockPercent);

    final accentColor = const Color(0xFF8B5CF6);
    final bgColor = isDark ? const Color(0xFF0E0B1C) : const Color(0xFFF5F3FF);
    final cardBorder = isDark
        ? const Color(0xFF7C3AED).withValues(alpha: 0.25)
        : const Color(0xFF8B5CF6).withValues(alpha: 0.3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Main card ──
        Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: AppRadius.lg,
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6D28D9).withValues(alpha: isDark ? 0.28 : 0.12),
                blurRadius: 28,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // ambient glow
              Positioned(
                top: -30, right: -30,
                child: Container(
                  width: 160, height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      const Color(0xFF6D28D9).withValues(alpha: isDark ? 0.15 : 0.08),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
              Padding(
                padding: AppSpacing.paddingLg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header row ──
                    Row(
                      children: [
                        Icon(Icons.monetization_on_outlined,
                            size: 14, color: accentColor.withValues(alpha: 0.8)),
                        const SizedBox(width: 8),
                        Text(
                          'FUNDING',
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: accentColor.withValues(alpha: 0.7),
                          ),
                        ),
                        const Spacer(),
                        // Time-left chip
                        if (event.fundingHasTimeLeft)
                          _TimeLeftBadge(timeLeft: _timeLeftFormatted)
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.1),
                              borderRadius: AppRadius.pill,
                            ),
                            child: Text(
                              'Ended',
                              style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: AppTheme.textSecondaryOf(context),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Amount ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$',
                          style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700,
                            color: accentColor.withValues(alpha: 0.65),
                            height: 1.8,
                          ),
                        ),
                        Text(
                          (_totalPledgedCents / 100).toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 38, fontWeight: FontWeight.w800,
                            letterSpacing: -1.5, height: 1,
                            color: isDark ? const Color(0xFFF5F3FF) : const Color(0xFF1C1C1E),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'of $_goalFormatted goal',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Progress bar with shimmer ──
                    FundingShimmerBar(
                      progress: _progress,
                      active: event.fundingHasTimeLeft,
                      fillColors: const [Color(0xFF5B21B6), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
                      trackColor: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.06),
                      glowColor: const Color(0xFF8B5CF6),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${progressPct.toStringAsFixed(0)}% funded',
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: accentColor,
                          ),
                        ),
                        if (_goalCents != null && _totalPledgedCents < _goalCents!)
                          Text(
                            '\$${((_goalCents! - _totalPledgedCents) / 100).toStringAsFixed(0)} remaining',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.8),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Stats strip ──
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                          bottom: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          Expanded(child: FundingStatCell(
                            value: '$_fundingCommissionPercent%',
                            label: 'Platform fee',
                            valueColor: isDark ? const Color(0xFFE4E4F0) : const Color(0xFF1C1C1E),
                          )),
                          Container(width: 0.5, height: 32, color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
                          Expanded(child: FundingStatCell(
                            value: '$_backersCount',
                            label: 'Backers',
                            valueColor: isDark ? const Color(0xFFE4E4F0) : const Color(0xFF1C1C1E),
                          )),
                          Container(width: 0.5, height: 32, color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
                          Expanded(child: FundingStatCell(
                            value: _avgPledgeFormatted,
                            label: 'Avg pledge',
                            valueColor: isDark ? const Color(0xFFE4E4F0) : const Color(0xFF1C1C1E),
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Early bird banners ──
                    ..._earlyBirdDiscounts.where((eb) => eb.isActive).map((eb) {
                      final value = eb.value;
                      final windowEnd = eb.endsAt != null ? DateTime.tryParse(eb.endsAt!) : null;
                      final remaining = windowEnd != null ? windowEnd.difference(DateTime.now().toUtc()) : Duration.zero;
                      final daysLeft = remaining.inDays;
                      final discLabel = eb.discountType == 'percent'
                          ? '$value% off' : '\$${(value / 100).toStringAsFixed(2)} off';
                      final timeLabel = daysLeft > 0
                          ? '${daysLeft}d ${remaining.inHours % 24}h left'
                          : '${remaining.inHours}h left';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: AppSpacing.paddingMd,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              context.scheduleAccent.withValues(alpha: 0.12),
                              context.scheduleAccent.withValues(alpha: 0.04),
                            ]),
                            borderRadius: AppRadius.sm,
                            border: Border.all(color: context.scheduleAccent.withValues(alpha: 0.22)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.bolt_rounded, size: 14, color: context.scheduleAccent),
                              AppSpacing.hSm,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      eb.target == 'funding'
                                          ? 'Early bird pledge — $discLabel tickets!'
                                          : 'Early bird tickets — $discLabel!',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.scheduleAccent),
                                    ),
                                    Text(timeLabel,
                                      style: TextStyle(fontSize: 11, color: context.scheduleAccent.withValues(alpha: 0.8))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    // ── Pledge CTA + Register ──
                    if (canPledge) ...[
                      Row(
                        children: [
                          // Register / Unregister button
                          if (!widget.isRegistered) ...[
                            _RegisterButton(
                              registered: false,
                              loading: _registering,
                              onTap: _register,
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                          ] else ...[
                            _RegisterButton(
                              registered: true,
                              loading: _registering,
                              onTap: _unregisterFromCard,
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                          ],
                          // Donate / Back this Event button
                          Expanded(
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                    colors: [Color(0xFF5B21B6), Color(0xFF6D28D9), Color(0xFF7C3AED)]),
                                borderRadius: AppRadius.md,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6D28D9).withValues(alpha: 0.38),
                                    blurRadius: 18, offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _pledging ? null : _showPledgeDialog,
                                  borderRadius: AppRadius.md,
                                  child: Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          widget.isRegistered
                                              ? Icons.favorite_border_rounded
                                              : Icons.card_giftcard_rounded,
                                          color: Colors.white, size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          widget.isRegistered ? 'Back this Event' : 'Donate',
                                          style: const TextStyle(
                                            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (_pledging) ...[
                                          const SizedBox(width: 10),
                                          const SizedBox(width: 14, height: 14,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (widget.isRegistered) ...[
                        const SizedBox(height: 4),
                        Center(
                          child: TextButton.icon(
                            onPressed: _pledging ? null : _unpledge,
                            icon: Icon(Icons.money_off, size: 13,
                                color: _refundProcessing
                                    ? AppTheme.textSecondaryOf(context)
                                    : accentColor.withValues(alpha: 0.5)),
                            label: Text(
                              _refundProcessing ? 'Refund Processing…' : 'Remove my pledge',
                              style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: _refundProcessing
                                    ? AppTheme.textSecondaryOf(context)
                                    : accentColor.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],

                    // ── Milestones ──
                    if (sorted.isNotEmpty) ...[
                      Container(
                        height: 0.5,
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'MILESTONES',
                            style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              letterSpacing: 0.09,
                              color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.6),
                            ),
                          ),
                          Text(
                            '${sorted.where((m) => m.isUnlocked).length} of ${sorted.length} reached',
                            style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: accentColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...sorted.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final ms = entry.value;
                        final goalAmt = _goalCents != null
                            ? '\$${(_goalCents! * ms.unlockPercent / 10000).toStringAsFixed(0)}'
                            : '${ms.unlockPercent}%';
                        final isHit = ms.isUnlocked;
                        final isNext = !isHit && idx == nextIdx;
                        final progressToNext = isNext && ms.unlockPercent > 0
                            ? (progressPct / ms.unlockPercent).clamp(0.0, 1.0)
                            : 0.0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: FundingMilestoneRow(
                            title: ms.title,
                            subtitle: isHit
                                ? 'Reached · ${ms.unlockPercent}% goal'
                                : isNext
                                    ? '${ms.unlockPercent}% goal · ${((1 - progressToNext) * (_goalCents ?? 0) * ms.unlockPercent / 10000).toStringAsFixed(0)}\$ away'
                                    : 'Locked · ${ms.unlockPercent}% goal',
                            amount: goalAmt,
                            state: isHit ? FundingMsState.hit : isNext ? FundingMsState.next : FundingMsState.locked,
                            nextFillFraction: progressToNext,
                            isDark: isDark,
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

      ],
    );
  }

}

// ── Pulsing Live badge (private — only used in FundingCard) ──
class _PulseBadge extends StatefulWidget {
  final Color color;
  final String label;
  const _PulseBadge({required this.color, required this.label});
  @override
  State<_PulseBadge> createState() => _PulseBadgeState();
}

class _PulseBadgeState extends State<_PulseBadge> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.1),
        border: Border.all(color: widget.color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: (1 - _ctrl.value) * 0.6),
                    blurRadius: 6 * _ctrl.value,
                    spreadRadius: 2 * _ctrl.value,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(widget.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: widget.color)),
        ],
      ),
    );
  }
}

// ── Time-left chip — shows "2d 14h" with a pulsing amber dot ──
class _TimeLeftBadge extends StatefulWidget {
  final String timeLeft;
  const _TimeLeftBadge({required this.timeLeft});
  @override
  State<_TimeLeftBadge> createState() => _TimeLeftBadgeState();
}

class _TimeLeftBadgeState extends State<_TimeLeftBadge> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFFBBF24);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: (1 - _ctrl.value) * 0.55),
                    blurRadius: 5 * _ctrl.value,
                    spreadRadius: 2 * _ctrl.value,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            widget.timeLeft,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(width: 4),
          const Text(
            'left',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }
}

// ── Register / Unregister compact button beside Donate ──
class _RegisterButton extends StatelessWidget {
  final bool registered;
  final bool loading;
  final VoidCallback? onTap;
  final bool isDark;
  const _RegisterButton({
    required this.registered,
    required this.loading,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: registered ? 0.12 : 0.18)
        : Colors.black.withValues(alpha: registered ? 0.10 : 0.14);
    final textColor = registered
        ? AppTheme.textSecondaryOf(context)
        : (isDark ? const Color(0xFFE4E4F0) : const Color(0xFF1C1C1E));
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
          border: Border.all(color: borderColor),
          borderRadius: AppRadius.md,
        ),
        child: loading
            ? SizedBox(
                width: 48,
                child: Center(
                  child: SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: textColor,
                    ),
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    registered ? Icons.how_to_reg_rounded : Icons.person_add_outlined,
                    size: 15,
                    color: textColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    registered ? 'Registered' : 'Register',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
