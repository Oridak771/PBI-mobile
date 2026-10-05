import 'package:flutter/material.dart';

import '../layout/adaptive.dart';
import '../theme/app_dimens.dart';
import '../theme/app_palette.dart';

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
      color: context.palette.surfaceAlt,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Card-shaped skeleton row: icon well, two text lines.
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({super.key, this.lines = 2});

  final int lines;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          const SkeletonBox(
            width: 40,
            height: 40,
            radius: AppDimens.radiusControl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FractionallySizedBox(
                  widthFactor: 0.7,
                  child: SkeletonBox(height: 14),
                ),
                for (var i = 1; i < lines; i++) ...[
                  const SizedBox(height: 8),
                  const FractionallySizedBox(
                    widthFactor: 0.45,
                    child: SkeletonBox(height: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
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

/// Home loading state: section labels and rows of card placeholders.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Skeleton(
    child: ListView(
      key: const Key('skeleton-home'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppDimens.page, 8, 0, 16),
      children: [
        for (var s = 0; s < 3; s++) ...[
          const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 10),
            child: SkeletonBox(width: 90, height: 12),
          ),
          SizedBox(
            height: AppDimens.groupCardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 8,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: AppDimens.groupCardGap),
              itemBuilder: (_, _) => const SkeletonBox(
                width: AppDimens.groupCardWidth,
                height: AppDimens.groupCardHeight,
                radius: AppDimens.radiusCard,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
