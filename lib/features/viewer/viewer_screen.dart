import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../core/storage/session_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common.dart';
import '../../data/models/catalog.dart';
import '../../data/models/user.dart';
import '../../data/repositories/cbi_repository.dart';
import '../auth/session_controller.dart';
import '../reports/catalog_controller.dart';
import 'ntlm_auth.dart';

enum _ViewerStatus { opening, ready, noAccess, networkError }

/// Legacy RapportActivity: the Power BI report from PBIRS in a WebView.
///
/// * `POST reports/<id>/open/` → `embed_url`, loaded directly.
/// * NTLM challenges are answered only for `catalog.servers[].host`
///   (see [NtlmChallengeTracker]); any other host is cancelled.
/// * `POST reports/<id>/close/` with the viewing time on exit (the stopwatch
///   is paused while the app is in the background).
/// * The only screen allowed to rotate to landscape.
class ViewerScreen extends ConsumerStatefulWidget {
  const ViewerScreen({super.key, required this.report});

  final Report report;

  @override
  ConsumerState<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends ConsumerState<ViewerScreen> {
  static const noAccessMessage = "Vous n'avez pas accès à ce rapport.";

  late final CbiRepository _repo;
  late final SessionStore _store;
  late final bool _demo;
  late final AppLifecycleListener _lifecycle;
  final _stopwatch = Stopwatch();

  _ViewerStatus _status = _ViewerStatus.opening;
  String _errorMessage = ErrorMessages.network;
  bool _pageLoading = false;
  ReportOpening? _opening;
  WebViewController? _controller;
  NtlmChallengeTracker? _tracker;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(repositoryProvider);
    _store = ref.read(sessionStoreProvider);
    _demo = ref.read(appConfigProvider).demoMode;
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    _open();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _closeView();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _onLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_opening != null) _stopwatch.start();
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _stopwatch.stop();
    }
  }

  /// Records the consultation time (fire-and-forget).
  void _closeView() {
    final opening = _opening;
    if (opening == null) return;
    _opening = null;
    _stopwatch.stop();
    final seconds = _stopwatch.elapsed.inSeconds;
    _stopwatch.reset();
    unawaited(
      _repo
          .closeReport(
            widget.report.id,
            viewId: opening.viewId,
            durationSeconds: seconds,
          )
          .catchError((Object _) {}),
    );
  }

  Future<void> _open() async {
    _closeView();
    setState(() => _status = _ViewerStatus.opening);
    try {
      final opening = await _repo.openReport(widget.report.id);
      if (!mounted) {
        _opening = opening;
        _closeView();
        return;
      }
      _opening = opening;
      _stopwatch
        ..reset()
        ..start();
      final hosts = <String>{
        ...?ref.read(catalogProvider).value?.serverHosts,
        if (opening.server != null && opening.server!.host.isNotEmpty)
          opening.server!.host,
      };
      _tracker = NtlmChallengeTracker(hosts);
      final url = opening.embedUrl.isNotEmpty
          ? opening.embedUrl
          : widget.report.embedUrl;
      _load(url);
      setState(() => _status = _ViewerStatus.ready);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = e.isForbidden || e.isNotFound
            ? _ViewerStatus.noAccess
            : _ViewerStatus.networkError;
        _errorMessage = errorMessage(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _ViewerStatus.networkError;
        _errorMessage = errorMessage(e);
      });
    }
  }

  void _load(String url) {
    // JavaScript on; DOM storage is enabled by default by the Android
    // WebView implementation of webview_flutter.
    final controller = _controller ??= WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => _setPageLoading(true),
          onPageFinished: (_) => _setPageLoading(false),
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? true) {
              if (!mounted) return;
              setState(() {
                _pageLoading = false;
                _status = _ViewerStatus.networkError;
                _errorMessage = ErrorMessages.network;
              });
            }
          },
          onHttpAuthRequest: _onHttpAuthRequest,
        ),
      );
    _pageLoading = true;
    final uri = Uri.tryParse(url);
    if (_demo || uri == null || !uri.hasScheme) {
      controller.loadHtmlString(_demoHtml(widget.report));
    } else {
      controller.loadRequest(uri);
    }
  }

  void _setPageLoading(bool value) {
    if (mounted && _pageLoading != value) setState(() => _pageLoading = value);
  }

  Future<void> _onHttpAuthRequest(HttpAuthRequest request) async {
    final tracker = _tracker;
    final session = await _store.read();
    final credentials =
        session?.credentials ??
        ref.read(sessionProvider).credentials ??
        const PbiCredentials(domain: '', username: '');
    final password = session?.password ?? '';
    final decision =
        tracker?.next(
          request.host,
          hasStoredPassword:
              password.isNotEmpty && credentials.username.isNotEmpty,
        ) ??
        HttpAuthDecision.cancel;

    switch (decision) {
      case HttpAuthDecision.cancel:
        request.onCancel();
      case HttpAuthDecision.useStoredCredentials:
        request.onProceed(
          WebViewCredential(user: credentials.ntlmUser, password: password),
        );
      case HttpAuthDecision.askUser:
        if (!mounted) return request.onCancel();
        final result = await showPbiCredentialsDialog(
          context,
          host: request.host,
          initialUser: credentials.ntlmUser,
        );
        if (result == null) {
          request.onCancel();
          if (mounted) setState(() => _status = _ViewerStatus.noAccess);
          return;
        }
        await ref
            .read(sessionProvider.notifier)
            .updatePbiLogin(PbiCredentials.parse(result.user), result.password);
        request.onProceed(
          WebViewCredential(
            user: PbiCredentials.parse(result.user).ntlmUser,
            password: result.password,
          ),
        );
    }
  }

  void _refresh() {
    final controller = _controller;
    if (_status == _ViewerStatus.ready && controller != null) {
      _tracker?.reset();
      controller.reload();
    } else {
      _open();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (_status) {
      _ViewerStatus.opening => const _BigSpinner(),
      _ViewerStatus.noAccess => const _CenteredMessage(noAccessMessage),
      _ViewerStatus.networkError => Padding(
        padding: const EdgeInsets.only(top: 200),
        child: Align(
          alignment: Alignment.topCenter,
          child: RetryMessage(message: _errorMessage, onRetry: _open),
        ),
      ),
      _ViewerStatus.ready => Stack(
        children: [
          if (_controller != null) WebViewWidget(controller: _controller!),
          if (_pageLoading) const _BigSpinner(),
        ],
      ),
    };
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: widget.report.name,
              height: 45,
              action: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  tooltip: 'Actualiser',
                  padding: EdgeInsets.zero,
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh, color: AppColors.blueGreen),
                ),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _BigSpinner extends StatelessWidget {
  const _BigSpinner();

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(width: 100, height: 100, child: CircularProgressIndicator()),
  );
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 200, left: 20, right: 20),
    child: Align(
      alignment: Alignment.topCenter,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.tint, fontSize: 18),
      ),
    ),
  );
}

