import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../config/design_tokens.dart';
import '../../widgets/press_feedback.dart';
import '../../widgets/app_toast.dart';
import 'profile_section_card.dart';

class ProfileSecuritySection extends StatelessWidget {
  const ProfileSecuritySection({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      title: 'Security',
      icon: Icons.shield_outlined,
      delay: 350,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardOf(context),
            borderRadius: AppRadius.md,
            border: Border.all(color: AppTheme.dividerOf(context)),
          ),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.warningSurfaceOf(context),
                borderRadius: AppRadius.md,
              ),
              child: Icon(Icons.lock_outline_rounded,
                  size: 20, color: context.fundingAccent),
            ),
            title: Text('Change Password',
                style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimaryOf(context))),
            subtitle: Text('Update your account password',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryOf(context))),
            trailing: Icon(Icons.chevron_right_rounded,
                color: AppTheme.textSecondaryOf(context)),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
            onTap: () => _changePassword(context),
          ),
        ),
      ],
    );
  }

  Future<void> _changePassword(BuildContext context) async {
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
                            AppToast.success(
                                context, 'Password changed successfully');
                          }
                        } on FirebaseAuthException catch (e) {
                          setDialogState(() => loading = false);
                          if (ctx.mounted) {
                            AppToast.error(
                                ctx,
                                e.code == 'wrong-password'
                                    ? 'Current password is incorrect'
                                    : e.message ?? 'Authentication error');
                          }
                        } catch (e) {
                          setDialogState(() => loading = false);
                          if (ctx.mounted) {
                            AppToast.fromError(ctx, e,
                                fallback: 'Password change failed');
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
}
