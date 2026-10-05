# GSH - CBI mobile — setup & operations

## Build configuration

| dart-define        | Default                   | Notes |
|--------------------|---------------------------|-------|
| `API_BASE_URL`     | `http://10.10.10.53:8222` | CBI platform origin, **no path**. HTTPS is accepted for any host; plain HTTP only for private / loopback addresses (10/8, 172.16/12, 192.168/16, 127/8, `localhost`). Any other value makes every call fail with "Configuration du serveur invalide." |
| `ENABLE_DEMO_MODE` | `false`                   | `true` swaps the API for `DemoCbiRepository` (fixtures shaped like the contract, in-memory session, local placeholder instead of PBIRS). Never enable in a release build. |

```powershell
flutter build apk --debug
flutter build apk --debug --dart-define=ENABLE_DEMO_MODE=true
flutter build apk --release --dart-define=API_BASE_URL=http://10.10.10.53:8222
```

Version: `pubspec.yaml` `version: 3.4.0+11` (versionName 3.4.0, versionCode 11;
3.4 brings the platform's ticket system ("Tickets") and adaptive tablet
layouts; 3.3 draws the Power BI mobile layout of PBIRS reports with
`flutter_inappwebview`, see "Power BI mobile layout"; 3.2.0+9 added the
fingerprint app lock and "Se souvenir de moi"; 3.1.0+8 brought the
Portail BI theme; 3.0.0+7 was the first Flutter release, legacy was 2.2 / 6). The value sent as `app_version` at login and compared with
`config.min_version` comes from `package_info_plus`.

Android specifics (`android/`): Kotlin DSL, AGP 9, core library desugaring
enabled (required by `flutter_local_notifications`), label "GSH - CBI",
`applicationId com.cbi.portal.cbi_mobile`. Phones are portrait-locked and
edge-to-edge; the report viewer unlocks rotation while it is open (and uses
immersive mode in full screen). Tablets (display shortest side ≥ 600 dp,
detected at startup by `AppOrientations.init`) rotate on every screen. Leaving
the viewer restores the app policy (`AppOrientations.restore`: portrait on
phones, free on tablets) and `SystemUiMode.edgeToEdge`.

Package added in 3.4: `image_picker` ^1.2.2 (ticket attachments). It uses the
Android photo picker (no storage permission) and the camera app through an
intent; no `CAMERA` permission is declared (declaring it would force a runtime
request), so nothing was added to the manifest.

Packages added in 3.1: `cached_network_image` (logo images) and
`flutter_cache_manager` (the permanent logo cache, `LogoCacheManager`).

Added in 3.2: `local_auth` 3.0.x (+ `local_auth_android`, imported for the
French prompt strings). Android requirements, all in place:

- `MainActivity` extends `FlutterFragmentActivity` (BiometricPrompt needs a
  FragmentActivity);
- `android.permission.USE_BIOMETRIC` in `AndroidManifest.xml`;
- `LaunchTheme` / `NormalTheme` inherit `Theme.AppCompat.(Light.)NoActionBar`
  in `values`, `values-night`, `values-v31`, `values-night-v31` (the plugin
  crashes on Android 8 and below without an AppCompat theme; minSdk is 24), the
  window backgrounds (dark `#1C1D22` splash) are unchanged;
- `androidx.appcompat:appcompat` declared in `android/app/build.gradle.kts`
  (no plugin brings it, and the AppCompat themes live there).

## Backend contract (mobile API v1)

Authoritative spec: `CBI/docs/MOBILE_API.md`. Base path
`<API_BASE_URL>/mobile/v1/`, JSON, `Authorization: Bearer <token>`.

