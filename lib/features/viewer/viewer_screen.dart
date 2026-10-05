import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/layout/adaptive.dart';
import '../../core/providers.dart';
import '../../core/storage/session_store.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/common.dart';
import '../../data/models/catalog.dart';
import '../../data/models/mobile_layout.dart';
import '../../data/models/user.dart';
import '../../data/repositories/cbi_repository.dart';
import '../auth/session_controller.dart';
import '../reports/catalog_controller.dart';
import 'mobile_layout_support.dart';
import 'ntlm_auth.dart';
import 'viewer_variant.dart';

enum _ViewerStatus { opening, ready, noAccess, networkError }

/// One page load of the WebView (a new WebView per load: the user scripts are
/// fixed at creation).
class _PageLoad {
  const _PageLoad({
    required this.id,
    required this.target,
    required this.source,
    required this.scripts,
    this.html,
  });

  final int id;
  final ViewerTarget target;
  final LayoutSource source;
  final List<UserScript> scripts;

  /// Demo mode / invalid URL: local placeholder instead of [target] URL.
  final String? html;
}

/// Legacy RapportActivity: the Power BI report from PBIRS in a WebView
/// (`flutter_inappwebview`).
///
/// * `POST reports/<id>/open/` once → `embed_url` (and `report.phone`);
///   `GET reports/<id>/mobile-layout/` in parallel (cached per report for the
///   app session, see [MobileLayoutCache]).
/// * Linked phone edition: portrait shows `phone.embed_url`, landscape the
///   full report. Otherwise portrait shows the full report with its Power BI
///   mobile layout (user scripts injected at document start in every frame,
///   see `mobile_layout_support.dart`), landscape the desktop layout (no
///   scripts). Rotating re-creates the page with the right scripts; the
///   first portrait load waits at most ~6 s for the backend map, then falls
///   back to the script alone. "Mobile" / "Bureau" switches manually for this
///   session ([selectReportVariant]). Switching never calls `open/` again.
/// * NTLM challenges are answered only for `catalog.servers[].host`
///   (see [NtlmChallengeTracker]); any other host is cancelled.
/// * Full screen: immersive system UI, no toolbar, any orientation, floating
///   exit / rotate control.
/// * `POST reports/<id>/close/` once on exit, with the total viewing time
///   (the stopwatch is paused while the app is in the background).
/// * Long press on the title: hidden "Informations techniques" sheet.
/// * The only screen allowed to rotate; leaving it restores the app-wide
///   portrait lock and system UI.
class ViewerScreen extends ConsumerStatefulWidget {
  const ViewerScreen({super.key, required this.report});

  final Report report;

  @override
  ConsumerState<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends ConsumerState<ViewerScreen> {
  static const noAccessMessage = "Vous n'avez pas accès à ce rapport.";

  /// Orientation rules of the viewer outside full screen.
  static const _viewerOrientations = DeviceOrientation.values;

  late final CbiRepository _repo;
  late final SessionStore _store;
  late final bool _demo;
  late final AppLifecycleListener _lifecycle;
  final _stopwatch = Stopwatch();
  final _webKey = GlobalKey();

  _ViewerStatus _status = _ViewerStatus.opening;
  String _errorMessage = ErrorMessages.network;
  bool _pageLoading = false;
  ReportOpening? _opening;
  InAppWebViewController? _controller;
  NtlmChallengeTracker? _tracker;

  // Editions / layouts.
  String _fullUrl = '';
  PhoneEdition? _phone;
  ReportVariant? _manualVariant;
  MobileLayoutRequest? _layoutRequest;

  /// Target of the latest load (possibly still waiting for the layout).
  ViewerTarget? _wanted;

  /// Page on screen.
  _PageLoad? _page;
  int _loadCounter = 0;

  /// `WebViewFeature.DOCUMENT_START_SCRIPT` (null = unknown / not Android).
  bool? _documentStartSupported;

  // Full screen.
  bool _fullscreen = false;
  bool _controlsDimmed = false;
  Timer? _dimTimer;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(repositoryProvider);
    _store = ref.read(sessionStoreProvider);
    _demo = ref.read(appConfigProvider).demoMode;
    SystemChrome.setPreferredOrientations(_viewerOrientations);
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    _phone = widget.report.phone;
    unawaited(_checkDocumentStartSupport());
    _open();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Orientation change: mobile ↔ desktop (no open/ call).
    if (_status == _ViewerStatus.ready) _syncVariant();
  }

