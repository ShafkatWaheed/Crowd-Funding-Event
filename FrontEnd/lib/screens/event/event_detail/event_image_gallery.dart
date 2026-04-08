import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../config/api_config.dart';
import '../../../config/theme.dart';
import '../../../config/design_tokens.dart';
import '../../../models/event_image.dart';
import '../../../providers/event_provider.dart';
import '../../../widgets/app_toast.dart';
import '../../../widgets/fullscreen_image_viewer.dart';
import '../../../widgets/shimmer_loaders.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'event_detail_helpers.dart';
import '../create_event/create_event_actions.dart' show confirmDelete;

class EventImageGallery extends StatefulWidget {
  final int eventId;
  final bool isPreview;
  final List<Uint8List>? previewImages;
  final bool canManage;
  final List<EventImage> images;
  final VoidCallback onImagesChanged;

  const EventImageGallery({
    super.key,
    required this.eventId,
    this.isPreview = false,
    this.previewImages,
    this.canManage = false,
    required this.images,
    required this.onImagesChanged,
  });

  @override
  State<EventImageGallery> createState() => _EventImageGalleryState();
}

class _EventImageGalleryState extends State<EventImageGallery> {
  bool _uploading = false;

  void _openImageViewer(int index) {
    final urls =
        widget.images.map((i) => ApiConfig.imageUrl(i.imageUrl)).toList();
    final captions = widget.images.map((i) => i.caption).toList();
    FullscreenImageViewer.open(
      context,
      imageUrls: urls,
      captions: captions,
      initialIndex: index,
    );
  }

  Future<void> _pickAndUploadImages() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage();
      if (picked.isEmpty) return;
      if (!mounted) return;

      setState(() => _uploading = true);
      final repo = context.read<EventProvider>();
      int order = widget.images.length;

      for (final xFile in picked) {
        final Uint8List bytes = await xFile.readAsBytes();
        await repo.uploadEventImage(
          widget.eventId,
          fileBytes: bytes,
          fileName: xFile.name,
          displayOrder: order++,
        );
      }

      widget.onImagesChanged();
      if (mounted) {
        AppToast.success(context,
            '${picked.length} photo${picked.length == 1 ? '' : 's'} added');
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Image upload failed');
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPreviewImages = widget.isPreview &&
        widget.previewImages != null &&
        widget.previewImages!.isNotEmpty;

    if (hasPreviewImages && widget.previewImages!.length > 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EventDetailHelpers.sectionTitle(context, 'Photos',
              icon: Icons.photo_library_rounded,
              iconColor: context.photoAccent),
          AppSpacing.vSm,
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.previewImages!.length,
              separatorBuilder: (_, __) => AppSpacing.hSm,
              itemBuilder: (ctx, i) {
                return ClipRRect(
                  borderRadius: AppRadius.md,
                  child: Image.memory(
                    widget.previewImages![i],
                    height: 180,
                    width: 260,
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
          ),
          AppSpacing.vXxl,
        ],
      );
    }

    if (!widget.isPreview && widget.images.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EventDetailHelpers.sectionTitle(context, 'Photos',
              icon: Icons.photo_library_rounded,
              iconColor: context.photoAccent),
          AppSpacing.vSm,
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.images.length,
              separatorBuilder: (_, __) => AppSpacing.hSm,
              itemBuilder: (ctx, i) {
                final img = widget.images[i];
                return GestureDetector(
                  onTap: () => _openImageViewer(i),
                  child: ClipRRect(
                    borderRadius: AppRadius.md,
                    child: Stack(
                      children: [
                        Hero(
                          tag: 'event-image-$i',
                          child: CachedNetworkImage(
                            imageUrl: ApiConfig.imageUrl(img.imageUrl),
                            height: 180,
                            width: 260,
                            memCacheHeight: 360,
                            memCacheWidth: 520,
                            fit: BoxFit.cover,
                            imageBuilder: (context, imageProvider) =>
                                Container(
                              height: 180,
                              width: 260,
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: imageProvider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                                    .animate()
                                    .fadeIn(
                                        duration: AppDuration.normal,
                                        curve: AppCurve.enter)
                                    .scale(
                                      begin: const Offset(0.95, 0.95),
                                      end: const Offset(1.0, 1.0),
                                      duration: AppDuration.slow,
                                      curve: AppCurve.enter,
                                    ),
                            progressIndicatorBuilder:
                                (context, url, progress) {
                              return const ShimmerImagePlaceholder(
                                  height: 180, width: 260);
                            },
                            errorWidget: (_, __, ___) => Container(
                              height: 180,
                              width: 260,
                              color: AppTheme.cardOf(context),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image_rounded,
                                      size: 32,
                                      color:
                                          AppTheme.textSecondaryOf(context)),
                                  AppSpacing.vXs,
                                  Text('Failed to load',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondaryOf(
                                              context))),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (img.caption != null && img.caption!.isNotEmpty)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              color: Colors.black.withValues(alpha: 0.54),
                              child: Text(
                                img.caption!,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        if (widget.canManage)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () async {
                                if (!await confirmDelete(context, 'image')) return;
                                if (!context.mounted) return;
                                final repo = context.read<EventProvider>();
                                await repo.deleteEventImage(
                                    widget.eventId, img.id);
                                widget.onImagesChanged();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.54),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    size: AppIconSize.sm,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.canManage) ...[
            AppSpacing.vSm,
            _addImageButton(),
          ],
          AppSpacing.vXxl,
        ],
      );
    }

    if (!widget.isPreview && widget.canManage) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EventDetailHelpers.sectionTitle(context, 'Photos',
              icon: Icons.photo_library_rounded,
              iconColor: context.photoAccent),
          AppSpacing.vSm,
          _addImageButton(),
          AppSpacing.vXxl,
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _addImageButton() {
    return OutlinedButton.icon(
      onPressed: _uploading ? null : _pickAndUploadImages,
      icon: _uploading
          ? const SizedBox(
              width: AppIconSize.sm,
              height: AppIconSize.sm,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.add_photo_alternate, size: AppIconSize.sm),
      label: Text(_uploading ? 'Uploading...' : 'Add Photos'),
    );
  }
}
