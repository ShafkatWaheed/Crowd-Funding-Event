import 'package:flutter/material.dart';

class StrategyTierInput {
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
}

class EditableTier {
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  int maxReservedSpots = 0;
}

class LocalPrerequisite {
  String name;
  String description;
  bool isRequired;
  bool requiresDocument;
  LocalPrerequisite({required this.name, this.description = '', this.isRequired = true, this.requiresDocument = false});
}

class EditableSponsorCategory {
  final int? templateId;
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final spotsCtrl = TextEditingController();
  final minBidCtrl = TextEditingController();
  bool expanded;
  List<LocalPrerequisite> prereqs;
  EditableSponsorCategory({this.templateId, this.expanded = false})
      : prereqs = [];
}

class MilestoneInput {
  final titleCtrl = TextEditingController();
  final benefitCtrl = TextEditingController();
  final discountValueCtrl = TextEditingController();
  int unlockPercent = 50;
}

class EarlyBirdInput {
  String appliesTo = 'funding'; // 'funding' | 'tickets'
  String discountType = 'percent'; // 'percent' | 'fixed_cents'
  final valueCtrl = TextEditingController();
  DateTime? windowEnd;
}

class ScheduleDayInput {
  DateTime? date;
  final List<ScheduleSlotInput> slots = [];
}

class ScheduleSlotInput {
  TimeOfDay startTime;
  TimeOfDay endTime;
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final imageUrlCtrl = TextEditingController();
  final imageCaptionCtrl = TextEditingController();
  final linkUrlCtrl = TextEditingController();
  ScheduleSlotInput()
      : startTime = const TimeOfDay(hour: 9, minute: 0),
        endTime = const TimeOfDay(hour: 10, minute: 0);
}
