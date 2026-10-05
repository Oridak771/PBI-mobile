import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_palette.dart';
import 'glass.dart';

/// Legacy Toast → floating snackbar.
void showToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Header of the secondary screens (Historique, Tickets, viewer…): round
/// glass back button, bold title, optional action on the right.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.onBack,
    this.action,
    this.height = AppDimens.screenHeaderHeight,
    this.titleSize = 18,
    this.onTitleLongPress,
    this.subtitle,
    this.showBack = true,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? action;
  final double height;
  final double titleSize;

  /// Hides the back button (root screens).
  final bool showBack;

  /// Hidden gesture on the title (no visual affordance).
  final VoidCallback? onTitleLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sub = subtitle ?? '';
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppDimens.page, 6, AppDimens.page, 6),
        child: Row(
          children: [
            if (showBack) ...[
              GlassIconButton(
                key: const Key('screen-back'),
                tooltip: 'Retour',
                size: 40,
                icon: Icons.chevron_left_rounded,
                iconSize: 24,
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: GestureDetector(
                key: const Key('screen-header-title'),
                behavior: HitTestBehavior.opaque,
                onLongPress: onTitleLongPress,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.text,
                        fontSize: titleSize,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (sub.isNotEmpty)
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.textMuted, fontSize: 11),
                      ),
                  ],
                ),
              ),
            ),
            if (action != null) ...[const SizedBox(width: 8), action!],
          ],
        ),
      ),
    );
  }
}

/// Section title ("Récents", "Activité"…): bold 14, optional count pill and
/// trailing action ("Tout voir").
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.count,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(
      AppDimens.page + 2,
      16,
      AppDimens.page + 2,
      8,
    ),
  });

  final String title;
  final int? count;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final heading = Row(
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: palette.glassSelected,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Expanded(child: heading),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              // Right-aligned; shrinks (ellipsis) on narrow screens.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * 0.6,
                ),
                child: trailing,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small green text action ("Tout voir").
class LinkText extends StatelessWidget {
  const LinkText(this.text, {super.key, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: context.palette.primaryText, fontSize: 11.5),
      ),
    ),
  );
}

/// Glass card (no backdrop blur: safe inside scrolling lists), optionally
/// tappable.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.radius = AppDimens.radiusCard,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;

  /// Flat fill replacing the glass gradient (selected / tinted cards).
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: margin,
    child: GlassPanel(
      borderRadius: BorderRadius.circular(radius),
      fill: color,
      borderColor: borderColor,
      onTap: onTap,
      padding: padding,
      child: child,
    ),
  );
}

/// Glass panel holding rows separated by 1px dividers (report lists,
/// settings groups).
class GlassListPanel extends StatelessWidget {
  const GlassListPanel({
    super.key,
    required this.children,
    this.indent = 0,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  });

  final List<Widget> children;
  final double indent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GlassPanel(
      borderRadius: BorderRadius.circular(AppDimens.radiusPanel),
      padding: padding,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: indent,
                  color: palette.divider,
                ),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

/// Leading rounded icon tile of list rows (green tint by default).
class IconWell extends StatelessWidget {
  const IconWell(
    this.icon, {
    super.key,
    this.size = 40,
    this.color,
    this.background,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? palette.primarySoft,
        borderRadius: BorderRadius.circular(size * AppDimens.radiusTile / 40),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.48, color: color ?? palette.primaryText),
    );
  }
}

/// Heart of the report rows: green when favourite, muted otherwise.
class FavoriteHeart extends StatelessWidget {
  const FavoriteHeart({
    super.key,
    required this.favorite,
    required this.onPressed,
  });

  final bool favorite;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return IconButton(
      tooltip: favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
      onPressed: onPressed,
      // Mockup: the same outlined heart, green when favourite.
      icon: Icon(
        Icons.favorite_border_rounded,
        size: 21,
        color: favorite ? palette.primaryText : palette.textMuted,
      ),
    );
  }
}

/// Centered muted message used by empty states.
class EmptyText extends StatelessWidget {
  const EmptyText(
    this.text, {
    super.key,
    this.color,
    this.padding = 24,
    this.fontSize = 14,
    this.icon,
  });

  final String text;
  final Color? color;
  final double padding;
  final double fontSize;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 36, color: palette.textSubtle),
            const SizedBox(height: 10),
          ],
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: color ?? palette.textMuted, fontSize: fontSize),
          ),
        ],
      ),
    );
  }
}

/// Error block with a "Réessayer" button.
class RetryMessage extends StatelessWidget {
  const RetryMessage({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 40, color: palette.textSubtle),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted, fontSize: 16),
          ),
          const SizedBox(height: 16),
          GradientButton(
            label: 'Réessayer',
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
            expand: false,
            height: 44,
            fontSize: 14,
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
        ],
      ),
    );
  }
}

/// Parses `#RRGGBB` (API `avatar_color`).
Color parseHexColor(String? hex, {Color fallback = AppColors.avatarFallback}) {
  if (hex == null) return fallback;
  var v = hex.trim().replaceFirst('#', '');
  if (v.length == 6) v = 'FF$v';
  final n = int.tryParse(v, radix: 16);
  return n == null || v.length != 8 ? fallback : Color(n);
}
