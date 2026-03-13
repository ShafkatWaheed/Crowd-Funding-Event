import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../config/theme.dart';
import '../../config/design_tokens.dart';
import 'profile_section_card.dart';

// ─── Brand colour palette for social networks ──────────────────────────────

const _kInstagramColor = Color(0xFFE1306C);
const _kTwitterColor   = Color(0xFF000000);
const _kFacebookColor  = Color(0xFF1877F2);
const _kLinkedInColor  = Color(0xFF0A66C2);
const _kYouTubeColor   = Color(0xFFFF0000);
const _kTikTokColor    = Color(0xFF010101);

// ─── Widget ────────────────────────────────────────────────────────────────

class ProfileContactSection extends StatelessWidget {
  final TextEditingController bioCtrl;
  final TextEditingController websiteCtrl;
  final TextEditingController contactEmailCtrl;
  final TextEditingController instagramCtrl;
  final TextEditingController twitterCtrl;
  final TextEditingController facebookCtrl;
  final TextEditingController linkedinCtrl;
  final TextEditingController youtubeCtrl;
  final TextEditingController tiktokCtrl;

  const ProfileContactSection({
    super.key,
    required this.bioCtrl,
    required this.websiteCtrl,
    required this.contactEmailCtrl,
    required this.instagramCtrl,
    required this.twitterCtrl,
    required this.facebookCtrl,
    required this.linkedinCtrl,
    required this.youtubeCtrl,
    required this.tiktokCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Container(
        width: double.infinity,
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
            // ── Premium gradient header ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF1A1035), const Color(0xFF0D1B3E)]
                      : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.lgValue),
                  topRight: Radius.circular(AppRadius.lgValue),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.public_rounded, size: 18, color: AppTheme.accentColor),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Online Presence',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        'Shown on your public profile',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : const Color(0xFF6366F1).withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── About ──────────────────────────────────────────────
                  _SubHeader(label: 'About', icon: Icons.person_outline_rounded),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: bioCtrl,
                    maxLines: 4,
                    minLines: 3,
                    maxLength: 500,
                    decoration: profileFieldDecoration(
                      context,
                      label: 'Bio',
                      icon: Icons.edit_note_rounded,
                      hint: 'Tell attendees about yourself and the events you organize…',
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Contact ────────────────────────────────────────────
                  _SubHeader(label: 'Contact', icon: Icons.contact_mail_outlined),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: contactEmailCtrl,
                    decoration: profileFieldDecoration(
                      context,
                      label: 'Public Contact Email',
                      icon: Icons.alternate_email_rounded,
                      hint: 'hello@yourname.com',
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: websiteCtrl,
                    decoration: profileFieldDecoration(
                      context,
                      label: 'Website',
                      icon: Icons.language_rounded,
                      hint: 'https://yourwebsite.com',
                    ),
                    keyboardType: TextInputType.url,
                  ),

                  const SizedBox(height: 24),

                  // ── Social Handles ─────────────────────────────────────
                  _SubHeader(label: 'Social Handles', icon: Icons.share_rounded),
                  const SizedBox(height: 12),

                  _SocialField(
                    controller: instagramCtrl,
                    label: 'Instagram',
                    badge: '@',
                    badgeColor: _kInstagramColor,
                    hint: 'yourhandle',
                    prefix: _SocialBadge(label: 'IG', color: _kInstagramColor),
                  ),
                  const SizedBox(height: 12),
                  _SocialField(
                    controller: twitterCtrl,
                    label: 'X / Twitter',
                    badge: '@',
                    badgeColor: _kTwitterColor,
                    hint: 'yourhandle',
                    prefix: _SocialBadge(label: '𝕏', color: _kTwitterColor),
                  ),
                  const SizedBox(height: 12),
                  _SocialField(
                    controller: facebookCtrl,
                    label: 'Facebook',
                    badge: 'f',
                    badgeColor: _kFacebookColor,
                    hint: 'page-name or handle',
                    prefix: _SocialBadge(label: 'f', color: _kFacebookColor, fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  _SocialField(
                    controller: linkedinCtrl,
                    label: 'LinkedIn',
                    badge: 'in',
                    badgeColor: _kLinkedInColor,
                    hint: 'your-name',
                    prefix: _SocialBadge(label: 'in', color: _kLinkedInColor, fontSize: 10),
                  ),
                  const SizedBox(height: 12),
                  _SocialField(
                    controller: youtubeCtrl,
                    label: 'YouTube',
                    badge: '@',
                    badgeColor: _kYouTubeColor,
                    hint: 'yourchannel',
                    prefix: _SocialBadge(label: '▶', color: _kYouTubeColor, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  _SocialField(
                    controller: tiktokCtrl,
                    label: 'TikTok',
                    badge: '@',
                    badgeColor: _kTikTokColor,
                    hint: 'yourhandle',
                    prefix: _SocialBadge(label: 'TT', color: _kTikTokColor, fontSize: 9),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate(delay: 260.ms)
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.08, end: 0, duration: 400.ms, curve: AppCurve.enter);
  }
}

// ─── Sub-section header ────────────────────────────────────────────────────

class _SubHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SubHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.accentColor.withValues(alpha: 0.75)),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: AppTheme.accentColor.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: AppTheme.dividerOf(context), height: 1)),
      ],
    );
  }
}

// ─── Social brand badge prefix ─────────────────────────────────────────────

class _SocialBadge extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;

  const _SocialBadge({
    required this.label,
    required this.color,
    this.fontSize = 11,
    this.fontWeight = FontWeight.w800,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(7),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: fontWeight,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ─── Social handle field ───────────────────────────────────────────────────

class _SocialField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String badge;
  final Color badgeColor;
  final String hint;
  final Widget prefix;

  const _SocialField({
    required this.controller,
    required this.label,
    required this.badge,
    required this.badgeColor,
    required this.hint,
    required this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefix,
        // @ or handle prefix inline in the field text area
        prefix: Text(
          badge == '@' ? '@' : '',
          style: TextStyle(
            color: badgeColor.withValues(alpha: 0.8),
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        filled: true,
        fillColor: AppTheme.inputFillOf(context),
        border: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: AppTheme.dividerOf(context), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: badgeColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
        floatingLabelStyle: TextStyle(
          color: isDark ? Colors.white70 : badgeColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      keyboardType: TextInputType.text,
      autocorrect: false,
    );
  }
}