/// French prompt shown when PBIRS rejects the stored password.
Future<({String user, String password})?> showPbiCredentialsDialog(
  BuildContext context, {
  required String host,
  required String initialUser,
}) async {
  final user = TextEditingController(text: initialUser);
  final password = TextEditingController();
  String? error;
  final result = await showDialog<({String user, String password})>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: AppColors.sheet,
        title: const Text(
          'Authentification Power BI',
          style: TextStyle(color: AppColors.black, fontSize: 19),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Le serveur $host refuse votre mot de passe. '
                'Saisissez votre mot de passe Windows pour continuer.',
                style: const TextStyle(color: AppColors.black, fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: user,
                style: const TextStyle(color: AppColors.black),
                decoration: const InputDecoration(
                  labelText: 'Utilisateur',
                  helperText: r'DOMAINE\utilisateur',
                ),
              ),
              TextField(
                controller: password,
                autofocus: true,
                obscureText: true,
                style: const TextStyle(color: AppColors.black),
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  errorText: error,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Annuler',
              style: TextStyle(color: AppColors.blueGreen),
            ),
          ),
          TextButton(
            onPressed: () {
              if (user.text.trim().isEmpty || password.text.isEmpty) {
                setState(() => error = 'Mot de passe obligatoire');
                return;
              }
              Navigator.pop(context, (
                user: user.text.trim(),
                password: password.text,
              ));
            },
            child: const Text(
              'Valider',
              style: TextStyle(color: AppColors.blueGreen),
            ),
          ),
        ],
      ),
    ),
  );
  user.dispose();
  password.dispose();
  return result;
}

String _demoHtml(Report report) =>
    '''
<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{background:#1C1D22;color:#F2F2F2;font-family:sans-serif;display:flex;
align-items:center;justify-content:center;height:90vh;text-align:center}
h1{color:#A5CF4B;font-size:22px}p{color:#ABABAB}</style></head>
<body><div><h1>${const HtmlEscape().convert(report.name)}</h1>
<p>${const HtmlEscape().convert(report.location)}</p>
<p>Mode démonstration : le rapport Power BI s'affiche ici.</p></div></body></html>''';