  @override
  void dispose() {
    _dimTimer?.cancel();
    _lifecycle.dispose();
    _closeView();
    // Back to the app-wide rules, whatever state the viewer was in.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Phones back to portrait, tablets keep rotating (app policy).
    AppOrientations.restore();
    super.dispose();
  }

  void _onLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_opening != null) _stopwatch.start();
      // Android may drop immersive mode while in the background.
      if (_fullscreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _stopwatch.stop();
    }
  }

  /// The mobile layout needs `WebViewCompat.addDocumentStartJavaScript`
  /// (Android System WebView with DOCUMENT_START_SCRIPT). Without it the
  /// plugin injects the scripts after the page has loaded: too late, the
  /// report simply stays in its desktop layout.
  Future<void> _checkDocumentStartSupport() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final supported = await WebViewFeature.isFeatureSupported(
        WebViewFeature.DOCUMENT_START_SCRIPT,
      );
      _documentStartSupported = supported;
      if (!supported) {
        debugPrint(
          '[viewer] WebViewFeature.DOCUMENT_START_SCRIPT non pris en charge : '
          'mettre à jour Android System WebView. La disposition mobile Power '
          'BI ne peut pas être appliquée (affichage bureau).',
        );
      }
    } catch (e) {
      debugPrint('[viewer] DOCUMENT_START_SCRIPT : vérification impossible ($e)');
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

  /// `mobile-layout/`, in parallel with `open/` (reused from the session
  /// cache; a failed request is retried by the next [_open]).
  void _startLayoutRequest() {
    final current = _layoutRequest;
    if (current != null && current.status != MobileLayoutStatus.failed) return;
    final request = _layoutRequest = MobileLayoutRequest(
      ref.read(mobileLayoutCacheProvider).fetch(widget.report.id),
    );
    // The toolbar toggle depends on `available`.
    request.done.then((_) {
      if (mounted && identical(_layoutRequest, request)) setState(() {});
    });
  }

  Future<void> _open() async {
    _closeView();
    _startLayoutRequest();
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
      _fullUrl = opening.embedUrl.isNotEmpty
          ? opening.embedUrl
          : widget.report.embedUrl;
      // The open response is authoritative (`phone` is null when the user
      // may not open the phone edition).
      _phone = opening.report != null
          ? opening.report!.phone
          : widget.report.phone;
      _tracker = NtlmChallengeTracker(
        viewerAllowedHosts(
          catalog: ref.read(catalogProvider).value,
          openedServer: opening.server,
          phone: _phone,
        ),
      );
      _wanted = null;
      _syncVariant();
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

  ViewerTarget _target() => resolveViewerTarget(
    orientation: MediaQuery.orientationOf(context),
    fullUrl: _fullUrl,
    phone: _phone,
    manual: _manualVariant,
  );

  bool get _hasPhoneEdition => (_phone?.embedUrl.trim() ?? '').isNotEmpty;

  /// Loads the page matching the orientation / manual choice when it is not
  /// the one on screen (or being prepared). Never calls `open/`.
  void _syncVariant() {
    final target = _target();
    final wanted = _wanted;
    if (wanted != null && wanted.mode == target.mode && wanted.url == target.url) {
      return;
    }
    _wanted = target;
    // New page: its first NTLM challenge must use the stored password again.
    _tracker?.reset();
    _pageLoading = true;
    unawaited(_load(target));
  }

  void _selectVariant(ReportVariant variant) {
    setState(() => _manualVariant = variant);
    _syncVariant();
  }

  /// Prepares the user scripts of [target] (waiting for the backend map at
  /// most what is left of the ~6 s budget), then re-creates the WebView.
  Future<void> _load(ViewerTarget target) async {
    final id = ++_loadCounter;
    final bundle = DefaultAssetBundle.of(context);
    var sources = const <String>[];
    MobileLayout? layout;
    if (target.injectsScripts) {
      layout = await (_layoutRequest?.wait() ?? Future<MobileLayout?>.value());
      try {
        sources = mobileLayoutScriptSources(
          assetSource: await loadMobileLayoutAsset(bundle),
          layout: layout,
        );
      } catch (e) {
        debugPrint('[viewer] $mobileLayoutAsset illisible ($e)');
      }
    } else {
      await Future<void>.value();
    }
    if (!mounted || id != _loadCounter) return; // superseded
    final palette = context.palette;
    final uri = Uri.tryParse(target.url);
    final local = _demo || uri == null || !uri.hasScheme;
    setState(() {
      _controller = null;
      _pageLoading = true;
      _page = _PageLoad(
        id: id,
        target: target,
        source: sources.isEmpty
            ? LayoutSource.none
            : layoutSourceFor(target.mode, layout),
        scripts: documentStartUserScripts(sources),
        html: local ? _demoHtml(widget.report, target.mode, palette) : null,
      );
    });
  }

  void _setPageLoading(int pageId, bool value) {
    if (!mounted || _page?.id != pageId) return;
    if (_pageLoading != value) setState(() => _pageLoading = value);
  }

  Future<HttpAuthResponse> _onHttpAuthRequest(String host) async {
    final tracker = _tracker;
    final session = await _store.read();
    final credentials =
        session?.credentials ??
        ref.read(sessionProvider).credentials ??
        const PbiCredentials(domain: '', username: '');
    final password = session?.password ?? '';
    final decision =
        tracker?.next(
          host,
          hasStoredPassword:
              password.isNotEmpty && credentials.username.isNotEmpty,
        ) ??
        HttpAuthDecision.cancel;

    switch (decision) {
      case HttpAuthDecision.cancel:
        return HttpAuthResponse(action: HttpAuthResponseAction.CANCEL);
      case HttpAuthDecision.useStoredCredentials:
        return HttpAuthResponse(
          username: credentials.ntlmUser,
          password: password,
          action: HttpAuthResponseAction.PROCEED,
        );
      case HttpAuthDecision.askUser:
        if (!mounted) {
          return HttpAuthResponse(action: HttpAuthResponseAction.CANCEL);
        }
        final result = await showPbiCredentialsDialog(
          context,
          host: host,
          initialUser: credentials.ntlmUser,
        );
        if (result == null) {
          if (mounted) setState(() => _status = _ViewerStatus.noAccess);
          return HttpAuthResponse(action: HttpAuthResponseAction.CANCEL);
        }
        await ref
            .read(sessionProvider.notifier)
            .updatePbiLogin(PbiCredentials.parse(result.user), result.password);
        return HttpAuthResponse(
          username: PbiCredentials.parse(result.user).ntlmUser,
          password: result.password,
          action: HttpAuthResponseAction.PROCEED,
        );
    }
  }

  void _refresh() {
    final page = _page;
    if (_status != _ViewerStatus.ready || page == null) {
      if (_status != _ViewerStatus.ready) _open();
      return;
    }
    _tracker?.reset();
    final controller = _controller;
    // The backend map arrived after the first load: re-create the page with it.
    final staleScripts =
        page.target.injectsScripts &&
        page.source != layoutSourceFor(page.target.mode, _layoutRequest?.layout);
    if (controller == null || staleScripts) {
      _wanted = null;
      _syncVariant();
      setState(() {});
    } else {
      controller.reload();
    }
  }

  // --- Technical info (hidden: long press on the title) -----------------

  Future<void> _showTechnicalInfo() async {
    String? stats;
    final controller = _controller;
    if (controller != null) {
      try {
        final result = await controller
            .evaluateJavascript(source: mobileLayoutStatsExpression)
            .timeout(const Duration(seconds: 2));
        stats = result?.toString();
      } catch (_) {}
    }
    if (!mounted) return;
    final page = _page;
    final lines = technicalInfoLines(
      mode: page?.target.mode ?? _target().mode,
      source: page?.source ?? LayoutSource.none,
      request: _layoutRequest,
      documentStartSupported: _documentStartSupported,
      jsStats: stats,
    );
    final palette = context.palette;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: palette.surface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.page,
            0,
            AppDimens.page,
            AppDimens.page,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Informations techniques',
                style: TextStyle(
                  color: palette.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                lines.join('\n'),
                key: const Key('viewer-technical-info'),
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Full screen -------------------------------------------------------

  Future<void> _enterFullscreen() async {
    setState(() {
      _fullscreen = true;
      _controlsDimmed = false;
    });
    _scheduleDim();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  Future<void> _exitFullscreen() async {
    _dimTimer?.cancel();
    if (mounted) setState(() => _fullscreen = false);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(_viewerOrientations);
  }

  /// Forces the other orientation (landscape ↔ portrait).
  void _rotate() {
    final portrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    SystemChrome.setPreferredOrientations(
      portrait
          ? const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : const [DeviceOrientation.portraitUp],
    );
    _wakeControls();
  }

  void _scheduleDim() {
    _dimTimer?.cancel();
    _dimTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _fullscreen) setState(() => _controlsDimmed = true);
    });
  }

  void _wakeControls() {
    if (_controlsDimmed) setState(() => _controlsDimmed = false);
    _scheduleDim();
  }

  // --- UI ----------------------------------------------------------------

  Widget _webView(_PageLoad page) {
    final id = page.id;
    final html = page.html;
    return InAppWebView(
      key: ValueKey(id),
      initialUrlRequest: html == null
          ? URLRequest(url: WebUri(page.target.url))
          : null,
      initialData: html == null ? null : InAppWebViewInitialData(data: html),
      initialUserScripts: UnmodifiableListView(page.scripts),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        // Mixed content: Android default (as before); cleartext HTTP is
        // allowed by network_security_config.xml.
        transparentBackground: true,
        supportZoom: true,
        builtInZoomControls: true,
        displayZoomControls: false,
        useWideViewPort: true,
        loadWithOverviewMode: true,
        isInspectable: !kReleaseMode,
      ),
      onWebViewCreated: (controller) {
        if (_page?.id == id) _controller = controller;
      },
      onLoadStart: (_, _) => _setPageLoading(id, true),
      onLoadStop: (_, _) => _setPageLoading(id, false),
      onReceivedError: (_, request, _) {
        if (!(request.isForMainFrame ?? true)) return;
        if (!mounted || _page?.id != id) return;
        setState(() {
          _pageLoading = false;
          _status = _ViewerStatus.networkError;
          _errorMessage = ErrorMessages.network;
        });
      },
      onReceivedHttpAuthRequest: (_, challenge) =>
          _onHttpAuthRequest(challenge.protectionSpace.host),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final page = _page;
    final Widget body = switch (_status) {
      _ViewerStatus.opening => const _BigSpinner(),
      _ViewerStatus.noAccess => const _CenteredMessage(
        noAccessMessage,
        icon: Icons.lock_outline_rounded,
      ),
      _ViewerStatus.networkError => Padding(
        padding: const EdgeInsets.only(top: 120),
        child: Align(
          alignment: Alignment.topCenter,
          child: RetryMessage(message: _errorMessage, onRetry: _open),
        ),
      ),
      _ViewerStatus.ready => ColoredBox(
        color: palette.background,
        child: Stack(
          children: [
            if (page != null) _webView(page),
            if (_pageLoading) const _BigSpinner(),
          ],
        ),
      ),
    };

    return PopScope(
      canPop: !_fullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _fullscreen) _exitFullscreen();
      },
      child: Scaffold(
        backgroundColor: palette.background,
        body: SafeArea(
          top: !_fullscreen,
          bottom: !_fullscreen,
          left: !_fullscreen,
          right: !_fullscreen,
          child: Stack(
            children: [
              Column(
                children: [
                  if (!_fullscreen) _toolbar(context),
                  Expanded(
                    child: KeyedSubtree(key: _webKey, child: body),
                  ),
                ],
              ),
              if (_fullscreen)
                _FullscreenControls(
                  dimmed: _controlsDimmed,
                  onWake: _wakeControls,
                  onExit: _exitFullscreen,
                  onRotate: _rotate,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    final palette = context.palette;
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final showToggle =
        _status == _ViewerStatus.ready &&
        showVariantToggle(
          hasPhoneEdition: _hasPhoneEdition,
          mobileLayoutAvailable: _layoutRequest?.available ?? false,
        );
    final toggle = showToggle
        ? _VariantToggle(
            selected: _wanted?.variant ?? _target().variant,
            onChanged: _selectVariant,
          )
        : null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.background,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScreenHeader(
            title: widget.report.name,
            height: 52,
            titleSize: 17,
            onTitleLongPress: _showTechnicalInfo,
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (wide && toggle != null)
                  Padding(padding: const EdgeInsets.only(right: 4), child: toggle),
                IconButton(
                  tooltip: 'Actualiser',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  key: const Key('viewer-fullscreen'),
                  tooltip: 'Plein écran',
                  onPressed: _enterFullscreen,
                  icon: const Icon(Icons.fullscreen_rounded),
                ),
              ],
            ),
          ),
          if (!wide && toggle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.page,
                0,
                AppDimens.page,
                10,
              ),
              child: SizedBox(width: double.infinity, child: toggle),
            ),
        ],
      ),
    );
  }
}

