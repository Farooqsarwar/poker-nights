# Poker Night

A Flutter web (PWA) companion app for running real-world home Texas Hold'em tournaments. It organizes your poker group (members, RSVPs, guest seats), auto-generates blind structures and payouts from a few parameters, and drives the event itself: live blinds timer, rebuys/add-ons, final table, TV display mode, and a cash-game ledger. It is an operations tool for games played with physical chips around a real table — not an online poker game.

## Feature overview

- **Groups** — create a group, share a join code (or QR), manage member roles, group chat and polls.
- **RSVPs & guests** — members RSVP "going"; each going member can bring named guests who check in from their own device via a guest link/code.
- **Tournament engine** — generates starting stacks, chip plans, a full blind ladder with antes, color-up instructions, prize splits and organizer cut from player count, duration, buy-in and chip set.
- **Live tournament management** — admin dashboard with check-in, seating, start/pause/pause-resume timer, eliminations, rebuy/add-on requests and settlement, final table mode, results podium, lifetime stats.
- **Player & guest views** — players follow the live game from their phones; guests get an event-only view without group access.
- **TV mode** — a code-scoped, read-only projection of the live game for a shared screen.
- **Cash games** — a separate ledger for ring-game sessions with buy-ins, top-ups, cash-outs and reconciliation.
- **Notifications & voice** — in-app/browser notification inbox and text-to-speech announcements for level warnings and eliminations.

## Tech stack

| Concern | Choice |
| --- | --- |
| Framework | Flutter, web-first installable PWA (Android/iOS folders exist but web is the primary target) |
| Backend | Firebase Auth (email/password + anonymous guest sessions) and Cloud Firestore |
| State | `provider` — a single `AppProvider` `ChangeNotifier` |
| Routing | `go_router` with an auth guard |
| Voice | `flutter_tts` announcements |
| Layout | `responsive_framework` + `flutter_screenutil` |
| Codes | `qr_flutter` (display) and `mobile_scanner` (scan) |
| Local recovery | `localstore` crash-recovery snapshots |

See `pubspec.yaml` for the full dependency list.

## Getting started

### Prerequisites

- Flutter SDK (project requires Dart SDK `^3.10.0`, see `pubspec.yaml`)
- A Firebase project with **Authentication** (enable *Email/Password* and *Anonymous* providers) and **Cloud Firestore** created
- Firebase CLI and flutterfire CLI:

```sh
npm i -g firebase-tools
dart pub global activate flutterfire_cli
```

### Configure Firebase

```sh
firebase login
flutterfire configure
```

Select your Firebase project, enable the **web** platform, and accept the defaults — this regenerates `lib/firebase_options.dart` (checked into the repo), the config the app boots with in `lib/main.dart`.

Deploy the shipped security rules before first run:

```sh
firebase deploy --only firestore:rules
```

### Run

```sh
flutter pub get
flutter run -d chrome
```

The app is served as a PWA (`web/manifest.json`, standalone display). Android/iOS builds compile from the same code base but web is the tested target.

### Test and analyze

```sh
flutter test      # unit tests in test/
flutter analyze   # static analysis (flutter_lints)
```

## Environment configuration

| Dart define | Purpose |
| --- | --- |
| `APP_CHECK_RECAPTCHA_SITE_KEY` | Optional. When provided (`--dart-define=APP_CHECK_RECAPTCHA_SITE_KEY=...`), Firebase App Check is activated on web with a reCAPTCHA v3 provider. Without it the app runs normally with App Check dormant. Activation failure never blocks startup. |

Example:

```sh
flutter run -d chrome --dart-define=APP_CHECK_RECAPTCHA_SITE_KEY=your-key
```

## Deployment

`firebase.json` is preconfigured to serve `build/web` from Firebase Hosting with SPA rewrites and cache headers:

```sh
flutter build web
firebase deploy
```

Any static host works the same way (a Vercel project link also ships under `.vercel/`). There are no server-side components to deploy beyond Firestore rules; all logic runs client-side against Firebase.

## Project structure

```
lib/
├── main.dart            App bootstrap: Firebase init, optional App Check, providers, router
├── app/                 Theme, colors, typography, GoRouter setup and route paths
├── constants/           Shared app-wide constants
├── models/              Plain data classes (tournament, live game, cash session, user, ...)
├── providers/           app_provider.dart — the single ChangeNotifier holding UI + domain state
├── repositories/        firebase_repository.dart — the sole Firestore access point
├── responsive/          Breakpoint definitions shared by screens
├── services/            Role projections, offline RecoveryService, browser notifications
├── screens/
│   ├── public/          Landing, auth, splash, join by code, guest flow, TV mode, legal pages
│   ├── shell/           Signed-in app shell: home, group hub, history, stats, presets,
│   │                    chip sets, profile, settings, notifications
│   ├── tournament/      Create → structure review → invitations → check-in → admin dashboard,
│   │                    player live view, rebuy settlement, final table, completion, podium
│   └── cash/            Cash-game setup and live session ledger
├── utils/               Tournament engine, codecs, formatters, voice service, mock data
└── widgets/             Reusable design-system widgets (cards, buttons, modals, timer, ...)
```

Architecture notes (data flow, roles/projections, Firestore layout, concurrency model) live in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
