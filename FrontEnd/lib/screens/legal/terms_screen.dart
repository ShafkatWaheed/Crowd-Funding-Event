import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../config/terms_content.dart';

/// Full-screen Terms & Conditions viewer.
///
/// Pass [role] as `'organizer'` or `'customer'` to display the appropriate
/// agreement. Used from both the register screen (pre-auth) and the profile
/// screen (post-auth).
class TermsScreen extends StatelessWidget {
  final String role;

  const TermsScreen({super.key, required this.role});

  bool get _isOrganizer => role == 'organizer';

  @override
  Widget build(BuildContext context) {
    final termsText =
        _isOrganizer ? TermsContent.organizerTerms : TermsContent.customerTerms;

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Terms & Conditions'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Role badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isOrganizer
                        ? Colors.deepPurple.withValues(alpha: 0.1)
                        : AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isOrganizer ? Icons.event : Icons.person,
                        size: 14,
                        color: _isOrganizer
                            ? Colors.deepPurple
                            : AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isOrganizer
                            ? 'Organizer Agreement'
                            : 'Customer Agreement',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _isOrganizer
                              ? Colors.deepPurple
                              : AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'Updated ${TermsContent.lastUpdated}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Terms content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SelectableText(
                      termsText.trim(),
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.7,
                        color: Color(0xFF333333),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
