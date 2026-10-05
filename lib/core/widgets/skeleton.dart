import 'package:flutter/material.dart';

import '../layout/adaptive.dart';
import '../theme/app_dimens.dart';
import '../theme/app_palette.dart';
import 'glass.dart';

/// Gently pulsing placeholder shown while a list loads (instead of a
/// full-screen spinner). Static when animations are disabled.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.child});

  final Widget child;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Chargement',
    child: ExcludeSemantics(
      child: FadeTransition(opacity: _controller, child: widget.child),
    ),
  );
}

/// Rounded grey block of a skeleton.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 6,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: context.palette.skeleton,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Card-shaped skeleton row: icon tile, two text lines.
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({super.key, this.lines = 2});

  final int lines;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: GlassPanel(
      shadow: false,
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          const SkeletonBox(
            width: AppDimens.tile,
            height: AppDimens.tile,
            radius: AppDimens.radiusTile,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FractionallySizedBox(
                  widthFactor: 0.7,
                  child: SkeletonBox(height: 13),
                ),
                for (var i = 1; i < lines; i++) ...[
                  const SizedBox(height: 8),
                  const FractionallySizedBox(
                    widthFactor: 0.45,
                    child: SkeletonBox(height: 10),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Loading list: [count] skeleton rows, centered like the real content.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 6, this.lines = 2, this.top = 8});

  final int count;
  final int lines;
  final double top;

  @override
  Widget build(BuildContext context) => CenteredContent(
    builder: (context, gutter) => Skeleton(
      child: ListView(
        key: const Key('skeleton-list'),
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(gutter, top, gutter, 16),
        children: [for (var i = 0; i < count; i++) SkeletonRow(lines: lines)],
      ),
    ),
  );
}

/// Home loading state: récents cards, the chip bar and the group grid.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Skeleton(
    child: ListView(
      key: const Key('skeleton-home'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppDimens.page, 16, AppDimens.page, 16),
      children: [
        const SkeletonBox(width: 80, height: 13),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(
              child: SkeletonBox(height: 112, radius: AppDimens.radiusCard),
            ),
            SizedBox(width: 10),
            Expanded(
              child: SkeletonBox(height: 112, radius: AppDimens.radiusCard),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const SkeletonBox(height: 40, radius: 999),
        const SizedBox(height: 14),
        for (var r = 0; r < 2; r++) ...[
          const Row(
            children: [
              Expanded(
                child: SkeletonBox(height: 104, radius: AppDimens.radiusCard),
              ),
              SizedBox(width: AppDimens.gridGap),
              Expanded(
                child: SkeletonBox(height: 104, radius: AppDimens.radiusCard),
              ),
              SizedBox(width: AppDimens.gridGap),
              Expanded(
                child: SkeletonBox(height: 104, radius: AppDimens.radiusCard),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gridGap),
        ],
      ],
    ),
  );
}
