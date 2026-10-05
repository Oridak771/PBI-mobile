import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_palette.dart';

/// Legacy Toast → floating snackbar.
void showToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// App bar area of the secondary screens (Historique, Tickets, viewer…):
/// green back arrow, bold title in the text colour, optional action on the
/// right.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.onBack,
    this.action,
    this.height = AppDimens.screenHeaderHeight,
    this.titleSize = 20,
    this.onTitleLongPress,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? action;
  final double height;
  final double titleSize;

  /// Hidden gesture on the title (no visual affordance).
  final VoidCallback? onTitleLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Retour',
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: Icon(Icons.arrow_back_rounded, color: palette.primaryText),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: GestureDetector(
                key: const Key('screen-header-title'),
                behavior: HitTestBehavior.opaque,
                onLongPress: onTitleLongPress,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: titleSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

/// Small upper-case, letter-spaced muted label with an optional count
/// (home sections, notification groups, settings groups).
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.count,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(AppDimens.page, 16, AppDimens.page, 8),
  });

  final String title;
  final int? count;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Flexible(
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.border),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: palette.textSubtle,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (trailing == null)
            const Spacer()
          else ...[
            const SizedBox(width: 8),
            // Shrinks (ellipsis) on narrow screens / large fonts.
            Expanded(
              child: Align(alignment: Alignment.centerRight, child: trailing),
            ),
          ],
        ],
      ),
    );
  }
}

/// Flat surface with a 1px border (no elevation), optionally tappable.
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
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor ?? palette.border),
    );
    return Padding(
      padding: margin,
      child: Material(
        color: color ?? palette.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? Padding(padding: padding, child: child)
            : InkWell(
                onTap: onTap,
                child: Padding(padding: padding, child: child),
              ),
      ),
    );
  }
}

/// Leading rounded icon container of list rows (icon on a green tint by
/// default).
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
        borderRadius: BorderRadius.circular(AppDimens.radiusControl),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.55, color: color ?? palette.primaryText),
    );
  }
}

/// Green heart used in report lists and favourites.
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
      icon: Icon(
        favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: favorite ? palette.primaryText : palette.textSubtle,
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
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: Icon(Icons.refresh_rounded, color: palette.primaryText),
            label: const Text('Réessayer'),
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
