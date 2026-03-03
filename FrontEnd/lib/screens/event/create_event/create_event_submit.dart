import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/event_form_models.dart';
import '../../../models/venue.dart';
import '../../../providers/event_provider.dart';
import '../../../providers/ticket_provider.dart';
import '../../../providers/sponsor_provider.dart';

Map<String, dynamic> buildCreateEventPayload({
  required int selectedVenueId,
  required String title,
  required String description,
  required int maxCapacity,
  required String registrationType,
  required double minPledge,
  required int maxReservedSpotsPerUser,
  required String? genre,
  required bool communityRules,
  required bool postsEnabled,
  required bool publish,
  required DateTime? startTime,
  required DateTime? endTime,
  required DateTime? fundingEndAt,
  required int refundDeadlineDays,
  required double? fundingGoal,
  required int? selectedStrategyId,
  required List<Venue> venues,
  required String parkingInfo,
  required String transitInfo,
  required String rideshareInfo,
  required String accessibilityInfo,
  required bool hasSchedule,
  required bool linkFundingToTiers,
  required int maxDiscountPercent,
  required bool ageRestricted,
  required int minAge,
  required int? waitlistMaxSize,
  required bool waitlistAutoApprove,
  required int? eventMaxImages,
  required int? maxPostsPerDay,
  required int? maxCoOrganizers,
}) {
  final data = <String, dynamic>{
    'venue_id': selectedVenueId,
    'title': title.trim(),
    'description': description.trim(),
    'max_capacity': maxCapacity,
    'registration_type': registrationType,
    'min_pledge_cents': (minPledge * 100).toInt(),
    'max_reserved_spots_per_user': maxReservedSpotsPerUser,
    'genre': genre,
    'community_rules': communityRules,
    'posts_enabled': postsEnabled,
    'publish': publish,
  };

  if (startTime != null) data['start_time'] = startTime.toUtc().toIso8601String();
  if (endTime != null) data['end_time'] = endTime.toUtc().toIso8601String();
  if (fundingEndAt != null) {
    data['funding_end_at'] = fundingEndAt.toUtc().toIso8601String();
    if (refundDeadlineDays > 0) data['refund_deadline_days'] = refundDeadlineDays;
  }
  if (fundingGoal != null && fundingGoal > 0) {
    data['funding_goal_cents'] = (fundingGoal * 100).toInt();
  }
  if (selectedStrategyId != null) data['ticket_strategy_id'] = selectedStrategyId;

  final selectedVenue = venues.where((v) => v.id == selectedVenueId).firstOrNull;
  if (selectedVenue != null) {
    data['lat'] = selectedVenue.lat;
    data['lng'] = selectedVenue.lng;
  }
  if (parkingInfo.isNotEmpty) data['parking_info'] = parkingInfo;
  if (transitInfo.isNotEmpty) data['transit_info'] = transitInfo;
  if (rideshareInfo.isNotEmpty) data['rideshare_info'] = rideshareInfo;
  if (accessibilityInfo.isNotEmpty) data['accessibility_info'] = accessibilityInfo;
  if (hasSchedule) data['has_schedule'] = true;
  if (linkFundingToTiers) data['link_funding_to_tiers'] = true;
  if (maxDiscountPercent != 100) data['max_discount_percent'] = maxDiscountPercent;
  if (ageRestricted) {
    data['age_restricted'] = true;
    data['min_age'] = minAge;
  }

  if (waitlistMaxSize != null && waitlistMaxSize > 0) data['waitlist_max_size'] = waitlistMaxSize;
  data['waitlist_auto_approve'] = waitlistAutoApprove;
  if (eventMaxImages != null && eventMaxImages > 0) data['event_max_images'] = eventMaxImages;
  if (maxPostsPerDay != null && maxPostsPerDay > 0) data['max_posts_per_day'] = maxPostsPerDay;
  if (maxCoOrganizers != null && maxCoOrganizers > 0) data['max_co_organizers'] = maxCoOrganizers;

  return data;
}

