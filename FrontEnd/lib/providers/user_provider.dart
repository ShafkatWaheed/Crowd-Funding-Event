import 'package:flutter/foundation.dart';

import '../models/event.dart';
import '../models/rating.dart';
import '../models/user.dart';
import '../repositories/user_repository.dart';

class UserProvider extends ChangeNotifier {
  final UserRepository _repo;
  UserProvider(this._repo);

  // ─── Auth ───

  Future<AppUser> verifyToken(
    String idToken,
    String role, {
    String? displayName,
    String? termsAcceptedAt,
    String? birthday,
  }) =>
      _repo.verifyToken(idToken, role,
          displayName: displayName,
          termsAcceptedAt: termsAcceptedAt,
          birthday: birthday);

  // ─── User Profile ───

  Future<AppUser> getMe() => _repo.getMe();

  Future<AppUser> updateMe(UpdateProfileRequest data) => _repo.updateMe(data);

  // ─── Payment Info ───

  Future<PaymentInfo> getPaymentInfo() => _repo.getPaymentInfo();

  Future<PaymentInfo> updatePaymentInfo(UpdatePaymentInfoRequest data) =>
      _repo.updatePaymentInfo(data);

  // ─── Bank Account ───

  Future<BankAccount> getBankAccount() => _repo.getBankAccount();

  Future<BankAccount> updateBankAccount(UpdateBankAccountRequest data) =>
      _repo.updateBankAccount(data);

  // ─── Public Profiles ───

  Future<PublicProfile> getPublicProfile(int userId) =>
      _repo.getPublicProfile(userId);

  Future<SponsorPublicProfile> getSponsorPublicProfile(int userId) =>
      _repo.getSponsorPublicProfile(userId);

  Future<List<Event>> getPublicEvents(
    int userId, {
    int offset = 0,
    int limit = 20,
    String? search,
    String? status,
  }) =>
      _repo.getPublicEvents(userId,
          offset: offset, limit: limit, search: search, status: status);

  // ─── User Ratings ───

  Future<RatingsSummary> getUserRatingsSummary(int userId) =>
      _repo.getUserRatingsSummary(userId);

  // ─── KYC ───

  Future<KycStatus> getKycStatus() => _repo.getKycStatus();

  Future<KycDocumentUpload> uploadKycDocument(
          String filePath, String documentType) =>
      _repo.uploadKycDocument(filePath, documentType);

  Future<void> deleteKycDocument(int documentId) =>
      _repo.deleteKycDocument(documentId);

  Future<KycSubmitResult> submitKyc() => _repo.submitKyc();

  Future<List<KycPendingUser>> adminGetKycPending() =>
      _repo.adminGetKycPending();

  Future<List<KycDocument>> adminGetUserKycDocuments(int userId) =>
      _repo.adminGetUserKycDocuments(userId);

  Future<KycVerifyResult> adminVerifyKyc(
    int userId, {
    required bool approved,
    String? rejectionReason,
  }) =>
      _repo.adminVerifyKyc(userId,
          approved: approved, rejectionReason: rejectionReason);
}
