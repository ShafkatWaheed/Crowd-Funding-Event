/// Factory methods for test data objects.
library;

import '../../lib/models/user.dart';
import '../../lib/models/event.dart';
import '../../lib/models/venue.dart';
import '../../lib/models/funding.dart';
import '../../lib/models/ticket.dart';
import '../../lib/models/sponsor.dart';
import '../../lib/models/chat_message.dart';
import '../../lib/models/milestone.dart';
import '../../lib/models/schedule.dart';
import '../../lib/models/ticket_strategy.dart';
import '../../lib/models/event_image.dart';
import '../../lib/models/post.dart';

// ── JSON builders (for fromJson round-trip tests) ──

Map<String, dynamic> userJson({
  int id = 1,
  String email = 'test@example.com',
  String? displayName = 'Test User',
  String role = 'customer',
  String? phone,
  String? birthday,
  String kycStatus = 'not_started',
  bool kycVerified = false,
}) =>
    {
      'id': id,
      'email': email,
      'display_name': displayName,
      'phone': phone,
      'role': role,
      'birthday': birthday,
      'kyc_status': kycStatus,
      'kyc_verified': kycVerified,
    };

Map<String, dynamic> venueJson({
  int id = 1,
  String name = 'Test Venue',
  String address = '123 Main St',
  String city = 'Test City',
  String? province,
  double? lat = 40.7128,
  double? lng = -74.0060,
  int maxCapacity = 500,
}) =>
    {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'province': province,
      'lat': lat,
      'lng': lng,
      'max_capacity': maxCapacity,
    };

Map<String, dynamic> eventJson({
  int id = 1,
  int organizerId = 10,
  String? organizerName = 'Organizer',
  int venueId = 1,
  String title = 'Test Event',
  String? description = 'A test event',
  String? startTime,
  String? endTime,
  int? fundingGoalCents = 100000,
  String? fundingEndAt,
  int minPledgeCents = 500,
  String status = 'approved',
  String registrationType = 'open',
  int maxCapacity = 200,
  int commonDiscountPercent = 0,
  int pledgeDiscountPercent = 5,
  int? totalPledgedCents = 50000,
  int? fundingDaysLeft = 14,
  String? genre,
  bool ageRestricted = false,
  int minAge = 18,
  Map<String, dynamic>? venue,
  String createdAt = '2025-01-15T10:00:00',
}) =>
    {
      'id': id,
      'organizer_id': organizerId,
      'organizer_name': organizerName,
      'venue_id': venueId,
      'title': title,
      'description': description,
      'start_time': startTime,
      'end_time': endTime,
      'funding_goal_cents': fundingGoalCents,
      'funding_end_at': fundingEndAt,
      'min_pledge_cents': minPledgeCents,
      'status': status,
      'registration_type': registrationType,
      'max_capacity': maxCapacity,
      'common_discount_percent': commonDiscountPercent,
      'pledge_discount_percent': pledgeDiscountPercent,
      'total_pledged_cents': totalPledgedCents,
      'funding_days_left': fundingDaysLeft,
      'genre': genre,
      'age_restricted': ageRestricted,
      'min_age': minAge,
      'venue': venue,
      'created_at': createdAt,
    };

Map<String, dynamic> pledgeJson({
  int id = 1,
  int eventId = 1,
  int userId = 1,
  int amountCents = 2000,
  String status = 'pledged',
  bool isGuest = false,
  String? receiptNumber = 'REC-001',
  String? eventTitle = 'Test Event',
  String createdAt = '2025-01-20T10:00:00',
}) =>
    {
      'id': id,
      'event_id': eventId,
      'user_id': userId,
      'amount_cents': amountCents,
      'status': status,
      'is_guest': isGuest,
      'receipt_number': receiptNumber,
      'event_title': eventTitle,
      'created_at': createdAt,
    };

