import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../utils/date_time_utils.dart';
import '../../../config/design_tokens.dart';
import '../../../models/event.dart';
import '../../../models/ticket.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/event_provider.dart';
import '../../../providers/ticket_provider.dart';
import '../../../providers/config_provider.dart';
import '../../../widgets/app_toast.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import '../receipts/ticket_receipt_screen.dart';
import '../receipts/purchase_group_receipt_screen.dart';

class TicketTiersSection extends StatefulWidget {
  final Event event;
  final int myTicketCount;
  final int myReservedSpots;
  final List<TicketSale> myEventTickets;
  final bool isOrganizer;
  final bool isAdmin;
  final bool isRegistered;
  final VoidCallback onPurchaseComplete;

  const TicketTiersSection({
    super.key,
    required this.event,
    required this.myTicketCount,
    required this.myReservedSpots,
    required this.myEventTickets,
    required this.isOrganizer,
    required this.isAdmin,
    required this.isRegistered,
    required this.onPurchaseComplete,
  });

  @override
  State<TicketTiersSection> createState() => _TicketTiersSectionState();
}

class _TicketTiersSectionState extends State<TicketTiersSection> {
  Future<(List<TicketTier>, Map<int, TicketPricePreview>)>
      _loadTiersWithPreviews() async {
    final ticketRepo = context.read<TicketProvider>();
    final tiers = await ticketRepo.getTicketTiers(widget.event.id);
    final previews = <int, TicketPricePreview>{};
    await Future.wait(tiers.map((t) async {
      if (t.priceCents > 0) {
        try {
          previews[t.id] =
              await ticketRepo.getTicketPrice(widget.event.id, t.id);
        } catch (_) {}
      }
    }));
    return (tiers, previews);
  }

  int? _popularTierId(List<TicketTier> tiers) {
    // Priority 1: manually featured
    for (final t in tiers) {
      if (t.isFeatured) return t.id;
    }
    // Priority 2: highest sell-through ≥ 20% among paid tiers with capacity
    TicketTier? best;
    double bestRate = 0.2; // minimum threshold
    for (final t in tiers) {
      if (t.priceCents == 0 || t.maxReservedSpots <= 0) continue;
      final rate = t.ticketsSold / t.maxReservedSpots;
      if (rate >= bestRate) {
        bestRate = rate;
        best = t;
      }
    }
    return best?.id;
  }

