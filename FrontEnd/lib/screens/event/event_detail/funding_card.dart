import 'dart:async';

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
  List<dynamic> _earlyBirdDiscounts = [];
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
      final api = context.read<ApiService>();
      final data = await api.getEarlyBirdDiscounts(widget.eventId);
      if (mounted) setState(() => _earlyBirdDiscounts = data);
    } catch (_) {}
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
    List<Map<String, dynamic>> tierAvailability = [];
    bool loadingTiers = isTierLinked;

    if (isTierLinked) {
      try {
        final api = context.read<ApiService>();
        final preview = await api.getPledgePreview(widget.eventId, 0, 0);
        tierAvailability = List<Map<String, dynamic>>.from(preview['tier_availability'] ?? []);
        for (final t in tierAvailability) {
          tierSpots[t['tier_id'] as int] = 0;
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
            final tid = t['tier_id'] as int;
            final price = t['price_cents'] as int;
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
                    Text('Reserve Spots by Tier',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.textPrimaryOf(context))),
                    AppSpacing.vXs,
                    Text(
                      'Min pledge = tier price × spots reserved.',
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
                        final tid = t['tier_id'] as int;
                        final name = t['tier_name'] as String;
                        final price = t['price_cents'] as int;
                        final available = t['available'] as int;
                        final spots = tierSpots[tid] ?? 0;
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
                                onPressed: spots < available
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
                            ...tierAvailability.where((t) => (tierSpots[t['tier_id'] as int] ?? 0) > 0).map((t) {
                              final tid = t['tier_id'] as int;
                              final name = t['tier_name'] as String;
                              final price = t['price_cents'] as int;
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
                          .map((e) => {'tier_id': e.key, 'spots': e.value})
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
      {List<Map<String, dynamic>>? tierReservations}) async {
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
                      final name = tr['tier_name'] ?? 'Tier #${tr['tier_id']}';
                      final spots = tr['spots'] as int;
                      return _invoiceRow('  $name', '$spots spot(s)', subtle: true);
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
      {List<Map<String, dynamic>>? tierReservations}) async {
    setState(() => _pledging = true);
    try {
      final api = context.read<ApiService>();
      final result = await api.pledge(widget.eventId, amountCents,
          reservedSpots: reservedSpots,
          tierReservations: tierReservations);
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
          final status = result['status'] ?? 'completed';

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
          _loadFunding();
        }
      } catch (e) {
        if (context.mounted) {
          AppToast.fromError(context, e, fallback: 'Unpledge failed');
        }
      }
    }
  }

  void _startRefundPolling() {
    _refundPollTimer?.cancel();
    _refundPollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final api = context.read<ApiService>();
        final result = await api.getRefundStatus(widget.eventId);
        final status = result['status'] as String? ?? 'none';

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
      } catch (_) {}
    });
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
                      Icon(Icons.people_outline, size: 14, color: AppTheme.textSecondaryOf(context)),
                      const SizedBox(width: 4),
                      Text(
                        '$_backersCount backer${_backersCount == 1 ? '' : 's'}',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryOf(context),
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                if (_totalReservedSpots > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_seat, size: AppIconSize.sm, color: context.ticketAccent),
                      AppSpacing.hXs,
                      Text(
                        '$_totalReservedSpots spot${_totalReservedSpots == 1 ? '' : 's'} reserved',
                        style: TextStyle(
                            fontSize: 12,
                            color: context.ticketAccent,
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
                        color: _trustColor(context, event.organizerTrustLabel),
                      ),
                      AppSpacing.hSm,
                      Text(
                        'Organizer Trust: ',
                        style: TextStyle(fontSize: 11, color: AppTheme.accentColor),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: _trustColor(context, event.organizerTrustLabel).withValues(alpha: 0.15),
                          borderRadius: AppRadius.sm,
                        ),
                        child: Text(
                          '${event.organizerTrustLabel} (${(event.organizerTrustScore * 100).toInt()}%)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _trustColor(context, event.organizerTrustLabel),
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

          // Early bird discount banner
          ..._earlyBirdDiscounts.where((eb) {
            final isActive = eb['is_active'] == true;
            return isActive;
          }).map((eb) {
            final appliesTo = eb['applies_to'] ?? '';
            final discType = eb['discount_type'] ?? '';
            final value = eb['value'] ?? 0;
            final windowEnd = eb['window_end'] != null
                ? DateTime.tryParse(eb['window_end'])
                : null;
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
              padding: EdgeInsets.only(top: AppSpacing.sm),
              child: Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.scheduleAccent.withValues(alpha: 0.12),
                      context.scheduleAccent.withValues(alpha: 0.04),
                    ],
                  ),
                  borderRadius: AppRadius.sm,
                  border: Border.all(color: context.scheduleAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bolt_rounded, size: 18, color: context.scheduleAccent),
                    AppSpacing.hSm,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appliesTo == 'funding'
                                ? 'Early bird pledge — $discLabel tickets!'
                                : 'Early bird tickets — $discLabel!',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.scheduleAccent,
                            ),
                          ),
                          Text(
                            timeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.scheduleAccent.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

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
                      child: _refundProcessing
                          ? OutlinedButton.icon(
                              onPressed: null,
                              icon: const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              label: const Text('Refund Processing…',
                                  style: TextStyle(fontWeight: FontWeight.w700)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade400),
                                shape: RoundedRectangleBorder(
                                    borderRadius: AppRadius.md),
                              ),
                            )
                          : OutlinedButton.icon(
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