Future<int> executeCreateEventSubmission({
  required SponsorProvider sponsorRepo,
  required EventProvider eventRepo,
  required TicketProvider ticketRepo,
  required Map<String, dynamic> eventData,
  required Map<int, bool> selectedDiscounts,
  required List<EditableTier> localTiers,
  required List<MilestoneInput> milestones,
  required List<EarlyBirdInput> earlyBirdDiscounts,
  required bool hasSchedule,
  required List<ScheduleDayInput> scheduleDays,
  required List<EditableSponsorCategory> localCategories,
  required List<XFile> pickedImages,
  required Map<int, Uint8List> imageBytes,
}) async {
  final resp = await eventRepo.createEventRaw(eventData);
  final eventId = resp.id;

  await _attachDiscounts(ticketRepo, eventId, selectedDiscounts);
  await _createTiers(ticketRepo, eventId, localTiers);
  await _createMilestones(eventRepo, ticketRepo, eventId, milestones);
  await _createEarlyBirdDiscounts(ticketRepo, eventId, earlyBirdDiscounts);
  if (hasSchedule) await _createSchedule(eventRepo, eventId, scheduleDays);
  await _createSponsorCategories(sponsorRepo, eventId, localCategories);
  await _uploadImages(eventRepo, eventId, pickedImages, imageBytes);

  return eventId;
}

Future<void> _attachDiscounts(TicketProvider ticketRepo, int eventId, Map<int, bool> selectedDiscounts) async {
  for (final entry in selectedDiscounts.entries) {
    try {
      await ticketRepo.attachDiscountStrategy(eventId, entry.key, autoApply: entry.value);
    } catch (e) { debugPrint(e.toString()); }
  }
}

Future<void> _createTiers(TicketProvider ticketRepo, int eventId, List<EditableTier> localTiers) async {
  for (int i = 0; i < localTiers.length; i++) {
    final t = localTiers[i];
    final name = t.nameCtrl.text.trim();
    if (name.isEmpty) continue;
    try {
      final tierData = <String, dynamic>{
        'name': name,
        'price_cents': ((double.tryParse(t.priceCtrl.text) ?? 0) * 100).toInt(),
        'display_order': i,
        if (t.descCtrl.text.trim().isNotEmpty) 'description': t.descCtrl.text.trim(),
        if (t.maxReservedSpots > 0) 'max_reserved_spots': t.maxReservedSpots,
      };
      await ticketRepo.createTicketTier(eventId, tierData);
    } catch (e) { debugPrint(e.toString()); }
  }
}

Future<void> _createMilestones(EventProvider eventRepo, TicketProvider ticketRepo, int eventId, List<MilestoneInput> milestones) async {
  for (final ms in milestones) {
    final title = ms.titleCtrl.text.trim();
    if (title.isEmpty) continue;
    try {
      await eventRepo.createMilestone(eventId, {
        'title': title,
        'unlock_percent': ms.unlockPercent,
        if (ms.benefitCtrl.text.trim().isNotEmpty) 'benefit_description': ms.benefitCtrl.text.trim(),
      });
    } catch (e) { debugPrint(e.toString()); }
    final discVal = int.tryParse(ms.discountValueCtrl.text.trim()) ?? 0;
    if (discVal > 0) {
      try {
        await ticketRepo.createEventDiscount(eventId, {
          'name': 'Milestone ${ms.unlockPercent}% discount',
          'discount_type': 'funding_milestone',
          'value': discVal,
          'target': 'pledgers',
          'milestone_percent': ms.unlockPercent,
          'milestone_discount_value': discVal,
        });
      } catch (e) { debugPrint(e.toString()); }
    }
  }
}

Future<void> _createEarlyBirdDiscounts(TicketProvider ticketRepo, int eventId, List<EarlyBirdInput> earlyBirdDiscounts) async {
  for (final eb in earlyBirdDiscounts) {
    final val = int.tryParse(eb.valueCtrl.text.trim()) ?? 0;
    if (val <= 0 || eb.windowEnd == null) continue;
    try {
      await ticketRepo.createEarlyBirdDiscount(eventId, {
        'applies_to': eb.appliesTo,
        'discount_type': eb.discountType,
        'value': val,
        if (eb.windowStart != null)
          'window_start': eb.windowStart!.toUtc().toIso8601String(),
        'window_end': eb.windowEnd!.toUtc().toIso8601String(),
      });
    } catch (e) { debugPrint(e.toString()); }
  }
}

