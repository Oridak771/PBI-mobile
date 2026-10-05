import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/assets.dart';
import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../core/security/biometric_auth.dart';
import '../../core/storage/remembered_credentials_store.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/asset_slots.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_page.dart';
import '../lock/app_lock_controller.dart';
import '../lock/lock_screen.dart';
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
  bool _obscure = true;
  String? _usernameError;
  String? _passwordError;

  /// "Se souvenir de moi" (on by default).
  bool _remember = true;

  /// Credentials saved by a previous "Se souvenir de moi" login.
  RememberedCredentials? _saved;

  /// The password field holds the remembered password (untouched): it can't
  /// be revealed with the eye button.
  bool _passwordFromVault = false;

  /// The silent re-login was refused: the AD password changed.
  late final bool _passwordChanged;

  @override
  void initState() {
    super.initState();
    _passwordChanged = ref.read(sessionProvider).passwordChanged;
    ref.read(appLockProvider.notifier).load();
    _prefill();
  }

  /// Remembered credentials first, else the last username (legacy app).
  Future<void> _prefill() async {
    RememberedCredentials? saved;
    try {
      saved = await ref.read(rememberedCredentialsStoreProvider).read();
    } catch (_) {
      saved = null;
    }
    final last = saved == null
        ? await ref.read(sessionStoreProvider).lastUsername()
        : null;
    if (!mounted) return;
    setState(() {
      _saved = saved;
      if (_username.text.isEmpty) {
        final username = saved?.username ?? last;
        if (username != null) _username.text = username;
      }
      if (saved != null && saved.hasPassword && _password.text.isEmpty) {
        _password.text = saved.password!;
        _passwordFromVault = true;
        _obscure = true;
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
    await _login(username, password, remember: _remember);
  }

  /// "Connexion par empreinte": prompt, then login with the saved
  /// credentials.
  Future<void> _biometricLogin() async {
    final saved = _saved;
    if (_busy || saved == null || !saved.hasPassword) return;
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(appLockProvider.notifier)
        .authenticate(LockPrompts.login);
    if (!ok || !mounted) return;
    await _login(saved.username, saved.password!, remember: true);
  }

  Future<void> _login(
    String username,
    String password, {
    required bool remember,
  }) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(sessionProvider.notifier)
          .login(username: username, password: password, remember: remember);
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final offer = await ref
          .read(appLockProvider.notifier)
          .shouldOfferEnrolment();
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const ShellScreen()),
        (_) => false,
      );
      final overlay = navigator.overlay?.context;
      if (offer && overlay != null && overlay.mounted) {
        await showEnableLockSheet(overlay);
      }
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

  /// Remembered password + lock enabled + fingerprint / PIN available.
  bool get _showBiometricLogin =>
      (_saved?.hasPassword ?? false) &&
      ref.watch(appLockProvider.select((s) => s.enabled)) &&
      (ref.watch(biometricStatusProvider).value?.isAvailable ?? false);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Portail BI brand logo (dark lettering in light mode).
                        SizedBox(
                          height: 72,
                          child: LogoSlot(
                            asset: AppAssets.loginLogo(brightness),
                            fallbackText: 'GSH',
                            fontSize: 56,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          'Accéder à votre session.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: palette.text,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (_passwordChanged) ...[
                          const _Banner(ErrorMessages.passwordChanged),
                          const SizedBox(height: 16),
                        ],
                        _LoginField(
                          key: const Key('login-username'),
                          controller: _username,
                          hint: 'Email | AD 2000',
                          icon: Icons.person_outline_rounded,
                          error: _usernameError,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) {
                            if (_usernameError != null) {
                              setState(() => _usernameError = null);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        _LoginField(
                          key: const Key('login-password'),
                          controller: _password,
                          hint: 'Mot de Passe',
                          icon: Icons.lock_outline_rounded,
                          error: _passwordError,
                          obscure: _obscure,
                          password: true,
                          onToggleObscure: _passwordFromVault
                              ? null
                              : () => setState(() => _obscure = !_obscure),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          onChanged: (_) {
                            if (_passwordError != null || _passwordFromVault) {
                              setState(() {
                                _passwordError = null;
                                _passwordFromVault = false;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 6),
                        _RememberMe(
                          value: _remember,
                          onChanged: (v) => setState(() => _remember = v),
                        ),
                        const SizedBox(height: 14),
                        SubmitButton(
                          key: const Key('login-submit'),
                          label: 'CONNEXION',
                          busy: _busy,
                          onPressed: _submit,
                        ),
                        if (_showBiometricLogin) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              key: const Key('login-biometric'),
                              onPressed: _busy ? null : _biometricLogin,
                              icon: const Icon(Icons.fingerprint_rounded),
                              label: const Text('Connexion par empreinte'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Footer logo (legacy Cellule BI), only once one is chosen.
            if (AppAssets.footerLogo != null)
              SizedBox(
                height: 56,
                child: LogoSlot(
                  asset: AppAssets.footerLogo,
                  fallbackText: 'CBI',
                  fontSize: 24,
                  color: palette.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.error,
    this.obscure = false,
    this.password = false,
    this.onToggleObscure,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String? error;
  final bool obscure;
  final bool password;
  final VoidCallback? onToggleObscure;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return TextField(
      controller: controller,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: !password,
      maxLines: 1,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      keyboardType: password
          ? TextInputType.visiblePassword
          : TextInputType.emailAddress,
      style: TextStyle(color: palette.text, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        errorText: error,
        prefixIcon: Icon(icon),
        suffixIcon: password && onToggleObscure != null
            ? IconButton(
                tooltip: obscure
                    ? 'Afficher le mot de passe'
                    : 'Masquer le mot de passe',
                onPressed: onToggleObscure,
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              )
            : null,
      ),
    );
  }
}

/// "Se souvenir de moi" checkbox, under the password.
class _RememberMe extends StatelessWidget {
  const _RememberMe({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        key: const Key('login-remember'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 2, 10, 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
              ),
              Flexible(
                child: Text(
                  'Se souvenir de moi',
                  style: TextStyle(color: palette.text, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline notice above the fields (password changed).
class _Banner extends StatelessWidget {
  const _Banner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      key: const Key('login-banner'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimens.radiusControl),
        border: Border.all(color: palette.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: palette.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: palette.text, fontSize: 14, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
