import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/remote_config.dart';
import '../about/about_screen.dart';
import '../auth/session_controller.dart';
import '../history/history_screen.dart';
import '../tickets/ticket_create_screen.dart';
import '../tickets/tickets_screen.dart';

/// "Paramètre" tab (legacy fragment_parametre.xml).
class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider.select((s) => s.user));
    void push(Widget screen) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));

    return Stack(
      children: [
        Positioned.fill(
          top: AppDimens.middle,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: AppColors.sheet,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, AppDimens.middle, 5, 5),
                  child: Text(
                    user?.name ?? '',
                    style: const TextStyle(
                      color: AppColors.black,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      shadows: AppShadows.dark223,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 5, 5),
                  child: Text(
                    user?.description ?? '',
                    style: const TextStyle(
                      color: AppColors.black,
                      fontSize: 18,
                      shadows: AppShadows.dark223,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SettingsEntry(
                            'Historique',
                            onTap: () => push(const HistoryScreen()),
                          ),
                          SettingsEntry(
                            'Mes demandes',
                            onTap: () => push(const TicketsScreen()),
                          ),
                          SettingsEntry(
                            'À propos',
                            onTap: () => push(const AboutScreen()),
                          ),
                          SettingsEntry(
                            'Aide',
                            onTap: () async {
                              final config = await ref.read(
                                remoteConfigProvider.future,
                              );
                              if (context.mounted) {
                                showHelpDialog(context, config.contact);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: () => confirmLogout(context, ref),
                    child: const Text(
                      'Se déconnecter',
                      style: TextStyle(
                        color: AppColors.black,
                        fontSize: 16,
                        shadows: AppShadows.dark223,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 20,
          child: UserAvatar(
            size: 80,
            photoUrl: user?.photoUrl,
            initials: user?.initials ?? '',
            color: user?.avatarColor,
          ),
        ),
      ],
    );
  }
}

/// Underlined menu entry (legacy EditText with `#D2D2D2` underline).
class SettingsEntry extends StatelessWidget {
  const SettingsEntry(this.text, {super.key, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.tint, width: 2)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.black,
          fontSize: 18,
          shadows: AppShadows.dark223,
        ),
      ),
    ),
  );
}

Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.sheet,
      icon: const Icon(Icons.warning_amber_rounded, color: AppColors.yellow),
      title: const Text(
        'Déconnexion',
        style: TextStyle(color: AppColors.black),
      ),
      content: const Text(
        'Voulez-vous vraiment vous déconnecter?',
        style: TextStyle(color: AppColors.black),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            'Annuler',
            style: TextStyle(color: AppColors.blueGreen),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'Se déconnecter',
            style: TextStyle(color: AppColors.blueGreen),
          ),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    // Navigation back to the login screen is handled by CbiApp.
    await ref.read(sessionProvider.notifier).logout();
  }
}

/// Legacy "Aide" dialog ("Contactez-nous").
Future<void> showHelpDialog(BuildContext context, Contact contact) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.sheet,
        title: const Text(
          'Contactez-nous',
          style: TextStyle(color: AppColors.black),
        ),
        contentPadding: const EdgeInsets.only(top: 10, bottom: 10),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ContactRow(
              icon: Icons.email,
              text: contact.email,
              onTap: () => launchUrl(Uri(scheme: 'mailto', path: contact.email)),
            ),
            _ContactRow(
              icon: Icons.public,
              text: contact.websiteLabel,
              onTap: () {
                final uri = Uri.tryParse(contact.website);
                if (uri != null) {
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TicketCreateScreen(),
                ),
              );
            },
            child: const Text(
              'Envoyer une demande',
              style: TextStyle(color: AppColors.blueGreen),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Ok',
              style: TextStyle(color: AppColors.blueGreen),
            ),
          ),
        ],
      ),
    );

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.black),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.black, fontSize: 16),
            ),
          ),
        ],
      ),
    ),
  );
}
