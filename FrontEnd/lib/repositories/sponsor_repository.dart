import 'package:dio/dio.dart';
import 'base_repository.dart';

/// Repository for all sponsor-related HTTP calls.
///
/// Groups: Profile, Discovery, Organizer Sponsors, Categories, Bids,
/// Payments, Tickets, Delegates, Public Sponsors, Prerequisites,
/// Category Templates, Chat.
class SponsorRepository extends BaseRepository {
  SponsorRepository(super.dio);

  // ── Sponsor Profile ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> getSponsorProfile() async {
    final resp = await dio.get('/me/sponsor-profile');
    return resp.data;
  }

  Future<Map<String, dynamic>> createSponsorProfile(
      Map<String, dynamic> data) async {
    final resp = await dio.post('/me/sponsor-profile', data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> updateSponsorProfile(
      Map<String, dynamic> data) async {
    final resp = await dio.patch('/me/sponsor-profile', data: data);
    return resp.data;
  }

  // ── Discovery ────────────────────────────────────────────────────────

  Future<List<dynamic>> getSponsorBidEvents() async {
    final resp = await dio.get('/me/sponsor-bid-events');
    return resp.data;
  }

  Future<List<dynamic>> getSponsorshipAvailableEvents(
      {bool excludeMyBids = false}) async {
    final resp = await dio.get('/events/sponsorship-available',
        queryParameters: {
          'exclude_my_bids': excludeMyBids,
        });
    return resp.data;
  }

  // ── Organizer: My Sponsors ───────────────────────────────────────────

  Future<List<dynamic>> getOrganizerSponsors({
    String? eventStatus,
    String? genre,
    int? eventId,
    int offset = 0,
    int limit = 20,
  }) async {
    final resp = await dio.get('/me/organizer-sponsors', queryParameters: {
      if (eventStatus != null) 'event_status': eventStatus,
      if (genre != null) 'genre': genre,
      if (eventId != null) 'event_id': eventId,
      'offset': offset,
      'limit': limit,
    });
    return resp.data as List;
  }

  Future<List<dynamic>> getSponsorEventsForOrganizer(
      int sponsorUserId) async {
    final resp =
        await dio.get('/me/organizer-sponsors/$sponsorUserId/events');
    return resp.data as List;
  }

  // ── Sponsorship Categories ───────────────────────────────────────────

  Future<List<dynamic>> getSponsorshipCategories(int eventId) async {
    final resp = await dio.get('/events/$eventId/sponsorships');
    return resp.data as List;
  }

  Future<Map<String, dynamic>> createSponsorshipCategory(
      int eventId, Map<String, dynamic> data) async {
    final resp =
        await dio.post('/events/$eventId/sponsorships', data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> updateSponsorshipCategory(
      int eventId, int catId, Map<String, dynamic> data) async {
    final resp = await dio
        .patch('/events/$eventId/sponsorships/$catId', data: data);
    return resp.data;
  }

  Future<void> deleteSponsorshipCategory(int eventId, int catId) async {
    await dio.delete('/events/$eventId/sponsorships/$catId');
  }

  // ── Sponsor Bids ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> placeBid(
      int eventId, int catId, Map<String, dynamic> data) async {
    final resp = await dio.post(
        '/events/$eventId/sponsorships/$catId/bids',
        data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> updateBid(
      int eventId, int catId, int bidId, Map<String, dynamic> data) async {
    final resp = await dio.patch(
        '/events/$eventId/sponsorships/$catId/bids/$bidId',
        data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> withdrawBid(
      int eventId, int catId, int bidId) async {
    final resp = await dio
        .post('/events/$eventId/sponsorships/$catId/bids/$bidId/withdraw');
    return resp.data;
  }

  Future<List<dynamic>> listBids(int eventId, int catId) async {
    final resp =
        await dio.get('/events/$eventId/sponsorships/$catId/bids');
    return resp.data as List;
  }

  Future<Map<String, dynamic>> acceptBid(
      int eventId, int catId, int bidId) async {
    final resp = await dio
        .post('/events/$eventId/sponsorships/$catId/bids/$bidId/accept');
    return resp.data;
  }

  Future<Map<String, dynamic>> rejectBid(
      int eventId, int catId, int bidId) async {
    final resp = await dio
        .post('/events/$eventId/sponsorships/$catId/bids/$bidId/reject');
    return resp.data;
  }

  Future<Map<String, dynamic>> refundBid(
      int eventId, int catId, int bidId) async {
    final resp = await dio.post(
        '/events/$eventId/sponsorships/$catId/bids/$bidId/refund');
    return resp.data;
  }

  // ── Sponsor Payments ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> payBid(
      int eventId, int catId, int bidId) async {
    final resp = await dio
        .post('/events/$eventId/sponsorships/$catId/bids/$bidId/pay');
    return resp.data;
  }

  Future<Map<String, dynamic>> getSponsorPaymentReceipt(
      int paymentId) async {
    final resp = await dio.get('/payments/$paymentId/receipt');
    return resp.data;
  }

  // ── Sponsor Tickets ──────────────────────────────────────────────────

  Future<List<dynamic>> getMySponsorTickets() async {
    final resp = await dio.get('/me/sponsor-tickets');
    return resp.data as List;
  }

  Future<Map<String, dynamic>> scanSponsorTicket(
      int eventId, String encryptedPayload) async {
    final resp = await dio.post('/events/$eventId/scan-sponsor', data: {
      'encrypted_payload': encryptedPayload,
    });
    return resp.data;
  }

  Future<List<dynamic>> getScannedSponsorTickets(int eventId) async {
    final resp =
        await dio.get('/events/$eventId/scanned-sponsor-tickets');
    return resp.data as List;
  }

  // ── Sponsor Delegates ────────────────────────────────────────────────

  Future<List<dynamic>> listDelegates(int ticketId) async {
    final resp =
        await dio.get('/me/sponsor-tickets/$ticketId/delegates');
    return resp.data as List;
  }

  Future<Map<String, dynamic>> addDelegate(
      int ticketId, String name,
      {String? email, String? phone}) async {
    final resp = await dio
        .post('/me/sponsor-tickets/$ticketId/delegates', data: {
      'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
    });
    return resp.data;
  }

  Future<void> removeDelegate(int ticketId, int delegateId) async {
    await dio
        .delete('/me/sponsor-tickets/$ticketId/delegates/$delegateId');
  }

  Future<Map<String, dynamic>> checkInDelegate(
      int eventId, int delegateId) async {
    final resp = await dio
        .post('/events/$eventId/sponsor-delegates/$delegateId/check-in');
    return resp.data;
  }

  // ── Public Sponsors ──────────────────────────────────────────────────

  Future<List<dynamic>> getEventSponsors(int eventId) async {
    final resp = await dio.get('/events/$eventId/sponsors');
    return resp.data as List;
  }

  // ── Prerequisites ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createPrerequisite(
      int eventId, int catId,
      {required String name,
      String? description,
      bool isRequired = true,
      bool requiresDocument = false}) async {
    final formData = FormData.fromMap({
      'name': name,
      if (description != null) 'description': description,
      'is_required': isRequired,
      'requires_document': requiresDocument,
    });
    final resp = await dio.post(
        '/events/$eventId/sponsorships/$catId/prerequisites',
        data: formData);
    return resp.data;
  }

  Future<List<dynamic>> listPrerequisites(int eventId, int catId) async {
    final resp = await dio
        .get('/events/$eventId/sponsorships/$catId/prerequisites');
    return resp.data as List;
  }

  Future<void> deletePrerequisite(
      int eventId, int catId, int prereqId) async {
    await dio.delete(
        '/events/$eventId/sponsorships/$catId/prerequisites/$prereqId');
  }

  Future<Map<String, dynamic>> uploadPrerequisiteDocument(
      int bidId, int prereqId, String filePath, String fileName) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final resp = await dio.post(
        '/bids/$bidId/prerequisites/$prereqId/upload',
        data: formData);
    return resp.data;
  }

  Future<List<dynamic>> listBidPrerequisiteUploads(int bidId) async {
    final resp = await dio.get('/bids/$bidId/prerequisites');
    return resp.data as List;
  }

  Future<Map<String, dynamic>> uploadCategoryPrerequisite(
      int eventId, int catId, int prereqId,
      {String? filePath,
      String? fileName,
      List<int>? fileBytes}) async {
    late final MultipartFile multipart;
    if (fileBytes != null) {
      multipart = MultipartFile.fromBytes(fileBytes,
          filename: fileName ?? 'document');
    } else if (filePath != null) {
      multipart =
          await MultipartFile.fromFile(filePath, filename: fileName);
    } else {
      throw ArgumentError('Either filePath or fileBytes must be provided');
    }
    final formData = FormData.fromMap({'file': multipart});
    final resp = await dio.post(
        '/events/$eventId/sponsorships/$catId/upload-prerequisite/$prereqId',
        data: formData);
    return resp.data;
  }

  Future<Map<String, dynamic>> reviewPrerequisiteUpload(
      int bidId, int prereqId,
      {required String status, String? reviewerNote}) async {
    final formData = FormData.fromMap({
      'status': status,
      if (reviewerNote != null) 'reviewer_note': reviewerNote,
    });
    final resp = await dio.patch(
        '/bids/$bidId/prerequisites/$prereqId/review',
        data: formData);
    return resp.data;
  }

  // ── Sponsor Category Templates ───────────────────────────────────────

  Future<List<dynamic>> getSponsorCategoryTemplates() async {
    final resp = await dio.get('/me/sponsor-category-templates');
    return resp.data as List;
  }

  Future<Map<String, dynamic>> createSponsorCategoryTemplate(
      Map<String, dynamic> data) async {
    final resp =
        await dio.post('/me/sponsor-category-templates', data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> updateSponsorCategoryTemplate(
      int id, Map<String, dynamic> data) async {
    final resp = await dio
        .patch('/me/sponsor-category-templates/$id', data: data);
    return resp.data;
  }

  Future<void> deleteSponsorCategoryTemplate(int id) async {
    await dio.delete('/me/sponsor-category-templates/$id');
  }

  Future<Map<String, dynamic>> copyTemplateToEvent(
      int eventId, int templateId) async {
    final resp = await dio.post(
        '/events/$eventId/sponsorships/from-template/$templateId');
    return resp.data;
  }

  Future<List<dynamic>> listTemplatePrerequisites(
      int templateId) async {
    final resp = await dio
        .get('/me/sponsor-category-templates/$templateId/prerequisites');
    return resp.data as List;
  }

  Future<Map<String, dynamic>> createTemplatePrerequisite(
      int templateId,
      {required String name,
      String? description,
      bool isRequired = true,
      bool requiresDocument = false}) async {
    final formData = FormData.fromMap({
      'name': name,
      if (description != null) 'description': description,
      'is_required': isRequired,
      'requires_document': requiresDocument,
    });
    final resp = await dio.post(
        '/me/sponsor-category-templates/$templateId/prerequisites',
        data: formData);
    return resp.data;
  }

  Future<void> deleteTemplatePrerequisite(
      int templateId, int prereqId) async {
    await dio.delete(
        '/me/sponsor-category-templates/$templateId/prerequisites/$prereqId');
  }

  // ── Chat (sponsor-specific) ──────────────────────────────────────────

  Future<Map<String, dynamic>> uploadChatImage(int bidId,
      {required List<int> fileBytes, required String fileName}) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
    });
    final resp =
        await dio.post('/chat/bids/$bidId/upload', data: formData);
    return resp.data;
  }

  // ── Admin: Sponsor Bid Refund ────────────────────────────────────────

  Future<void> adminRefundSponsorBid(
      int eventId, int catId, int bidId) async {
    await dio.post(
        '/admin/events/$eventId/sponsorships/$catId/bids/$bidId/refund');
  }
}
