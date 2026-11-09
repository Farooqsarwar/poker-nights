## WP2 — one stack-first StructureBuilder

Branch `fix/wp2-builder` off `new-implementation` (`abe935f5`). Not merged.

### What it is
One flow (a controller `lib/utils/structure_builder_controller.dart` + a widget `lib/widgets/structure_builder.dart`) used by all three entry points. Routes are unchanged.

| Entry point | Route | Confirm does |
|---|---|---|
| Quick game | `/quick` | creates the night, then starts the clock |
| Create structure (from a group event) | `/structure-review` | saves the structure to the event and confirms it |
| Free blind generator | `/tools/blinds` | asks "Use this structure in the tournament clock?"; yes opens `/tools/clock` with these exact levels (`ToolClockHandoff`) |

Steps:
1. **Inputs** — players (suggested: last headcount; the invited count for an event) · duration or finish time · tournament type Turbo / Normal / Deep (75 / 100 / 150 BB → `targetDepthBB`) with a Custom depth stepper 50–200 in steps of 25 · pace 15 / 20 / 30-min levels · format freeze-out / rebuy / re-entry · rebuys Unlimited / Limited (suggested from player count) · add-on · ante Yes/No then Big blind / Individual (no "Recommended") · on-time bonus % with the chip amount beside it · chip set.
2. **Stack** (before any level) — starting stack (stepper in round-unit steps, or type it), depth in BB, per-player chips, bank check, and the engine's blocked / bank-shortfall / shallow cards. Editing sets `forceStack` and re-runs. "Approve stack".
3. **Structure** — every level row edits inline (SB / BB / minutes). An edited row is pinned and shows a calculator button, "Recalculate around this" (`TournamentEngine.recalculate(params, pins)`): pinned rows keep their typed values, only unpinned levels change. "Rebuys close after this level" can be moved on any row; the structure re-solves (ante start and add-on break follow it) and shows "Fresh stack at L{n}: {x} BB, M {m}". Warnings never block; only `isBlocked` does.

### Persistence (survives Recalculate, leaving the screen, reopening)
`GameSettings` gains `forceStack`, `targetDepthBB`, `levelPins` (new `LevelPin`: level, sb, bb, minutes); a chosen rebuy close uses the existing `rebuyCloseChosenByOrganizer`. All are in the codec. Every Recalculate / Start / check-in regeneration goes through one helper, `solveWithPins` (`lib/utils/builder_solve.dart`), which only composes the existing engine API — **no engine change**. The structure verification audit uses the same helper, so a pinned structure does not fail its own audit.

### Old paths removed
- The quick start that generated and started the clock in one tap (old `QuickStartScreen` body, pace cards, preview cache).
- The "Adjust starting stack" modal and `AppProvider.adjustStructure` (replaced by `applyBuilderResult`).
- The bottom-of-screen "Recalculate structure" dialog and the old Parameters / Blind Structure tabs of the review screen.
- The tool's old generator form (Generate button, quick-settings pills, start-time picker).

### Tests
- New `test/structure_builder_test.dart` (27 tests): stack step before any level at all three entry points; a stack edit survives Recalculate, the codec and reopening; an edited row is pinned and "Recalculate around this" changes only unpinned levels (pinned values exact); moving the rebuy close moves the ante start and the add-on break; a blocked night cannot reach Confirm (Approve disabled, no confirm button, the event refuses to save it); free tool → clock hand-off carries the edited levels; ante has no "Recommended"; the **shallow card is wired and tested** (closes the WP1 known gap); quick game runs on the approved stack.
- `test/engine_invariants_test.dart` is tagged `@Tags(['slow'])`; `dart_test.yaml` declares the tag. CI still runs it (plain `flutter test`); locally use `--exclude-tags slow`.

**Changed existing tests (client-driven: stack-first replaces one-tap generate)**
| Test | Change | Why |
|---|---|---|
| `infeasible_start_guard_test` quick start ×2 | the blocked card and the disabled control are now on the stack step: "Approve stack" disabled / enabled (was "Generate & start the clock") | stack-first |
| `infeasible_start_guard_test` free tools ×2 | go through Next → Approve stack; the placeholder ladder is never shown (no `level-row-1`) and Approve is disabled | stack-first |
| `shallow_warning_test` quick start | the shallow card is asserted on the stack step, and "Skip the add-on" is asserted by the stack changing (the old sentence preview no longer exists) | stack-first |

No existing "2 taps to a running clock" (T113) test exists in the repo, so none changed.

### Decisions I made (none needed an owner answer)
- **Type → depth**: Turbo 75 / Normal 100 / Deep 150 BB (the values the engine's `targetDepthBB` marker already documents), also setting the matching pace style; a custom depth below 100 uses the turbo style, above 100 the deep style. `// OWNER-DECISION`.
- **Rebuy suggestion**: ≤ 8 players Unlimited, 9–14 Limited to 2 each, 15+ Limited to 1 each; follows the player count until the host chooses. `// OWNER-DECISION`.
- **Add-on break**: a night with an add-on gets one 10-minute break after the rebuy window (the engine places it at the close). Host-set breaks win. `// OWNER-DECISION`.
- Changing any setup input drops a forced stack and pins (they were set against the old ladder); the rebuy close choice is kept unless the format becomes freeze-out.
- Pinned rows are exact (the solver otherwise rounds a typed 37/75 to 40/75), and a big-blind ante follows a pinned big blind.
- `AppSegmentedControl` labels are now `Flexible` so a long label ellipsizes instead of overflowing.

### Known gaps / for review
- **Quick game's optional player-name fields are gone** with the old screen (players are added as Player 1…N as before when no names were typed). Say if you want them back inside the builder.
- The review screen's old parameter cards (AI insights panel, "field size suggestion", per-field generation overrides) are not in the builder; the pace proposal card (§10.1) is kept. The overrides still exist on `GameSettings` and the provider.
- Shootout events and games already running show a short notice instead of the builder (stacks are physical once play starts).
- A forced stack is saved against the headcount it was set for; if the check-in headcount differs, the existing start guard (`isBlocked`) still refuses an undealable night.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
