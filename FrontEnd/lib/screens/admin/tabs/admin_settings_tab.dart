import 'package:flutter/material.dart';

import '../../../config/design_tokens.dart';
import '../../../config/theme.dart';
import '../../../widgets/admin/admin_empty_state.dart';
import 'banking/banking_escrow_config.dart';

class AdminSettingsTab extends StatefulWidget {
  const AdminSettingsTab({
    super.key,
    required this.settings,
    required this.onUpdateSetting,
    required this.onReloadSettings,
  });

  final List<dynamic> settings;
  final void Function(String key, String value) onUpdateSetting;
  final Future<void> Function() onReloadSettings;

  @override
  State<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<AdminSettingsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // ── Tab → group mapping ──
  static const _tabDefs = [
    {'label': 'General', 'icon': Icons.dashboard, 'groups': ['Branding', 'Feature Flags', 'Push Notifications']},
    {'label': 'Financial', 'icon': Icons.monetization_on, 'groups': ['Commissions', 'Financial Policy', 'Community Rules']},
    {'label': 'Events', 'icon': Icons.event, 'groups': ['Events', 'Event Limits', 'Ticket Limits']},
    {'label': 'Security', 'icon': Icons.security, 'groups': ['API Rate Limits', 'KYC', 'File Uploads', 'Banking']},
    {'label': 'Infrastructure', 'icon': Icons.build_circle, 'groups': ['Cache', 'Cache TTLs', 'Stampede Prevention', 'Circuit Breaker', 'Offline / Sync', 'Infrastructure', 'Chat']},
    {'label': 'Escrow', 'icon': Icons.lock_clock, 'groups': <String>[]},
  ];

  // ── Group → setting keys ──
  static const _settingsGroups = {
    'Branding': ['platform_name', 'support_email'],
    'Commissions': ['ticket_commission_percent', 'funding_commission_percent', 'sponsor_commission_percent'],
    'Events': ['cancel_approval_threshold_percent', 'event_date_grace_days', 'event_date_deadline_days', 'default_refund_deadline_days'],
    'Community Rules': ['community_max_duration_days', 'community_max_ticket_price_cents', 'community_listing_fee_cents', 'community_ticket_commission_percent', 'community_funding_commission_percent', 'community_sponsor_commission_percent', 'community_escrow_disabled', 'new_organizer_deposit_cents'],
    'Ticket Limits': ['max_tickets_per_purchase', 'max_tickets_backend_enabled', 'max_tickets_frontend_enabled'],
    'API Rate Limits': ['rate_limit_global_default', 'rate_limit_auth_verify', 'rate_limit_public_config', 'rate_limit_event_register', 'rate_limit_ticket_purchase', 'rate_limit_pledge', 'rate_limit_file_upload', 'rate_limit_payment_action', 'rate_limit_event_create', 'rate_limit_content_create', 'rate_limit_public_search', 'rate_limit_social_action', 'rate_limit_qr_scan'],
    'Feature Flags': ['feature_milestones_enabled', 'feature_schedule_enabled', 'feature_sponsors_enabled', 'feature_community_rules_enabled'],
    'Push Notifications': ['push_notifications_enabled'],
    'File Uploads': ['upload_max_image_size_mb', 'upload_max_document_size_mb', 'upload_allowed_image_types', 'upload_allowed_document_types'],
    'Cache': ['cache_enabled'],
    'Cache TTLs': ['cache_ttl_settings', 'cache_ttl_featured', 'cache_ttl_event_detail', 'cache_ttl_dashboard', 'cache_ttl_cities', 'cache_ttl_genres', 'cache_ttl_map', 'cache_ttl_admin_dashboard'],
    'Stampede Prevention': ['cache_stampede_lock_ttl', 'cache_stampede_retry_ms', 'cache_beta_featured', 'cache_beta_event_detail', 'cache_beta_map', 'cache_beta_dashboard'],
    'Circuit Breaker': ['cache_circuit_breaker_threshold', 'cache_circuit_breaker_cooldown'],
    'Offline / Sync': ['offline_scan_enabled', 'offline_scan_max_queue', 'offline_scan_sync_interval', 'client_event_cache_max_age_hours', 'client_sync_on_launch'],
    'Infrastructure': ['worker_run_log_retention_days', 'notification_retention_days', 'cron_reconciliation_hour', 'cron_payout_hour', 'cron_escrow_check_interval_min'],
    'Financial Policy': ['payout_minimum_cents', 'max_events_per_organizer', 'escrow_trust_score_threshold', 'max_dispute_days_after_event', 'max_push_notifications_per_hour', 'email_digest_enabled'],
    'Email Branding': ['email_template_logo_url', 'email_template_footer_text'],
    'Event Limits': ['waitlist_max_size_limit', 'waitlist_auto_approve_default', 'event_max_images_limit', 'max_posts_per_event_limit', 'max_co_organizers_limit', 'refund_deadline_percent_min', 'refund_deadline_percent_max'],
    'KYC': ['kyc_required_organizer', 'kyc_required_customer', 'kyc_required_sponsor', 'kyc_mock_enabled', 'mock_kyc_latency_min_ms', 'mock_kyc_latency_max_ms', 'mock_kyc_failure_rate_percent'],
    'Banking': ['bank_encryption_key', 'bank_verification_delay_seconds'],
    'Chat': ['chat_enabled', 'chat_max_message_length', 'chat_stream_maxlen', 'chat_archive_retention_days'],
  };

