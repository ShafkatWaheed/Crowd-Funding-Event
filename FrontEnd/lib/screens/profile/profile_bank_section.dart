import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  final _institutionCtrl = TextEditingController();
  final _transitCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _accountHolderCtrl = TextEditingController();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _institutionCtrl.dispose();
    _transitCtrl.dispose();
    _accountNumberCtrl.dispose();
    _accountHolderCtrl.dispose();
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
    if (_institutionCtrl.text.trim().length != 3) {
      AppToast.error(context, 'Institution number must be 3 digits');
      return;
    }
    if (_transitCtrl.text.trim().length != 5) {
      AppToast.error(context, 'Transit number must be 5 digits');
      return;
    }
    if (_accountNumberCtrl.text.trim().length < 7) {
      AppToast.error(context, 'Account number must be 7-12 digits');
      return;
    }
    if (_accountHolderCtrl.text.trim().isEmpty) {
      AppToast.error(context, 'Account holder is required');
      return;
    }
    try {
      await context.read<ApiService>().updateBankAccount({
        'institution_number': _institutionCtrl.text.trim(),
        'transit_number': _transitCtrl.text.trim(),
        'account_number': _accountNumberCtrl.text.trim(),
        'account_holder': _accountHolderCtrl.text.trim(),
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
      _institutionCtrl.clear();
      _transitCtrl.clear();
      _accountNumberCtrl.clear();
      _accountHolderCtrl.clear();
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
              if (_bankData != null &&
                  _bankData!['has_bank_account'] == true &&
                  !_editing) ...[
                _bankDetailRow(
                    context, 'Institution', _bankData!['institution_number'] ?? '—'),
                const SizedBox(height: 8),
                _bankDetailRow(
                    context, 'Transit', _bankData!['transit_number'] ?? '—'),
                const SizedBox(height: 8),
                _bankDetailRow(
                    context, 'Account', '••••${_bankData!['account_last_four'] ?? ''}'),
                const SizedBox(height: 8),
                _bankDetailRow(
                    context, 'Holder', _bankData!['account_holder_masked'] ?? ''),
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
                          : _bankData!['verification_status'] == 'rejected'
                              ? 'Rejected'
                              : 'Pending verification',
                      style: TextStyle(
                        fontSize: 13,
                        color: _bankData!['verified'] == true
                            ? AppTheme.successColor
                            : _bankData!['verification_status'] == 'rejected'
                                ? AppTheme.errorColor
                                : AppTheme.warningColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (_bankData!['rejection_reason'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _bankData!['rejection_reason'],
                    style: TextStyle(fontSize: 12, color: AppTheme.errorColor),
                  ),
                ],
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
                Text(
                  'Canadian bank account details',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                ),
                AppSpacing.vMd,
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _institutionCtrl,
                        decoration: profileFieldDecoration(context,
                            label: 'Institution # (3 digits)',
                            icon: Icons.account_balance),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: _transitCtrl,
                        decoration: profileFieldDecoration(context,
                            label: 'Transit # (5 digits)',
                            icon: Icons.alt_route),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(5),
                        ],
                      ),
                    ),
                  ],
                ),
                AppSpacing.vLg,
                TextFormField(
                  controller: _accountNumberCtrl,
                  decoration: profileFieldDecoration(context,
                      label: 'Account Number (7-12 digits)',
                      icon: Icons.numbers),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(12),
                  ],
                ),
                AppSpacing.vLg,
                TextFormField(
                  controller: _accountHolderCtrl,
                  decoration: profileFieldDecoration(context,
                      label: 'Account Holder Name',
                      icon: Icons.person_outline),
                ),
                AppSpacing.vLg,
                Row(
                  children: [
                    if (_bankData != null && _bankData!['has_bank_account'] == true)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _editing = false),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                    if (_bankData != null && _bankData!['has_bank_account'] == true)
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
