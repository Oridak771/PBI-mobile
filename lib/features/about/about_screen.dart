import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/assets.dart';
import '../../core/providers.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/asset_slots.dart';
import '../../core/widgets/common.dart';
import '../../data/models/remote_config.dart';

/// Legacy AboutAppAct.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider).value ?? '';
    final contact =
        ref.watch(remoteConfigProvider).value?.contact ?? const Contact();
    final palette = context.palette;
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'À propos'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.page),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 64,
                      child: LogoSlot(
                        asset: AppAssets.aboutLogo(brightness),
                        fallbackText: 'CBI',
                        fontSize: 36,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'GSH - CBI',
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: palette.primarySoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'V.$version',
                        style: TextStyle(
                          color: palette.primaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SquareIconButton(
                          tooltip: contact.websiteLabel,
                          icon: Icons.public_rounded,
                          onTap: () {
                            final uri = Uri.tryParse(contact.website);
                            if (uri != null) {
                              launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 20),
                        _SquareIconButton(
                          tooltip: contact.email,
                          icon: Icons.alternate_email_rounded,
                          onTap: () => launchUrl(
                            Uri(scheme: 'mailto', path: contact.email),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                children: [
                  Text(
                    'Cellule Business Intelligence',
                    style: TextStyle(color: palette.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '© ${DateTime.now().year} GSH',
                    style: TextStyle(color: palette.textSubtle, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Tooltip(
      message: tooltip,
      child: AppCard(
        onTap: onTap,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Icon(icon, color: palette.primaryText, size: 30),
        ),
      ),
    );
  }
}
