import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

/// Modern toast / snackbar helpers used across the app.
///
/// Usage:
///   AppToast.error(context, 'Something went wrong');
///   AppToast.success(context, 'Event published!');
///   AppToast.fromError(context, e);   // auto-extracts backend detail
class AppToast {
  AppToast._();

  // ── Error (red) ──
  static void error(BuildContext context, String message) {
    _show(context,
      message: message,
      icon: Icons.error_outline_rounded,
      backgroundColor: AppTheme.errorColor,
    );
  }

  // ── Success (green) ──
  static void success(BuildContext context, String message) {
    _show(context,
      message: message,
      icon: Icons.check_circle_outline_rounded,
      backgroundColor: AppTheme.successColor,
    );
  }

  // ── Warning (orange) ──
  static void warning(BuildContext context, String message) {
    _show(context,
      message: message,
      icon: Icons.warning_amber_rounded,
      backgroundColor: Colors.orange,
    );
  }

  // ── Info (blue) ──
  static void info(BuildContext context, String message) {
    _show(context,
      message: message,
      icon: Icons.info_outline_rounded,
      backgroundColor: AppTheme.primaryColor,
    );
  }

  /// Auto-extract the error message from an exception and show an error toast.
  static void fromError(BuildContext context, Object e, {String fallback = 'Something went wrong'}) {
    error(context, ApiService.extractError(e, fallback: fallback));
  }

  // ── Internal ──
  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color backgroundColor,
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 6,
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }
}
