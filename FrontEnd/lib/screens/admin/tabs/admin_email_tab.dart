import 'package:flutter/material.dart';

import '../admin_shared.dart';
import '../../../config/theme.dart';
import '../../../services/api_service.dart';

class AdminEmailTab extends StatefulWidget {
  final void Function(String) onSnack;

  const AdminEmailTab({
    super.key,
    required this.onSnack,
  });

  @override
  State<AdminEmailTab> createState() => _AdminEmailTabState();
}

class _AdminEmailTabState extends State<AdminEmailTab> {
  List<dynamic> _emailTemplates = [];
  bool _emailLoading = false;

  Future<void> _loadEmailTemplates() async {
    setState(() => _emailLoading = true);
    try {
      final resp = await ApiService.instance.dio.get('/admin/email-templates');
      final data = resp.data;
      if (mounted) {
        setState(() {
          _emailTemplates = data is List ? List<dynamic>.from(data) : [];
          _emailLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _emailLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_emailTemplates.isEmpty && !_emailLoading) _loadEmailTemplates();
    if (_emailLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _loadEmailTemplates,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email Configuration',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: 8),
            Card(
              color: AppTheme.cardOf(context),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Configure email provider and templates from platform settings.',
                        style:
                            TextStyle(color: AppTheme.textSecondaryOf(context))),
                    const SizedBox(height: 8),
                    Text(
                        'Provider settings: email_enabled, email_provider, email_from_address, email_from_name',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryOf(context))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
                'Email Templates (${_emailTemplates.length})',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryOf(context))),
            const SizedBox(height: 8),
            if (_emailTemplates.isEmpty)
              Card(
                color: AppTheme.cardOf(context),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                      'No custom templates. All emails use default hardcoded templates.',
                      style:
                          TextStyle(color: AppTheme.textSecondaryOf(context))),
                ),
              ),
            if (_emailTemplates.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('Reset All to Defaults'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: BorderSide(
                          color: AppTheme.errorColor.withValues(alpha: 0.4)),
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Reset All Templates?'),
                          content: const Text(
                              'This will delete all custom email templates and revert to built-in defaults.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text('Reset All',
                                    style: TextStyle(
                                        color: AppTheme.errorColor))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        try {
                          await ApiService.instance
                              .post('/admin/email-templates/reset-all', {});
                          _loadEmailTemplates();
                          if (mounted) {
                            widget.onSnack('All templates reset to defaults');
                          }
                        } catch (e) { debugPrint(e.toString()); }
                      }
                    },
                  ),
                ),
              ),
            ..._emailTemplates.map((t) => Card(
                  color: AppTheme.cardOf(context),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    title: Text(
                        t['template_key'] ?? '',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryOf(context))),
                    subtitle: Text(
                        t['subject'] ?? '',
                        style: TextStyle(
                            color: AppTheme.textSecondaryOf(context),
                            fontSize: 13)),
                    trailing: Icon(
                        t['is_active'] == true
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: t['is_active'] == true
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                        size: 20),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Variables: ${t['variables'] ?? '[]'}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        AppTheme.textSecondaryOf(context))),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.visibility, size: 16),
                                  label: const Text('Preview'),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text(
                                            'Preview: ${t['template_key']}'),
                                        content: SizedBox(
                                          width: double.maxFinite,
                                          height: 400,
                                          child: SingleChildScrollView(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                    'Subject: ${t['subject'] ?? ''}',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600)),
                                                const Divider(),
                                                SelectableText(
                                                  (t['body_html'] as String?)
                                                          ?.replaceAll(
                                                              RegExp(
                                                                  r'<[^>]*>'),
                                                              '') ??
                                                      'No content',
                                                  style: const TextStyle(
                                                      fontSize: 13),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text('Close'))
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  icon: const Icon(Icons.send, size: 16),
                                  label: const Text('Test Send'),
                                  onPressed: () async {
                                    try {
                                      await ApiService.instance.post(
                                          '/admin/email-templates/${t['template_key']}/test-send',
                                          {});
                                      if (mounted) {
                                        widget.onSnack('Test email sent');
                                      }
                                    } catch (e) { debugPrint(e.toString()); }
                                  },
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  icon: const Icon(Icons.restore, size: 16),
                                  label: const Text('Reset'),
                                  onPressed: () async {
                                    try {
                                      await ApiService.instance.post(
                                          '/admin/email-templates/${t['template_key']}/reset',
                                          {});
                                      _loadEmailTemplates();
                                    } catch (e) { debugPrint(e.toString()); }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
