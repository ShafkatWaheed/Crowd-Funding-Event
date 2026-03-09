import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/app_toast.dart';

class KycSection extends StatefulWidget {
  const KycSection({super.key});

  @override
  State<KycSection> createState() => _KycSectionState();
}

class _KycSectionState extends State<KycSection> {
  KycStatus? _kycData;
  bool _loading = true;
  bool _submitting = false;
  bool _uploading = false;
  bool _expanded = false;

  static const _docLabels = {
    'id_front': 'Government ID (Front)',
    'id_back': 'Government ID (Back)',
    'proof_of_address': 'Proof of Address',
    'selfie': 'Selfie with ID',
    'tax_id': 'Tax ID Document',
  };

  bool get _isCustomer {
    final role = context.read<AuthProvider>().user?.role ?? UserRole.customer;
    return role == UserRole.customer;
  }

  List<String> get _requiredDocTypes => _isCustomer
      ? ['id_front', 'id_back']
      : ['id_front', 'id_back', 'proof_of_address', 'tax_id'];

  List<String> get _optionalDocTypes => ['selfie'];

  @override
  void initState() {
    super.initState();
    _loadKycStatus();
  }

  Future<void> _loadKycStatus() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<UserProvider>().getKycStatus();
      if (mounted) setState(() => _kycData = data);
    } catch (e) {
      if (mounted) AppToast.fromError(context, e, fallback: 'Failed to load KYC status');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<KycDocument> get _documents => _kycData?.documents ?? [];

  KycDocument? _docForType(String type) {
    try {
      return _documents.firstWhere((d) => d.documentType == type);
    } catch (_) {
      return null;
    }
  }

  bool get _canSubmit {
    final status = _kycData?.kycStatus ?? 'not_started';
    if (status == 'verified' || status == 'submitted') return false;
    for (final dt in _requiredDocTypes) {
      if (_docForType(dt) == null) return false;
    }
    return true;
  }

  Future<void> _uploadDocument(String docType) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    final filename = file.name;

    setState(() => _uploading = true);
    if (!mounted) return;
    try {
      final uploaded = await context.read<UserProvider>().uploadKycDocument(bytes, filename, docType);
      if (mounted && _kycData != null) {
        final newDoc = KycDocument(
          id: uploaded.documentId ?? 0,
          documentType: uploaded.documentType ?? docType,
          fileUrl: uploaded.fileUrl,
          originalFilename: filename,
          status: uploaded.status ?? 'pending',
        );
        setState(() {
          _kycData = KycStatus(
            kycStatus: _kycData!.kycStatus,
            kycVerified: _kycData!.kycVerified,
            kycVerifiedAt: _kycData!.kycVerifiedAt,
            kycRequiredForRole: _kycData!.kycRequiredForRole,
            documents: [
              ..._kycData!.documents.where((d) => d.documentType != docType),
              newDoc,
            ],
          );
        });
        AppToast.success(context, 'Document uploaded');
      }
    } catch (e) {
      if (mounted) AppToast.fromError(context, e, fallback: 'Upload failed');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteDocument(int docId) async {
    try {
      await context.read<UserProvider>().deleteKycDocument(docId);
      if (mounted && _kycData != null) {
        setState(() {
          _kycData = KycStatus(
            kycStatus: _kycData!.kycStatus,
            kycVerified: _kycData!.kycVerified,
            kycVerifiedAt: _kycData!.kycVerifiedAt,
            kycRequiredForRole: _kycData!.kycRequiredForRole,
            documents: _kycData!.documents.where((d) => d.id != docId).toList(),
          );
        });
        AppToast.success(context, 'Document removed');
      }
    } catch (e) {
      if (mounted) AppToast.fromError(context, e, fallback: 'Delete failed');
    }
  }

  Future<void> _submitForReview() async {
    setState(() => _submitting = true);
    try {
      final resp = await context.read<UserProvider>().submitKyc();
      await _loadKycStatus();
      if (mounted) AppToast.success(context, resp.message ?? 'Submitted');
    } catch (e) {
      if (mounted) AppToast.fromError(context, e, fallback: 'Submit failed');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final status = _kycData?.kycStatus ?? 'not_started';

    return _buildExpansionTile(status);
  }

  Widget _buildExpansionTile(String status) {
    final (icon, color, label) = _statusDisplay(status);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(10),
        color: color.withValues(alpha: 0.04),
      ),
      child: Theme(
        // Remove the default divider lines ExpansionTile adds
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _expanded,
          onExpansionChanged: (v) => setState(() => _expanded = v),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Identity Verification',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          children: [
            const SizedBox(height: 4),
            if (status == 'verified')
              _buildVerifiedContent()
            else if (status == 'submitted')
              _buildSubmittedContent()
            else ...[
              _buildDocumentUploadList(),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_canSubmit && !_submitting) ? _submitForReview : null,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(_submitting ? 'Submitting...' : 'Submit for Verification'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (status == 'rejected') ...[
                const SizedBox(height: 8),
                _buildRejectionInfo(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  (IconData, Color, String) _statusDisplay(String status) {
    return switch (status) {
      'verified' => (Icons.verified, AppTheme.successColor, 'Verified'),
      'submitted' => (Icons.hourglass_top_rounded, AppTheme.warningColor, 'Under Review'),
      'rejected' => (Icons.error_outline, Colors.red, 'Rejected'),
      _ => (Icons.shield_outlined,
            (_kycData?.kycRequiredForRole ?? false) ? AppTheme.warningColor : AppTheme.textSecondaryOf(context),
            (_kycData?.kycRequiredForRole ?? false) ? 'Required' : 'Not Started'),
    };
  }

  Widget _buildVerifiedContent() {
    return Row(
      children: [
        Icon(Icons.check_circle, color: AppTheme.successColor, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Your identity has been verified. No further action needed.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context)),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmittedContent() {
    return Row(
      children: [
        Icon(Icons.schedule, color: AppTheme.warningColor, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Your documents are under review. You will be notified when verification is complete.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context)),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentUploadList() {
    final allDocs = [..._requiredDocTypes, ..._optionalDocTypes];
    return Column(
      children: allDocs.map((docType) {
        final doc = _docForType(docType);
        final isRequired = _requiredDocTypes.contains(docType);
        final label = _docLabels[docType] ?? docType;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceOf(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.dividerOf(context)),
            ),
            child: Row(
              children: [
                Icon(
                  doc != null ? Icons.description : Icons.upload_file,
                  color: doc != null ? AppTheme.successColor : AppTheme.textSecondaryOf(context),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          if (isRequired) ...[
                            const SizedBox(width: 4),
                            const Text('*', style: TextStyle(color: Colors.red, fontSize: 13)),
                          ],
                        ],
                      ),
                      if (doc == null && (docType == 'id_front' || docType == 'id_back'))
                        Text(
                          'Passport or Driver\'s License',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                        ),
                      if (doc != null && doc.originalFilename != null)
                        Text(
                          doc.originalFilename!,
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (doc != null && doc.status == 'pending')
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _deleteDocument(doc.id),
                    tooltip: 'Remove',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  )
                else if (doc == null)
                  SizedBox(
                    height: 32,
                    child: OutlinedButton(
                      onPressed: _uploading ? null : () => _uploadDocument(docType),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        side: BorderSide(color: AppTheme.accentColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: Text(
                        _uploading ? '...' : 'Upload',
                        style: TextStyle(fontSize: 12, color: AppTheme.accentColor),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRejectionInfo() {
    final docs = _documents.where((d) => d.rejectionReason != null && d.rejectionReason!.isNotEmpty);
    if (docs.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rejection reasons:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red)),
          const SizedBox(height: 4),
          ...docs.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '${_docLabels[d.documentType] ?? d.documentType}: ${d.rejectionReason}',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                ),
              )),
        ],
      ),
    );
  }
}
