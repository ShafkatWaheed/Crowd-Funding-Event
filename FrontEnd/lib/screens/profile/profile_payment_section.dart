import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../config/design_tokens.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';
import 'profile_section_card.dart';

class ProfilePaymentSection extends StatefulWidget {
  const ProfilePaymentSection({super.key});

  @override
  State<ProfilePaymentSection> createState() => _ProfilePaymentSectionState();
}

class _ProfilePaymentSectionState extends State<ProfilePaymentSection> {
  bool _loading = false;
  Map<String, dynamic>? _paymentInfo;
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
      final data = await context.read<ApiService>().getPaymentInfo();
      if (mounted) {
        setState(() {
          _paymentInfo = data;
          _cardHolderCtrl.text = data['card_holder_name'] ?? '';
          _billingAddressCtrl.text = data['billing_address'] ?? '';
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
      await context.read<ApiService>().updatePaymentInfo({
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
                  (_paymentInfo!['card_last_four'] ?? '')
                      .toString()
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
                              '${(_paymentInfo!['card_brand'] ?? 'Card').toString().toUpperCase()} •••• ${_paymentInfo!['card_last_four']}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimaryOf(context)),
                            ),
                            if ((_paymentInfo!['card_holder_name'] ?? '')
                                .toString()
                                .isNotEmpty)
                              Text(
                                _paymentInfo!['card_holder_name'],
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
