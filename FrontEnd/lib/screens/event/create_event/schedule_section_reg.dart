import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../config/theme.dart';
import '../../../models/event_form_models.dart';

class ScheduleSectionRegistration extends StatefulWidget {
  final bool hasSchedule;
  final ValueChanged<bool> onHasScheduleChanged;
  final List<ScheduleDayInput> scheduleDays;
  final DateTime startTime;
  final DateTime endTime;

  const ScheduleSectionRegistration({
    super.key,
    required this.hasSchedule,
    required this.onHasScheduleChanged,
    required this.scheduleDays,
    required this.startTime,
    required this.endTime,
  });

  @override
  State<ScheduleSectionRegistration> createState() =>
      _ScheduleSectionRegistrationState();
}

class _ScheduleSectionRegistrationState
    extends State<ScheduleSectionRegistration> {
  final _imagePicker = ImagePicker();
  bool _showScheduleSection = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(
              () => _showScheduleSection = !_showScheduleSection),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _showScheduleSection
                  ? context.feedAccent.withValues(alpha: 0.08)
                  : AppTheme.cardOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showScheduleSection
                    ? context.feedAccent.withValues(alpha: 0.3)
                    : AppTheme.dividerOf(context),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded,
                    size: 18,
                    color: _showScheduleSection
                        ? context.feedAccent
                        : AppTheme.textSecondaryOf(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Event Schedule (Optional)',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color:
                              AppTheme.textPrimaryOf(context))),
                ),
                if (widget.scheduleDays.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.feedAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                        '${widget.scheduleDays.fold<int>(0, (sum, d) => sum + d.slots.length)}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.feedAccent)),
                  ),
                const SizedBox(width: 4),
                Icon(
                  _showScheduleSection
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.dividerOf(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Use structured schedule',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryOf(
                                  context))),
                    ),
                    Switch(
                      value: widget.hasSchedule,
                      onChanged: (v) {
                        widget.onHasScheduleChanged(v);
                      },
                    ),
                  ],
                ),
                if (widget.hasSchedule) ...[
                  const SizedBox(height: 8),
                  Text('Add time slots for each day of your event.',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryOf(
                              context))),
                  const SizedBox(height: 12),
                  ...widget.scheduleDays
                      .asMap()
                      .entries
                      .map((dayEntry) {
                    final dayIdx = dayEntry.key;
                    final day = dayEntry.value;
                    final dateLabel = day.date != null
                        ? '${day.date!.month}/${day.date!.day}/${day.date!.year}'
                        : 'Select date';
                    return _buildScheduleDay(dayIdx, day, dateLabel);
                  }),
                  GestureDetector(
                    onTap: () => setState(() =>
                        widget.scheduleDays
                            .add(ScheduleDayInput())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                AppTheme.dividerOf(context)),
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded,
                              size: 18,
                              color:
                                  AppTheme.textSecondaryOf(
                                      context)),
                          const SizedBox(width: 6),
                          Text('Add Date',
                              style: TextStyle(
                                  fontWeight:
                                      FontWeight.w600,
                                  fontSize: 13,
                                  color: AppTheme
                                      .textSecondaryOf(
                                          context))),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          crossFadeState: _showScheduleSection
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  Widget _buildScheduleDay(int dayIdx, ScheduleDayInput day, String dateLabel) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: context.feedAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: day.date ?? widget.startTime,
                    firstDate: widget.startTime,
                    lastDate: widget.endTime,
                  );
                  if (picked != null) {
                    setState(() => day.date = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.feedAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 14, color: context.feedAccent),
                      const SizedBox(width: 6),
                      Text(dateLabel,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.feedAccent)),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 18, color: AppTheme.errorColor),
                onPressed: () => setState(
                    () => widget.scheduleDays.removeAt(dayIdx)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...day.slots.asMap().entries.map((slotEntry) {
            final slotIdx = slotEntry.key;
            final slot = slotEntry.value;
            return _buildScheduleSlot(day, slotIdx, slot);
          }),
          GestureDetector(
            onTap: () => setState(
                () => day.slots.add(ScheduleSlotInput())),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppTheme.dividerOf(context)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded,
                      size: 16,
                      color: AppTheme.textSecondaryOf(context)),
                  const SizedBox(width: 4),
                  Text('Add Time Slot',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppTheme.textSecondaryOf(context))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSlot(
      ScheduleDayInput day, int slotIdx, ScheduleSlotInput slot) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Slot ${slotIdx + 1}',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context))),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 16, color: AppTheme.errorColor),
                onPressed: () =>
                    setState(() => day.slots.removeAt(slotIdx)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final t = await showTimePicker(
                        context: context,
                        initialTime: slot.startTime);
                    if (t != null) {
                      setState(() => slot.startTime = t);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppTheme.dividerOf(context)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(slot.startTime.format(context),
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textPrimaryOf(context))),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('–',
                    style: TextStyle(
                        color: AppTheme.textSecondaryOf(context))),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final t = await showTimePicker(
                        context: context,
                        initialTime: slot.endTime);
                    if (t != null) {
                      setState(() => slot.endTime = t);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppTheme.dividerOf(context)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(slot.endTime.format(context),
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textPrimaryOf(context))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: slot.titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'e.g. Opening Keynote',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: slot.descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              isDense: true,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          _buildSlotImageSection(slot),
          const SizedBox(height: 8),
          TextFormField(
            controller: slot.linkUrlCtrl,
            decoration: InputDecoration(
              labelText: 'Link URL (optional)',
              hintText: 'https://speaker-website.com',
              isDense: true,
              prefixIcon: Icon(Icons.link_rounded,
                  size: 18,
                  color: AppTheme.textSecondaryOf(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotImageSection(ScheduleSlotInput slot) {
    final hasPickedImage = slot.pickedImageBytes != null;
    final hasUrl = slot.imageUrlCtrl.text.trim().isNotEmpty;
    final hasImage = hasPickedImage || hasUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasPickedImage) ...[
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  slot.pickedImageBytes!,
                  width: double.infinity,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => setState(() {
                    slot.pickedImageBytes = null;
                    slot.pickedImageName = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.close,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            slot.pickedImageName ?? 'Uploaded image',
            style: TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondaryOf(context)),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: slot.imageUrlCtrl,
                decoration: InputDecoration(
                  labelText: hasPickedImage
                      ? 'Image URL (overridden by upload)'
                      : 'Image URL (optional)',
                  hintText: 'https://example.com/logo.png',
                  isDense: true,
                  enabled: !hasPickedImage,
                  prefixIcon: Icon(Icons.image_rounded,
                      size: 18,
                      color: AppTheme.textSecondaryOf(context)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: OutlinedButton.icon(
                onPressed: () => _pickSlotImage(slot),
                icon: Icon(
                  hasPickedImage
                      ? Icons.swap_horiz_rounded
                      : Icons.upload_rounded,
                  size: 16,
                ),
                label: Text(hasPickedImage ? 'Change' : 'Upload',
                    style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10),
                  side: BorderSide(
                      color: AppTheme.dividerOf(context)),
                ),
              ),
            ),
          ],
        ),
        if (hasImage) ...[
          const SizedBox(height: 6),
          TextFormField(
            controller: slot.imageCaptionCtrl,
            decoration: const InputDecoration(
              labelText: 'Image caption / alt text',
              isDense: true,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickSlotImage(ScheduleSlotInput slot) async {
    try {
      final xFile =
          await _imagePicker.pickImage(source: ImageSource.gallery);
      if (xFile == null) return;
      final bytes = await xFile.readAsBytes();
      setState(() {
        slot.pickedImageBytes = bytes;
        slot.pickedImageName = xFile.name;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: $e')),
        );
      }
    }
  }
}
