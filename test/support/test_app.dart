import 'dart:async';

import 'package:cbi_mobile/core/images/logo_images.dart';
import 'package:cbi_mobile/core/images/ticket_images.dart';
import 'package:cbi_mobile/core/layout/adaptive.dart';
import 'package:cbi_mobile/core/providers.dart';
import 'package:cbi_mobile/core/security/biometric_auth.dart';
import 'package:cbi_mobile/core/storage/lock_settings_store.dart';
import 'package:cbi_mobile/core/storage/remembered_credentials_store.dart';
import 'package:cbi_mobile/core/storage/session_store.dart';
import 'package:cbi_mobile/core/theme/app_theme.dart';
import 'package:cbi_mobile/core/theme/theme_mode_controller.dart';
import 'package:cbi_mobile/data/models/catalog.dart';
import 'package:cbi_mobile/data/models/mobile_layout.dart';
import 'package:cbi_mobile/data/models/notification.dart';
import 'package:cbi_mobile/data/models/ticket.dart';
import 'package:cbi_mobile/data/models/user.dart';
import 'package:cbi_mobile/data/repositories/demo_cbi_repository.dart';
import 'package:cbi_mobile/features/tickets/attachment_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Demo repository without latency whose behaviour tests can tweak.
class FakeRepository extends DemoCbiRepository {
  FakeRepository({this.catalog, this.notifications, super.ticketAdmin})
    : super(latency: Duration.zero);

  Catalog? catalog;
  NotificationsPage? notifications;
  Object? loginError;
  Object? favoriteError;
  int favoriteCalls = 0;

  /// `(username, password)` of every login call.
  final logins = <(String, String)>[];

  /// `mobile-layout/` answer (default: the demo fixture); [mobileLayoutError]
  /// makes it fail, [mobileLayoutGate] holds it until completed.
  MobileLayout? mobileLayout;
  Object? mobileLayoutError;
  Completer<void>? mobileLayoutGate;
  int mobileLayoutCalls = 0;

  @override
  Future<Catalog> fetchCatalog({bool force = false}) async =>
      catalog ?? super.fetchCatalog(force: force);

  @override
  Future<MobileLayout> fetchMobileLayout(int reportId) async {
    mobileLayoutCalls++;
    await mobileLayoutGate?.future;
    if (mobileLayoutError != null) throw mobileLayoutError!;
    return mobileLayout ?? super.fetchMobileLayout(reportId);
  }

  @override
  Future<NotificationsPage> fetchNotifications({int? after, int limit = 50}) async =>
      notifications ?? super.fetchNotifications(after: after, limit: limit);

  @override
  Future<LoginResult> login({
    required String username,
    required String password,
    String? device,
    String? appVersion,
  }) async {
    logins.add((username, password));
    if (loginError != null) throw loginError!;
    return super.login(username: username, password: password);
  }

  @override
  Future<bool> setFavorite(int reportId, bool favorite) async {
    favoriteCalls++;
    if (favoriteError != null) throw favoriteError!;
    return super.setFavorite(reportId, favorite);
  }

  // --- Tickets ---------------------------------------------------------

  /// Every `POST tickets/` body.
  final createdTickets = <NewTicket>[];
  Object? createTicketError;

  /// Every `POST tickets/<id>/update/` call.
  final ticketUpdates = <(int, TicketUpdate)>[];
  Object? updateTicketError;

  /// Holds `updateTicket` until completed (optimistic UI tests).
  Completer<void>? updateTicketGate;

  /// Every `GET tickets/` filter.
  final ticketFilters = <TicketFilter>[];

  @override
  Future<TicketList> fetchTickets({
    TicketFilter filter = TicketFilter.all,
  }) {
    ticketFilters.add(filter);
    return super.fetchTickets(filter: filter);
  }

  @override
  Future<Ticket> createTicket(NewTicket ticket) async {
    createdTickets.add(ticket);
    if (createTicketError != null) throw createTicketError!;
    return super.createTicket(ticket);
  }

  @override
  Future<Ticket> updateTicket(int ticketId, TicketUpdate update) async {
    ticketUpdates.add((ticketId, update));
    await updateTicketGate?.future;
    if (updateTicketError != null) throw updateTicketError!;
    return super.updateTicket(ticketId, update);
  }
}

/// [TicketImagePicker] returning [next] (or throwing [error]).
class FakeTicketImagePicker implements TicketImagePicker {
  FakeTicketImagePicker([this.next]);

  TicketAttachment? next;
  Object? error;
  final sources = <AttachmentSource>[];

  @override
  Future<TicketAttachment?> pick(AttachmentSource source) async {
    sources.add(source);
    if (error != null) throw error!;
    return next;
  }
}

/// Scriptable [BiometricAuth].
class FakeBiometricAuth implements BiometricAuth {
  FakeBiometricAuth({
    this.current = BiometricStatus.biometrics,
    this.succeed = true,
  });

  BiometricStatus current;
  bool succeed;
  final reasons = <String>[];

  @override
  Future<BiometricStatus> status() async => current;

  @override
  Future<bool> authenticate(String reason) async {
    reasons.add(reason);
    return succeed && current.isAvailable;
  }
}

/// Wraps [child] in a ProviderScope + themed MaterialApp + Scaffold.
///
/// The app follows [themeMode] (default: the platform, i.e. light in tests)
/// and [logoResolver] replaces the network logo loader (default: no logo →
/// initials tiles).
Widget testApp(
  Widget child, {
  required FakeRepository repo,
  SessionStore? store,
  RememberedCredentialsStore? remembered,
  LockSettingsStore? lockStore,
  BiometricAuth? biometrics,
  bool scaffold = true,
  ThemeMode themeMode = ThemeMode.system,
  ThemeModeStore? themeStore,
  LogoImageResolver? logoResolver,
  TicketImagePicker? imagePicker,
  LogoImageResolver? ticketImageResolver,
}) => ProviderScope(
  retry: (_, _) => null,
  overrides: [
    repositoryProvider.overrideWithValue(repo),
    sessionStoreProvider.overrideWithValue(store ?? MemorySessionStore()),
    rememberedCredentialsStoreProvider.overrideWithValue(
      remembered ?? MemoryRememberedCredentialsStore(),
    ),
    lockSettingsStoreProvider.overrideWithValue(
      lockStore ?? MemoryLockSettingsStore(),
    ),
    biometricAuthProvider.overrideWithValue(
      biometrics ?? FakeBiometricAuth(current: BiometricStatus.unavailable),
    ),
    appVersionProvider.overrideWith((ref) => '3.0.0'),
    initialThemeModeProvider.overrideWithValue(themeMode),
    themeModeStoreProvider.overrideWithValue(
      themeStore ?? MemoryThemeModeStore(themeMode),
    ),
    logoImageResolverProvider.overrideWithValue(logoResolver ?? (_) => null),
    ticketImagePickerProvider.overrideWithValue(
      imagePicker ?? FakeTicketImagePicker(),
    ),
    ticketImageResolverProvider.overrideWithValue(
      ticketImageResolver ?? (_) => null,
    ),
  ],
  child: Consumer(
    builder: (context, ref, _) => MaterialApp(
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ref.watch(themeModeProvider),
      // Same text-scale clamp as the app (large system fonts).
      builder: clampTextScale,
      home: scaffold ? Scaffold(body: child) : child,
    ),
  ),
);

/// Sets the window (MediaQuery) size in logical pixels, optionally with a
/// system text scale; reset at the end of the test.
void setWindowSize(WidgetTester tester, Size size, {double textScale = 1}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}
