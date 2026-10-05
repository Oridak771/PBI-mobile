import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import '../theme/app_palette.dart';

/// Building blocks of the Portail BI "glass" style (approved mockup,
/// `docs/design/mockup.html`).
///
/// * [GlassBackground]: dark (or pale) base gradient with three soft radial
///   glows, painted once behind a screen (static, own repaint boundary).
/// * [GlassPanel]: translucent surface (white 14%→4% gradient, 1px white 16%
///   border, inner top highlight, soft shadow). `blur: true` adds a
///   [BackdropFilter] (blur 22 + saturation 170%) and must only be used on
///   static chrome (tab bar, search field, chip bars, round header buttons,
///   login panel, sheets); cards inside scrolling lists use `blur: false`.
/// * [GradientButton], [GlassChip], [GlassSegmentedBar], [GlassIconButton].

/// Base gradient + radial glows behind a screen.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child, this.palette});

  final Widget child;

  /// Forces a palette (the splash is always dark); defaults to the theme's.
  final AppPalette? palette;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      RepaintBoundary(
        child: CustomPaint(
          key: const Key('glass-background'),
          painter: _GlowPainter(palette ?? context.palette),
        ),
      ),
      child,
    ],
  );
}

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.palette);

  final AppPalette palette;

  // Mockup phone: 310 px wide; glows of 240 px fading out at 70 %.
  static const _mockupWidth = 310.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.backgroundTop, palette.background],
        ).createShader(rect),
    );
    // Scale with the width, capped so tablets keep soft corner glows.
    final scale = (size.width.clamp(0, 520) / _mockupWidth).toDouble();
    void glow(double fx, double fy, double radius, Color color) {
      final center = Offset(size.width * fx, size.height * fy);
      final r = radius * scale;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
            stops: const [0, 0.7],
          ).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }

    glow(0.85, 0.08, 240, palette.glowGreen);
    glow(0, 0.55, 260, palette.glowTeal);
    glow(1, 0.95, 220, palette.glowBlue);
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.palette != palette;
}

/// Saturation matrix (CSS `saturate()`), used with the backdrop blur.
List<double> _saturation(double s) {
  const r = 0.213, g = 0.715, b = 0.072;
  return [
    r * (1 - s) + s, g * (1 - s), b * (1 - s), 0, 0, //
    r * (1 - s), g * (1 - s) + s, b * (1 - s), 0, 0, //
    r * (1 - s), g * (1 - s), b * (1 - s) + s, 0, 0, //
    0, 0, 0, 1, 0,
  ];
}

final ui.ImageFilter _glassFilter = ui.ImageFilter.compose(
  outer: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
  inner: ui.ColorFilter.matrix(_saturation(1.7)),
);

/// Translucent glass surface.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(AppDimens.radiusCard),
    ),
    this.blur = false,
    this.padding = EdgeInsets.zero,
    this.onTap,
    this.onLongPress,
    this.fill,
    this.borderColor,
    this.shadow = true,
    this.highlight = true,
    this.width,
    this.height,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// Backdrop blur (static chrome only).
  final bool blur;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Flat fill replacing the white gradient (inputs, tinted states).
  final Color? fill;
  final Color? borderColor;
  final bool shadow;

  /// Inner top highlight (white 28% line).
  final bool highlight;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null || onLongPress != null) {
      content = Material(
        type: MaterialType.transparency,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: borderRadius,
          child: content,
        ),
      );
    }
    Widget surface = CustomPaint(
      painter: _GlassPainter(
        palette: palette,
        borderRadius: borderRadius,
        fill: fill,
        borderColor: borderColor,
        highlight: highlight,
      ),
      child: content,
    );
    if (blur) {
      surface = RepaintBoundary(
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(filter: _glassFilter, child: surface),
        ),
      );
    }
    if (shadow) {
      surface = CustomPaint(
        painter: _SoftShadowPainter(
          color: palette.glassShadow,
          borderRadius: borderRadius,
        ),
        child: surface,
      );
    }
    if (width != null || height != null) {
      surface = SizedBox(width: width, height: height, child: surface);
    }
    return surface;
  }
}