| Used for | Endpoint |
|---|---|
| Force-update dialog, Aide / À propos, poll interval | `GET config/` |
| Login / logout | `POST auth/login/` (`username`, `password`, `device`, `app_version`), `POST auth/logout/` |
| Profile | `GET me/`, `GET me/photo/` (Bearer) |
| Home, tabs, lists, favourites | `GET catalog/` with `If-None-Match` (→ `304`) |
| Pôle / société logos | `GET metadata/<option_id>/logo/` via the catalog's versioned `logo_url` (Bearer) |
| Viewer | `POST reports/<id>/open/`, `POST reports/<id>/close/` (`view_id`, `duration_seconds`) |
| Favourites | `PUT` / `DELETE favorites/<id>/` |
| Notifications | `GET notifications/?after=&limit=`, `GET notifications/unread-count/`, `POST notifications/<id>/read/`, `POST notifications/read-all/` |
| Historique | `GET history/?days=30`, `GET history/users/?q=&company=&limit=&offset=` (admins), `GET history/users/<id>/?days=30` |
| Tickets | `GET tickets/choices/`, `GET tickets/?status=&assigned=me`, `POST tickets/` (multipart: fields + optional `attachment`), `GET tickets/<id>/`, `POST tickets/<id>/messages/` (multipart), `POST tickets/<id>/update/` (admins, JSON `status` / `assigned_to`), `GET tickets/admins/`, attachment images `GET tickets/<id>/attachment/`, `GET tickets/<id>/messages/<mid>/attachment/` (Bearer) |

Errors `{"detail","code"}` are shown in French (server `detail` first, legacy
texts for login: "Email ou mot de passe invalide", "Accès refusé.\nVeuillez
contacter Helpdesk BI", "Connexion impossible.\nVeuillez contacter Helpdesk BI",
"Vérifiez votre connexion internet"). Any `401` on an authenticated call wipes
the local session and returns to the login screen. Riverpod retries only
network failures (3 times, exponential back-off).

## Credentials & storage

- `flutter_secure_storage` (Android Keystore): session token, user profile,
  NTLM `credentials` (`domain`, `username`) and the AD password.
- Same store, separate keys (`remembered_username`, `remembered_password`):
  the "Se souvenir de moi" credentials. They survive logout and `401`; they are
  removed when the user logs in with the box unchecked, and the password alone
  is removed when a silent re-login is refused with `invalid_credentials`.
- Same store: the app lock settings (`app_lock_enabled`,
  `app_lock_delay_seconds`, `app_lock_offered`), kept after logout.
- The password is never sent anywhere except in answer to an NTLM challenge
  from a PBIRS host listed in `catalog.servers` (see below). The CBI server does
  not store it.
- `shared_preferences`: last username (login prefill, kept after logout), the
  last notification id seen (background poller) and the "Apparence" choice
  (`theme_mode` = `system` | `light` | `dark`, kept after logout).
- Logo cache (`cbiGroupLogos`, app cache dir): pôle / société logos, kept 10
  years / 500 files and never revalidated (the `?v=` of `logo_url` changes
  with the logo). The Bearer header is only sent when the logo URL is on the
  `API_BASE_URL` origin.
- Logout (`auth/logout/`, also when offline) wipes the session keys of the
  secure storage, cancels the background task and removes posted
  notifications. Remembered credentials and the lock settings stay.

## Security: remembered credentials and app lock

**Where the credentials are.** `flutter_secure_storage` encrypts the values
with a key held in the **Android Keystore** (hardware-backed on most phones)
and keeps them in the app's private storage. They never leave the device:
`android:allowBackup="false"` excludes them from cloud / adb backups, and they
are unreadable by other apps. Uninstalling the app or clearing its data
deletes them. They are sent only to `POST /mobile/v1/auth/login/` (login,
fingerprint login, silent re-login) and, for the AD password, to the PBIRS
hosts of `catalog.servers` in answer to an NTLM challenge.

**Silent re-login.** When the API answers `401` to an authenticated call and a
password is remembered, `ApiClient` asks `SessionController` for one new login
(a single in-flight attempt shared by concurrent requests; `auth/login/` is
always sent without the old token and never re-triggers itself) and retries
the request once. A second `401` ends the session normally. With the app lock
on, the re-login waits until the app is unlocked. `invalid_credentials` →
password forgotten (username kept) and "Votre mot de passe a changé. Veuillez
vous reconnecter." on the login screen; network errors and `429` → the normal
"session expirée" path, nothing deleted, no loop. `auth/logout/` is never
retried.

