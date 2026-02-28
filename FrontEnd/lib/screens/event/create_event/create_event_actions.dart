import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../models/event_form_models.dart';
import '../../../services/api_service.dart';
import '../../../services/mapbox_geocoding_service.dart';
import '../../../widgets/app_toast.dart';

Future<DateTime?> pickDateTimeGeneric(BuildContext context, {DateTime? initial}) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial ?? DateTime.now().add(const Duration(days: 7)),
    firstDate: DateTime.now(),
    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: initial != null
        ? TimeOfDay.fromDateTime(initial)
        : const TimeOfDay(hour: 18, minute: 0),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

Future<void> pickEventDateTime(
  BuildContext context, {
  required bool isStart,
  required DateTime? currentStartTime,
  required DateTime? currentEndTime,
  required DateTime? fundingEndAt,
  required void Function(DateTime dt, bool isStartPicked) onPicked,
}) async {
  final dt = await pickDateTimeGeneric(context, initial: isStart ? currentStartTime : currentEndTime);
  if (dt == null) return;
  onPicked(dt, isStart);

  if (isStart) {
    if (currentEndTime != null && !currentEndTime.isAfter(dt)) {
      if (context.mounted) AppToast.error(context, 'End time must be after start time');
    }
  } else {
    if (currentStartTime != null && !dt.isAfter(currentStartTime)) {
      if (context.mounted) AppToast.error(context, 'End time must be after start time');
    }
  }
  if (fundingEndAt != null && (isStart ? dt : currentStartTime) != null) {
    final start = isStart ? dt : currentStartTime!;
    if (!start.isAfter(fundingEndAt)) {
      if (context.mounted) AppToast.error(context, 'Start time should be after funding deadline');
    }
  }
}

Future<DateTime?> pickFundingDeadline(
  BuildContext context, {
  required DateTime? current,
  required DateTime? startTime,
}) async {
  final dt = await pickDateTimeGeneric(context, initial: current);
  if (dt == null) return null;
  if (startTime != null && !startTime.isAfter(dt) && context.mounted) {
    AppToast.error(context, 'Event start should be after funding deadline');
  }
  return dt;
}

Future<int?> createVenueInline(
  BuildContext context, {
  required TextEditingController nameCtrl,
  required TextEditingController addressCtrl,
  required TextEditingController cityCtrl,
  required TextEditingController provinceCtrl,
  required TextEditingController capacityCtrl,
  required double? lat,
  required double? lng,
}) async {
  if (nameCtrl.text.trim().isEmpty || addressCtrl.text.trim().isEmpty ||
      cityCtrl.text.trim().isEmpty || capacityCtrl.text.trim().isEmpty) {
    AppToast.error(context, 'Please fill in all venue fields');
    return null;
  }
  try {
    final api = context.read<ApiService>();
    final resp = await api.createVenue({
      'name': nameCtrl.text.trim(),
      'address': addressCtrl.text.trim(),
      'city': cityCtrl.text.trim(),
      'province': provinceCtrl.text.trim(),
      'max_capacity': int.parse(capacityCtrl.text.trim()),
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    });
    if (context.mounted) AppToast.success(context, 'Venue created and selected!');
    return resp['id'] as int?;
  } catch (e) {
    if (context.mounted) AppToast.fromError(context, e, fallback: 'Failed to create venue');
    return null;
  }
}

Future<int?> createStrategyInline(
  BuildContext context, {
  required TextEditingController nameCtrl,
  required List<StrategyTierInput> tiers,
}) async {
  if (nameCtrl.text.trim().isEmpty) {
    AppToast.error(context, 'Please enter a strategy name');
    return null;
  }
  for (final t in tiers) {
    if (t.nameCtrl.text.trim().isEmpty || t.priceCtrl.text.trim().isEmpty) {
      AppToast.error(context, 'All tier fields must be filled');
      return null;
    }
  }
  try {
    final api = context.read<ApiService>();
    final tiersData = tiers.asMap().entries.map((e) {
      final data = <String, dynamic>{
        'name': e.value.nameCtrl.text.trim(),
        'price_cents': ((double.tryParse(e.value.priceCtrl.text) ?? 0) * 100).toInt(),
        'display_order': e.key,
      };
      if (e.value.descCtrl.text.trim().isNotEmpty) data['description'] = e.value.descCtrl.text.trim();
      return data;
    }).toList();
    final resp = await api.createTicketStrategy({'name': nameCtrl.text.trim(), 'tiers': tiersData});
    if (context.mounted) AppToast.success(context, 'Ticket strategy created and selected!');
    return resp['id'] as int?;
  } catch (e) {
    if (context.mounted) AppToast.fromError(context, e, fallback: 'Failed to create ticket strategy');
    return null;
  }
}

