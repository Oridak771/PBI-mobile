import 'package:flutter/material.dart';

import '../layout/adaptive.dart';
import '../theme/app_dimens.dart';
import '../theme/app_palette.dart';
import 'glass.dart';

/// Full-screen form (ticket creation): title with a round glass close "X",
/// glass fields, blurred bottom bar with the green gradient submit button.
class FormPageScaffold extends StatelessWidget {
  const FormPageScaffold({
    super.key,
    required this.title,
    required this.children,
    required this.submitLabel,
    required this.onSubmit,
    this.busy = false,
  });

  final String title;
  final List<Widget> children;
  final String submitLabel;
  final VoidCallback? onSubmit;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GlassScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppDimens.screenHeaderHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.page + 2,
                  6,
                  AppDimens.page,
                  6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    GlassIconButton(
                      tooltip: 'Fermer',
                      size: 40,
                      icon: Icons.close_rounded,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
            ),
            // The Scaffold resizes above the keyboard; the focused field is
            // scrolled into view.
            Expanded(
              child: CenteredContent(
                builder: (context, gutter) => ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    8,
                    gutter,
                    AppDimens.page,
                  ),
                  children: children,
                ),
              ),
            ),
            GlassBottomBar(
              child: ContentWidth(
                child: SubmitButton(
                  label: submitLabel,
                  busy: busy,
                  onPressed: onSubmit,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Blurred glass bar pinned at the bottom (form submit, ticket composer).
class GlassBottomBar extends StatelessWidget {
  const GlassBottomBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppDimens.page,
      12,
      AppDimens.page,
      12,
    ),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => GlassPanel(
    blur: true,
    shadow: false,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    child: SafeArea(
      top: false,
      child: Padding(padding: padding, child: child),
    ),
  );
}

/// Full-width primary button (green gradient) with an inline spinner while
/// [busy].
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => GradientButton(
    label: label,
    busy: busy,
    onPressed: onPressed,
  );
}

/// Small label above a glass field.
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              label,
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
