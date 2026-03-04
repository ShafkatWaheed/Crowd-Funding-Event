import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../config/design_tokens.dart';
import '../../models/user.dart';
import '../../providers/user_provider.dart';
import '../../widgets/app_toast.dart';
import 'profile_section_card.dart';

class ProfilePaymentSection extends StatefulWidget {
  const ProfilePaymentSection({super.key});

  @override
  State<ProfilePaymentSection> createState() => _ProfilePaymentSectionState();
}

class _ProfilePaymentSectionState extends State<ProfilePaymentSection> {
  bool _loading = false;
  PaymentInfo? _paymentInfo;
  final _cardHolderCtrl = TextEditingController();
  final _billingAddressCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cardHolderCtrl.dispose();
    _billingAddressCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<UserProvider>().getPaymentInfo();
      if (mounted) {
        setState(() {
          _paymentInfo = data;
          _cardHolderCtrl.text = data.cardHolderName ?? '';
          _billingAddressCtrl.text = data.billingAddress ?? '';
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    try {
      await context.read<UserProvider>().updatePaymentInfo({
        'card_holder_name': _cardHolderCtrl.text.trim(),
        'billing_address': _billingAddressCtrl.text.trim(),
      });
      await _load();
      if (mounted) AppToast.success(context, 'Payment info updated');
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e,
            fallback: 'Failed to update payment info');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      title: 'Payment Information',
      icon: Icons.credit_card_rounded,
      delay: 250,
      children: _loading
          ? [const Center(child: CircularProgressIndicator())]
          : [
              if (_paymentInfo != null &&
                  (_paymentInfo!.cardLastFour ?? '')
                      .isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.credit_card,
                          color: AppTheme.accentColor, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${(_paymentInfo!.cardBrand ?? 'Card').toUpperCase()} •••• ${_paymentInfo!.cardLastFour}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimaryOf(context)),
                            ),
                            if ((_paymentInfo!.cardHolderName ?? '')
                                .isNotEmpty)
                              Text(
                                _paymentInfo!.cardHolderName!,
                                style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        AppTheme.textSecondaryOf(context)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              TextFormField(
                controller: _cardHolderCtrl,
                decoration: profileFieldDecoration(
                  context,
                  label: 'Cardholder Name',
                  icon: Icons.person_outline_rounded,
                  hint: 'Name on card',
                ),
              ),
              AppSpacing.vLg,
              TextFormField(
                controller: _billingAddressCtrl,
                decoration: profileFieldDecoration(
                  context,
                  label: 'Billing Address',
                  icon: Icons.location_on_outlined,
                ),
              ),
              AppSpacing.vLg,
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save Payment Info'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentColor,
                    side: BorderSide(color: AppTheme.accentColor),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
    );
  }
}