  Widget _buildTicketTiersSection() {
    return FutureBuilder<(List<TicketTier>, Map<int, TicketPricePreview>)>(
      future: _loadTiersWithPreviews(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 226,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Text('Could not load ticket tiers',
              style: TextStyle(color: AppTheme.textSecondaryOf(context)));
        }
        final (tiers, _) = snapshot.data!;
        if (tiers.isEmpty) {
          return Text('No tiers configured yet',
              style: TextStyle(color: AppTheme.textSecondaryOf(context)));
        }
        final isDark = AppTheme.isDark(context);
        final popularId = _popularTierId(tiers);
        return LayoutBuilder(
          builder: (context, constraints) {
            const cardWidth = 160.0;
            const sepWidth  = 12.0;
            final totalW = tiers.length * cardWidth +
                (tiers.length - 1) * sepWidth;
            final sidePad = ((constraints.maxWidth - totalW) / 2)
                .clamp(0.0, double.infinity);
            return SizedBox(
              height: 226,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: sidePad),
                itemCount: tiers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final t = tiers[i];
                  return _TierCard(
                    tier: t,
                    isFeatured: t.id == popularId,
                    isDark: isDark,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showBuyTicketDialog() async {
    final event = widget.event;
    try {
      final ticketRepo = context.read<TicketProvider>();
      final tiers = await ticketRepo.getTicketTiers(event.id);
      if (tiers.isEmpty) {
        if (mounted) {
          AppToast.error(context, 'No ticket tiers available for this event');
        }
        return;
      }
      if (!mounted) return;

      final previews = <int, TicketPricePreview>{};
      await Future.wait(tiers.map((t) async {
        if (t.priceCents > 0) {
          try {
            final preview = await ticketRepo.getTicketPrice(event.id, t.id);
            previews[t.id] = preview;
          } catch (e) { debugPrint(e.toString()); }
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
                  final name = t.name;
                  final baseCents = t.priceCents;
                  final tierId = t.id;
                  final maxSpots = t.maxReservedSpots;
                  final spotsLeft = t.spotsLeft;
                  final preview = previews[tierId];
                  final finalCents = preview?.finalPriceCents ?? baseCents;
                  final totalDiscount = preview?.totalDiscountCents ?? 0;
                  final isFree = finalCents == 0;
                  final basePrice = (baseCents / 100).toStringAsFixed(2);
                  final finalPrice = (finalCents / 100).toStringAsFixed(2);

                  return Card(
                    child: InkWell(
                      borderRadius: AppRadius.md,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _showInvoiceDialog(t, preview);
                      },
                      child: Padding(
                        padding: AppSpacing.paddingMd,
                        child: Row(
                          children: [
                            const Icon(Icons.confirmation_number, color: Colors.teal, size: AppIconSize.xl),
                            AppSpacing.hMd,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                  AppSpacing.vXs,
                                  if (isFree)
                                    Row(
                                      children: [
                                        if (baseCents > 0) ...[
                                          Text('\$$basePrice',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.textSecondaryOf(context),
                                                  decoration: TextDecoration.lineThrough)),
                                          AppSpacing.hSm,
                                        ],
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: AppRadius.sm,
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
                                                color: AppTheme.textSecondaryOf(context),
                                                decoration: TextDecoration.lineThrough)),
                                        AppSpacing.hSm,
                                        Text('\$$finalPrice',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.teal)),
                                        AppSpacing.hXs,
                                        Text('(-\$${(totalDiscount / 100).toStringAsFixed(2)})',
                                            style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
                                      ],
                                    )
                                  else
                                    Text('\$$basePrice', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  // Note: TicketTier model lacks 'description' field
                                  if (maxSpots > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          Icon(Icons.event_seat_rounded,
                                              size: 12,
                                              color: spotsLeft <= 0
                                                  ? AppTheme.errorColor
                                                  : AppTheme.textSecondaryOf(context)),
                                          const SizedBox(width: 4),
                                          Text(
                                            spotsLeft > 0
                                                ? '$spotsLeft of $maxSpots spots available'
                                                : 'Sold out',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: spotsLeft <= 0
                                                    ? AppTheme.errorColor
                                                    : AppTheme.textSecondaryOf(context)),
                                          ),
                                        ],
                                      ),
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

  Future<void> _showInvoiceDialog(
      TicketTier tier, TicketPricePreview? preview) async {
    final eventRepo = context.read<EventProvider>();
    final event = widget.event;
    final tierName = tier.name;
    final tierId = tier.id;
    final baseCents = tier.priceCents;
    final commonDisc = preview?.commonDiscountCents ?? 0;
    final selectiveDisc = preview?.selectiveDiscountCents ?? 0;
    final pledgeDisc = preview?.pledgeDiscountCents ?? 0;
    final eventDisc = preview?.eventDiscountCents ?? 0;
    final totalDiscountPerTicket = preview?.totalDiscountCents ?? 0;
    final finalCentsPerTicket = preview?.finalPriceCents ?? baseCents;
    final commissionPerTicket = preview?.commissionCents ?? 0;
    final maxSpots = tier.maxReservedSpots;
    final spotsLeft = tier.spotsLeft;

    int configMax = 10;
    try {
      final cfg = await eventRepo.getPublicConfig();
      final feEnabled = cfg.maxTicketsFrontendEnabled;
      if (feEnabled) {
        configMax = cfg.maxTicketsPerPurchase;
      } else {
        configMax = 999;
      }
    } catch (e) { debugPrint(e.toString()); }
    final maxQty = maxSpots > 0 ? spotsLeft.clamp(0, configMax) : configMax;

    if (!mounted) return;
    if (maxSpots > 0 && spotsLeft <= 0) {
      if (mounted) AppToast.error(context, 'This tier is sold out');
      return;
    }

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
          final spotsUsed = widget.myReservedSpots > 0 ? (widget.myReservedSpots < quantity ? widget.myReservedSpots : quantity) : 0;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.xl),
            contentPadding: EdgeInsets.zero,
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: AppSpacing.paddingXl,
                    decoration: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: AppRadius.topXl,
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.receipt_long_rounded, color: Colors.white, size: AppIconSize.xxl),
                        AppSpacing.vSm,
                        const Text('Invoice',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800)),
                        AppSpacing.vXs,
                        Text(event.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13)),
                      ],
                    ),
                  ),

                  Padding(
                    padding: AppSpacing.paddingXl,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.confirmation_number_rounded,
                                size: AppIconSize.sm, color: Colors.teal),
                            AppSpacing.hSm,
                            Expanded(
                              child: Text(tierName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 16)),
                            ),
                          ],
                        ),

                        AppSpacing.vMd,
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceOf(ctx),
                            borderRadius: AppRadius.md,
                            border: Border.all(color: AppTheme.dividerOf(ctx)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.people_rounded, size: AppIconSize.sm, color: Colors.teal[600]),
                              AppSpacing.hSm,
                              const Text('Quantity',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              const Spacer(),
                              GestureDetector(
                                onTap: quantity > 1
                                    ? () => setDialogState(() => quantity--)
                                    : null,
                                child: Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    color: quantity > 1 ? Colors.teal : AppTheme.dividerOf(ctx),
                                    borderRadius: AppRadius.sm,
                                  ),
                                  child: Icon(Icons.remove, size: AppIconSize.sm,
                                      color: quantity > 1 ? Colors.white : AppTheme.textSecondaryOf(ctx)),
                                ),
                              ),
                              SizedBox(
                                width: 44,
                                child: Text('$quantity',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 18, fontWeight: FontWeight.w800)),
                              ),
                              GestureDetector(
                                onTap: quantity < maxQty
                                    ? () => setDialogState(() => quantity++)
                                    : null,
                                child: Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    color: quantity < maxQty ? Colors.teal : AppTheme.dividerOf(ctx),
                                    borderRadius: AppRadius.sm,
                                  ),
                                  child: Icon(Icons.add, size: AppIconSize.sm,
                                      color: quantity < maxQty ? Colors.white : AppTheme.textSecondaryOf(ctx)),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (maxSpots > 0) ...[
                          const SizedBox(height: 6),
                          Text(
                            '$spotsLeft spot${spotsLeft == 1 ? '' : 's'} available',
                            style: TextStyle(
                              fontSize: 11,
                              color: spotsLeft <= 3 ? AppTheme.warningColor : AppTheme.textSecondaryOf(ctx),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],

                        if (widget.myTicketCount > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.06),
                              borderRadius: AppRadius.sm,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded, size: 15, color: Colors.teal[600]),
                                AppSpacing.hSm,
                                Expanded(
                                  child: Text(
                                    'You already have ${widget.myTicketCount} ticket${widget.myTicketCount == 1 ? '' : 's'} for this event',
                                    style: TextStyle(fontSize: 12, color: Colors.teal[700], fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (widget.myReservedSpots > 0) ...[
                          AppSpacing.vSm,
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: ctx.sponsorSurface,
                              borderRadius: AppRadius.sm,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.event_seat_rounded, size: AppIconSize.sm, color: ctx.sponsorAccent),
                                AppSpacing.hSm,
                                Expanded(
                                  child: Text(
                                    widget.event.linkFundingToTiers
                                        ? 'Using $spotsUsed of your reserved spot${spotsUsed == 1 ? '' : 's'} for this tier from pledging'
                                        : 'Using $spotsUsed of your ${widget.myReservedSpots} reserved spot${widget.myReservedSpots == 1 ? '' : 's'} from pledging',
                                    style: TextStyle(fontSize: 12, color: ctx.sponsorAccent, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        AppSpacing.vLg,

                        Container(
                          width: double.infinity,
                          padding: AppSpacing.paddingLg,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceOf(ctx),
                            borderRadius: AppRadius.lg,
                          ),
                          child: Column(
                            children: [
                              _invoiceRow(ctx, 'Ticket Price', fmtCents(baseCents)),
                              if (commonDisc > 0) ...[
                                AppSpacing.vSm,
                                _invoiceRow(ctx, 'Common Discount',
                                    '- ${fmtCents(commonDisc)}',
                                    valueColor: AppTheme.successColor),
                              ],
                              if (selectiveDisc > 0) ...[
                                AppSpacing.vSm,
                                _invoiceRow(ctx, 'Selective Discount',
                                    '- ${fmtCents(selectiveDisc)}',
                                    valueColor: AppTheme.successColor),
                              ],
                              if (pledgeDisc > 0) ...[
                                AppSpacing.vSm,
                                _invoiceRow(ctx, 'Pledge Discount',
                                    '- ${fmtCents(pledgeDisc)}',
                                    valueColor: AppTheme.successColor),
                              ],
                              if (eventDisc > 0) ...[
                                AppSpacing.vSm,
                                _invoiceRow(ctx, 'Event Discount',
                                    '- ${fmtCents(eventDisc)}',
                                    valueColor: AppTheme.successColor),
                              ],
                              if (commissionPerTicket > 0) ...[
                                AppSpacing.vSm,
                                _invoiceRow(ctx, 'Platform Fee',
                                    fmtCents(commissionPerTicket),
                                    valueColor: AppTheme.textSecondaryOf(ctx)),
                              ],
                              if (quantity > 1) ...[
                                AppSpacing.vSm,
                                Container(height: 1, color: AppTheme.dividerOf(ctx)),
                                AppSpacing.vSm,
                                _invoiceRow(ctx, 'Per Ticket',
                                    isFree ? 'FREE' : fmtCents(finalCentsPerTicket)),
                                AppSpacing.vXs,
                                _invoiceRow(ctx, 'x Quantity', '$quantity'),
                              ],
                              AppSpacing.vMd,
                              Container(height: 1, color: AppTheme.dividerOf(ctx)),
                              AppSpacing.vMd,
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
                                AppSpacing.vSm,
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                                      decoration: BoxDecoration(
                                        color: AppTheme.successColor
                                            .withValues(alpha: 0.1),
                                        borderRadius: AppRadius.sm,
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
                                AppSpacing.vSm,
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Includes ${fmtCents(totalCommission)} platform fee',
                                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(ctx)),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        AppSpacing.vXl,

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
                                  borderRadius: AppRadius.lg),
                              elevation: 0,
                            ),
                          ),
                        ),
                        AppSpacing.vSm,
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
      _showBuyTicketDialog();
    }
  }

  Widget _invoiceRow(BuildContext ctx, String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(ctx))),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppTheme.textPrimaryOf(ctx))),
      ],
    );
  }

  Future<void> _purchaseTickets(int eventId, int tierId, int quantity) async {
    _showPaymentProcessing();
    try {
      final config = context.read<ConfigProvider>();
      final ticketRepo = context.read<TicketProvider>();

      // Stripe Payment Sheet flow when Stripe is enabled
      if (config.stripeEnabled) {
        final intent = await config.createPaymentIntent(
          amountCents: 0, // actual amount computed by backend
          description: 'Ticket purchase for event $eventId',
        );
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: intent.clientSecret,
            merchantDisplayName: 'CrowdFund Event',
          ),
        );
        await Stripe.instance.presentPaymentSheet();
      }

      final salesList = await ticketRepo.purchaseTickets(eventId, tierId: tierId, quantity: quantity);
      _dismissPaymentProcessing();
      if (salesList.isEmpty) return;

      final first = salesList[0];
      final status = first.status;
      final purchaseGroupId = first.purchaseGroupId;

      if (mounted) {
        if (status == 'waitlisted') {
          AppToast.info(context,
              quantity > 1
                  ? 'Event is at capacity — your $quantity tickets are waiting for organizer approval.'
                  : 'Event is at capacity — your ticket is waiting for organizer approval.');
        } else {
          final totalPaid = salesList.fold<int>(0, (sum, s) => sum + s.amountPaidCents);
          final isFree = totalPaid == 0;
          final ticketWord = quantity > 1 ? '$quantity tickets' : 'ticket';
          final priceStr = isFree
              ? 'Free $ticketWord'
              : 'Paid \$${(totalPaid / 100).toStringAsFixed(2)} for $ticketWord';
          AppToast.success(context, priceStr);
          widget.onPurchaseComplete();
          context.read<EventProvider>().loadEvent(eventId);
          if (mounted) {
            final event = context.read<EventProvider>().selectedEvent;
            if (quantity > 1 && purchaseGroupId != null) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PurchaseGroupReceiptScreen(
                    eventId: eventId,
                    purchaseGroupId: purchaseGroupId,
                    showBuyAgain: true,
                    onBuyAgain: event != null ? () => _showBuyTicketDialog() : null,
                  ),
                ),
              );
            } else {
              final saleId = first.id;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TicketReceiptScreen(
                    eventId: eventId,
                    saleId: saleId,
                    showBuyAgain: true,
                    onBuyAgain: event != null ? () => _showBuyTicketDialog() : null,
                  ),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      _dismissPaymentProcessing();
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Purchase failed');
      }
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
                Text('Processing payment...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(context))),
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

  Widget _buildYourTicketsSection() {
    final scannedCount = widget.myEventTickets.where((t) => t.isScanned).length;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.04),
        borderRadius: AppRadius.lg,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
            child: Row(
              children: [
                const Icon(Icons.confirmation_number_rounded, size: AppIconSize.sm, color: Colors.teal),
                AppSpacing.hSm,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Tickets (${widget.myTicketCount})',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.teal),
                      ),
                      if (scannedCount > 0)
                        Text(
                          '$scannedCount of ${widget.myTicketCount} scanned',
                          style: TextStyle(fontSize: 11, color: Colors.teal[400]),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/my-tickets?eventId=${widget.event.id}'),
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
          ...widget.myEventTickets.take(3).map((t) {
            final ticketCode = t.ticketCode;
            final receiptNumber = t.receiptNumber ?? '';
            final status = t.status;
            final isScanned = t.isScanned;
            final saleId = t.id;
            final createdAt = AppDateFormat.isoShort(t.createdAt.toIso8601String());
            return GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TicketReceiptScreen(
                    eventId: widget.event.id,
                    saleId: saleId,
                  ),
                ),
              ),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 3),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppTheme.cardOf(context),
                  borderRadius: AppRadius.sm,
                  border: isScanned
                      ? Border.all(color: AppTheme.successColor.withValues(alpha: 0.25))
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      isScanned ? Icons.check_circle_rounded : Icons.qr_code_rounded,
                      size: AppIconSize.sm,
                      color: isScanned ? AppTheme.successColor : AppTheme.textSecondaryOf(context),
                    ),
                    AppSpacing.hSm,
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
                              style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryOf(context))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
                      decoration: BoxDecoration(
                        color: status == 'purchased'
                            ? AppTheme.successColor.withValues(alpha: 0.1)
                            : AppTheme.warningColor.withValues(alpha: 0.1),
                        borderRadius: AppRadius.sm,
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
                    AppSpacing.hXs,
                    Icon(Icons.chevron_right_rounded, size: AppIconSize.sm, color: AppTheme.textSecondaryOf(context)),
                  ],
                ),
              ),
            );
          }),
          if (widget.myTicketCount > 3)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm, top: 2),
              child: Text(
                '+${widget.myTicketCount - 3} more ticket${widget.myTicketCount - 3 == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context), fontWeight: FontWeight.w500),
              ),
            ),
          AppSpacing.vXs,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final event = widget.event;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (event.ticketStrategyId != null &&
            (user == null || (!user.isOrganizer && !user.isAdmin))) ...[
          _buildTicketTiersSection(),
        ],

        if (user != null && user.isCustomer &&
            (event.status == EventStatus.selling_tickets ||
                event.status == EventStatus.live)) ...[
          if (widget.myTicketCount > 0) ...[
            _buildYourTicketsSection(),
            AppSpacing.vSm,
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                if (!widget.isRegistered) {
                  AppToast.info(context, 'Please register for this event first to buy tickets.');
                  return;
                }
                _showBuyTicketDialog();
              },
              icon: const Icon(Icons.confirmation_number),
              label: const Text('Buy Tickets',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.md),
                elevation: 0,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Premium horizontal tier card ───────────────────────────────────────────

class _TierCard extends StatelessWidget {
  final TicketTier tier;
  final bool isFeatured;
  final bool isDark;

  const _TierCard({
    required this.tier,
    required this.isFeatured,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final spotsLeft = tier.spotsLeft;
    final maxSpots = tier.maxReservedSpots;
    final hasCapacity = maxSpots > 0;
    final isSoldOut = hasCapacity && spotsLeft <= 0;
    final isLow = hasCapacity && !isSoldOut && spotsLeft <= 5;

    // Availability label
    String availText;
    Color availColor;
    String availIcon;
    if (!hasCapacity) {
      availText = 'Open availability';
      availColor = AppTheme.successColor;
      availIcon = '✓';
    } else if (isSoldOut) {
      availText = 'Sold out';
      availColor = AppTheme.errorColor;
      availIcon = '✕';
    } else if (isLow) {
      availText = '$spotsLeft left';
      availColor = AppTheme.warningColor;
      availIcon = '⚠';
    } else {
      availText = '$spotsLeft left';
      availColor = AppTheme.successColor;
      availIcon = '✓';
    }

    // Card visual properties
    final Color nameFg = isFeatured
        ? Colors.white
        : AppTheme.textPrimaryOf(context);
    final Color mutedFg = isFeatured
        ? Colors.white.withValues(alpha: 0.65)
        : AppTheme.textSecondaryOf(context);

    final BoxDecoration cardDecoration = isFeatured
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment(0.6, -0.8),
              end: Alignment(-0.6, 0.8),
              colors: [Color(0xFF0D1B3E), Color(0xFF1A0A2E)],
            ),
            border: Border.all(
              color: AppTheme.accentColor.withValues(alpha: 0.40),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentColor.withValues(alpha: 0.20),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          )
        : BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF6F6F6),
            border: Border.all(
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E2E2),
              width: 1,
            ),
          );

    return Stack(
      children: [
        Container(
          width: 160,
          padding: const EdgeInsets.all(16),
          decoration: cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isFeatured) const SizedBox(height: 18),
              Text(
                tier.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: nameFg,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (tier.description != null && tier.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  tier.description!,
                  style: TextStyle(
                    fontSize: 11,
                    color: mutedFg,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ] else
                const SizedBox(height: 10),
              const Spacer(),
              Text(
                tier.isFree ? 'FREE' : tier.priceFormatted,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: tier.isFree
                      ? AppTheme.successColor
                      : nameFg,
                ),
              ),
              Text(
                'per person',
                style: TextStyle(fontSize: 10, color: mutedFg),
              ),
              const SizedBox(height: 6),
              Text(
                '$availIcon $availText',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: availColor,
                ),
              ),
            ],
          ),
        ),
        if (isFeatured)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.accentColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'POPULAR',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
