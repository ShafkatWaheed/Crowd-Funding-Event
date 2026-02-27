import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/design_tokens.dart';
import '../../widgets/shimmer_loaders.dart';
import 'profile_section_card.dart';

class ProfileSponsorSection extends StatelessWidget {
  final bool loading;
  final TextEditingController companyNameCtrl;
  final TextEditingController contactNameCtrl;
  final TextEditingController professionCtrl;
  final TextEditingController logoUrlCtrl;
  final TextEditingController descriptionCtrl;
  final TextEditingController websiteUrlCtrl;
  final TextEditingController experienceCtrl;

  const ProfileSponsorSection({
    super.key,
    required this.loading,
    required this.companyNameCtrl,
    required this.contactNameCtrl,
    required this.professionCtrl,
    required this.logoUrlCtrl,
    required this.descriptionCtrl,
    required this.websiteUrlCtrl,
    required this.experienceCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      title: 'Company Details',
      icon: Icons.business_rounded,
      delay: 200,
      children: loading
          ? [const ShimmerProfileSection()]
          : [
              TextFormField(
                controller: companyNameCtrl,
                decoration: profileFieldDecoration(
                  context,
                  label: 'Company Name',
                  icon: Icons.business_rounded,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Company name is required'
                    : null,
              ),
              AppSpacing.vLg,
              TextFormField(
                controller: contactNameCtrl,
                decoration: profileFieldDecoration(
                  context,
                  label: 'Contact Name',
                  icon: Icons.person_outline_rounded,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Contact name is required'
                    : null,
              ),
              AppSpacing.vLg,
              TextFormField(
                controller: professionCtrl,
                decoration: profileFieldDecoration(
                  context,
                  label: 'Profession / Industry',
                  icon: Icons.work_outline_rounded,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Profession is required'
                    : null,
              ),
              AppSpacing.vLg,
              TextFormField(
                controller: logoUrlCtrl,
                decoration: profileFieldDecoration(
                  context,
                  label: 'Logo URL',
                  icon: Icons.image_outlined,
                  hint: 'https://...',
                ),
                keyboardType: TextInputType.url,
              ),
              AppSpacing.vLg,
              TextFormField(
                controller: descriptionCtrl,
                decoration: profileFieldDecoration(
                  context,
                  label: 'Company Description',
                  icon: Icons.description_outlined,
                  hint: 'Tell us about your company...',
                ),
                maxLines: 3,
                minLines: 2,
              ),
              AppSpacing.vLg,
              TextFormField(
                controller: websiteUrlCtrl,
                decoration: profileFieldDecoration(
                  context,
                  label: 'Website URL',
                  icon: Icons.language_rounded,
                  hint: 'https://...',
                ),
                keyboardType: TextInputType.url,
              ),
              AppSpacing.vLg,
              TextFormField(
                controller: experienceCtrl,
                decoration: profileFieldDecoration(
                  context,
                  label: 'Years of Experience',
                  icon: Icons.timeline_rounded,
                  hint: 'e.g. 5',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
    );
  }
}
