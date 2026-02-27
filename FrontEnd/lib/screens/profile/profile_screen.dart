import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../utils/date_time_utils.dart';
import '../../config/design_tokens.dart';
import '../../widgets/press_feedback.dart';
import '../../widgets/shimmer_loaders.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/mapbox_geocoding_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/kyc_section.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _birthdayCtrl;
  late TextEditingController _experienceCtrl;

  late TextEditingController _companyNameCtrl;
  late TextEditingController _contactNameCtrl;
  late TextEditingController _professionCtrl;
  late TextEditingController _logoUrlCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _websiteUrlCtrl;

  DateTime? _selectedBirthday;
  bool _saving = false;
  bool _loadingSponsorProfile = false;
  bool _hasSponsorProfile = false;

  // Payment info
  bool _paymentInfoLoading = false;
  Map<String, dynamic>? _paymentInfo;
  final _cardHolderCtrl = TextEditingController();
  final _billingAddressCtrl = TextEditingController();

  // Bank account (organizer)
  bool _bankLoading = false;
  Map<String, dynamic>? _bankData;
  final _bankNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _routingNumberCtrl = TextEditingController();
  final _accountHolderCtrl = TextEditingController();
  final _swiftCodeCtrl = TextEditingController();
  bool _bankEditing = false;

  List<GeocodingResult> _addressSuggestions = [];
  bool _showAddressSuggestions = false;
  bool _geocoding = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameCtrl = TextEditingController(text: user?.displayName ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    _addressCtrl = TextEditingController(text: user?.address ?? '');
    _experienceCtrl = TextEditingController(
        text: user?.yearsOfExperience?.toString() ?? '');

    _companyNameCtrl = TextEditingController();
    _contactNameCtrl = TextEditingController();
    _professionCtrl = TextEditingController();
    _logoUrlCtrl = TextEditingController();
    _descriptionCtrl = TextEditingController();
    _websiteUrlCtrl = TextEditingController();

    if (user?.birthday != null) {
      try {
        _selectedBirthday = DateTime.parse(user!.birthday!);
        _birthdayCtrl = TextEditingController(
            text: AppDateFormat.dateOnly(_selectedBirthday!));
      } catch (_) {
        _birthdayCtrl = TextEditingController();
      }
    } else {
      _birthdayCtrl = TextEditingController();
    }

    if (user != null && user.isSponsor) {
      _loadSponsorProfile();
    }
    _loadPaymentInfo();
    if (user != null && user.isOrganizer) {
      _loadBankAccount();
    }
  }

  Future<void> _refreshProfile() async {
    await context.read<AuthProvider>().refreshUser();
    if (!mounted) return;
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      setState(() {
        _nameCtrl.text = user.displayName ?? '';
        _phoneCtrl.text = user.phone ?? '';
        _addressCtrl.text = user.address ?? '';
        _experienceCtrl.text = user.yearsOfExperience?.toString() ?? '';
        if (user.birthday != null) {
          try {
            _selectedBirthday = DateTime.parse(user.birthday!);
            _birthdayCtrl.text =
                AppDateFormat.dateOnly(_selectedBirthday!);
          } catch (_) {}
        }
      });
    }
    if (user != null && user.isSponsor) {
      await _loadSponsorProfile();
    }
  }

  Future<void> _loadSponsorProfile() async {
    setState(() => _loadingSponsorProfile = true);
    try {
      final api = context.read<ApiService>();
      final data = await api.getSponsorProfile();
      if (mounted) {
        setState(() {
          _hasSponsorProfile = true;
          _companyNameCtrl.text = data['company_name'] ?? '';
          _contactNameCtrl.text = data['contact_name'] ?? '';
          _professionCtrl.text = data['profession'] ?? '';
          _logoUrlCtrl.text = data['logo_url'] ?? '';
          _descriptionCtrl.text = data['description'] ?? '';
          _websiteUrlCtrl.text = data['website_url'] ?? '';
        });
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _loadingSponsorProfile = false);
    }
  }

  Future<void> _loadPaymentInfo() async {
    setState(() => _paymentInfoLoading = true);
    try {
      final api = context.read<ApiService>();
      final data = await api.getPaymentInfo();
      if (mounted) {
        setState(() {
          _paymentInfo = data;
          _cardHolderCtrl.text = data['card_holder_name'] ?? '';
          _billingAddressCtrl.text = data['billing_address'] ?? '';
        });
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _paymentInfoLoading = false);
    }
  }

  Future<void> _savePaymentInfo() async {
    try {
      final api = context.read<ApiService>();
      await api.updatePaymentInfo({
        'card_holder_name': _cardHolderCtrl.text.trim(),
        'billing_address': _billingAddressCtrl.text.trim(),
      });
      await _loadPaymentInfo();
      if (mounted) AppToast.success(context, 'Payment info updated');
    } catch (e) {
      if (mounted) AppToast.fromError(context, e, fallback: 'Failed to update payment info');
    }
  }

  Future<void> _loadBankAccount() async {
    setState(() => _bankLoading = true);
    try {
      final api = context.read<ApiService>();
      final data = await api.getBankAccount();
      if (mounted) {
        setState(() {
          _bankData = data;
          _bankEditing = false;
        });
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _bankLoading = false);
    }
  }

  Future<void> _saveBankAccount() async {
    try {
      final api = context.read<ApiService>();
      await api.updateBankAccount({
        'bank_name': _bankNameCtrl.text.trim(),
        'account_number': _accountNumberCtrl.text.trim(),
        'routing_number': _routingNumberCtrl.text.trim(),
        'account_holder': _accountHolderCtrl.text.trim(),
        'swift_code': _swiftCodeCtrl.text.trim().isEmpty ? null : _swiftCodeCtrl.text.trim(),
      });
      await _loadBankAccount();
      if (mounted) AppToast.success(context, 'Bank account updated');
    } catch (e) {
      if (mounted) AppToast.fromError(context, e, fallback: 'Failed to update bank account');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _birthdayCtrl.dispose();
    _experienceCtrl.dispose();
    _companyNameCtrl.dispose();
    _contactNameCtrl.dispose();
    _professionCtrl.dispose();
    _logoUrlCtrl.dispose();
    _descriptionCtrl.dispose();
    _websiteUrlCtrl.dispose();
    _cardHolderCtrl.dispose();
    _billingAddressCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _routingNumberCtrl.dispose();
    _accountHolderCtrl.dispose();
    _swiftCodeCtrl.dispose();
    super.dispose();
  }

  void _onAddressChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _addressSuggestions = [];
        _showAddressSuggestions = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _geocoding = true);
      final results = await MapboxGeocodingService.search(query);
      if (mounted) {
        setState(() {
          _addressSuggestions = results;
          _showAddressSuggestions = results.isNotEmpty;
          _geocoding = false;
        });
      }
    });
  }

  void _selectAddressSuggestion(GeocodingResult result) {
    setState(() {
      _addressCtrl.text = result.fullAddress;
      _showAddressSuggestions = false;
      _addressSuggestions = [];
    });
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime(now.year - 20),
      firstDate: DateTime(1920),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedBirthday = picked;
        _birthdayCtrl.text = AppDateFormat.dateOnly(picked);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final api = context.read<ApiService>();
      final user = context.read<AuthProvider>().user!;

      final data = <String, dynamic>{};
      if (_nameCtrl.text.trim() != (user.displayName ?? '')) {
        data['display_name'] = _nameCtrl.text.trim();
      }
      if (_phoneCtrl.text.trim() != (user.phone ?? '')) {
        data['phone'] = _phoneCtrl.text.trim();
      }
      if (_addressCtrl.text.trim() != (user.address ?? '')) {
        data['address'] = _addressCtrl.text.trim();
      }
      if (_selectedBirthday != null) {
        final bdStr = AppDateFormat.apiDate(_selectedBirthday!);
        if (bdStr != (user.birthday ?? '')) {
          data['birthday'] = bdStr;
        }
      }
      if ((user.isOrganizer || user.isSponsor) &&
          _experienceCtrl.text.trim().isNotEmpty) {
        final exp = int.tryParse(_experienceCtrl.text.trim());
        if (exp != null && exp != user.yearsOfExperience) {
          data['years_of_experience'] = exp;
        }
      }

      bool userUpdated = false;
      if (data.isNotEmpty) {
        await api.updateMe(data);
        userUpdated = true;
      }

      bool sponsorUpdated = false;
      if (user.isSponsor) {
        final spData = <String, dynamic>{
          'company_name': _companyNameCtrl.text.trim(),
          'contact_name': _contactNameCtrl.text.trim(),
          'profession': _professionCtrl.text.trim(),
          'logo_url': _logoUrlCtrl.text.trim().isEmpty
              ? null
              : _logoUrlCtrl.text.trim(),
          'description': _descriptionCtrl.text.trim().isEmpty
              ? null
              : _descriptionCtrl.text.trim(),
          'website_url': _websiteUrlCtrl.text.trim().isEmpty
              ? null
              : _websiteUrlCtrl.text.trim(),
        };

        if (_hasSponsorProfile) {
          await api.updateSponsorProfile(spData);
        } else {
          await api.createSponsorProfile(spData);
          _hasSponsorProfile = true;
        }
        sponsorUpdated = true;
      }

      if (!userUpdated && !sponsorUpdated) {
        if (mounted) AppToast.info(context, 'No changes to save');
        return;
      }

      await context.read<AuthProvider>().refreshUser();

      if (mounted) AppToast.success(context, 'Profile updated successfully');
    } catch (e) {
      if (mounted) AppToast.fromError(context, e, fallback: 'Failed to update profile');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final currentPwCtrl = TextEditingController();
    final newPwCtrl = TextEditingController();
    final confirmPwCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool loading = false;
    final pwFormKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardOf(ctx),
          title: Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: AppTheme.accentColor),
              AppSpacing.hSm,
              Text('Change Password',
                  style: TextStyle(color: AppTheme.textPrimaryOf(ctx))),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Form(
              key: pwFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentPwCtrl,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      filled: true,
                      fillColor: AppTheme.inputFillOf(ctx),
                      border: OutlineInputBorder(
                          borderRadius: AppRadius.md,
                          borderSide: BorderSide.none),
                      suffixIcon: IconButton(
                        icon: Icon(obscureCurrent
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () => setDialogState(
                            () => obscureCurrent = !obscureCurrent),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  AppSpacing.vLg,
                  TextFormField(
                    controller: newPwCtrl,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      filled: true,
                      fillColor: AppTheme.inputFillOf(ctx),
                      border: OutlineInputBorder(
                          borderRadius: AppRadius.md,
                          borderSide: BorderSide.none),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () =>
                            setDialogState(() => obscureNew = !obscureNew),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length < 6) return 'At least 6 characters';
                      return null;
                    },
                  ),
                  AppSpacing.vLg,
                  TextFormField(
                    controller: confirmPwCtrl,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      filled: true,
                      fillColor: AppTheme.inputFillOf(ctx),
                      border: OutlineInputBorder(
                          borderRadius: AppRadius.md,
                          borderSide: BorderSide.none),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () => setDialogState(
                            () => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v != newPwCtrl.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(color: AppTheme.textSecondaryOf(ctx))),
            ),
            PressFeedback(
              child: ElevatedButton(
                onPressed: loading
                  ? null
                  : () async {
                      if (!pwFormKey.currentState!.validate()) return;
                      setDialogState(() => loading = true);
                      try {
                        final fbUser = FirebaseAuth.instance.currentUser;
                        if (fbUser == null || fbUser.email == null) {
                          throw Exception('Not signed in');
                        }
                        final cred = EmailAuthProvider.credential(
                          email: fbUser.email!,
                          password: currentPwCtrl.text,
                        );
                        await fbUser.reauthenticateWithCredential(cred);
                        await fbUser.updatePassword(newPwCtrl.text);

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          AppToast.success(context, 'Password changed successfully');
                        }
                      } on FirebaseAuthException catch (e) {
                        setDialogState(() => loading = false);
                        if (ctx.mounted) {
                          AppToast.error(ctx, e.code == 'wrong-password'
                              ? 'Current password is incorrect'
                              : e.message ?? 'Authentication error');
                        }
                      } catch (e) {
                        setDialogState(() => loading = false);
                        if (ctx.mounted) {
                          AppToast.fromError(ctx, e, fallback: 'Password change failed');
                        }
                      }
                    },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
                ),
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Update Password'),
              ),
            ),
          ],
        ),
      ),
    );

    currentPwCtrl.dispose();
    newPwCtrl.dispose();
    confirmPwCtrl.dispose();
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffix,
    bool readOnly = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: AppIconSize.md),
      suffixIcon: suffix,
      filled: true,
      fillColor: readOnly
          ? AppTheme.surfaceOf(context).withValues(alpha: 0.5)
          : AppTheme.inputFillOf(context),
      border: OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: BorderSide(
            color: AppTheme.dividerOf(context), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: const BorderSide(color: AppTheme.accentColor, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('Edit Profile'),
      ),
      body: user == null
          ? const Center(child: Text('Not signed in'))
          : RefreshIndicator(
              onRefresh: _refreshProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppSpacing.paddingXxl,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Profile header card ──
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.xxl),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: AppRadius.xl,
                              boxShadow: AppShadow.elevated(isDark),
                            ),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 44,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.2),
                                  child: Text(
                                    user.initial,
                                    style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white),
                                  ),
                                ),
                                AppSpacing.vMd,
                                Text(
                                  user.displayName ?? 'User',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                AppSpacing.vXs,
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md,
                                      vertical: AppSpacing.xs),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: AppRadius.pill,
                                  ),
                                  child: Text(
                                    user.role.name.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                AppSpacing.vSm,
                                Text(
                                  user.email,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                              .animate()
                              .fadeIn(duration: 500.ms)
                              .slideY(begin: 0.1, end: 0, duration: 500.ms, curve: AppCurve.enter),

                          const SizedBox(height: 28),

                          // ── Personal Information ──
                          _SectionCard(
                            title: 'Personal Information',
                            icon: Icons.person_outline_rounded,
                            delay: 100,
                            children: [
                              TextFormField(
                                controller: _nameCtrl,
                                decoration: _fieldDecoration(
                                  label: 'Full Name',
                                  icon: Icons.person_outline_rounded,
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Name is required'
                                        : null,
                              ),
                              AppSpacing.vLg,
                              TextFormField(
                                initialValue: user.email,
                                readOnly: true,
                                decoration: _fieldDecoration(
                                  label: 'Email',
                                  icon: Icons.email_outlined,
                                  readOnly: true,
                                  suffix: Icon(Icons.lock_outline,
                                      size: 18,
                                      color:
                                          AppTheme.textSecondaryOf(context)),
                                ),
                                style: TextStyle(
                                    color:
                                        AppTheme.textSecondaryOf(context)),
                              ),
                              AppSpacing.vLg,
                              TextFormField(
                                controller: _phoneCtrl,
                                decoration: _fieldDecoration(
                                  label: 'Phone Number',
                                  icon: Icons.phone_outlined,
                                  hint: '+1 (555) 000-0000',
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                              AppSpacing.vLg,
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    controller: _addressCtrl,
                                    decoration: _fieldDecoration(
                                      label: 'Address',
                                      icon: Icons.location_on_outlined,
                                      hint: 'Start typing to search...',
                                      suffix: _geocoding
                                          ? const Padding(
                                              padding: EdgeInsets.all(12),
                                              child: SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2),
                                              ),
                                            )
                                          : (_addressCtrl.text
                                                  .trim()
                                                  .isNotEmpty
                                              ? Icon(Icons.check_circle,
                                                  color:
                                                      AppTheme.successColor,
                                                  size: 20)
                                              : null),
                                    ),
                                    onChanged: _onAddressChanged,
                                  ),
                                  if (_showAddressSuggestions &&
                                      _addressSuggestions.isNotEmpty)
                                    Container(
                                      constraints: const BoxConstraints(
                                          maxHeight: 200),
                                      margin:
                                          const EdgeInsets.only(top: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.cardOf(context),
                                        borderRadius: AppRadius.md,
                                        border: Border.all(
                                            color: AppTheme.dividerOf(
                                                context)),
                                        boxShadow:
                                            AppShadow.card(isDark),
                                      ),
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        padding: EdgeInsets.zero,
                                        itemCount:
                                            _addressSuggestions.length,
                                        separatorBuilder: (_, __) =>
                                            Divider(
                                                height: 1,
                                                color:
                                                    AppTheme.dividerOf(
                                                        context)),
                                        itemBuilder: (context, index) {
                                          final s =
                                              _addressSuggestions[index];
                                          return ListTile(
                                            dense: true,
                                            leading: Icon(
                                                Icons
                                                    .location_on_outlined,
                                                size: 20,
                                                color: AppTheme
                                                    .textSecondaryOf(
                                                        context)),
                                            title: Text(
                                              s.fullAddress,
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: AppTheme
                                                      .textPrimaryOf(
                                                          context)),
                                            ),
                                            onTap: () =>
                                                _selectAddressSuggestion(
                                                    s),
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),

                          // ── Customer: birthday ──
                          if (user.isCustomer)
                            _SectionCard(
                              title: 'Additional Details',
                              icon: Icons.info_outline_rounded,
                              delay: 200,
                              children: [
                                TextFormField(
                                  controller: _birthdayCtrl,
                                  readOnly: true,
                                  onTap: _pickBirthday,
                                  decoration: _fieldDecoration(
                                    label: 'Birthday',
                                    icon: Icons.cake_outlined,
                                    hint: 'Select your birthday',
                                    suffix: IconButton(
                                      icon: const Icon(
                                          Icons.calendar_today_outlined,
                                          size: 20),
                                      onPressed: _pickBirthday,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                          // ── Organizer: experience ──
                          if (user.isOrganizer)
                            _SectionCard(
                              title: 'Professional Details',
                              icon: Icons.work_outline_rounded,
                              delay: 200,
                              children: [
                                TextFormField(
                                  controller: _experienceCtrl,
                                  decoration: _fieldDecoration(
                                    label: 'Years of Experience',
                                    icon: Icons.work_outline_rounded,
                                    hint: 'e.g. 5',
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                ),
                              ],
                            ),

                          // ── Sponsor fields ──
                          if (user.isSponsor)
                            _SectionCard(
                              title: 'Company Details',
                              icon: Icons.business_rounded,
                              delay: 200,
                              children: _loadingSponsorProfile
                                  ? [const ShimmerProfileSection()]
                                  : [
                                      TextFormField(
                                        controller: _companyNameCtrl,
                                        decoration: _fieldDecoration(
                                          label: 'Company Name',
                                          icon: Icons.business_rounded,
                                        ),
                                        validator: (v) =>
                                            (v == null || v.trim().isEmpty)
                                                ? 'Company name is required'
                                                : null,
                                      ),
                                      AppSpacing.vLg,
                                      TextFormField(
                                        controller: _contactNameCtrl,
                                        decoration: _fieldDecoration(
                                          label: 'Contact Name',
                                          icon:
                                              Icons.person_outline_rounded,
                                        ),
                                        validator: (v) =>
                                            (v == null || v.trim().isEmpty)
                                                ? 'Contact name is required'
                                                : null,
                                      ),
                                      AppSpacing.vLg,
                                      TextFormField(
                                        controller: _professionCtrl,
                                        decoration: _fieldDecoration(
                                          label: 'Profession / Industry',
                                          icon: Icons.work_outline_rounded,
                                        ),
                                        validator: (v) =>
                                            (v == null || v.trim().isEmpty)
                                                ? 'Profession is required'
                                                : null,
                                      ),
                                      AppSpacing.vLg,
                                      TextFormField(
                                        controller: _logoUrlCtrl,
                                        decoration: _fieldDecoration(
                                          label: 'Logo URL',
                                          icon: Icons.image_outlined,
                                          hint: 'https://...',
                                        ),
                                        keyboardType: TextInputType.url,
                                      ),
                                      AppSpacing.vLg,
                                      TextFormField(
                                        controller: _descriptionCtrl,
                                        decoration: _fieldDecoration(
                                          label: 'Company Description',
                                          icon: Icons.description_outlined,
                                          hint:
                                              'Tell us about your company...',
                                        ),
                                        maxLines: 3,
                                        minLines: 2,
                                      ),
                                      AppSpacing.vLg,
                                      TextFormField(
                                        controller: _websiteUrlCtrl,
                                        decoration: _fieldDecoration(
                                          label: 'Website URL',
                                          icon: Icons.language_rounded,
                                          hint: 'https://...',
                                        ),
                                        keyboardType: TextInputType.url,
                                      ),
                                      AppSpacing.vLg,
                                      TextFormField(
                                        controller: _experienceCtrl,
                                        decoration: _fieldDecoration(
                                          label: 'Years of Experience',
                                          icon: Icons.timeline_rounded,
                                          hint: 'e.g. 5',
                                        ),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly
                                        ],
                                      ),
                                    ],
                            ),

                          // ── Identity Verification (KYC) ──
                          if (!user.isAdmin)
                            _SectionCard(
                              title: 'Identity Verification',
                              icon: Icons.verified_user_outlined,
                              delay: 240,
                              children: const [KycSection()],
                            ),

                          // ── Payment Information ──
                          _SectionCard(
                            title: 'Payment Information',
                            icon: Icons.credit_card_rounded,
                            delay: 250,
                            children: _paymentInfoLoading
                                ? [const Center(child: CircularProgressIndicator())]
                                : [
                                    if (_paymentInfo != null && (_paymentInfo!['card_last_four'] ?? '').toString().isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        margin: const EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.accentColor.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.credit_card, color: AppTheme.accentColor, size: 24),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${(_paymentInfo!['card_brand'] ?? 'Card').toString().toUpperCase()} •••• ${_paymentInfo!['card_last_four']}',
                                                    style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(context)),
                                                  ),
                                                  if ((_paymentInfo!['card_holder_name'] ?? '').toString().isNotEmpty)
                                                    Text(_paymentInfo!['card_holder_name'],
                                                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context))),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    TextFormField(
                                      controller: _cardHolderCtrl,
                                      decoration: _fieldDecoration(
                                        label: 'Cardholder Name',
                                        icon: Icons.person_outline_rounded,
                                        hint: 'Name on card',
                                      ),
                                    ),
                                    AppSpacing.vLg,
                                    TextFormField(
                                      controller: _billingAddressCtrl,
                                      decoration: _fieldDecoration(
                                        label: 'Billing Address',
                                        icon: Icons.location_on_outlined,
                                      ),
                                    ),
                                    AppSpacing.vLg,
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: _savePaymentInfo,
                                        icon: const Icon(Icons.save_outlined, size: 18),
                                        label: const Text('Save Payment Info'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.accentColor,
                                          side: BorderSide(color: AppTheme.accentColor),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                  ],
                          ),

                          // ── Bank Account (organizer only) ──
                          if (user.isOrganizer)
                            _SectionCard(
                              title: 'Bank Account',
                              icon: Icons.account_balance_rounded,
                              delay: 300,
                              children: _bankLoading
                                  ? [const Center(child: CircularProgressIndicator())]
                                  : [
                                      if (_bankData != null && !_bankEditing) ...[
                                        _bankDetailRow('Bank', _bankData!['bank_name_masked'] ?? 'Not set'),
                                        const SizedBox(height: 8),
                                        _bankDetailRow('Account', _bankData!['account_number_masked'] ?? '••••'),
                                        const SizedBox(height: 8),
                                        _bankDetailRow('Routing', _bankData!['routing_number_masked'] ?? '••••'),
                                        const SizedBox(height: 8),
                                        _bankDetailRow('Holder', _bankData!['account_holder_masked'] ?? ''),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              _bankData!['verified'] == true ? Icons.verified : Icons.pending,
                                              size: 16,
                                              color: _bankData!['verified'] == true ? AppTheme.successColor : AppTheme.warningColor,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _bankData!['verified'] == true ? 'Verified' : 'Pending verification',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: _bankData!['verified'] == true ? AppTheme.successColor : AppTheme.warningColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        AppSpacing.vLg,
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: () => setState(() {
                                              _bankEditing = true;
                                              _bankNameCtrl.clear();
                                              _accountNumberCtrl.clear();
                                              _routingNumberCtrl.clear();
                                              _accountHolderCtrl.clear();
                                              _swiftCodeCtrl.clear();
                                            }),
                                            icon: const Icon(Icons.edit_outlined, size: 18),
                                            label: const Text('Edit Bank Details'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppTheme.accentColor,
                                              side: BorderSide(color: AppTheme.accentColor),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                          ),
                                        ),
                                      ] else ...[
                                        TextFormField(
                                          controller: _bankNameCtrl,
                                          decoration: _fieldDecoration(label: 'Bank Name', icon: Icons.account_balance),
                                        ),
                                        AppSpacing.vLg,
                                        TextFormField(
                                          controller: _accountNumberCtrl,
                                          decoration: _fieldDecoration(label: 'Account Number', icon: Icons.numbers),
                                        ),
                                        AppSpacing.vLg,
                                        TextFormField(
                                          controller: _routingNumberCtrl,
                                          decoration: _fieldDecoration(label: 'Routing Number', icon: Icons.alt_route),
                                        ),
                                        AppSpacing.vLg,
                                        TextFormField(
                                          controller: _accountHolderCtrl,
                                          decoration: _fieldDecoration(label: 'Account Holder', icon: Icons.person_outline),
                                        ),
                                        AppSpacing.vLg,
                                        TextFormField(
                                          controller: _swiftCodeCtrl,
                                          decoration: _fieldDecoration(label: 'SWIFT Code (optional)', icon: Icons.language),
                                        ),
                                        AppSpacing.vLg,
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () {
                                                  if (_bankData != null) {
                                                    setState(() => _bankEditing = false);
                                                  }
                                                },
                                                style: OutlinedButton.styleFrom(
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                                child: const Text('Cancel'),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: _saveBankAccount,
                                                icon: const Icon(Icons.save_outlined, size: 18),
                                                label: const Text('Save'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppTheme.accentColor,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                            ),

                          const SizedBox(height: 28),

                          // ── Save button ──
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: PressFeedback(
                              child: ElevatedButton.icon(
                                onPressed: _saving ? null : _saveProfile,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white))
                                  : const Icon(Icons.check_rounded,
                                      size: 20),
                              label: Text(
                                  _saving ? 'Saving...' : 'Save Changes',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: AppRadius.md),
                                ),
                              ),
                            ),
                          )
                              .animate(delay: 300.ms)
                              .fadeIn(duration: 400.ms)
                              .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: AppCurve.enter),

                          AppSpacing.vXxl,

                          // ── Security section ──
                          _SectionCard(
                            title: 'Security',
                            icon: Icons.shield_outlined,
                            delay: 350,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.cardOf(context),
                                  borderRadius: AppRadius.md,
                                  border: Border.all(
                                      color:
                                          AppTheme.dividerOf(context)),
                                ),
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppTheme.warningSurfaceOf(
                                          context),
                                      borderRadius: AppRadius.md,
                                    ),
                                    child: Icon(
                                        Icons.lock_outline_rounded,
                                        size: 20,
                                        color: context.fundingAccent),
                                  ),
                                  title: Text('Change Password',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color:
                                              AppTheme.textPrimaryOf(
                                                  context))),
                                  subtitle: Text(
                                      'Update your account password',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              AppTheme.textSecondaryOf(
                                                  context))),
                                  trailing: Icon(
                                      Icons.chevron_right_rounded,
                                      color:
                                          AppTheme.textSecondaryOf(
                                              context)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: AppRadius.md),
                                  onTap: _changePassword,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

Widget _bankDetailRow(String label, String value) {
  return Builder(builder: (context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context))),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(context))),
      ],
    );
  });
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final int delay;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: AppRadius.lg,
          boxShadow: AppShadow.soft(isDark),
          border: Border.all(
            color: AppTheme.dividerOf(context).withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: AppIconSize.md,
                    color: AppTheme.accentColor),
                AppSpacing.hSm,
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondaryOf(context),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            AppSpacing.vLg,
            ...children,
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: delay))
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.08, end: 0, duration: 400.ms, curve: AppCurve.enter);
  }
}
