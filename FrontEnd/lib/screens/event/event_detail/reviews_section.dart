import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../providers/auth_provider.dart';
import '../../../repositories/base_repository.dart';
import '../../../providers/event_provider.dart';
import '../../../widgets/app_toast.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/star_rating.dart';

class ReviewsSection extends StatefulWidget {
  final int eventId;
  final int organizerId;
  const ReviewsSection({super.key, required this.eventId, required this.organizerId});

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  Map<String, dynamic>? _summary;
  bool _loading = true;
  int _selectedStars = 0;
  final _descCtrl = TextEditingController();
  bool _submitting = false;
  int _selectedOrgStars = 0;
  final _orgDescCtrl = TextEditingController();
  bool _submittingOrg = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _orgDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = context.read<EventProvider>();
      final data = await repo.getEventRatingsSummary(widget.eventId);
      if (mounted) setState(() { _summary = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedStars == 0 || _submitting) return;
    setState(() => _submitting = true);
    try {
      final repo = context.read<EventProvider>();
      await repo.createRating(
        widget.eventId,
        direction: 'customer_to_event',
        stars: _selectedStars,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      );
      if (mounted) {
        AppToast.success(context, 'Rating submitted!');
        _descCtrl.clear();
        _selectedStars = 0;
        _load();
      }
    } catch (e) {
      if (mounted) AppToast.error(context, ApiError.extractMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitOrgRating() async {
    if (_selectedOrgStars == 0 || _submittingOrg) return;
    setState(() => _submittingOrg = true);
    try {
      final repo = context.read<EventProvider>();
      await repo.createRating(
        widget.eventId,
        direction: 'customer_to_organizer',
        ratedUserId: widget.organizerId,
        stars: _selectedOrgStars,
        description: _orgDescCtrl.text.trim().isEmpty ? null : _orgDescCtrl.text.trim(),
      );
      if (mounted) {
        AppToast.success(context, 'Organizer rating submitted!');
        _orgDescCtrl.clear();
        _selectedOrgStars = 0;
        _load();
      }
    } catch (e) {
      if (mounted) AppToast.error(context, ApiError.extractMessage(e));
    } finally {
      if (mounted) setState(() => _submittingOrg = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_summary == null) return const SizedBox.shrink();

    final avgStars = _summary!['avg_stars'] as double?;
    final count = _summary!['count'] as int? ?? 0;
    final topReviews = (_summary!['top_reviews'] as List?) ?? [];
    final worstReviews = (_summary!['worst_reviews'] as List?) ?? [];
    final myRating = _summary!['my_rating'];
    final myOrgRating = _summary!['my_organizer_rating'];
    final user = context.watch<AuthProvider>().user;
    final isCustomer = user != null && user.isCustomer;
    final isOrganizer = user != null && (user.isOrganizer || user.isAdmin);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0).copyWith(top: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Row(
              children: [
                Icon(Icons.reviews_rounded, size: AppIconSize.sm, color: context.reviewAccent),
                AppSpacing.hSm,
                Text('Reviews',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryOf(context))),
              ],
            ),
          ),
          AppSpacing.vMd,

          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Container(
              padding: AppSpacing.paddingLg,
              decoration: BoxDecoration(
                color: AppTheme.cardOf(context),
                borderRadius: AppRadius.lg,
                border: Border.all(color: AppTheme.dividerOf(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StarRatingDisplay(avgStars: avgStars, count: count, size: 22),
                  if (count == 0)
                    Padding(
                      padding: EdgeInsets.only(top: AppSpacing.sm),
                      child: EmptyState(
                        icon: Icons.reviews_outlined,
                        title: 'No reviews yet',
                        subtitle: 'Be the first to rate!',
                      ),
                    ),

                  if (topReviews.isNotEmpty) ...[
                    AppSpacing.vLg,
                    Text('Top Reviews',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondaryOf(context))),
                    AppSpacing.vSm,
                    ...topReviews.take(5).map((r) => _reviewCard(r)),
                  ],

                  if (worstReviews.isNotEmpty && worstReviews.first['stars'] < 4) ...[
                    AppSpacing.vLg,
                    Text('Critical Reviews',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondaryOf(context))),
                    AppSpacing.vSm,
                    ...worstReviews.take(5).map((r) => _reviewCard(r)),
                  ],

                  if (isCustomer && myRating == null) ...[
                    Divider(height: AppSpacing.xxl),
                    Text('Rate this event',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryOf(context))),
                    AppSpacing.vSm,
                    StarRating(
                      rating: _selectedStars,
                      onChanged: (v) => setState(() => _selectedStars = v),
                      size: 36,
                    ),
                    AppSpacing.vMd,
                    TextField(
                      controller: _descCtrl,
                      decoration: InputDecoration(
                        hintText: 'Write your review (optional)...',
                        filled: true,
                        fillColor: AppTheme.inputFillOf(context),
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.md,
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                      ),
                      maxLines: 3,
                    ),
                    AppSpacing.vMd,
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selectedStars > 0 && !_submitting ? _submit : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.photoAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
                        ),
                        child: _submitting
                            ? SizedBox(width: AppIconSize.md, height: AppIconSize.md, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Submit Rating', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],

                  if (isCustomer && myRating != null)
                    Padding(
                      padding: EdgeInsets.only(top: AppSpacing.md),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded, size: AppIconSize.sm, color: AppTheme.successColor),
                          AppSpacing.hSm,
                          Text('Event: ${myRating['stars']} star${myRating['stars'] == 1 ? '' : 's'}',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.successColor)),
                        ],
                      ),
                    ),

                  if (isCustomer && myOrgRating == null) ...[
                    Divider(height: AppSpacing.xxl),
                    Text('Rate the organizer',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryOf(context))),
                    AppSpacing.vSm,
                    StarRating(
                      rating: _selectedOrgStars,
                      onChanged: (v) => setState(() => _selectedOrgStars = v),
                      size: 36,
                    ),
                    AppSpacing.vMd,
                    TextField(
                      controller: _orgDescCtrl,
                      decoration: InputDecoration(
                        hintText: 'How was the organizer? (optional)...',
                        filled: true,
                        fillColor: AppTheme.inputFillOf(context),
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.md,
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                      ),
                      maxLines: 3,
                    ),
                    AppSpacing.vMd,
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selectedOrgStars > 0 && !_submittingOrg ? _submitOrgRating : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.feedAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
                        ),
                        child: _submittingOrg
                            ? SizedBox(width: AppIconSize.md, height: AppIconSize.md, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Submit Organizer Rating', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],

                  if (isCustomer && myOrgRating != null)
                    Padding(
                      padding: EdgeInsets.only(top: AppSpacing.sm),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded, size: AppIconSize.sm, color: AppTheme.successColor),
                          AppSpacing.hSm,
                          Text('Organizer: ${myOrgRating['stars']} star${myOrgRating['stars'] == 1 ? '' : 's'}',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.successColor)),
                        ],
                      ),
                    ),

                  if (isOrganizer) ...[
                    Divider(height: AppSpacing.xxl),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showAllReviews(context),
                        icon: Icon(Icons.list_alt_rounded, size: AppIconSize.sm),
                        label: const Text('View All Reviews', style: TextStyle(fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.sm),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewCard(dynamic r) {
    final stars = r['stars'] as int? ?? 0;
    final name = r['rater_name'] ?? 'Anonymous';
    final desc = r['description'] as String? ?? '';

    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StarRating(rating: stars, size: 14),
          AppSpacing.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (desc.isNotEmpty)
                  Text(desc,
                      style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(context)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                Text('— $name',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAllReviews(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.topXl,
      ),
      backgroundColor: AppTheme.cardOf(context),
      builder: (ctx) => AllReviewsSheet(eventId: widget.eventId),
    );
  }
}


class AllReviewsSheet extends StatefulWidget {
  final int eventId;
  const AllReviewsSheet({super.key, required this.eventId});

  @override
  State<AllReviewsSheet> createState() => _AllReviewsSheetState();
}

class _AllReviewsSheetState extends State<AllReviewsSheet> {
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;
  String? _directionFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = context.read<EventProvider>();
      final data = await repo.getEventRatings(widget.eventId, direction: _directionFilter);
      if (mounted) setState(() { _reviews = data.cast<Map<String, dynamic>>(); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static const _directions = [
    ('All', null),
    ('Event', 'customer_to_event'),
    ('Organizer', 'customer_to_organizer'),
    ('Sponsor', 'organizer_to_sponsor'),
  ];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (ctx, scrollCtrl) => Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
        child: Column(
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.dividerOf(context), borderRadius: AppRadius.sm),
            ),
            AppSpacing.vLg,
            Text('All Reviews', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryOf(context))),
            AppSpacing.vMd,
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _directions.map((d) {
                  final isActive = _directionFilter == d.$2;
                  return Padding(
                    padding: EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(d.$1),
                      selected: isActive,
                      onSelected: (_) {
                        setState(() { _directionFilter = d.$2; _loading = true; });
                        _load();
                      },
                      selectedColor: context.reviewAccent,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.white : AppTheme.textPrimaryOf(context),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }).toList(),
              ),
            ),
            AppSpacing.vMd,
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _reviews.isEmpty
                      ? EmptyState(icon: Icons.reviews_outlined, title: 'No reviews found')
                      : ListView.separated(
                          controller: scrollCtrl,
                          itemCount: _reviews.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final r = _reviews[i];
                            final stars = r['stars'] as int? ?? 0;
                            return ListTile(
                              dense: true,
                              leading: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  StarRating(rating: stars, size: AppIconSize.sm),
                                ],
                              ),
                              title: Text(r['description'] ?? '',
                                  style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(context)),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: Text('${r['rater_name']} · ${r['direction']?.toString().replaceAll('_', ' ') ?? ''}',
                                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
