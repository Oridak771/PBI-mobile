# GSH - CBI (mobile)

Flutter Android app (version **4.0.0+12**, application id
`com.cbi.portal.cbi_mobile`) that lists the Power BI reports a user may access
on the CBI platform and displays them from Power BI Report Server (PBIRS) in a
WebView. It is the revival of the legacy Java app (`gsh-cbi-android-master`,
v2.2 / versionCode 6), redesigned in 4.0 with the Portail BI **glass** style
(approved mockup: `docs/design/portail_bi_glass.png`, source
`docs/design/mockup.html`), light and dark.

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
    widgets/                glass system (glass.dart), report icon tiles, logo slot, group logo,
                            headers, cards, form page, avatar, skeletons
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
    shell/                  floating glass tab bar / glass rail, notifications poller, back handling
    home/                   greeting + bell, search field, Récents (history/), section chips,
                            group grid (logos), no-access
    search/                 instant local search over the catalog (name / location)
    group_tabs/             group screen (header, "Tous" + direction chips, one report panel)
    reports/                catalog controller (ETag, optimistic favourites), report rows / panel
    viewer/                 PBIRS WebView, phone/full edition choice, full screen,
                            NTLM host allowlist, open/close + viewing time
    tickets/                "Tickets": list + filters, create (image), detail / conversation,
                            admin status / assignee, two-pane on large screens
    favorites/  notifications/  settings/  history/  about/
test/                       unit + widget tests (see below)
```

State management: `flutter_riverpod` 3 (no code generation). Navigation:
plain `Navigator`; a group is shown inside the shell (above the tab bar) like
the legacy fragment.

## Design: Portail BI glass (4.0)

Reference: `docs/design/portail_bi_glass.png` (approved) and its source
`docs/design/mockup.html`; renders of the implementation (dark: login, home,
group, tickets, 412×892 @2x) are in `docs/design/implementation/`.

- **Background** (`GlassBackground`, `lib/core/widgets/glass.dart`): base
  gradient `#121519 → #0C0E11` with three radial glows (green
  `rgba(165,207,75,.55)` top-right, teal `rgba(38,166,154,.40)` mid-left, blue
  `rgba(124,196,232,.32)` bottom-right), painted once per screen behind its
  own `RepaintBoundary`, no animation.
- **Glass surfaces** (`GlassPanel`): white 14% → 4% gradient (135°), 1px white
  16% border, 1px white 28% inner top highlight, soft `0 10 30` shadow drawn
  outside the surface (stacked translucent rects, no mask filter). Radius 20
  (cards), 24 (list panels, sheets), 22–32 (pills, tab bar).
  `blur: true` adds a `BackdropFilter` (blur 22 + saturation 170%) and is used
  **only on static chrome**: floating tab bar / rail, search fields, segmented
  chip bars, round header buttons, login panel, viewer toolbar buttons and
  toggle, sheets, bottom bars. Cards inside scrolling lists and grids use the
  same look without blur (smooth scrolling on mid-range Android).
- **Accent**: green `#A5CF4B`; primary buttons and selected chips use the
  vertical gradient `#B6DD62 → #93BF3A`, dark text `#10140A`, white 35% border,
  inner highlight and a green glow (`GradientButton`, `GlassChip`,
  `GlassSegmentedBar`). Text `#F5F6F8`, muted `rgba(235,238,243,.62)`, green
  text `#B9E06A` / `#C8EA82`.
- **Typography**: Roboto (system font), bold titles with a slight negative
  letter spacing (page titles 24, names 16–17, rows 13–13.5 semi-bold, meta
  10–11 muted). No text shadows (guarded by `test/no_text_shadow_test.dart`).
- **Report icon tiles** (`ReportIconTile`): 40×40, radius 13, green / blue /
  amber tint at 22%; icon and tint picked deterministically from the report
  name (business keywords, then a stable FNV hash) among bar chart, pie, line,
  receipt, truck, users, map.
- **Light mode**: same language on `#F3F5F8` with weaker glows, white 60–72%
  frosted glass, text `#1B1E24`, muted `#5F6168`, green text `#5E8A1F`.
