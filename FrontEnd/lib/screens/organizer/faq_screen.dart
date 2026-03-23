import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/design_tokens.dart';
import '../../config/theme.dart';
import '../../models/faq.dart';
import '../../providers/faq_provider.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/shimmer_loaders.dart';

class OrganizerFaqScreen extends StatefulWidget {
  const OrganizerFaqScreen({super.key});

  @override
  State<OrganizerFaqScreen> createState() => _OrganizerFaqScreenState();
}

class _OrganizerFaqScreenState extends State<OrganizerFaqScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FaqProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FaqProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('FAQ Library')),
      body: provider.loading
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List.generate(3, (_) => const ShimmerListTile()),
              ),
            )
          : provider.faqs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceOf(context),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Icon(Icons.quiz_rounded,
                            size: 40,
                            color: AppTheme.textSecondaryOf(context)),
                      ),
                      const SizedBox(height: 16),
                      Text('No FAQ items yet',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryOf(context))),
                      const SizedBox(height: 4),
                      Text('Tap + to add your first Q&A',
                          style: TextStyle(
                              color: AppTheme.textSecondaryOf(context))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: provider.load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: provider.faqs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _FaqTile(faq: provider.faqs[i]),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, null),
        backgroundColor: AppTheme.accentColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add FAQ'),
      ),
    );
  }

  void _showForm(BuildContext context, OrganizerFaq? faq) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FaqFormSheet(faq: faq),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final OrganizerFaq faq;
  const _FaqTile({required this.faq});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<FaqProvider>();
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(AppRadius.lgValue),
        boxShadow: AppShadow.soft(AppTheme.isDark(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    faq.question,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    faq.answer,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: faq.isActive
                          ? AppTheme.accentColor.withValues(alpha: 0.12)
                          : AppTheme.surfaceOf(context),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      faq.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: faq.isActive
                            ? AppTheme.accentColor
                            : AppTheme.textSecondaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                IconButton(
                  onPressed: () => _showForm(context, faq),
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  tooltip: 'Edit',
                  color: AppTheme.textSecondaryOf(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 8),
                IconButton(
                  onPressed: () async {
                    try {
                      await provider.toggleActive(faq);
                    } catch (e) {
                      if (context.mounted) {
                        AppToast.error(context, e.toString());
                      }
                    }
                  },
                  icon: Icon(
                    faq.isActive
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 20,
                  ),
                  tooltip: faq.isActive ? 'Deactivate' : 'Activate',
                  color: AppTheme.textSecondaryOf(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 8),
                IconButton(
                  onPressed: () => _confirmDelete(context, faq),
                  icon: const Icon(Icons.delete_rounded, size: 20),
                  tooltip: 'Delete',
                  color: AppTheme.errorColor,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showForm(BuildContext context, OrganizerFaq faq) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FaqFormSheet(faq: faq),
    );
  }

  void _confirmDelete(BuildContext context, OrganizerFaq faq) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete FAQ'),
        content: const Text('Are you sure you want to delete this FAQ item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await context.read<FaqProvider>().delete(faq.id);
              } catch (e) {
                if (context.mounted) {
                  AppToast.error(context, e.toString());
                }
              }
            },
            child: Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }
}

class _FaqFormSheet extends StatefulWidget {
  final OrganizerFaq? faq;
  const _FaqFormSheet({this.faq});

  @override
  State<_FaqFormSheet> createState() => _FaqFormSheetState();
}

class _FaqFormSheetState extends State<_FaqFormSheet> {
  late final TextEditingController _questionCtrl;
  late final TextEditingController _answerCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _questionCtrl = TextEditingController(text: widget.faq?.question ?? '');
    _answerCtrl = TextEditingController(text: widget.faq?.answer ?? '');
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _answerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.faq != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEdit ? 'Edit FAQ' : 'Add FAQ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _questionCtrl,
              decoration: InputDecoration(
                labelText: 'Question',
                hintText: 'e.g. Is there parking available?',
                filled: true,
                fillColor: AppTheme.surfaceOf(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _answerCtrl,
              decoration: InputDecoration(
                labelText: 'Answer',
                hintText: 'Provide a clear, helpful answer',
                filled: true,
                fillColor: AppTheme.surfaceOf(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 20),
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
                    : Text(isEdit ? 'Save Changes' : 'Add FAQ',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final q = _questionCtrl.text.trim();
    final a = _answerCtrl.text.trim();
    if (q.isEmpty || a.isEmpty) {
      AppToast.error(context, 'Question and answer are required');
      return;
    }
    setState(() => _saving = true);
    try {
      final provider = context.read<FaqProvider>();
      if (widget.faq == null) {
        await provider.create(CreateFaqRequest(question: q, answer: a));
      } else {
        await provider.update(
          widget.faq!.id,
          UpdateFaqRequest(question: q, answer: a),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) AppToast.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
