import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/app_colors.dart';
import 'common.dart';

/// Circular avatar: the photo (downloaded with the Bearer header) or the
/// initials on `avatar_color`.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    super.key,
    required this.size,
    this.photoUrl,
    this.initials = '',
    this.color,
  });

  final double size;
  final String? photoUrl;
  final String initials;
  final String? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = photoUrl;
    final bytes = url == null ? null : ref.watch(photoProvider(url)).value;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: parseHexColor(color),
      ),
      alignment: Alignment.center,
      child: bytes != null
          ? Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => _initials(),
            )
          : _initials(),
    );
  }

  Widget _initials() => Text(
    initials.isEmpty ? '?' : initials.toUpperCase(),
    style: TextStyle(
      color: AppColors.white,
      fontSize: size * 0.36,
      fontWeight: FontWeight.bold,
    ),
  );
}