/// Fill gradient + 1px border + inner top highlight.
class _GlassPainter extends CustomPainter {
  _GlassPainter({
    required this.palette,
    required this.borderRadius,
    this.fill,
    this.borderColor,
    this.highlight = true,
  });

  final AppPalette palette;
  final BorderRadius borderRadius;
  final Color? fill;
  final Color? borderColor;
  final bool highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);
    final paint = Paint();
    final flat = fill;
    if (flat != null) {
      paint.color = flat;
    } else {
      paint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [palette.glassTop, palette.glassBottom],
      ).createShader(rect);
    }
    canvas.drawRRect(rrect, paint);
    if (highlight) {
      // Inner top highlight (CSS `inset 0 1px 0`).
      final outer = Path()..addRRect(rrect);
      canvas.drawPath(
        Path.combine(
          PathOperation.difference,
          outer,
          outer.shift(const Offset(0, 1)),
        ),
        Paint()..color = palette.glassHighlight,
      );
    }
    final border = borderColor ?? palette.glassBorder;
    if (border.a == 0) return;
    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = border,
    );
  }

  @override
  bool shouldRepaint(_GlassPainter old) =>
      old.palette != palette ||
      old.borderRadius != borderRadius ||
      old.fill != fill ||
      old.highlight != highlight ||
      old.borderColor != borderColor;
}

/// Paints a soft shadow of [rrect] as stacked translucent rounded rects
/// (a cheap, renderer-independent approximation of a CSS `box-shadow` blur
/// of [blur] px; no mask filter / save layer).
void paintSoftShadow(
  Canvas canvas,
  RRect rrect,
  Color color, {
  required double blur,
  Offset offset = Offset.zero,
  int steps = 12,
}) {
  final target = color.a;
  if (target <= 0 || blur <= 0) return;
  final perLayer = 1 - math.pow(1 - target, 1 / steps).toDouble();
  final paint = Paint()..color = color.withValues(alpha: perLayer);
  final shifted = rrect.shift(offset);
  final minHalf = math.min(rrect.width, rrect.height) / 2;
  for (var i = 0; i < steps; i++) {
    final grow = blur - 2 * blur * (i + 0.5) / steps;
    if (-grow >= minHalf) break;
    canvas.drawRRect(shifted.inflate(grow), paint);
  }
}

/// Soft drop shadow (CSS `0 10px 30px`), optionally drawn only outside the
/// surface so a translucent fill is not darkened.
class _SoftShadowPainter extends CustomPainter {
  _SoftShadowPainter({
    required this.color,
    required this.borderRadius,
    this.blur = 30,
    this.offset = const Offset(0, 10),
    this.outsideOnly = true,
  });

  final Color color;
  final BorderRadius borderRadius;
  final double blur;
  final Offset offset;
  final bool outsideOnly;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = borderRadius.toRRect(Offset.zero & size);
    canvas.save();
    if (outsideOnly) {
      canvas.clipPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect((Offset.zero & size).inflate(blur * 2 + 20)),
          Path()..addRRect(rrect),
        ),
      );
    }
    paintSoftShadow(canvas, rrect, color, blur: blur, offset: offset);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SoftShadowPainter old) =>
      old.color != color ||
      old.borderRadius != borderRadius ||
      old.blur != blur ||
      old.offset != offset ||
      old.outsideOnly != outsideOnly;
}

/// Green glow under the gradient buttons / selected chips
/// (CSS `0 6px 18px rgba(165,207,75,.35)`).
class _GreenGlow extends StatelessWidget {
  const _GreenGlow({
    required this.radius,
    required this.enabled,
    required this.child,
  });

  final BorderRadius radius;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) => enabled
      ? CustomPaint(
          painter: _SoftShadowPainter(
            color: context.palette.primary.withValues(alpha: 0.35),
            borderRadius: radius,
            blur: 18,
            offset: const Offset(0, 6),
            outsideOnly: false,
          ),
          child: child,
        )
      : child;
}

