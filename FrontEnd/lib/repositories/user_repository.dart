import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/event.dart';
import '../models/rating.dart';
import '../models/user.dart';
import 'base_repository.dart';

class UserRepository extends BaseRepository {
  UserRepository(super.dio);

  // ─── Auth ───

  Future<AppUser> verifyToken(
    String idToken,
    String role, {
    String? displayName,
    String? termsAcceptedAt,
    String? birthday,
  }) async {
    final data = <String, dynamic>{
      'id_token': idToken,
      'role': role,
    };
    if (displayName != null) data['display_name'] = displayName;
    if (termsAcceptedAt != null) data['terms_accepted_at'] = termsAcceptedAt;
    if (birthday != null) data['birthday'] = birthday;
    final resp = await dio.post('/auth/verify', data: data);
    final body = Map<String, dynamic>.from(resp.data as Map);
    // VerifyResponse uses user_id; AppUser.fromJson expects id
    body['id'] ??= body['user_id'];
    return AppUser.fromJson(body);
  }

  // ─── User Profile ───

  Future<AppUser> getMe() async {
    final resp = await dio.get('/me');
    return AppUser.fromJson(resp.data);
  }

  Future<AppUser> updateMe(UpdateProfileRequest data) async {
    final resp = await dio.patch('/me', data: data.toJson());
    return AppUser.fromJson(resp.data);
  }

  // ─── Payment Info ───

  Future<PaymentInfo> getPaymentInfo() async {
    final resp = await dio.get('/me/payment-info');
    return PaymentInfo.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<PaymentInfo> updatePaymentInfo(
      UpdatePaymentInfoRequest data) async {
    final resp = await dio.put('/me/payment-info', data: data.toJson());
    return PaymentInfo.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  // ─── Bank Account ───

  Future<BankAccount> getBankAccount() async {
    final resp = await dio.get('/me/bank-account');
    return BankAccount.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<BankAccount> updateBankAccount(
      UpdateBankAccountRequest data) async {
    final resp = await dio.put('/me/bank-account', data: data.toJson());
    return BankAccount.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  // ─── Public Profiles ───

  Future<PublicProfile> getPublicProfile(int userId) async {
    final resp = await dio.get('/users/$userId/public-profile');
    return PublicProfile.fromJson(
        Map<String, dynamic>.from(resp.data as Map));
  }

  Future<SponsorPublicProfile> getSponsorPublicProfile(int userId) async {
    final resp = await dio.get('/users/$userId/sponsor-public-profile');
    return SponsorPublicProfile.fromJson(
        Map<String, dynamic>.from(resp.data as Map));
  }

  Future<List<Event>> getPublicEvents(
    int userId, {
    int offset = 0,
    int limit = 20,
    String? search,
    String? status,
  }) async {
    final params = <String, dynamic>{'offset': offset, 'limit': limit};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status.isNotEmpty) params['status'] = status;
    final resp = await dio.get('/users/$userId/public-events',
        queryParameters: params);
    return (resp.data as List).map((e) => Event.fromJson(e)).toList();
  }

  // ─── User Ratings ───

  Future<RatingsSummary> getUserRatingsSummary(int userId) async {
    final resp = await dio.get('/users/$userId/ratings-received');
    return RatingsSummary.fromJson(
        Map<String, dynamic>.from(resp.data as Map));
  }

  // ─── KYC ───

  Future<KycStatus> getKycStatus() async {
    final resp = await dio.get('/me/kyc-status');
    return KycStatus.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<KycDocumentUpload> uploadKycDocument(
    Uint8List bytes,
    String filename,
    String documentType,
  ) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
      'document_type': documentType,
    });
    final resp = await dio.post('/me/kyc-documents', data: formData);
    return KycDocumentUpload.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> deleteKycDocument(int documentId) async {
    await dio.delete('/me/kyc-documents/$documentId');
  }

  Future<KycSubmitResult> submitKyc() async {
    final resp = await dio.post('/me/kyc-submit', data: {});
    return KycSubmitResult.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<List<KycPendingUser>> adminGetKycPending() async {
    final resp = await dio.get('/admin/kyc-pending');
    return (resp.data as List)
        .map((e) =>
            KycPendingUser.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<KycDocument>> adminGetUserKycDocuments(int userId) async {
    final resp = await dio.get('/admin/users/$userId/kyc-documents');
    return (resp.data as List)
        .map((e) =>
            KycDocument.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<KycVerifyResult> adminVerifyKyc(
    int userId, {
    required bool approved,
    String? rejectionReason,
  }) async {
    final data = <String, dynamic>{'approved': approved};
    if (rejectionReason != null) data['rejection_reason'] = rejectionReason;
    final resp =
        await dio.post('/admin/users/$userId/kyc-verify', data: data);
    return KycVerifyResult.fromJson(resp.data as Map<String, dynamic>);
  }
}
