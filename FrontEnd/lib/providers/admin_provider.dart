import 'package:flutter/foundation.dart';

import '../models/event.dart';
import '../repositories/admin_repository.dart';

/// Thin provider wrapper around [AdminRepository].
///
/// Screens use this instead of touching the repository directly,
/// keeping the 3-layer architecture (Screen → Provider → Repository).
/// No local state management — just forwards every call.
class AdminProvider extends ChangeNotifier {
  final AdminRepository _repo;

  AdminProvider(this._repo);

  // ─── Users ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getUsers({
    int offset = 0,
    int limit = 20,
    String? search,
  }) =>
      _repo.getUsers(offset: offset, limit: limit, search: search);

  Future<Map<String, dynamic>> getUserDetail(int userId) =>
      _repo.getUserDetail(userId);

  // ─── Events ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getEvents({
    int offset = 0,
    int limit = 20,
    String? search,
    String? status,
  }) =>
      _repo.getEvents(
        offset: offset,
        limit: limit,
        search: search,
        status: status,
      );

  Future<Event> approveEvent(int id, Map<String, dynamic> data) =>
      _repo.approveEvent(id, data);

  Future<Event> resolveReview(
    int eventId, {
    required String targetStatus,
    String? notes,
  }) =>
      _repo.resolveReview(eventId, targetStatus: targetStatus, notes: notes);

  Future<Event> decideCancellation(int eventId, String action) =>
      _repo.decideCancellation(eventId, action);

  Future<Map<String, dynamic>> setPolicyOverrides(
    int eventId,
    Map<String, dynamic> overrides,
  ) =>
      _repo.setPolicyOverrides(eventId, overrides);

  // ─── Sponsor Bids ────────────────────────────────────────────────────────

  Future<void> refundSponsorBid(int eventId, int catId, int bidId) =>
      _repo.refundSponsorBid(eventId, catId, bidId);

  // ─── Stats & Dashboard ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStats() => _repo.getStats();

  Future<Map<String, dynamic>> getDashboard({
    String period = '30d',
    String? genre,
    String? status,
  }) =>
      _repo.getDashboard(period: period, genre: genre, status: status);

  // ─── Settings ─────────────────────────────────────────────────────────────

  Future<List<dynamic>> getSettings() => _repo.getSettings();

  Future<Map<String, dynamic>> updateSetting(String key, String value) =>
      _repo.updateSetting(key, value);

  // ─── Banking ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getBankingOverview({
    String period = '30d',
  }) =>
      _repo.getBankingOverview(period: period);

  // ─── Escrows ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getEscrows({
    String type = 'fund',
    int limit = 50,
  }) =>
      _repo.getEscrows(type: type, limit: limit);

  Future<Map<String, dynamic>> getEscrowList({
    int offset = 0,
    int limit = 20,
    String? search,
  }) =>
      _repo.getEscrowList(offset: offset, limit: limit, search: search);

  Future<Map<String, dynamic>> getEventEscrows(int eventId) =>
      _repo.getEventEscrows(eventId);

  Future<Map<String, dynamic>> releaseEscrowStage(
    int eventId,
    String escrowType,
    int stage,
  ) =>
      _repo.releaseEscrowStage(eventId, escrowType, stage);

  Future<Map<String, dynamic>> freezeEscrow(
    int eventId,
    String escrowType,
  ) =>
      _repo.freezeEscrow(eventId, escrowType);

  Future<Map<String, dynamic>> unfreezeEscrow(
    int eventId,
    String escrowType,
  ) =>
      _repo.unfreezeEscrow(eventId, escrowType);

  Future<Map<String, dynamic>> toggleAutoRelease(
    int eventId,
    String escrowType, {
    bool? stage1,
    bool? stage2,
    bool? stage3,
  }) =>
      _repo.toggleAutoRelease(
        eventId,
        escrowType,
        stage1: stage1,
        stage2: stage2,
        stage3: stage3,
      );

  Future<void> escrowAction(
    int eventId,
    String action, {
    int? stage,
  }) =>
      _repo.escrowAction(eventId, action, stage: stage);

  // ─── Disputes ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDisputes({
    String? status,
    int offset = 0,
    int limit = 50,
  }) =>
      _repo.getDisputes(status: status, offset: offset, limit: limit);

  Future<Map<String, dynamic>> submitDisputeEvidence(int disputeId) =>
      _repo.submitDisputeEvidence(disputeId);

  Future<Map<String, dynamic>> acceptDisputeLoss(int disputeId) =>
      _repo.acceptDisputeLoss(disputeId);

  Future<Map<String, dynamic>> resolveDispute(
    int disputeId, {
    required String outcome,
    String? notes,
  }) =>
      _repo.resolveDispute(disputeId, outcome: outcome, notes: notes);

  // ─── Reconciliation & Ledger ──────────────────────────────────────────────

  Future<List<dynamic>> getReconciliationHistory({int limit = 30}) =>
      _repo.getReconciliationHistory(limit: limit);

  Future<Map<String, dynamic>> runReconciliation() =>
      _repo.runReconciliation();

  Future<Map<String, dynamic>> getLedgerHealth() => _repo.getLedgerHealth();

  // ─── Payouts ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getPayoutStatus() => _repo.getPayoutStatus();

  Future<Map<String, dynamic>> forcePayout(int organizerId) =>
      _repo.forcePayout(organizerId);

  // ─── Transactions ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getTransactions({
    int offset = 0,
    int limit = 20,
    String? search,
    String? status,
  }) =>
      _repo.getTransactions(
        offset: offset,
        limit: limit,
        search: search,
        status: status,
      );

  // ─── Mock ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMockOverview() => _repo.getMockOverview();

  Future<Map<String, dynamic>> simulateDispute(String transactionId) =>
      _repo.simulateDispute(transactionId);

  Future<Map<String, dynamic>> clearMockData() => _repo.clearMockData();

  Future<Map<String, dynamic>> settleAllPending() => _repo.settleAllPending();

  Future<Map<String, dynamic>> failNextCharge() => _repo.failNextCharge();

  Future<Map<String, dynamic>> resetMockDefaults() =>
      _repo.resetMockDefaults();

  // ─── Platform Account ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getPlatformAccount() =>
      _repo.getPlatformAccount();

  Future<Map<String, dynamic>> updatePlatformAccount(
    Map<String, dynamic> data,
  ) =>
      _repo.updatePlatformAccount(data);

  // ─── Audit Log ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getAuditLog({
    int offset = 0,
    int limit = 50,
    String? action,
    String? targetType,
  }) =>
      _repo.getAuditLog(
        offset: offset,
        limit: limit,
        action: action,
        targetType: targetType,
      );

  // ─── Workers (ARQ) ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getWorkerSummary() => _repo.getWorkerSummary();

  Future<Map<String, dynamic>> getWorkerRuns({
    String? taskName,
    String? status,
    int offset = 0,
    int limit = 50,
  }) =>
      _repo.getWorkerRuns(
        taskName: taskName,
        status: status,
        offset: offset,
        limit: limit,
      );

  // ─── Email Templates ─────────────────────────────────────────────────────

  Future<List<dynamic>> getEmailTemplates() => _repo.getEmailTemplates();

  Future<void> uploadEmailLogo({
    required List<int> fileBytes,
    required String fileName,
  }) =>
      _repo.uploadEmailLogo(fileBytes: fileBytes, fileName: fileName);

  Future<Map<String, dynamic>> saveEmailTemplate(
    String key, {
    required String subject,
    required String bodyHtml,
    required bool isActive,
  }) =>
      _repo.saveEmailTemplate(
        key,
        subject: subject,
        bodyHtml: bodyHtml,
        isActive: isActive,
      );

  Future<Map<String, dynamic>> resetAllEmailTemplates() =>
      _repo.resetAllEmailTemplates();

  Future<Map<String, dynamic>> testSendEmailTemplate(String key) =>
      _repo.testSendEmailTemplate(key);

  Future<Map<String, dynamic>> resetEmailTemplate(String key) =>
      _repo.resetEmailTemplate(key);
}
