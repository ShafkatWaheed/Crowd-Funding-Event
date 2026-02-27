import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../config/design_tokens.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';
import 'profile_section_card.dart';

class ProfileBankSection extends StatefulWidget {
  const ProfileBankSection({super.key});

  @override
  State<ProfileBankSection> createState() => _ProfileBankSectionState();
}

class _ProfileBankSectionState extends State<ProfileBankSection> {
  bool _loading = false;
  Map<String, dynamic>? _bankData;

  final _bankNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _routingNumberCtrl = TextEditingController();
  final _accountHolderCtrl = TextEditingController();
  final _swiftCodeCtrl = TextEditingController();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _routingNumberCtrl.dispose();
    _accountHolderCtrl.dispose();
    _swiftCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<ApiService>().getBankAccount();
      if (mounted) {
        setState(() {
          _bankData = data;
          _editing = false;
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
      await context.read<ApiService>().updateBankAccount({
        'bank_name': _bankNameCtrl.text.trim(),
        'account_number': _accountNumberCtrl.text.trim(),
        'routing_number': _routingNumberCtrl.text.trim(),
        'account_holder': _accountHolderCtrl.text.trim(),
        'swift_code': _swiftCodeCtrl.text.trim().isEmpty
            ? null
            : _swiftCodeCtrl.text.trim(),
      });
      await _load();
      if (mounted) AppToast.success(context, 'Bank account updated');
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e,
            fallback: 'Failed to update bank account');
      }
    }
  }

  void _startEditing() {
    setState(() {
      _editing = true;
      _bankNameCtrl.clear();
      _accountNumberCtrl.clear();
      _routingNumberCtrl.clear();
      _accountHolderCtrl.clear();
      _swiftCodeCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      title: 'Bank Account',
      icon: Icons.account_balance_rounded,
      delay: 300,
      children: _loading
          ? [const Center(child: CircularProgressIndicator())]
          : [
              if (_bankData != null && !_editing) ...[
                _bankDetailRow(context, 'Bank',
                    _bankData!['bank_name_masked'] ?? 'Not set'),
                const SizedBox(height: 8),
                _bankDetailRow(context, 'Account',
                    _bankData!['account_number_masked'] ?? '••••'),
                const SizedBox(height: 8),
                _bankDetailRow(context, 'Routing',
                    _bankData!['routing_number_masked'] ?? '••••'),
                const SizedBox(height: 8),
                _bankDetailRow(context, 'Holder',
                    _bankData!['account_holder_masked'] ?? ''),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      _bankData!['verified'] == true
                          ? Icons.verified
                          : Icons.pending,
                      size: 16,
                      color: _bankData!['verified'] == true
                          ? AppTheme.successColor
                          : AppTheme.warningColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _bankData!['verified'] == true
                          ? 'Verified'
                          : 'Pending verification',
                      style: TextStyle(
                        fontSize: 13,
                        color: _bankData!['verified'] == true
                            ? AppTheme.successColor
                            : AppTheme.warningColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                AppSpacing.vLg,
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _startEditing,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit Bank Details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentColor,
                      side: BorderSide(color: AppTheme.accentColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ] else ...[
                TextFormField(
                  controller: _bankNameCtrl,
                  decoration: profileFieldDecoration(context,
                      label: 'Bank Name', icon: Icons.account_balance),
                ),
                AppSpacing.vLg,
                TextFormField(
                  controller: _accountNumberCtrl,
                  decoration: profileFieldDecoration(context,
                      label: 'Account Number', icon: Icons.numbers),
                ),
                AppSpacing.vLg,
                TextFormField(
                  controller: _routingNumberCtrl,
                  decoration: profileFieldDecoration(context,
                      label: 'Routing Number', icon: Icons.alt_route),
                ),
                AppSpacing.vLg,
                TextFormField(
                  controller: _accountHolderCtrl,
                  decoration: profileFieldDecoration(context,
                      label: 'Account Holder',
                      icon: Icons.person_outline),
                ),
                AppSpacing.vLg,
                TextFormField(
                  controller: _swiftCodeCtrl,
                  decoration: profileFieldDecoration(context,
                      label: 'SWIFT Code (optional)',
                      icon: Icons.language),
                ),
                AppSpacing.vLg,
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          if (_bankData != null) {
                            setState(() => _editing = false);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: const Text('Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
    );
  }
}

Widget _bankDetailRow(BuildContext context, String label, String value) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label,
          style: TextStyle(
              fontSize: 13, color: AppTheme.textSecondaryOf(context))),
      Text(value,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryOf(context))),
    ],
  );
}