**What the app lock protects.** With "Verrouillage par empreinte" on, anyone
holding the unlocked phone must pass the fingerprint / face prompt (or the
phone's PIN / pattern: `biometricOnly: false`, so a user is never locked out)
to see the app: at cold start with a stored session, and on resume after the
chosen delay in the background (Immédiat = any trip to the background; the
notification shade or the prompt itself never count). The lock screen is
drawn above the navigator (`AppLockGate` in `MaterialApp.builder`): the screen
underneath, including an open report WebView, keeps its state but is covered,
hidden from accessibility services and its animations paused; the back button
/ gesture is swallowed. At cold start no API call is made before the unlock.
"Connexion par empreinte" on the login screen uses the same prompt, then the
remembered credentials. If the phone no longer has any fingerprint or PIN, the
lock switches itself off instead of blocking the user.

It does **not** protect against someone who knows the phone PIN, nor hide the
app thumbnail in the recent-apps screen (no `FLAG_SECURE`, screenshots stay
possible). The lock is a local gate: the server session is unchanged.

## Report viewer and NTLM

1. Tap on a report → `POST reports/<id>/open/` (once per viewing) and, in
   parallel, `GET reports/<id>/mobile-layout/` → `embed_url` loaded directly in
   `flutter_inappwebview` (`InAppWebView`: JavaScript on, DOM storage on,
   mixed content left at the Android default as before, cleartext allowed by
   the network security config below; remote debugging via `chrome://inspect`
   in debug / profile builds only).
   - **Phone edition** (`report.phone`, from the open response, else the
     catalog) keeps priority: portrait loads `phone.embed_url`, landscape the
     full `embed_url`.
   - **Without a phone edition**: portrait loads the full `embed_url` in
     *mobile layout* mode (the Power BI phone layout, see "Power BI mobile
     layout" below), landscape in *desktop* mode (no user scripts).
   - Mode selection: `selectReportVariant` / `resolveViewerTarget`
     (`lib/features/viewer/viewer_variant.dart`, unit tested). The toolbar
     "Mobile" / "Bureau" switch is shown when a phone edition exists or the
     backend reports a phone layout (`available: true`); it overrides the
     orientation for the rest of the viewing. Every switch / rotation creates
     a new WebView with the right user scripts: no new `open/`, the NTLM
     attempt counter is reset for the new page.
   - **Plein écran** (toolbar button): `SystemUiMode.immersiveSticky`, toolbar
     hidden, all orientations allowed, translucent floating control top-right
     (exit full screen + rotate landscape ↔ portrait) that fades to 30% after
     3 s and comes back on tap. The exit button or Android back restores
     `edgeToEdge`, the toolbar and the viewer's orientation rules.
2. `InAppWebView.onReceivedHttpAuthRequest`
   (`lib/features/viewer/ntlm_auth.dart`, unit tested; the answer is never
   persisted by the plugin, `permanentPersistence: false`):
   - host **not** in `catalog.servers[].host` (case-insensitive; the `server` of
     the open response and the phone edition's `server_id` are accepted too —
     both are in `catalog.servers`) → **cancel**, credentials are never sent;
   - first challenge for an allowed host during this view → proceed with
     `DOMAIN\username` + stored password;
   - challenged again for the same host (wrong / expired password) → French
     dialog "Authentification Power BI" prefilled with `DOMAIN\username`; on
     submit the stored password is updated and the request proceeds; cancel
     shows "Vous n'avez pas accès à ce rapport.".
3. Leaving the viewer → `POST reports/<id>/close/` once with the total viewing
   time, whatever edition was shown (Stopwatch paused while the app is in the
   background).

PBIRS must offer NTLM (`RSWindowsNTLM`, or `RSWindowsNegotiate` falling back to
NTLM): Android WebView cannot do Kerberos without an enterprise authenticator
app. **Verify on a real device against each PBIRS server before release.**

## Power BI mobile layout

PBIRS always draws a report's **desktop** layout in a browser, even when the
author designed a phone layout in Power BI Desktop (View → Mobile layout). The
app draws that phone layout itself:

- **Mechanism.** The PBIRS report page (`embed_url`, the report renders in a
  same-origin iframe) downloads the report definition from
  `/powerbi/api/explore/reports/<id>/modelsAndExploration`. In mobile layout
  mode the viewer injects two **user scripts at document start in every
  frame** (`UserScriptInjectionTime.AT_DOCUMENT_START`,
  `forMainFrameOnly: false`; on Android the plugin registers them with
  `WebViewCompat.addDocumentStartJavaScript`):
  1. `window.__PBI_MOBILE_LAYOUT__ = {pages: …};` — the backend map, embedded
     with `jsonEncode` (plus `<`, `>`, `&`, U+2028/9 escaped), only when the
     backend sent pages;
  2. `assets/js/pbi_mobile_layout.js` (declared under `assets/js/` in
     `pubspec.yaml`). It patches `fetch` / `XMLHttpRequest` and rewrites that
     download: each visual gets its phone position (`config.layouts` id 1),
     visuals absent from the phone canvas are dropped, phone-only formatting
     (`Report/MobileState`) is merged and the page becomes a portrait canvas
     shown fit to width. Counters: `window.__pbiMobileLayoutStats`
     (`rewritten`, `pages`, `errors`, copied to `window.top`).
  Code: `lib/features/viewer/mobile_layout_support.dart` (unit tested) and
  `viewer_screen.dart`.
- **Endpoint.** `GET /mobile/v1/reports/<id>/mobile-layout/` →
  `{"available", "version": 1, "pages": {<section>: {display_name, width,
  height, visuals: {<visual>: {x, y, z, width, height, objects?}}}}}`
  (`MobileLayout`, `lib/data/models/mobile_layout.dart`). The first call for a
  report can take several seconds (the backend downloads the .pbix), then the
  backend caches it; the app also keeps the result in memory per report for
  the app session (`MobileLayoutCache`; a failed call is retried at the next
  viewing).
- **Wait and fallback.** The call starts together with `open/`. The first
  portrait load waits for it **at most ~6 s** (`mobileLayoutWaitBudget`);
  later loads (rotation, "Mobile") use whatever has arrived, without waiting.
  On timeout or error — or when the backend answers `available: false` — the
  asset script is injected **alone**: it then reads the phone positions from
  the download itself (without the phone-only formatting). The report is
  never blocked. "Actualiser" re-creates the page when the map arrived after
  the first load.
- **Per-page desktop fallback.** Pages without a phone layout are left
  untouched and render in their desktop layout; a report without any phone
  layout therefore simply shows the desktop view in portrait.
- **Landscape / "Bureau"** loads the same `embed_url` without any user script
  (the PBIRS desktop layout). A linked phone edition (`report.phone`) always
  wins over the mobile layout in portrait.
- **Hidden technical info.** A long press on the report title opens the
  "Informations techniques" bottom sheet (selectable text, no visible
  button): mode (mobile / bureau / édition téléphone), layout source
  (serveur = backend map, repli = script alone, aucune = no script), number of
  phone pages returned by the endpoint, DOCUMENT_START_SCRIPT support, and the
  JS counters read with
  `evaluateJavascript('JSON.stringify(window.__pbiMobileLayoutStats||null)')`
  on the main frame (`null` = no script or nothing rewritten yet).
- **WebView requirement.** Document-start scripts need an **up-to-date Android
  System WebView** exposing `WebViewFeature.DOCUMENT_START_SCRIPT` (androidx
  webkit; any recent WebView from the Play Store has it). The viewer checks the
  feature at start-up and logs `[viewer] WebViewFeature.DOCUMENT_START_SCRIPT
  non pris en charge …` when it is missing; the plugin then injects the scripts
  only after the page has loaded, which is too late: the report stays in its
  desktop layout (no error). Update "Android System WebView" from the Play
  Store on such devices.
- **Package.** `flutter_inappwebview` **6.2.0-beta.3** replaces
  `webview_flutter`: the 6.1.5 stable release does not build with AGP 9
  (`getDefaultProguardFile('proguard-android.txt')` is rejected); 6.2.0-beta.3
  (Feb 2026) is the latest 6.x and builds. Move to the next stable 6.x when
  it is published.

### Cleartext HTTP

`android/app/src/main/res/xml/network_security_config.xml` sets
`base-config cleartextTrafficPermitted="true"`: the CBI platform and the PBIRS
servers are on the internal network over plain HTTP, and admins can add PBIRS
servers at runtime, so they cannot be enumerated in the config. NTLM is a
challenge/response protocol (the password is not sent in clear). Note however
that the **login call** (`auth/login/`) carries the password in its JSON body:
over plain HTTP it is protected only by the internal network. Move
`API_BASE_URL` to HTTPS as soon as the platform offers it.

## Notifications (no Firebase)

- **Foreground**: the Notification tab badge shows `unread_count`. While the app
  is in the foreground it polls `notifications/unread-count/` every
  `config.notification_poll_seconds` (min 15 s) and immediately on resume; the
  catalog and the notification list also refresh it.
- **Background**: a WorkManager periodic task (`cbi-notifications-poll`, every
  15 min, network required) runs `callbackDispatcher`
  (`lib/features/notifications/notification_worker.dart`): it reads the stored
  token, calls `notifications/?after=<last_seen_id>`, raises up to 5 local
  notifications (channel `cbi_notifications` "Notifications CBI", colour
  `#6E8F4F`, BigText, title = notification title, body = message) and stores
  `latest_id`. The first poll after login only records `latest_id` (no replay
  of old notifications); items seen in the foreground are not raised again.
- Tapping a notification opens the app on the Notification tab.
- Android 13+: `POST_NOTIFICATIONS` is requested when the shell opens. Manifest
  entries: `INTERNET`, `ACCESS_NETWORK_STATE`, `POST_NOTIFICATIONS`,
  `RECEIVE_BOOT_COMPLETED`, plus `<queries>` for `https`/`http`/`mailto`
  (url_launcher).
- WorkManager timing is best-effort (Doze, battery optimisation, OEM task
  killers may delay it). The local notification small icon currently uses the
  launcher icon (`@mipmap/ic_launcher`); a monochrome drawable can be added with
  the other assets.

## Theme and image assets

Colours come from `AppPalette` (`lib/core/theme/app_palette.dart`, light and
dark tokens of the Portail BI web platform); `AppColors` only keeps fixed brand
values (green, splash background, notification accent). The splash and the
Android launch screen stay dark.

Image slots are in `lib/core/assets.dart`:

| Slot | Image | Fallback |
|---|---|---|
| `AppAssets.splashLogo` | `brand/pbi_mark_on_dark.png` (always dark) | "CBI" text |
| `AppAssets.loginLogo(brightness)` | `brand/portail_bi_logo[_on_dark].png` | "GSH" text |
| `AppAssets.headerLogo(brightness)` | `brand/pbi_mark[_on_dark].png` | "GSH" text |
| `AppAssets.aboutLogo(brightness)` | `brand/portail_bi_logo[_on_dark].png` | "CBI" text |
| `AppAssets.footerLogo` | not chosen (`null`) | nothing |
| `AppAssets.codeImages[<CODE or name>]` | empty | code / initials tile |
| pôle / société cards | catalog `logo_url` (network, cached) | code / initials tile |

Existing files under `assets/images/` (including `assets/images/legacy/`) are
kept and already declared in `pubspec.yaml`.

## Release

Signing uses environment variables (never committed):

```powershell
$env:CBI_ANDROID_KEYSTORE = 'C:\secure\cbi-upload.jks'
$env:CBI_ANDROID_STORE_PASSWORD = '...'
$env:CBI_ANDROID_KEY_ALIAS = 'cbi-upload'
$env:CBI_ANDROID_KEY_PASSWORD = '...'
flutter build apk --release --obfuscate --split-debug-info=build/symbols
```

Without them the release build is unsigned. Before publishing: raise
`config.min_version` on the server only once the new APK is available at
`download_url`, and verify on real devices login/logout, 401 handling (silent
re-login), "Se souvenir de moi", the fingerprint lock (enable, delays,
cold start, PIN fallback), NTLM on every PBIRS server, the Power BI mobile
layout (portrait / landscape / "Mobile" / "Bureau", long-press info sheet),
favourites, history (admin and non-admin), tickets (create with a camera /
gallery image, admin status and assignee, image messages) on a phone and a
tablet (rotation, navigation rail, two-pane tickets) and background
notifications.