  static const _groupIcons = {
    'Branding': Icons.palette,
    'Commissions': Icons.monetization_on,
    'Events': Icons.event,
    'Community Rules': Icons.groups,
    'Ticket Limits': Icons.confirmation_number,
    'API Rate Limits': Icons.speed,
    'Feature Flags': Icons.toggle_on_rounded,
    'Push Notifications': Icons.notifications_active,
    'File Uploads': Icons.upload_file,
    'Cache': Icons.cached,
    'Cache TTLs': Icons.timer_outlined,
    'Stampede Prevention': Icons.shield_outlined,
    'Circuit Breaker': Icons.flash_off_rounded,
    'Offline / Sync': Icons.sync,
    'Infrastructure': Icons.build_circle,
    'Financial Policy': Icons.account_balance,
    'Email Branding': Icons.email,
    'Event Limits': Icons.tune,
    'KYC': Icons.verified_user,
    'Banking': Icons.account_balance_rounded,
    'Chat': Icons.chat_rounded,
  };

  static const _triggerModeOptions = <String, List<String>>{};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabDefs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  String _settingVal(String key) {
    final s = widget.settings
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (e) => e != null && e['key'] == key,
          orElse: () => null,
        );
    return s?['value']?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.settings.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await widget.onReloadSettings();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: 400,
            child: AdminEmptyState(icon: Icons.settings, message: 'No settings loaded'),
          ),
        ),
      );
    }

    return Column(
      children: [
        TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppTheme.accentOf(context),
          unselectedLabelColor: AppTheme.textSecondaryOf(context),
          indicatorColor: AppTheme.accentOf(context),
          tabs: _tabDefs.map((t) => Tab(
            icon: Icon(t['icon'] as IconData, size: 18),
            text: t['label'] as String,
          )).toList(),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: _tabDefs.map((t) {
              final label = t['label'] as String;
              if (label == 'Escrow') {
                return RefreshIndicator(
                  onRefresh: () async => widget.onReloadSettings(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 700),
                        child: BankingEscrowConfigSection(
                          settingVal: _settingVal,
                          onUpdateSetting: widget.onUpdateSetting,
                        ),
                      ),
                    ),
                  ),
                );
              }
              final groups = t['groups'] as List<String>;
              return _buildGroupList(groups);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupList(List<String> groupNames) {
    final settingsMap = {for (var s in widget.settings) s['key']: s};

    return RefreshIndicator(
      onRefresh: () async {
        await widget.onReloadSettings();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: groupNames.map((groupName) {
                final keys = _settingsGroups[groupName];
                if (keys == null) return const SizedBox.shrink();

                final groupSettings = keys
                    .map((k) => settingsMap[k])
                    .where((s) => s != null)
                    .toList();
                if (groupSettings.isEmpty) return const SizedBox.shrink();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
                  child: ExpansionTile(
                    leading: Icon(_groupIcons[groupName] ?? Icons.settings, size: 22),
                    title: Text(groupName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    initiallyExpanded: groupNames.indexOf(groupName) == 0,
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: groupSettings.map((s) => _settingRow(context, s!)).toList(),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  static final _rateLimitPattern = RegExp(r'^\d+/(second|minute|hour|day)$');

  Widget _settingRow(BuildContext context, Map<String, dynamic> s) {
    final key = s['key'] ?? '';
    final value = s['value'] ?? '';
    final desc = s['description'] ?? '';
    final isRateLimit = key.startsWith('rate_limit_');
    final isPercent = !isRateLimit && key.contains('percent');
    final isCents = key.contains('_cents');
    final isBool = value == 'true' || value == 'false';
    final isDropdown = _triggerModeOptions.containsKey(key);

    String displayValue = value;
    if (isBool) {
      displayValue = value == 'true' ? 'ON' : 'OFF';
    } else if (isPercent) {
      displayValue = '$value%';
    } else if (isCents) {
      final parsed = int.tryParse(value);
      displayValue = parsed != null ? '\$${(parsed / 100).toStringAsFixed(2)}' : value;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(key.replaceAll('_', ' '),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (desc.isNotEmpty)
                  Text(desc, style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (isBool)
            Switch(
              value: value == 'true',
              activeTrackColor: AppTheme.successOf(context),
              onChanged: (on) => widget.onUpdateSetting(key, on ? 'true' : 'false'),
            )
          else if (isDropdown)
            DropdownButton<String>(
              value: _triggerModeOptions[key]!.contains(value) ? value : _triggerModeOptions[key]!.first,
              underline: const SizedBox.shrink(),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.accentOf(context)),
              items: _triggerModeOptions[key]!.map((opt) => DropdownMenuItem(
                value: opt,
                child: Text(opt.replaceAll('_', ' ')),
              )).toList(),
              onChanged: (v) { if (v != null) widget.onUpdateSetting(key, v); },
            )
          else ...[
            Flexible(
              child: Text(displayValue,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentOf(context))),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              tooltip: 'Edit',
              onPressed: () => _showEditSettingDialog(context, key, value, isPercent, isRateLimit: isRateLimit),
            ),
          ],
        ],
      ),
    );
  }

  void _showEditSettingDialog(BuildContext context, String key, String currentValue, bool isPercent, {bool isRateLimit = false}) {
    final ctrl = TextEditingController(text: currentValue);
    String? errorText;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Edit ${key.replaceAll('_', ' ')}'),
          content: TextField(
            controller: ctrl,
            keyboardType: isRateLimit ? TextInputType.text : TextInputType.number,
            decoration: InputDecoration(
              labelText: isRateLimit ? 'e.g. 60/minute' : 'Value',
              suffixText: isPercent ? '%' : null,
              helperText: isRateLimit ? 'Format: N/second, N/minute, N/hour, or N/day' : null,
              errorText: errorText,
            ),
            onChanged: (v) {
              if (isRateLimit) {
                setDialogState(() {
                  errorText = _rateLimitPattern.hasMatch(v.trim()) ? null : 'Must be N/second, N/minute, N/hour, or N/day';
                });
              } else if (isPercent) {
                final n = int.tryParse(v);
                setDialogState(() {
                  errorText = (n == null || n < 0 || n > 100) ? 'Must be 0-100' : null;
                });
              } else if (key.contains('_cents') || key.contains('_days')) {
                final n = int.tryParse(v);
                setDialogState(() {
                  errorText = (n == null || n < 0) ? 'Must be a non-negative number' : null;
                });
              }
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: errorText != null
                  ? null
                  : () {
                      Navigator.of(ctx).pop();
                      widget.onUpdateSetting(key, ctrl.text.trim());
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    ).then((_) => ctrl.dispose());
  }
}
