import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/mapbox_geocoding_service.dart';

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

  // Sponsor profile controllers
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
            text: DateFormat('MMM dd, yyyy').format(_selectedBirthday!));
      } catch (_) {
        _birthdayCtrl = TextEditingController();
      }
    } else {
      _birthdayCtrl = TextEditingController();
    }

    if (user != null && user.isSponsor) {
      _loadSponsorProfile();
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
    } catch (_) {
      // Profile doesn't exist yet
    } finally {
      if (mounted) setState(() => _loadingSponsorProfile = false);
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
        _birthdayCtrl.text = DateFormat('MMM dd, yyyy').format(picked);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final api = context.read<ApiService>();
      final user = context.read<AuthProvider>().user!;

      // --- User profile fields ---
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
      if (user.isCustomer && _selectedBirthday != null) {
        final bdStr = DateFormat('yyyy-MM-dd').format(_selectedBirthday!);
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

      // --- Sponsor profile fields ---
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No changes to save')),
          );
        }
        return;
      }

      await context.read<AuthProvider>().refreshUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully'),
            backgroundColor: Colors.green.shade600,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
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
              const SizedBox(width: 10),
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
                          borderRadius: BorderRadius.circular(12),
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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: newPwCtrl,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      filled: true,
                      fillColor: AppTheme.inputFillOf(ctx),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmPwCtrl,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      filled: true,
                      fillColor: AppTheme.inputFillOf(ctx),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
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
            ElevatedButton(
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  const Text('Password changed successfully'),
                              backgroundColor: Colors.green.shade600,
                            ),
                          );
                        }
                      } on FirebaseAuthException catch (e) {
                        setDialogState(() => loading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                  e.code == 'wrong-password'
                                      ? 'Current password is incorrect'
                                      : e.message ?? 'Authentication error'),
                              backgroundColor: AppTheme.errorColor,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => loading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: AppTheme.errorColor,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Update Password'),
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
      prefixIcon: Icon(icon, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: readOnly
          ? AppTheme.surfaceOf(context).withValues(alpha: 0.5)
          : AppTheme.inputFillOf(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: AppTheme.dividerOf(context), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.accentColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar & role badge
                        Center(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 48,
                                backgroundColor: AppTheme.accentColor,
                                child: Text(
                                  user.initial,
                                  style: const TextStyle(
                                      fontSize: 36, color: Colors.white),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Chip(
                                label: Text(
                                  user.role.name.toUpperCase(),
                                  style: TextStyle(
                                    color: AppTheme.textPrimaryOf(context),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                backgroundColor: AppTheme.accentColor
                                    .withValues(alpha: 0.15),
                                side: BorderSide.none,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Basic info section
                        _sectionHeader('Personal Information'),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _nameCtrl,
                          decoration: _fieldDecoration(
                            label: 'Full Name',
                            icon: Icons.person_outline_rounded,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Name is required'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          initialValue: user.email,
                          readOnly: true,
                          decoration: _fieldDecoration(
                            label: 'Email',
                            icon: Icons.email_outlined,
                            readOnly: true,
                            suffix: Icon(Icons.lock_outline,
                                size: 18,
                                color: AppTheme.textSecondaryOf(context)),
                          ),
                          style: TextStyle(
                              color: AppTheme.textSecondaryOf(context)),
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _phoneCtrl,
                          decoration: _fieldDecoration(
                            label: 'Phone Number',
                            icon: Icons.phone_outlined,
                            hint: '+1 (555) 000-0000',
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      )
                                    : (_addressCtrl.text.trim().isNotEmpty
                                        ? const Icon(Icons.check_circle,
                                            color: Colors.green, size: 20)
                                        : null),
                              ),
                              onChanged: _onAddressChanged,
                            ),
                            if (_showAddressSuggestions &&
                                _addressSuggestions.isNotEmpty)
                              Container(
                                constraints:
                                    const BoxConstraints(maxHeight: 200),
                                margin: const EdgeInsets.only(top: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardOf(context),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppTheme.dividerOf(context)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: _addressSuggestions.length,
                                  separatorBuilder: (_, __) => Divider(
                                      height: 1,
                                      color: AppTheme.dividerOf(context)),
                                  itemBuilder: (context, index) {
                                    final s = _addressSuggestions[index];
                                    return ListTile(
                                      dense: true,
                                      leading: Icon(
                                          Icons.location_on_outlined,
                                          size: 20,
                                          color: AppTheme.textSecondaryOf(
                                              context)),
                                      title: Text(
                                        s.fullAddress,
                                        style: TextStyle(
                                            fontSize: 13,
                                            color:
                                                AppTheme.textPrimaryOf(
                                                    context)),
                                      ),
                                      onTap: () =>
                                          _selectAddressSuggestion(s),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),

                        // Customer-specific: birthday
                        if (user.isCustomer) ...[
                          const SizedBox(height: 24),
                          _sectionHeader('Additional Details'),
                          const SizedBox(height: 16),
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

                        // Organizer-specific: experience
                        if (user.isOrganizer) ...[
                          const SizedBox(height: 24),
                          _sectionHeader('Professional Details'),
                          const SizedBox(height: 16),
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

                        // Sponsor-specific fields
                        if (user.isSponsor) ...[
                          const SizedBox(height: 24),
                          _sectionHeader('Company Details'),
                          const SizedBox(height: 16),
                          if (_loadingSponsorProfile)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          else ...[
                            TextFormField(
                              controller: _companyNameCtrl,
                              decoration: _fieldDecoration(
                                label: 'Company Name',
                                icon: Icons.business_rounded,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Company name is required'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _contactNameCtrl,
                              decoration: _fieldDecoration(
                                label: 'Contact Name',
                                icon: Icons.person_outline_rounded,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Contact name is required'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _professionCtrl,
                              decoration: _fieldDecoration(
                                label: 'Profession / Industry',
                                icon: Icons.work_outline_rounded,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Profession is required'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _logoUrlCtrl,
                              decoration: _fieldDecoration(
                                label: 'Logo URL',
                                icon: Icons.image_outlined,
                                hint: 'https://...',
                              ),
                              keyboardType: TextInputType.url,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descriptionCtrl,
                              decoration: _fieldDecoration(
                                label: 'Company Description',
                                icon: Icons.description_outlined,
                                hint: 'Tell us about your company...',
                              ),
                              maxLines: 3,
                              minLines: 2,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _websiteUrlCtrl,
                              decoration: _fieldDecoration(
                                label: 'Website URL',
                                icon: Icons.language_rounded,
                                hint: 'https://...',
                              ),
                              keyboardType: TextInputType.url,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _experienceCtrl,
                              decoration: _fieldDecoration(
                                label: 'Years of Experience',
                                icon: Icons.timeline_rounded,
                                hint: 'e.g. 5',
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                            ),
                          ],
                        ],

                        const SizedBox(height: 32),

                        // Save button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _saveProfile,
                            icon: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check_rounded, size: 20),
                            label: Text(_saving ? 'Saving...' : 'Save Changes',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Security section
                        _sectionHeader('Security'),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.cardOf(context),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppTheme.dividerOf(context)),
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.lock_outline_rounded,
                                  size: 20, color: Colors.orange),
                            ),
                            title: Text('Change Password',
                                style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textPrimaryOf(context))),
                            subtitle: Text('Update your account password',
                                style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        AppTheme.textSecondaryOf(context))),
                            trailing: Icon(Icons.chevron_right_rounded,
                                color: AppTheme.textSecondaryOf(context)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            onTap: _changePassword,
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppTheme.textSecondaryOf(context),
        letterSpacing: 0.5,
      ),
    );
  }
}