Future<void> _createSchedule(EventProvider eventRepo, int eventId, List<ScheduleDayInput> scheduleDays) async {
  if (scheduleDays.isEmpty) return;
  final scheduleItems = <Map<String, dynamic>>[];
  final slotsWithImages = <int, ScheduleSlotInput>{};

  for (final day in scheduleDays) {
    if (day.date == null) continue;
    final dateStr =
        '${day.date!.year}-${day.date!.month.toString().padLeft(2, '0')}-${day.date!.day.toString().padLeft(2, '0')}';
    for (int i = 0; i < day.slots.length; i++) {
      final slot = day.slots[i];
      final title = slot.titleCtrl.text.trim();
      if (title.isEmpty) continue;
      final itemIdx = scheduleItems.length;
      scheduleItems.add({
        'date': dateStr,
        'start_time':
            '${slot.startTime.hour.toString().padLeft(2, '0')}:${slot.startTime.minute.toString().padLeft(2, '0')}',
        'end_time':
            '${slot.endTime.hour.toString().padLeft(2, '0')}:${slot.endTime.minute.toString().padLeft(2, '0')}',
        'title': title,
        if (slot.descCtrl.text.trim().isNotEmpty) 'description': slot.descCtrl.text.trim(),
        if (slot.pickedImageBytes == null && slot.imageUrlCtrl.text.trim().isNotEmpty)
          'image_url': slot.imageUrlCtrl.text.trim(),
        if (slot.imageCaptionCtrl.text.trim().isNotEmpty)
          'image_caption': slot.imageCaptionCtrl.text.trim(),
        if (slot.linkUrlCtrl.text.trim().isNotEmpty) 'link_url': slot.linkUrlCtrl.text.trim(),
        'sort_order': i,
      });
      if (slot.pickedImageBytes != null) slotsWithImages[itemIdx] = slot;
    }
  }

  if (scheduleItems.isEmpty) return;
  try {
    final created = await eventRepo.bulkCreateSchedule(eventId, scheduleItems);
    for (final entry in slotsWithImages.entries) {
      final idx = entry.key;
      final slot = entry.value;
      if (idx < created.length) {
        final itemId = created[idx].id;
        try {
          await eventRepo.uploadScheduleImage(
            eventId,
            itemId,
            slot.pickedImageBytes!,
            slot.pickedImageName ?? 'image.png',
            caption: slot.imageCaptionCtrl.text.trim().isNotEmpty
                ? slot.imageCaptionCtrl.text.trim()
                : null,
          );
        } catch (e) { debugPrint(e.toString()); }
      }
    }
  } catch (e) { debugPrint(e.toString()); }
}

Future<void> _createSponsorCategories(
    SponsorProvider sponsorRepo, int eventId, List<EditableSponsorCategory> localCategories) async {
  for (final cat in localCategories) {
    final name = cat.nameCtrl.text.trim();
    if (name.isEmpty) continue;
    try {
      final created = await sponsorRepo.createSponsorshipCategory(eventId, {
        'name': name,
        'description': cat.descCtrl.text.trim(),
        'total_spots': int.tryParse(cat.spotsCtrl.text) ?? 1,
        'min_bid_cents': ((double.tryParse(cat.minBidCtrl.text) ?? 0) * 100).round(),
      });
      final catId = created.id;
      for (final p in cat.prereqs) {
        try {
          await sponsorRepo.createPrerequisite(eventId, catId,
              name: p.name,
              description: p.description,
              isRequired: p.isRequired,
              requiresDocument: p.requiresDocument);
        } catch (e) { debugPrint(e.toString()); }
      }
    } catch (e) { debugPrint(e.toString()); }
  }
}

Future<void> _uploadImages(
    EventProvider eventRepo, int eventId, List<XFile> pickedImages, Map<int, Uint8List> imageBytes) async {
  for (int i = 0; i < pickedImages.length; i++) {
    try {
      final bytes = imageBytes[i] ?? await pickedImages[i].readAsBytes();
      await eventRepo.uploadEventImage(
        eventId,
        fileBytes: bytes,
        fileName: pickedImages[i].name,
        displayOrder: i,
      );
    } catch (e) { debugPrint(e.toString()); }
  }
}