Future<List<XFile>> pickEventImages(ImagePicker picker, {bool singleMode = false}) async {
  if (singleMode) {
    final single = await picker.pickImage(source: ImageSource.gallery);
    return single != null ? [single] : [];
  }
  return await picker.pickMultiImage();
}

void removeEventImage(int index, List<XFile> images, Map<int, Uint8List> bytes) {
  images.removeAt(index);
  final newBytes = <int, Uint8List>{};
  for (int i = 0; i < images.length; i++) {
    final oldIdx = i >= index ? i + 1 : i;
    if (bytes.containsKey(oldIdx)) newBytes[i] = bytes[oldIdx]!;
  }
  bytes..clear()..addAll(newBytes);
}

void onVenueAddressChanged(
  String query, {
  required Timer? Function() getDebounce,
  required void Function(Timer?) setDebounce,
  required void Function({
    List<GeocodingResult>? suggestions,
    bool? showSuggestions,
    bool? geocoding,
  }) updateState,
}) {
  getDebounce()?.cancel();
  if (query.trim().length < 3) {
    updateState(suggestions: [], showSuggestions: false);
    return;
  }
  setDebounce(Timer(const Duration(milliseconds: 400), () async {
    updateState(geocoding: true);
    final results = await MapboxGeocodingService.search(query);
    updateState(
      suggestions: results,
      showSuggestions: results.isNotEmpty,
      geocoding: false,
    );
  }));
}

void selectVenueGeoSuggestion(
  GeocodingResult result, {
  required TextEditingController addressCtrl,
  required TextEditingController cityCtrl,
  required TextEditingController provinceCtrl,
  required void Function(double lat, double lng) onLatLng,
  required VoidCallback onClear,
}) {
  addressCtrl.text = result.fullAddress;
  if (result.city != null && result.city!.isNotEmpty) cityCtrl.text = result.city!;
  if (result.province != null && result.province!.isNotEmpty) provinceCtrl.text = result.province!;
  onLatLng(result.lat, result.lng);
  onClear();
}

Future<void> toggleSponsorTemplate(
  BuildContext context,
  Map<String, dynamic> t, {
  required List<EditableSponsorCategory> localCategories,
  required VoidCallback onChanged,
}) async {
  final id = t['id'] as int;
  final idx = localCategories.indexWhere((c) => c.templateId == id);
  if (idx >= 0) {
    localCategories.removeAt(idx);
    onChanged();
    return;
  }
  final cat = EditableSponsorCategory(templateId: id, expanded: true);
  cat.nameCtrl.text = t['name'] ?? '';
  cat.descCtrl.text = (t['description'] as String?) ?? '';
  cat.spotsCtrl.text = '${t['total_spots'] ?? 1}';
  final minBid = t['min_bid_cents'] ?? 0;
  cat.minBidCtrl.text = (minBid / 100).toStringAsFixed(2);
  try {
    final prereqs = await context.read<ApiService>().listTemplatePrerequisites(id);
    for (final p in prereqs) {
      cat.prereqs.add(LocalPrerequisite(
        name: (p['name'] as String?) ?? '',
        description: (p['description'] as String?) ?? '',
        isRequired: p['is_required'] as bool? ?? true,
        requiresDocument: p['requires_document'] as bool? ?? false,
      ));
    }
  } catch (e) { debugPrint(e.toString()); }
  if (!context.mounted) return;
  localCategories.add(cat);
  onChanged();
}

Future<bool> confirmDiscardDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Discard changes?'),
      content: const Text('You have unsaved changes. Are you sure you want to leave?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Editing')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Discard'),
        ),
      ],
    ),
  );
  return result ?? false;
}
