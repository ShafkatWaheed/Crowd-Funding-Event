import 'dart:async';
import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../utils/date_time_utils.dart';
import '../../../config/design_tokens.dart';
import '../../../models/discount.dart';
import '../../../models/event.dart';
import '../../../models/funding.dart';
import '../../../providers/auth_provider.dart';
import '../../../repositories/base_repository.dart';
import '../../../providers/pledge_provider.dart';
import '../../../providers/ticket_provider.dart';
import '../../../providers/config_provider.dart';
import '../../../widgets/app_toast.dart';
import '../receipts/pledge_receipt_screen.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

// ═══════════════════════════════════════════
// Self-contained Funding Card
// Loads its own data, pledge/unpledge only refresh this card
// ═══════════════════════════════════════════

class FundingCard extends StatefulWidget {
  final int eventId;
  final Event event;
  final bool isRegistered;

  const FundingCard({super.key, required this.eventId, required this.event, required this.isRegistered});

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
  List<EarlyBirdDiscount> _earlyBirdDiscounts = [];
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

  Color _trustColor(BuildContext context, String label) {
    switch (label) {
      case 'Excellent': return context.trustHigh;
      case 'Good':      return context.trustMedium;
      case 'Fair':      return context.trustMedium;
      case 'Low':       return context.trustLow;
      default:         return AppTheme.textSecondaryOf(context);
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

  // ── Metadata pill chip helper ──
  Widget _metaPill({
    required IconData icon,
    required String label,
    required bool isDark,
    bool accent = false,
    bool teal = false,
  }) {
    final Color bg, fg;
    if (accent) {
      bg = const Color(0xFFFF8C00).withValues(alpha: isDark ? 0.14 : 0.10);
      fg = isDark ? const Color(0xFFFFA733) : const Color(0xFFB85E00);
    } else if (teal) {
      bg = AppTheme.tealColor.withValues(alpha: isDark ? 0.13 : 0.10);
      fg = isDark ? const Color(0xFF4DB6AC) : const Color(0xFF0A7870);
    } else {
      bg = isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.055);
      fg = isDark ? const Color(0xFFC8B89A) : const Color(0xFF3A3A3C);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.pill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final fundingTimeLeft = event.fundingTimeLeftFormatted;
    final hasTimeLeft = event.fundingHasTimeLeft;
    final user = context.watch<AuthProvider>().user;
    final isOrganizerOrAdmin = user != null && (user.isOrganizer || user.isAdmin);
    final canPledge = event.canPledge && !isOrganizerOrAdmin;

    // ── Funding card decoration ──
    final cardDecoration = BoxDecoration(
      gradient: LinearGradient(
        begin: const Alignment(1, -1),
        end: const Alignment(-1, 1),
        colors: isDark
            // deep navy → rich Uber-blue → dark teal
            ? const [Color(0xFF0D1A2E), Color(0xFF112D5E), Color(0xFF0A2825)]
            // warm amber cream → pale ivory → soft blue-white
            : const [Color(0xFFFFF6E8), Color(0xFFFFF0D4), Color(0xFFEEF4FF)],
        stops: const [0.0, 0.5, 1.0],
      ),
      borderRadius: AppRadius.lg,
      border: Border.all(
        color: isDark
            ? const Color(0xFF276EF1).withValues(alpha: 0.22)
            : const Color(0xFFFF8C00).withValues(alpha: 0.28),
        width: isDark ? 1.0 : 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? const Color(0xFF276EF1).withValues(alpha: 0.28)
              : const Color(0xFFFF8C00).withValues(alpha: 0.16),
          blurRadius: isDark ? 32 : 24,
          offset: const Offset(0, 4),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Amber gradient card ──
        Container(
          width: double.infinity,
          decoration: cardDecoration,
          padding: AppSpacing.paddingLg,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Decorative glow orb (top-right)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topRight,
                      radius: 1.0,
                      colors: [
                        isDark
                            ? const Color(0xFF276EF1).withValues(alpha: 0.25)
                            : const Color(0xFFFF8C00).withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Card content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title row ──
                  Row(
                    children: [
                      Icon(Icons.attach_money,
                          size: AppIconSize.md,
                          color: isDark ? const Color(0xFFFFA733) : const Color(0xFFFF8C00)),
                      AppSpacing.hSm,
                      Text(
                        'Funding',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: isDark ? const Color(0xFFF2ECE0) : const Color(0xFF1C1C1E),
                        ),
                      ),
                      const Spacer(),
                      if (event.fundingEndAt != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: hasTimeLeft
                                ? const Color(0xFFFF8C00).withValues(alpha: 0.15)
                                : AppTheme.textSecondaryOf(context).withValues(alpha: 0.12),
                            borderRadius: AppRadius.xl,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer_rounded,
                                  size: 11,
                                  color: hasTimeLeft
                                      ? const Color(0xFFFF8C00)
                                      : AppTheme.textSecondaryOf(context)),
                              const SizedBox(width: 3),
                              Text(
                                fundingTimeLeft,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: hasTimeLeft
                                      ? const Color(0xFFFF8C00)
                                      : AppTheme.textSecondaryOf(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  AppSpacing.vLg,

                  // ── Arc (110px) + Stats ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 110,
                        height: 110,
                        child: Stack(
                          children: [
                            CustomPaint(
                              size: const Size(110, 110),
                              painter: _ArcPainter(
                                progress: _progress,
                                isDark: isDark,
                                isFunded: _progress >= 1.0,
                              ),
                            ),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${(_progress * 100).clamp(0, 999).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                      color: _progress >= 1.0
                                          ? AppTheme.successColor
                                          : const Color(0xFFFF8C00),
                                    ),
                                  ),
                                  Text(
                                    _progress >= 1.0 ? 'funded!' : 'funded',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4,
                                      color: Color(0xFFAFAFAF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Raised amount — visual anchor
                            Text(
                              _totalFormatted,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                                height: 1.05,
                                color: _progress >= 1.0
                                    ? AppTheme.successColor
                                    : (isDark
                                        ? const Color(0xFFF2ECE0)
                                        : const Color(0xFF1C1C1E)),
                              ),
                            ),
                            Text(
                              'of $_goalFormatted goal',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFAFAFAF)),
                            ),
                            if (_backersCount > 0 || _totalReservedSpots > 0) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 10,
                                runSpacing: 4,
                                children: [
                                  if (_backersCount > 0)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.people_rounded,
                                            size: 12, color: Color(0xFFFF8C00)),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$_backersCount backer${_backersCount == 1 ? '' : 's'}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFFF8C00)),
                                        ),
                                      ],
                                    ),
                                  if (_totalReservedSpots > 0)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.event_seat,
                                            size: 12, color: AppTheme.tealColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$_totalReservedSpots reserved',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.tealColor),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.vMd,

                  // ── Metadata strip (pill chips) ──
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (event.fundingEndAt != null)
                        _metaPill(
                          icon: Icons.timer_rounded,
                          label: 'Deadline ${AppDateFormat.dateOnly(event.fundingEndAt!)}',
                          isDark: isDark,
                          accent: true,
                        ),
                      if (event.minPledgeCents > 0)
                        _metaPill(
                          icon: Icons.arrow_downward,
                          label: 'Min \$${(event.minPledgeCents / 100).toStringAsFixed(0)}',
                          isDark: isDark,
                        ),
                      if (event.maxReservedSpotsPerUser > 0)
                        _metaPill(
                          icon: Icons.person_pin_rounded,
                          label:
                              '${event.maxReservedSpotsPerUser} spot${event.maxReservedSpotsPerUser == 1 ? '' : 's'} max',
                          isDark: isDark,
                          teal: true,
                        ),
                      if (_fundingCommissionPercent > 0)
                        _metaPill(
                          icon: Icons.percent,
                          label: '$_fundingCommissionPercent% fee',
                          isDark: isDark,
                        ),
                    ],
                  ),
                  AppSpacing.vMd,

                  // ── Amber divider ──
                  Container(
                    height: 1,
                    color: isDark
                        ? const Color(0xFFFFC043).withValues(alpha: 0.10)
                        : const Color(0xFFFF8C00).withValues(alpha: 0.18),
                  ),
                  AppSpacing.vMd,

                  // ── Early bird banners ──
                  ..._earlyBirdDiscounts.where((eb) => eb.isActive).map((eb) {
                    final discType = eb.discountType;
                    final value = eb.value;
                    final windowEnd =
                        eb.endsAt != null ? DateTime.tryParse(eb.endsAt!) : null;
                    final remaining = windowEnd != null
                        ? windowEnd.difference(DateTime.now().toUtc())
                        : Duration.zero;
                    final daysLeft = remaining.inDays;
                    final hoursLeft = remaining.inHours % 24;
                    final discLabel = discType == 'percent'
                        ? '$value% off'
                        : '\$${(value / 100).toStringAsFixed(2)} off';
                    final timeLabel = daysLeft > 0
                        ? '${daysLeft}d ${hoursLeft}h left'
                        : '${remaining.inHours}h left';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Container(
                        padding: AppSpacing.paddingMd,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            context.scheduleAccent.withValues(alpha: 0.14),
                            context.scheduleAccent.withValues(alpha: 0.04),
                          ]),
                          borderRadius: AppRadius.sm,
                          border: Border.all(
                              color: context.scheduleAccent.withValues(alpha: 0.25)),
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
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: context.scheduleAccent),
                                  ),
                                  Text(
                                    timeLabel,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: context.scheduleAccent.withValues(alpha: 0.8)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // ── Pledge button (full-width gradient CTA) ──
                  if (canPledge) ...[
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFFF7A00), Color(0xFFFFAA00)]),
                        borderRadius: AppRadius.md,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF8C00).withValues(alpha: 0.38),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _pledging ? null : _showPledgeDialog,
                          borderRadius: AppRadius.md,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                widget.isRegistered
                                    ? Icons.volunteer_activism
                                    : Icons.card_giftcard_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.isRegistered ? 'Pledge' : 'Donate',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700),
                              ),
                              if (_pledging) ...[
                                const SizedBox(width: 10),
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Unpledge — demoted to text link
                    if (widget.isRegistered)
                      Center(
                        child: TextButton.icon(
                          onPressed: _pledging ? null : _unpledge,
                          icon: Icon(
                            Icons.money_off,
                            size: 13,
                            color: _refundProcessing
                                ? AppTheme.textSecondaryOf(context)
                                : (isDark
                                    ? const Color(0xFFFF8C00).withValues(alpha: 0.55)
                                    : const Color(0xFFB85E00).withValues(alpha: 0.65)),
                          ),
                          label: Text(
                            _refundProcessing ? 'Refund Processing…' : 'Remove my pledge',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _refundProcessing
                                  ? AppTheme.textSecondaryOf(context)
                                  : (isDark
                                      ? const Color(0xFFFF8C00).withValues(alpha: 0.55)
                                      : const Color(0xFFB85E00).withValues(alpha: 0.65)),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // ── Trust strip — outside the amber card, neutral ──
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: AppRadius.md,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined,
                      size: 13,
                      color: isDark ? const Color(0xFF5B8DE8) : AppTheme.accentColor),
                  const SizedBox(width: 5),
                  Text(
                    'Escrow protected',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondaryOf(context)),
                  ),
                ],
              ),
              Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
              ),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 5,
                runSpacing: 4,
                children: [
                  Icon(_trustIcon(event.organizerTrustLabel),
                      size: 13,
                      color: _trustColor(context, event.organizerTrustLabel)),
                  Text(
                    'Organizer:',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondaryOf(context)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                      color: _trustColor(context, event.organizerTrustLabel)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${event.organizerTrustLabel} (${(event.organizerTrustScore * 100).toInt()}%)',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _trustColor(context, event.organizerTrustLabel)),
                    ),
                  ),
                  Text(
                    '${event.organizerCompletedEvents}/${event.organizerPublishedEvents} events',
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Arc CustomPainter — 270° horseshoe, orange→amber gradient
// ═══════════════════════════════════════════════════════════

class _ArcPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final bool isFunded;

  const _ArcPainter({
    required this.progress,
    required this.isDark,
    required this.isFunded,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5.5;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = 135 * pi / 180;  // 7.5 o'clock position
    const sweepAngle = 270 * pi / 180;  // 270° arc
    const strokeWidth = 8.5;

    // Track arc
    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = isDark ? const Color(0xFF3A2200) : const Color(0xFFFFE5B4),
    );

    if (progress <= 0) return;

    final fillSweep = progress.clamp(0.0, 1.0) * sweepAngle;
    final Color c1, c2;
    if (isFunded) {
      c1 = const Color(0xFF059669);
      c2 = const Color(0xFF34D399);
    } else {
      c1 = const Color(0xFFFF7A00);
      c2 = const Color(0xFFFFAA00);
    }

    canvas.drawArc(
      rect,
      startAngle,
      fillSweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + sweepAngle,
          colors: [c1, c2],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.isDark != isDark || old.isFunded != isFunded;
}
