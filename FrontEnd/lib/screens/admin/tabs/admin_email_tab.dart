import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../config/api_config.dart';
import '../../../config/theme.dart';
import '../../../repositories/admin_repository.dart';
import '../../../repositories/base_repository.dart';

class AdminEmailTab extends StatefulWidget {
  const AdminEmailTab({
    super.key,
    required this.settings,
    required this.onSnack,
    required this.onUpdateSetting,
    required this.onReloadSettings,
  });

  final List<dynamic> settings;
  final void Function(String) onSnack;
  final void Function(String key, String value) onUpdateSetting;
  final Future<void> Function() onReloadSettings;

  @override
  State<AdminEmailTab> createState() => _AdminEmailTabState();
}

class _AdminEmailTabState extends State<AdminEmailTab> {
  List<dynamic> _emailTemplates = [];
  bool _emailLoading = true;
  bool _initialLoaded = false;
  bool _logoUploading = false;

  String _settingVal(String key) {
    final s = widget.settings.cast<Map<String, dynamic>?>().firstWhere(
          (e) => e != null && e['key'] == key,
          orElse: () => null,
        );
    return s?['value']?.toString() ?? '';
  }

  @override
  void initState() {
    super.initState();
    _loadEmailTemplates();
  }

  Future<void> _loadEmailTemplates() async {
    setState(() => _emailLoading = true);
    try {
      final admin = context.read<AdminRepository>();
      final data = await admin.getEmailTemplates();
      if (mounted) {
        setState(() {
          _emailTemplates = data;
          _emailLoading = false;
          _initialLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _emailLoading = false;
          _initialLoaded = true;
        });
      }
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadEmailTemplates(), widget.onReloadSettings()]);
  }

  // ── Logo upload ──

  Future<void> _pickAndUploadLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _logoUploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final admin = context.read<AdminRepository>();
      await admin.uploadEmailLogo(fileBytes: bytes, fileName: picked.name);
      await widget.onReloadSettings();
      if (mounted) widget.onSnack('Logo uploaded');
    } catch (e) {
      if (mounted) {
        widget.onSnack('Upload failed: ${ApiError.extractMessage(e)}');
      }
    }
    if (mounted) setState(() => _logoUploading = false);
  }

  // ── Template save ──

  Future<void> _saveTemplate(
      String key, String subject, String bodyHtml, bool isActive) async {
    try {
      final admin = context.read<AdminRepository>();
      await admin.saveEmailTemplate(key,
          subject: subject, bodyHtml: bodyHtml, isActive: isActive);
      _loadEmailTemplates();
      if (mounted) widget.onSnack('Template "$key" updated');
    } catch (e) {
      if (mounted) {
        widget.onSnack('Save failed: ${ApiError.extractMessage(e)}');
      }
    }
  }

  // ── Setting edit dialog ──

  void _showEditSettingDialog(
      BuildContext context, String key, String currentValue,
      {bool multiline = false}) {
    final ctrl = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(key.replaceAll('_', ' ')),
        content: TextField(
          controller: ctrl,
          maxLines: multiline ? 4 : 1,
          decoration: const InputDecoration(
            labelText: 'Value',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onUpdateSetting(key, ctrl.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) => ctrl.dispose());
  }

  // ── Template editor dialog ──

  void _showEditTemplateDialog(
      BuildContext context, Map<String, dynamic> template) {
    final subjectCtrl =
        TextEditingController(text: template['subject'] ?? '');
    final bodyCtrl =
        TextEditingController(text: template['body_html'] ?? '');
    bool isActive = template['is_active'] == true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            'Edit: ${template['template_key']}',
            style: const TextStyle(fontSize: 16),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Variables: ${template['variables'] ?? '[]'}',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondaryOf(ctx)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Use {{variable_name}} in subject or body.',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondaryOf(ctx)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subjectCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Body HTML',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 12,
                    minLines: 6,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('Active',
                          style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textPrimaryOf(ctx))),
                      const Spacer(),
                      Switch(
                        value: isActive,
                        activeTrackColor: AppTheme.successOf(ctx),
                        onChanged: (v) =>
                            setDialogState(() => isActive = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _saveTemplate(
                  template['template_key'],
                  subjectCtrl.text,
                  bodyCtrl.text,
                  isActive,
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    ).then((_) {
      subjectCtrl.dispose();
      bodyCtrl.dispose();
    });
  }

  // ═══════════════════════════════════════════
  //  Build
  // ═══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_emailLoading && !_initialLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEmailConfigSection(context),
            const SizedBox(height: 24),
            _buildEmailTemplatesSection(context),
          ],
        ),
      ),
    );
  }

  // ── Section 1: Email Configuration ──

  Widget _buildEmailConfigSection(BuildContext context) {
    return Column(
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
                Text('Provider Settings',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppTheme.textPrimaryOf(context))),
                _boolSettingRow(context, 'email_enabled', 'Email Enabled'),
                _textSettingRow(context, 'email_provider', 'Provider'),
                _textSettingRow(
                    context, 'email_from_address', 'From Address'),
                _textSettingRow(context, 'email_from_name', 'From Name'),
                _boolSettingRow(
                    context, 'email_mock_enabled', 'Mock Mode'),
                _boolSettingRow(
                    context, 'email_digest_enabled', 'Email Digest'),
                const Divider(height: 24),
                Text('Branding',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppTheme.textPrimaryOf(context))),
                const SizedBox(height: 8),
                _buildLogoSection(context),
                const SizedBox(height: 12),
                _buildFooterTextSection(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _boolSettingRow(BuildContext context, String key, String label) {
    final val = _settingVal(key);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13))),
          Switch(
            value: val == 'true',
            activeTrackColor: AppTheme.successOf(context),
            onChanged: (on) =>
                widget.onUpdateSetting(key, on ? 'true' : 'false'),
          ),
        ],
      ),
    );
  }

  Widget _textSettingRow(BuildContext context, String key, String label) {
    final val = _settingVal(key);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(val.isEmpty ? 'Not set' : val,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryOf(context))),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: () =>
                _showEditSettingDialog(context, key, val),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSection(BuildContext context) {
    final logoUrl = _settingVal('email_template_logo_url');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Email Logo',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        if (logoUrl.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              ApiConfig.imageUrl(logoUrl),
              height: 60,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Text('Failed to load logo',
                  style:
                      TextStyle(color: AppTheme.textSecondaryOf(context))),
            ),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          icon: _logoUploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.upload, size: 18),
          label: Text(logoUrl.isEmpty ? 'Upload Logo' : 'Change Logo'),
          onPressed: _logoUploading ? null : _pickAndUploadLogo,
        ),
      ],
    );
  }

  Widget _buildFooterTextSection(BuildContext context) {
    final footerText = _settingVal('email_template_footer_text');
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Footer Text',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                footerText.isEmpty ? 'Not set' : footerText,
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryOf(context)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit, size: 18),
          onPressed: () => _showEditSettingDialog(
              context, 'email_template_footer_text', footerText,
              multiline: true),
        ),
      ],
    );
  }

  // ── Section 2: Email Templates ──

  Widget _buildEmailTemplatesSection(BuildContext context) {
    final hasCustomized =
        _emailTemplates.any((t) => t['is_customized'] == true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Email Templates (${_emailTemplates.length})',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryOf(context)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Reload templates',
              onPressed: _loadEmailTemplates,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (hasCustomized)
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
                          'This will delete all custom templates and revert to built-in defaults.'),
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
                      await context
                          .read<AdminRepository>()
                          .resetAllEmailTemplates();
                      _loadEmailTemplates();
                      if (mounted) {
                        widget.onSnack('All templates reset to defaults');
                      }
                    } catch (e) {
                      debugPrint(e.toString());
                    }
                  }
                },
              ),
            ),
          ),
        ..._emailTemplates.map((t) => _buildTemplateCard(context, t)),
      ],
    );
  }

  Widget _buildTemplateCard(BuildContext context, dynamic t) {
    final isCustomized = t['is_customized'] == true;
    final isActive = t['is_active'] == true;
    final key = t['template_key'] ?? '';

    return Card(
      color: AppTheme.cardOf(context),
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(key,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryOf(context),
                      fontSize: 14)),
            ),
            if (isCustomized)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Customized',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentColor)),
              ),
          ],
        ),
        subtitle: Text(t['subject'] ?? '',
            style: TextStyle(
                color: AppTheme.textSecondaryOf(context), fontSize: 13)),
        trailing: Icon(
            isActive ? Icons.check_circle : Icons.cancel,
            color: isActive
                ? AppTheme.successColor
                : AppTheme.errorColor,
            size: 20),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Variables: ${t['variables'] ?? '[]'}',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryOf(context))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                      onPressed: () =>
                          _showEditTemplateDialog(context, t),
                    ),
                    if (isCustomized)
                      TextButton.icon(
                        icon: const Icon(Icons.visibility, size: 16),
                        label: const Text('Preview'),
                        onPressed: () => _showPreviewDialog(context, t),
                      ),
                    TextButton.icon(
                      icon: const Icon(Icons.send, size: 16),
                      label: const Text('Test Send'),
                      onPressed: () async {
                        try {
                          await context
                              .read<AdminRepository>()
                              .testSendEmailTemplate(key);
                          if (mounted) {
                            widget.onSnack('Test email sent');
                          }
                        } catch (e) {
                          debugPrint(e.toString());
                        }
                      },
                    ),
                    if (isCustomized)
                      TextButton.icon(
                        icon: const Icon(Icons.restore, size: 16),
                        label: const Text('Reset'),
                        onPressed: () async {
                          try {
                            await context
                                .read<AdminRepository>()
                                .resetEmailTemplate(key);
                            _loadEmailTemplates();
                            if (mounted) {
                              widget.onSnack('"$key" reset to default');
                            }
                          } catch (e) {
                            debugPrint(e.toString());
                          }
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPreviewDialog(BuildContext context, dynamic t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Preview: ${t['template_key']}'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Subject: ${t['subject'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const Divider(),
                SelectableText(
                  (t['body_html'] as String?)
                          ?.replaceAll(RegExp(r'<[^>]*>'), '') ??
                      'No content',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
        ],
      ),
    );
  }
}
