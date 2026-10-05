import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/layout/adaptive.dart';
import '../../core/providers.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/theme_mode_controller.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/remote_config.dart';
import '../about/about_screen.dart';
import '../auth/session_controller.dart';
import '../history/history_screen.dart';
import '../shell/shell_header.dart';
import '../tickets/ticket_create_screen.dart';
import 'security_settings.dart';
import '../../core/widgets/glass.dart';

/// "Profil" tab (former "Paramètre"): profile card, Activité, Sécurité,
/// Apparence, Assistance, logout.
class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider.select((s) => s.user));
    final palette = context.palette;
    void push(Widget screen) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));

    final profile = AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          UserAvatar(
            size: 60,
            brand: true,
            photoUrl: user?.photoUrl,
            initials: user?.initials ?? '',
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                if ((user?.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    user!.description,
                    style: TextStyle(color: palette.textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    final activityAndSecurity = <Widget>[
      const SectionHeader('Activité', padding: _sectionPadding),
      SettingsGroup(
        children: [
          SettingsEntry(
            'Historique',
            icon: Icons.history_rounded,
            onTap: () => push(const HistoryScreen()),
          ),
        ],
      ),
      const SectionHeader('Sécurité', padding: _sectionPadding),
      const SecuritySettings(),
    ];
    final appearanceAndHelp = <Widget>[
      const SectionHeader('Apparence', padding: _sectionPadding),
      const AppearanceSelector(),
      const SectionHeader('Assistance', padding: _sectionPadding),
      SettingsGroup(
        children: [
          SettingsEntry(
            'À propos',
            icon: Icons.info_outline_rounded,
            onTap: () => push(const AboutScreen()),
          ),
          SettingsEntry(
            'Aide',
            icon: Icons.help_outline_rounded,
            onTap: () async {
              final config = await ref.read(remoteConfigProvider.future);
              if (context.mounted) showHelpDialog(context, config.contact);
            },
          ),
        ],
      ),
      const SizedBox(height: 28),
      OutlinedButton.icon(
        key: const Key('logout-button'),
        onPressed: () => confirmLogout(context, ref),
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.danger,
          backgroundColor: palette.danger.withValues(alpha: 0.1),
          minimumSize: const Size(64, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
          side: BorderSide(color: palette.danger.withValues(alpha: 0.45)),
        ),
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Se déconnecter'),
      ),
    ];

    final bottom = BottomBarInset.of(context);
    final list = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (WindowSize.of(width).isExpanded) {
          // Expanded: the groups in two columns under the profile card.
          final gutter = math.max(AppDimens.page + 8, (width - 1100) / 2);
          return ListView(
            padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 32 + bottom),
            children: [
              profile,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: activityAndSecurity,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: appearanceAndHelp,
                    ),
                  ),
                ],
              ),
            ],
          );
        }
        final gutter = AdaptiveDimens.gutter(width);
        return ListView(
          padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 32 + bottom),
          children: [profile, ...activityAndSecurity, ...appearanceAndHelp],
        );
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ShellHeader(title: 'Profil'),
        Expanded(child: list),
      ],
    );
  }

  static const _sectionPadding = EdgeInsets.fromLTRB(4, 22, 2, 8);
}

/// "Apparence": Système / Clair / Sombre, applied instantly and persisted.
class AppearanceSelector extends ConsumerWidget {
  const AppearanceSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return GlassSegmentedBar<ThemeMode>(
      key: const Key('appearance-selector'),
      expand: true,
      segments: const [
        GlassSegment(ThemeMode.system, 'Système'),
        GlassSegment(ThemeMode.light, 'Clair'),
        GlassSegment(ThemeMode.dark, 'Sombre'),
      ],
      selected: {mode},
      onChanged: ref.read(themeModeProvider.notifier).set,
    );
  }
}

/// Glass panel holding settings entries separated by 1px dividers.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      GlassListPanel(indent: 62, children: children);
}

/// Settings entry: icon well, label, chevron.
class SettingsEntry extends StatelessWidget {
  const SettingsEntry(
    this.text, {
    super.key,
    required this.onTap,
    this.icon = Icons.chevron_right_rounded,
  });

  final String text;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              IconWell(icon, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.textSubtle),
            ],
          ),
        ),
      ),
    );
  }
}

/// Settings entry with a switch (icon well, label, optional subtitle).
class SettingsSwitchEntry extends StatelessWidget {
  const SettingsSwitchEntry(
    this.text, {
    super.key,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String text;
  final IconData icon;
  final String? subtitle;
  final bool value;

  /// `null`: disabled.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onChanged != null;
    return InkWell(
      onTap: enabled ? () => onChanged!(!value) : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              IconWell(
                icon,
                size: 36,
                color: enabled ? null : palette.textSubtle,
                background: enabled ? null : palette.glassSelected,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: TextStyle(
                        color: enabled ? palette.text : palette.textSubtle,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(color: palette.textMuted, fontSize: 11.5),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

/// Settings entry showing the current value on the right (opens a picker).
class SettingsValueEntry extends StatelessWidget {
  const SettingsValueEntry(
    this.text, {
    super.key,
    required this.icon,
    required this.value,
    required this.onTap,
  });

  final String text;
  final IconData icon;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              IconWell(icon, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: palette.textSubtle),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
  final palette = context.palette;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.logout_rounded, color: palette.danger),
      title: const Text('Déconnexion'),
      content: const Text('Voulez-vous vraiment vous déconnecter?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(foregroundColor: palette.textMuted),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: palette.danger,
            foregroundColor: Colors.white,
            minimumSize: const Size(64, 40),
          ),
          child: const Text('Se déconnecter'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    // Navigation back to the login screen is handled by CbiApp.
    await ref.read(sessionProvider.notifier).logout();
  }
}

/// "Aide" bottom sheet ("Contactez-nous").
Future<void> showHelpDialog(BuildContext context, Contact contact) =>
    showGlassSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final palette = sheetContext.palette;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.page,
              0,
              AppDimens.page,
              AppDimens.page,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Contactez-nous',
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                SettingsGroup(
                  children: [
                    _ContactRow(
                      icon: Icons.mail_outline_rounded,
                      text: contact.email,
                      onTap: () =>
                          launchUrl(Uri(scheme: 'mailto', path: contact.email)),
                    ),
                    _ContactRow(
                      icon: Icons.public_rounded,
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
                const SizedBox(height: 20),
                GradientButton(
                  label: 'Envoyer une demande',
                  icon: Icons.edit_note_rounded,
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        fullscreenDialog: true,
                        builder: (_) => const TicketCreateScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Ok'),
                ),
              ],
            ),
          ),
        );
      },
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
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            IconWell(icon, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: palette.text, fontSize: 15),
              ),
            ),
            Icon(Icons.open_in_new_rounded, size: 18, color: palette.textSubtle),
          ],
        ),
      ),
    );
  }
}
