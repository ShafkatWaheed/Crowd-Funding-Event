import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../models/sponsor.dart';
import '../../../repositories/base_repository.dart';
import '../../../providers/sponsor_provider.dart';
import '../../../widgets/app_toast.dart';

class CategoryRequirements extends StatefulWidget {
  final int eventId;
  final int categoryId;
  final String categoryName;
  final List<SponsorBid> myBids;

  const CategoryRequirements({
    super.key,
    required this.eventId,
    required this.categoryId,
    required this.categoryName,
    required this.myBids,
  });

  @override
  State<CategoryRequirements> createState() => _CategoryRequirementsState();
}

class _CategoryRequirementsState extends State<CategoryRequirements> {
  bool _expanded = false;
  bool _loading = false;
  List<CategoryPrerequisite> _prereqs = [];
  Map<int, BidPrerequisiteUpload> _uploads = {};
  final Map<int, bool> _uploading = {};

  bool get _hasBid => widget.myBids.isNotEmpty;

  Future<void> _loadData() async {
    if (_prereqs.isNotEmpty) return;
    setState(() => _loading = true);
    try {
      final api = context.read<SponsorProvider>();
      final prereqs = await api.listPrerequisites(widget.eventId, widget.categoryId);

      Map<int, BidPrerequisiteUpload> uploads = {};
      if (widget.myBids.isNotEmpty) {
        final latestBidId = widget.myBids.first.id;
        final bidUploads = await api.listBidPrerequisiteUploads(latestBidId);
        for (final u in bidUploads) {
          uploads[u.prerequisiteId] = u;
        }
      }

      if (mounted) {
        setState(() {
          _prereqs = prereqs;
          _uploads = uploads;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, ApiError.extractMessage(e));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _uploadFile(int prereqId) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null && file.path == null) return;

    setState(() => _uploading[prereqId] = true);
    if (!mounted) return;
    try {
      final api = context.read<SponsorProvider>();
      final resp = await api.uploadCategoryPrerequisite(
        widget.eventId, widget.categoryId, prereqId,
        filePath: file.path,
        fileName: file.name,
        fileBytes: file.bytes,
      );
      if (mounted) {
        setState(() {
          _uploads[prereqId] = BidPrerequisiteUpload(
            id: resp.id ?? 0,
            bidId: 0,
            prerequisiteId: prereqId,
            fileUrl: resp.fileUrl,
            status: resp.status ?? 'pending',
          );
          _uploading[prereqId] = false;
        });
        AppToast.success(context, 'Document uploaded');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, ApiError.extractMessage(e));
        setState(() => _uploading[prereqId] = false);
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved': return AppTheme.successColor;
      case 'rejected': return AppTheme.errorColor;
      default: return AppTheme.warningColor;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved': return 'Approved';
      case 'rejected': return 'Rejected';
      default: return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() => _expanded = !_expanded);
              if (_expanded) _loadData();
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.checklist_rounded, size: 18, color: context.sponsorAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Requirements',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 20,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: AppTheme.dividerOf(context)),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else if (_prereqs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No requirements.', style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13)),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Column(
                  children: [
                    if (!_hasBid && _prereqs.any((p) => p.requiresDocument))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.warningColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Place a bid first to upload documents.',
                                style: TextStyle(fontSize: 11, color: AppTheme.warningColor, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ..._prereqs.map((p) {
                    final prereqId = p.id;
                    final name = p.name;
                    final desc = p.description ?? '';
                    final requiresDoc = p.requiresDocument;
                    final upload = _uploads[prereqId];
                    final hasUpload = upload != null;
                    final isUploading = _uploading[prereqId] == true;
                    final status = upload?.status ?? 'pending';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              hasUpload ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                              size: 16,
                              color: hasUpload ? _statusColor(status) : AppTheme.textSecondaryOf(context),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textPrimaryOf(context),
                                  ),
                                ),
                                if (desc.isNotEmpty)
                                  Text(desc, style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
                                if (hasUpload)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Row(
                                      children: [
                                        Icon(Icons.attach_file_rounded, size: 12, color: _statusColor(status)),
                                        const SizedBox(width: 3),
                                        Text(
                                          'File attached',
                                          style: TextStyle(fontSize: 11, color: _statusColor(status), fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: _statusColor(status).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _statusLabel(status),
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _statusColor(status)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (_hasBid && requiresDoc) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 30,
                              child: isUploading
                                  ? const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 1.5)),
                                    )
                                  : Material(
                                      color: context.sponsorAccent.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        onTap: () => _uploadFile(prereqId),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                hasUpload ? Icons.sync_rounded : Icons.upload_file_rounded,
                                                size: 16,
                                                color: context.sponsorAccent,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                hasUpload ? 'Replace' : 'Upload',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: context.sponsorAccent,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
