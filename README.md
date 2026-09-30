# GSH - CBI (mobile)

Flutter Android app (version **3.0.0+7**, application id
`com.cbi.portal.cbi_mobile`) that lists the Power BI reports a user may access
on the CBI platform and displays them from Power BI Report Server (PBIRS) in a
WebView. It is the revival of the legacy Java app (`gsh-cbi-android-master`,
v2.2 / versionCode 6): same colours, sizes, layouts and French texts, with a
modern code base.

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
  main.dart                 portrait lock + ProviderScope + CbiApp
  app.dart                  MaterialApp, global 401/logout → login, Riverpod retry policy
  core/
    assets.dart             AppAssets registry (all image slots, currently empty)
    providers.dart          config, storage, api client, repository, app version, config/, photos
    config/app_config.dart  dart-defines, v1 URL building, base-URL validation
    api/api_client.dart     http wrapper: Bearer, JSON, {"detail","code"} errors, 304, onUnauthorized
    errors/app_exception.dart  ApiException / NetworkException + French messages
    storage/session_store.dart flutter_secure_storage (Keystore) + shared_preferences
    theme/                  legacy colours, dimens, text shadows, Material theme
    utils/                  JSON readers, version compare, date / duration / relative-time formats
    widgets/                logo & code image slots, headers, legacy dialog, avatar, misc
  data/
    models/                 user, remote config, catalog (sections/groups/tabs/reports/servers),
                            notifications, history, tickets — all with fromJson
    repositories/           CbiRepository (interface), ApiCbiRepository (v1), DemoCbiRepository + fixtures
  features/
    splash/                 CheckAuth: config/ version gate, token → me/ → shell, else login
    auth/                   login screen, SessionController (login, logout, 401 wipe, NTLM password)
    shell/                  header, bottom navigation, badge poller, back handling
    home/                   sections (consolidé cards, rows, société grid), no-access state
    group_tabs/             legacy DirectionFragment (tab per direction)
    reports/                catalog controller (ETag, optimistic favourites), report list rows
    viewer/                 PBIRS WebView, NTLM host allowlist, open/close + viewing time
    favorites/  notifications/  settings/  history/  about/  tickets/
test/                       unit + widget tests (see below)
```

State management: `flutter_riverpod` 3 (no code generation). Navigation:
plain `Navigator`; the group tabs are shown inside the shell like the legacy
fragment.

## Behaviour highlights

- **Session**: `auth/login/` returns a token, the user and the NTLM
  `credentials` (`DOMAIN\username`). Token, user, credentials and the password
  are stored with `flutter_secure_storage` (Android Keystore); the password is
  used only to answer PBIRS NTLM challenges. Any authenticated `401` wipes the
  session and returns to the login screen. Logout calls `auth/logout/` and wipes
  everything except the last username (prefilled on the login screen).
- **Force update**: `config/` `min_version` above the installed version shows the
  blocking "Mise à jour requise" dialog.
- **Catalog**: one `GET catalog/` feeds home, tabs, lists and favourites; it is
  cached with `If-None-Match` / `304`. Favourites toggle optimistically
  (`PUT`/`DELETE favorites/<id>/`) and roll back on error.
- **Viewer**: `reports/<id>/open/` → load `embed_url`; NTLM credentials only for
  `catalog.servers[].host`; `reports/<id>/close/` with the viewing time
  (paused in background). Landscape allowed in the viewer only.
- **Notifications**: badge polled every `notification_poll_seconds` while in the
  foreground and on resume; WorkManager polls every 15 min in the background and
  raises local notifications (no Firebase). See [MOBILE_SETUP.md](MOBILE_SETUP.md).

## Pending: images

No image asset is wired yet. Every image slot of the legacy app goes through
`lib/core/assets.dart` (`AppAssets`) and falls back to text (tile/tab code in
upper case, "GSH"/"CBI" text logos). The existing files in `assets/images/`
are kept; to wire one, set the slot in `AppAssets` (see the doc comment there).
Launcher icons are unchanged.

## Tests

`flutter test` covers: catalog JSON parsing, API client (Bearer, errors, 401
hook, 304/ETag cache), French error mapping, base-URL validation, version
comparison, NTLM host allowlist, login screen texts/validation/errors, home
sections and consolidé cards, shell navigation and badge, notification
Nouveau/Déjà vu split and background poll logic, favourite rollback.

See [MOBILE_SETUP.md](MOBILE_SETUP.md) for Android, security and release notes.