/// "Mobile" / "Bureau" switch.
class _VariantToggle extends StatelessWidget {
  const _VariantToggle({required this.selected, required this.onChanged});

  final ReportVariant selected;
  final ValueChanged<ReportVariant> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<ReportVariant>(
    key: const Key('viewer-variant'),
    showSelectedIcon: false,
    segments: const [
      ButtonSegment(
        value: ReportVariant.mobile,
        icon: Icon(Icons.smartphone_rounded, size: 18),
        label: Text('Mobile'),
      ),
      ButtonSegment(
        value: ReportVariant.desktop,
        icon: Icon(Icons.desktop_windows_outlined, size: 18),
        label: Text('Bureau'),
      ),
    ],
    selected: {selected},
    onSelectionChanged: (s) => onChanged(s.first),
  );
}

/// Translucent floating control of the full screen mode (top-right):
/// exit + rotate. Fades to 30% after 3 s; a tap while faded only wakes it.
class _FullscreenControls extends StatelessWidget {
  const _FullscreenControls({
    required this.dimmed,
    required this.onWake,
    required this.onExit,
    required this.onRotate,
  });

  final bool dimmed;
  final VoidCallback onWake;
  final VoidCallback onExit;
  final VoidCallback onRotate;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewPaddingOf(context);
    return Positioned(
      top: padding.top + 12,
      right: padding.right + 12,
      child: AnimatedOpacity(
        opacity: dimmed ? 0.3 : 1,
        duration: const Duration(milliseconds: 300),
        child: Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const Key('viewer-exit-fullscreen'),
                    tooltip: 'Quitter le plein écran',
                    color: Colors.white,
                    onPressed: () {
                      onWake();
                      onExit();
                    },
                    icon: const Icon(Icons.fullscreen_exit_rounded),
                  ),
                  IconButton(
                    tooltip: 'Pivoter',
                    color: Colors.white,
                    onPressed: onRotate,
                    icon: const Icon(Icons.screen_rotation_rounded),
                  ),
                ],
              ),
            ),
            if (dimmed)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onWake,
                ),
              ),
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
    child: SizedBox(
      width: 40,
      height: 40,
      child: CircularProgressIndicator(strokeWidth: 3),
    ),
  );
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage(this.text, {this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 120, left: 20, right: 20),
    child: Align(
      alignment: Alignment.topCenter,
      child: EmptyText(text, icon: icon, fontSize: 16),
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
        icon: Icon(Icons.key_rounded, color: context.palette.primaryText),
        title: const Text('Authentification Power BI'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Le serveur $host refuse votre mot de passe. '
                'Saisissez votre mot de passe Windows pour continuer.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: user,
                decoration: const InputDecoration(
                  labelText: 'Utilisateur',
                  helperText: r'DOMAINE\utilisateur',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                autofocus: true,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  errorText: error,
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: context.palette.textMuted,
            ),
            child: const Text('Annuler'),
          ),
          FilledButton(
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
            style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
            child: const Text('Valider'),
          ),
        ],
      ),
    ),
  );
  user.dispose();
  password.dispose();
  return result;
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

String _demoHtml(Report report, ViewerMode mode, AppPalette palette) {
  const escape = HtmlEscape();
  final edition = switch (mode) {
    ViewerMode.phoneEdition => 'Édition téléphone',
    ViewerMode.mobileLayout => 'Disposition mobile',
    ViewerMode.desktop => 'Disposition bureau',
  };
  return '''
<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{background:${_hex(palette.background)};color:${_hex(palette.text)};font-family:Roboto,sans-serif;display:flex;
align-items:center;justify-content:center;height:90vh;text-align:center;margin:0}
h1{color:${_hex(palette.primaryText)};font-size:22px}p{color:${_hex(palette.textMuted)}}
span{display:inline-block;padding:3px 10px;border-radius:12px;border:1px solid ${_hex(palette.border)}}</style></head>
<body><div><h1>${escape.convert(report.name)}</h1>
<p>${escape.convert(report.location)}</p><p><span>${escape.convert(edition)}</span></p>
<p>Mode démonstration : le rapport Power BI s'affiche ici.</p></div></body></html>''';
}
