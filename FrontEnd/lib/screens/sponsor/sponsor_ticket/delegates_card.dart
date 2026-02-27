import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/design_tokens.dart';
import '../../../config/theme.dart';
import '../../../models/sponsor.dart';
import '../../../services/api_service.dart';
import '../../../utils/date_time_utils.dart';
import '../../../widgets/app_toast.dart';

class DelegatesCard extends StatefulWidget {
  final int ticketId;

  const DelegatesCard({super.key, required this.ticketId});

  @override
  State<DelegatesCard> createState() => _DelegatesCardState();
}

class _DelegatesCardState extends State<DelegatesCard> {
  List<SponsorDelegate> _delegates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.listDelegates(widget.ticketId);
      if (mounted) {
        setState(() {
          _delegates = data.map((j) => SponsorDelegate.fromJson(j)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Delegate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name *'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );

    if (confirmed != true || nameCtrl.text.trim().isEmpty) return;

    try {
      final api = context.read<ApiService>();
      await api.addDelegate(
        widget.ticketId,
        nameCtrl.text.trim(),
        email:
            emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
        phone:
            phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
      );
      if (mounted) AppToast.success(context, 'Delegate added');
      _load();
    } catch (e) {
      if (mounted) AppToast.error(context, ApiService.extractError(e));
    }
  }

  Future<void> _remove(SponsorDelegate d) async {
    try {
      final api = context.read<ApiService>();
      await api.removeDelegate(widget.ticketId, d.id);
      if (mounted) AppToast.success(context, '${d.name} removed');
      _load();
    } catch (e) {
      if (mounted) AppToast.error(context, ApiService.extractError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkedIn = _delegates.where((d) => d.checkedIn).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, checkedIn),
          const SizedBox(height: 10),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else if (_delegates.isEmpty)
            _buildEmpty(context)
          else
            ..._delegates.map((d) => _DelegateRow(
                  delegate: d,
                  onRemove: () => _remove(d),
                )),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int checkedIn) {
    return Row(
      children: [
        Icon(Icons.people_outline_rounded,
            size: 18, color: AppTheme.textSecondaryOf(context)),
        const SizedBox(width: 8),
        Text(
          'Delegates',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondaryOf(context),
            letterSpacing: 0.3,
          ),
        ),
        if (_delegates.isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.1),
              borderRadius: AppRadius.pill,
            ),
            child: Text(
              '$checkedIn/${_delegates.length}',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentColor),
            ),
          ),
        ],
        const Spacer(),
        SizedBox(
          height: 30,
          child: TextButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.person_add_rounded, size: 14),
            label: const Text('Add', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8)),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(Icons.group_add_rounded,
              size: 28,
              color:
                  AppTheme.textSecondaryOf(context).withValues(alpha: 0.5)),
          const SizedBox(height: 6),
          Text('No delegates added yet',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textSecondaryOf(context))),
          const SizedBox(height: 2),
          Text('Add people who will attend on your behalf',
              style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondaryOf(context)
                      .withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

class _DelegateRow extends StatelessWidget {
  final SponsorDelegate delegate;
  final VoidCallback onRemove;

  const _DelegateRow({required this.delegate, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final d = delegate;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: d.checkedIn
              ? AppTheme.successColor.withValues(alpha: 0.06)
              : AppTheme.surfaceOf(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: d.checkedIn
                ? AppTheme.successColor.withValues(alpha: 0.2)
                : AppTheme.dividerOf(context),
          ),
        ),
        child: Row(
          children: [
            Icon(
              d.checkedIn
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: d.checkedIn
                  ? AppTheme.successColor
                  : AppTheme.textSecondaryOf(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryOf(context),
                      )),
                  if (d.email != null || d.phone != null)
                    Text(
                      [d.email, d.phone]
                          .where((s) => s != null)
                          .join(' \u2022 '),
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondaryOf(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (d.checkedIn && d.checkedInAt != null)
                    Text(
                        'Checked in ${AppDateFormat.isoShort(d.checkedInAt)}',
                        style: TextStyle(
                            fontSize: 10, color: AppTheme.successColor)),
                ],
              ),
            ),
            if (!d.checkedIn)
              IconButton(
                onPressed: onRemove,
                icon: Icon(Icons.close_rounded,
                    size: 18,
                    color: AppTheme.errorColor.withValues(alpha: 0.7)),
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                tooltip: 'Remove delegate',
              ),
          ],
        ),
      ),
    );
  }
}
