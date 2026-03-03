import 'package:flutter/foundation.dart';

import '../models/ticket.dart';
import '../models/ticket_strategy.dart';
import '../repositories/base_repository.dart';
import '../repositories/ticket_repository.dart';

class TicketProvider extends ChangeNotifier {
  final TicketRepository _repo;
  TicketProvider(this._repo);

  // ─── Ticket Strategies ───

  Future<List<TicketStrategy>> getTicketStrategies() =>
      _repo.getTicketStrategies();

  Future<TicketStrategy> createTicketStrategy(Map<String, dynamic> data) =>
      _repo.createTicketStrategy(data);

  Future<TicketStrategy> getTicketStrategy(int id) =>
      _repo.getTicketStrategy(id);

  Future<void> deleteTicketStrategy(int id) =>
      _repo.deleteTicketStrategy(id);

  // ─── Customer tickets ───

  Future<PaginatedResult<TicketSale>> getMyTickets({
    int offset = 0,
    int limit = 20,
    String? sortBy,
  }) =>
      _repo.getMyTickets(offset: offset, limit: limit, sortBy: sortBy);

  Future<List<dynamic>> getMyTicketsRaw({int offset = 0, int limit = 20}) =>
      _repo.getMyTicketsRaw(offset: offset, limit: limit);

  Future<List<dynamic>> getTicketSalesRaw(int eventId,
          {int offset = 0, int limit = 20}) =>
      _repo.getTicketSalesRaw(eventId, offset: offset, limit: limit);

  // ─── Ticket tiers ───

  Future<List<TicketTier>> getTicketTiers(int eventId) =>
      _repo.getTicketTiers(eventId);

  Future<TicketTier> createTicketTier(
          int eventId, Map<String, dynamic> data) =>
      _repo.createTicketTier(eventId, data);

  Future<TicketTier> updateTicketTier(
          int eventId, int tierId, Map<String, dynamic> data) =>
      _repo.updateTicketTier(eventId, tierId, data);

  Future<void> deleteTicketTier(int eventId, int tierId) =>
      _repo.deleteTicketTier(eventId, tierId);

  // ─── Ticket pricing ───

  Future<Map<String, dynamic>> getTicketPrice(
          int eventId, int ticketTierId) =>
      _repo.getTicketPrice(eventId, ticketTierId);

  // ─── Ticket purchase ───

  Future<List<TicketSale>> purchaseTickets(int eventId,
          {required int tierId, int quantity = 1, String? extraPerks}) =>
      _repo.purchaseTickets(eventId,
          tierId: tierId, quantity: quantity, extraPerks: extraPerks);

  // ─── Ticket receipts ───

  Future<Map<String, dynamic>> getTicketReceipt(int eventId, int saleId) =>
      _repo.getTicketReceipt(eventId, saleId);

  Future<Map<String, dynamic>> getMyTicketReceipt(int saleId) =>
      _repo.getMyTicketReceipt(saleId);

  Future<Map<String, dynamic>> getPurchaseGroupReceipt(
          int eventId, String groupId) =>
      _repo.getPurchaseGroupReceipt(eventId, groupId);

  // ─── Ticket sales stats ───

  Future<Map<String, dynamic>> getTicketSalesStats(int eventId) =>
      _repo.getTicketSalesStats(eventId);

  // ─── Ticket scanning ───

  Future<Map<String, dynamic>> scanTicket(int eventId,
          {String? ticketCode, String? encryptedPayload}) =>
      _repo.scanTicket(eventId,
          ticketCode: ticketCode, encryptedPayload: encryptedPayload);

  // ─── Ticket sales lists (organizer/event) ───

  Future<List<TicketSale>> getTicketSales(int eventId,
          {int offset = 0, int limit = 20}) =>
      _repo.getTicketSales(eventId, offset: offset, limit: limit);

  Future<List<TicketSale>> getScannedTickets(int eventId,
          {int offset = 0, int limit = 20}) =>
      _repo.getScannedTickets(eventId, offset: offset, limit: limit);

  // ─── Organizer cross-event sales ───

  Future<List<TicketSale>> getOrganizerTicketSales({
    bool scannedOnly = false,
    String? eventStatus,
    String? genre,
    int? eventId,
    int offset = 0,
    int limit = 20,
  }) =>
      _repo.getOrganizerTicketSales(
        scannedOnly: scannedOnly,
        eventStatus: eventStatus,
        genre: genre,
        eventId: eventId,
        offset: offset,
        limit: limit,
      );

