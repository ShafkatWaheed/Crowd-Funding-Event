import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../repositories/base_repository.dart';
import '../../../repositories/sponsor_repository.dart';
import '../../../providers/config_provider.dart';
import '../../../repositories/payment_repository.dart';
import '../../../widgets/app_toast.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

class MyBidActions extends StatefulWidget {
  final Map<String, dynamic> bid;
  final int eventId;
  final int categoryId;
  final VoidCallback onDone;

  const MyBidActions({
    super.key,
    required this.bid,
    required this.eventId,
    required this.categoryId,
    required this.onDone,
  });

  @override
  State<MyBidActions> createState() => _MyBidActionsState();
}

class _MyBidActionsState extends State<MyBidActions> {
  bool _busy = false;

  String get _status => widget.bid['status'] ?? '';
  int get _bidId => widget.bid['id'];
  int get _amountCents => widget.bid['amount_cents'] ?? 0;
  String get _amountDisplay => '\$${(_amountCents / 100).toStringAsFixed(2)}';

  Future<void> _withdraw() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw Bid?'),
        content: Text('Withdraw your $_amountDisplay bid? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final repo = context.read<SponsorRepository>();
      await repo.withdrawBid(widget.eventId, widget.categoryId, _bidId);
      if (mounted) AppToast.success(context, 'Bid withdrawn');
      widget.onDone();
    } catch (e) {
      if (mounted) AppToast.error(context, ApiError.extractMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pay for Sponsorship'),
        content: Text('Confirm payment of $_amountDisplay for this sponsorship?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Pay Now'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    _showPaymentProcessing();
    try {
      final config = context.read<ConfigProvider>();
      final paymentRepo = context.read<PaymentRepository>();
      final repo = context.read<SponsorRepository>();

      // Stripe Payment Sheet flow when Stripe is enabled
      if (config.stripeEnabled) {
        final intent = await paymentRepo.createPaymentIntent(
          amountCents: widget.bid['amount_cents'] as int? ?? 0,
          description: 'Sponsorship payment for bid $_bidId',
        );
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: intent['client_secret'] as String,
            merchantDisplayName: 'CrowdFund Event',
          ),
        );
        await Stripe.instance.presentPaymentSheet();
      }

      await repo.payBid(widget.eventId, widget.categoryId, _bidId);
      _dismissPaymentProcessing();
      if (mounted) AppToast.success(context, 'Payment successful!');
      widget.onDone();
    } catch (e) {
      _dismissPaymentProcessing();
      if (mounted) AppToast.error(context, ApiError.extractMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
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

  Color get _statusColor => switch (_status) {
    'accepted' => AppTheme.successColor,
    'rejected' => AppTheme.errorColor,
    'paid' => AppTheme.accentColor,
    _ => AppTheme.warningColor,
  };

  String get _statusLabel => switch (_status) {
    'pending' => 'Under Review',
    'accepted' => 'Accepted',
    'paid' => 'Paid',
    'rejected' => 'Rejected',
    _ => _status,
  };

  Widget _circleAction({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color.withValues(alpha: 0.1),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, color: color, size: 22),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasChat = _status == 'pending' || _status == 'accepted' || _status == 'paid';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _statusColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_amountDisplay, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimaryOf(context))),
                const SizedBox(height: 2),
                Text(_statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor)),
              ],
            ),
          ),
          if (_busy)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            if (_status == 'pending') ...[
              _circleAction(
                icon: Icons.undo_rounded,
                color: AppTheme.errorColor,
                label: 'Withdraw',
                onTap: _withdraw,
              ),
              const SizedBox(width: 16),
            ],
            if (_status == 'accepted') ...[
              _circleAction(
                icon: Icons.payment_rounded,
                color: AppTheme.successColor,
                label: 'Pay',
                onTap: _pay,
              ),
              const SizedBox(width: 16),
            ],
            if (hasChat)
              _circleAction(
                icon: Icons.forum_rounded,
                color: AppTheme.accentColor,
                label: 'Message',
                onTap: () => context.push(
                  '/chat/bid/$_bidId?name=Organizer&writable=${_status != 'rejected'}',
                ),
              ),
          ],
        ],
      ),
    );
  }
}
