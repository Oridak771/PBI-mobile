# GSH - CBI (mobile)

Flutter Android app (version **3.4.0+11**, application id
`com.cbi.portal.cbi_mobile`) that lists the Power BI reports a user may access
on the CBI platform and displays them from Power BI Report Server (PBIRS) in a
WebView. It is the revival of the legacy Java app (`gsh-cbi-android-master`,
v2.2 / versionCode 6): same screens, navigation and French texts, restyled
since 3.1 with the Portail BI web platform theme (light + dark).

The backend is the CBI Django platform, mobile API **v1**
(`<API_BASE_URL>/mobile/v1/`), specified in
`CBI/docs/MOBILE_API.md`. The app uses only those endpoints.

## Quick start

```powershell
flutter pub get
flutter run                                              # real server (default http://10.10.10.53:8222)
flutter run --dart-define=ENABLE_DEMO_MODE=true          # fixtures, no server needed
flutter run --dart-define=API_BASE_URL=https://cbi.example.com
flutter analyze; flutter test
flutter build apk --debug
```

| dart-define        | Default                     | Purpose                                                        |
|--------------------|-----------------------------|----------------------------------------------------------------|
| `API_BASE_URL`     | `http://10.10.10.53:8222`   | Origin of the CBI platform (no path). HTTP only for private IPs.|
| `ENABLE_DEMO_MODE` | `false`                     | Run on contract-shaped fixtures (`DemoCbiRepository`).         |

## Project structure

```
lib/
  main.dart                 orientation policy (phones portrait, tablets free) + ProviderScope + CbiApp
  app.dart                  MaterialApp, global 401/logout → login, Riverpod retry policy
  core/
    assets.dart             AppAssets registry (brand logos, theme-aware, + code image slots)
    providers.dart          config, storage, api client, repository, app version, config/, photos
    config/app_config.dart  dart-defines, v1 URL building, base-URL validation
    api/api_client.dart     http wrapper: Bearer, JSON, {"detail","code"} errors, 304,
                            401 → one shared silent re-login + retry, onUnauthorized
    errors/app_exception.dart  ApiException / NetworkException + French messages
    storage/session_store.dart flutter_secure_storage (Keystore) + shared_preferences
    storage/remembered_credentials_store.dart  "Se souvenir de moi" (survives logout / 401)
    storage/lock_settings_store.dart  app lock on/off, delay, "offered once" flag
    security/biometric_auth.dart  BiometricAuth interface + local_auth implementation
    theme/                  AppPalette (light/dark tokens), Material 3 theme, dimens,
                            ThemeModeController ("Apparence", shared_preferences)
    images/logo_images.dart pôle/société logo loader (Bearer, permanent disk cache)
    images/ticket_images.dart ticket attachment loader (Bearer, normal HTTP cache, 7 days)
    layout/adaptive.dart    window size classes, content max width, text-scale clamp, orientations
    storage/catalog_cache_store.dart  last catalog (JSON + ETag) for an instant home at launch
    utils/                  JSON readers, version compare, date / duration / relative-time formats
    widgets/                logo slot, group logo tile, headers, cards, form page, avatar, misc
  data/
    models/                 user, remote config, catalog (sections/groups/tabs/reports/servers),
                            notifications, history, tickets — all with fromJson
    repositories/           CbiRepository (interface), ApiCbiRepository (v1), DemoCbiRepository + fixtures
  features/
    splash/                 CheckAuth: config/ version gate, token → me/ → shell, else login
    auth/                   login screen ("Se souvenir de moi", fingerprint login),
                            SessionController (login, logout, silent re-login, 401 wipe, NTLM password)
    lock/                   LockPolicy (pure decision), AppLockController, AppLockGate
                            (lock screen above the navigator, back guard), lock screen
    shell/                  header, bottom navigation / navigation rail, badge poller, back handling
    home/                   sections (consolidé / group cards with logos, société grid), no-access
    group_tabs/             legacy DirectionFragment (tab per direction)
    reports/                catalog controller (ETag, optimistic favourites), report list rows
    viewer/                 PBIRS WebView, phone/full edition choice, full screen,
                            NTLM host allowlist, open/close + viewing time
    tickets/                "Tickets": list + filters, create (image), detail / conversation,
                            admin status / assignee, two-pane on large screens
    favorites/  notifications/  settings/  history/  about/
test/                       unit + widget tests (see below)
```

