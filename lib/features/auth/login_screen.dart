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
import '../../core/widgets/glass.dart';
import '../lock/app_lock_controller.dart';
import '../lock/lock_screen.dart';
import '../shell/shell_screen.dart';
import 'session_controller.dart';

/// Login (legacy AuthenticationAct): Portail BI logo, glass panel with the
/// fields, "Se souvenir de moi", "Se connecter" and the fingerprint button.
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
    return GlassScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(18, 32, 18, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Full Portail BI logo (light lettering in dark mode).
                        Center(
                          child: SizedBox(
                            width: 220,
                            height: 64,
                            child: LogoSlot(
                              asset: AppAssets.loginLogo(brightness),
                              fallbackText: 'PBI',
                              fontSize: 44,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Vos tableaux de bord, partout',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 30),
                        if (_passwordChanged) ...[
                          const _Banner(ErrorMessages.passwordChanged),
                          const SizedBox(height: 14),
                        ],
                        GlassPanel(
                          key: const Key('login-panel'),
                          blur: true,
                          borderRadius: BorderRadius.circular(28),
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
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
                              const SizedBox(height: 10),
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
                                  if (_passwordError != null ||
                                      _passwordFromVault) {
                                    setState(() {
                                      _passwordError = null;
                                      _passwordFromVault = false;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 10),
                              _RememberMe(
                                value: _remember,
                                onChanged: (v) => setState(() => _remember = v),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: SubmitButton(
                                      key: const Key('login-submit'),
                                      label: 'Se connecter',
                                      busy: _busy,
                                      onPressed: _submit,
                                    ),
                                  ),
                                  if (_showBiometricLogin) ...[
                                    const SizedBox(width: 10),
                                    GlassPanel(
                                      borderRadius: BorderRadius.circular(17),
                                      width: 50,
                                      height: 50,
                                      child: Material(
                                        type: MaterialType.transparency,
                                        child: IconButton(
                                          key: const Key('login-biometric'),
                                          tooltip: 'Connexion par empreinte',
                                          onPressed: _busy
                                              ? null
                                              : _biometricLogin,
                                          icon: Icon(
                                            Icons.fingerprint_rounded,
                                            size: 26,
                                            color: palette.primaryText,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 18, top: 8),
              child: Text(
                'Cellule Business Intelligence · GSH',
                key: const Key('login-footer'),
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textMuted, fontSize: 11),
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
      obscuringCharacter: '•',
      autocorrect: false,
      enableSuggestions: !password,
      maxLines: 1,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      keyboardType: password
          ? TextInputType.visiblePassword
          : TextInputType.emailAddress,
      style: TextStyle(
        color: palette.text,
        fontSize: 13.5,
        letterSpacing: password && obscure ? 3 : null,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: palette.textMuted,
          fontSize: 13.5,
          letterSpacing: 0,
        ),
        errorText: error,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        prefixIcon: Icon(icon, size: 19),
        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 46),
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
                  size: 19,
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
          padding: const EdgeInsets.fromLTRB(2, 4, 10, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: Checkbox(
                  value: value,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  onChanged: (v) => onChanged(v ?? false),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Se souvenir de moi',
                  style: TextStyle(color: palette.textMuted, fontSize: 12),
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
    return GlassPanel(
      key: const Key('login-banner'),
      fill: palette.danger.withValues(alpha: 0.12),
      borderColor: palette.danger.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(AppDimens.radiusControl),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: palette.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: palette.text, fontSize: 13.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
