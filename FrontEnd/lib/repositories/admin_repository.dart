import 'package:dio/dio.dart';

import '../models/event.dart';
import 'base_repository.dart';

/// Repository for all `/admin/*` endpoints.
class AdminRepository extends BaseRepository {
  AdminRepository(super.dio);

  // ─── Users ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getUsers({
    int offset = 0,
    int limit = 20,
    String? search,
  }) async {
    final resp = await dio.get('/admin/users', queryParameters: {
      'offset': offset,
      'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getUserDetail(int userId) async {
    final resp = await dio.get('/admin/users/$userId/detail');
    return resp.data as Map<String, dynamic>;
  }

  // ─── Events ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getEvents({
    int offset = 0,
    int limit = 20,
    String? search,
    String? status,
  }) async {
    final resp = await dio.get('/admin/events', queryParameters: {
      'offset': offset,
      'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status.isNotEmpty) 'status': status,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Event> approveEvent(
    int id,
    Map<String, dynamic> data,
  ) async {
    final resp = await dio.post('/admin/events/$id/approve', data: data);
    return Event.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<Event> resolveReview(
    int eventId, {
    required String targetStatus,
    String? notes,
  }) async {
    final resp =
        await dio.post('/admin/events/$eventId/resolve-review', data: {
      'target_status': targetStatus,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return Event.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<Event> decideCancellation(
    int eventId,
    String action,
  ) async {
    final resp = await dio.post(
      '/events/$eventId/cancellation/approve',
      data: {'action': action},
    );
    return Event.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> setPolicyOverrides(
    int eventId,
    Map<String, dynamic> overrides,
  ) async {
    final resp = await dio.patch(
      '/admin/events/$eventId/policy-overrides',
      data: overrides,
    );
    return resp.data as Map<String, dynamic>;
  }

  // ─── Sponsor Bids ──────────────────────────────────────────────────────

  Future<void> refundSponsorBid(
    int eventId,
    int catId,
    int bidId,
  ) async {
    await dio.post(
      '/admin/events/$eventId/sponsorships/$catId/bids/$bidId/refund',
    );
  }

  // ─── Stats & Dashboard ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStats() async {
    final resp = await dio.get('/admin/stats');
    return resp.data;
  }

  Future<Map<String, dynamic>> getDashboard({
    String period = '30d',
    String? genre,
    String? status,
  }) async {
    final resp = await dio.get('/admin/dashboard', queryParameters: {
      'period': period,
      if (genre != null) 'genre': genre,
      if (status != null) 'status': status,
    });
    return Map<String, dynamic>.from(resp.data as Map);
  }

  // ─── Settings ───────────────────────────────────────────────────────────

  Future<List<dynamic>> getSettings() async {
    final resp = await dio.get('/admin/settings');
    return resp.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> updateSetting(
    String key,
    String value,
  ) async {
    final resp =
        await dio.patch('/admin/settings/$key', data: {'value': value});
    return resp.data as Map<String, dynamic>;
  }

  // ─── Banking ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getBankingOverview({
    String period = '30d',
  }) async {
    final resp = await dio.get(
      '/admin/banking-overview',
      queryParameters: {'period': period},
    );
    return resp.data as Map<String, dynamic>;
  }

  // ─── Escrows ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getEscrows({
    String type = 'fund',
    int limit = 50,
  }) async {
    final path = type == 'fund'
        ? '/admin/escrows'
        : type == 'ticket'
            ? '/admin/ticket-escrows'
            : '/admin/sponsor-escrows';
    final resp = await dio.get(path, queryParameters: {'limit': '$limit'});
    return resp.data as Map<String, dynamic>;
  }

  /// Paginated escrow list with optional search.
  Future<Map<String, dynamic>> getEscrowList({
    int offset = 0,
    int limit = 20,
    String? search,
  }) async {
    final resp = await dio.get('/admin/escrows', queryParameters: {
      'offset': offset,
      'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getEventEscrows(int eventId) async {
    final resp = await dio.get('/admin/escrows/by-event/$eventId');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> releaseEscrowStage(
    int eventId,
    String escrowType,
    int stage,
  ) async {
    final path = escrowType == 'fund'
        ? '/admin/escrows/$eventId/release/$stage'
        : escrowType == 'ticket'
            ? '/admin/ticket-escrows/$eventId/release/$stage'
            : '/admin/sponsor-escrows/$eventId/release/$stage';
    final resp = await dio.post(path, data: {});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> freezeEscrow(
    int eventId,
    String escrowType,
  ) async {
    final path = escrowType == 'fund'
        ? '/admin/escrows/$eventId/freeze'
        : escrowType == 'ticket'
            ? '/admin/ticket-escrows/$eventId/freeze'
            : '/admin/sponsor-escrows/$eventId/freeze';
    final resp = await dio.post(path, data: {});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> unfreezeEscrow(
    int eventId,
    String escrowType,
  ) async {
    final path = escrowType == 'fund'
        ? '/admin/escrows/$eventId/unfreeze'
        : escrowType == 'ticket'
            ? '/admin/ticket-escrows/$eventId/unfreeze'
            : '/admin/sponsor-escrows/$eventId/unfreeze';
    final resp = await dio.post(path, data: {});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> toggleAutoRelease(
    int eventId,
    String escrowType, {
    bool? stage1,
    bool? stage2,
    bool? stage3,
  }) async {
    final path = '/admin/$escrowType-escrows/$eventId/auto-release';
    final body = <String, dynamic>{};
    if (stage1 != null) body['stage1_auto_release'] = stage1;
    if (stage2 != null) body['stage2_auto_release'] = stage2;
    if (stage3 != null) body['stage3_auto_release'] = stage3;
    final resp = await dio.patch(path, data: body);
    return resp.data as Map<String, dynamic>;
  }

  /// Generic escrow action used by financial tab and user-detail shared.
  Future<void> escrowAction(
    int eventId,
    String action, {
    int? stage,
  }) async {
    final path = stage != null
        ? '/admin/escrows/$eventId/release/$stage'
        : '/admin/escrows/$eventId/$action';
    await dio.post(path);
  }

  // ─── Disputes ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDisputes({
    String? status,
    int offset = 0,
    int limit = 50,
  }) async {
    final resp = await dio.get('/admin/disputes', queryParameters: {
      if (status != null) 'status': status,
      'offset': offset,
      'limit': limit,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitDisputeEvidence(int disputeId) async {
    final resp =
        await dio.post('/admin/disputes/$disputeId/submit-evidence', data: {});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> acceptDisputeLoss(int disputeId) async {
    final resp =
        await dio.post('/admin/disputes/$disputeId/accept', data: {});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> resolveDispute(
    int disputeId, {
    required String outcome,
    String? notes,
  }) async {
    final resp = await dio.post('/admin/disputes/$disputeId/resolve', data: {
      'outcome': outcome,
      if (notes != null) 'notes': notes,
    });
    return resp.data as Map<String, dynamic>;
  }

  // ─── Reconciliation & Ledger ────────────────────────────────────────────

  Future<List<dynamic>> getReconciliationHistory({int limit = 30}) async {
    final resp = await dio.get(
      '/admin/reconciliation/history',
      queryParameters: {'limit': limit},
    );
    return resp.data as List;
  }

  Future<Map<String, dynamic>> runReconciliation() async {
    final resp = await dio.post('/admin/reconciliation/run', data: {});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLedgerHealth() async {
    final resp = await dio.get('/admin/ledger-health');
    return resp.data as Map<String, dynamic>;
  }

  // ─── Payouts ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getPayoutStatus() async {
    final resp = await dio.get('/admin/payout-status');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> forcePayout(int organizerId) async {
    final resp =
        await dio.post('/admin/payouts/$organizerId/force', data: {});
    return resp.data as Map<String, dynamic>;
  }

  // ─── Transactions ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getTransactions({
    int offset = 0,
    int limit = 20,
    String? search,
    String? status,
  }) async {
    final resp = await dio.get('/admin/transactions', queryParameters: {
      'offset': offset,
      'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status.isNotEmpty) 'status': status,
    });
    return resp.data as Map<String, dynamic>;
  }

  // ─── Mock ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMockOverview() async {
    final resp = await dio.get('/admin/mock-overview');
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Map<String, dynamic>> simulateDispute(String transactionId) async {
    final resp = await dio.post(
      '/admin/mock/simulate-dispute',
      data: {'transaction_id': transactionId},
    );
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> clearMockData() async {
    final resp = await dio.post('/admin/mock/clear', data: {});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> settleAllPending() async {
    final resp = await dio.post('/admin/mock/settle-all', data: {});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> failNextCharge() async {
    final resp = await dio.post('/admin/mock/fail-next', data: {});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> resetMockDefaults() async {
    final resp = await dio.post('/admin/mock/reset-defaults', data: {});
    return resp.data as Map<String, dynamic>;
  }

  // ─── Platform Account ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> getPlatformAccount() async {
    final resp = await dio.get('/admin/platform-account');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updatePlatformAccount(
    Map<String, dynamic> data,
  ) async {
    final resp = await dio.put('/admin/platform-account', data: data);
    return resp.data as Map<String, dynamic>;
  }

  // ─── Audit Log ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getAuditLog({
    int offset = 0,
    int limit = 50,
    String? action,
    String? targetType,
  }) async {
    final resp = await dio.get('/admin/audit-log', queryParameters: {
      'offset': offset,
      'limit': limit,
      if (action != null) 'action': action,
      if (targetType != null) 'target_type': targetType,
    });
    return resp.data as Map<String, dynamic>;
  }

  // ─── Workers (ARQ) ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getWorkerSummary() async {
    final resp = await dio.get('/admin/worker-summary');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getWorkerRuns({
    String? taskName,
    String? status,
    int offset = 0,
    int limit = 50,
  }) async {
    final resp = await dio.get('/admin/worker-runs', queryParameters: {
      if (taskName != null) 'task_name': taskName,
      if (status != null) 'status': status,
      'offset': offset,
      'limit': limit,
    });
    return resp.data as Map<String, dynamic>;
  }

  // ─── Email Templates ───────────────────────────────────────────────────

  Future<List<dynamic>> getEmailTemplates() async {
    final resp = await dio.get('/admin/email-templates');
    final data = resp.data;
    return data is List ? List<dynamic>.from(data) : [];
  }

  Future<void> uploadEmailLogo({
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
    });
    await dio.post('/admin/email-templates/upload-logo', data: formData);
  }

  Future<Map<String, dynamic>> saveEmailTemplate(
    String key, {
    required String subject,
    required String bodyHtml,
    required bool isActive,
  }) async {
    final resp = await dio.put('/admin/email-templates/$key', data: {
      'subject': subject,
      'body_html': bodyHtml,
      'is_active': isActive,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> resetAllEmailTemplates() async {
    final resp =
        await dio.post('/admin/email-templates/reset-all', data: {});
    if (resp.data is Map) return resp.data as Map<String, dynamic>;
    return {};
  }

  Future<Map<String, dynamic>> testSendEmailTemplate(String key) async {
    final resp =
        await dio.post('/admin/email-templates/$key/test-send', data: {});
    if (resp.data is Map) return resp.data as Map<String, dynamic>;
    return {};
  }

  Future<Map<String, dynamic>> resetEmailTemplate(String key) async {
    final resp =
        await dio.post('/admin/email-templates/$key/reset', data: {});
    if (resp.data is Map) return resp.data as Map<String, dynamic>;
    return {};
  }
}
