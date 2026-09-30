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

Version: `pubspec.yaml` `version: 3.0.0+7` (versionName 3.0.0, versionCode 7;
legacy was 2.2 / 6). The value sent as `app_version` at login and compared with
`config.min_version` comes from `package_info_plus`.

Android specifics (`android/`): Kotlin DSL, AGP 9, core library desugaring
enabled (required by `flutter_local_notifications`), label "GSH - CBI",
`applicationId com.cbi.portal.cbi_mobile`. The app is portrait-locked; the report
viewer unlocks landscape while it is open.

## Backend contract (mobile API v1)

Authoritative spec: `CBI/docs/MOBILE_API.md`. Base path
`<API_BASE_URL>/mobile/v1/`, JSON, `Authorization: Bearer <token>`.

| Used for | Endpoint |
|---|---|
| Force-update dialog, Aide / À propos, poll interval | `GET config/` |
| Login / logout | `POST auth/login/` (`username`, `password`, `device`, `app_version`), `POST auth/logout/` |
| Profile | `GET me/`, `GET me/photo/` (Bearer) |
| Home, tabs, lists, favourites | `GET catalog/` with `If-None-Match` (→ `304`) |
| Viewer | `POST reports/<id>/open/`, `POST reports/<id>/close/` (`view_id`, `duration_seconds`) |
| Favourites | `PUT` / `DELETE favorites/<id>/` |
| Notifications | `GET notifications/?after=&limit=`, `GET notifications/unread-count/`, `POST notifications/<id>/read/`, `POST notifications/read-all/` |
| Historique | `GET history/?days=30`, `GET history/users/?q=&company=&limit=&offset=` (admins), `GET history/users/<id>/?days=30` |
| Mes demandes | `GET` / `POST tickets/`, `GET tickets/<id>/`, `POST tickets/<id>/messages/` |

Errors `{"detail","code"}` are shown in French (server `detail` first, legacy
texts for login: "Email ou mot de passe invalide", "Accès refusé.\nVeuillez
contacter Helpdesk BI", "Connexion impossible.\nVeuillez contacter Helpdesk BI",
"Vérifiez votre connexion internet"). Any `401` on an authenticated call wipes
the local session and returns to the login screen. Riverpod retries only
network failures (3 times, exponential back-off).

## Credentials & storage

- `flutter_secure_storage` (Android Keystore): session token, user profile,
  NTLM `credentials` (`domain`, `username`) and the AD password.
- The password is never sent anywhere except in answer to an NTLM challenge
  from a PBIRS host listed in `catalog.servers` (see below). The CBI server does
  not store it.
- `shared_preferences`: last username (login prefill, kept after logout) and the
  last notification id seen (background poller).
- Logout (`auth/logout/`, also when offline) wipes the secure storage, cancels
  the background task and removes posted notifications.

## Report viewer and NTLM

1. Tap on a report → `POST reports/<id>/open/` → `embed_url` loaded directly in
   `webview_flutter` (JavaScript on, DOM storage on — default of the Android
   implementation).
2. `NavigationDelegate.onHttpAuthRequest`
   (`lib/features/viewer/ntlm_auth.dart`, unit tested):
   - host **not** in `catalog.servers[].host` (case-insensitive; the `server` of
     the open response is accepted too) → **cancel**, credentials are never sent;
   - first challenge for an allowed host during this view → proceed with
     `DOMAIN\username` + stored password;
   - challenged again for the same host (wrong / expired password) → French
     dialog "Authentification Power BI" prefilled with `DOMAIN\username`; on
     submit the stored password is updated and the request proceeds; cancel
     shows "Vous n'avez pas accès à ce rapport.".
3. Leaving the viewer → `POST reports/<id>/close/` with the viewing time
   (Stopwatch paused while the app is in the background).

PBIRS must offer NTLM (`RSWindowsNTLM`, or `RSWindowsNegotiate` falling back to
NTLM): Android WebView cannot do Kerberos without an enterprise authenticator
app. **Verify on a real device against each PBIRS server before release.**

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

## Pending: image assets

No image is wired yet (to be chosen). All slots are in `lib/core/assets.dart`:

| Slot | Legacy image | Fallback |
|---|---|---|
| `AppAssets.splashLogo` | `cbi_login` | "CBI" text |
| `AppAssets.loginLogo` | `gsh_login` | "GSH" text |
| `AppAssets.headerLogo` | `gsh_white_small` | "GSH" text |
| `AppAssets.footerLogo` | `cbi_dark` | "CBI" text |
| `AppAssets.aboutLogo` | `cbi` | "CBI" text |
| `AppAssets.codeImages[<CODE or name>]` | tile / consolidé card images (dgr, dfc, alpostone, …) | code in upper case (tiles), nothing above the code (consolidé cards) |

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
`download_url`, and verify on real devices login/logout, 401 handling, NTLM on
every PBIRS server, favourites, history (admin and non-admin), tickets and
background notifications.
