import 'package:flutter/foundation.dart';

import '../models/event.dart';
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

  Future<AppUser> updateMe(Map<String, dynamic> data) => _repo.updateMe(data);

  // ─── Payment Info ───

  Future<Map<String, dynamic>> getPaymentInfo() => _repo.getPaymentInfo();

  Future<Map<String, dynamic>> updatePaymentInfo(
          Map<String, dynamic> data) =>
      _repo.updatePaymentInfo(data);

  // ─── Bank Account ───

  Future<Map<String, dynamic>> getBankAccount() => _repo.getBankAccount();

  Future<Map<String, dynamic>> updateBankAccount(
          Map<String, dynamic> data) =>
      _repo.updateBankAccount(data);

  // ─── Public Profiles ───

  Future<Map<String, dynamic>> getPublicProfile(int userId) =>
      _repo.getPublicProfile(userId);

  Future<Map<String, dynamic>> getSponsorPublicProfile(int userId) =>
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

  Future<Map<String, dynamic>> getUserRatingsSummary(int userId) =>
      _repo.getUserRatingsSummary(userId);

  // ─── KYC ───

  Future<Map<String, dynamic>> getKycStatus() => _repo.getKycStatus();

  Future<Map<String, dynamic>> uploadKycDocument(
          String filePath, String documentType) =>
      _repo.uploadKycDocument(filePath, documentType);

  Future<Map<String, dynamic>> deleteKycDocument(int documentId) =>
      _repo.deleteKycDocument(documentId);

  Future<Map<String, dynamic>> submitKyc() => _repo.submitKyc();

  Future<List<AppUser>> adminGetKycPending() => _repo.adminGetKycPending();

  Future<List<dynamic>> adminGetUserKycDocuments(int userId) =>
      _repo.adminGetUserKycDocuments(userId);

  Future<Map<String, dynamic>> adminVerifyKyc(
    int userId, {
    required bool approved,
    String? rejectionReason,
  }) =>
      _repo.adminVerifyKyc(userId,
          approved: approved, rejectionReason: rejectionReason);
}
