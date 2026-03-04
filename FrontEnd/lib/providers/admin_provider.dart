import 'package:flutter/foundation.dart';

import '../models/admin.dart';
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

  Future<AdminPage<AdminUserItem>> getUsers({
    int offset = 0,
    int limit = 20,
    String? search,
  }) =>
      _repo.getUsers(offset: offset, limit: limit, search: search);

  Future<AdminUserDetail> getUserDetail(int userId) =>
      _repo.getUserDetail(userId);

  // ─── Events ─────────────────────────────────────────────────────────────

  Future<AdminPage<AdminEventItem>> getEvents({
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

  Future<Event> approveEvent(int id, ApproveEventRequest data) =>
      _repo.approveEvent(id, data);

  Future<Event> resolveReview(
    int eventId, {
    required String targetStatus,
    String? notes,
  }) =>
      _repo.resolveReview(eventId, targetStatus: targetStatus, notes: notes);

  Future<Event> decideCancellation(int eventId, String action) =>
      _repo.decideCancellation(eventId, action);

  Future<AdminPolicyOverrides> setPolicyOverrides(
    int eventId,
    SetPolicyOverridesRequest overrides,
  ) =>
      _repo.setPolicyOverrides(eventId, overrides);

  // ─── Sponsor Bids ────────────────────────────────────────────────────────

  Future<void> refundSponsorBid(int eventId, int catId, int bidId) =>
      _repo.refundSponsorBid(eventId, catId, bidId);

  // ─── Stats & Dashboard ─────────────────────────────────────────────────

  Future<AdminStats> getStats() => _repo.getStats();

  Future<AdminDashboard> getDashboard({
    String period = '30d',
    String? genre,
    String? status,
  }) =>
      _repo.getDashboard(period: period, genre: genre, status: status);

  // ─── Settings ─────────────────────────────────────────────────────────────

  Future<List<PlatformSetting>> getSettings() => _repo.getSettings();

  Future<PlatformSetting> updateSetting(String key, String value) =>
      _repo.updateSetting(key, value);

  // ─── Banking ──────────────────────────────────────────────────────────────

  Future<AdminBankingOverview> getBankingOverview({
    String period = '30d',
  }) =>
      _repo.getBankingOverview(period: period);

  // ─── Escrows ──────────────────────────────────────────────────────────────

  Future<AdminPage<AdminEscrowItem>> getEscrows({
    String type = 'fund',
    int limit = 50,
  }) =>
      _repo.getEscrows(type: type, limit: limit);

  Future<AdminPage<AdminEscrowItem>> getEscrowList({
    int offset = 0,
    int limit = 20,
    String? search,
  }) =>
      _repo.getEscrowList(offset: offset, limit: limit, search: search);

  Future<AdminEventEscrows> getEventEscrows(int eventId) =>
      _repo.getEventEscrows(eventId);

  Future<void> releaseEscrowStage(
    int eventId,
    String escrowType,
    int stage,
  ) =>
      _repo.releaseEscrowStage(eventId, escrowType, stage);

  Future<void> freezeEscrow(
    int eventId,
    String escrowType,
  ) =>
      _repo.freezeEscrow(eventId, escrowType);

  Future<void> unfreezeEscrow(
    int eventId,
    String escrowType,
  ) =>
      _repo.unfreezeEscrow(eventId, escrowType);

  Future<AdminEscrowItem> toggleAutoRelease(
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

  Future<AdminPage<AdminDispute>> getDisputes({
    String? status,
    int offset = 0,
    int limit = 50,
  }) =>
      _repo.getDisputes(status: status, offset: offset, limit: limit);

  Future<void> submitDisputeEvidence(int disputeId) =>
      _repo.submitDisputeEvidence(disputeId);

  Future<void> acceptDisputeLoss(int disputeId) =>
      _repo.acceptDisputeLoss(disputeId);

  Future<void> resolveDispute(
    int disputeId, {
    required String outcome,
    String? notes,
  }) =>
      _repo.resolveDispute(disputeId, outcome: outcome, notes: notes);

  // ─── Reconciliation & Ledger ──────────────────────────────────────────────

  Future<List<ReconciliationEntry>> getReconciliationHistory({
    int limit = 30,
  }) =>
      _repo.getReconciliationHistory(limit: limit);

  Future<void> runReconciliation() =>
      _repo.runReconciliation();

  Future<AdminLedgerHealth> getLedgerHealth() => _repo.getLedgerHealth();

  // ─── Payouts ──────────────────────────────────────────────────────────────

  Future<List<AdminPayoutItem>> getPayoutStatus() => _repo.getPayoutStatus();

  Future<void> forcePayout(int organizerId) =>
      _repo.forcePayout(organizerId);

  // ─── Transactions ─────────────────────────────────────────────────────────

  Future<AdminPage<AdminTransaction>> getTransactions({
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

  Future<AdminMockOverview> getMockOverview() => _repo.getMockOverview();

  Future<void> simulateDispute(String transactionId) =>
      _repo.simulateDispute(transactionId);

  Future<void> clearMockData() => _repo.clearMockData();

  Future<void> settleAllPending() => _repo.settleAllPending();

  Future<void> failNextCharge() => _repo.failNextCharge();

  Future<void> resetMockDefaults() =>
      _repo.resetMockDefaults();

  // ─── Platform Account ─────────────────────────────────────────────────────

  Future<AdminPlatformAccount> getPlatformAccount() =>
      _repo.getPlatformAccount();

  Future<AdminPlatformAccount> updatePlatformAccount(
    UpdatePlatformAccountRequest data,
  ) =>
      _repo.updatePlatformAccount(data);

  // ─── Audit Log ────────────────────────────────────────────────────────────

  Future<AdminPage<AdminAuditEntry>> getAuditLog({
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

  Future<AdminWorkerSummary> getWorkerSummary() => _repo.getWorkerSummary();

  Future<AdminPage<AdminWorkerRun>> getWorkerRuns({
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

  Future<List<EmailTemplate>> getEmailTemplates() => _repo.getEmailTemplates();

  Future<void> uploadEmailLogo({
    required List<int> fileBytes,
    required String fileName,
  }) =>
      _repo.uploadEmailLogo(fileBytes: fileBytes, fileName: fileName);

  Future<EmailTemplate> saveEmailTemplate(
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

  Future<void> resetAllEmailTemplates() =>
      _repo.resetAllEmailTemplates();

  Future<void> testSendEmailTemplate(String key) =>
      _repo.testSendEmailTemplate(key);

  Future<EmailTemplate> resetEmailTemplate(String key) =>
      _repo.resetEmailTemplate(key);
}