State management: `flutter_riverpod` 3 (no code generation). Navigation:
plain `Navigator`; the group tabs are shown inside the shell like the legacy
fragment.

## Theme (3.1)

- Palette of the Portail BI web platform, light and dark (`AppPalette`, a
  `ThemeExtension`; widgets read `context.palette`, no hard-coded colours).
  Flat surfaces with 1px borders (no elevation, no text shadows), radius 14 on
  cards / 10 on inputs and buttons, filled inputs with a green 1.5px focus
  border, green `#A5CF4B` primary buttons with bold `#1C1D22` text, Material 3
  `NavigationBar`, floating snackbars, Roboto (Android system font).
- Theme mode follows the phone by default; **Paramètre → Apparence**
  (Système / Clair / Sombre) applies instantly and is stored in
  `shared_preferences` (`theme_mode`), read before `runApp`.
- Brand images: `*_on_dark` (light lettering) in dark mode, the original
  dark-lettered `portail_bi_logo.png` / `pbi_mark.png` in light mode
  (`AppAssets.loginLogo(brightness)` …). The splash stays dark.

## Behaviour highlights

- **Session**: `auth/login/` returns a token, the user and the NTLM
  `credentials` (`DOMAIN\username`). Token, user, credentials and the password
  are stored with `flutter_secure_storage` (Android Keystore); the password is
  used only to answer PBIRS NTLM challenges. An authenticated `401` first tries
  one silent re-login with the remembered credentials (see below), then wipes
  the session and returns to the login screen. Logout calls `auth/logout/` and
  wipes the session; the last username, the remembered credentials and the app
  lock setting are kept.
- **Se souvenir de moi** (login, on by default): the username and password are
  kept on the device, separate from the session. They prefill the login form
  (the password stays masked and cannot be revealed), enable **Connexion par
  empreinte** when the app lock is on, and allow a **silent re-login** when the
  token expires or is revoked: a single attempt shared by all concurrent
  requests, then the original request is retried once (also at splash). If the
  server answers `invalid_credentials` (AD password changed) the password is
  dropped (username kept) and the login screen says "Votre mot de passe a
  changé. Veuillez vous reconnecter.". Network errors / `429` fall back to the
  normal expiry and delete nothing. Logging in with the box unchecked forgets
  them. A new password typed in the viewer's NTLM prompt updates them.
- **App lock** (Paramètre → Sécurité → "Verrouillage par empreinte", optional,
  offered once after the first login on a phone with a fingerprint): the lock
  screen covers the app at cold start and on resume after the chosen delay
  (Immédiat / 1 / 5 / 15 min, default 1 min). Fingerprint or face, with the
  phone PIN / pattern as fallback. The screen underneath (including an open
  report) keeps its state; the back button is blocked; "Se déconnecter" is
  available on the lock screen.
- **Tickets** (Paramètre → Tickets, the platform's ticket system): list with
  status chips (Tous / Ouvert / En cours / Fermé / Rejeté, labels from
  `tickets/choices/`) and, for admins, "Assignés à moi"; rows show title,
  type, catégorie, priority dot (haute = red, moyenne = amber, basse = grey),
  status pill, creator (admins), relative date and message count. "Nouveau
  ticket" = the web form (titre, description, type, catégorie, priorité,
  optional image from the camera or the photo picker, ≤ 5 MB checked before
  upload), sent as multipart; server field errors appear under the fields.
  Detail: header card (people, dates, description, attachment → zoomable
  full-screen viewer), conversation (mine on the right, others on the left
  with an "Admin BI" badge, image messages) and a composer (text + image).
  Admins (`can_manage`) change the status and the assignee in place
  (optimistic, rolled back with a snackbar on error). Images are fetched with
  the Bearer header and kept in a normal (7-day) cache. The no-access
  "Contacter" link and Aide → "Envoyer une demande" open the form.
