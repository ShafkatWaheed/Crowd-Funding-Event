import 'package:dio/dio.dart';

import 'base_repository.dart';

class UserRepository extends BaseRepository {
  UserRepository(super.dio);

  // ─── Auth ───

  Future<Map<String, dynamic>> verifyToken(
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
    return resp.data;
  }

  // ─── User Profile ───

  Future<Map<String, dynamic>> getMe() async {
    final resp = await dio.get('/me');
    return resp.data;
  }

  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> data) async {
    final resp = await dio.patch('/me', data: data);
    return resp.data;
  }

  // ─── Payment Info ───

  Future<Map<String, dynamic>> getPaymentInfo() async {
    final resp = await dio.get('/me/payment-info');
    return resp.data;
  }

  Future<Map<String, dynamic>> updatePaymentInfo(
      Map<String, dynamic> data) async {
    final resp = await dio.put('/me/payment-info', data: data);
    return resp.data;
  }

  // ─── Bank Account ───

  Future<Map<String, dynamic>> getBankAccount() async {
    final resp = await dio.get('/me/bank-account');
    return resp.data;
  }

  Future<Map<String, dynamic>> updateBankAccount(
      Map<String, dynamic> data) async {
    final resp = await dio.put('/me/bank-account', data: data);
    return resp.data;
  }

  // ─── Public Profiles ───

  Future<Map<String, dynamic>> getPublicProfile(int userId) async {
    final resp = await dio.get('/users/$userId/public-profile');
    return resp.data;
  }

  Future<Map<String, dynamic>> getSponsorPublicProfile(int userId) async {
    final resp = await dio.get('/users/$userId/sponsor-public-profile');
    return resp.data;
  }

  Future<List<dynamic>> getPublicEvents(
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
    return resp.data as List;
  }

  // ─── User Ratings ───

  Future<Map<String, dynamic>> getUserRatingsSummary(int userId) async {
    final resp = await dio.get('/users/$userId/ratings-received');
    return resp.data;
  }

  // ─── KYC ───

  Future<Map<String, dynamic>> getKycStatus() async {
    final resp = await dio.get('/me/kyc-status');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadKycDocument(
    String filePath,
    String documentType,
  ) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      'document_type': documentType,
    });
    final resp = await dio.post('/me/kyc-documents', data: formData);
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deleteKycDocument(int documentId) async {
    final resp = await dio.delete('/me/kyc-documents/$documentId');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitKyc() async {
    final resp = await dio.post('/me/kyc-submit', data: {});
    return resp.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> adminGetKycPending() async {
    final resp = await dio.get('/admin/kyc-pending');
    return resp.data as List<dynamic>;
  }

  Future<List<dynamic>> adminGetUserKycDocuments(int userId) async {
    final resp = await dio.get('/admin/users/$userId/kyc-documents');
    return resp.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> adminVerifyKyc(
    int userId, {
    required bool approved,
    String? rejectionReason,
  }) async {
    final data = <String, dynamic>{'approved': approved};
    if (rejectionReason != null) data['rejection_reason'] = rejectionReason;
    final resp =
        await dio.post('/admin/users/$userId/kyc-verify', data: data);
    return resp.data as Map<String, dynamic>;
  }
}
