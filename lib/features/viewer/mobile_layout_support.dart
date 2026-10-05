/// Power BI mobile (phone) layout of PBIRS reports: backend map fetch, the
/// bounded wait before the first portrait load, and the user scripts injected
/// into the report page (pure logic, unit tested).
///
/// PBIRS always draws the desktop layout in a browser. In "mobile layout"
/// mode the viewer injects, at document start and in every frame:
///   1. `window.__PBI_MOBILE_LAYOUT__ = {pages: …};` (the backend map, only
///      when it has pages),
///   2. `assets/js/pbi_mobile_layout.js`, which rewrites the report
///      definition download so the renderer draws the phone layout (with the
///      phone positions found in the download itself when 1. is absent).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/mobile_layout.dart';
import '../../data/repositories/cbi_repository.dart';
import 'viewer_variant.dart';

/// Asset rewriting the report definition (declared under `assets/js/`).
const mobileLayoutAsset = 'assets/js/pbi_mobile_layout.js';

/// Longest wait for `mobile-layout/` before the first portrait load.
const mobileLayoutWaitBudget = Duration(seconds: 6);

/// Where the phone positions of the page on screen come from.
enum LayoutSource {
  /// Backend map injected (`window.__PBI_MOBILE_LAYOUT__`).
  server,

  /// Script alone: phone positions read from the report download itself.
  fallback,

  /// No script (desktop mode or phone edition).
  none;

  /// French label (technical info sheet).
  String get label => switch (this) {
    LayoutSource.server => 'serveur',
    LayoutSource.fallback => 'repli',
    LayoutSource.none => 'aucune',
  };
}

/// Layout source of a load in [mode] with the backend map [layout]
/// (`null` = not received in time / failed).
LayoutSource layoutSourceFor(ViewerMode mode, MobileLayout? layout) {
  if (mode != ViewerMode.mobileLayout) return LayoutSource.none;
  return layout != null && layout.hasPages
      ? LayoutSource.server
      : LayoutSource.fallback;
}

// --- Backend map: session cache + bounded wait ------------------------------

/// `mobile-layout/` results kept in memory per report for the app session
/// (in-flight requests are shared; a failed one is forgotten so the next
/// viewing tries again).
class MobileLayoutCache {
  MobileLayoutCache(this._repo);

  final CbiRepository _repo;
  final _entries = <int, Future<MobileLayout>>{};

  Future<MobileLayout> fetch(int reportId) {
    final cached = _entries[reportId];
    if (cached != null) return cached;
    final future = _repo.fetchMobileLayout(reportId);
    _entries[reportId] = future;
    future.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(_entries[reportId], future)) _entries.remove(reportId);
      },
    );
    return future;
  }

  void clear() => _entries.clear();
}

final mobileLayoutCacheProvider = Provider<MobileLayoutCache>(
  (ref) => MobileLayoutCache(ref.watch(repositoryProvider)),
);

enum MobileLayoutStatus { pending, loaded, failed }

/// One viewer session's `mobile-layout/` request, started in parallel with
/// `open/`. [wait] never takes longer than what is left of [budget] since the
/// request started: the first portrait load waits at most ~6 s, later loads
/// use whatever has arrived by then.
class MobileLayoutRequest {
  MobileLayoutRequest(
    Future<MobileLayout> future, {
    this.budget = mobileLayoutWaitBudget,
    DateTime Function() clock = DateTime.now,
  }) : _clock = clock,
       _startedAt = clock() {
    _done = future.then<void>(
      (layout) {
        _layout = layout;
        _status = MobileLayoutStatus.loaded;
      },
      onError: (Object e) {
        _error = e;
        _status = MobileLayoutStatus.failed;
      },
    );
  }

  final Duration budget;
  final DateTime Function() _clock;
  final DateTime _startedAt;
  late final Future<void> _done;

  MobileLayoutStatus _status = MobileLayoutStatus.pending;
  MobileLayout? _layout;
  Object? _error;

  MobileLayoutStatus get status => _status;

  /// The backend map, once received.
  MobileLayout? get layout => _layout;
  Object? get error => _error;

  /// Completes when the request succeeds or fails (never throws).
  Future<void> get done => _done;

  /// The backend says the report has a phone layout.
  bool get available => _layout?.available ?? false;