/// Green vertical gradient decoration (#B6DD62 → #93BF3A, white 35% border)
/// of primary buttons and selected chips (the glow is painted by
/// `_GreenGlow`).
BoxDecoration primaryGradientDecoration(
  AppPalette palette,
  BorderRadius radius, {
  bool enabled = true,
}) => BoxDecoration(
  borderRadius: radius,
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: enabled
        ? [palette.gradientTop, palette.gradientBottom]
        : [
            palette.gradientTop.withValues(alpha: 0.5),
            palette.gradientBottom.withValues(alpha: 0.5),
          ],
  ),
  border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
);

/// Inner top highlight of the green gradient (white 50%, 1px).
class _GradientHighlight extends StatelessWidget {
  const _GradientHighlight({required this.radius});

  final BorderRadius radius;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      painter: _HighlightPainter(radius, Colors.white.withValues(alpha: 0.5)),
    ),
  );
}

class _HighlightPainter extends CustomPainter {
  _HighlightPainter(this.radius, this.color);

  final BorderRadius radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()..addRRect(radius.toRRect(Offset.zero & size));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        outer,
        outer.shift(const Offset(0, 1)),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_HighlightPainter old) =>
      old.radius != radius || old.color != color;
}

/// Primary action: green gradient, dark label, optional icon / spinner.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.height = 50,
    this.radius = 17,
    this.fontSize = 15,
    this.expand = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final double height;
  final double radius;
  final double fontSize;

  /// Takes the full available width.
  final bool expand;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onPressed != null && !busy;
    final r = BorderRadius.circular(radius);
    final fg = palette.onPrimary;
    final Widget content = busy
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) Icon(icon, size: fontSize + 3, color: fg),
              if (icon != null && label.isNotEmpty) const SizedBox(width: 6),
              if (label.isNotEmpty)
                Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
    return Semantics(
      button: true,
      enabled: enabled,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: height,
          minWidth: expand ? double.infinity : 0,
        ),
        child: _GreenGlow(
          radius: r,
          enabled: enabled,
          child: DecoratedBox(
          decoration: primaryGradientDecoration(
            palette,
            r,
            enabled: enabled || busy,
          ),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(child: _GradientHighlight(radius: r)),
              Material(
                type: MaterialType.transparency,
                borderRadius: r,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: enabled ? onPressed : null,
                  borderRadius: r,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: height),
                    child: Padding(
                      padding: padding,
                      child: Center(widthFactor: 1, heightFactor: 1, child: content),
                    ),
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

/// Pill chip: selected = green gradient, otherwise muted text (inside a
/// [GlassSegmentedBar]) or a small glass pill ([standalone]).
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.standalone = false,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool standalone;
  final IconData? icon;

  static const _radius = BorderRadius.all(Radius.circular(999));

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = selected
        ? palette.onPrimary
        : standalone
        ? palette.text
        : palette.textMuted;
    final text = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          maxLines: 1,
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
    const padding = EdgeInsets.symmetric(horizontal: 13, vertical: 7);
    final Widget body = Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: _radius,
        child: Padding(padding: padding, child: text),
      ),
    );
    if (selected) {
      return _GreenGlow(
        radius: _radius,
        enabled: true,
        child: DecoratedBox(
          decoration: primaryGradientDecoration(palette, _radius),
          child: Stack(
            children: [
              const Positioned.fill(child: _GradientHighlight(radius: _radius)),
              Material(type: MaterialType.transparency, child: body),
            ],
          ),
        ),
      );
    }
    if (standalone) {
      return GlassPanel(
        borderRadius: _radius,
        shadow: false,
        child: Material(type: MaterialType.transparency, child: body),
      );
    }
    return Material(type: MaterialType.transparency, child: body);
  }
}

/// Item of a [GlassSegmentedBar].
class GlassSegment<T> {
  const GlassSegment(this.value, this.label, {this.key, this.icon});

  final T value;
  final String label;
  final Key? key;
  final IconData? icon;
}