  // ─── Refunds ───

  Future<Map<String, dynamic>> requestTicketRefund(
          int eventId, int ticketId) =>
      _repo.requestTicketRefund(eventId, ticketId);

  Future<List<TicketSale>> getRefundRequests(int eventId) =>
      _repo.getRefundRequests(eventId);

  Future<List<TicketSale>> getOrganizerRefundRequests({
    int? eventId,
    int offset = 0,
    int limit = 50,
  }) =>
      _repo.getOrganizerRefundRequests(
          eventId: eventId, offset: offset, limit: limit);

  Future<Map<String, dynamic>> approveTicketRefund(
          int eventId, int ticketId) =>
      _repo.approveTicketRefund(eventId, ticketId);

  Future<Map<String, dynamic>> rejectTicketRefund(
          int eventId, int ticketId) =>
      _repo.rejectTicketRefund(eventId, ticketId);

  // ─── Waitlist ───

  Future<List<TicketSale>> getWaitlistedTickets(int eventId) =>
      _repo.getWaitlistedTickets(eventId);

  Future<Map<String, dynamic>> approveWaitlistedTicket(
          int eventId, int ticketId) =>
      _repo.approveWaitlistedTicket(eventId, ticketId);

  Future<Map<String, dynamic>> rejectWaitlistedTicket(
          int eventId, int ticketId) =>
      _repo.rejectWaitlistedTicket(eventId, ticketId);

  // ─── Event discounts ───

  Future<List<dynamic>> getEventDiscounts(int eventId) =>
      _repo.getEventDiscounts(eventId);

  Future<Map<String, dynamic>> createEventDiscount(
          int eventId, Map<String, dynamic> data) =>
      _repo.createEventDiscount(eventId, data);

  Future<void> deleteEventDiscount(int eventId, int discountId) =>
      _repo.deleteEventDiscount(eventId, discountId);

  Future<List<dynamic>> getMyDiscounts(int eventId) =>
      _repo.getMyDiscounts(eventId);

  // ─── Discount strategies ───

  Future<List<dynamic>> getDiscountStrategies() =>
      _repo.getDiscountStrategies();

  Future<Map<String, dynamic>> createDiscountStrategy(
          Map<String, dynamic> data) =>
      _repo.createDiscountStrategy(data);

  Future<void> deleteDiscountStrategy(int id) =>
      _repo.deleteDiscountStrategy(id);

  Future<void> attachDiscountStrategy(int eventId, int strategyId,
          {bool autoApply = true}) =>
      _repo.attachDiscountStrategy(eventId, strategyId, autoApply: autoApply);

  Future<void> detachDiscountStrategy(int eventId, int strategyId) =>
      _repo.detachDiscountStrategy(eventId, strategyId);

  Future<List<dynamic>> getEventDiscountStrategies(int eventId) =>
      _repo.getEventDiscountStrategies(eventId);

  // ─── Customer discount claims ───

  Future<List<dynamic>> getClaimableDiscounts(int eventId) =>
      _repo.getClaimableDiscounts(eventId);

  Future<void> claimDiscount(int eventId, int linkId) =>
      _repo.claimDiscount(eventId, linkId);

  Future<void> unclaimDiscount(int eventId, int linkId) =>
      _repo.unclaimDiscount(eventId, linkId);

  // ─── Early bird discounts ───

  Future<List<dynamic>> getEarlyBirdDiscounts(int eventId) =>
      _repo.getEarlyBirdDiscounts(eventId);

  Future<Map<String, dynamic>> createEarlyBirdDiscount(
          int eventId, Map<String, dynamic> data) =>
      _repo.createEarlyBirdDiscount(eventId, data);

  Future<Map<String, dynamic>> updateEarlyBirdDiscount(
          int eventId, int discountId, Map<String, dynamic> data) =>
      _repo.updateEarlyBirdDiscount(eventId, discountId, data);

  Future<void> deleteEarlyBirdDiscount(int eventId, int discountId) =>
      _repo.deleteEarlyBirdDiscount(eventId, discountId);

  // ─── Admin ───

  Future<PaginatedResult<TicketSale>> adminGetTickets({
    int offset = 0,
    int limit = 20,
    String? search,
    String? status,
  }) =>
      _repo.adminGetTickets(
          offset: offset, limit: limit, search: search, status: status);
}
