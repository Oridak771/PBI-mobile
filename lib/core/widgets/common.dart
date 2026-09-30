import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Legacy Toast → floating snackbar.
void showToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Title with the 2px `#66A5CF4B` underline as wide as the text
/// (Historique / viewer headers).
class UnderlinedTitle extends StatelessWidget {
  const UnderlinedTitle(this.text, {super.key, this.fontSize = 22});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) => IntrinsicWidth(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.green, fontSize: fontSize),
        ),
        Container(
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          color: AppColors.greenLight,
        ),
      ],
    ),
  );
}

/// Header of the secondary screens (Historique, Mes demandes, viewer):
/// back arrow, centred underlined title, optional action on the right.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.onBack,
    this.action,
    this.height = 50,
    this.titleSize = 22,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? action;
  final double height;
  final double titleSize;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Row(
      children: [
        SizedBox(
          width: 48,
          child: IconButton(
            tooltip: 'Retour',
            padding: EdgeInsets.zero,
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.chevron_left,
              size: 30,
              color: AppColors.blueGreen,
            ),
          ),
        ),
        Expanded(
          child: Center(child: UnderlinedTitle(title, fontSize: titleSize)),
        ),
        SizedBox(width: 48, child: action),
      ],
    ),
  );
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
  Widget build(BuildContext context) => IconButton(
    tooltip: favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
    onPressed: onPressed,
    padding: const EdgeInsets.all(5),
    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
    icon: Icon(
      favorite ? Icons.favorite : Icons.favorite_border,
      color: AppColors.green,
    ),
  );
}

/// Centered grey message used by empty states.
class EmptyText extends StatelessWidget {
  const EmptyText(
    this.text, {
    super.key,
    this.color = AppColors.greyText,
    this.padding = 25,
    this.fontSize = 14,
  });

  final String text;
  final Color color;
  final double padding;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(padding),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: color, fontSize: fontSize),
    ),
  );
}

/// Error block with a "Réessayer" button.
class RetryMessage extends StatelessWidget {
  const RetryMessage({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.tint, fontSize: 18),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: onRetry,
          child: const Text(
            'Réessayer',
            style: TextStyle(
              color: AppColors.green,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Parses `#RRGGBB` (API `avatar_color`).
Color parseHexColor(String? hex, {Color fallback = AppColors.blueGreen}) {
  if (hex == null) return fallback;
  var v = hex.trim().replaceFirst('#', '');
  if (v.length == 6) v = 'FF$v';
  final n = int.tryParse(v, radix: 16);
  return n == null || v.length != 8 ? fallback : Color(n);
}