/// Blurred glass pill holding chips (sections of the home, ticket filters,
/// Mobile / Bureau). Scrolls horizontally when the chips don't fit.
class GlassSegmentedBar<T> extends StatelessWidget {
  const GlassSegmentedBar({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.blur = true,
    this.expand = false,
  });

  final List<GlassSegment<T>> segments;

  /// Selected values (several for combinable filters).
  final Set<T> selected;
  final ValueChanged<T> onChanged;
  final bool blur;

  /// Chips share the width equally (when they fit).
  final bool expand;

  static const _radius = BorderRadius.all(Radius.circular(999));

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final s in segments)
        GlassChip(
          key: s.key,
          label: s.label,
          icon: s.icon,
          selected: selected.contains(s.value),
          onTap: () => onChanged(s.value),
        ),
    ];
    return GlassPanel(
      blur: blur,
      borderRadius: _radius,
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final row = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, chip) in chips.indexed) ...[
                if (i > 0) const SizedBox(width: 4),
                chip,
              ],
            ],
          );
          // Inside a Row (unbounded width): just the chips.
          if (!constraints.hasBoundedWidth) return row;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: expand
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: chips,
                    )
                  : Align(alignment: Alignment.centerLeft, child: row),
            ),
          );
        },
      ),
    );
  }
}

/// Round glass button (back, bell, viewer actions).
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 42,
    this.iconSize = 20,
    this.color,
    this.blur = true,
    this.badge,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color? color;
  final bool blur;

  /// Drawn over the top-right of the circle (unread dot).
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(size / 2);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GlassPanel(
            blur: blur,
            borderRadius: radius,
            width: size,
            height: size,
            child: Material(
              type: MaterialType.transparency,
              child: IconButton(
                tooltip: tooltip,
                onPressed: onPressed,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tight(Size(size, size)),
                icon: Icon(icon, size: iconSize, color: color ?? palette.text),
              ),
            ),
          ),
          if (badge != null) Positioned(top: 9, right: 10, child: badge!),
        ],
      ),
    );
  }
}

/// Small glowing dot (unread notifications, ticket priority): solid dot and
/// a radial glow of [glow] px (CSS `0 0 8px`).
class GlowDot extends StatelessWidget {
  const GlowDot({super.key, required this.color, this.size = 8, this.glow = 8});

  final Color color;
  final double size;
  final double glow;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _GlowDotPainter(color, glow)),
  );
}

class _GlowDotPainter extends CustomPainter {
  _GlowDotPainter(this.color, this.glow);

  final Color color;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    if (glow > 0) {
      final outer = r + glow;
      canvas.drawCircle(
        center,
        outer,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: color.a * 0.55),
              color.withValues(alpha: 0),
            ],
            stops: [r / outer, 1],
          ).createShader(Rect.fromCircle(center: center, radius: outer)),
      );
    }
    canvas.drawCircle(center, r, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_GlowDotPainter old) =>
      old.color != color || old.glow != glow;
}

/// Opens a modal bottom sheet drawn as blurred glass (drag handle, 24 top
/// radius).
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: isScrollControlled,
  backgroundColor: Colors.transparent,
  elevation: 0,
  showDragHandle: false,
  builder: (sheetContext) => GlassSheet(child: builder(sheetContext)),
);

/// Frame of [showGlassSheet]: blurred glass, opaque enough to read on any
/// content, with a drag handle.
class GlassSheet extends StatelessWidget {
  const GlassSheet({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GlassPanel(
      blur: true,
      shadow: false,
      fill: palette.isDark ? const Color(0xD91A1E24) : const Color(0xE6FFFFFF),
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppDimens.radiusSheet),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 14),
              decoration: BoxDecoration(
                color: palette.textSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}

/// Scaffold whose body sits on the [GlassBackground].
class GlassScaffold extends StatelessWidget {
  const GlassScaffold({
    super.key,
    required this.body,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset,
  });

  final Widget body;
  final Widget? floatingActionButton;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.palette.background,
    resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    floatingActionButton: floatingActionButton,
    body: GlassBackground(child: body),
  );
}
