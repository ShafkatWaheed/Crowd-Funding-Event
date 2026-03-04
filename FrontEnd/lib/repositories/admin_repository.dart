import 'package:dio/dio.dart';

import '../models/admin.dart';
import '../models/event.dart';
import 'base_repository.dart';

/// Repository for all `/admin/*` endpoints.
class AdminRepository extends BaseRepository {
  AdminRepository(super.dio);

  // ─── Helpers ──────────────────────────────────────────────────────────────

  AdminPage<T> _parsePage<T>(
    dynamic data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final map = Map<String, dynamic>.from(data as Map);
    return AdminPage<T>(
      items: (map['items'] as List?)
              ?.map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      total: (map['total'] as int?) ?? 0,
    );
  }

  // ─── Users ──────────────────────────────────────────────────────────────

  Future<AdminPage<AdminUserItem>> getUsers({
    int offset = 0,
    int limit = 20,
    String? search,
  }) async {
    final resp = await dio.get('/admin/users', queryParameters: {
      'offset': offset,
      'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return _parsePage(resp.data, AdminUserItem.fromJson);
  }

  Future<AdminUserDetail> getUserDetail(int userId) async {
    final resp = await dio.get('/admin/users/$userId/detail');
    return AdminUserDetail.fromJson(
        Map<String, dynamic>.from(resp.data as Map));
  }

  // ─── Events ─────────────────────────────────────────────────────────────

  Future<AdminPage<AdminEventItem>> getEvents({
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
    return _parsePage(resp.data, AdminEventItem.fromJson);
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

  Future<AdminPolicyOverrides> setPolicyOverrides(
    int eventId,
    Map<String, dynamic> overrides,
  ) async {
    final resp = await dio.patch(
      '/admin/events/$eventId/policy-overrides',
      data: overrides,
    );
    return AdminPolicyOverrides.fromJson(
        Map<String, dynamic>.from(resp.data as Map));
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

  Future<AdminStats> getStats() async {
    final resp = await dio.get('/admin/stats');
    return AdminStats.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<AdminDashboard> getDashboard({
    String period = '30d',
    String? genre,
    String? status,
  }) async {
    final resp = await dio.get('/admin/dashboard', queryParameters: {
      'period': period,
      if (genre != null) 'genre': genre,
      if (status != null) 'status': status,
    });
    return AdminDashboard.fromJson(
        Map<String, dynamic>.from(resp.data as Map));
  }

  // ─── Settings ───────────────────────────────────────────────────────────

  Future<List<PlatformSetting>> getSettings() async {
    final resp = await dio.get('/admin/settings');
    final data = resp.data;
    if (data is List) {
      return data
          .map((e) =>
              PlatformSetting.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  Future<PlatformSetting> updateSetting(
    String key,
    String value,
  ) async {
    final resp =
        await dio.patch('/admin/settings/$key', data: {'value': value});
    return PlatformSetting.fromJson(
        Map<String, dynamic>.from(resp.data as Map));
  }

  // ─── Banking ────────────────────────────────────────────────────────────

  Future<AdminBankingOverview> getBankingOverview({
    String period = '30d',
  }) async {
    final resp = await dio.get(
      '/admin/banking-overview',
      queryParameters: {'period': period},
    );
    return AdminBankingOverview.fromJson(
        Map<String, dynamic>.from(resp.data as Map));
  }

  // ─── Escrows ────────────────────────────────────────────────────────────

  Future<AdminPage<AdminEscrowItem>> getEscrows({
    String type = 'fund',
    int limit = 50,
  }) async {
    final path = type == 'fund'
        ? '/admin/escrows'
        : type == 'ticket'
            ? '/admin/ticket-escrows'
            : '/admin/sponsor-escrows';
    final resp = await dio.get(path, queryParameters: {'limit': '$limit'});
    return _parsePage(resp.data, AdminEscrowItem.fromJson);
  }

  /// Paginated escrow list with optional search.
  Future<AdminPage<AdminEscrowItem>> getEscrowList({
    int offset = 0,
    int limit = 20,
    String? search,
  }) async {
    final resp = await dio.get('/admin/escrows', queryParameters: {
      'offset': offset,
      'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return _parsePage(resp.data, AdminEscrowItem.fromJson);
  }

  Future<AdminEventEscrows> getEventEscrows(int eventId) async {
    final resp = await dio.get('/admin/escrows/by-event/$eventId');
    return AdminEventEscrows.fromJson(
        Map<String, dynamic>.from(resp.data as Map));
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

  Future<AdminEscrowItem> toggleAutoRelease(
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
    return AdminEscrowItem.fromJson(
        Map<String, dynamic>.from(resp.data as Map));
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

  Future<AdminPage<AdminDispute>> getDisputes({
    String? status,
    int offset = 0,
    int limit = 50,
  }) async {
    final resp = await dio.get('/admin/disputes', queryParameters: {
      if (status != null) 'status': status,
      'offset': offset,
      'limit': limit,
    });
    return _parsePage(resp.data, AdminDispute.fromJson);
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

  Future<List<ReconciliationEntry>> getReconciliationHistory(
      {int limit = 30}) async {
    final resp = await dio.get(
      '/admin/reconciliation/history',
      queryParameters: {'limit': limit},
    );
    final data = resp.data;
    if (data is List) {
      return data
          .map((e) => ReconciliationEntry.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> runReconciliation() async {
    final resp = await dio.post('/admin/reconciliation/run', data: {});
    return resp.data as Map<String, dynamic>;
  }

  Future<AdminLedgerHealth> getLedgerHealth() async {
    final resp = await dio.get('/admin/ledger-health');
    return AdminLedgerHealth.fromJson(
        Map<String, dynamic>.from(resp.data as Map));
  }

  // ─── Payouts ────────────────────────────────────────────────────────────

  Future<List<AdminPayoutItem>> getPayoutStatus() async {
    final resp = await dio.get('/admin/payout-status');
    final data = resp.data;
    if (data is List) {
      return data
          .map((e) =>
              AdminPayoutItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    if (data is Map) {
      final items = data['items'];
      if (items is List) {
        return items
            .map((e) =>
                AdminPayoutItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    }
    return [];
  }

  Future<Map<String, dynamic>> forcePayout(int organizerId) async {
    final resp =
        await dio.post('/admin/payouts/$organizerId/force', data: {});
    return resp.data as Map<String, dynamic>;
  }

  // ─── Transactions ──────────────────────────────────────────────────────

  Future<AdminPage<AdminTransaction>> getTransactions({
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
    return _parsePage(resp.data, AdminTransaction.fromJson);
  }

  // ─── Mock ───────────────────────────────────────────────────────────────

  Future<AdminMockOverview> getMockOverview() async {
    final resp = await dio.get('/admin/mock-overview');
    return AdminMockOverview.fromJson(
        Map<String, dynamic>.from(resp.data as Map));
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

  Future<AdminPlatformAccount> getPlatformAccount() async {
    final resp = await dio.get('/admin/platform-account');
    return AdminPlatformAccount.fromJson(
        Map<String, dynamic>.from(resp.data as Map));
  }

  Future<AdminPlatformAccount> updatePlatformAccount(
    Map<String, dynamic> data,
  ) async {
    final resp = await dio.put('/admin/platform-account', data: data);
    return AdminPlatformAccount.fromJson(
        Map<String, dynamic>.from(resp.data as Map));
  }

  // ─── Audit Log ─────────────────────────────────────────────────────────

  Future<AdminPage<AdminAuditEntry>> getAuditLog({
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
    return _parsePage(resp.data, AdminAuditEntry.fromJson);
  }

  // ─── Workers (ARQ) ─────────────────────────────────────────────────────

  Future<AdminWorkerSummary> getWorkerSummary() async {
    final resp = await dio.get('/admin/worker-summary');
    return AdminWorkerSummary.fromJson(
        Map<String, dynamic>.from(resp.data as Map));
  }

  Future<AdminPage<AdminWorkerRun>> getWorkerRuns({
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
    return _parsePage(resp.data, AdminWorkerRun.fromJson);
  }

  // ─── Email Templates ───────────────────────────────────────────────────

  Future<List<EmailTemplate>> getEmailTemplates() async {
    final resp = await dio.get('/admin/email-templates');
    final data = resp.data;
    if (data is List) {
      return data
          .map((e) =>
              EmailTemplate.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
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

  Future<EmailTemplate> saveEmailTemplate(
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
    return EmailTemplate.fromJson(
        Map<String, dynamic>.from(resp.data as Map));
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

  Future<EmailTemplate> resetEmailTemplate(String key) async {
    final resp =
        await dio.post('/admin/email-templates/$key/reset', data: {});
    return EmailTemplate.fromJson(
        Map<String, dynamic>.from(resp.data as Map));
  }
}
