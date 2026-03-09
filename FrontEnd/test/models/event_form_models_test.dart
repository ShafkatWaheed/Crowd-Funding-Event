import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crowd_funding_app/models/event_form_models.dart';

void main() {
  group('StrategyTierInput', () {
    test('creates controllers on instantiation', () {
      final input = StrategyTierInput();
      expect(input.nameCtrl, isA<TextEditingController>());
      expect(input.descCtrl, isA<TextEditingController>());
      expect(input.priceCtrl, isA<TextEditingController>());
      expect(input.nameCtrl.text, isEmpty);
    });
  });

  group('EditableTier', () {
    test('creates controllers and defaults maxReservedSpots to 0', () {
      final tier = EditableTier();
      expect(tier.nameCtrl, isA<TextEditingController>());
      expect(tier.priceCtrl, isA<TextEditingController>());
      expect(tier.descCtrl, isA<TextEditingController>());
      expect(tier.maxReservedSpots, 0);
    });

    test('maxReservedSpots is mutable', () {
      final tier = EditableTier();
      tier.maxReservedSpots = 5;
      expect(tier.maxReservedSpots, 5);
    });
  });

  group('LocalPrerequisite', () {
    test('required constructor parameter and defaults', () {
      final prereq = LocalPrerequisite(name: 'Insurance');
      expect(prereq.name, 'Insurance');
      expect(prereq.description, '');
      expect(prereq.isRequired, true);
      expect(prereq.requiresDocument, false);
    });

    test('custom values', () {
      final prereq = LocalPrerequisite(
        name: 'License',
        description: 'Must have a valid license',
        isRequired: false,
        requiresDocument: true,
      );
      expect(prereq.name, 'License');
      expect(prereq.description, 'Must have a valid license');
      expect(prereq.isRequired, false);
      expect(prereq.requiresDocument, true);
    });
  });

  group('EditableSponsorCategory', () {
    test('defaults', () {
      final cat = EditableSponsorCategory();
      expect(cat.templateId, isNull);
      expect(cat.nameCtrl, isA<TextEditingController>());
      expect(cat.descCtrl, isA<TextEditingController>());
      expect(cat.spotsCtrl, isA<TextEditingController>());
      expect(cat.minBidCtrl, isA<TextEditingController>());
      expect(cat.expanded, false);
      expect(cat.prereqs, isEmpty);
    });

    test('custom templateId and expanded', () {
      final cat = EditableSponsorCategory(templateId: 42, expanded: true);
      expect(cat.templateId, 42);
      expect(cat.expanded, true);
    });
  });

  group('MilestoneInput', () {
    test('defaults and controllers', () {
      final m = MilestoneInput();
      expect(m.titleCtrl, isA<TextEditingController>());
      expect(m.benefitCtrl, isA<TextEditingController>());
      expect(m.discountValueCtrl, isA<TextEditingController>());
      expect(m.unlockPercent, 50);
    });
  });

  group('EarlyBirdInput', () {
    test('defaults', () {
      final eb = EarlyBirdInput();
      expect(eb.appliesTo, 'funding');
      expect(eb.discountType, 'percent');
      expect(eb.valueCtrl, isA<TextEditingController>());
      expect(eb.windowStart, isNull);
      expect(eb.windowEnd, isNull);
    });
  });

  group('ScheduleDayInput', () {
    test('defaults', () {
      final day = ScheduleDayInput();
      expect(day.date, isNull);
      expect(day.slots, isEmpty);
    });
  });

  group('ScheduleSlotInput', () {
    test('default time values and controllers', () {
      final slot = ScheduleSlotInput();
      expect(slot.startTime, const TimeOfDay(hour: 9, minute: 0));
      expect(slot.endTime, const TimeOfDay(hour: 10, minute: 0));
      expect(slot.titleCtrl, isA<TextEditingController>());
      expect(slot.descCtrl, isA<TextEditingController>());
      expect(slot.imageUrlCtrl, isA<TextEditingController>());
      expect(slot.imageCaptionCtrl, isA<TextEditingController>());
      expect(slot.linkUrlCtrl, isA<TextEditingController>());
      expect(slot.pickedImageBytes, isNull);
      expect(slot.pickedImageName, isNull);
    });
  });
}
