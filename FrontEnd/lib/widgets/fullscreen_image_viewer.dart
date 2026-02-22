import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/design_tokens.dart';

class FullscreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final List<String?> captions;
  final int initialIndex;

  const FullscreenImageViewer({
    super.key,
    required this.imageUrls,
    this.captions = const [],
    this.initialIndex = 0,
  });

  static Future<void> open(
    BuildContext context, {
    required List<String> imageUrls,
    List<String?> captions = const [],
    int initialIndex = 0,
    String? heroTagPrefix,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        transitionDuration: AppDuration.normal,
        reverseTransitionDuration: AppDuration.normal,
        pageBuilder: (_, __, ___) => FullscreenImageViewer(
          imageUrls: imageUrls,
          captions: captions,
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer>
    with TickerProviderStateMixin {
  late PageController _pageCtrl;
  late int _currentIndex;
  late List<TransformationController> _transformCtrls;

  bool _chromeVisible = true;
  double _dragOffset = 0;
  double _dragOpacity = 1;
  bool _dragging = false;

  late AnimationController _doubleTapCtrl;
  Animation<Matrix4>? _doubleTapAnim;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _pageCtrl = PageController(initialPage: _currentIndex);
    _transformCtrls = List.generate(
      widget.imageUrls.length,
      (_) => TransformationController(),
    );
    _doubleTapCtrl = AnimationController(
      vsync: this,
      duration: AppDuration.normal,
    )..addListener(() {
        if (_doubleTapAnim != null) {
          _transformCtrls[_currentIndex].value = _doubleTapAnim!.value;
        }
      });

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _precacheAdjacent(_currentIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final c in _transformCtrls) {
      c.dispose();
    }
    _doubleTapCtrl.dispose();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  void _precacheAdjacent(int index) {
    for (final i in [index - 1, index + 1]) {
      if (i >= 0 && i < widget.imageUrls.length) {
        precacheImage(NetworkImage(widget.imageUrls[i]), context);
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _resetZoom(index);
    _precacheAdjacent(index);
  }

  void _resetZoom(int index) {
    _transformCtrls[index].value = Matrix4.identity();
  }

  void _handleDoubleTap(TapDownDetails details) {
    final ctrl = _transformCtrls[_currentIndex];
    final currentScale = ctrl.value.getMaxScaleOnAxis();
    final isZoomed = currentScale > 1.1;

    Matrix4 end;
    if (isZoomed) {
      end = Matrix4.identity();
    } else {
      const targetScale = 2.5;
      final pos = details.localPosition;
      final dx = (1 - targetScale) * pos.dx;
      final dy = (1 - targetScale) * pos.dy;
      end = Matrix4.identity()
        ..translate(dx, dy)
        ..scale(targetScale);
    }

    _doubleTapAnim = Matrix4Tween(begin: ctrl.value, end: end).animate(
      CurvedAnimation(parent: _doubleTapCtrl, curve: AppCurve.standard),
    );
    _doubleTapCtrl
      ..reset()
      ..forward();
  }

  void _onVerticalDragStart(DragStartDetails _) {
    final isZoomed =
        _transformCtrls[_currentIndex].value.getMaxScaleOnAxis() > 1.1;
    if (isZoomed) return;
    setState(() => _dragging = true);
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    setState(() {
      _dragOffset += details.delta.dy;
      _dragOpacity = (1 - (_dragOffset.abs() / 400)).clamp(0.4, 1.0);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (!_dragging) return;
    final velocity = details.primaryVelocity ?? 0;
    if (_dragOffset.abs() > 100 || velocity.abs() > 800) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _dragOffset = 0;
        _dragOpacity = 1;
        _dragging = false;
      });
    }
  }

  void _toggleChrome() {
    setState(() => _chromeVisible = !_chromeVisible);
  }

  String? _captionAt(int index) {
    if (index < widget.captions.length) return widget.captions[index];
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final caption = _captionAt(_currentIndex);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: _dragOpacity),
      body: Stack(
        children: [
          GestureDetector(
            onVerticalDragStart: _onVerticalDragStart,
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            onTap: _toggleChrome,
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: Opacity(
                opacity: _dragOpacity,
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: widget.imageUrls.length,
                  onPageChanged: _onPageChanged,
                  physics: _transformCtrls[_currentIndex]
                              .value
                              .getMaxScaleOnAxis() >
                          1.1
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  itemBuilder: (context, index) {
                    return _buildPage(index);
                  },
                ),
              ),
            ),
          ),

          // Top chrome: close button + counter
          AnimatedOpacity(
            opacity: _chromeVisible ? 1.0 : 0.0,
            duration: AppDuration.fast,
            child: IgnorePointer(
              ignoring: !_chromeVisible,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _chromeButton(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      if (widget.imageUrls.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: AppRadius.pill,
                          ),
                          child: Text(
                            '${_currentIndex + 1} / ${widget.imageUrls.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom chrome: caption
          if (caption != null && caption.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedOpacity(
                opacity: _chromeVisible ? 1.0 : 0.0,
                duration: AppDuration.fast,
                child: IgnorePointer(
                  ignoring: !_chromeVisible,
                  child: Container(
                    padding: EdgeInsets.only(
                      left: AppSpacing.lg,
                      right: AppSpacing.lg,
                      top: AppSpacing.md,
                      bottom: MediaQuery.of(context).padding.bottom +
                          AppSpacing.lg,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: Text(
                      caption,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    final url = widget.imageUrls[index];
    final heroTag = 'event-image-$index';

    Widget image = InteractiveViewer(
      transformationController: _transformCtrls[index],
      minScale: 1.0,
      maxScale: 4.0,
      child: Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            final pct = progress.expectedTotalBytes != null
                ? progress.cumulativeBytesLoaded /
                    progress.expectedTotalBytes!
                : null;
            return Center(
              child: CircularProgressIndicator(
                value: pct,
                strokeWidth: 2,
                color: Colors.white70,
              ),
            );
          },
          errorBuilder: (_, __, ___) => const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image_rounded, size: 48, color: Colors.white38),
              SizedBox(height: 8),
              Text(
                'Failed to load image',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );

    image = GestureDetector(
      onDoubleTapDown: (details) => _handleDoubleTap(details),
      onDoubleTap: () {},
      child: image,
    );

    return Hero(
      tag: heroTag,
      child: image,
    );
  }

  Widget _chromeButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: AppIconSize.md),
      ),
    );
  }
}
