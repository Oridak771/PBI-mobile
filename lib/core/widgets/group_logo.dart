import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../assets.dart';
import '../images/logo_images.dart';
import '../theme/app_dimens.dart';
import '../theme/app_palette.dart';

/// Square tile of a home card: the group logo (`logo_url`) inside a white
/// rounded square, or the code / initials on a green-tinted square.
///
/// The white square keeps logos with transparent backgrounds or dark marks
/// readable in dark mode. While the logo loads a neutral placeholder is shown;
/// a failed download falls back to the initials tile.
class GroupLogo extends ConsumerWidget {
  const GroupLogo({
    super.key,
    required this.label,
    this.logoUrl,
    this.assetCode,
    this.assetName,
    this.size = AppDimens.groupTile,
  });

  /// Code / initials shown when there is no logo.
  final String label;
  final String? logoUrl;

  /// Optional `AppAssets.codeImages` lookup (legacy code images).
  final String? assetCode;
  final String? assetName;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initials = InitialsTile(label: label, size: size);
    final url = logoUrl;
    ImageProvider? image;
    if (url != null && url.isNotEmpty) {
      image = ref.watch(logoImageResolverProvider)(url);
    }
    final asset = AppAssets.forCode(assetCode, name: assetName);
    if (image == null && asset != null) image = AssetImage(asset);
    if (image == null) return initials;
    return LogoTile(image: image, size: size, fallback: initials);
  }
}

/// [image] contained in a white rounded square (8 padding).
class LogoTile extends StatelessWidget {
  const LogoTile({
    super.key,
    required this.image,
    required this.fallback,
    this.size = AppDimens.groupTile,
  });

  final ImageProvider image;
  final Widget fallback;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(size * 0.22);
    return Image(
      image: image,
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, sync) {
        final loaded = sync || frame != null;
        return Container(
          key: loaded ? const Key('group-logo-loaded') : null,
          width: size,
          height: size,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: loaded ? Colors.white : palette.surfaceAlt,
            borderRadius: radius,
            border: Border.all(color: palette.border),
          ),
          child: AnimatedOpacity(
            opacity: loaded ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: child,
          ),
        );
      },
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

/// Code / initials on a green-tinted rounded square.
class InitialsTile extends StatelessWidget {
  const InitialsTile({
    super.key,
    required this.label,
    this.size = AppDimens.groupTile,
  });

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      key: const Key('group-initials'),
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: palette.primarySoft,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: palette.primary.withValues(alpha: 0.25)),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label.isEmpty ? '?' : label,
          maxLines: 1,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