- **Adaptive layout**: window classes compact < 600 dp, medium 600–839,
  expanded ≥ 840. Compact: bottom navigation bar; medium / expanded:
  navigation rail with labels (same items, badge). Lists, forms, settings,
  tickets and history are centred at ≤ 720 dp; expanded shows tickets list +
  detail side by side and the settings groups in two columns; on tablets the
  home société grid / pôle rows become wrapping grids (cards keep their
  size). Tablets (shortest side ≥ 600 dp) rotate on every screen; phones stay
  portrait except in the viewer. The system font scale is clamped to 1.3.
  Lists load with skeleton placeholders, and the last catalog saved on the
  device is shown at launch while a fresh one loads in the background.
- **Force update**: `config/` `min_version` above the installed version shows the
  blocking "Mise à jour requise" dialog.
- **Catalog**: one `GET catalog/` feeds home, tabs, lists and favourites; it is
  cached with `If-None-Match` / `304`. Favourites toggle optimistically
  (`PUT`/`DELETE favorites/<id>/`) and roll back on error.
- **Home logos**: pôle / société groups with a `logo_url` show the logo (white
  rounded square, name underneath); the URL is resolved against
  `API_BASE_URL`, fetched with the Bearer header and cached on disk forever
  (the URL is versioned). No logo, still loading or failed → code / initials
  tile.
- **Viewer** (`flutter_inappwebview`): `reports/<id>/open/` once (with
  `reports/<id>/mobile-layout/` in parallel) → load `embed_url`; when the report
  has a **phone edition** (`report.phone`) portrait shows `phone.embed_url`,
  otherwise portrait draws the report's **Power BI mobile layout** (user
  scripts injected at document start, see MOBILE_SETUP.md); landscape shows
  the desktop layout. "Mobile" / "Bureau" switch when a phone edition or a
  phone layout exists (the manual choice sticks for the viewing session;
  switching never calls `open/` again). Long press on the title: hidden
  "Informations techniques" sheet. **Plein écran**: immersive mode, no toolbar, any orientation, a
  floating exit / rotate control (fades to 30% after 3 s). NTLM credentials
  only for `catalog.servers[].host`; `reports/<id>/close/` once with the total
  viewing time (paused in background). Rotation allowed in the viewer only.
- **Notifications**: badge polled every `notification_poll_seconds` while in the
  foreground and on resume; WorkManager polls every 15 min in the background and
  raises local notifications (no Firebase). See [MOBILE_SETUP.md](MOBILE_SETUP.md).

## Images

Brand logos (Portail BI, light and dark variants) are wired through
`lib/core/assets.dart` (`AppAssets`). Pôle / société logos come from the
catalog (`logo_url`); in demo mode Gamma, HPS and Puma use the bundled
`assets/images/legacy/*.png`. Direction codes still show as text
(`AppAssets.codeImages` is empty). Launcher icons are unchanged.

## Tests

`flutter test` covers: catalog JSON parsing (incl. `logo_url`, `phone`), API
client (Bearer, errors, 401 hook, 304/ETag cache), French error mapping,
base-URL validation and URL resolution, version comparison, NTLM host
allowlist (incl. the phone edition host), viewer edition selection
(orientation × phone edition × manual choice), palette tokens and theme mode
persistence / Apparence switch, logo card (image vs initials, error
fallback, Bearer header, permanent cache), login screen texts / validation /
errors / theme-aware logo, home sections and cards, shell navigation and
badge, notification Nouveau/Déjà vu split and background poll logic,
favourite rollback, lock decision (every delay, cold start, no session),
remembered credentials (survive logout, cleared when unchecked, password
changed keeps the username), login "Se souvenir de moi" / prefill /
fingerprint login, silent re-login (single attempt, retry, invalid
credentials, network / 429, waits for the unlock), Sécurité settings with a
fake `BiometricAuth`, lock screen (cold start, resume, back button, logout),
tickets (parsing, filters, form validation incl. size limit and server
errors, admin panel visibility, optimistic status rollback, assignee update,
composer with image, multipart body / file part / Bearer / 401 resend),
adaptive layouts (no overflow at 320 dp × 1.3 and 1024×768 for login, every
shell tab, tickets list / detail / create, history; rail vs bar; two-pane
tickets; two-column settings; wrapping home grid), the cached-first catalog,
and a guard against text shadows / legacy colours.

See [MOBILE_SETUP.md](MOBILE_SETUP.md) for Android, security and release notes.