- Theme mode follows the phone by default; **Profil → Apparence**
  (Système / Clair / Sombre) applies instantly and is stored in
  `shared_preferences` (`theme_mode`), read before `runApp`.
- Brand images: `*_on_dark` (light lettering) in dark mode, the dark-lettered
  `portail_bi_logo.png` / `pbi_mark.png` in light mode
  (`AppAssets.loginLogo(brightness)` …). The splash stays dark.

### Screens

- **Login**: full Portail BI logo (~220 wide, theme-aware), "Vos tableaux de
  bord, partout", one blurred glass panel (identifier, password with eye
  toggle and green focus border, "Se souvenir de moi", gradient "Se
  connecter" + square glass fingerprint button when fingerprint login is
  available), footer "Cellule Business Intelligence · GSH".
- **Shell**: floating glass tab bar (16 from the sides, 18 from the bottom,
  64 high, radius 32) with **Accueil / Favoris / Tickets / Profil**; the
  selected tab is a lit glass pill with a green icon and label. Tablets keep a
  `NavigationRail` inside a floating glass panel. Scrolling content reserves
  room for the bar (`BottomBarInset`).
- **Accueil**: avatar (photo or green gradient initials), "Bonjour" + first
  name, bell (glass circle, green dot when unread) → notifications screen;
  blurred search field → instant local search of every catalog report by name
  or location (accent / case insensitive); "Récents" = up to 6 distinct
  reports of `GET history/` still in the catalog ("Tout voir" → full history);
  pinned blurred chip bar of the catalog sections (first selected) and a
  3-column grid (more on tablets) of group cards (logo, name, "N rapports";
  consolidé = its direction tabs). Pull-to-refresh, skeletons, cached catalog
  first and the no-access state are kept.
- **Group**: round glass back button, logo, name, "parent · N rapports";
  chips "Tous" + direction codes (replace the tabs; a consolidé card preselects
  its direction); reports in one glass list panel: icon tile, name, meta line
  ("Vue mobile · DCO" with a phone icon when `has_mobile_layout` or a phone
  edition, else "DFC · mis à jour hier"), heart (green when favourite,
  optimistic).
- **Favoris**: glass list panels grouped by location.
- **Tickets** (tab): title + gradient "Nouveau", blurred segmented filter
  (Tous / Ouverts / En cours / Fermés / Rejetés, + "Assignés à moi" for
  admins), glass ticket cards (status pill, "type · catégorie", relative date,
  title, glowing priority dot, assignee, attachment / message indicators).
  Detail and creation screens use glass panels and a blurred bottom bar.
- **Profil** (former Paramètre): profile card, Activité (Historique),
  Sécurité, Apparence, Assistance (À propos, Aide), logout.
- **Viewer**: only the toolbar (round glass buttons) and the Mobile / Bureau
  toggle (blurred segmented pill) were restyled; the WebView, phone layout and
  scripts are unchanged.

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
- **App lock** (Profil → Sécurité → "Verrouillage par empreinte", optional,
  offered once after the first login on a phone with a fingerprint): the lock
  screen covers the app at cold start and on resume after the chosen delay
  (Immédiat / 1 / 5 / 15 min, default 1 min). Fingerprint or face, with the
  phone PIN / pattern as fallback. The screen underneath (including an open
  report) keeps its state; the back button is blocked; "Se déconnecter" is
  available on the lock screen.
- **Tickets** (the Tickets tab, the platform's ticket system): list with
  a segmented status filter (Tous / Ouverts / En cours / Fermés / Rejetés,
  statuses from `tickets/choices/`) and, for admins, "Assignés à moi"; rows show title,
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
tickets; two-column settings; wider home grid on tablets), the cached-first
catalog, the glass design (4 tabs, bell → notifications, home search and
récents, group chips filter, `has_mobile_layout` parsing and "Vue mobile" meta,
blur only on static chrome, deterministic icon tiles, theme-aware login logo)
and a guard against text shadows / legacy colours.

See [MOBILE_SETUP.md](MOBILE_SETUP.md) for Android, security and release notes.
