import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';

class SponsorOnboardingScreen extends StatefulWidget {
  const SponsorOnboardingScreen({super.key});

  @override
  State<SponsorOnboardingScreen> createState() =>
      _SponsorOnboardingScreenState();
}

class _SponsorOnboardingScreenState extends State<SponsorOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _professionCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _websiteUrlCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isEdit = false;
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
  }

  Future<void> _loadExisting() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getSponsorProfile();
      _companyNameCtrl.text = data['company_name'] ?? '';
      _contactNameCtrl.text = data['contact_name'] ?? '';
      _professionCtrl.text = data['profession'] ?? '';
      _logoUrlCtrl.text = data['logo_url'] ?? '';
      _descriptionCtrl.text = data['description'] ?? '';
      _websiteUrlCtrl.text = data['website_url'] ?? '';
      _isEdit = true;
    } catch (_) {
      // No existing profile — create mode
    }
    if (mounted) setState(() => _initialLoading = false);
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _contactNameCtrl.dispose();
    _professionCtrl.dispose();
    _logoUrlCtrl.dispose();
    _descriptionCtrl.dispose();
    _websiteUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final payload = {
      'company_name': _companyNameCtrl.text.trim(),
      'contact_name': _contactNameCtrl.text.trim(),
      'profession': _professionCtrl.text.trim(),
      if (_logoUrlCtrl.text.trim().isNotEmpty)
        'logo_url': _logoUrlCtrl.text.trim(),
      if (_descriptionCtrl.text.trim().isNotEmpty)
        'description': _descriptionCtrl.text.trim(),
      if (_websiteUrlCtrl.text.trim().isNotEmpty)
        'website_url': _websiteUrlCtrl.text.trim(),
    };

    try {
      final api = context.read<ApiService>();
      if (_isEdit) {
        await api.updateSponsorProfile(payload);
      } else {
        await api.createSponsorProfile(payload);
      }

      if (mounted) {
        await context.read<AuthProvider>().refreshUser();
        AppToast.success(
          context,
          _isEdit ? 'Profile updated!' : 'Welcome, Sponsor!',
        );
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, ApiService.extractError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Sponsor Profile' : 'Become a Sponsor'),
      ),
      body: _initialLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.storefront_rounded,
                          size: 64,
                          color: AppTheme.accentColor,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isEdit
                              ? 'Update your sponsor profile'
                              : 'Set up your company profile to start sponsoring events',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: AppTheme.textSecondaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _companyNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Company Name *',
                            prefixIcon: Icon(Icons.business),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _contactNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Contact Name *',
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _professionCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Profession / Industry *',
                            prefixIcon: Icon(Icons.work_outline),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _logoUrlCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Logo URL',
                            prefixIcon: Icon(Icons.image_outlined),
                            hintText: 'https://...',
                          ),
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Company Description',
                            prefixIcon: Icon(Icons.description_outlined),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _websiteUrlCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Website URL',
                            prefixIcon: Icon(Icons.language),
                            hintText: 'https://...',
                          ),
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text(
                                    _isEdit
                                        ? 'Update Profile'
                                        : 'Create Sponsor Profile',
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
