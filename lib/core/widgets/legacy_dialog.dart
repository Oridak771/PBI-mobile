import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Legacy full-screen dialog style (history filter, ticket creation):
/// `#F1F1F1` background, 50px `#2F3139` top bar with centred title and a close
/// "X", full-width 50px submit button.
class LegacyDialogScaffold extends StatelessWidget {
  const LegacyDialogScaffold({
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.sheet,
    body: SafeArea(
      child: Column(
        children: [
          Container(
            height: 50,
            color: AppColors.surface,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.dialogText,
                    fontSize: 19,
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close, color: AppColors.dialogText),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: children,
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: TextButton(
              onPressed: busy ? null : onSubmit,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.surface,
                shape: const RoundedRectangleBorder(),
              ),
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      submitLabel,
                      style: const TextStyle(
                        color: AppColors.dialogText,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Label (margin start 25) + field (margin 20) of the legacy dialogs.
class LegacyField extends StatelessWidget {
  const LegacyField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 25, top: 10),
        child: Text(
          label,
          style: const TextStyle(color: AppColors.black, fontSize: 16),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: child,
      ),
    ],
  );
}

/// Underlined text field of the legacy dialogs.
InputDecoration legacyInputDecoration({String? hint, String? error}) =>
    InputDecoration(
      hintText: hint,
      errorText: error,
      isDense: true,
      hintStyle: const TextStyle(color: AppColors.greyText),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.tint),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.blueGreen, width: 2),
      ),
    );

const legacyFieldTextStyle = TextStyle(color: AppColors.black, fontSize: 16);
