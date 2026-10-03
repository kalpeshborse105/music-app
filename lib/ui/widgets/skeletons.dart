import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Shimmering skeleton block used for progressive loading (spec §4/§27).
/// Pure Flutter — no extra dependency.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 12,
    this.radius = AppSpacing.radiusSm,
  });

  @override
  Widget build(BuildContext context) {
    final Color base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return _Shimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Skeleton rows for a horizontal card carousel.
class SkeletonCardRow extends StatelessWidget {
  final int count;
  final double cardWidth;
  final double cardHeight;

  const SkeletonCardRow({
    super.key,
    this.count = 4,
    this.cardWidth = 150,
    this.cardHeight = 190,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.screen,
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (_, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SkeletonBox(width: cardWidth, height: cardWidth, radius: AppSpacing.radiusLg),
            const SizedBox(height: AppSpacing.sm),
            SkeletonBox(width: cardWidth * 0.8, height: 12),
            const SizedBox(height: AppSpacing.xs),
            SkeletonBox(width: cardWidth * 0.5, height: 10),
          ],
        ),
      ),
    );
  }
}

/// Skeleton list rows (for search results / library).
class SkeletonList extends StatelessWidget {
  final int count;
  const SkeletonList({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: AppSpacing.screenVertical,
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, __) => Row(
        children: <Widget>[
          const SkeletonBox(width: 52, height: 52, radius: AppSpacing.radiusMd),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const <Widget>[
                SkeletonBox(width: 180, height: 13),
                SizedBox(height: AppSpacing.sm),
                SkeletonBox(width: 110, height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A subtle moving shimmer painted behind a child.
class _Shimmer extends StatefulWidget {
  final Widget child;
  const _Shimmer({required this.child});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (Rect bounds) {
            final double slide = _controller.value * 2 - 1;
            return LinearGradient(
              begin: Alignment(-1 + slide, 0),
              end: Alignment(1 + slide, 0),
              colors: <Color>[
                Colors.transparent,
                Colors.white.withValues(alpha: 0.28),
                Colors.transparent,
              ],
              stops: const <double>[0.35, 0.5, 0.65],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
