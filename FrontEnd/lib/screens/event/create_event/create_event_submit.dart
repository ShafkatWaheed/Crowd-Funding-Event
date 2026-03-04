import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/discount.dart';
import '../../../models/event.dart';
import '../../../models/event_form_models.dart';
import '../../../models/milestone.dart';
import '../../../models/schedule.dart';
import '../../../models/sponsor.dart';
import '../../../models/ticket.dart';
import '../../../models/venue.dart';
import '../../../providers/event_provider.dart';
import '../../../providers/ticket_provider.dart';
import '../../../providers/sponsor_provider.dart';

EventCreateRequest buildCreateEventPayload({
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
  final selectedVenue = venues.where((v) => v.id == selectedVenueId).firstOrNull;

  return EventCreateRequest(
    venueId: selectedVenueId,
    title: title.trim(),
    description: description.trim(),
    maxCapacity: maxCapacity,
    registrationType: registrationType,
    minPledgeCents: (minPledge * 100).toInt(),
    maxReservedSpotsPerUser: maxReservedSpotsPerUser,
    genre: genre,
    communityRules: communityRules,
    postsEnabled: postsEnabled,
    publish: publish,
    startTime: startTime?.toUtc().toIso8601String(),
    endTime: endTime?.toUtc().toIso8601String(),
    fundingEndAt: fundingEndAt?.toUtc().toIso8601String(),
    refundDeadlineDays: fundingEndAt != null && refundDeadlineDays > 0 ? refundDeadlineDays : null,
    fundingGoalCents: fundingGoal != null && fundingGoal > 0 ? (fundingGoal * 100).toInt() : null,
    ticketStrategyId: selectedStrategyId,
    lat: selectedVenue?.lat,
    lng: selectedVenue?.lng,
    parkingInfo: parkingInfo.isNotEmpty ? parkingInfo : null,
    transitInfo: transitInfo.isNotEmpty ? transitInfo : null,
    rideshareInfo: rideshareInfo.isNotEmpty ? rideshareInfo : null,
    accessibilityInfo: accessibilityInfo.isNotEmpty ? accessibilityInfo : null,
    hasSchedule: hasSchedule,
    linkFundingToTiers: linkFundingToTiers,
    maxDiscountPercent: maxDiscountPercent,
    ageRestricted: ageRestricted,
    minAge: minAge,
    waitlistMaxSize: waitlistMaxSize,
    waitlistAutoApprove: waitlistAutoApprove,
    eventMaxImages: eventMaxImages,
    maxPostsPerDay: maxPostsPerDay,
    maxCoOrganizers: maxCoOrganizers,
  );
}

Future<int> executeCreateEventSubmission({
  required SponsorProvider sponsorRepo,
  required EventProvider eventRepo,
  required TicketProvider ticketRepo,
  required EventCreateRequest eventData,
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
      await ticketRepo.createTicketTier(eventId, CreateTicketTierRequest(
        name: name,
        priceCents: ((double.tryParse(t.priceCtrl.text) ?? 0) * 100).toInt(),
        displayOrder: i,
        description: t.descCtrl.text.trim().isNotEmpty ? t.descCtrl.text.trim() : null,
        maxReservedSpots: t.maxReservedSpots > 0 ? t.maxReservedSpots : null,
      ));
    } catch (e) { debugPrint(e.toString()); }
  }
}

Future<void> _createMilestones(EventProvider eventRepo, TicketProvider ticketRepo, int eventId, List<MilestoneInput> milestones) async {
  for (final ms in milestones) {
    final title = ms.titleCtrl.text.trim();
    if (title.isEmpty) continue;
    try {
      await eventRepo.createMilestone(eventId, MilestoneRequest(
        title: title,
        unlockPercent: ms.unlockPercent,
        benefitDescription: ms.benefitCtrl.text.trim().isNotEmpty ? ms.benefitCtrl.text.trim() : null,
      ));
    } catch (e) { debugPrint(e.toString()); }
    final discVal = int.tryParse(ms.discountValueCtrl.text.trim()) ?? 0;
    if (discVal > 0) {
      try {
        await ticketRepo.createEventDiscount(eventId, CreateEventDiscountRequest(
          name: 'Milestone ${ms.unlockPercent}% discount',
          discountType: 'funding_milestone',
          value: discVal,
          target: 'pledgers',
          milestonePercent: ms.unlockPercent,
          milestoneDiscountValue: discVal,
        ));
      } catch (e) { debugPrint(e.toString()); }
    }
  }
}

Future<void> _createEarlyBirdDiscounts(TicketProvider ticketRepo, int eventId, List<EarlyBirdInput> earlyBirdDiscounts) async {
  for (final eb in earlyBirdDiscounts) {
    final val = int.tryParse(eb.valueCtrl.text.trim()) ?? 0;
    if (val <= 0 || eb.windowEnd == null) continue;
    try {
      await ticketRepo.createEarlyBirdDiscount(eventId, CreateEarlyBirdDiscountRequest(
        appliesTo: eb.appliesTo,
        discountType: eb.discountType,
        value: val,
        windowStart: eb.windowStart?.toUtc().toIso8601String(),
        windowEnd: eb.windowEnd!.toUtc().toIso8601String(),
      ));
    } catch (e) { debugPrint(e.toString()); }
  }
}

Future<void> _createSchedule(EventProvider eventRepo, int eventId, List<ScheduleDayInput> scheduleDays) async {
  if (scheduleDays.isEmpty) return;
  final scheduleItems = <CreateScheduleItemRequest>[];
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
      scheduleItems.add(CreateScheduleItemRequest(
        date: dateStr,
        startTime:
            '${slot.startTime.hour.toString().padLeft(2, '0')}:${slot.startTime.minute.toString().padLeft(2, '0')}',
        endTime:
            '${slot.endTime.hour.toString().padLeft(2, '0')}:${slot.endTime.minute.toString().padLeft(2, '0')}',
        title: title,
        description: slot.descCtrl.text.trim().isNotEmpty ? slot.descCtrl.text.trim() : null,
        imageUrl: slot.pickedImageBytes == null && slot.imageUrlCtrl.text.trim().isNotEmpty
            ? slot.imageUrlCtrl.text.trim()
            : null,
        imageCaption: slot.imageCaptionCtrl.text.trim().isNotEmpty
            ? slot.imageCaptionCtrl.text.trim()
            : null,
        linkUrl: slot.linkUrlCtrl.text.trim().isNotEmpty ? slot.linkUrlCtrl.text.trim() : null,
        sortOrder: i,
      ));
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
      final created = await sponsorRepo.createSponsorshipCategory(eventId,
          CreateSponsorshipCategoryRequest(
        name: name,
        description: cat.descCtrl.text.trim().isEmpty
            ? null
            : cat.descCtrl.text.trim(),
        totalSpots: int.tryParse(cat.spotsCtrl.text) ?? 1,
        minBidCents: ((double.tryParse(cat.minBidCtrl.text) ?? 0) * 100).round(),
      ));
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
