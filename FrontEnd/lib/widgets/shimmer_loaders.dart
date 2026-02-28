import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../config/theme.dart';

class _ShimmerBase extends StatelessWidget {
  final Widget child;
  const _ShimmerBase({required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.shimmerOf(context),
      highlightColor: AppTheme.shimmerHighlightOf(context),
      child: child,
    );
  }
}

class _Box extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const _Box(
      {required this.width, required this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.shimmerOf(context),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class ShimmerEventCard extends StatelessWidget {
  const ShimmerEventCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerBase(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Box(width: double.infinity, height: 140, radius: 12),
            const SizedBox(height: 12),
            const _Box(width: 200, height: 16),
            const SizedBox(height: 8),
            const _Box(width: 140, height: 12),
            const SizedBox(height: 10),
            Row(
              children: [
                const _Box(width: 60, height: 22, radius: 12),
                const SizedBox(width: 8),
                const _Box(width: 50, height: 22, radius: 12),
                const SizedBox(width: 8),
                const _Box(width: 70, height: 22, radius: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ShimmerDetailHeader extends StatelessWidget {
  const ShimmerDetailHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerBase(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Box(width: 260, height: 24),
            const SizedBox(height: 12),
            const _Box(width: 180, height: 14),
            const SizedBox(height: 16),
            Row(
              children: [
                const _Box(width: 60, height: 24, radius: 12),
                const SizedBox(width: 8),
                const _Box(width: 50, height: 24, radius: 12),
                const SizedBox(width: 8),
                const _Box(width: 80, height: 24, radius: 12),
              ],
            ),
            const SizedBox(height: 20),
            const _Box(width: double.infinity, height: 8, radius: 4),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(child: _Box(width: 100, height: 44, radius: 12)),
                const SizedBox(width: 10),
                const Expanded(child: _Box(width: 100, height: 44, radius: 12)),
                const SizedBox(width: 10),
                const Expanded(child: _Box(width: 100, height: 44, radius: 12)),
              ],
            ),
            const SizedBox(height: 24),
            const _Box(width: double.infinity, height: 100, radius: 14),
            const SizedBox(height: 16),
            const _Box(width: double.infinity, height: 60, radius: 14),
            const SizedBox(height: 16),
            const _Box(width: double.infinity, height: 80, radius: 14),
          ],
        ),
      ),
    );
  }
}

class ShimmerListTile extends StatelessWidget {
  const ShimmerListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerBase(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const _Box(width: 48, height: 48, radius: 12),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Box(width: 160, height: 14),
                  const SizedBox(height: 6),
                  const _Box(width: 100, height: 11),
                ],
              ),
            ),
            const _Box(width: 60, height: 24, radius: 8),
          ],
        ),
      ),
    );
  }
}

class ShimmerReceiptCard extends StatelessWidget {
  const ShimmerReceiptCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerBase(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const _Box(width: 180, height: 180, radius: 16),
            const SizedBox(height: 20),
            const _Box(width: 200, height: 18),
            const SizedBox(height: 10),
            const _Box(width: 140, height: 14),
            const SizedBox(height: 20),
            const _Box(width: double.infinity, height: 1),
            const SizedBox(height: 16),
            for (int i = 0; i < 4; i++) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const _Box(width: 80, height: 12),
                    const _Box(width: 120, height: 12),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ShimmerProfileSection extends StatelessWidget {
  const ShimmerProfileSection({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerBase(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const _Box(width: 80, height: 80, radius: 40),
            const SizedBox(height: 16),
            const _Box(width: 150, height: 18),
            const SizedBox(height: 8),
            const _Box(width: 200, height: 13),
            const SizedBox(height: 24),
            for (int i = 0; i < 5; i++) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Box(width: 80, height: 11),
                    const SizedBox(height: 8),
                    const _Box(width: double.infinity, height: 48, radius: 12),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ShimmerEventList extends StatelessWidget {
  final int count;
  const ShimmerEventList({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: List.generate(count, (_) => const ShimmerEventCard()),
      ),
    );
  }
}

class ShimmerGrid extends StatelessWidget {
  final int count;
  const ShimmerGrid({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return _ShimmerBase(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(
            count,
            (_) => const _Box(width: 100, height: 90, radius: 14),
          ),
        ),
      ),
    );
  }
}
