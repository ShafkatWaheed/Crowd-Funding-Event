import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/faq.dart';
import '../../repositories/faq_repository.dart';
import '../../repositories/base_repository.dart';

/// Read-only FAQ screen for attendees — fetches FAQs for a given event.
/// Uses FaqRepository directly (single one-shot fetch, no shared state needed).
class EventFaqScreen extends StatefulWidget {
  final int eventId;
  const EventFaqScreen({super.key, required this.eventId});

  @override
  State<EventFaqScreen> createState() => _EventFaqScreenState();
}

class _EventFaqScreenState extends State<EventFaqScreen> {
  List<OrganizerFaq> _faqs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = context.read<FaqRepository>();
      final faqs = await repo.getEventFaqs(widget.eventId);
      if (mounted) setState(() { _faqs = faqs; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() { _error = ApiError.extractMessage(e); _loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Frequently Asked Questions')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 48, color: AppTheme.errorColor),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: TextStyle(
                              color: AppTheme.textSecondaryOf(context))),
                      const SizedBox(height: 16),
                      TextButton(
                          onPressed: () {
                            setState(() { _loading = true; _error = null; });
                            _load();
                          },
                          child: const Text('Retry')),
                    ],
                  ),
                )
              : _faqs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.quiz_rounded,
                              size: 48,
                              color: AppTheme.textSecondaryOf(context)),
                          const SizedBox(height: 12),
                          Text('No FAQ available for this event',
                              style: TextStyle(
                                  color: AppTheme.textSecondaryOf(context))),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount: _faqs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (_, i) => _FaqExpansionTile(faq: _faqs[i]),
                    ),
    );
  }
}

class _FaqExpansionTile extends StatelessWidget {
  final OrganizerFaq faq;
  const _FaqExpansionTile({required this.faq});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(Icons.help_outline_rounded,
              color: AppTheme.accentColor, size: 22),
          title: Text(
            faq.question,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppTheme.textPrimaryOf(context),
            ),
          ),
          children: [
            Text(
              faq.answer,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