Map<String, dynamic> fundingSummaryJson({
  int goalCents = 100000,
  int totalPledgedCents = 50000,
  int pledgeCount = 25,
  int totalReservedSpots = 10,
  String? fundingEndAt,
}) =>
    {
      'goal_cents': goalCents,
      'total_pledged_cents': totalPledgedCents,
      'pledge_count': pledgeCount,
      'total_reserved_spots': totalReservedSpots,
      'funding_end_at': fundingEndAt,
    };

Map<String, dynamic> ticketTierJson({
  int id = 1,
  int eventId = 1,
  String name = 'General',
  int priceCents = 5000,
  int maxReservedSpots = 0,
  int displayOrder = 0,
}) =>
    {
      'id': id,
      'event_id': eventId,
      'name': name,
      'price_cents': priceCents,
      'max_reserved_spots': maxReservedSpots,
      'display_order': displayOrder,
    };

Map<String, dynamic> ticketSaleJson({
  int id = 1,
  int eventId = 1,
  int userId = 1,
  int ticketTierId = 1,
  String ticketCode = 'TKT-001',
  String? receiptNumber = 'REC-TKT-001',
  String? tierName = 'General',
  String? eventTitle = 'Test Event',
  int amountPaidCents = 5000,
  int discountAppliedCents = 0,
  String status = 'active',
  String? scannedAt,
  String createdAt = '2025-02-01T10:00:00',
}) =>
    {
      'id': id,
      'event_id': eventId,
      'user_id': userId,
      'ticket_tier_id': ticketTierId,
      'ticket_code': ticketCode,
      'receipt_number': receiptNumber,
      'tier_name': tierName,
      'event_title': eventTitle,
      'amount_paid_cents': amountPaidCents,
      'discount_applied_cents': discountAppliedCents,
      'status': status,
      'scanned_at': scannedAt,
      'created_at': createdAt,
    };

Map<String, dynamic> sponsorProfileJson({
  int id = 1,
  int userId = 5,
  String companyName = 'Acme Corp',
  String contactName = 'John Doe',
  String profession = 'Marketing',
  String? logoUrl,
  String? description = 'A test sponsor',
}) =>
    {
      'id': id,
      'user_id': userId,
      'company_name': companyName,
      'contact_name': contactName,
      'profession': profession,
      'logo_url': logoUrl,
      'description': description,
    };

Map<String, dynamic> sponsorshipCategoryJson({
  int id = 1,
  int eventId = 1,
  String name = 'Gold Sponsor',
  int totalSpots = 5,
  int filledSpots = 2,
  int minBidCents = 10000,
}) =>
    {
      'id': id,
      'event_id': eventId,
      'name': name,
      'total_spots': totalSpots,
      'filled_spots': filledSpots,
      'min_bid_cents': minBidCents,
    };

Map<String, dynamic> sponsorBidJson({
  int id = 1,
  int categoryId = 1,
  int sponsorUserId = 5,
  int amountCents = 15000,
  String? proposalText = 'We want to sponsor',
  String status = 'pending',
}) =>
    {
      'id': id,
      'category_id': categoryId,
      'sponsor_user_id': sponsorUserId,
      'amount_cents': amountCents,
      'proposal_text': proposalText,
      'status': status,
    };

Map<String, dynamic> chatMessageJson({
  String id = 'msg-1',
  int bidId = 1,
  int senderId = 1,
  String body = 'Hello',
  String? clientId,
  String msgType = 'text',
  String createdAt = '2025-02-01T10:00:00',
}) =>
    {
      'id': id,
      'bid_id': bidId,
      'sender_id': senderId,
      'body': body,
      'client_id': clientId,
      'msg_type': msgType,
      'created_at': createdAt,
    };

Map<String, dynamic> chatConversationJson({
  int bidId = 1,
  int eventId = 1,
  String eventTitle = 'Test Event',
  String categoryName = 'Gold Sponsor',
  String bidStatus = 'pending',
  String eventStatus = 'approved',
  int sponsorUserId = 5,
  int organizerUserId = 10,
  int unreadCount = 3,
  bool isWritable = true,
}) =>
    {
      'bid_id': bidId,
      'event_id': eventId,
      'event_title': eventTitle,
      'category_name': categoryName,
      'bid_status': bidStatus,
      'event_status': eventStatus,
      'sponsor_user_id': sponsorUserId,
      'organizer_user_id': organizerUserId,
      'unread_count': unreadCount,
      'is_writable': isWritable,
    };

