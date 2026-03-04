import 'package:flutter/foundation.dart';

import '../models/event.dart';
import '../models/sponsor.dart';
import '../repositories/sponsor_repository.dart';

/// Thin provider wrapper around [SponsorRepository].
///
/// Every public method is a direct pass-through to the repository.
/// Screens should call these methods via `context.read<SponsorProvider>()`.
class SponsorProvider extends ChangeNotifier {
  final SponsorRepository _repo;
  SponsorProvider(this._repo);

  // ── Sponsor Profile ────────────────────────────────────────────────────

  Future<SponsorProfile> getSponsorProfile() =>
      _repo.getSponsorProfile();

  Future<SponsorProfile> createSponsorProfile(
          SponsorProfileRequest data) =>
      _repo.createSponsorProfile(data);

  Future<SponsorProfile> updateSponsorProfile(
          SponsorProfileRequest data) =>
      _repo.updateSponsorProfile(data);

  // ── Discovery ──────────────────────────────────────────────────────────

  Future<List<SponsorBidEvent>> getSponsorBidEvents() =>
      _repo.getSponsorBidEvents();

  Future<List<Event>> getSponsorshipAvailableEvents(
          {bool excludeMyBids = false}) =>
      _repo.getSponsorshipAvailableEvents(excludeMyBids: excludeMyBids);

  // ── Organizer: My Sponsors ─────────────────────────────────────────────

  Future<List<OrganizerSponsorItem>> getOrganizerSponsors({
    String? eventStatus,
    String? genre,
    int? eventId,
    int offset = 0,
    int limit = 20,
  }) =>
      _repo.getOrganizerSponsors(
        eventStatus: eventStatus,
        genre: genre,
        eventId: eventId,
        offset: offset,
        limit: limit,
      );

  Future<List<SponsorEventItem>> getSponsorEventsForOrganizer(
          int sponsorUserId) =>
      _repo.getSponsorEventsForOrganizer(sponsorUserId);

  // ── Sponsorship Categories ─────────────────────────────────────────────

  Future<List<SponsorshipCategory>> getSponsorshipCategories(int eventId) =>
      _repo.getSponsorshipCategories(eventId);

  Future<SponsorshipCategory> createSponsorshipCategory(
          int eventId, CreateSponsorshipCategoryRequest data) =>
      _repo.createSponsorshipCategory(eventId, data);

  Future<SponsorshipCategory> updateSponsorshipCategory(
          int eventId, int catId, UpdateSponsorshipCategoryRequest data) =>
      _repo.updateSponsorshipCategory(eventId, catId, data);

  Future<void> deleteSponsorshipCategory(int eventId, int catId) =>
      _repo.deleteSponsorshipCategory(eventId, catId);

  // ── Sponsor Bids ───────────────────────────────────────────────────────

  Future<SponsorBid> placeBid(
          int eventId, int catId, PlaceBidRequest data) =>
      _repo.placeBid(eventId, catId, data);

  Future<SponsorBid> updateBid(
          int eventId, int catId, int bidId, UpdateBidRequest data) =>
      _repo.updateBid(eventId, catId, bidId, data);

  Future<SponsorBid> withdrawBid(int eventId, int catId, int bidId) =>
      _repo.withdrawBid(eventId, catId, bidId);

  Future<List<SponsorBid>> listBids(int eventId, int catId) =>
      _repo.listBids(eventId, catId);

  Future<SponsorBid> acceptBid(int eventId, int catId, int bidId) =>
      _repo.acceptBid(eventId, catId, bidId);

  Future<SponsorBid> rejectBid(int eventId, int catId, int bidId) =>
      _repo.rejectBid(eventId, catId, bidId);

  Future<SponsorBid> refundBid(int eventId, int catId, int bidId) =>
      _repo.refundBid(eventId, catId, bidId);

  // ── Sponsor Payments ───────────────────────────────────────────────────

  Future<SponsorPayment> payBid(
          int eventId, int catId, int bidId) =>
      _repo.payBid(eventId, catId, bidId);

  Future<SponsorPaymentReceipt> getSponsorPaymentReceipt(int paymentId) =>
      _repo.getSponsorPaymentReceipt(paymentId);

  // ── Sponsor Tickets ────────────────────────────────────────────────────

  Future<List<dynamic>> getMySponsorTicketsRaw() =>
      _repo.getMySponsorTicketsRaw();

  Future<List<SponsorTicketModel>> getMySponsorTickets() =>
      _repo.getMySponsorTickets();

  Future<ScannedSponsorTicket> scanSponsorTicket(
          int eventId, String encryptedPayload) =>
      _repo.scanSponsorTicket(eventId, encryptedPayload);

  Future<List<ScannedSponsorTicket>> getScannedSponsorTickets(
          int eventId) =>
      _repo.getScannedSponsorTickets(eventId);

