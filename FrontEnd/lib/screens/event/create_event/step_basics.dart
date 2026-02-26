import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../config/theme.dart';

class StepBasics extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final String? genre;
  final List<String> genres;
  final ValueChanged<String?> onGenreChanged;
  final int imageCount;
  final Map<int, Uint8List> imageBytes;
  final VoidCallback onPickImages;
  final VoidCallback onPickSingleImage;
  final ValueChanged<int> onRemoveImage;
  final VoidCallback onMarkDirty;
  final bool ageRestricted;
  final int minAge;
  final ValueChanged<bool> onAgeRestrictedChanged;
  final ValueChanged<int> onMinAgeChanged;

  const StepBasics({
    super.key,
    required this.formKey,
    required this.titleCtrl,
    required this.descCtrl,
    required this.genre,
    required this.genres,
    required this.onGenreChanged,
    required this.imageCount,
    required this.imageBytes,
    required this.onPickImages,
    required this.onPickSingleImage,
    required this.onRemoveImage,
    required this.onMarkDirty,
    this.ageRestricted = false,
    this.minAge = 18,
    required this.onAgeRestrictedChanged,
    required this.onMinAgeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.accentColor.withValues(alpha: 0.08),
                        AppTheme.accentColor.withValues(alpha: 0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.accentColor.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.celebration_rounded,
                            size: 24, color: AppTheme.accentColor),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tell us about your event',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimaryOf(context),
                                    letterSpacing: -0.3)),
                            const SizedBox(height: 2),
                            Text(
                                'Start with the basics — you can always edit later.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        AppTheme.textSecondaryOf(context))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Event Title *',
                    prefixIcon: Icon(Icons.title_rounded, size: 20),
                    hintText: 'Give your event a catchy name',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                  onChanged: (_) => onMarkDirty(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 40),
                      child: Icon(Icons.notes_rounded, size: 20),
                    ),
                    hintText: 'What makes your event special?',
                    counterText: '${descCtrl.text.length} / 2000',
                    counterStyle: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondaryOf(context)),
                  ),
                  maxLines: 3,
                  maxLength: 2000,
                  buildCounter: (context,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      null,
                  onChanged: (_) => onMarkDirty(),
                ),
                const SizedBox(height: 20),
                _buildImageSection(context),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: genre,
                  decoration: const InputDecoration(
                    labelText: 'Genre / Category *',
                    prefixIcon: Icon(Icons.category_rounded, size: 20),
                  ),
                  items: genres
                      .map((g) => DropdownMenuItem(
                          value: g,
                          child:
                              Text(g[0].toUpperCase() + g.substring(1))))
                      .toList(),
                  onChanged: onGenreChanged,
                  validator: (v) =>
                      v == null ? 'Please select a genre' : null,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.cardOf(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.dividerOf(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shield_outlined,
                              size: 20, color: ageRestricted ? AppTheme.errorColor : AppTheme.textSecondaryOf(context)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('Age Restriction',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimaryOf(context))),
                          ),
                          Switch.adaptive(
                            value: ageRestricted,
                            onChanged: (v) {
                              onAgeRestrictedChanged(v);
                              onMarkDirty();
                            },
                            activeColor: AppTheme.errorColor,
                          ),
                        ],
                      ),
                      if (ageRestricted) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text('Minimum age: ',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textSecondaryOf(context))),
                            SizedBox(
                              width: 70,
                              child: TextFormField(
                                initialValue: minAge.toString(),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: AppTheme.textPrimaryOf(context)),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: AppTheme.dividerOf(context)),
                                  ),
                                ),
                                onChanged: (v) {
                                  final age = int.tryParse(v);
                                  if (age != null && age >= 13 && age <= 99) {
                                    onMinAgeChanged(age);
                                    onMarkDirty();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.errorColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('$minAge+',
                                  style: TextStyle(
                                      color: AppTheme.errorColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.photo_library_rounded,
                    size: 18, color: AppTheme.accentColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Event Images',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textPrimaryOf(context))),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: imageCount > 0
                      ? AppTheme.accentColor.withValues(alpha: 0.1)
                      : AppTheme.surfaceOf(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$imageCount selected',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: imageCount > 0
                            ? AppTheme.accentColor
                            : AppTheme.textSecondaryOf(context))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (imageCount > 0) ...[
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: imageCount,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final bytes = imageBytes[i];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: bytes != null
                            ? Image.memory(bytes,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover)
                            : Container(
                                width: 120,
                                height: 120,
                                color: AppTheme.dividerOf(context),
                                child:
                                    const Icon(Icons.image, size: 32)),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => onRemoveImage(i),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color:
                                  Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                      if (i == 0)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOf(context),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Cover',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickImages,
                  icon:
                      const Icon(Icons.photo_library_rounded, size: 18),
                  label: const Text('Select Multiple'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryOf(context),
                    side: BorderSide(
                        color: AppTheme.primaryOf(context)
                            .withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickSingleImage,
                  icon: const Icon(Icons.add_photo_alternate_rounded,
                      size: 18),
                  label: const Text('Pick One'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondaryOf(context),
                    side: BorderSide(
                        color: AppTheme.dividerOf(context)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          if (imageCount == 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Add photos to make your event stand out. The first image will be the cover.',
                style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondaryOf(context)),
              ),
            ),
        ],
      ),
    );
  }
}
