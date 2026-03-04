import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../models/sponsor.dart';
import '../../../repositories/base_repository.dart';
import '../../../providers/sponsor_provider.dart';
import '../../../widgets/app_toast.dart';

class SponsorUploadSheet extends StatefulWidget {
  final int eventId;
  final int categoryId;
  final String categoryName;

  const SponsorUploadSheet({
    super.key,
    required this.eventId,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<SponsorUploadSheet> createState() => _SponsorUploadSheetState();
}

class _SponsorUploadSheetState extends State<SponsorUploadSheet> {
  List<CategoryPrerequisite> _prereqs = [];
  List<SponsorBid> _bids = [];
  final Map<int, List<BidPrerequisiteUpload>> _uploadsByBid = {};
  bool _loading = true;
  int? _selectedBidId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<SponsorProvider>();
      final prereqs = await api.listPrerequisites(widget.eventId, widget.categoryId);
      final allBids = await api.listBids(widget.eventId, widget.categoryId);
      final myBids = allBids
          .where((b) => b.sponsorUserId != 0)
          .toList();

      if (mounted) {
        setState(() {
          _prereqs = prereqs;
          _bids = myBids;
          if (_bids.isNotEmpty && _selectedBidId == null) {
            _selectedBidId = _bids.first.id;
          }
          _loading = false;
        });
      }
      if (_selectedBidId != null) await _loadUploads(_selectedBidId!);
    } catch (e) {
      if (mounted) {
        AppToast.error(context, ApiError.extractMessage(e));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadUploads(int bidId) async {
    try {
      final api = context.read<SponsorProvider>();
      final uploads = await api.listBidPrerequisiteUploads(bidId);
      if (mounted) {
        setState(() {
          _uploadsByBid[bidId] = uploads;
        });
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _uploadFile(int prereqId) async {
    if (_selectedBidId == null) return;
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    if (!mounted) return;
    try {
      final api = context.read<SponsorProvider>();
      await api.uploadPrerequisiteDocument(
        _selectedBidId!,
        prereqId,
        file.path!,
        file.name,
      );
      if (mounted) AppToast.success(context, 'Document uploaded');
      _loadUploads(_selectedBidId!);
    } catch (e) {
      if (mounted) AppToast.error(context, ApiError.extractMessage(e));
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved': return AppTheme.successColor;
      case 'rejected': return AppTheme.errorColor;
      default: return AppTheme.warningColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploads = _selectedBidId != null ? (_uploadsByBid[_selectedBidId!] ?? []) : <BidPrerequisiteUpload>[];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (ctx, scrollCtrl) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerOf(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Upload Documents: ${widget.categoryName}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            if (_bids.length > 1) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _bids.map((b) {
                    final isSelected = _selectedBidId == b.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('Bid ${b.amountDisplay}'),
                        selected: isSelected,
                        onSelected: (sel) {
                          if (sel) {
                            setState(() => _selectedBidId = b.id);
                            _loadUploads(b.id);
                          }
                        },
                        selectedColor: AppTheme.accentColor,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppTheme.textPrimaryOf(context),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _prereqs.isEmpty
                      ? Center(
                          child: Text(
                            'No requirements for this category.',
                            style: TextStyle(color: AppTheme.textSecondaryOf(context)),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollCtrl,
                          itemCount: _prereqs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final prereq = _prereqs[i];
                            final upload = uploads.where(
                              (u) => u.prerequisiteId == prereq.id,
                            ).toList();
                            final hasUpload = upload.isNotEmpty;
                            final uploadStatus = hasUpload ? upload.first.status : null;
                            final isRequired = prereq.isRequired;

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceOf(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.dividerOf(context)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isRequired ? Icons.star_rounded : Icons.star_border_rounded,
                                        size: 16,
                                        color: isRequired ? context.sponsorAccent : AppTheme.textSecondaryOf(context),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          prereq.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimaryOf(context),
                                          ),
                                        ),
                                      ),
                                      if (hasUpload)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _statusColor(uploadStatus!).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            uploadStatus.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: _statusColor(uploadStatus),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (prereq.description != null && prereq.description!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      prereq.description!,
                                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                                    ),
                                  ],
                                  if (hasUpload && upload.first.reviewerNote != null &&
                                      upload.first.reviewerNote!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Note: ${upload.first.reviewerNote}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                        color: AppTheme.textSecondaryOf(context),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 34,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _uploadFile(prereq.id),
                                      icon: const Icon(Icons.upload_rounded, size: 16),
                                      label: Text(
                                        hasUpload ? 'Re-upload' : 'Upload',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: context.sponsorAccent,
                                        side: BorderSide(color: context.sponsorAccent),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