  // ── Sponsor Delegates ──────────────────────────────────────────────────

  Future<List<SponsorDelegate>> listDelegates(int ticketId) =>
      _repo.listDelegates(ticketId);

  Future<SponsorDelegate> addDelegate(int ticketId, String name,
          {String? email, String? phone}) =>
      _repo.addDelegate(ticketId, name, email: email, phone: phone);

  Future<void> removeDelegate(int ticketId, int delegateId) =>
      _repo.removeDelegate(ticketId, delegateId);

  Future<SponsorDelegate> checkInDelegate(
          int eventId, int delegateId) =>
      _repo.checkInDelegate(eventId, delegateId);

  // ── Public Sponsors ────────────────────────────────────────────────────

  Future<List<EventSponsor>> getEventSponsors(int eventId) =>
      _repo.getEventSponsors(eventId);

  // ── Prerequisites ──────────────────────────────────────────────────────

  Future<CategoryPrerequisite> createPrerequisite(
          int eventId, int catId,
          {required String name,
          String? description,
          bool isRequired = true,
          bool requiresDocument = false}) =>
      _repo.createPrerequisite(eventId, catId,
          name: name,
          description: description,
          isRequired: isRequired,
          requiresDocument: requiresDocument);

  Future<List<CategoryPrerequisite>> listPrerequisites(
          int eventId, int catId) =>
      _repo.listPrerequisites(eventId, catId);

  Future<void> deletePrerequisite(
          int eventId, int catId, int prereqId) =>
      _repo.deletePrerequisite(eventId, catId, prereqId);

  Future<FileUploadResult> uploadPrerequisiteDocument(
          int bidId, int prereqId, String filePath, String fileName) =>
      _repo.uploadPrerequisiteDocument(bidId, prereqId, filePath, fileName);

  Future<List<BidPrerequisiteUpload>> listBidPrerequisiteUploads(
          int bidId) =>
      _repo.listBidPrerequisiteUploads(bidId);

  Future<FileUploadResult> uploadCategoryPrerequisite(
          int eventId, int catId, int prereqId,
          {String? filePath, String? fileName, List<int>? fileBytes}) =>
      _repo.uploadCategoryPrerequisite(eventId, catId, prereqId,
          filePath: filePath, fileName: fileName, fileBytes: fileBytes);

  Future<BidPrerequisiteUpload> reviewPrerequisiteUpload(
          int bidId, int prereqId,
          {required String status, String? reviewerNote}) =>
      _repo.reviewPrerequisiteUpload(bidId, prereqId,
          status: status, reviewerNote: reviewerNote);

  // ── Sponsor Category Templates ─────────────────────────────────────────

  Future<List<SponsorCategoryTemplate>> getSponsorCategoryTemplates() =>
      _repo.getSponsorCategoryTemplates();

  Future<SponsorCategoryTemplate> createSponsorCategoryTemplate(
          CreateSponsorCategoryTemplateRequest data) =>
      _repo.createSponsorCategoryTemplate(data);

  Future<SponsorCategoryTemplate> updateSponsorCategoryTemplate(
          int id, UpdateSponsorCategoryTemplateRequest data) =>
      _repo.updateSponsorCategoryTemplate(id, data);

  Future<void> deleteSponsorCategoryTemplate(int id) =>
      _repo.deleteSponsorCategoryTemplate(id);

  Future<SponsorshipCategory> copyTemplateToEvent(
          int eventId, int templateId) =>
      _repo.copyTemplateToEvent(eventId, templateId);

  Future<List<TemplatePrerequisite>> listTemplatePrerequisites(
          int templateId) =>
      _repo.listTemplatePrerequisites(templateId);

  Future<TemplatePrerequisite> createTemplatePrerequisite(int templateId,
          {required String name,
          String? description,
          bool isRequired = true,
          bool requiresDocument = false}) =>
      _repo.createTemplatePrerequisite(templateId,
          name: name,
          description: description,
          isRequired: isRequired,
          requiresDocument: requiresDocument);

  Future<void> deleteTemplatePrerequisite(
          int templateId, int prereqId) =>
      _repo.deleteTemplatePrerequisite(templateId, prereqId);

  // ── Chat (sponsor-specific) ────────────────────────────────────────────

  Future<ChatImageUpload> uploadChatImage(int bidId,
          {required List<int> fileBytes, required String fileName}) =>
      _repo.uploadChatImage(bidId, fileBytes: fileBytes, fileName: fileName);

  // ── Admin: Sponsor Bid Refund ──────────────────────────────────────────

  Future<void> adminRefundSponsorBid(
          int eventId, int catId, int bidId) =>
      _repo.adminRefundSponsorBid(eventId, catId, bidId);
}
