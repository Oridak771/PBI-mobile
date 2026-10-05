import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'common.dart';

/// Circular avatar: the photo (downloaded with the Bearer header) or the
/// initials on `avatar_color` — or, with [brand], on the green gradient of
/// the glass style (white 40% ring, dark initials).
class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    super.key,
    required this.size,
    this.photoUrl,
    this.initials = '',
    this.color,
    this.brand = false,
  });

  final double size;
  final String? photoUrl;
  final String initials;
  final String? color;
  final bool brand;

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
        color: brand ? null : parseHexColor(color),
        gradient: brand
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFB6DD62), Color(0xFF5E8A1F)],
              )
            : null,
        border: brand
            ? Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2)
            : null,
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
      color: brand ? const Color(0xFF10140A) : Colors.white,
      fontSize: size * (brand ? 0.33 : 0.36),
      fontWeight: FontWeight.bold,
    ),
  );
}
