# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository structure

This repo contains two independent apps that share one Supabase project as their backend:

- **Root (`lib/`, `android/`, `ios/`, etc.)** — the Flutter mobile app "Tamil Business Tribe" (package name `moble_app`).
- **`admin-app/`** — a standalone Node/Express admin panel (CRUD UI + REST API) used to manage the Supabase content that the mobile app reads. It is a separate deployable, not part of the Flutter build.

They are developed and run independently; changes to one do not require rebuilding the other.

## Commands

### Flutter app (run from repo root)
- Install deps: `flutter pub get`
- Run app: `flutter run`
- Analyze/lint: `flutter analyze`
- Run all tests: `flutter test`
- Run a single test file: `flutter test test/podcast_test.dart`
- Build Android release: `flutter build apk`

### Admin app (run from `admin-app/`)
- Install deps: `npm install`
- Start server: `npm start` (runs `node server.js`, default port 5000, configurable via `PORT` env var)
- Requires `admin-app/.env` with `SUPABASE_URL` and `SUPABASE_KEY` (service-role key, since the server does writes the anon key can't do).
- No test suite or lint script defined for this app.

## Architecture

### Flutter app

- **Flat file layout, no feature folders.** Every screen/module lives directly under `lib/` as one large file per feature area (e.g. `profile.dart` ~6.4k lines, `main.dart` ~4.8k lines, `task.dart`, `podcast.dart`, `ebooks.dart`, `community.dart`). When editing a feature, expect to find all of its screens, dialogs, and helper widgets in that one file — use `Grep` for the specific `class` rather than trying to read the whole file.
- **`main.dart`** contains: app bootstrap (`main()`), `SessionManager` (login-state persisted to a local file, not real auth), `ThemeManager` (dark/light persisted to a local file, default dark), the video splash screen, the home feed (`PostPopupScreen`), the login/signup/forgot-password screens, and — at the very bottom — the `ThemeContext` extension on `BuildContext` (`context.textColor`, `context.cardBg`, `context.borderCol`, `context.scaffoldBg`, `context.isDark`, `context.themeGradients`, etc.). This extension is the app-wide theming mechanism; use it instead of hardcoding colors in new UI.
- **No authentication system.** There is no Supabase Auth (or any auth) integration — "login" only flips a boolean flag written to a local file via `SessionManager`. Don't assume `Supabase.instance.client.auth` has a real session.
- **Data access pattern:** newer modules (Podcast, E-books) use a singleton service class (`PodcastService.instance`, `EBookService.instance`) that talks directly to Supabase via `supabase_flutter` and returns plain `Map<String, dynamic>` (no model classes). `EBookService` explicitly mirrors `PodcastService`'s structure and reuses its per-device anonymous UUID (stored via `shared_preferences`) as the "user id" for library/progress/bookmarks, since there's no real auth. Follow this same pattern for new Supabase-backed features rather than introducing model classes or a different data layer.
- **`home_carousel` (in `main.dart`)** is the one place that also wires up a Supabase Realtime subscription (`onPostgresChanges`) to live-update content pushed from the admin app, in addition to a manual poll timer as a backup.
- **Morning Ritual habits/buttons config is fetched over plain HTTP from the admin-app server** (`_fetchDynamicHabits` in `main.dart`), not Supabase — it tries a hardcoded LAN IP (`192.168.0.123`), then `localhost`/`127.0.0.1`, then `10.0.2.2` on Android emulator, against `admin-app`'s `/api/habits` and `/api/buttons_config` endpoints on port 5000. This only works when the admin server is reachable on the same network as the device; it silently fails otherwise (by design — wrapped in try/catch, falls back to hardcoded defaults).
- **Supabase project URL/anon key are hardcoded** in `main.dart`'s `main()` (not read from env/config) — this is intentional for this project since only the anon key is embedded client-side.
- **Global mutable state without a state-management library:** e.g. `communityPosts` (top-level list in `community.dart`) is mutated directly and persisted to a local JSON file (`savePostsToLocal`/`loadPostsFromLocal`); there's no Provider/Bloc/Riverpod in this codebase. `PodcastPlayerController` (a `ChangeNotifier`) is the one exception, used to keep podcast playback state/mini-player alive across screens.
- **`ConnectivityWrapper`** (`connectivity_wrapper.dart`) wraps the app to show a no-internet overlay; check it when debugging connectivity-related UI issues.
- **`packages/native_glass_navbar`** is a local Flutter package (path dependency via `dependency_overrides` in `pubspec.yaml`) providing the custom bottom nav bar — edit it directly if the nav bar needs changes, it's not pulled from pub.dev.
- Firebase (Core + Messaging/FCM) is initialized in `main()` before Supabase; `firebase_notification_service.dart` owns all FCM setup, token retrieval, and foreground/background message handling. `firebase_options.dart` is generated (FlutterFire) — regenerate via FlutterFire CLI rather than hand-editing if platform config changes.

### Admin app (`admin-app/`)

- Single-file Express server (`server.js`, ~1150 lines) with no router/controller split — all routes are defined inline as `app.get/post/put/delete(...)` handlers, each doing a direct Supabase query via `@supabase/supabase-js` and returning JSON.
- Serves a static vanilla HTML/CSS/JS admin UI from `admin-app/public/` (single large `index.html`) — no frontend build step or framework.
- Covers CRUD for: community posts (with approval flow), home carousel, podcast categories/series/episodes (+ per-user progress/continue-listening), ebook categories/books/banners (+ bookmarks/reading progress), plus the mobile app's `/api/habits` and `/api/buttons_config` endpoints (used for the LAN-polling flow described above).
- `*_dashboard` endpoints aggregate stats for the admin UI (e.g. `/api/podcast_dashboard`, `/api/ebook_dashboard`).
- `.sql` files at the `admin-app/` root (`home_carousel.sql`, `podcast_schema.sql`, `ebook_schema.sql`, `seed.sql`) are the reference schema/seed definitions for the corresponding Supabase tables — consult them when a query needs a column you can't find, rather than guessing the schema.
