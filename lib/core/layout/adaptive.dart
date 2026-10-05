import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Material window size classes (by available width, in dp).
enum WindowSize {
  /// < 600: phones in portrait.
  compact,

  /// 600–839: small tablets, foldables, phones in landscape.
  medium,

  /// ≥ 840: tablets in landscape, large screens.
  expanded;

  static const mediumMin = 600.0;
  static const expandedMin = 840.0;

  static WindowSize of(double width) => width >= expandedMin
      ? expanded
      : width >= mediumMin
      ? medium
      : compact;

  bool get isCompact => this == compact;
  bool get isExpanded => this == expanded;
}

extension WindowSizeContext on BuildContext {
  /// Size class of the whole window.
  WindowSize get windowSize => WindowSize.of(MediaQuery.sizeOf(this).width);
}

/// Widths of the adaptive layouts.
abstract final class AdaptiveDimens {
  /// Readable content width of lists, forms, settings, tickets, history.
  static const contentMaxWidth = 720.0;

  /// List pane of the two-pane layouts (tickets).
  static const listPaneWidth = 380.0;

  /// Largest app text scale: bigger system font sizes are clamped to it.
  static const maxTextScale = 1.3;

  /// Horizontal padding that centers [contentMaxWidth] in [width] (at least
  /// [minimum], the page gutter).
  static double gutter(double width, {double minimum = 16}) =>
      math.max(minimum, (width - contentMaxWidth) / 2);
}

/// Centers [child] at most [maxWidth] wide (non-scrolling content).
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = AdaptiveDimens.contentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Gives [builder] the side padding that centers the content in the space
/// actually available (scroll views keep their full width, so the whole
/// screen scrolls while the content stays readable).
class CenteredContent extends StatelessWidget {
  const CenteredContent({super.key, required this.builder});

  final Widget Function(BuildContext context, double gutter) builder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : MediaQuery.sizeOf(context).width;
      return builder(context, AdaptiveDimens.gutter(width));
    },
  );
}

/// `MaterialApp.builder` part: clamps the system text scale to
/// [AdaptiveDimens.maxTextScale] so large font settings stay legible without
/// breaking the layouts.
Widget clampTextScale(BuildContext context, Widget? child) =>
    MediaQuery.withClampedTextScaling(
      maxScaleFactor: AdaptiveDimens.maxTextScale,
      child: child ?? const SizedBox.shrink(),
    );

/// Orientation policy: tablets (shortest side ≥ 600 dp) rotate freely on
/// every screen; phones stay in portrait except in the report viewer (which
/// sets its own orientations and calls [restore] when it closes).
abstract final class AppOrientations {
  static bool _tablet = false;

  static bool get isTablet => _tablet;

  /// Orientations of the non-viewer screens.
  static List<DeviceOrientation> get allowed =>
      _tablet ? DeviceOrientation.values : const [DeviceOrientation.portraitUp];

  static bool isTabletSize(ui.Size logicalSize) =>
      logicalSize.shortestSide >= WindowSize.mediumMin;

  /// Startup: detects a tablet from the display and applies [allowed].
  static Future<void> init() async {
    _tablet = isTabletSize(_displaySize());
    await restore();
  }

  /// Back to the app policy (after the viewer).
  static Future<void> restore() =>
      SystemChrome.setPreferredOrientations(allowed);

  /// Logical size of the display (independent of the current rotation and
  /// window), `Size.zero` when unknown (treated as a phone).
  static ui.Size _displaySize() {
    try {
      final views = ui.PlatformDispatcher.instance.views;
      if (views.isEmpty) return ui.Size.zero;
      final view = views.first;
      final display = view.display;
      if (display.size.isEmpty || display.devicePixelRatio <= 0) {
        return view.physicalSize / view.devicePixelRatio;
      }
      return display.size / display.devicePixelRatio;
    } catch (_) {
      return ui.Size.zero;
    }
  }
}
