import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/design_tokens.dart';
import '../../config/theme.dart';
import '../../models/poll.dart';
import '../../providers/poll_provider.dart';
import '../../widgets/app_toast.dart';

/// Shown as a modal bottom sheet for organizers to create and manage live polls.
/// Call [showCreatePollSheet] to display it.
void showCreatePollSheet(BuildContext context, int eventId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CreatePollSheet(eventId: eventId),
  );
}

class _CreatePollSheet extends StatefulWidget {
  final int eventId;
  const _CreatePollSheet({required this.eventId});

  @override
  State<_CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends State<_CreatePollSheet> {
  final _questionCtrl = TextEditingController();
  final List<TextEditingController> _optionCtrls = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _showResultsWhileOpen = true;
  bool _saving = false;

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionCtrls.length >= 6) return;
    setState(() => _optionCtrls.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_optionCtrls.length <= 2) return;
    final ctrl = _optionCtrls.removeAt(index);
    ctrl.dispose();
    setState(() {});
  }

  Future<void> _submit() async {
    final question = _questionCtrl.text.trim();
    if (question.isEmpty) {
      AppToast.error(context, 'Question is required');
      return;
    }
    final options =
        _optionCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (options.length < 2) {
      AppToast.error(context, 'At least 2 options are required');
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<PollProvider>().createPoll(
            widget.eventId,
            CreatePollRequest(
              question: question,
              options: options,
              showResultsWhileOpen: _showResultsWhileOpen,
            ),
          );
      if (mounted) {
        Navigator.pop(context);
        AppToast.success(context, 'Poll created');
      }
    } catch (e) {
      if (mounted) AppToast.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final poll = context.watch<PollProvider>().activePoll;
    final hasActivePoll = poll != null && !poll.isClosed;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Live Poll',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
              if (hasActivePoll) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: AppTheme.warningColor),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Creating a new poll will close the current active poll.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.warningColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _questionCtrl,
                decoration: InputDecoration(
                  labelText: 'Question',
                  hintText: 'e.g. How are you enjoying the event?',
                  filled: true,
                  fillColor: AppTheme.surfaceOf(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Options (${_optionCtrls.length}/6)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...List.generate(_optionCtrls.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _optionCtrls[i],
                          decoration: InputDecoration(
                            labelText: 'Option ${i + 1}',
                            filled: true,
                            fillColor: AppTheme.surfaceOf(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ),
                      if (_optionCtrls.length > 2) ...[
                        const SizedBox(width: AppSpacing.sm),
                        IconButton(
                          onPressed: () => _removeOption(i),
                          icon: Icon(Icons.remove_circle_outline_rounded,
                              color: AppTheme.errorColor),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              if (_optionCtrls.length < 6)
                TextButton.icon(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Option'),
                ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show results while poll is open',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text(
                  'If off, results are hidden until you close the poll',
                  style: TextStyle(fontSize: 11),
                ),
                value: _showResultsWhileOpen,
                activeTrackColor: AppTheme.accentColor,
                onChanged: (v) => setState(() => _showResultsWhileOpen = v),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Launch Poll',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Close active poll button
              if (hasActivePoll)
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _saving ? null : () => _closePoll(poll.id),
                    child: Text(
                      'Close Active Poll',
                      style: TextStyle(color: AppTheme.errorColor),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _closePoll(int pollId) async {
    setState(() => _saving = true);
    try {
      await context.read<PollProvider>().closePoll(widget.eventId, pollId);
      if (mounted) {
        Navigator.pop(context);
        AppToast.success(context, 'Poll closed');
      }
    } catch (e) {
      if (mounted) AppToast.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
