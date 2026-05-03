# Barfum (عطري) — Agent Guide

Barfum is a Flutter mobile application for Arabic-speaking fragrance enthusiasts. It provides perfume discovery, personal collection tracking, occasion-based recommendations, and a community feed. The app targets iOS and Android with an Arabic right-to-left (RTL) interface and a bespoke gold/oud/cream visual identity.

## Technology Stack

- **Frontend**: Flutter (Dart SDK ^3.11.5)
- **Backend / Database**: Supabase (PostgreSQL, Auth, Realtime, Storage)
- **Data Import / Scraping**: Python 3.13 + Playwright + `supabase` Python client
- **Target Platforms**: iOS, Android, macOS, Windows, Linux, Web

## Project Structure

```
lib/
  main.dart                 # App entry point, auth gate, bottom-nav shell
  theme.dart                # Color palette, typography (Google Fonts), shadows
  models/
    perfume.dart            # Perfume, FragranceNote, and hard-coded demo data
  data/
    fragdb_repository.dart              # Offline CSV asset loader
    supabase_fragrance_repository.dart  # Remote fragrance queries
    user_collection_repository.dart     # User collection CRUD
    community_repository.dart           # Feed, posts, reviews, profiles
  screens/
    auth_screen.dart
    onboarding_screen.dart
    home_screen.dart
    detail_screen.dart
    collection_screen.dart
    add_screen.dart
    occasion_screen.dart
    community_screen.dart
    price_tracker_screen.dart
    profile_screen.dart
  widgets/
    bottle_icon.dart        # CustomPaint perfume bottle icon
    star_rating.dart        # 5-star rating row

scripts/
  requirements.txt
  import_fragrance_csv_to_supabase.py   # CLI: CSV → Supabase
  fragrantica_to_supabase.py            # CLI: Fragrantica scrape → Supabase
  barfum_tools/
    __init__.py
    common.py               # Logging, env helpers, Supabase client factory
    csv_importer.py         # CSV parsing, row transformation, popularity scoring
    fragrantica_scraper.py  # Playwright scraper with stealth / scroll logic
    supabase_writer.py      # Batch upsert helper

assets/fragdb/
  fragrances.csv            # Bundled offline fragrance database
  notes.csv                 # Fragrance note metadata
  brands.csv

sql/
  fragrances_schema.sql     # Full Supabase schema (tables, indexes, RLS, triggers)
```

## Build and Run Commands

### Flutter

```bash
# Install dependencies
flutter pub get

# Run locally with Supabase credentials
flutter run --dart-define-from-file define.json

# Run tests
flutter test

# Analyze
flutter analyze
```

The app reads Supabase credentials from compile-time environment variables (`--dart-define`). `define.json` at the repo root contains the real credentials; `.env.example` shows the expected keys. The VS Code launch configuration (`.vscode/launch.json`) already passes `--dart-define-from-file define.json`.

When Supabase is unavailable (missing credentials or network failure), the app gracefully falls back to the bundled `assets/fragdb/` CSV files for read-only browsing.

### Python Scripts

The scripts live under `scripts/` and expect a virtualenv at `scripts/.venv/`:

```bash
# CSV import
cd scripts
.venv/bin/python import_fragrance_csv_to_supabase.py --csv /path/to/fra_cleaned.csv

# Fragrantica scraper
.venv/bin/python fragrantica_to_supabase.py --target-count 1000
```

Both scripts read `SUPABASE_URL` and `SUPABASE_KEY` from a `.env` file inside `scripts/` or from the environment.

## Architecture Overview

### Data Layer (Repository Pattern)

All remote data access goes through repository classes injected into the app shell in `main.dart`:

- `FragDbRepository` — parses `assets/fragdb/fragrances.csv` and `notes.csv` at startup for offline use.
- `SupabaseFragranceRepository` — queries the `fragrances` table (trending, search, accord filters, occasion matching, pagination).
- `UserCollectionRepository` — upserts `user_collections` rows (`owned` | `wish` | `tested`).
- `CommunityRepository` — loads community feed, reviewer leaderboards, and user profile stats.

### State Management

The project uses plain Flutter `StatefulWidget`s and `FutureBuilder`. There is no BLoC, Riverpod, or Provider dependency; state is held in `_AppShellState` and passed down via constructor callbacks.

### Navigation

The app uses a single `Scaffold` with an `IndexedStack` driven by a custom bottom navigation bar (5 tabs: استكشف / مجموعتي / تقويم / مجتمع / أنا). Detail and add screens are displayed by swapping the root body widget, not by pushing routes.

### Authentication

Supabase Auth with email/password. A custom deep-link scheme (`com.novaparfum.barfum://login-callback/`) is registered for mobile redirects. On successful auth, `AuthGate` rebuilds and shows `AppShell`.

### Database Schema

See `sql/fragrances_schema.sql` for the canonical schema. Key tables:

- `fragrances` — catalog (RLS not required; publicly readable).
- `users` — public profile mirror of `auth.users`, auto-populated via trigger `on_auth_user_created`.
- `user_collections` — per-user perfume status.
- `reviews` — ratings + text reviews.
- `posts` — community feed posts.

All user-data tables have Row Level Security policies restricting write access to the owning user and read access according to feature needs (e.g., reviews and posts are publicly readable).

## Code Style Guidelines

- Dart code follows `package:flutter_lints/flutter.yaml` (configured in `analysis_options.yaml`).
- Prefer `const` constructors where possible.
- Widgets are organized as `lib/screens/` for pages and `lib/widgets/` for reusable pieces.
- Arabic text is embedded directly in widget files; there is no localization layer yet.
- Typography uses `GoogleFonts.notoSansArabic` for Arabic and `GoogleFonts.playfairDisplay` for Latin/serif accents.
- Colors are centralized in `theme.dart`; do not hard-code palette values in screens.

## Testing

- `test/widget_test.dart` contains a single smoke test that verifies the app widget renders a `MaterialApp`.
- There is no integration test suite or unit test coverage for repositories at this time.

## Security Considerations

- `define.json` and `.env` contain live Supabase credentials and are `.gitignore`d. Never commit them.
- The iOS `Info.plist` contains a Google OAuth URL scheme; keep the bundle identifier consistent.
- Supabase RLS policies enforce that users can only modify their own `user_collections`, `reviews`, and `posts`.
- The Python scraper uses `playwright-stealth` and random delays to reduce bot detection; respect target site terms of service.

## Offline Fallback Behavior

If `SUPABASE_URL` / `SUPABASE_ANON_KEY` are not provided at compile time, `kSupabaseReady` stays `false` and the app:

1. Skips auth (no login screen).
2. Loads perfumes from `FragDbRepository` (local CSV).
3. Disables search, collection saving, occasion finder, community, and profile stats.
4. Still allows browsing the home grid and viewing static detail data.

## Asset Notes

- `assets/fragdb/` is declared in `pubspec.yaml` under `flutter: assets:`.
- The CSVs use pipe (`|`) delimiters and may contain quoted fields; `FragDbRepository` includes a custom pipe-CSV parser.
