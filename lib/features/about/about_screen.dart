import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/assets.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/widgets/asset_slots.dart';
import '../../data/models/remote_config.dart';

/// Legacy AboutAppAct.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider).value ?? '';
    final contact = ref.watch(remoteConfigProvider).value?.contact ?? const Contact();
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Like the legacy activity: no header, system back closes it.
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(
                      height: 50 + 20,
                      child: Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: LogoSlot(
                          asset: AppAssets.aboutLogo,
                          fallbackText: 'CBI',
                          fontSize: 36,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'GSH - CBI',
                      style: TextStyle(
                        color: AppColors.tint,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        shadows: AppShadows.dark222,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'V.$version',
                      style: const TextStyle(
                        color: AppColors.tint,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        shadows: AppShadows.dark222,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SquareIconButton(
                          tooltip: contact.websiteLabel,
                          icon: const Icon(Icons.public, color: AppColors.gray, size: 36),
                          onTap: () {
                            final uri = Uri.tryParse(contact.website);
                            if (uri != null) {
                              launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                        const SizedBox(width: 30),
                        _SquareIconButton(
                          tooltip: contact.email,
                          icon: const Text(
                            '@',
                            style: TextStyle(
                              color: AppColors.gray,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
            const Padding(
              padding: EdgeInsets.only(bottom: 15),
              child: Column(
                children: [
                  Text(
                    'Cellule Business Intelligence',
                    style: TextStyle(color: AppColors.tint, fontSize: 13),
                  ),
                  SizedBox(height: 2),
                  _Copyright(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Copyright extends StatelessWidget {
  const _Copyright();

  @override
  Widget build(BuildContext context) => Text(
    '© ${DateTime.now().year} GSH',
    style: const TextStyle(color: AppColors.tint, fontSize: 13),
  );
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final Widget icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 70,
        height: 70,
        padding: const EdgeInsets.all(5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.gray, width: 2),
          borderRadius: BorderRadius.circular(15),
        ),
        child: icon,
      ),
    ),
  );
}
