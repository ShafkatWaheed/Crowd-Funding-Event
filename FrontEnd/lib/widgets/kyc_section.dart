import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../services/api_service.dart';
import '../widgets/app_toast.dart';

class KycSection extends StatefulWidget {
  const KycSection({super.key});

  @override
  State<KycSection> createState() => _KycSectionState();
}

class _KycSectionState extends State<KycSection> {
  Map<String, dynamic>? _kycData;
  bool _loading = true;
  bool _submitting = false;
  bool _uploading = false;

  static const _requiredDocs = ['id_front', 'proof_of_address'];
  static const _optionalDocs = ['id_back', 'selfie', 'tax_id'];
  static const _docLabels = {
    'id_front': 'Government ID (Front)',
    'id_back': 'Government ID (Back)',
    'proof_of_address': 'Proof of Address',
    'selfie': 'Selfie with ID',
    'tax_id': 'Tax ID Document',
  };

  @override
  void initState() {
    super.initState();
    _loadKycStatus();
  }

  Future<void> _loadKycStatus() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<ApiService>().getKycStatus();
      if (mounted) setState(() => _kycData = data);
    } catch (e) {
      if (mounted) AppToast.fromError(context, e, fallback: 'Failed to load KYC status');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _documents {
    final docs = _kycData?['documents'];
    if (docs is List) return docs.cast<Map<String, dynamic>>();
    return [];
  }

  Map<String, dynamic>? _docForType(String type) {
    try {
      return _documents.firstWhere((d) => d['document_type'] == type);
    } catch (_) {
      return null;
    }
  }

  bool get _canSubmit {
    final status = _kycData?['kyc_status'] ?? 'not_started';
    if (status == 'verified' || status == 'submitted') return false;
    for (final dt in _requiredDocs) {
      if (_docForType(dt) == null) return false;
    }
    return true;
  }

  Future<void> _uploadDocument(String docType) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    setState(() => _uploading = true);
    if (!mounted) return;
    try {
      await context.read<ApiService>().uploadKycDocument(file.path!, docType);
      await _loadKycStatus();
      if (mounted) AppToast.success(context, 'Document uploaded');
    } catch (e) {
      if (mounted) AppToast.fromError(context, e, fallback: 'Upload failed');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteDocument(int docId) async {
    try {
      await context.read<ApiService>().deleteKycDocument(docId);
      await _loadKycStatus();
      if (mounted) AppToast.success(context, 'Document removed');
    } catch (e) {
      if (mounted) AppToast.fromError(context, e, fallback: 'Delete failed');
    }
  }

  Future<void> _submitForReview() async {
    setState(() => _submitting = true);
    try {
      final resp = await context.read<ApiService>().submitKyc();
      await _loadKycStatus();
      if (mounted) AppToast.success(context, resp['message'] ?? 'Submitted');
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

    final status = _kycData?['kyc_status'] ?? 'not_started';
    final verified = _kycData?['kyc_verified'] == true;
    final required = _kycData?['kyc_required_for_role'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatusBanner(status, verified, required),
        if (status == 'verified') ...[
          const SizedBox(height: 8),
          _buildVerifiedContent(),
        ] else if (status == 'submitted') ...[
          const SizedBox(height: 8),
          _buildSubmittedContent(),
        ] else ...[
          const SizedBox(height: 12),
          _buildDocumentUploadList(),
          const SizedBox(height: 16),
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
    );
  }

  Widget _buildStatusBanner(String status, bool verified, bool required) {
    IconData icon;
    Color color;
    String label;

    switch (status) {
      case 'verified':
        icon = Icons.verified;
        color = AppTheme.successColor;
        label = 'Identity Verified';
      case 'submitted':
        icon = Icons.hourglass_top_rounded;
        color = AppTheme.warningColor;
        label = 'Under Review';
      case 'rejected':
        icon = Icons.error_outline;
        color = Colors.red;
        label = 'Verification Rejected';
      default:
        icon = Icons.shield_outlined;
        color = required ? AppTheme.warningColor : AppTheme.textSecondaryOf(context);
        label = required ? 'Verification Required' : 'Not Verified';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedContent() {
    return Row(
      children: [
        Icon(Icons.check_circle, color: AppTheme.successColor, size: 16),
        const SizedBox(width: 6),
        Text(
          'Your identity has been verified. No further action needed.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context)),
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
    final allDocs = [..._requiredDocs, ..._optionalDocs];
    return Column(
      children: allDocs.map((docType) {
        final doc = _docForType(docType);
        final isRequired = _requiredDocs.contains(docType);
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
                  doc != null ? Icons.check_circle : Icons.upload_file,
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
                            Text('*', style: TextStyle(color: Colors.red, fontSize: 13)),
                          ],
                        ],
                      ),
                      if (doc != null)
                        Text(
                          doc['original_filename'] ?? '',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (doc != null && doc['status'] == 'pending')
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _deleteDocument(doc['id']),
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
    final docs = _documents.where((d) => d['rejection_reason'] != null && d['rejection_reason'].toString().isNotEmpty);
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
          Text('Rejection reasons:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red)),
          const SizedBox(height: 4),
          ...docs.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '${_docLabels[d['document_type']] ?? d['document_type']}: ${d['rejection_reason']}',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                ),
              )),
        ],
      ),
    );
  }
}