Map<String, dynamic> milestoneJson({
  int id = 1,
  int eventId = 1,
  String title = '50% Funded',
  String? description = 'Halfway there!',
  int unlockPercent = 50,
  String? benefitDescription = 'Free drinks',
  bool isUnlocked = false,
  String createdAt = '2025-01-20T10:00:00',
}) =>
    {
      'id': id,
      'event_id': eventId,
      'title': title,
      'description': description,
      'unlock_percent': unlockPercent,
      'benefit_description': benefitDescription,
      'is_unlocked': isUnlocked,
      'created_at': createdAt,
    };

Map<String, dynamic> scheduleItemJson({
  int id = 1,
  int eventId = 1,
  String date = '2025-03-15',
  String startTime = '09:00',
  String endTime = '10:00',
  String title = 'Opening Ceremony',
  String? description,
  String createdAt = '2025-01-20T10:00:00',
}) =>
    {
      'id': id,
      'event_id': eventId,
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      'title': title,
      'description': description,
      'created_at': createdAt,
    };

Map<String, dynamic> ticketStrategyJson({
  int id = 1,
  int organizerId = 10,
  String name = 'Concert Standard',
  List<Map<String, dynamic>>? tiers,
  String createdAt = '2025-01-10T10:00:00',
  String updatedAt = '2025-01-10T10:00:00',
}) =>
    {
      'id': id,
      'organizer_id': organizerId,
      'name': name,
      'tiers': tiers ??
          [
            {'id': 1, 'name': 'General', 'price_cents': 5000, 'display_order': 0},
            {'id': 2, 'name': 'VIP', 'price_cents': 15000, 'display_order': 1},
          ],
      'created_at': createdAt,
      'updated_at': updatedAt,
    };

Map<String, dynamic> eventImageJson({
  int id = 1,
  int eventId = 1,
  String imageUrl = 'https://example.com/image.jpg',
  String? caption = 'Event photo',
  int displayOrder = 0,
  String createdAt = '2025-01-20T10:00:00',
}) =>
    {
      'id': id,
      'event_id': eventId,
      'image_url': imageUrl,
      'caption': caption,
      'display_order': displayOrder,
      'created_at': createdAt,
    };

Map<String, dynamic> eventPostJson({
  int id = 1,
  int eventId = 1,
  int userId = 10,
  String? authorName = 'Organizer',
  String content = 'Exciting update!',
  String createdAt = '2025-01-25T10:00:00',
}) =>
    {
      'id': id,
      'event_id': eventId,
      'user_id': userId,
      'author_name': authorName,
      'content': content,
      'created_at': createdAt,
    };

// ── Model factory methods ──

AppUser makeUser({
  int id = 1,
  String email = 'test@example.com',
  String? displayName = 'Test User',
  UserRole role = UserRole.customer,
}) =>
    AppUser(
      id: id,
      email: email,
      displayName: displayName,
      role: role,
    );

Venue makeVenue({int id = 1}) => Venue.fromJson(venueJson(id: id));

Event makeEvent({
  int id = 1,
  String status = 'approved',
  String title = 'Test Event',
  int? fundingGoalCents = 100000,
  int? totalPledgedCents = 50000,
}) =>
    Event.fromJson(eventJson(
      id: id,
      status: status,
      title: title,
      fundingGoalCents: fundingGoalCents,
      totalPledgedCents: totalPledgedCents,
    ));

Pledge makePledge({int id = 1, String status = 'pledged'}) =>
    Pledge.fromJson(pledgeJson(id: id, status: status));

TicketTier makeTicketTier({int id = 1, int priceCents = 5000}) =>
    TicketTier.fromJson(ticketTierJson(id: id, priceCents: priceCents));

TicketSale makeTicketSale({int id = 1}) =>
    TicketSale.fromJson(ticketSaleJson(id: id));
