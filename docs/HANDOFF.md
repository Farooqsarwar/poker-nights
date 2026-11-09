# Handoff — WP1 engine + WP2 StructureBuilder

Facts only. Repo `Farooqsarwar/poker-nights`, base branch `new-implementation`.

## Merges
- WP1 `fix/wp1-engine` → merge `abe935f5`. WP2 `fix/wp2-builder` → merge `df2c0f7a` (branches kept).
- PR texts: `pr_body_wp2.md` (repo root); WP1 write-up `docs/analysis/wp1-results.md`.

## Where the builder lives
- Controller (no UI): `lib/utils/structure_builder_controller.dart` — `StructureBuilderController`, `BuilderOptions`, `BuilderMode {quick,event,tool}`, `BuilderStep`, `TournamentType`.
- Engine glue: `lib/utils/builder_solve.dart` — `solveWithPins`, `validatePins` (wraps `TournamentEngine.recalculate`; no engine change).
- Widgets: `lib/widgets/structure_builder.dart` (`StructureBuilder`: inputs → stack → structure), `structure_builder_options.dart` (names, More options), `save_chip_set_offer.dart`.
- Provider: `AppProvider.applyBuilderResult(settings, structure, {confirm})` in `app_provider_tournament.dart`.

## Entry points (routes unchanged)
- `/quick` → `QuickStartScreen` (mode quick; confirm creates the night and starts the clock).
- `/structure-review` → `StructureReviewScreen` (mode event, seeded by `fromSettings`; saves as you go; confirm → `/invitation`).
- `/tools/blinds` → `ToolBlindsScreen` (mode tool, synthetic bank; confirm asks, then `/tools/clock` with `ToolClockHandoff`).

## Persisted (GameSettings + `model_codec.dart`)
- `forceStack`, `targetDepthBB`, `levelPins` (`LevelPin`: level, sb, bb, durationMins), chosen rebuy close = `rebuysCloseLevel` + `rebuyCloseChosenByOrganizer`.
- Honoured by `_engineParamsFor`, `generateFinalStructure`, `_recalculateWithPlayers` and `structure_verification` via `solveWithPins`.
- `GameSettings.copyWith(clearBuilderOverrides: true)` clears expected rebuys/re-entries/add-ons, their chips and the two prices.

## Old review controls → now
- Player count → Players stepper (inputs). Starting stack, "Adjust starting stack" → stack step (type or ± round unit).
- Recalculate dialog → "Recalculate around this" on a pinned row. Edit blinds/minutes → inline row edit.
- Generation params (level length, expected rebuys / re-entries / add-ons, rebuy / re-entry / add-on chips) → More options.
- Paid places, buy-in, KO bounty, organiser %, max per table, rebuy / add-on price → More options.
- Early arrival bonus → inputs (% with chip amount). Field-size suggestion → Rebuys hint + Unlimited/Limited.
- Fix count (+ save as my chips) → stack step. Shallow / blocked / bank-shortfall cards → stack and structure steps.
- Pace proposal (§10.1) → still on `StructureReviewScreen`.
- In-game level edits and the speed recommendation → unchanged (`/t/:id/levels`, `StructureEditor`, `admin_dashboard_screen.dart`).
- Not in the builder: `AiInsightsPanel`, `enableUnlimitedRebuys` button (provider method remains), shootout events (notice + confirm only).

## OWNER-DECISION markers
- `lib/models/tournament.dart:85` depth/blind values · `:108` SHALLOW_WARN_BB = 50 · `:433` turbo 75 / deep depth.
- `lib/utils/tournament_engine.dart:1877`, `:1955` depth band widening, home25 fallback.
- `lib/utils/structure_builder_controller.dart:28` type→depth · `:275` rebuy-limit suggestion · `:311` add-on break 10 min · `:554` custom depth pace style.
- `test/engine_invariants_test.dart:158` MIN_STEP = 1.15.
- Open questions: rebuy close never before L3? · chip valuation vs blind family (client pt 13) · "limit rebuys" as a table-wide cap.

## Tests
- Local: `flutter test --exclude-tags slow` → 1,721 pass, 0 fail (merge tree).
- CI / full: `flutter test` also runs `test/engine_invariants_test.dart` (tag `slow`, 3,840 runs, 11 invariants = 0).
- Builder: `flutter test test/structure_builder_test.dart` (39). Recalc choices: `test/wp2_recalc_choices_test.dart`.
- Level editor: `test/cohost_structure_rules_test.dart`, `route_matrix_test.dart`, `breaks_test.dart` pass.
- Tests regenerate `spec_boards/responsive_audit.txt`; restore with `git checkout -- spec_boards/responsive_audit.txt`.

## Analyze
- `flutter analyze --fatal-infos`: 14 infos baseline (isAdmin deprecations ×11, avoid_print ×2, prefer_initializing_formals ×1). Any new one fails CI.
- Local SDK 3.38.9; CI pins 3.44.7. `edit_chip_set_screen.dart` `onReorder` edit and `pubspec.lock` are local-only; never commit them.

## Known gaps
- A forced stack is saved for the headcount it was set for; a different check-in headcount can make it undealable (start guard refuses).
- Quick-game names are positional; blank rows are skipped.
