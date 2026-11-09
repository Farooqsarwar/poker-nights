# How the Spec Boards Are Made

Every PNG in `spec_boards/` is generated, not hand-drawn. Pipeline:

```
tool/board_fixtures.dart          dummy Friday-night dataset + screen registry
        ↓ imported by
tool/capture_boards_test.dart     pumps REAL widgets, screenshots them
        ↓ writes 92 PNGs to
spec_boards/{mobile,desktop}/captures/      raw, pixel-exact, nothing drawn on them
        ↓ read by
tool/generate_formfactor_boards.py          cards + flow boards + masters + dashboard
        ↓ writes
spec_boards/{mobile,desktop}/{cards/,FLOW_*.png,MASTER_*.png} + MASTER_SPEC_MAP.html
```

Re-run everything:

```bash
flutter test tool/capture_boards_test.dart
python tool/generate_formfactor_boards.py
python tool/refresh_legacy_boards.py   # refreshes doc/spec_mappings/ too
```

> `doc/spec_mappings/` (screens, flows, master) is the legacy location and is
> refreshed from the same exact captures by `tool/refresh_legacy_boards.py`,
> so old and new never disagree. `spec_boards/` is the current home.

## 1. Captures — real widgets, dummy data (`tool/capture_boards_test.dart`)

For each of the 46 screens, the harness builds the **actual production widget**
(the same classes in `lib/screens/`) inside a `MaterialApp.router` with:

- a real `AppProvider` (same state class the app runs),
- a stub `GoRouter` with one route (`/`), so `context.go` calls never crash,
- a `Scaffold` with the app ground `#0A0A0A` for shell screens (mirrors `ScreenShell`),
- the shipped red theme + real Space Grotesk fonts (preloaded from `assets/google_fonts/`),
- viewport fixed per factor: **mobile 390×844 @2x**, **desktop 1440×900 @1x**.

Each screen is pumped, left 800 ms to settle (fonts awaited), then shot through a
`RepaintBoundary` → PNG. Splash waits 3200 ms to land on the wordmark face.

### Dummy dataset (`tool/board_fixtures.dart`)

One seeded Friday night, shared by every screen:

| Data | Content |
|---|---|
| Users | Alice (admin, stats 24/5/9, avg 4.2, 31 KO) + Bob, Carol, Dave, Eve, Frank |
| Group | "Friday Poker Club", code FP2608, 6 members, 2 chat messages, 1 poll (3 votes), live + finished game |
| Players | 9 (stacks 42000→9500, tables 1/2, seats 1–9, 6 going / 2 maybe / 1 can't, 6 checked in) |
| Games | per-screen status: published (invite/structure), checkin, running (admin/player), rebuypause (rebuys), finaltable, completed (finish/podium) |
| Cash | "Friday Cash 1/2" session, 5 players, one cashed out |
| Inbox | 2 notifications via `pushNotification` (offline-safe) |
| Auth forms | filled dummy input (Alex Morgan / alex@pokernight.app / Demo1234!), consent boxes ticked, never submitted |
| TV | live game projected → real running scoreboard |

Per-screen exceptions go to `spec_boards/capture_log.txt` (expect: all clean).
Known honest limit: `01_08` join-group shows the offline branch ("Invalid Invitation") —
the preview card needs the live `joinCodes/{CODE}` backend lookup.

One test-only app tweak supports this (no production effect): `setCurrentGroupForTesting`
marks the injected bundle loaded, otherwise hub screens spin on bundle-loading forever offline.

## 2. Boards (`tool/generate_formfactor_boards.py`)

Per factor (mobile cards 4/row, desktop 2/row):

- **Card** = header (screen id, spec ref, title, route, FLOW pill, VERIFIED pill)
  + screenshot in a device frame — phone bezel with status bar, laptop browser chrome
  with route pill (chrome lives *outside* the pixels; the shot itself is only scaled)
  + legend strip + numbered requirements checklist (full wrapped text, PASS column)
  + traceability footer (source capture path).
- **Rules enforced by asserts**: no drawing on screenshots, no truncated text, no text
  crossing into the PASS column — any violation fails the script loudly.
- **Flow boards** (6 per factor) + **master poster** (cover with stats + all flows).
- **Dashboard** (`MASTER_SPEC_MAP.html`, works offline): Mobile/Laptop toggle, flow
  filter, free-text search, per-card How-to-verify steps, raw-capture links, boards
  gallery with dimensions, and a clickable **spec § index** (56 refs → screens).

## 3. Trust checks

- `spec_boards/capture_log.txt` — per-screen capture status (90+ clean expected).
- `spec_boards/responsive_audit.txt` — 46 screens × 6 viewports overflow audit.
- Pixel proof: cropping a card's shot region reproduces the scaled capture byte-for-byte
  (verified in-session for mobile + desktop samples).
- `flutter test` (repo suite) stays green — board tooling lives in `tool/` + `test/` helpers
  and never ships in the app.
