import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../utils/date_time_utils.dart';
import '../../config/design_tokens.dart';
import '../../models/user.dart';
import '../../widgets/press_feedback.dart';
import '../../widgets/kyc_section.dart';
import '../../providers/auth_provider.dart';
import '../../models/sponsor.dart';
import '../../providers/sponsor_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/app_toast.dart';
import 'profile_section_card.dart';
import 'profile_header.dart';
import 'profile_personal_info_section.dart';
import 'profile_sponsor_section.dart';
import 'profile_payment_section.dart';
import 'profile_bank_section.dart';
import 'profile_contact_section.dart';
import 'profile_security_section.dart';

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

  // ── Contact / social (all user-level, shown for organizers & sponsors) ──
  late TextEditingController _bioCtrl;
  late TextEditingController _websiteCtrl;
  late TextEditingController _contactEmailCtrl;
  late TextEditingController _instagramCtrl;
  late TextEditingController _twitterCtrl;
  late TextEditingController _facebookCtrl;
  late TextEditingController _linkedinCtrl;
  late TextEditingController _youtubeCtrl;
  late TextEditingController _tiktokCtrl;

  DateTime? _selectedBirthday;
  bool _saving = false;
  bool _loadingSponsorProfile = false;
  bool _hasSponsorProfile = false;

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

    _bioCtrl          = TextEditingController(text: user?.bio ?? '');
    _websiteCtrl      = TextEditingController(text: user?.websiteUrl ?? '');
    _contactEmailCtrl = TextEditingController(text: user?.contactEmail ?? '');
    _instagramCtrl    = TextEditingController(text: user?.instagram ?? '');
    _twitterCtrl      = TextEditingController(text: user?.twitter ?? '');
    _facebookCtrl     = TextEditingController(text: user?.facebook ?? '');
    _linkedinCtrl     = TextEditingController(text: user?.linkedin ?? '');
    _youtubeCtrl      = TextEditingController(text: user?.youtube ?? '');
    _tiktokCtrl       = TextEditingController(text: user?.tiktok ?? '');

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

    if (user != null && user.isSponsor) _loadSponsorProfile();
  }

  @override
  void dispose() {
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
    _bioCtrl.dispose();
    _websiteCtrl.dispose();
    _contactEmailCtrl.dispose();
    _instagramCtrl.dispose();
    _twitterCtrl.dispose();
    _facebookCtrl.dispose();
    _linkedinCtrl.dispose();
    _youtubeCtrl.dispose();
    _tiktokCtrl.dispose();
    super.dispose();
  }

  // ── Data Loading ──────────────────────────────────────────────────────

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
        _bioCtrl.text          = user.bio ?? '';
        _websiteCtrl.text      = user.websiteUrl ?? '';
        _contactEmailCtrl.text = user.contactEmail ?? '';
        _instagramCtrl.text    = user.instagram ?? '';
        _twitterCtrl.text      = user.twitter ?? '';
        _facebookCtrl.text     = user.facebook ?? '';
        _linkedinCtrl.text     = user.linkedin ?? '';
        _youtubeCtrl.text      = user.youtube ?? '';
        _tiktokCtrl.text       = user.tiktok ?? '';
        if (user.birthday != null) {
          try {
            _selectedBirthday = DateTime.parse(user.birthday!);
            _birthdayCtrl.text = AppDateFormat.dateOnly(_selectedBirthday!);
          } catch (e) {
            debugPrint(e.toString());
          }
        }
      });
    }
    if (user != null && user.isSponsor) await _loadSponsorProfile();
  }

  Future<void> _loadSponsorProfile() async {
    setState(() => _loadingSponsorProfile = true);
    try {
      final profile = await context.read<SponsorProvider>().getSponsorProfile();
      if (mounted) {
        setState(() {
          _hasSponsorProfile = true;
          _companyNameCtrl.text = profile.companyName;
          _contactNameCtrl.text = profile.contactName;
          _professionCtrl.text = profile.profession;
          _logoUrlCtrl.text = profile.logoUrl ?? '';
          _descriptionCtrl.text = profile.description ?? '';
          _websiteUrlCtrl.text = profile.websiteUrl ?? '';
        });
      }
    } on DioException catch (e) {
      // 404 is expected when sponsor hasn't created a profile yet — ignore
      if (e.response?.statusCode != 404) debugPrint(e.toString());
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      if (mounted) setState(() => _loadingSponsorProfile = false);
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────

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
      final userRepo = context.read<UserProvider>();
      final sponsorRepo = context.read<SponsorProvider>();
      final user = context.read<AuthProvider>().user!;

      final profileRequest = UpdateProfileRequest(
        displayName: _nameCtrl.text.trim() != (user.displayName ?? '')
            ? _nameCtrl.text.trim()
            : null,
        phone: _phoneCtrl.text.trim() != (user.phone ?? '')
            ? _phoneCtrl.text.trim()
            : null,
        address: _addressCtrl.text.trim() != (user.address ?? '')
            ? _addressCtrl.text.trim()
            : null,
        birthday: _selectedBirthday != null &&
                AppDateFormat.apiDate(_selectedBirthday!) !=
                    (user.birthday ?? '')
            ? AppDateFormat.apiDate(_selectedBirthday!)
            : null,
        yearsOfExperience: (user.isOrganizer || user.isSponsor) &&
                _experienceCtrl.text.trim().isNotEmpty
            ? (() {
                final exp = int.tryParse(_experienceCtrl.text.trim());
                return exp != null && exp != user.yearsOfExperience
                    ? exp
                    : null;
              })()
            : null,
        bio: (user.isOrganizer || user.isSponsor) &&
                _bioCtrl.text.trim() != (user.bio ?? '')
            ? _bioCtrl.text.trim()
            : null,
        websiteUrl: (user.isOrganizer || user.isSponsor) &&
                _websiteCtrl.text.trim() != (user.websiteUrl ?? '')
            ? _websiteCtrl.text.trim()
            : null,
        contactEmail: (user.isOrganizer || user.isSponsor) &&
                _contactEmailCtrl.text.trim() != (user.contactEmail ?? '')
            ? _contactEmailCtrl.text.trim()
            : null,
        instagram: (user.isOrganizer || user.isSponsor) &&
                _instagramCtrl.text.trim() != (user.instagram ?? '')
            ? _instagramCtrl.text.trim()
            : null,
        twitter: (user.isOrganizer || user.isSponsor) &&
                _twitterCtrl.text.trim() != (user.twitter ?? '')
            ? _twitterCtrl.text.trim()
            : null,
        facebook: (user.isOrganizer || user.isSponsor) &&
                _facebookCtrl.text.trim() != (user.facebook ?? '')
            ? _facebookCtrl.text.trim()
            : null,
        linkedin: (user.isOrganizer || user.isSponsor) &&
                _linkedinCtrl.text.trim() != (user.linkedin ?? '')
            ? _linkedinCtrl.text.trim()
            : null,
        youtube: (user.isOrganizer || user.isSponsor) &&
                _youtubeCtrl.text.trim() != (user.youtube ?? '')
            ? _youtubeCtrl.text.trim()
            : null,
        tiktok: (user.isOrganizer || user.isSponsor) &&
                _tiktokCtrl.text.trim() != (user.tiktok ?? '')
            ? _tiktokCtrl.text.trim()
            : null,
      );

      bool userUpdated = false;
      if (!profileRequest.isEmpty) {
        await userRepo.updateMe(profileRequest);
        userUpdated = true;
      }

      bool sponsorUpdated = false;
      if (user.isSponsor) {
        final spData = SponsorProfileRequest(
          companyName: _companyNameCtrl.text.trim(),
          contactName: _contactNameCtrl.text.trim(),
          profession: _professionCtrl.text.trim(),
          logoUrl: _logoUrlCtrl.text.trim().isEmpty
              ? null
              : _logoUrlCtrl.text.trim(),
          description: _descriptionCtrl.text.trim().isEmpty
              ? null
              : _descriptionCtrl.text.trim(),
          websiteUrl: _websiteUrlCtrl.text.trim().isEmpty
              ? null
              : _websiteUrlCtrl.text.trim(),
        );

        if (_hasSponsorProfile) {
          await sponsorRepo.updateSponsorProfile(spData);
        } else {
          await sponsorRepo.createSponsorProfile(spData);
          _hasSponsorProfile = true;
        }
        sponsorUpdated = true;
      }

      if (!userUpdated && !sponsorUpdated) {
        if (mounted) AppToast.info(context, 'No changes to save');
        return;
      }

      if (!mounted) return;
      await context.read<AuthProvider>().refreshUser();
      if (mounted) AppToast.success(context, 'Profile updated successfully');
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to update profile');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
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
                          ProfileHeaderCard(user: user),
                          const SizedBox(height: 28),
                          ProfilePersonalInfoSection(
                            nameCtrl: _nameCtrl,
                            phoneCtrl: _phoneCtrl,
                            addressCtrl: _addressCtrl,
                            email: user.email,
                          ),
                          if (user.isCustomer)
                            ProfileSectionCard(
                              title: 'Additional Details',
                              icon: Icons.info_outline_rounded,
                              delay: 200,
                              children: [
                                TextFormField(
                                  controller: _birthdayCtrl,
                                  readOnly: true,
                                  onTap: _pickBirthday,
                                  decoration: profileFieldDecoration(
                                    context,
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
                          if (user.isOrganizer)
                            ProfileContactSection(
                              bioCtrl: _bioCtrl,
                              websiteCtrl: _websiteCtrl,
                              contactEmailCtrl: _contactEmailCtrl,
                              instagramCtrl: _instagramCtrl,
                              twitterCtrl: _twitterCtrl,
                              facebookCtrl: _facebookCtrl,
                              linkedinCtrl: _linkedinCtrl,
                              youtubeCtrl: _youtubeCtrl,
                              tiktokCtrl: _tiktokCtrl,
                            ),
                          if (user.isOrganizer)
                            ProfileSectionCard(
                              title: 'Professional Details',
                              icon: Icons.work_outline_rounded,
                              delay: 200,
                              children: [
                                TextFormField(
                                  controller: _birthdayCtrl,
                                  readOnly: true,
                                  onTap: _pickBirthday,
                                  decoration: profileFieldDecoration(
                                    context,
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
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _experienceCtrl,
                                  decoration: profileFieldDecoration(
                                    context,
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
                          if (user.isSponsor)
                            ProfileContactSection(
                              bioCtrl: _bioCtrl,
                              websiteCtrl: _websiteCtrl,
                              contactEmailCtrl: _contactEmailCtrl,
                              instagramCtrl: _instagramCtrl,
                              twitterCtrl: _twitterCtrl,
                              facebookCtrl: _facebookCtrl,
                              linkedinCtrl: _linkedinCtrl,
                              youtubeCtrl: _youtubeCtrl,
                              tiktokCtrl: _tiktokCtrl,
                            ),
                          if (user.isSponsor)
                            ProfileSponsorSection(
                              loading: _loadingSponsorProfile,
                              companyNameCtrl: _companyNameCtrl,
                              contactNameCtrl: _contactNameCtrl,
                              professionCtrl: _professionCtrl,
                              logoUrlCtrl: _logoUrlCtrl,
                              descriptionCtrl: _descriptionCtrl,
                              websiteUrlCtrl: _websiteUrlCtrl,
                              experienceCtrl: _experienceCtrl,
                            ),
                          if (!user.isAdmin)
                            ProfileSectionCard(
                              title: 'Identity Verification',
                              icon: Icons.verified_user_outlined,
                              delay: 240,
                              children: const [KycSection()],
                            ),
                          const ProfilePaymentSection(),
                          if (user.isOrganizer) const ProfileBankSection(),
                          const SizedBox(height: 28),
                          _buildSaveButton(),
                          AppSpacing.vXxl,
                          const ProfileSecuritySection(),
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

  Widget _buildSaveButton() {
    return SizedBox(
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
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_rounded, size: 20),
          label: Text(_saving ? 'Saving...' : 'Save Changes',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
          ),
        ),
      ),
    )
        .animate(delay: 300.ms)
        .fadeIn(duration: 400.ms)
        .slideY(
            begin: 0.1, end: 0, duration: 400.ms, curve: AppCurve.enter);
  }
}
