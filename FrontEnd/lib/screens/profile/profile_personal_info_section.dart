import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../config/design_tokens.dart';
import '../../services/mapbox_geocoding_service.dart';
import 'profile_section_card.dart';

class ProfilePersonalInfoSection extends StatefulWidget {
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController addressCtrl;
  final String email;

  const ProfilePersonalInfoSection({
    super.key,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.addressCtrl,
    required this.email,
  });

  @override
  State<ProfilePersonalInfoSection> createState() =>
      _ProfilePersonalInfoSectionState();
}

class _ProfilePersonalInfoSectionState
    extends State<ProfilePersonalInfoSection> {
  List<GeocodingResult> _addressSuggestions = [];
  bool _showAddressSuggestions = false;
  bool _geocoding = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
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

  void _selectSuggestion(GeocodingResult result) {
    setState(() {
      widget.addressCtrl.text = result.fullAddress;
      _showAddressSuggestions = false;
      _addressSuggestions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return ProfileSectionCard(
      title: 'Personal Information',
      icon: Icons.person_outline_rounded,
      delay: 100,
      children: [
        TextFormField(
          controller: widget.nameCtrl,
          decoration: profileFieldDecoration(
            context,
            label: 'Full Name',
            icon: Icons.person_outline_rounded,
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Name is required' : null,
        ),
        AppSpacing.vLg,
        TextFormField(
          initialValue: widget.email,
          readOnly: true,
          decoration: profileFieldDecoration(
            context,
            label: 'Email',
            icon: Icons.email_outlined,
            readOnly: true,
            suffix: Icon(Icons.lock_outline,
                size: 18, color: AppTheme.textSecondaryOf(context)),
          ),
          style: TextStyle(color: AppTheme.textSecondaryOf(context)),
        ),
        AppSpacing.vLg,
        TextFormField(
          controller: widget.phoneCtrl,
          decoration: profileFieldDecoration(
            context,
            label: 'Phone Number',
            icon: Icons.phone_outlined,
            hint: '+1 (555) 000-0000',
          ),
          keyboardType: TextInputType.phone,
        ),
        AppSpacing.vLg,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: widget.addressCtrl,
              decoration: profileFieldDecoration(
                context,
                label: 'Address',
                icon: Icons.location_on_outlined,
                hint: 'Start typing to search...',
                suffix: _geocoding
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : (widget.addressCtrl.text.trim().isNotEmpty
                        ? Icon(Icons.check_circle,
                            color: AppTheme.successColor, size: 20)
                        : null),
              ),
              onChanged: _onAddressChanged,
            ),
            if (_showAddressSuggestions && _addressSuggestions.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: AppTheme.cardOf(context),
                  borderRadius: AppRadius.md,
                  border:
                      Border.all(color: AppTheme.dividerOf(context)),
                  boxShadow: AppShadow.card(isDark),
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
                      leading: Icon(Icons.location_on_outlined,
                          size: 20,
                          color: AppTheme.textSecondaryOf(context)),
                      title: Text(
                        s.fullAddress,
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textPrimaryOf(context)),
                      ),
                      onTap: () => _selectSuggestion(s),
                    );
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }
}