  /// Time left before loads stop waiting for the backend.
  Duration get remaining {
    final left = budget - _clock().difference(_startedAt);
    return left.isNegative ? Duration.zero : left;
  }

  /// The map if it arrives within the remaining budget, else `null`
  /// (timeout or error → the script alone, never blocks the report).
  Future<MobileLayout?> wait() async {
    if (_status == MobileLayoutStatus.pending && remaining > Duration.zero) {
      await _done.timeout(remaining, onTimeout: () {});
    }
    return _layout;
  }
}

// --- User scripts ------------------------------------------------------------

/// [value] as a JavaScript literal: `jsonEncode`, then `<`, `>`, `&`,
/// U+2028 and U+2029 escaped as `\uXXXX` (only possible inside JSON strings,
/// so the value is unchanged) — no raw text can end a script or break out of
/// the literal.
String jsonForScript(Object? value) {
  var text = jsonEncode(value);
  for (final code in _scriptUnsafeCodeUnits) {
    text = text.replaceAll(String.fromCharCode(code), _jsUnicodeEscape(code));
  }
  return text;
}

/// `<`, `>`, `&`, LINE SEPARATOR, PARAGRAPH SEPARATOR.
const _scriptUnsafeCodeUnits = [0x3C, 0x3E, 0x26, 0x2028, 0x2029];

/// Backslash + `u` + 4 hex digits.
String _jsUnicodeEscape(int code) =>
    '${String.fromCharCode(0x5C)}u${code.toRadixString(16).padLeft(4, '0')}';

/// First user script: the backend map for the asset script.
String mobileLayoutGlobalScript(MobileLayout layout) =>
    'window.__PBI_MOBILE_LAYOUT__ = ${jsonForScript(layout.toScriptJson())};';

/// Sources injected in mobile layout mode, in order: the map (only when the
/// backend sent pages; an empty map would disable the script's fallback) then
/// the asset.
List<String> mobileLayoutScriptSources({
  required String assetSource,
  MobileLayout? layout,
}) => [
  if (layout != null && layout.hasPages) mobileLayoutGlobalScript(layout),
  assetSource,
];

/// [sources] as document-start user scripts for every frame (the report runs
/// in a same-origin iframe of the PBIRS page). On Android they are
/// registered with `WebViewCompat.addDocumentStartJavaScript`
/// (`WebViewFeature.DOCUMENT_START_SCRIPT`).
List<UserScript> documentStartUserScripts(List<String> sources) => [
  for (var i = 0; i < sources.length; i++)
    UserScript(
      groupName: 'pbi_mobile_layout',
      source: sources[i],
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      forMainFrameOnly: false,
    ),
];

/// Reads the JS counters exposed by the asset script (main frame; the report
/// frame copies them to `window.top`).
const mobileLayoutStatsExpression =
    'JSON.stringify(window.__pbiMobileLayoutStats||null)';

String? _assetCache;

/// The asset script source (read once).
Future<String> loadMobileLayoutAsset(AssetBundle bundle) async =>
    _assetCache ??= await bundle.loadString(mobileLayoutAsset, cache: false);

// --- Technical info sheet ----------------------------------------------------

/// Lines of the hidden "Informations techniques" sheet (long press on the
/// report title).
List<String> technicalInfoLines({
  required ViewerMode mode,
  required LayoutSource source,
  required MobileLayoutRequest? request,
  required bool? documentStartSupported,
  required String? jsStats,
}) {
  final pages = switch (request?.status) {
    MobileLayoutStatus.loaded =>
      request!.available ? '${request.layout!.pages.length}' : '0 (non disponible)',
    MobileLayoutStatus.failed => 'erreur',
    MobileLayoutStatus.pending => 'en attente',
    null => '—',
  };
  final docStart = switch (documentStartSupported) {
    true => 'pris en charge',
    false => 'non pris en charge',
    null => 'inconnu',
  };
  return [
    'Mode : ${mode.label}',
    'Source de la disposition : ${source.label}',
    'Pages téléphone (serveur) : $pages',
    'Scripts au démarrage (DOCUMENT_START_SCRIPT) : $docStart',
    'Compteurs JS : ${jsStats ?? 'indisponibles'}',
  ];
}
