import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/assets.dart';
import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/asset_slots.dart';
import '../../core/widgets/common.dart';
import '../shell/shell_screen.dart';
import 'session_controller.dart';

/// Legacy AuthenticationAct (activity_main.xml).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _usernameError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    // Prefill the last username, like the legacy app.
    ref.read(sessionStoreProvider).lastUsername().then((value) {
      if (mounted && value != null && _username.text.isEmpty) {
        _username.text = value;
      }
    });
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final username = _username.text.trim();
    final password = _password.text;
    setState(() {
      _usernameError = username.isEmpty ? 'Username obligatoire' : null;
      _passwordError = password.isEmpty ? 'Mot de passe obligatoire' : null;
    });
    if (_usernameError != null || _passwordError != null) return;

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await ref
          .read(sessionProvider.notifier)
          .login(username: username, password: password);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const ShellScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      final error = loginErrorMessage(e);
      if (error.onPasswordField) {
        setState(() => _passwordError = error.message);
      } else {
        showToast(context, error.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.black,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight < 560
              ? 560.0
              : constraints.maxHeight;
          final middle = height / 2;
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: SizedBox(
              height: height,
              child: Stack(
                children: [
                  // Brand logo in the top half. The Portail BI logo is wide, so
                  // it gets less side margin than the legacy square GSH logo.
                  Positioned(
                    top: 20,
                    left: 30,
                    right: 30,
                    height: middle - 10 - 20,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 25),
                      child: LogoSlot(
                        asset: AppAssets.loginLogo,
                        fallbackText: 'GSH',
                        fontSize: 64,
                      ),
                    ),
                  ),
                  Positioned(
                    top: middle + 10,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        _LoginField(
                          key: const Key('login-username'),
                          controller: _username,
                          hint: 'Email | AD 2000',
                          error: _usernameError,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) {
                            if (_usernameError != null) {
                              setState(() => _usernameError = null);
                            }
                          },
                        ),
                        _LoginField(
                          key: const Key('login-password'),
                          controller: _password,
                          hint: 'Mot de Passe',
                          error: _passwordError,
                          obscure: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          onChanged: (_) {
                            if (_passwordError != null) {
                              setState(() => _passwordError = null);
                            }
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 20, bottom: 10),
                          child: _ConnexionButton(busy: _busy, onPressed: _submit),
                        ),
                      ],
                    ),
                  ),
                  // Footer logo (legacy Cellule BI), only once one is chosen.
                  if (AppAssets.footerLogo != null)
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 65,
                      child: LogoSlot(
                        asset: AppAssets.footerLogo,
                        fallbackText: 'CBI',
                        fontSize: 28,
                        color: AppColors.tint,
                      ),
                    ),
                  if (_busy)
                    const Center(
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    super.key,
    required this.controller,
    required this.hint,
    this.error,
    this.obscure = false,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final String? error;
  final bool obscure;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(15, 0, 15, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: error == null
                ? null
                : Border.all(color: AppColors.red, width: 1),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            autocorrect: false,
            enableSuggestions: !obscure,
            maxLines: 1,
            textAlign: TextAlign.center,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            onChanged: onChanged,
            keyboardType: obscure ? TextInputType.visiblePassword : TextInputType.text,
            style: const TextStyle(color: AppColors.gray, fontSize: 18),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.loginHint, fontSize: 18),
              border: InputBorder.none,
              isCollapsed: true,
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.red, fontSize: 13),
            ),
          ),
      ],
    ),
  );
}

class _ConnexionButton extends StatelessWidget {
  const _ConnexionButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.green,
    elevation: 10,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: busy ? null : onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 70, vertical: 12),
          child: Text(
            'CONNEXION',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: busy ? AppColors.disabledButtonText : AppColors.black,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    ),
  );
}
