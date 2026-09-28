# POKER NIGHT — BUILD SPECIFICATION

**Version 3.1 · 27 September 2026** (v3.0 of 26 September, audited and corrected — every change is listed in §G4)

**One document to build the whole app: flows, screens, architecture, algorithms and acceptance tests.**

This document replaces both *Architecture Reference v2.8.0* (draft) and *Complete Product Specification v19*. Nothing in those two files, or in any earlier version, should be read any more; where they disagree with this one, this one wins. Everything that is still true in them has been carried over here, updated to the engines and the mock as they stand today.

**Who it is for.** The developers building the app (data model, state machines, algorithms, edge cases) come first. The designers checking screens against the redesign board are covered by Part B and by the "Board" line on every screen in Part D.

**The four sources, and which one wins for what.**

| Question | Source that decides | Where |
|---|---|---|
| What a screen **looks like** (layout, components, spacing, type, iconography) | The redesign board — *App redesign project.pdf* | project root; tiles in `research/redesign/tiles/` |
| What a screen **does** (flows, fields, defaults, rules, states, copy intent) | **This document** | here |
| The **maths** (blind structure, chip plans, payouts, ICM, deals, seasons, settle-up) | The two reference engines and their test vectors | `research/structure_engine.js` (759 tests) · `research/payouts_engine.js` (55 tests) |
| How a flow **feels** when you tap through it | The interactive mock | https://claude.ai/artifact/Gk8uzG9cY5bWNS8iXpqkjx · source `mockup/index.html` · 145 behaviour tests in `mockup/tests.js` |

Two hard rules follow from that table:

1. **Never copy the look from the mock.** Only two screens of the mock (the shell and the live dashboard) have been rebuilt in the board's style so far. Every other mock screen shows the right behaviour in the old visual style. Build the look from the board, the behaviour from this document.
2. **Never re-derive the maths from prose.** Port the two engines to Dart line for line and make them pass the same test vectors. The prose in Part F explains the engines; if the prose and the code ever disagree, the code and its tests win, and the prose is a bug to report.

**How to read a screen in Part D.** Every screen has the same blocks:

- **Board** — the board's screen ID (e.g. `C5`) and its name. "Not on board" means the board has no such screen; build it from the design system in Part B.
- **Mock** — the mock screen ID (e.g. `timer`) you can open to try the flow.
- **Route · Who** — the app route and which roles can open it.
- **Purpose** — one sentence.
- **Layout** — the components, top to bottom, in board vocabulary.
- **Fields** — every input: type, default, range/step, rule.
- **Actions** — every button: what happens, which engine call, which state changes.
- **States** — empty, loading, error, offline, locked, premium, and anything specific.
- **Rules** — edge cases and the reasons behind non-obvious choices.
- **Acceptance** — the checks that prove it is done, with the mock test IDs (`T1`–`T145`, listed in §G2).

**Two kinds of reference.** A bare ID is a **screen** from the board: `C5` is the live dashboard, `E4` the ICM calculator, `F2` Settings. An ID with **§** is a **section** of this document: `§A5` the board-vs-owner table, `§C3` the route guard, `§E9` is sync and authority, `§F2.1` the payout split, `§G3` the open decisions. `D1`–`D15` are the owner's decisions (§A4), `O1`–`O17` open decisions (§G3), `T1`–`T145` mock tests (§G2).

**Certainty tags.** Where a number or rule is not settled fact, it is tagged: **[Sure]** primary source or verified arithmetic · **[Probable]** strong inference from several sources · **[Hypothesis]** a design choice to confirm with real games.

---

## What each part covers

- **Part A — Read this first:** what the app is, scope, how to build and verify, the owner's decisions, where the board and the owner disagree, glossary.
- **Part B — Design system:** tokens, logo, components, rules (their board plus the owner's non-negotiables).
- **Part C — Navigation and shell:** top bar, five tabs, drawer, More sheet, desktop sidebar, guest shell, the full route table.
- **Part D — Flows and screens:** every screen, in the board's order (A onboarding · B group hub · C hosting a tournament · D cash and TV · E tools · F account · G premium · H legal), plus the screens the board is missing.
- **Part E — Architecture:** platform, layers, domain model, storage, identity, permissions, lifecycle, sync and authority, notifications, sound, TV, integrity, stats, privacy, input safety, and every automatic behaviour in one table (§E17).
- **Part F — The engines:** every algorithm with its maths, constants and worked examples.
- **Part G — Reference:** constants, the acceptance-test catalogue, open decisions, change log, known gaps in the mock and the engines.

## Where to start

| You are… | Read, in this order |
|---|---|
| **Building the Flutter UI** | Part A → Part C (shell, routes, guard) → your Part D section → Part B for tokens and components as you go → §E17 for everything the screen does on its own |
| **Porting the engines** | §A3 (point 1) → Part F end to end → run both reference suites (§G2.1) → then the screens that call the engines |
| **Building the backend** | Part A → Part E (model, storage, rules, sync, automations) → §G3 open decisions |
| **Checking designs against the board** | Part B → the **Board** line of every screen in Part D → §A5 (where the board is overridden) |
| **Testing** | §A3 (definition of done) → §G2 (the 145 behaviour tests and the list of behaviours that still need tests) → §E17 (every automation, each with its test) |

The screen index is the route table in §C2 (route · board ID · mock screen · who).

---


# PART A — READ THIS FIRST

## A1. What Poker Night is

Poker Night runs a home poker night end to end. A private group of regulars; a scheduled tournament with RSVPs and a waitlist; a blind structure and chip plan designed from the chips the host actually owns; a clock every device in the room shares; live rebuys, add-ons and eliminations; a prize pool and payouts that reconcile themselves; deals (ICM, chip chop) when the table wants one; a results card and season standings afterwards. It also runs cash games and offers five free calculators that need no account.

Four audiences, one app:

| Audience | What they do | Account |
|---|---|---|
| **The host** | Designs and runs the night. The only role that changes structure, payouts and money settings. | Yes, or none at all for a quick game tonight (A2 "Start a game now", D-C0) |
| **The co-host** | Runs the clock and the table for the host: busts, rebuys, pauses, check-ins. Never structure, payouts or the organiser contribution (D15). | Yes |
| **The players** | RSVP, check in, watch the clock and the prizes, chat, vote. | Members: yes. Guests: no — a link and a name. |
| **The room** | A TV or laptop showing the scoreboard, the payouts and what's next. Read-only, no private money on it. | No — a pairing code. |

**The principle behind every screen:** the host describes *the night they want* — how many people, when it starts, when it must finish, the buy-in, the chips in the case, whether rebuys and an add-on happen — and the app derives everything else: starting stack, which chips each player gets, blinds and level lengths, breaks and colour-ups, rebuy close, paid places and amounts. Every derived value stays overridable, and a host's override is remembered and respected on every recalculation.

## A2. Scope of version 1

**In scope** — everything specified in Part D. In short:

- Accounts (Google or email), the no-account "Start a game now", guests by link.
- Groups: create, join by code/link/QR, invite, members and roles (host, co-host, member), chat, polls, notifications, history, standings, seasons (Premium), import of past results.
- Tournaments: quick start (2 taps) and the planned 5-step wizard; RSVP with plus-ones, deadline and waitlist; check-in with host approval; early-arrival bonus; late arrival; no-show gate; the live dashboard; level editing; rebuys, re-entries, add-ons, pause, bust with "knocked out by", KO bounty; seating with TDA balancing, break-and-redraw, hand-for-hand; bubble, bubble save, deals (ICM, chip chop, equal chop) with confirm-and-end; finish order, results card, share.
- Cash games with a chip ledger and exact "who pays whom".
- TV display (one free), player live view.
- The five free tools.
- Sound and voice (chime, 5- and 1-minute warnings, blinds read aloud as words, one speaker device), haptics.
- Offline play on the host phone, take-over between two phones, restore after a crash.
- Premium: the owner's four items (Part D-G).

**Out of scope for v1** (stated so nobody treats them as missed):

- The app never moves, holds or confirms real money for games. Every money screen is guidance for humans; "paid" is a record the host ticks. (Premium itself is billed through the App Store / Google Play — that is the only real payment in the product.)
- Balancing more than two tables in one global pass, or balancing on dealer-button history. The app recommends the TDA pairwise move; it never moves anybody on its own.
- Manual seat moves beyond the recommended rebalance and the per-table randomise (open decision O6).
- A soft shot clock (a per-decision timer, 30 / 60 / 90 s). It was in the old reference but was never built in the mock; out of v1 unless the owner asks (O13).
- Custom per-place percentages for the payout split. The engine accepts them (`shares`, §F2.1) but no screen exposes them in v1; the host changes only the number of paid places.
- A partial deal ("chop most, play on for the rest" beyond `leaveForWinner`'s engine support) as a UI flow (open decision O7).
- A blind timer for cash games and multi-table cash sessions.
- Progressive and Mystery bounty *payout mechanics* beyond pricing and pot tracking (they are Premium and specified at the level of the pot; see D-C1 step 4 and O8).

## A3. How to build it and prove it's done

**1. Port the engines first.** `research/structure_engine.js` and `research/payouts_engine.js` are pure ES5 functions with no I/O, no clock and a seeded RNG. Port each to a pure Dart library (`lib/engine/structure.dart`, `lib/engine/payouts.dart`), keeping the function names. Then port the test harnesses (`research/structure_engine_test.html`, `research/payouts_engine_test.html`) to `package:test` and make **all 759 + 55 vectors pass** before any screen uses the engines. This is the single step that removes almost every "what did you mean" question about maths.

**2. Treat the mock's 145 behaviour tests as the acceptance contract.** Each test is listed in Part G with an ID (`T1`–`T145`) and referenced from the screens it covers. Write them as widget or integration tests against the app. A screen is done when:

- it matches its board screen (or Part B, where the board has none);
- every field, action and state in its Part D block works;
- its acceptance checks pass, including the global ones: WCAG AA contrast on every text (T102), 44 × 44 px tap targets (T103), left-aligned text (T70), no yellow/gold anywhere (T141), no emoji anywhere.

**3. Suggested order of work** (each step shippable and testable on its own):

1. Engines + vectors.
2. Design system components (Part B) and the shell (Part C).
3. Quick start → live dashboard → levels → players → payouts (a real night can run on this alone).
4. Groups, RSVP, check-in, the wizard, Configure.
5. Seating, bubble, deals, end of night, results.
6. Sync, co-host, take-over, offline, TV, player live view.
7. Cash game, tools, account, settings, sound.
8. Premium, legal pages, onboarding polish.

**Design dependency.** Before the visual pass on any screen, check that its board tile exists (the board covers most of Part D; screens marked "Not on board" have none). Where a tile is missing, build the structure and behaviour from this document with Part B's tokens and components, and re-skin it when a tile arrives. Never block a whole step on one missing tile. §A5 lists where the board is overridden even when a tile exists.

**Environments.** Three Firebase projects — dev, staging, production — each with its own Firestore, Auth, Functions, Remote Config and Crashlytics. CI runs on every pull request: the Dart engine vectors (§G2.1), the widget/integration tests ported from the 145 mock tests, and the Firestore rules tests (§E4). Dev deploys on every merge, staging on release branches, production on a tagged release. The organiser-fee remote flag (§E15) is exercised in staging before any production country turns it on.

**Definition of done, per step.** (1) Engineering: every acceptance test cited on the step's screens passes, plus the engine vectors; no open crash in Crashlytics for the step's flows on staging. (2) Design: each screen checked against its board tile and Part B (colour rule, contrast, left-aligned text, sentence case). (3) Owner: walks the step's flows on staging. Step 8 additionally needs the gaming lawyer's sign-off (D13) before any market launches. Team size, roles and calendar dates are for the owner and the team to set; they are not decidable from this document.

**App-store readiness (before the first submission).** Poker is named in Apple's guideline 5.3.4 ("Apps that offer real money gaming (e.g. sports betting, poker, casino games, horse racing) or lotteries must have necessary licensing…"), and Google Play restricts apps that "facilitate" real-money play. Poker Night takes no bets and moves no money, and the submission must make that plain:
- The first submission ships with the organiser contribution switched off by its remote flag (it is already off by default and behind the legal gate, D13, H4).
- Store listing, screenshots and keywords never say "rake", "cut", "bet" or "gamble"; the review notes say: "A timer, blind-structure and payout calculator for private home games. No wagering, no payments between users, no real-money gaming; buy-ins are recorded, never collected."
- Answer the age-rating questionnaires truthfully (Apple's "Gambling and Contests" and simulated-gambling questions, Google Play's content rating); target 17+ / Mature, and use Play Console's age-restricted-content setting if Google asks for it.
- The privacy labels (Apple App Privacy, Google Data safety) list exactly what H1 lists: account data, game data, Firebase Analytics (usage, identifiers), Crashlytics (diagnostics).
- User-generated content: chat ships with the filter, **Report**, **Block** and published contact details (§E10, Apple 1.2, Google UGC policy) — without them both stores reject a chat app.
- Premium goes through store billing only, validated server-side (G2).
Keep a short record of the answers given, so every later submission stays consistent (O17).

**4. Freeze a baseline.** This document (v3.1) plus mock v35 plus the two engines at their current test counts are the handoff baseline. The files carry no version stamp, so identify them by SHA-256:

| File | Tests | SHA-256 |
|---|---|---|
| `mockup/index.html` (mock v35; its shell has been stable since v33) | 145 in `mockup/tests.js` (`cb781211…c19dc523`) | `f9a54648…6e0e53853c` |
| `research/structure_engine.js` (fixed in v3.1: chips in play, pace explanation, a case too small for the field, early-bonus chips in C, the fit tolerance) | 759 in `structure_engine_test.html` (`b218ecbe…23c46b49`) | `3be40556…980580dbe7` |
| `research/payouts_engine.js` (fixed in v3.1: `roundDeal` cap) | 55 in `payouts_engine_test.html` (`86e3f9aa…f119689a`) | `d0d34d40…f622ac61c` |

Anything after that goes through a dated change log (§G4), never a silent edit.

## A4. The owner's decisions (binding)

These were decided by the owner and are not open for re-design. The ID is how the mock tests and the older documents refer to them.

| ID | Decision | Why |
|---|---|---|
| **D1** | The add-on is taken **once per player, at the add-on break right after rebuys close**. The engine places that break. | The standard, and it keeps the chip bank predictable. |
| **D2** | **Everyone — players, guests, the TV — sees the prize pool and the payouts.** Only the host's organiser contribution stays hidden. | Trust at the table; every competitor shows prizes. |
| **D3** | **No chip counts during play.** Per-player stacks are typed only when needed: for a deal or at the final table. | ICM needs stacks; nothing else does, and nobody keeps chip counts up all night. |
| **D4** | **Free:** every tool, one table, full level editing, ICM deal suggestions, 3 saved templates/presets, basic standings. **Premium:** 2+ tables, seasons and points, custom TV layouts and more displays, bounty formats (Progressive, Mystery), unlimited templates/presets, graphs and exportable history. | Three sources disagreed; this is the one list. Free ICM keeps the deal moment inside the app. |
| **D5** | The free tier stops at **the second table** (10+ players at 9 per table). The upgrade prompt appears **when the RSVP that needs a second table arrives, days before**, never at the door — with a free alternative (seat 10 at one table). | Most home games are one table; blocking them on night one loses them. |
| **D6** | The early-arrival bonus goes to **anyone checked in and approved before the scheduled start**. | The old rule (15 min before start) fell before check-in even opened (10 min before), so nobody could qualify. |
| **D7** | The individual ante is **10 % of the big blind, rounded to a chip still in play, never below one chip**. The big-blind ante stays the default. | The option existed with no amount anywhere. |
| **D8** | Ship the current engine constants; **log real nights and retune after about 20 games**. | K_ANTE = 27, deep pacing and turbo pacing are extrapolated, not observed. |
| **D9** | Keep bust times, the level at each bust and the final big blind per game, per group — **with consent at sign-up and an opt-out per group**. | Rebuy-rate learning, pace learning and the end-time estimate need it; GDPR needs the consent. |
| **D10** | A bubble save is funded by **every paid place in proportion to its prize**, in whole currency units, **only when the whole table agrees**. | The least contested version. |
| **D11** | Platform: **Flutter, iOS + Android + web** (host, player and TV views all open from a link in any browser). The TV gets the scoreboard either by casting the timer as a second screen or by opening a pairing code in the TV's browser. | The board's landing promises "runs in any browser today, apps coming soon". Casting research is still open (O1). |
| **D12** | Pricing shape: **monthly, yearly and a one-time "Host" licence**. Prices are open (O2). | Subscription fatigue is the most repeated complaint in the category. |
| **D13** | **Pick launch countries only after a gaming lawyer's review; Portuguese sign-off before any Portuguese launch.** The organiser contribution ships as decided, behind the legal gate (§E15, D-H4). | In Portugal poker is illegal outside casinos even without money; a host's cut can count as running illegal gaming. |
| **D14** | Season points: default **field-size weighted, 10 × √(players ÷ finish)**, one decimal; also a simple ladder (10-7-5-3-1) and a custom table. | A win in a 12-player night should count more than in a 6-player one. |
| **D15** | **One co-host role:** bust, rebuy, pause, approve check-ins, run the clock. Cannot change the structure, payouts or the organiser contribution. | Keeps money settings with the host. |

**Decisions taken after D1–D15 (same authority):**

| Date | Decision |
|---|---|
| 2026-09-24 | KO bounty is a toggle **on top of** the buy-in (e.g. 15 + 5), a separate pot, never part of the prize pool; the payouts choice is **None / Standard** only. |
| 2026-09-24 | Played levels lock during a game; the only way to change one is **"correct the record"**, and a played level can never be deleted. |
| 2026-09-25 | **Bust = Out**, final. **+ = rebuy.** **Pause = out of chips and deciding**; a paused player becomes Out automatically when rebuys close. |
| 2026-09-25 | Standard starting depth is a **hard 85–130 BB**; the "no chip worth more than 25 % of the stack" rule is soft. Small chips stay in play until a break once the blinds no longer need them; **colour-ups happen only at breaks**; the biggest chip is never coloured up. |
| 2026-09-25 | The chip bank is sized for a **busy night: the 90th percentile of rebuys** (Poisson), plus every player taking the add-on and the early bonus. Add-ons and bonuses are handed out as the **fewest chips**. |
| 2026-09-25 | Balancing is **TDA 11-A** (the player due the big blind next moves). Paid places ≈ **top 15 % of entries (rebuys count)**, last place ≥ **1.5 × buy-in**, the owner's shapes **52.5/32.5/15** and **42.5/30/17.5/10**. |
| 2026-09-25 | The organiser contribution is **host-only, taken from the pool, hidden from players**, kept despite the legal risk, behind the gate, with lawyer sign-off before launch. |
| 2026-09-25 | **Level editing is free.** Cash settle-up is the **exact fewest transfers**. |
| 2026-09-26 | **Paces.** Turbo 15 min · Regular 20 min · Deep 30 min per level, **one level length all night**. A night fits a **finish time**; a late start keeps the finish. The app recommends the slowest of Deep / Regular that fits; if even Regular does not fit, it **warns and the host picks** (finish later, skip the add-on, or turbo) — never a silent turbo. Home-game norm ≈ 100 BB deep. |
| 2026-09-26 | **Currency: none by default.** Amounts are plain numbers until the user picks a symbol in Settings (None / € / $ / £). |
| 2026-09-26 | **Redesign:** the board's structure and look win; the mock's flows, engines, inputs and toggles are rebuilt inside it. Premium uses the owner's rule in the board's visuals. The board's sign-in/register/reset screens stay, plus a no-account "Start a game now" on the landing. The board's 5-step wizard for planned games, plus the 2-tap quick start. The real PNT logo replaces the board's generic spade everywhere. |
| 2026-09-26 | **No yellow, no gold.** The board's gold money colour is not carried over. Black + crimson + white; green only for live status and positive results. |
| 2026-09-26 | Long explanations sit behind a **"Why?"** link; every input and toggle stays on screen. |

## A5. Where the board and the owner disagree — and what to build

The board is the visual source, but it was drawn before several owner decisions. Where they conflict, **build the right-hand column**.

| # | The board shows | Build instead | Rule |
|---|---|---|---|
| 1 | Gold for money, prize pools, P&L, the podium, the "Pro" crown, the yearly price card, achievement chips | White amounts; crimson for a headline pool/win; green only for positive P&L and live status | No gold (2026-09-26) |
| 2 | `$` everywhere | No symbol until the user picks one; then that symbol | Currency (2026-09-26) |
| 3 | A generic spade + "Poker Night" wordmark; splash reads "POKER NIGHT TOOLS · SCAN. TRADE. TRACK. WIN." | The real PNT symbol (scan-frame corners around a spade) in every logo spot; splash = the symbol + "Poker Night" | Logo (2026-09-26) |
| 4 | Premium sells "Unlimited tournaments, TV mode, ICM deals, cloud sync" | Premium = 2+ tables, seasons & points, custom TV layouts & more displays, Progressive & Mystery bounties, unlimited templates, graphs & export. ICM, one TV, unlimited tournaments and sync are free | D4 |
| 5 | Privacy/Support: "prize amounts show only to the admin; players see their position" | Everyone sees the prize pool and payouts; only the organiser contribution is private | D2 |
| 6 | Achievement chips with emoji (trophy, fire, money bag) | The same chips with icons from the app's icon set | No emoji, ever |
| 7 | Group code "FP2608" | 6 characters from `ABCDEFGHJKMNPQRSTUVWXYZ23456789` — never I, L, O, 0, 1 | §E7 |
| 8 | Player live view shows "Your seat · 18,900 · 47 BB" all night | The stack line appears only when the host has typed stacks (deal or final table); otherwise the card shows table, seat, place-if-out, knockouts and rebuys | D3 |
| 9 | ICM calculator takes "prize pool + players left" | Takes each player's stack and **the prizes still to pay** (a pool alone cannot be ICM'd) | §F2.5 |
| 10 | New tournament wizard step 1 asks "Expected players" and a free "Buy-in" field; no finish time | Step 1 carries date, start **and finish time**; players come from RSVPs (editable); buy-in is a stepper; the pace choice appears in step 4 | Pace (2026-09-26) |
| 11 | Check-in has a green "Confirm" and green "CHECKED IN" pills | Keep green — it is a live status, which the colour rule allows | — |
| 12 | "Free for up to 9 players" on the landing | Keep — matches D5 (one table of 9) | D5 |
| 13 | Admin dashboard "Out" on every row, no rebuy | "Out" opens our bust sheet ("knocked out by"); rebuys stay on the Players screen and the Pause state | 2026-09-25 |
| 14 | Finish order "drag to reorder" for the whole field | Finish order is recorded by busts as they happen; drag-to-reorder is only for **correcting** the order, and only above the last bust recorded by the clock | D-C8 |
| 15 | Profile shows "Lifetime P&L" publicly styled | P&L is private to the user (never on standings, never visible to others) | §E14 |
| 16 | Payout calculator (E5) splits 3 places 50 / 30 / 20 (24 entries × 100 → 1,200 / 720 / 480) | The owner's shape through `payoutPlan`: 52.5 / 32.5 / 15 → **1,260 / 780 / 360**; 42.5 / 30 / 17.5 / 10 at 4 places | 2026-09-25 |
| 17 | ICM and payout calculators show amounts in gold, gold medal and gold row border | White amounts; medal icons from the icon set in white / grey / crimson outline — no metallic gold, silver or bronze | No gold |
| 18 | Upgrade shows two plan cards (Monthly, Yearly) | Three: Monthly · Yearly · **Host licence** ("Pay once"; no trial line under it; not part of the "SAVE n %" comparison) | D12 |
| 19 | Presets tile: "Friday Freezeout" 100 buy-in · 10K stack · 15M levels; "Sunday Deepstack" | The app's four built-in starter presets (F6); the tile's names and numbers are illustrations | Mock |

## A6. Glossary

| Term | Meaning |
|---|---|
| **BB / SB** | Big blind / small blind. The engine always sets SB = BB ÷ 2 on a chip still in play. |
| **BB ante** | One ante per hand, posted by the big-blind player, equal to the BB. |
| **Individual ante** | Every active player posts 10 % of the BB (D7). |
| **Depth** | Starting stack ÷ opening BB, in BB. The home norm is ≈ 100 BB. |
| **Pace** | Turbo (15-min levels) / Regular (20) / Deep (30); one length all night. |
| **Finish time** | The clock time the night must end by. A late start keeps it and shortens the night. |
| **Entry** | One paid seat: a player, a re-entry, or (by default, for paid places) a rebuy. |
| **Rebuy** | Buying a fresh starting stack while rebuys are open; the player keeps their seat. |
| **Re-entry** | A new registration after busting, with its own finish position. |
| **Add-on** | One extra stack per player, at the add-on break after rebuys close (D1). |
| **Pause** | Out of chips and deciding: seat held, no finish position yet. |
| **Bust / Out** | Final elimination; a finish position is recorded; "knocked out by" is asked. |
| **Colour-up** | Retiring the smallest chip at a break, exchanging it for the next chip up (rounded up, no chip race). |
| **Bank** | The chip case: every colour, its value and how many the host owns. |
| **Handout** | The exact chips to give for a start stack, a rebuy, an add-on, an early bonus, a late arrival. |
| **Organiser contribution** | The host's share taken from the pool; host-only, hidden, legally risky (D13). |
| **Bubble** | Remaining players = paid places + 1. |
| **ICM** | Independent Chip Model (Malmuth–Harville): what each stack is worth in money. |
| **Chip chop** | Everyone gets the lowest remaining prize first; the rest splits by chips; nobody gets more than 1st. |
| **Hand-for-hand** | On the bubble with 2+ tables: every table plays one hand and waits for the others. |
| **Co-host** | A member the host lets run the table (D15). |
| **Admin** | Not a role. Never write "admin" in the app: it is always **host** or **co-host**. |
| **Authority** | The one device that writes the clock and game state; everyone else follows. |
| **Audio master** | The one device that speaks the announcements (§E11): the TV when "Plays on: The TV", otherwise the authority. It owns sound only, never writes. |
| **M (M-ratio)** | How many orbits a stack survives: stack ÷ (SB + BB + total ante per hand). Times the rebuy close (§F1.10); shown live on the dashboard. |
| **TDA** | The Tournament Directors Association rulebook. "TDA 11-A" is its rule for moving one player to balance two tables (§F3). |
| **ITM %** | In the money: paid finishes ÷ games played × 100. |
| **Win rate** | Wins ÷ games played × 100, rounded to a whole percent. |


# PART B — DESIGN SYSTEM

The board defines the look. This part turns it into tokens and components a Flutter theme can hold, and adds the owner's non-negotiable rules the board does not show. Where a board screen and this part disagree on a value, measure the board; where the board breaks a rule in §B4, the rule wins.

## B1. Tokens

### Colour

Exactly one look: black ground, crimson accent, white ink. Greys are shades of the ground. Green exists only for live status and positive results. **There is no gold, yellow, amber or second accent anywhere** (a test fails on any yellow pixel colour, T141).

| Token | Value | Use |
|---|---|---|
| `bg` | `#0A0A0A` | App ground; scoreboard ground; input fill |
| `surface` | `#141414` | Cards, list rows, tiles |
| `surface2` | `#1C1C1C` | Secondary buttons, square back button, steppers' inner fill, drawer rows on press |
| `border` | `rgba(255,255,255,0.08)` | Card and row borders |
| `borderStrong` | `rgba(255,255,255,0.16)` | Focused/secondary outlines, sheet borders |
| `red` | `#D53032` | Brand: filled buttons, active tab pill, progress bars, big numerals (≥ 24 px), the logo |
| `redText` | `#F2555A` | Red **text** below 24 px (AA contrast on dark: ≥ 4.5 : 1 on every surface). **Wherever this document calls text below 24 px (18.66 px bold) "red" or "crimson" — eyebrows, the LEVEL and ANTE labels, antes in tables, link rows, legal headings — it means `redText`, never `red`** (`red` on `bg` is 4.05 : 1, on `surface` 3.77 : 1) |
| `redDim` | `rgba(213,48,50,0.16)` | Tinted fills: selected option, avatar tint, pill backgrounds, hero cards |
| `redDanger` | `#B23430` | Destructive actions (End tournament, Delete account). **Fill only**, with white text (6.13 : 1); as a text or outline colour it fails (3.23 : 1 on `bg`) |
| Disabled | 40 % opacity of the control | The reason is always visible text next to it (never opacity alone), and that text meets the normal contrast rule |
| `white` | `#FFFFFF` | Primary text, clock minutes |
| `muted` | `#A6A6AA` | Secondary text, inactive tab labels |
| `muted2` | `#939399` | Tertiary text, small uppercase labels (≥ 4.6 : 1 on every surface) |
| `green` | `#3FBF6B` | Only: LIVE dot, GOING / CHECKED IN / ACTIVE pills, positive P&L figures |

Contrast is a hard requirement: every text node must meet WCAG AA against its real background (4.5 : 1, or 3 : 1 at ≥ 24 px or ≥ 18.66 px bold). The mock measures it on every screen (T102); the app's CI should too.

### Typography

One family everywhere: **Space Grotesk** (weights 300–700), with tabular, slashed-zero numerals for every number (`FontFeature.tabularFigures()`, `FontFeature('zero')`).

| Style | Size / line | Weight | Case | Use |
|---|---|---|---|---|
| `pageTitle` | 28 / 1.15 | 700 | Sentence | Screen titles ("Rebuy settlement") |
| `heroTitle` | 32–34 / 1.1 | 700 | Sentence | Landing, invitation hero, podium title |
| `sectionTitle` | 17 / 1.3 | 600 | Sentence | "Group snapshot", "Upcoming", "Games" |
| `eyebrow` | 11 / 1.2 | 600 | UPPER, tracking .16em | Red context line above a title ("LIVE · RUNNING", "EVENT DETAILS") |
| `label` | 11 / 1.2 | 600 | UPPER, tracking .14em | Grey section and card labels ("PLAYERS", "PRIZE POOL SO FAR") |
| `fieldLabel` | 14 / 1.3 | 500 | Sentence | Labels above inputs ("Event name", "Buy-in") |
| `body` | 14 / 1.5 | 400 | Sentence | Paragraphs, subtitles |
| `meta` | 12.5 / 1.4 | 400 | Sentence | Row sub-lines ("Table 2 · Seat 5") |
| `pill` | 10.5 / 1 | 600 | UPPER, tracking .10em | Pills and status chips |
| `button` | 15–16.5 / 1 | 600 | Sentence | Buttons |
| `clock` | 84 phone · up to 180 TV | 500 | — | Scoreboard minutes (white) + seconds (red) |
| `statBig` | 28–30 | 500 | — | Stat tiles ("34 games") |

### Shape, spacing, depth

| Token | Value |
|---|---|
| Screen side gutter | 18 px (phone) |
| Card radius · padding | 18 px · 18 px (20 px bottom) |
| Row card radius | 16 px |
| Button radius · heights | 14 px · 44 px min (secondary), 52 px (primary), 56 px (`lg`, bottom actions) |
| Input radius · height | 14 px · 52–56 px, 18 px side padding |
| Pill radius | 999 |
| Top bar | 60 px, glass: `rgba(10,10,10,0.72)` + 18 px background blur, bottom hairline `border` |
| Bottom nav | 64 px floating, inset 10 px, radius 22, glass `rgba(20,20,20,0.78)` + blur, `borderStrong` hairline |
| Drawer | 280 px, `#101010`, right hairline |
| Primary glow | `0 10px 26px -12px rgba(213,48,50,0.85)` |
| Hero-card glow | `0 18px 40px -24px rgba(213,48,50,0.6)` + a vertical `redDim` → transparent gradient over `surface` |
| Motion | 150–220 ms ease; screen fade 200 ms; honour "reduce motion" (no transitions) |

## B2. The logo

The PNT symbol — scan-frame corners around a spade — is the only mark. Source files: `final files/Logo/PNT Symbol Red.png`, `…White.png`, `…Black.png` (use vector exports for the app). It appears in: the top bar (red, 22 px, next to the "Poker Night" wordmark in `redText`), the drawer head, the splash, the landing header, the guest/join screens, the scoreboard status row, the TV status row, the results card. Always with full padding — never cropped tight to the corners. It replaces the board's generic spade everywhere.

## B3. Components

Each component is named as the Flutter widget should be, with the board screen that shows it best.

**`AppTopBar`** (N3) — 60 px glass bar: menu button (44 px, opens the drawer) · PNT symbol + "Poker Night" (tap → Home) · avatar (34 px red circle with the user's initial; tap → Profile). Present on every signed-in route. On guest routes it becomes `GuestBar`: a square ✕ button + "Exit · guest session".

**`AppBottomNav`** (N3) — floating glass bar, five items: Home · Games · Chat · Members · More. Icon 22 px over a 10.5 px label. Active item: `redText` icon and label plus a 24 × 2 px crimson bar with a soft glow at the top edge. Chat shows the unread count badge; Members shows the member count badge (17 px red circles, 10 px white bold). Content scrolls under it; screens reserve 64 px + the safe area at the bottom.

**`NavDrawer`** (N1) — 280 px from the left over a 55 % black scrim: logo head; user card (avatar, name, role · group); "GROUPS" label and the current-group switcher card (red-tinted, "12 members · Tap to switch", chevron) that expands into the group list; Home, Games, Chat (badge), Members (badge); "MORE" label; Polls (badge), History, Cash Game, Tools, Standings, Settings; divider; "New Group" in red; footer with Sign out and a close ✕.

**`ExploreSheet`** (N2) — bottom sheet, radius 24 on top, handle bar; title "Explore", subtitle "Everything else, one tap away"; tiles (icon in a 40 px red-tinted rounded square, title, sub-line, optional count pill, chevron): Polls, History, Cash Game, Tools, Standings, Settings.

**`PageHeader`** — a row with the square **back button** (44 px, `surface2`, red chevron) on the left and an optional right element (a pill, a text action like "+ Create poll", "Share", "Step 1 of 5", or a square ⋮); then an optional red `eyebrow`; the `pageTitle`; an optional one-line `body` subtitle in `muted`. Every non-shell screen starts with it.

**`WhyLink`** — the rule for long explanations: a paragraph shows its first sentence; the rest is hidden behind a red "Why? ›" link (13 px, 44 px hit area). Tapping reveals the rest in place and the link becomes "Less". Any explanatory paragraph longer than about 170 characters uses this (T138). Inputs, toggles and numbers are never hidden behind it.

**`Card`** — `surface`, 18 px radius, `border`. **`HeroCard`** — the red-tinted gradient with a red border and glow, for the one thing that matters most on a screen ("Next up", "A game is running", pending check-ins, the invitation).

**`Scoreboard`** (C5, C10, D3, E3) — the tournament display block on `bg` with a `borderStrong` hairline and a faint red glow: status row (PNT symbol, status word in red letter-spaced caps, optional icon buttons on the right) · a hairline · "LEVEL 4" in red, letter-spaced .3em · the clock (white minutes, crimson seconds, colon white) · SB · ANTE · BB columns (ANTE in red) · a 5 px red progress bar (level time elapsed) · a stats row with vertical dividers: TOTAL TIME | AVG STACK | PLAYERS (`10/11` with a red slash) · optional second row (STACK | M-RATIO | REBUYS CLOSE) · "NEXT — LEVEL 5 · 5/10 · ante 10". Numbers are centred; everything else left-aligned.

**`PrimaryButton` / `SecondaryButton` / `GhostButton` / `DangerButton`** — primary: `red` fill, white text, glow; secondary: `surface2` fill, `border`, white text; ghost: transparent, `redText` text (text links like "Forgot password?", "Not now"); danger: `redDanger`. Auth screens use a **white filled** button for the main action ("Sign In", "Create Account", "Send reset link"), exactly as on the board.

**`TextField`** — 52–56 px, `bg` fill, `borderStrong` hairline, 14 px radius, 16 px text, optional trailing icon (mail, eye). Focus: red border + 3 px `redDim` ring. Error: `redText` message under the field with an alert icon.

**`Stepper`** — [−] value [+] in a rounded `bg` box; red glyphs; 44 px buttons; value in tabular numerals. Long-press repeats.

**`Slider`** — a `red` track on a `borderStrong` rail with a 28 px thumb (48 px touch area); the current value always shown as text beside it in tabular numerals, with − / + buttons for exact steps; exposes value, min, max and step to screen readers (`Semantics(value, increasedValue, decreasedValue)`). Used for buy-in, rebuy rate, rebuy stack and ICM stacks.

**`Segmented`** — pill group on `bg`: the active segment is a red filled pill with glow; others `muted`. Used for tabs inside a screen (Players 18 · Eliminated 6 · Prizes), for two-to-five exclusive options (2h 3h 4h 5h; None € $ £).

**`OptionCard`** — a full-width selectable card for a decision with a one-line consequence ("Regular · 20 min · 00:20"). Selected: 2 px red border, `redDim` fill, `redText` title. Options are **stacked vertically**, never side by side, except genuinely two-dimensional sets (a calendar, a colour palette, the 2 × 2 seating-mode grid on the board, the 3-up pace cards where each card is short).

**`Pill`** — uppercase 10.5 px chip. Variants: neutral (`surface2`), red (`redDim` fill, `redText`), green (live/going/checked-in), outline.

**`Toggle`** — 46 × 28, red when on.

**`ListRowCard`** (B3, C4, C5) — a row as its own 16 px-radius card: **initials avatar** (38 px circle; tint alternates red-dim with red letter, or neutral with white letter) · name (15 px, 600) · meta line · right element (pill, count, small button like "Out" / "Take buy-in" / "Undo"). Lists with many short rows (levels, payouts, settings) may use rows separated by hairlines inside one card instead.

**`StatTile`** (B1, F1, F3) — `surface` card, big number (28–30 px, 500) over a `meta` caption; used in 3- or 4-up grids.

**`Toast`** — bottom, above the nav, wraps text (never truncates), stays up at least 4 s — 5 s when it carries **Undo** (§E9) — and longer for longer text, and carries an **Undo** button for every reversible action (rebuy, add-on, payment, bust, top-up) (T104, T110).

**`ConfirmSheet`** — bottom sheet for consequential actions. States the consequence in one sentence, may hold extra controls (e.g. "Knocked out by" chips), and has an explicit Cancel label and a named confirm label ("Costa is out", "Sign out"). Buttons inside the body keep their own labels (T126).

**`Banner`** — full-width card under the header for live situations: offline, take-over, hand-for-hand, bubble, paused. Offline sits directly below the top bar.

**`EmptyState`** — one sentence on what will appear here and one primary action (T114).

## B4. Rules (the owner's non-negotiables)

1. **No emoji anywhere** — not as icons, not in copy, not in generated text, not in notifications. One custom SVG icon set, used consistently.
2. **Left-aligned text** everywhere except numeric displays (clock, blinds, big stats) and button labels (T70).
3. **Touch targets ≥ 44 × 44 px** (T103). Toggles, checkboxes and chips get platform hit-slop.
4. **WCAG AA contrast** on every text (T102).
5. **Sentence case** for titles and buttons; uppercase only for eyebrows, labels and pills.
6. **Vertical choices** — pick-one options stack vertically unless the set is two-dimensional (see `OptionCard`).
7. **Numbers** — tabular, slashed zero; thousands separators; never abbreviate money (1,250 not 1.3K). Chip counts may use "k" only on the TV and stat tiles ("26.7k avg stack").
8. **Currency** — none by default. Amounts render as plain numbers until the user picks a symbol (None / € / $ / £, Settings → On this phone). Chips are never shown with a currency symbol. Every money amount in the app reads the same setting (T1).
9. **No gold** (T141). Money is white; a headline pool or win may be crimson; positive P&L green, negative P&L `redText` with a minus sign.
10. **Explanations behind "Why?"** — first sentence visible, the rest on tap (T138).
11. **Abbreviations** are fine in dense tables (L6, BB) but not in a field the host is setting ("Level 6").
12. **Haptics** — a short vibration on level change on the host phone (setting, default on) (T107).
13. **Focus** — every focusable control shows a 2 px `red` ring 2 px outside its bounds on keyboard or switch focus (web and desktop); never `borderStrong` alone (1.52 : 1 fails WCAG 2.4.11).
14. **Screen readers** — (a) the Scoreboard's level and clock are one live region that announces "Level {n}, {SB} / {BB}, {mm} minutes left" at each level change (never every second); (b) every icon-only control has a label ("More options", "Close", "Choose chip colour", "Show the join code"); (c) steppers and sliders expose value, min and max; (d) level change, rebuys closing, the hold and every bust also go out as a screen-reader announcement with the same words the voice uses, whatever the sound settings.
15. **Never sound alone** — every sound or vibration has a visual twin: the 5- and 1-minute warnings pulse the clock's seconds, the last five seconds show a large 5-4-3-2-1 on every Scoreboard, and the level change flashes the level label (§E17 row 19).
16. **Colour never carries meaning alone** — every state has its word or icon as well (LIVE pill with its word, P&L with its sign, PENDING with an hourglass). The owner is colour blind: red against green must never be the only difference.

**Acceptance for the design system.** Every screen opens with the page header (T137); the component kit — glowing primary, 18 px cards, tall inputs, uppercase pills, grey section labels (T139); initials avatars that never leak into text (T140); no yellow anywhere (T141); every text node meets WCAG AA contrast (T102).

## B5. Responsive and TV

- **Phone** (< 768 px): top bar + floating bottom nav. Follows the OS text size up to 200 %: cards, rows and fields grow to fit wrapped text instead of clipping; the clock and stat numerals keep their own sizes.
- **Tablet / desktop** (≥ 768 px, N4): a fixed 264 px left sidebar replaces both bars — logo, current-group switcher, Home/Games/Chat/Members, MORE (Polls, History, Cash Game, Settings), user card with Sign out at the bottom. Content max width 720 px, centred.
- **TV** (D3): landscape scoreboard, `clock` up to 180 px, status row with the game name and "TV · code", stats row with TOTAL TIME, AVG STACK, the next level (red label), PLAYERS; optional payouts strip and upcoming levels (settings in §E12). Text scale 0.7–2.0 per device.


# PART C — NAVIGATION AND SHELL

## C1. The shell (board N1–N5)

Every signed-in screen sits inside the same shell: the glass **top bar** (menu · PNT logo + "Poker Night" · avatar), the content scrolling underneath, and the floating glass **bottom nav** with five tabs. Secondary destinations live in two places that always agree: the **drawer** behind the menu button and the **Explore sheet** behind the More tab. Above 768 px a **264 px sidebar** replaces the top bar and bottom nav (§B5). Guests get a minimal shell with an exit and no dead ends (§C4).

The mock implements this shell (mock v33+, tests T133–T136).

### The five tabs

| Tab | Opens | Badge |
|---|---|---|
| **Home** | B1 Home for the current group (upcoming, live game, quick actions, snapshot). First open without a group: the landing variant (D-A2b). | — |
| **Games** | If a game you host or co-host is running: its **live dashboard** (C5). If you play in a running game: its **player live view** (C10). Otherwise: the current group's **Games** page (B2); with no games, its empty state with "Start a game now", "Run a cash game", "Plan one in a group" (T109). | — |
| **Chat** | B4 group chat. | Unread count |
| **Members** | B3 members and roles. | Member count |
| **More** | Opens the **Explore sheet** over the current screen (it is not a screen). | — |

**Which tab is active.** Each route belongs to one tab; routes not listed below belong to More. Home: home, landing, new group, join, notifications. Games: every tournament and quick-game route, invitation/RSVP, check-in, results, import results, guest routes, TV. Chat: chat. Members: members, invite, group standings, group settings, group chip default. Everything reached from Explore or the drawer (polls, history, cash, tools, standings, settings, profile, premium, legal) shows **More** as active (T135).

### Drawer contents (N1)

User card (avatar, name, role in the current group) → **Groups** switcher (current group card; tap to expand the list; picking a group switches every tab's context; ends with the group list) → Home · Games · Chat (unread) · Members (count) → **More**: Polls (open-poll count) · History · Cash Game · Tools · Standings · Settings → **New Group** (red) → footer: Sign out · close (T134). Picking any row navigates and closes the drawer.

### Explore sheet (N2)

Polls (count) · History · Cash Game · Tools · Standings · Settings — icon tile, title, one-line description, chevron. Tapping a tile navigates and closes the sheet (T135). Back from a screen opened from Explore returns to the previous tab with the sheet reopened.

### Connection banner

When the device goes offline, a banner slots directly under the top bar on every screen: "Offline — the clock keeps running on this phone; changes sync when you're back" (§E9).

## C2. Route table

Every route in the app, the board screen that draws it, the mock screen that shows its behaviour, and who may open it. **Roles:** `anyone` (no account, no link needed) · `guest` (has a game link or code) · `member` (signed in, in the group) · `player` (member or guest in this game) · `host` · `co-host` · `tv`.

| Route | Board | Mock | Who | Notes |
|---|---|---|---|---|
| `/splash` | A1 | — | anyone | Holds while auth resolves; stores a deep link (§C3) |
| `/start` | A2 | `welcome` | anyone | Landing; signed-out entry |
| `/login` | A3 | — | anyone | |
| `/register` | A4 | — | anyone | |
| `/forgot` | A5 | — | anyone | |
| `/join` | A7 | `joingroup` | anyone | Code, link or QR; classifies before joining |
| `/join/:code` | A7 | `joingroup` | anyone | Deep link; resolves to group invite, game (guest) or TV |
| `/invite/:code` | A8 | (join sheet) | anyone | Group invite preview → sign in/register → join |
| `/g/:gameCode` | A6 | `guest` | guest | Guest RSVP + check-in; guest shell |
| `/quick` | C0 | `quickgame` | anyone | Start a game now — no account needed |
| `/home` | B1 | `groups` | member, anonymous host | An anonymous host (A2b) lands on B1's "No group yet" state |
| `/games` | B2 | `gameempty` + game list | member | Group page: code, invite, table settings, presets, games |
| `/members` | B3 | `members` | member | Host sees role controls |
| `/chat` | B4 | `chat` | member | Guests cannot post (join the group first) |
| `/polls` | B5 | (inline on `groups`) | member | New screen |
| `/notifications` | B6 | `notifications` | member | |
| `/history` | B7 | `history` | member | |
| `/groups/new` | — | `newgroup` | member | Needs a real account: signed-out and anonymous users go through `/register?next=/groups/new` first |
| `/groups/:gid/settings` | — | `groupsettings` | member (host edits) | Chip default, standings, history, members & roles, import |
| `/groups/:gid/standings` | — | `groupstandings` | member | Seasons are Premium |
| `/groups/:gid/import` | — | `importresults` | host | |
| `/groups/:gid/chips` | — | `groupchips` | host | Default chip set pointer |
| `/groups/:gid/invite` | — | `invite` | member | |
| `/t/new` | C1 | `setup` (+ `configure`) | host | 5-step wizard |
| `/t/:id/review` | C2 | `configure` → levels | host | Wizard step 5 and later edits |
| `/t/:id` | C3 | `rsvp` | player | Invitation / RSVP / waitlist |
| `/t/:id/configure` | — | `configure` | host | After RSVPs; also reachable mid-game (per-field locks, §E8) |
| `/t/:id/checkin` | C4 | `players` (pending) | host, co-host | Alias: opens the Active tab of `/t/:id/players` |
| `/t/:id/dashboard` | C5 | `timer` | host, co-host | |
| `/t/:id/levels` | (C11 host variant) | `game` | host, co-host (co-host view-only) | Full level editor for the host |
| `/t/:id/players` | — | `players` | host, co-host | Active · Roster · Seating |
| `/t/:id/payouts` | — | `payouts` | player (projection) | Host view toggle for the host |
| `/t/:id/rebuys` | C6 | `endl6` | host, co-host | Rebuy settlement |
| `/t/:id/deal` | — | `icm` | host | ICM / chip chop / equal + agreed amounts |
| `/t/:id/final-table` | C7 | (seating redraw) | host, co-host | |
| `/t/:id/finish` | C8 | (derived) | host | Confirm finish order |
| `/t/:id/results` | C9 | `gamerecap` | player | Podium, story, share card |
| `/t/:id/live` | C10 · C11 | `liveview` | player | Dashboard · Structure tabs; the Payouts tab navigates to `/t/:id/payouts` (deep-linkable, back-button-correct) |
| `/t/:id/me` | — | `checkin*` | player | Check-in states: locked, request, pending, confirmed |
| `/tv/:code` | D3 | `tv` | tv | Pairing code; read-only projection |
| `/cash/new` | D1 | `cash` | member (or anyone) | |
| `/cash/:id` | D2 | `cash` | cash host | |
| `/tools` | E1 | `tools` | anyone | |
| `/tools/blinds` | E2 | `blindtool` | anyone | |
| `/tools/clock` | E3 | `clocktool` | anyone | |
| `/tools/icm` | E4 | `icmtool` | anyone | |
| `/tools/payouts` | E5 | `payouttool` | anyone | |
| `/tools/quick-blind` | E6 | `quickblind` | anyone | |
| `/profile` | F1 | `profile` | member | |
| `/settings` | F2 | `profile` + `gamesettings` | member | |
| `/stats` | F3 | `mystandings` | member | Graphs and export are Premium |
| `/chipsets` | F4 | `gamesettings` (presets) | member | |
| `/chipsets/:id` | F5 | `gamesettings` (editor) | member | |
| `/presets` | F6 | `templates` | member | Templates / presets |
| `/premium` | G1 | (upgrade toast) | member | |
| `/premium/checkout` | G2 | — | member | Store billing |
| `/privacy` | H1 | — | anyone | |
| `/terms` | H2 | — | anyone | |
| `/support` | H3 | — | anyone | |

## C3. The route guard

Runs on every navigation, in this order (ported from the old §5, extended for the no-account host, the TV and the redesign routes):

```
1. /game/{CODE} or /j/{CODE}             → rewrite to /join/{CODE}
2. /group?tab=X                          → rewrite to the tab's own route
3. if !authReady                          → remember the deep link (once), hold at /splash
4. public routes (/start, /login, /register, /forgot, /join*, /invite/*, /g/*, /quick,
   /tv/*, /tools*, /privacy, /terms, /support)   → allow for everyone
5. actor(game) is not in the route's Who list (§C2)   → /t/:id (the invitation) if a game is loaded, else /home
   (the Who column is the single source; co-host opens /levels view-only)
6. member on /t/:id while the game is running → /t/:id/live   (auto-follow the host)
7. host on /t/:id/review while the game is running → /t/:id/dashboard (no back-nav mid-game)
8. !authed && !guestSession && protected route
                                          → Signed-out guard card (N5): "This page needs a
                                            signed-in account. Guests can only watch the live
                                            game." [Sign in] [Back to start]; then /login?next=…
9. pending deep link                      → consume it (public targets for everyone; protected
                                            ones through login first)
10. authed && on /splash /start /login /register /forgot
                                          → ?next= if present, else /home
```

**Who counts as signed in.** `isAuthenticated` is true for **any** Firebase Auth session, including the anonymous one created by "Start a game now" (A2b), so an anonymous host clears step 8 and reaches `/home` (the "No group yet" state) and their quick game. `hasGuestSession` is unrelated: it is the device-local record of a link guest (A6) who has no Firebase session at all. Routes that need a real account (`/groups/new`, posting a game for RSVP, Premium) send an anonymous user to `/register?next=…`.

**Refresh throttle.** The app state notifies every second (clock) and on every sync delivery. The router listens to a 7-value snapshot only — `[authReady, isAuthenticated, hasGuestSession, isHost(currentGame), currentGame?.id, currentGame?.status, currentGroup?.id]` — and re-runs the guard only when one of them changes.

## C4. The guest shell (N5)

Guest routes (`/g/*`, `/t/:id/me`, `/t/:id/live` for a guest) show no bottom nav and no drawer. The top bar is replaced by a square ✕ + "Exit · guest session" (T136). Exit returns to `/start` for a signed-out guest, or `/home` for a signed-in member who was viewing a game link. A guest screen may show a "Join the Group" hero card: "Create an account to keep your results, join the chat and get invited to the next game." → `/register?next=/invite/{groupCode}`.


# PART D — FLOWS AND SCREENS

Screens are grouped the way the board groups them: **A** onboarding and access · **B** the group hub · **C** hosting a tournament · **D** cash game and TV · **E** public tools · **F** account · **G** premium · **H** legal and support. Screens the board is missing are placed where they belong in the flow and marked "Not on board".

Mock test IDs in *Acceptance* (T1–T145) are listed with their full names in §G2.

**How far to trust the mock here.** The mock is the behaviour reference for the live night (C0, C4–C9), the level editor and both engines. Its onboarding, group-hub, account, premium and legal screens are older and thinner than this document (several are static pictures). Where the mock lacks something described here, **the prose and the board win**; §G5 lists the known gaps.

---

## D-A. ONBOARDING AND ACCESS

**Flow.** splash → landing → { sign in | create account | start a game now (no account) | join with a code } → join by code → { group invite preview → join group | game → guest RSVP / check-in | TV → scoreboard }.

### A1. Splash

- **Board** A1 · **Mock** — · **Route** `/splash` · **Who** anyone
- **Purpose.** Hold while authentication and the stored session resolve; never a dead end.
- **Layout.** Black ground with a faint red radial glow; the PNT symbol centred (96 px) with "Poker Night" under it. (The board's "POKER NIGHT TOOLS · SCAN. TRADE. TRACK. WIN." tile is replaced by the real logo — §A5 #3.)
- **Rules.** Shown until `authReady`. If a deep link opened the app, it is stored once and consumed after auth (§C3 step 9). If auth has not resolved after 5 s, continue to `/start` and retry silently in the background. If a game was running on this device when the app closed, the next screen offers to **resume** it (§E9 "Restore", T86).

### A2. Landing

- **Board** A2 · **Mock** `welcome` · **Route** `/start` · **Who** anyone (signed out)
- **Purpose.** Say what the app does in one screen and offer every way in — including tonight's game with no account.
- **Layout.**
  1. Header row: PNT symbol + "Poker Night"; right: **Sign in** (secondary pill) and **Sign up** (red pill).
  2. Eyebrow "PRIVATE HOME POKER"; hero title "Run your best **poker night**" (the last two words in red).
  3. Body: "One host, one app. Tournament structure generated from your real chips. Timer, blinds, seating and prizes — handled."
  4. Feature pills (wrap): AUTO BLIND STRUCTURE · LIVE TIMER · SEATING & REDRAWS · TV MODE · CASH GAME TRACKER · GROUP CHAT.
  5. Two buttons side by side: **Create account** (primary) · **Join with a code** (secondary).
  6. **HeroCard — not on the board, required by the owner:** title "Poker tonight?", body "Friends already at the table? Start the clock now — no account, nothing to install.", full-width primary **Start a game now** → `/quick`.
  7. Small line: "Free for up to 9 players. No card, nothing to install."
  8. Footer: "Runs in any browser today" + "Host, player and TV views all open from a link — nothing to download." + two store badges "Coming soon · App Store" / "Coming soon · Google Play" (swap for real badges once the apps ship).
- **Actions.** Sign in → A3 · Sign up / Create account → A4 · Join with a code → A7 · Start a game now → C0 (no account; see "First night without an account" below).
- **Acceptance.** A brand-new user reaches a running clock in 2 taps from here with no account wall (T113).

### A2b. First night without an account (Not on board as a screen — a mode)

- **Mock** `welcome` + `quickgame` + first-open mode (T113, T114).
- **What happens.** Tapping "Start a game now" creates an **anonymous session** (Firebase anonymous auth) and opens the quick game (C0). The host can run a full night: clock, levels, players, payouts, join code for players and the TV. Nothing about groups, chat or history is shown yet; every empty screen explains itself in one sentence with one action (EmptyState).
- **Chips.** With no saved chip set, the quick game uses the most common 500-piece box — White 1 × 150 · Red 5 × 150 · Green 25 × 100 · Black 100 × 100 (`DEFAULT_CHIP_SET` in the mock) — and says so: "No chip set saved yet, so this assumes the most common 500-piece box. Different chips? Save yours in Settings; every level stays editable." The line lists the counts and carries **Fix the count** (→ F5 for this game), so a host whose case differs corrects it before the first handout, without an extra step for everyone else.
- **Keeping the night.** At the results screen (C9) and in the drawer, a card offers "Keep tonight's results — create an account". Registering **links** the anonymous user to the new credential, so the game, its results and the chip set move into the account intact (linking keeps the same user id, so no document is rewritten — §E5). If linking fails because that Google account or email already has an account (`credential-already-in-use`), offer: "That account already exists. Sign in to it instead — tonight's game stays open as a guest link you can still share." Registration is never blocked by it. If the host never registers, the night stays on this device only.
- **Rules.** An anonymous host can share the game's join code (players and TV join as guests). They cannot create a group, post a game for RSVP, or buy Premium until they register.

### A3. Sign in

- **Board** A3 · **Route** `/login?next=` · **Who** anyone
- **Layout.** Square back button · title "Sign In" · **Continue with Google** (secondary, Google mark) · divider "or continue with email" · Email (mail icon) · Password (eye toggle) · right-aligned red link "Forgot Password?" · **Sign In** (white filled) · bottom: "Don't have an account? **Create Account**".
- **Fields.** Email: trimmed, lower-cased, must match a basic email pattern. Password: required, shown/hidden by the eye.
- **Actions.** Google → OAuth; on first Google sign-in with no profile, create one from the Google name. Sign In → Firebase email auth. Success → `next` or `/home`.
- **States.** Wrong credentials: one generic error under the password ("That email and password don't match") — never say which one was wrong. Too many attempts: "Too many tries — wait a minute or reset your password." Offline: the button is disabled with "You're offline".

### A4. Create account

- **Board** A4 · **Route** `/register?next=` · **Who** anyone
- **Layout.** Back · title "Create Account" · Continue with Google · divider · Full Name (person icon) · Email · Password · Confirm Password · **two checkboxes (not on board, required):** "I'm 18 or older and agree to the Terms" (required) · "Keep my game history so structures and end times learn from our real nights" (D9 consent, **unchecked by default**) · **Create Account** (white filled) · "Already have an account? **Sign In**".
- **Validation.** Name 1–40 characters after sanitising (§E16). Password ≥ 8 characters; confirm must match ("Passwords don't match"). The Terms box must be ticked to enable the button.
- **After success.** If an anonymous night exists on this device, link it (A2b). If `next` points at a group invite, continue to A8 and join. Otherwise `/home`, which for a user with no group shows the landing variant (B1 "no group" state).

### A5. Forgot password

- **Board** A5 · **Route** `/forgot` · **Who** anyone
- **Layout.** Back · "Reset Password" · body "Enter your email and we'll send a link to set a new one." · Email · **Send reset link** (white filled) · red link "Back to Sign In".
- **Rules.** Always answer "If that email has an account, a reset link is on its way" — never reveal whether an account exists.

### A6. Join as guest (game code)

- **Board** A6 · **Mock** `guest` · **Route** `/g/:gameCode` (or `/join` with a game code) · **Who** guest
- **Purpose.** Someone who isn't a group member gets into one game with a code or link, a name and one tap.
- **Layout (board A6 for the code step).** PNT symbol · "Join as guest" · "Enter the code from the host or invitation link" · card "GAME CODE" with a 6-character field "ENTER CODE" · **Join** · "Have an account? Sign in".
- **Layout (after the code resolves — mock `guest`, restyled).** Guest shell (§C4). Game hero: name, date · time, group; "Shared link — no account needed" pill. Card "Your name" (required, first) and "Invited by" (optional free text). "Coming?" segmented: **Going · Maybe · Can't**. Secondary "See the blinds and the clock" → C10 in read-only. Primary **Check in**: before the check-in window opens (start − 10 min) it is replaced by the locked state — lock icon, "Check-in isn't open yet", the opening time; once open it reads **I'm here — check me in** and moves the guest through request → pending → confirmed on the same route (`/t/:id/me`, re-rendered by state; C4p).
- **Rules.** A name is asked **before** the RSVP (T115). A guest's session is kept on the device (`{gameId, name, inviter, slot}`) so a refresh keeps the same approved seat (§E4). Guests can never be organisers or co-hosts (§E6). Guests cannot post in chat until they join the group.
- **Acceptance.** RSVP in one tap, no account; a name is asked first (T115).

### A7. Join a game or group (code, link or QR)

- **Board** A7 · **Mock** `joingroup` · **Route** `/join`, `/join/:code` · **Who** anyone
- **Layout.** Back · PNT symbol · "Join a game or group" · "Enter an invite code, paste an invite link, or scan a QR code from your host." · card "INVITE CODE OR LINK" with one field · **Continue** · divider "OR" · **Scan QR code** (secondary, camera) · "Have an account? Sign in".
- **Normalisation (§E7).** Accepts a raw code, an invite URL or a QR payload: take `?code=`, else the last path segment; upper-case; strip everything outside `[A-Z0-9]`; forgive case and dashes. A code has exactly 6 characters from the 31-character alphabet.
- **Resolution** (`resolveJoinCode`, classifies **without** joining anything):
  - group code → A8 (invite preview);
  - game code → the game's invitation (C3) for a member, or A6 for a non-member;
  - TV code → D3.
  - Unknown → "No game or group uses that code. Check it with your host." (never "invalid"; the mock still says "No group uses {code}…", §G5).
- **Rate limit.** 10 lookups per minute per device, sliding window; the 11th shows "Too many tries — wait a minute." (10 a minute keeps brute-forcing the 887,503,681 codes to about 169 years — don't raise it without redoing that sum.)
- **Acceptance.** A 6-character code finds the group; typos in case and dashes are forgiven; a game code opens the game (T123).

### A8. Group invite preview

- **Board** A8 · **Mock** join sheet · **Route** `/invite/:code` · **Who** anyone
- **Layout.** Back · pill "GROUP INVITE" · group avatar (initials on a red rounded square, 88 px) · group name · "Invited by {name}" · card: Members (two initials avatars + "+n", as on the board) · Games played (count) · bottom: **Join group** (primary) · red link "Not now".
- **Actions.** Join group: signed in → join as member, toast "You're in {group}", → B1 with that group current. Signed out → A4 with `next=/invite/:code`, then join automatically.
- **Rules.** Joining is idempotent. Already a member → the button reads "Open {group}".


## D-B. THE GROUP HUB

**Flow.** home → group (games) → members → chat → polls → notifications → history. A **group** is the friends who play together. It owns its members, chat, polls, games, history, standings, a default chip set pointer and table settings. A user can be in several groups; the drawer's switcher picks the **current group**, and every tab reads it.

### B1. Home

- **Board** B1 · **Mock** `groups` (+ `welcome` when there is no group) · **Route** `/home` · **Who** member
- **Purpose.** What needs me now, for the current group, in priority order.
- **Layout, top to bottom.**
  1. Welcome row: avatar · "Welcome back" (small, green online dot) · the user's name · on the right a square **bell** button with a red dot when notifications are unread → B6.
  2. Page title "Home".
  3. **Group switcher** field: group avatar (initials on red) · group name · chevron → the drawer's group list. Pinned groups come first.
  4. **Hero card — one of, in this priority:**
     - **A game is running** (you host or co-host it): eyebrow "NEXT UP" with a **LIVE** pill (green dot), as on the board · title = the game name · "Level 4 · 4 / 8 · 10 players left. The clock kept running while the app was closed." → **Open dashboard** (primary) → C5. (T86)
     - **You play in a running game:** "NEXT UP · LIVE" → **Open the live view** → C10.
     - **Next game:** eyebrow "NEXT UP", game name, "Fri 20:00 · 18 going", your RSVP pill (GOING / MAYBE / CAN'T / NO REPLY) → **Open** → C3.
     - None: "No game planned" + **Plan the next game** → C1.
  5. Actions: two-up row **+ New game** (→ C1, host only; members see "Suggest a date" → B5 create poll) · **Cash game** (→ D1); below it a full-width secondary **Start a game now — no RSVP** (→ C0) (T67).
  6. **Same as last time?** card (host, when the group has a finished game): "Friday Poker · Fri 9 Oct · 20:00 · 15 · Rebuy · My home set — the Fri 2 Oct setup, one week later. RSVPs open the moment you post." → **Post for RSVP** (one tap, posts the same game one week later) · **Change something first** (opens C1 prefilled) (T68).
  7. **Second-table card** (host, only when an RSVP pushes "going" past one table — D5): "That's a second table · PREMIUM" · "10 going and your tables seat 9, so this night needs a second table — that is Premium. Sort it now, days before the game, never at the door." → **See Premium** (G1) · **Seat 10 at one table instead (free)** (raises max per table to ≤ 10) (T81). This changes the **group's default** max per table (Group settings → Table settings), not only tonight's game; the host can lower it there again.
  8. **Group snapshot** — section title; four stat tiles: games · members · cash games · paid out (the total of all prizes paid, white — not the board's gold "volume").
  9. **Upcoming** — section title with "See all" → B2; up to three rows (date · time, name, RSVP pill).
  10. **To vote** — up to two open polls as inline vote cards (tap an option to vote right here); "All polls" → B5.
- **States.** **No group yet** (new account, or the anonymous host of A2b): the landing variant — title "Home", pill "No account needed" (anonymous) or none, hero card **"Poker tonight?"** with **Start a game now**, then section "Same friends every week?" with **Create a group** (→ New group) and **Join a group** (→ A7) (T113, T114).
- **Acceptance.** T67, T68, T81, T86, T113, T114.

### B2. Games — the group page

- **Board** B2 · **Mock** `gameempty` + group settings bits · **Route** `/games` · **Who** member
- **Layout.**
  1. Back · square ⋮ (group menu: Group settings · Leave group; host also Delete group).
  2. Group hero card: group name (large) with the PNT symbol as a faint watermark · "12 members" + three initials avatars + "+9".
  3. Row of pills/buttons: **GROUP CODE · Q4MT7R** (red pill; tap copies the code) · **Invite link / QR** (secondary; → Invite sheet with QR, link, Share, Copy).
  4. Host-only row: **Table settings** (max players per table 4–10, default 9; randomise seats by default) · **Presets** (→ F6) · **+ New game** (primary → C1).
  5. Section "Games" with "n upcoming" on the right; game cards: status pill (LIVE with green dot · RSVP OPEN · RSVP CLOSED · FINISHED), name, date (calendar icon), time (clock icon), place (pin icon), "Buy-in: 15" (+ "+ 5 KO" when a bounty is on), divider, "Your RSVP" pill (GOING / MAYBE / CAN'T / WAITLIST #n) + red "Tap to change". Tap the card → C3 (or C5 / C10 when live).
- **Empty state (no game running, none planned).** Title "Games"; card "No game running right now" · "This tab switches straight to the live clock the moment a game you're in kicks off." · **Start a game now** (primary) · **Run a cash game** · **Plan one in a group**; then "Coming up" with any RSVP'd games (T109).
- **Rules.** The Games tab opens the live dashboard (host/co-host) or the live view (player) directly while a game is running (§C1).

### B3. Members and roles

- **Board** B3 · **Mock** `members` · **Route** `/members` · **Who** member (host manages)
- **Layout.** Back · right "+ Add member" (→ Invite) · title "Members" with the count beside it in `muted` ("Members 12") · one row card per member: initials avatar · name (" · you" for yourself) · role pill (**HOST** red, **CO-HOST** outline — the board's gold ADMIN pill predates the no-gold rule) · games · wins ("34 G · 6 W") on the right.
- **Host actions (per row, via a trailing ⋮ or long-press):** Make co-host / Remove co-host · Remove from group (confirm: "Remove Marco from Friday Regulars? Their past results stay in history.").
- **Section "What each role can do"** (collapsible):
  - **Host** — everything: structure, payouts, organiser contribution, members, the group.
  - **Co-host** — runs the night: bust, rebuy, pause, approve check-ins, run the clock. Cannot change the structure, payouts or the contribution (D15).
  - **Member** — RSVP, chat, vote, see live games and results.
- **Privacy.** Members never see each other's email addresses. The host sees "joined {date}" per member. (The board shows emails under names — do not build that.)
- **Acceptance.** Co-host runs the night but cannot touch structure, payouts or the contribution (T83); member rows are light text on the dark ground (T71).

### B4. Chat

- **Board** B4 · **Mock** `chat` · **Route** `/chat` · **Who** member (guests read-only after joining a game; they cannot post)
- **Layout.** Header: back · group name · "12 members · 3 online" (green dot) · pinned **Ongoing event** card at the top when a game is posted or live ("Friday Poker — RSVP open" → C3) · messages: others on the left (name above the first bubble of a run, `surface` bubble), mine on the right (red bubble, "You" under the last), centred day separators ("TODAY") · composer: field "Message the group…" + square red send button.
- **Rules.** Rate limit 8 messages per 30 s and at least 4 s between messages (client), stricter than the server so a compliant client never gets silently dropped (§E10). A blocked send keeps the text in the composer and shows "Sending too fast — wait a moment." Unread count feeds the tab badge. Messages are sanitised (§E16) and filtered (§E10). Deleted messages show "Message deleted". **Long-press a message:** Copy · **Report** (offensive · spam · other → "Thanks — the host has been told.") · **Block {name}** (their messages and polls are hidden for you; undo in Settings → Blocked). The group host also gets **Delete message**. A guest sees the chat with the composer replaced by one row, "Join the group to chat →" (→ the join card, C4).
- **Algorithms.** `rateLimited(uid)`: drop this user's send timestamps older than 30 s; block if 8 or more remain, or if `now − lastSend < 4,000 ms` (the server allows ~3,750 ms, so a compliant client is never silently dropped). `unread(scope)` = messages where `!deleted && authorId != me && (lastRead == null || timestamp > lastRead)`; `lastRead` is per user per chat and moves to now when that chat screen is opened.
- **Two chats.** This group chat, plus one **game chat** per game (host and players; guests read it but post only after joining the group), opened from the live view and from the dashboard menu. Same rules, same screen layout, its own unread count (§E10).

### B5. Polls

- **Board** B5 · **Mock** inline polls on `groups` · **Route** `/polls` · **Who** member
- **Layout.** Back · right "+ Create poll" · title "Polls" · open polls first: pill **OPEN** (green dot) · "8 votes" · question · options as full-width bars showing the share (leading option red-tinted, percentage right-aligned) · closed polls after: pill **CLOSED** · "11 votes" · question · "Winner: Yes, 1 rebuy · 73%".
- **Voting.** Tap an option to vote; tap another to change; tap your own choice again to remove your vote. Multi-choice polls allow several. Votes are stored as `votes: {uid: [optionId]}` (§E10): single-choice keeps only the newest option; multi-choice keeps every option tapped; emptying your list **deletes your entry** (an un-vote), never stores an empty list. Percent bars = votes for the option ÷ people who voted. (The mock's Home poll cards are static and throw when tapped — §G5.)
- **Create poll (sheet).** Question (1–120 chars) · options (2–6, each 1–60 chars) · "Allow more than one choice" toggle · closes: "When I close it" / a date and time · **Post poll** (notifies members). Typical uses the host can pick as a template: "What night works best?" (weekday options), "Buy-in?" (amounts), "Rebuys: yes or no?".
- **Home and drawer** show the open-poll count.

### B6. Notifications

- **Board** B6 · **Mock** `notifications` · **Route** `/notifications` · **Who** member
- **Layout.** Title "Notifications" · "3 unread" · right red "Mark all read" · section **NEW** then **EARLIER** · rows as cards: icon tile (red for time-sensitive, neutral otherwise) · title · sub-line with a relative time. Unread time-sensitive rows use the hero style.
- **Types (and push, where the device allows) — the 13 of §E10:** a game is posted · RSVP deadline in 24 h · you moved up from the waitlist · check-in is open (start − 10 min) · "Starts in 30 min — check in to keep your seat" · your seat is confirmed · the host changed the start or finish time · rebuys close after this level · final table · results are posted ("You finished 2nd") · a new poll · someone mentioned you in chat · someone joined the group. Tapping a row opens its target.
- **Who sends it.** The device that causes the event writes one outbox document; a Cloud Function fans it out to each recipient's inbox and push; every device records the ids it originated and never banners its own event (§E10). Per-type switches live in Settings (F2).

### B7. History

- **Board** B7 · **Mock** `history` · **Route** `/history` · **Who** any signed-in user — it lists group games and the user's own quick games with no group (tagged "Solo", from `users/{uid}/soloGames`, §E4)
- **Layout.** Back · title "History" · filter pills **ALL · TOURNAMENTS · CASH** · (host view) three stat tiles: nights hosted · players hosted · prizes paid out · rows as cards: icon (medal for a podium finish — white icon, never the board's gold medal or gold row border; cash icon for cash) · name ("Freezeout #33") · "Mar 8 · 24 players · finished 2nd" · on the right the user's own result (+720 green / −40 red) and a duration pill ("2H 40M"). Tap → C9 results.
- **Free vs Premium.** Free: the list and five basic stats. Premium: graphs over time and export (D4). The Premium line appears as a quiet note, not a wall.
- **Privacy.** The P&L column is the viewer's own result; nobody sees anyone else's money here.

### B8. New group (Not on board)

- **Mock** `newgroup` · **Route** `/groups/new` · **Who** member — needs a real account; an anonymous host is sent to `/register?next=/groups/new` first (§C3)
- **Layout.** Back · pill "Free" · title "New group" · "The friends you play with. Only the name is needed now; buy-in, format and chips are picked when you post a game." · field "Name" · **Create group**.
- **After create.** A share sheet: the new 6-character code (large, letter-spaced), the QR, the link `pokernighttools.app/invite/{CODE}` (the group-invite route, A8) and "Anyone with the code sees the group's next game. Check-ins on the night still need your OK." → **Share link** · **Done** (→ B1 with the new group current) (T112).
- **Code.** 6 characters from `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (no I, L, O, 0, 1), unique across groups and games (§E7).

### B9. Group settings (Not on board)

- **Mock** `groupsettings` · **Route** `/groups/:gid/settings` · **Who** member (host edits)
- **Rows:** Default chip set (→ B10) · Standings and seasons (→ B11) · History (→ B7) · Members and roles (→ B3) · Import past results (→ B12, host) · **Table settings** (max per table 4–10, randomise seats by default — stored on the group, `groups/{gid}.tableSettings`; the value in Settings F2 only pre-fills a **new** group) · Leave group / Delete group (host; confirm with the consequence).
- **Reports** (host; the row appears when there is one): each reported message with its reason, reporter and time → **Delete message** · **Remove {name} from the group** · **Dismiss**. Handling one tells the reporter "The host has dealt with your report." Open reports older than 24 h also go to support (§E10).
- **Group code:** **Re-roll the code** (host) — the old code and link stop working at once.
- **Principle (shown behind "Why?").** "Chip settings and standings belong to the group, not to one game — set once here; every tournament in this group starts from them, and a single game can still override them in Configure."

### B10. Group default chip set (Not on board)

- **Mock** `groupchips` · **Who** host
- Pick which of **your** chip sets (F4) this group uses by default. A pointer, never a copy: editing the set in F5 updates every group that points at it. A new game starts from it; Configure can override it for one game without touching the group default. Shows the per-player starting stack the default set produces for a typical night.

### B11. Group standings and seasons (Not on board)

- **Mock** `groupstandings` · **Route** `/groups/:gid/standings` · **Who** member
- **All-time table (free).** Per member: games played · wins · podiums · average finish · knockouts. Sorted by podiums, then average finish. **No money** — no profit, no ROI, nothing derived from buy-ins or prizes (§E14).
- **Season (Premium).** Section "Season 2026 · points" with a PREMIUM pill; formula segmented **Field-size · 10-7-5-3-1 · Custom**; the season table (rank · name · nights · wins · points). The explanation under the table follows the formula:
  - Field-size: "Points = 10 × √(players ÷ finish), one decimal. A win in a 12-player night is worth 34.6, in a 6-player night 24.5, and last place still earns 10 for playing. Rebuys don't change the field size."
  - Ladder: "10-7-5-3-1 for the top five, 0 for everyone else. Simple to explain, but a win counts the same in any field size."
  - Custom: the host's own table (default 25-18-15-12-10-8-6-4-2-1).
- **Engine.** `seasonPoints`, `seasonTable` (§F2.9). Ranking: points, then wins, then name. Points are never stored: changing the formula recomputes the whole season from the stored finishes, and a corrected result (C8) recomputes it too.
- **Acceptance.** T88.

### B12. Import past results (Not on board)

- **Mock** `importresults` · **Route** `/groups/:gid/import` · **Who** host
- **Purpose.** Bring last season's nights in so standings and season points start full.
- **Input.** A text area, one night per line: `2026-06-27; Costa, Alexey, Nina, Hugo, Elena` — the date (YYYY-MM-DD), a semicolon, then everyone in finishing order. **Check** parses and previews; **Import n nights** commits.
- **Validation, per line, named by line number:** exactly one semicolon ("write it as 'date; players in finishing order'") · date format · at least 2 players · no player twice · a date already in the season is refused ("already in the season — skipped"). Valid lines import even when others fail.
- **Result.** "Imported 4 nights — standings and season points updated." **Matching:** trim and lower-case both sides; a name matches a member when the strings are then equal (accents count: "Tomás" ≠ "Tomas"). An unmatched name becomes a result row with `playerId: null, guestName: <as typed>` — it counts in that night's standings and season points but never in a member's own record. If that person later joins, old guest rows are **not** re-linked automatically. (The mock parses and validates but never matches names — §G5.)
- **Acceptance.** T94.

### B13. Invite to a group (Not on board as a screen — the B2 "Invite link / QR" sheet and B3 "+ Add member")

- **Mock** `invite` · **Who** member
- **Layout.** Which group (when opened from outside a group: the user's groups as vertical options with member counts) · the group's own code, QR and link · **Share link** · **Copy** · "People you've played with": searchable list of past opponents with "last played" dates; **Invite** sends a one-tap join link; members show a "Member" pill.
- **Acceptance.** Invite picks a group, shares its own code and QR, adds someone you have played with; member counts match the Groups list (T124, T127).


## D-C. HOSTING A TOURNAMENT

**Flow (board C).** create → structure → invite → check-in → live → settle → final table → complete → podium. Plus the quick path the owner added: **start now** → live.

Two ways to create a game, one engine behind both:

| | **Quick start** (C0) | **Planned game** (C1 wizard → C3 → Configure → C4) |
|---|---|---|
| For | Friends already at the table | Next Friday's game |
| Taps to a running clock | 2 | — (posted for RSVP, run on the night) |
| Account | Not needed (A2b) | Needed (a group) |
| Inputs | players, how long, pace, buy-in, format | everything in C1, refined in Configure once RSVPs are in |
| Structure | `generateStructure` on the quick inputs | `generateStructure` on the Configure inputs |

### C0. Start a game now (quick start)

- **Board** — not on board (owner decision 2026-09-26) · **Mock** `quickgame` · **Route** `/quick` · **Who** anyone
- **Purpose.** "Friends already at the table? Four answers and one tap — the clock runs in under a minute."
- **Layout (PageHeader: back, pill STARTS NOW, title "Start a game now").**
  1. Card **Players** — stepper; default: the last headcount in the current group ("Last time at Friday Regulars: 9"), else 8. Range 2 up to one table on the free plan (the group's max per table, 9 by default, 10 after the free alternative) and 2–30 on Premium. Quick start **never** shows the second-table Premium prompt (D5 puts that prompt days before a planned night, and there is no "before" here). At the free cap the + is disabled with the hint "One table seats up to {n} on the free plan. For two tables, plan the night from New tournament." (O14 asks whether the owner wants a different rule.)
  2. Card **How long** — segmented 2h · 3h · 4h · 5h; default 4h. The finish time = now (rounded up to the next 5 minutes) + the hours.
  3. Card **Pace** — three short option cards side by side (Turbo · Regular · Deep), each showing "15 min · 23:50" / "20 min · 00:20" / "30 min · 03:40 · over". Default: the engine's recommended pace; if none fits, **Regular** is selected and a note says "Nothing ends by 00:00 at a regular pace: Regular runs to 00:20, Turbo ends 23:50. Your pick." (T131)
  4. Card **Buy-in** — stepper/slider 5–100, step 5, default 15 (in the chosen currency or none).
  5. Card **Format** — segmented Freeze Out · Rebuy. Rebuy turns on a 35 % expected rebuy rate and an add-on at 125 %.
  6. Chips line: "My home set · 500 pcs" (the group's default set) or "Standard set · 1/5/25/100 · 500 pcs" (no set saved — A2b).
  7. **Count it for Friday Regulars** toggle — records the night in the group's history and standings. Hidden when there is no group.
  8. Card **What you'll get** — one generated sentence, live: "Structure for 9 players over 4h: 200-chip stacks (100 big blinds), opening 1/2, 20-minute levels (Regular), rebuys close after level 4 (suggested), ending around 00:20. Each player gets 5 White · 9 Red · 2 Green · 1 Black. 15 buy-in. Tap to generate it and start — you can still edit any level."
  9. **Generate & start the clock** (primary, full width).
- **Engine inputs.** `{chipSet, players, buyIn, format, expectedRebuyRate: rebuy ? 0.35 : 0, addOn: {enabled: rebuy, multiplier: 1.25}, anteType: 'bb', startTime: now, endBy: now + hours, targetDurationMinutes: hours × 60, pace}`; pace options from `paceOptions(inputs without pace)` (§F1.3).
- **Actions.** Generate & start → `generateStructure` → load the structure, start level 1, open C5 with the **join code card** on top ("Join code 7X2K9P · Players and the TV. No account, no app." · QR · hide ✕) (T108).
- **If a game is already running on this device:** confirm sheet "Friday Poker is still running on this phone." + "Starting a new game ends it. The levels played so far are kept in History, marked unfinished, and it does not count for standings." → **End it and start** / **Keep Friday running** (→ C5).
- **Players without names.** A quick game can run with no names at all: the Players screen shows "No names yet. The clock doesn't need them." with **Share the join code**; players who join by code appear by name.
- **Acceptance.** T67, T113, T131.

### C1. New tournament — the 5-step wizard

- **Board** C1 (step 1), C2 (step 5) · **Mock** `setup` + `configure` · **Route** `/t/new` · **Who** host (a group member creating a game becomes its host)
- **Shell.** PageHeader with back and "Step n of 5" on the right; a thin red progress bar under it; the step's red eyebrow and title; the step pills at the bottom (EVENT DETAILS · CHIP SET · REBUYS & ADD-ONS · FORMAT · REVIEW & CREATE — current one red, done ones outlined, tappable to jump back); **Continue** (primary, full width) at the bottom. Back never loses entered values. A draft auto-saves; leaving shows it on B2 as "Draft — not posted".
- **Start from…** Above step 1, a segmented **Custom · Templates**: Templates opens F6 (starter presets and the host's saved templates); choosing one pre-fills every step and jumps to step 5.

**Where each input lives.** The board labels are kept; our fields are placed where a host expects them. Everything here remains editable later in **Configure** (C-cfg) until the per-field locks of §E8 apply.

#### Step 1 — Event details (eyebrow "EVENT DETAILS", title "New tournament")

| Field | Type | Default | Range / rule |
|---|---|---|---|
| Event name | text | "Friday Poker" (the group's last name, else "{weekday} Poker") | 1–40 chars |
| Tournament type | 4 option cards, vertical | Last used, else **Rebuy** | Freeze Out ("One buy-in, no rebuys — you're out when you're out") · Rebuy ("Buy a new stack if you bust, up to the deadline") · Re-entry ("Bust, then register again as a new entry") · Shootout ("Win your table to reach the final", **Premium** — needs 2+ tables) |
| Date | tappable field → month calendar | the next weekday the group usually plays (Friday for Friday Regulars) | Monday-start grid; today outlined; selected solid red; past days locked; month arrows (T128) |
| Starts | time field | 20:00 (group's usual) | 15-minute steps with −/+; quick picks 19:00 · 19:15 · 19:30 · 19:45 · 20:00 · 20:15 · 20:30 · 21:00 (T39) |
| Finish by | time field | start + 4 h 30 | 15-minute steps; between 1 and 12 hours after the start ("Keep between 1 and 12 hours of poker") |
| Location | text + maps autocomplete | the group's last location | optional |
| Buy-in | stepper (+ slider) | the group's last | 5–100, step 5; no presets row, no ceiling needed beyond 100 in v1 (T36, T38) |
| KO bounty | toggle → then amount + type | off | amount 5–50 step 5, default 5, shown as "15 + 5" — on top of the buy-in, a separate pot (T37, T38, T64). Type: **Fixed** (free) · **Progressive** (Premium) · **Mystery** (Premium) — both Premium options carry a PREMIUM pill; tapping one opens G1. Their payout mechanics are open (O8). The KO bounty stays available when Payouts is **None** — the bounty pot is separate from the prize pool. |
| Payouts | 2 option cards | Standard | **None** ("Just run the game — no prize pool") · **Standard** ("Prize pool paid to the top finishers") — nothing else here; paid places are set later (T35, T36) |
| Posting to | read-only row | current group · member count | — |

#### Step 2 — Chip set (eyebrow "CHIP SET")

- **Which chips** — the group's default set (pointer, B10) pre-selected; list of the host's sets (F4) as option cards with colour dots and totals; "Standard 500-piece box" always available; **+ New chip set** → F5.
- **Starting stack preview** — computed live by the engine for the expected players: "Starting stack — 200 (100 big blinds)" and the per-player chips as colour chips ("5 × White 1 · 9 × Red 5 · 2 × Green 25 · 1 × Black 100"), with the bank check line ("Your chip case covers every starting stack, a busy night of rebuys, every add-on and the early bonus"). This is a proposal; the host may override in Configure.
- **Early-arrival bonus** — toggle, default off; when on: percentage stepper (2.5–25 %, step 2.5, default 12.5 %) and the computed stack shown as chips ("On-time players start with 225 (200 + 25)"). Rule text: "Checked in and approved before the 20:00 start. Check-in opens 10 minutes before, so arriving on time is enough." (D6, T32)

#### Step 3 — Rebuys & add-ons (eyebrow "REBUYS & ADD-ONS")

Shown fully for **Rebuy**, as re-entry settings for **Re-entry**, and as a single line "A freeze-out has no rebuys — every player gets one stack" for **Freeze Out** (T58). For **Shootout**: tables and advancing players.

| Field | Default | Range / rule |
|---|---|---|
| Rebuys | Unlimited | **Unlimited / Limited** segmented; Limited reveals "Max rebuys per player" stepper 1–10, default 2 (T40). This is the game-wide rule; a host can still cap one player live (C-players) |
| Expected rebuy rate | 35 %, or "Suggested · from your last 8 games" when learned | slider 0–100 % step 5 (§E14 learning) |
| Rebuy price | = buy-in (+ bounty) | locked once posted |
| Rebuy stack | = starting stack ("a fresh starting stack") | locked once posted |
| Rebuy deadline | the engine's suggestion ("Level 4 — suggested") | shown after step 5 generates; −/+ any level; never before the running level (T43) |
| Add-on | Yes | Yes / No |
| Add-on size | 125 % of the starting stack, shown as chips ("= 250 chips") | 110–150 %, step 5 |
| Add-on price | = buy-in | 1–100 step 1; locked once posted |
| Pre-define the add-on chips? | off (the moment: "End of rebuy period") | toggles only when the physical breakdown is fixed; the value is always known |
| Re-entry window | the suggested close level | same rule as the rebuy deadline |
| Max re-entries per player | 1 | 1–5, or Unlimited |
| Shootout: starting tables · winners advancing per table | ceil(players ÷ 9) · 1 | tables 2–6 · advancing 1–3 (Premium) |

#### Step 4 — Format (eyebrow "FORMAT") — the shape of the night

- **Pace and finish.** "When" row: **Starts 20:00 · Finish by 00:30** (edit here or back in step 1) and the line "4h 30 of poker. Starting late keeps the finish: the pace re-fits to the time that is left, and latecomers can still join while rebuys are open."
  Three **pace option cards** (vertical), from `paceOptions`:
  - Turbo — "15-min levels · opens 2/4 (50 BB) · ends 00:20" · pill FITS
  - **Regular** — "20-min levels · opens 1/2 (100 BB) · ends 00:20" · pill **RECOMMENDED** · 2 px red border (in use)
  - Deep — "30-min levels · opens 1/2 (100 BB) · runs to 03:10, 160 min over" · pill TOO LONG
  Each card has **Use Turbo / Use Deep** unless in use. The recommended pace is the slowest of Deep / Regular that finishes on time with a chip case that covers it; **turbo is never recommended on its own** (T129).
  **When nothing fits** (even Regular runs over): a warning card replaces the recommendation — "At a regular pace this field needs about 4h40; the night has 4h00." — with three choices, each with its finish time: **Keep 20-minute levels and finish around 00:40** · **Skip the add-on: 20-minute levels, finish around 00:00** · **15-minute levels (turbo): finish around 23:50**. Nothing is chosen for the host (T130).
  **When the chip case is too small** for the field (the engine cannot deal everyone at least 20 big blinds — §F1.5 point 7): the pace cards are replaced by one blocking card with the engine's sentence, e.g. "Your chip case cannot give 22 players a playable stack (at least 20 big blinds) with the forecast rebuys and add-ons. It covers up to 20 players with rebuys and add-ons. Add chips, expect fewer rebuys or add-ons, or play a freeze-out." Three buttons: **Edit chips** (the chip set for this game, F4) · **Fewer rebuys** (jumps to the rebuy rate and the Limited option) · **Play a freeze-out** (switches the format; the structure regenerates). **Create** stays disabled until the stack is playable; the "Small chips out" option (C-cfg §4) is offered too when its bank check passes.
  **Hard finish** (a row under the pace cards, off by default): a toggle, the latest finish (default the finish + 1 h, up to + 3 h, 15-minute steps) and **If still playing: split by ICM · split by chips**. It is printed on the invitation and fixed once posted; how it works on the night: §F4.
- **Ante.** Segmented **Off · Big Blind · Individual**; default from the **Auto** ante rule (§F1.8) biased by the host's default (Settings F2, hosting defaults). "Starts at level" stepper; default the level after rebuys close (rebuy/re-entry) or the first level where a fresh stack is ≤ 40 BB. Individual = 10 % of the BB on a chip in play (D7, T77). Off means no ante anywhere.
- **Tables.** Max players per table stepper 4–10 (default from Settings, 9); summary pill "2 tables · 6 + 5" for the expected players (T56, T57). A night that needs a second table triggers D5's Premium prompt, with the free alternative.
- **Payouts** (Standard only). "Paid places" stepper with the engine's suggestion and **Use the suggestion** (§F2.1); "Why n places" behind Why?. Organiser contribution (host-only; C-cfg §10 and the legal gate H4).

#### Step 5 — Review & create (board C2, title "Review structure")

- **Players.** Before any RSVP the structure is built for a provisional headcount: the group's last headcount (8 if there is none, as in C0), shown as "Built for {n} players (your last night) · Change" — a stepper 2–60. Configure replaces it with the Going count once RSVPs arrive (§A5 #10).
- Three stat tiles: **16 levels** · **~4h 20 est. length** · **20m per level** (pace mode) — or "20m → 20m" if a legacy phased structure.
- The level table in a card: `L1  1 / 2  20m` … break rows ("Break · 10m — add-on window", "Break · 10m — colour up the 1s"), antes in red ("5 / 10 **+10**"), the rebuy-close row marked. Tapping any row opens the level editor (C2 editor rules).
- "Why this structure" — the engine's `explain[]` sentences, first one visible, the rest behind **Why?**.
- Buttons: **Edit** (secondary → the full level editor) · **Publish event** (primary) = **Post for RSVP**: the game becomes visible to the group, RSVPs open, members are notified; the host lands on C3.

### C2. The level editor (review and in-game)

- **Board** C2 (review) / host variant of C11 · **Mock** `game` (in game) and the Configure "Structure — generated" card · **Routes** `/t/:id/review`, `/t/:id/levels` · **Who** host, co-host (co-host read-only for structure — D15)
- **One editor, two contexts.** Before the game starts: nothing is locked except the rules below. Once running: played levels lock.
- **Rows.** Level number · SB / BB · ante · minutes · (host) average stack and average in BB. Break rows between levels with their purpose ("add-on window", "colour up the 1s").
- **Actions per row.** Edit blinds or minutes · insert a level below · insert a break below · delete. At the bottom: **Level at the end** · **Break at the end** · **Recalculate every unplayed level**.
- **Locks and rules** (all tested):
  - A **played** level is locked: no delete; tapping it asks first — "L{n} was already played. Edit it only to correct the record — the clock won't replay it, and it can't be deleted." — then opens the editor; the clock does not replay it (T8, T10, T12).
  - The **running** level can be edited (duration, rarely blinds) but never deleted (T9).
  - Before start, Configure locks nothing (T11); with nothing pinned, unplayed levels can move both ways (T3).
  - A structure never drops below 2 levels and can always be rebuilt (T61).
  - Every level has SB = BB ÷ 2 on a chip in play (T7).
  - **Editing a level's blinds pins it** (a manual anchor, shown with a calculator button). Pins, played levels, the running level and the final level are anchors; the re-solve moves only unpinned levels between anchors (T16, T17, `resolveAroundPins`, §F1.12).
  - A pin cannot go below the level before it; the final level cannot be pinned below the one before it (T45, T46).
  - If edits leave two adjacent levels repeating or dipping, a warning names them with a one-tap "recalculate around your pins"; recalculating clears it (T4). The warning never blocks.
  - Insert keeps blinds strictly rising and payable (T14, T44). If no nice payable blind fits between the neighbours, the unpinned levels around it are re-spaced ("No blind fits between {sb}/{bb} and {sb}/{bb} — the unpinned levels around it were re-spaced to make room"). If pins leave no room at all, the insert is refused: "No room for another level between L{a} ({sb} / {bb}) and L{b} ({sb} / {bb}) — unpin one of them or widen the gap first" or "No room: no blind fits between {sb} / {bb} and your pinned {sb} / {bb} — unpin one first". The refusal path has no mock test yet — write one.
  - Delete renumbers the levels after it (old L9 becomes L8) in both views (T13). Deleting a break asks "Delete this {n}-minute break? Everything after it starts {n} minutes earlier." and, if it carried a colour-up, adds "Its colour-up of the {v}s moves to the next break." or, for the last break, "It was the last break, so its colour-up of the {v}s is dropped — those chips stay in play to the end." Deleting a level asks "Delete L{n} ({sb} / {bb})? Every level after it moves up one number." A structure keeps at least 2 levels ("A structure needs at least 2 levels").
  - Deleting the rebuy-close level moves the marker to the level before it (T48). The ante can never start on a played or running level (T6); its start follows the Configure stepper (T49).
  - **Before start / Running preview.** Configure can preview the editor "as if running at L4" — a sandbox: switching back restores the real game exactly (T5).
  - 400 seeded random edit operations keep every ladder rising and payable (T78) — port this fuzz test.
  - Both contexts render the same engine structure (T2); a break inserts and deletes like a level (T15); the chip rule comes from the chip set and the biggest chip is never coloured up (T47).
  - **Co-host** opens this editor **view-only**: rows and the explanation are visible, every edit control is hidden (D15, §E6).

### C3. Invitation and RSVP

- **Board** C3 · **Mock** `rsvp` · **Route** `/t/:id` · **Who** player (member or guest); host sees host controls
- **Layout.**
  1. **Hero** (full-bleed red panel with a lighter circle): back button · pill "YOU'RE INVITED" · the game name large · pills "FRI · 20:00" and "15 BUY-IN" (+ "+5 KO").
  2. Place row: pin icon · location · distance (when location permission is given) → opens maps; **Add to calendar** (ICS with the right time, place and a link back; T97).
  3. "GOING · 7" with initials avatars + "+n"; pills **GOING 7 · MAYBE 2 · CAN'T COME 1 · NO REPLY 3**.
  4. Seats line: "7 of 9 seats taken" (one table on the free plan: "1 table · free plan").
  5. Lists: **Going** (in RSVP order), **Waitlist** (#1, #2…), **Maybe · Can't**.
  6. Bottom: "WILL YOU MAKE IT?" with **Going** (primary) · **Maybe** · **Can't Come**; below, **Bring a guest (+1)**. After answering, the three become a single status with "Tap to change".
  7. Host only: **Configure this game** (secondary) → C-cfg; the host can remove someone from Going (✕ on the row).
- **Rules.**
  - Seats = the free-plan table size (max per table, default 9) or tables × max per table on Premium. The (n+1)th Going goes to the **waitlist**.
  - A **plus-one** queues from the moment it was added — never ahead of people already waiting. A full table puts it on the waitlist (T89).
  - When someone drops, the first on the waitlist is **promoted** and notified (T89).
  - **RSVP deadline**: a host setting in Configure §1 — stepper in whole hours before the start, 1–72, default **24** (O3 decides the default). The invitation shows "RSVPs close {weekday} {date} · {time}, {n} hours before the start." After it passes nobody new can answer Going, but the waitlist still moves up until the start (T90).
  - A 10th Going on a 9-seat free table triggers the D5 prompt to the host immediately, days before the game (T81).
- **Acceptance.** T81, T89, T90, T97, T115.

### C-cfg. Configure (after RSVPs, and during the game)

- **Board** — not on board as one screen (the wizard steps hold the same fields) · **Mock** `configure` · **Route** `/t/:id/configure` · **Who** host
- **Purpose.** "Everything here is generated from a sensible default and fully overridable — recalculate any time up to start." Two exceptions, because players answered the invitation at these prices: the **buy-in, rebuy price, add-on price and KO bounty are fixed from posting** ("Fixed from the moment it's posted: rebuys cost the same."). The **chip amounts** (starting stack, rebuy stack, add-on multiplier, early bonus) stay adjustable until the **first player is checked in** and receives chips; after that they lock too (§E8). The same fields as the wizard, now with the real headcount, plus what only makes sense once RSVPs are in. Mid-game, each field follows its lock rule (§E8).
- **What most hosts touch is visible; the rest sits under "More options · …" (closed by default, T106):** player tracking (Named / Count-only), rebuy & add-on numbers, chips for this game, paid positions.
- **Sections, in order:**
  1. **Who's actually coming** — tally pills (9 going · 2 maybe · 1 guest) · **RSVP deadline** stepper (whole hours before the start, 1–72, default 24; changing it re-announces the deadline to members who haven't answered) · **Expected players** stepper (defaults to the Going count; overridable) · the Going list as checkable chips (unchecking someone excludes them from tonight's count without touching their RSVP) · **Add guest** · **Write in a name** · "Preview a player's check-in view →".
  2. **Tables** — max per table 4–10 (default from Settings) · summary "2 tables · 6 + 5" (T56).
  3. **Starting stack** — "Starting stack — 400 (100 big blinds)" · the per-player chips · pill "Same for everyone" · bank note (engine `explain` "bank") · early-arrival bonus line.
  4. **How to deal the chips** — the two engine options side by side as option cards (T111):
     - **Engine pick** — "Every colour in every stack; a rebuy is a fresh starting stack; the add-on is the fewest chips the case can spare." Shows start / rebuy / add-on / early bonus as chip rows.
     - **Small chips out, 100s for rebuys** — every small chip is shared out once; rebuys and add-ons are paid in the largest chip only, so small chips never run out. Its stack value is adjustable (−/+ 100, between half and three times the reference stack R of §F1.11 — the engine's stack, or the stack the pace aims for when the case is too small; clamp to [R/2, 3R]; the mock's floor of 100 is a bug, §G5). Shows the bank shortfall in red if the case can't cover it.
     Picking one re-deals the stacks and re-scales the blinds (`generateStructure` with `forceStack`, §F1.11).
  5. **Format** — per type: rebuy rate slider ("Suggested" pill when learned), **Rebuy deadline** (stepper with the level's blinds "15 / 30"; "Suggested: close after Level 4" with **Accept** / **Pick another**; the engine's three options as cards "Level 4 — suggested · a fresh rebuy is 25 big blinds · 30 % of the night") (T18, T19, T73) · rebuy stack (slider 100–20,000 step 100, defaults to the starting stack) · add-on multiplier (= chips) · add-on price · **expected add-on take-up** (0–100 %, step 10, default 70 %; "Suggested · from your last 8 games" when learned, §E14 — it moves only the finish estimate, never the chip bank check, which counts every player) · pre-define physical chips. Re-entry and Shootout sections for those types.
  6. **Ante** — Off / Big Blind / Individual · starts at level (T49, T77).
  7. **Time, pace & bonus** — **When**: Start −/+ and Finish −/+ (15-min steps, 1–12 h window). Changing either re-fits the pace; a late start keeps the finish (T130). **Pace** cards (as in step 4) with the warning-and-choices when nothing fits. **Early-arrival bonus** toggle and percentage. **Hard finish** (as in step 4; fixed once the game is posted, §F4).
  8. **Chips** — "Using Friday Regulars' preset" · the denominations · **Switch** (this game only; the group default is untouched).
  9. **Paid positions** — stepper with **Use the suggestion** (engine, §F2.1) (T42). Only the **number** of places is editable in v1; the shares always follow the owner's shape (§F2.1). Rebuys count as entries for places (`countRebuysForPlaces` is fixed to true in v1, no control).
  10. **Organiser contribution** — "Your contribution" · pill "Only you see this" · segmented **% of the pool / Fixed amount** · stepper (percent 0–30, step 1; fixed amount in steps of 5, from 5 up to the expected pool minus one cash unit) · live preview "On 11 expected entries × 15 = 165 before rebuys: 16 to you, 149 prize pool. Rebuys and add-ons are split the same way." Default comes from Settings (10 %); turning it on for the first time shows the legal gate (H4). If turnout is lower than expected and a fixed fee would reach the real pool when rebuys close, the app lowers it to the pool minus one cash unit and tells the host: "Your contribution was lowered to {x} — fewer entries than expected." The payouts engine is never called with a fee that reaches the pool (§F2.3). (T66)
  11. **Structure** — the **pace-learning** callout when the group has ≥ 5 finished games ("Friday Regulars runs long — averaged 34 min over target the last 5 games. Speed up by ~14 % this time?" → **Apply the adjustment** / **Keep standard pace**; never applied silently, §E14) · **Generate structure** (proposes; nothing is applied without confirmation; "Best once most RSVPs are in — typically ~2 h before start" as a hint, not a gate) (T75) · **Structure — generated** card (the level count pill, the table, **Recalculate the structure**, Before start / Running — L4 sandbox, Level at the end, Break at the end) · **Chip supply check** ("Short by 6 · Black at level 18" with **Open chip settings**) when the bank is short.
  12. **Save this game night** — name field · **Save as template** (a full value copy of these settings; 3 free, unlimited on Premium — D4).
- **Acceptance.** T18, T19, T42, T43, T49, T56, T57, T66, T72, T73, T75, T106, T111, T129, T130.


### C4. Check-in (host)

- **Board** C4 · **Mock** `players` → pending check-ins + no-show card · **Route** `/t/:id/players` (the **Active** tab of C-players; `/t/:id/checkin` is an alias that opens that tab) · **Who** host, co-host
- **When.** Check-in opens **10 minutes before the start**, automatically (players see a countdown before that — C4p).
- **Layout.**
  1. Header: back · title "Check-in" · subtitle the game name.
  2. Stats strip (one card, three columns with dividers): **14/18 CHECKED IN** · **1 PENDING** (hourglass icon, white) · **3 NOT ARRIVED** (redText once the start has passed). Each figure carries its word; colour never carries the meaning alone.
  3. **PENDING CHECK-IN REQUESTS** (red label) — hero rows: avatar · name · "Invited by Marcus L." / "Member · tapped 'I'm here' · 2 min ago" · **Confirm** (green filled). **Confirm all** appears when two or more are waiting (T105).
  4. **PLAYERS** — rows: avatar · name · RSVP line ("Going RSVP", "Going +1 RSVP") · right: **CHECKED IN** pill (green) or **Take buy-in** (secondary — records the buy-in as paid in the owed ledger) or **Nudge** (for not-arrived, sends "Check in to keep your seat").
  5. **SEATING** — 2 × 2 option grid: **Fully random** (default) · **Guests with inviter** · **Guests separate** · **Manual** (only if open decision O6 is approved; until then the grid shows the first three options only). The algorithms are in §F3.
  6. **Start with 14 players** (primary, play icon).
- **Confirming a check-in** seats the player immediately (random seat by the chosen mode, §F3), hands out their chips and records the buy-in as owed: toast "Sam is in at Table 1 · Seat 4 — hand over 5 White · 9 Red · 2 Green · 1 Black, 15 owed to the pot". **Early-arrival bonus**: anyone confirmed before the scheduled start gets the bonus chips added (D6) (T32).
- **No-show gate** (at the scheduled start, if anyone who said Going hasn't checked in): card "20:00 start — 1 confirmed player not checked in" with "Marta (Alexey's guest) RSVP'd Going but hasn't checked in." → **Marta arrived — seat her** · **Wait 10 more minutes** · **Start without her — hold her seat**. Starting without someone creates no player row and takes no buy-in; the seat stays reserved so a late arrival is a normal add. **More than one missing:** the card lists each player as a row ("{name} · RSVP'd Going, not checked in") with **Seat them** and **Start without them** per row, plus one **Wait 10 more minutes** for everyone still missing; resolving one row never closes the gate for the others.
- **Late arrival.** One tap seats them, hands out the chips and records the buy-in — allowed while rebuys are open (rebuy formats) or until the first break (freeze-out); after that: "Late registration closed with rebuys — Marta can't enter now" (T100).
- **Owed ledger.** Every buy-in, rebuy and add-on is recorded as owed until the host marks it paid ("Owed to the pot · 45" card on the Players screen; per player "owes 15" tag → tap = paid, with Undo). "Recorded — no money moves in the app." (T95)
- **Acceptance.** T32, T95, T100, T105.

### C4p. Check-in (player side)

- **Mock** `checkinlocked` → `checkinrequest` → `checkinpending` → `checkin` · **Route** `/t/:id/me` · **Who** player (guest shell for guests)
- **States.**
  - **Locked** — "Check-in isn't open yet" · "Opens at 19:50" · "10 minutes before the start, automatically."
  - **Request** — "You're on the list — Going. When you're actually here, let the host know." · **I'm here — check me in** (primary). "This sends a request; the host confirms."
  - **Pending** — pill "Waiting for the host to confirm"; updates by itself when confirmed.
  - **Confirmed** — pill CONFIRMED · title "Checked in" · "You're seated at **Table 1 · Seat 4**" (large, red) · "Your table" with the dealer marked and "This is you" · **Open the live view — blinds, clock, prizes** → C10. No seating controls for players.

### C5. The live dashboard (host)

- **Board** C5 · **Mock** `timer` (rebuilt in the board's layout, v35) · **Route** `/t/:id/dashboard` · **Who** host, co-host
- **Layout.**
  1. **Header**: red eyebrow **LIVE · RUNNING** (or Paused / Break / Rebuys closing / Final level) · title = the game name · square **⋮** game menu: Configure (host) · Payouts and deals · Announce to players · End tournament (danger).
  2. **Banners** (only when they apply, stacked): join code card after a quick start (T113) · hand-for-hand · take-over · offline.
  3. **Scoreboard** (§B3 component): PNT symbol + status word ("RUNNING") · QR/join and sound buttons on the right (sound shows "Sound on/off", T33) · **LEVEL 4** · the clock · SB / ANTE / BB · progress bar · TOTAL TIME | AVG STACK | PLAYERS 10/11 · STACK (locked icon = the starting stack) | M-RATIO (avg stack ÷ (SB + BB + ante), red) | REBUYS CLOSE (L4) · **NEXT — LEVEL 5 · SB 5 · BB 10 · Ante 10**.
  4. **State cards** under the scoreboard when the clock is in a special state (below).
  5. **Big actions**: **Pause** (crimson, 1.5 width; becomes **Resume**) · **Next ▸** (dark).
  6. **Quick tiles** (4-up): **Speed** · **Edit** · **Seats** · **TV**.
     - Speed → opens a panel under the tiles. When the projected finish drifts more than 20 minutes from the finish time (§F4), a line tops the panel: "Running {n} min behind — at this pace the night ends around {time}." (or "ahead"); nothing changes until the host acts. New build — the mock has no drift line. Controls: **Clock** −1 min · +1 min · Restart level · Previous level (T96); **Players in play** −1 · +1 ("a correction only — for a real bust use Out, so the finish and the knockout are recorded"; no dedicated test yet).
     - Edit → the level editor (C2).
     - Seats → Players → Seating.
     - TV → TV mode on this device, or the TV pairing sheet (D3).
  7. The last spoken announcement in small text ("Spoken at the last level change: 'Level four. Blinds four and eight.'").
  8. **Tabs** (segmented): **Players 11 · Eliminated 1 · Prizes**.
     - Players: row cards (avatar · name · "Table 1 · Seat 3" · "· paused" when paused) with a red-tinted **Out** button → the bust sheet. First six, then "See all 11 players" → Players screen.
     - Eliminated: row cards "Out in 10th · by Hugo" with **Undo**.
     - Prizes: the paid places as tiles (1st / 2nd / 3rd …, amounts from the payouts engine) + "Every paid place and the deal tools" → Payouts.
  9. **Bubble card** (remaining = paid + 1): "On the bubble · 4 left · 3 paid" · "One more elimination and everyone left is paid. Equity is highest right now: a good moment to talk about a deal before a marginal all-in, not after." · **Open ICM deal** · **Start hand-for-hand** (2+ tables) · **Offer a bubble save**.
  10. **Deal card** (2 ≤ remaining ≤ the deal-suggestion setting, default 5, and not on the bubble): "Deal time? · 5 left · 3 paid" · **Open ICM deal** (T79).
- **Clock states** (T53):
  | State | When | What the host sees | Next |
  |---|---|---|---|
  | **level** | normal | scoreboard counting down | Next → next level, or a break, or the hold |
  | **rebuy close** (status `rebuyPause`) | the rebuy-close level ends (rebuy formats, rebuys open) | card "Rebuys close now" · "Level 4 is over. Last chance to rebuy." · **Close rebuys** / **Keep them open one more level**. The clock holds; Next is blocked until the host decides. | Close → paused players become Out, the add-on window opens, the add-on break starts |
  | **break** | a scheduled break | card "Break · 10 min" + purpose: "Add-on window: once per player, 15 for 250 chips (2 × 100 · 2 × 25). Tap Add-on in Players." and/or the colour-up instructions (chips leaving, exchange rate, rounding up — no chip race) | Next → next level (closes the add-on window) |
  | **end** | the last planned level ends | card "The planned levels are over" · **Add a level** (next BB ≈ ×1.4, payable) / **Repeat the last level** | — |
  | **paused** | Pause | eyebrow "LIVE · PAUSED"; players see "Tournament is paused. Wait for the host to resume." | Resume |
- **Announcements (voice, §E11).** At each level: chime + "Level four. Blinds four and eight. Ante eight." (numbers as words); 5- and 1-minute warnings; break: "Break. Ten minutes. Colour up."; hold: "Level four is over. Last chance to rebuy."; end: "That was the last planned level." Haptic on the host phone (T107).
- **Total time** reads the real clock: 0:00:00 at the start of level 1, including break time (T116).
- **Acceptance.** T33, T50, T53, T76 (the tabs stay pinned while the screen scrolls), T96, T107, T108, T113, T116, T142, T143.

### C-players. Players (host)

- **Board** — not on board as its own screen (C5's list and C4 cover parts) · **Mock** `players` · **Route** `/t/:id/players` · **Who** host, co-host
- **Header.** "In play: 10 of 11" · pill HOST · CO-HOST ONLY · "Roster, seating and check-in approvals — live for this game only."
- **Tabs: Active · Roster · Seating.**
- **Active** — pending check-ins (C4) · no-show gate · **Owed to the pot** card · **Chip handout** card (exact chips for Starting stack · Rebuy · Add-on · Early-arrival bonus; "A rebuy is a fresh starting stack. The add-on is taken once, at the add-on break. The add-on and the bonus use the fewest chips your case can spare.") (T31) · one row per player:
  - **+** rebuy with the count always visible (including 0) — no confirmation; toast with the chips to hand over and Undo (T26, T104). Blocked when rebuys are closed or the player's cap is reached (T52).
  - **Add-on** — only in the add-on window, once per player ("Add-on taken") (D1, T53).
  - **Pause** ("out of chips, deciding") — seat held, no finish position; the row shows **Rebuy · 15 + 5** and **Out** (T34, T51). Pause is offered only while rebuys are open.
  - **Bust** — the bust sheet: "Mark Costa as out? A bust is final: they finish 10th and their seat is freed. Might they rebuy? Use Pause instead." + **Knocked out by** chips (tablemates; required when a KO bounty is on, optional otherwise; two picks = split pot, bounty split evenly) → **Costa is out**. The row then shows "Out · 10th · by Hugo" and **Undo bust** (T27, T28, T29). Every bust records the level it happened at (`bustLevel`, used by the recap and pace learning).
  - **More than one out in the same hand at one table** — the bust sheet has **+ Another player out this hand**. The host orders them by who started the hand with more chips; that player finishes higher (TDA — no tie at one table). Each keeps their own place and prize. (Across tables during hand-for-hand they tie instead — see C-bubble.)
  - **Undo** — reverses that player's own last action (rebuy, add-on, bust, pause), whatever anyone else did since.
  - **Rebuy cap** — "Unlimited / Limited to [X]" per player (a house rule for one player, live) (T52).
  - **Remove player** — "erases the entry, not a finish — use Bust if they actually played" (confirm).
  - **No chip counts** in any row during play (D3, T30).
  - **Add a walk-in player** at the bottom — the same gate as a late arrival (C4): allowed while rebuys are open (rebuy formats) or until the first break (freeze-out), and hidden once the rebuy settlement has shown the final pool (C6). A walk-in pays a full entry.
- **Roster** — every group member with their RSVP (Going / Maybe / Declined / No reply) and tonight's state (Active · Busted L5 · Pending check-in · Not coming), **Nudge** for no replies, **Add a walk-in player**.
- **Seating** — tables stepper (auto: 1–9 players one table, more splits evenly, each table ≥ 2) · summary "2 tables · max 9" · **Randomize all seats** · **Random dealers** · per table: players by seat (S1…), dealer marked, **Shuffle this table** · **Random dealer** · the **balance** suggestion when tables differ by 2+ (TDA move, confirm text names it) · the **break a table** prompt when the field fits one fewer table (T20–T24, T54, T55, T65).
- **Closing rebuys** (from the hold or here) blocks + and Pause, turns paused players Out; **Reopen rebuys** is possible until the add-on break ends (T34).
- **Freeze Out** hides every rebuy control (T58).
- **Acceptance.** T20–T31, T34, T51–T58, T63 (names with quotes and apostrophes survive in every generated button), T65, T95, T100, T104, T105.

### C6. Rebuy settlement (the add-on break)

- **Board** C6 · **Mock** `endl6` + the timer's hold → break · **Route** `/t/:id/rebuys` · **Who** host, co-host
- **When.** Two entry points, one screen: (1) at the rebuy-close hold, **Close rebuys** closes rebuys, starts the add-on break and opens this screen; (2) any time rebuys are open, Levels → **End rebuys now — after Level {n}** (an early close) asks for confirmation, then does the same at the end of the current level. The header pill reads **REBUYS CLOSING** until the break starts, then **BREAK**. (The mock only wires entry point 2 and never shows the resume button — §G5.)
- **Layout (board C6, with our three gated steps).**
  1. Header: back · pill **BREAK** (green dot — live status) · title "Rebuy settlement" · "Rebuys closed at the end of Level 4 — record the last ones before the clock resumes."
  2. **PRIZE POOL SO FAR** card (black): pool in large white (crimson allowed for the headline), pill "24 BUY-INS" (paid entries: buy-ins + rebuys + re-entries — the same count as `E` in §F2.1), line "+300 from 3 rebuys this break".
  3. **Step 1 — Who's still in** (open): one row per player with the final rebuy count (−/+), **In / Busted**. **Submit** fixes the confirmed player count and the confirmed rebuy count (both feed learning, §E14). Paused players are already Out.
  4. **Step 2 — Add-on** (unlocked by step 1): who takes it (checklist, once per player), the price and the chips (fewest chips from what's left in the bank at this level) → **Submit add-ons — 2 × 15 = 30**.
  5. **Step 3 — Prize pool** (unlocked by step 2): final entries, rebuys, add-ons → the final pool and the paid places → shown to everyone (D2).
  6. **Confirm & resume clock** (primary) — ends the break early if the host wants; otherwise the break runs out and the clock resumes. **If the break ends before step 2 is done**, the clock still resumes on time and the add-on window stays open as "Add-on window (overtime)" on the dashboard until every player from step 1 has taken or declined it; the final prize pool (step 3) locks and is shown to the table only then.
- **Why the order is enforced.** The add-on count is only known after attendance is fixed, and the final pool needs the add-on count.

### C7. Final table — redraw the seats

- **Board** C7 · **Mock** seating "break a table and redraw" · **Route** `/t/:id/final-table` · **Who** host, co-host
- **When.** Offered automatically **only when the remaining players fit on one table** (for example 11 left at max 9 → "11 players now fit 1 table…"). Every other table break (for example 3 tables down to 2) uses the inline "Break a table and redraw" card on Players → Seating (§F3), not this full-screen view.
- **Layout.** Back · pill **FINAL TABLE** (red, trophy icon — not gold) · title "Redraw the seats" · "9 players remain" · a ring of numbered seats (1 … n) around "Seat 1–9"; the dealer seat red; tapping a seat shows who is in it · **Assign seats & continue** (primary) · red link **Shuffle again**.
- **Rules.** Every remaining player gets a fresh random seat; a random dealer; each table ≥ 2 players when more than one table remains. The confirmation states the outcome before it runs ("Break Table 2 and redraw everyone for the final table?"). The app never moves anyone without the host's tap.

### C-bubble. Bubble, hand-for-hand and deals

- **Mock** `timer` bubble card, `icm` · **Who** host
- **Bubble** = remaining players = paid places + 1. The dashboard shows the bubble card; players and the TV see a bubble banner ("On the bubble — 4 left, 3 paid. The next player out wins nothing.") with a link to the ICM calculator.
- **Hand-for-hand** (2+ tables, on the bubble): **Start hand-for-hand** pauses the clock; a banner "Hand-for-hand · hand 1 · Waiting for Table 1 and Table 2 to finish hand 1" with one button per table ("Table 1: hand done"); when every table is done, "All tables finished — deal hand 2". Players knocked out in the same hand at different tables tie for that place and split its prize (TDA). **How it is recorded and paid:** during hand-for-hand the bust sheet has "Busted in the same hand as…" (pick the other players). Tied players share the highest place among them; the prizes of all the places they cover are added and split equally with `roundDeal` (cash unit; a leftover unit goes to the player who started the hand with more chips). Two players busted in the same hand **at the same table** do not tie: the one who started the hand with more chips finishes higher. **Stop hand-for-hand** in the banner ends it at any time (a mis-tap, a table breaking). It ends automatically when everyone left is in the money (T99).
- **Bubble save** (D10): **Offer a bubble save** shows the new ladder — the bubble gets its buy-in back, every paid place pays in proportion to its prize in whole units, 1st takes the rounding ("1st 91 (−8) · 2nd 55 (−5) · 3rd 28 (−2) · 4th (the bubble) 15"). "Only if the whole table agrees — nothing changes until you record it." Then **Record the bubble save** (confirm sheet listing the new amounts → the payout table, the TV and every player's view update; one Undo) or **Not now** (T82).
- **Deal suggestions** (host-only; `dealTrigger`, §F2.8; each type shows **once per game**, remembered in `dealTriggersShown`, §E3; never applies anything):
  - `targetTime` — "Target end time reached — {n} players left. Want to see deal options? Nobody has to take one." **See deal options** · **Keep playing**
  - `bubble` — the bubble card (C5 item 9) with **Offer a bubble save**
  - `inTheMoney` — "Everyone left is in the money. The deal calculator is ready if the table asks." **Open** · **Dismiss**
  - `headsUp` — "Heads-up. For two players, ICM and chip chop give the same numbers." **Open** · **Dismiss**
- **Hard finish** (only when the host set one before posting, §F4; not a suggestion — the table agreed to it): 15 minutes before, a banner on the dashboard and the TV, "Hard finish at 01:30 — about 15 minutes left." At the time, with two or more players left: the card "Hard finish — split the prizes by ICM" with **Hand finished → Split now** (opens C-deal with the agreed split and the live stacks to type in; confirming ends the game, C8) and **Play on (+30 min)** (host only, confirm "Everyone at the table agrees to play on?", logged).
  - The generic **Deal card** (C5 item 10) appears only while remaining ≤ the host's "Suggest an ICM deal from" setting (2–5, default 5). The mock shows the bubble and deal cards but never calls `dealTrigger` (§G5).

### C-deal. The deal screen (ICM chop)

- **Board** — not on board (E4 is the public tool) · **Mock** `icm` · **Route** `/t/:id/deal` · **Who** host
- **Layout.** Back to Payouts · pill ADVISORY · title "ICM chop".
  1. **Remaining stacks — 3 players**: one row per player with a stack stepper/slider (steps sized to the chips in play) and **Count by colour** (enter how many of each chip still in play; the stack is summed for you) (T98). **Add a player** (2–5 players take a deal).
  2. The prizes still to pay (from the payout plan).
  3. Three results, side by side on tablet, stacked on phone: **ICM split** (recommended, red figures) · **Chip chop — min-cash first** · **Equal chop** — each with per-player amounts to the cent.
  4. **Agreed amounts** — one field per player, pre-filled with the ICM split rounded to the cash unit (whole numbers that add up exactly, largest remainders), editable. They must add up to what is left to pay; otherwise "The agreed amounts add up to 185, but 189 is left to pay. Fix them first."
  5. **Confirm deal & end tournament** → confirm sheet listing "1st on chips · Alexey · 97" … → **Confirm deal & end** → results (C9) titled "{leader} leads on chips — deal at {n}" and standings by chip count (the share image reads "Deal at {n} players", C9).
- **Rules.** ICM and chip chop are always shown together (why ICM matters is visible, not asserted). KO bounties are never part of a deal — they were paid at each knockout. Deals are free (D4).
- **Acceptance.** T62, T79, T98, T144.

### C-payouts. Payouts (everyone, host view for the host)

- **Mock** `payouts` · **Route** `/t/:id/payouts` · **Who** player (projection); the host sees the Host view toggle
- **Layout.** "Prize pool" (large) · entries · rebuys · add-ons · "2 paid of 11 entries" · rows: medal icon for the top 3 (white / grey / crimson outline — no gold fill), place, amount, % of the pool · **Calculate a chop (ICM)** → C-deal (host) · the KO bounty pot as its own line when on ("Bounty pot 55 — paid at each knockout").
- **Host view** (toggle, host only): "Gross 165 · organiser 10 % (16)" and "Prize pool 149"; "Why 2 places: 11 entries → 3 (the 15 % curve); 3rd would pay 22.35, below 1.5 × buy-in (22.50) → 2 places."
- **Everyone else** sees the same amounts without the host lines (D2).
- **Live updates.** A rebuy, add-on or late entry recalculates immediately; when a place is added the host sees "New entry: payouts updated. 4 places now paid."
- **Acceptance.** T74, T92.

### C8. Finish order (complete the tournament)

- **Board** C8 · **Mock** derived from busts · **Route** `/t/:id/finish` · **Who** host
- **When.** Automatically when a bust leaves **one active player and no paused player** (the clock stops, status stays `running` until confirmed), when a deal is confirmed (C-deal), or manually from the dashboard menu **End tournament** (confirm: "End the tournament now? Players still in are placed by chip count if you typed stacks, otherwise you order them."). The mock has no reference for this screen or the last-bust detection (§G5) — build it from this block.
- **Writes on confirm** (the only path besides a confirmed deal that completes a game): each player's result (place, prize, knockouts, rebuys, bust level), `actualDurationMins`, season points (Premium seasons), group history, each player's own result copy (§E14); status → `completed`. A quick game with no group (C0) skips the group history and season points and writes the rest to `users/{hostUid}/soloGames/{gameId}` (§E4).
- **Layout.** Back · title "Finish order" · "Recorded from the night — drag only to correct" · rows: place number (1st crimson) · avatar · name · prize (white; "—" when unpaid) · **Confirm results** (primary).
- **Rules.** Places come from the busts as they happened (the last one standing is 1st). Drag-to-reorder exists only to correct a mistake and asks "Change Ava from 3rd to 2nd? Prizes move with the places." Prizes auto-fill from the payout plan (or the deal). **Correcting later:** History → the game → **Correct results** (host only) reopens this screen; prizes move with the places, standings and season points recompute from the stored finishes, and the correction is kept in the audit trail.

### C9. Results — podium, story and share

- **Board** C9 · **Mock** `gamerecap` · **Route** `/t/:id/results` · **Who** player
- **Layout.** ✕ · **Share** (top right) · pill FINAL RESULTS · the game name · **podium**: 2nd · 1st (raised, crimson pedestal) · 3rd, each with avatar, name, prize (white) · rows 4th and on ("4 · Devi K. · Bubble", "5 · Jordan P. · 2 rebuys") · **Story of the night** (behind Why? if long): biggest comeback (the lowest typed stack among the top 3 — the row is left out when nobody's stack was typed, which is most nights, D3), fastest bust (the lowest `bustLevel` among non-winners), most knockouts. The mock's comeback and fastest-bust lines are static text (§G5) · **Final standings** with "+34.6 season points" per player when seasons are on.
- **Share** — a 1080 × 1350 image: red top rule · "FRIDAY REGULARS · 2 OCT" · "Alexey wins" (or "Deal at 3 players") · "11 players · 189 prize pool" · the podium with prizes and season points · most knockouts · the PNT logo. Shared through the OS share sheet (T93).
- **No-account host.** "Keep tonight's results — create an account" card (A2b).
- **Acceptance.** T93.

### C10. Player live — Dashboard

- **Board** C10 · **Mock** `liveview` · **Route** `/t/:id/live` · **Who** player (members and guests)
- **Layout.** Back · game name + "Live" (green dot) · right: **TV** · **Chat** (unread badge) · **bubble banner** when on the bubble (with "ICM Calculator" link) · tabs **Dashboard · Structure · Payouts** (the Payouts tab opens `/t/:id/payouts`) · the scoreboard (no host controls) · "Next level 300 / 600 · ante 600" · two stat tiles: players left · avg stack · **YOUR SEAT** card: avatar · name · "Table 1 · Seat 2" (+ "· 3rd" once out) · pills ACTIVE / OUT · 2 KNOCKOUTS · 1 REBUY. The stack figure ("18,900 · 47 BB") appears **only** when the host has typed stacks (deal or final table) (D3).
- **Rules.** Same clock, blinds and prizes as the host, read-only; no organiser figure anywhere (T91). No Next / Bust / stepper controls (tested). A player sees their own knockouts and rebuys; nobody else's money.

### C11. Player live — Structure

- **Board** C11 · **Mock** `liveview` (levels) · **Who** player
- **Layout.** Paused banner when paused ("Tournament is paused. Wait for the host to resume.") · tabs · levels table (LVL · BLINDS · ANTE · TIME; the current level highlighted with "now"; breaks as their own rows with the break icon) · **TABLE 1** — the players at my table, "YOU" pill on me, seat numbers · **LATEST ANNOUNCEMENT** — the host's last message ("Break after level 5 — grab a drink, we restart at 9:40 sharp." · "Host · 4 min ago").
- **Announce** is a host action (⋮ → Announce to players): one line, pushed to players and shown on the TV.

### C-ops. Running the night safely

- **Take-over** — a second phone opening a running game as host/co-host sees "Costa is running this clock on another phone" · "One phone runs the clock. Take over and Costa's phone becomes a live view, or keep watching from here." → **Take over** / **Watch only** (T84, §E9).
- **Offline** — the clock keeps running on the authority phone; busts, rebuys and add-ons are saved locally and sync when the connection returns; the TV and players catch up then. Banner "Offline — the clock keeps running on this phone; changes sync when you're back" (T85; the same app-wide banner as §C1).
- **Restore** — opening the app while a game runs offers to resume it (Home hero card; T86).
- **Join** — **Players and TV join** (QR button on the scoreboard): the game's 6-character code, QR and link `pokernighttools.app/j/{CODE}`; phones open the live view, a TV browser opens the big clock (T108).
- **Co-host** — sees the dashboard, Players, check-in, seating and rebuy settlement; the Configure entry, payouts settings and the organiser contribution are hidden (T83).
- **Hand over hosting** (host only; menu on the dashboard, and on a co-host's row in Players): "Make Sam the host of this game? You stay a co-host." → **Make Sam host**. The new host can confirm the finish order and deals, so a host who leaves early never leaves the night unfinishable (§E9).
- **Host's phone gone** — if no co-host device is online and the clock's phone has been silent for 30 minutes, checked-in signed-in players see "The host's phone isn't responding — Take over the clock?" (§E9); the taker becomes co-host and runs the clock; every device shows "Sam took over the clock".


## D-D. CASH GAME AND TV

A cash game is deliberately simple: fixed blinds, a running session clock that never escalates, a chip ledger and an exact "who pays whom" at the end. No host or co-host roles, no group needed, no RSVPs, no structure, no prize pool. Reached from Home ("Cash game"), the Games empty state and Explore → Cash Game.

### D1. New cash game

- **Board** D1 · **Mock** `cash` (setup part) · **Route** `/cash/new` · **Who** member (or anyone, as a local session)
- **Layout.** Back · pill CASH GAME · title "New cash game" ·
  - **Stakes** — segmented **0.5 / 1 · 1 / 2 · 2 / 5** + **Custom** (two steppers: SB and BB, SB < BB, e.g. 1 / 3). Default 1 / 2. (The board shows only the three pills; Custom is added.)
  - **Min buy-in** · **Max buy-in** — two fields; defaults 50 BB and 250 BB at the chosen stakes (1/2 → 100 and 500); min < max.
  - **Chip set** — dropdown of the user's sets (default: the group's), e.g. "Home set · 5 colours". The **chip value** — what one chip unit is worth in money, **per session** (not saved on the chip set): default 1 (a chip marked 25 is worth 25), numeric field, min 0.01. Every chip count × chip value = money (reconciliation, cash-out). Shown as "1 chip = 1". (Neither the board nor the mock has this field; O15 asks whether it should be saved on the chip set instead.)
  - **Track settlement** toggle (default on) — "Auto-calculate who owes who at the end."
  - **Start session** (primary).

### D2. Cash session

- **Board** D2 · **Mock** `cash` · **Route** `/cash/:id` · **Who** the session host
- **Layout.** Eyebrow "LIVE · 1 / 2" (green dot) · title "Cash session" · ⋮ (end session, share code) ·
  - Three stat tiles: **6** players · **1,800** in play · **2:14** elapsed.
  - Reconciliation card (as built in the mock; the board's two-line version is simplified): **Chip value issued** (every buy-in + top-up) · **Chip value returned** (every cash-out) · **Still on the table** (issued − returned). The card is red-tinted while anyone is still playing — a running total, not an error. The check lives under **Cash out & settle**: Σ (counted stacks of seated players × chip value) must equal Still on the table; if not, "Recount: the stacks add up to {x} but {y} is on the table. Fix a stack before settling." "This tracks chip value only — Poker Night doesn't process or confirm real payments."
  - **PLAYERS** with "+ Add" on the right; rows: avatar · name · "In 300 · 2 buy-ins" · net on the right (+140 green / −60 red). Each active row expands to: current chip stack stepper (step 5) with "≈49 BB" · **Top-up** · **Cash out**.
  - Bottom actions: **Preview settle-up** (secondary, any time — writes nothing) and **End session & settle** (primary, enabled once every seated player has cashed out; used earlier it asks "Cash out everyone still seated at their current stack?").
- **Actions.**
  - **Add player** — name · buy-in (between min and max) · suggested starting chips (proposed from the chip set, editable) → **Add to table**.
  - **Top-up** — pick an amount (chips) → the ledger and the stack follow; toast "Nina tops up 20 — hand over 20 in chips" with Undo (T125).
  - **Cash out** — takes the counted stack as the cash-out value; the row shows "In 70 · cashed out 35" and **Rejoin** for the rest of the session: it reopens the row for a new buy-in, and the reconciliation and settle-up use that person's whole-session net (every buy-in and top-up across every stint, minus every cash-out).
  - **Settle** — when everyone has cashed out (or as a preview while some still play): the **fewest transfers** that bring every balance to zero (`settleUp`, §F2.10), e.g. "Costa pays Alexey 12 · Hugo pays Alexey 15"; **Copy as text** for the group chat (T87). If the stacks don't add up to what's on the table: "Recount: the stacks add up to 1,760 but 1,800 is on the table. Fix a stack before settling."
- **Rules.** The chip **total** per player is host-tracked (it moves every hand; the app can't see the table); the **breakdown** of any new stack (buy-in, top-up) is proposed from the chip set. While a player is seated, their chip stack only drives the ≈ BB display and the recount check. **At cash-out** the counted stack × chip value becomes that player's cash-out amount — only then does it enter the money maths (§E3, §F5).
- **Limit.** Settle-up handles up to **16** people with a non-zero balance at once (§F2.10). If cashing someone out would make a 17th open balance, that cash-out is blocked with "Settle-up handles up to 16 people still owed or owing — settle someone first."
- **Acceptance.** T87, T125.

### D3. TV mode

- **Board** D3 · **Mock** `tv` · **Route** `/tv/:code` · **Who** tv (anyone with the game's code)
- **Layout (landscape).** Status row: PNT symbol · **RUNNING** (red, letter-spaced) · on the right "Friday Poker · TV 4821". Big block: **LEVEL 4** (red) · the clock (white minutes, crimson seconds, up to 180 px) · SB · ANTE · BB large (the ANTE label in crimson, as on the board) · progress bar · stats row: **TOTAL TIME · AVG STACK · LEVEL 5 (next, red label) 300 / 600 · PLAYERS 18/24**. Optional panels with a switch in TV settings (§E12): payouts strip (1st … 4th amounts), upcoming levels, leaderboard. Shown automatically when they apply, no switch: the latest announcement (for 60 s) and the bubble banner.
- **Rules.** Read-only projection (§E6): no organiser figure, no ledger, no per-player money. Mirrors the running game in real time (T92). Fullscreen button; exit returns to where it was opened. One TV display is free; custom layouts and more displays are Premium (D4).
- **Pairing.** The host's QR/join sheet (C-ops) opens the TV in any browser; or the TV app casts the timer as a second screen (D11, O1).
- **Sound.** If "Plays on: The TV" is chosen, the TV speaks the announcements once someone taps its full-screen "Tap to turn on sound" (browsers need one tap); until then the host phone does (§E11).
- **TV code.** The host can **Re-roll the TV code** from the TV settings; the old code stops working at once. The first TV to connect in a session shows the host "A TV connected to Friday Poker" (§E7).

---

## D-E. PUBLIC TOOLS (free, no login)

The five calculators run the same engines as the app, on numbers typed in, and never read or write any group or game. Each has its own shareable link.

### E1. Poker tools (hub)

- **Board** E1 · **Mock** `tools` · **Route** `/tools`
- **Layout.** Back · pill FREE · NO LOGIN · title "Poker tools" · "Free, no account needed." · 2 × 2 tiles (icon in a red-tinted square, title, one line): **Blind Structure Generator** ("A full schedule from your chips") · **Tournament Clock** ("A readable clock for a structure") · **ICM Calculator** ("What each stack is worth") · **Payout Calculator** ("Clean, countable splits") · full-width row **Quick Blind Calculator** ("One level, right now").
- Behind Why?: "Standalone, no account, each with its own shareable link. Nothing here reads from or writes to your groups or games; TV Mode and the live timer stay inside their game."

### E2. Blind structure generator

- **Board** E2 · **Mock** `blindtool` · **Route** `/tools/blinds`
- **Inputs.** Players (stepper, min 2, default 10) · Target duration (stepper, hours in 30-min steps, default 4 h) · **Pace** (Turbo · Regular · Deep — sets the level length, T132) · Starting stack (100–20,000, step 100, default 400; no chip case → the practical blind table, §F1.14).
- **Generate** → subtitle "12 levels · ~4h 20m · 20-min levels", pills (e.g. "20 MIN LEVELS · ANTES FROM L4 · 400 START"), the level table (LVL · BLINDS · ANTE · MIN; the current row highlighted when the clock runs), **+ Add level**, **Share** (top right: a link that reopens the same inputs).
- **Acceptance.** T117, T132.

### E3. Tournament clock

- **Board** E3 · **Mock** `clocktool` · **Route** `/tools/clock`
- **Layout.** Back · **Full screen** · the scoreboard (level, clock, SB/ANTE/BB, progress, "Next: 300 / 600" · "Break in 2 levels") · controls: previous · **pause/play** (large red circle) · next · restart · **Edit levels** (your own levels: add, remove last, edit blinds and minutes).
- **Acceptance.** T120.

### E4. ICM calculator

- **Board** E4 · **Mock** `icmtool` · **Route** `/tools/icm`
- **Inputs (corrected from the board — §A5 #9).** Players remaining (**2–9**, as built; the 10th tap says "Up to 9 players left") · each player's **stack** · the **prizes still to pay**, 1st first (a prize pool alone can't be ICM'd).
- **Output.** "CHIP STACKS → EQUITY": rows with rank, name, chips, **ICM equity** (amount in white — the board's gold figures predate the no-gold rule — and % of the prizes) · a second list **Chip chop — min-cash first** · "Total distributed" = the sum of the prizes. Why?: "The chip chop treats chips as money once the minimum is paid. ICM prices each stack's real chance of finishing in every paid place, so it moves about N from the big stack to the short stacks."
- **Acceptance.** 8,000 / 5,000 / 2,000 chips with prizes 250 / 150 / 100 → ICM 197.44 / 171.61 / 130.95; chip chop 206.67 / 166.67 / 126.67 (T119).

### E5. Payout calculator

- **Board** E5 · **Mock** `payouttool` · **Route** `/tools/payouts`
- **Inputs.** Entries (min 2) · Buy-in (5–200, step 5) · paid places (segmented Top 3 · Top 4 · Top 5, plus the engine's suggestion marked).
- **Output.** TOTAL PRIZE POOL (large, white) · rows (medal icon from the icon set, white / grey / crimson outline, never gold; place, amount, %) using the owner's shape (§F2.1) — e.g. **24 entries × 100, top 3 → 1,260 / 780 / 360** (52.5 / 32.5 / 15; the board's 1,200 / 720 / 480 is a generic split, §A5 #16) · a line "For 10 entries the engine would pay 3 places (about the top 15 %, and the last paid place gets at least 1.5 × the buy-in). Amounts are rounded to 5 so cash can change hands." · **Use this structure** copies the split into a new game's payout override (signed-in users).
- **Acceptance.** T118.

### E6. Quick blind calculator

- **Board** E6 · **Mock** `quickblind` · **Route** `/tools/quick-blind`
- **Inputs.** Players (stepper) · Starting stack (100–20,000, step 100) · Target length (segmented 2h · 3h · 4h).
- **Output (SUGGESTED card).** Starting blinds "50 / 100" (red) · Level length "15 min" · Total levels "12". **Generate full structure** → E2 with the same inputs.
- **Acceptance.** Stack is a plain number; Calculate works; − / + update it (T41, T59).

---

## D-F. ACCOUNT

### F1. Profile

- **Board** F1 · **Mock** `profile` · **Route** `/profile`
- **Layout.** Edit button (top right, pencil) · large avatar (initial on red, glow) · name · "Member since 2023 · Friday Regulars" (with no group: "Member since {month year}") · **LIFETIME P&L** card (black): "+1,420" in green (negative in red), pill "↑ UP" · three stat tiles: games · wins · ITM % · **ACHIEVEMENTS** pills with icons from the icon set (not emoji): FIRST WIN · 3 IN A ROW · BIG NIGHT (and more later).
- **Edit.** Display name (shown to groups, on seats and in standings) · photo (change/remove).
- **Privacy.** P&L and ITM are the user's own; nobody else sees them (§E14).

### F2. Settings

- **Board** F2 · **Mock** `profile` ("On this phone", Plan, Account) + `gamesettings` (hosting defaults, sound) · **Route** `/settings`
- **Sections.**
  - **GAMEPLAY** — **Voice announcements** ("Spoken blinds and level updates") · **Hosting tour** ("Step-by-step guidance during tournaments") · **Push notifications** ("Tournament, RSVP and result alerts") · **Compact results** ("Fewer details in game summaries") · **Keep screen awake** ("While a clock you run is live").
  - **SOUND & VOICE** (device-local, §E11) — Level-change chime · 5-minute warning · 1-minute warning · Read the blinds aloud · Vibrate · **Plays on: This phone / The TV** · **Test sound** (plays the next level's announcement at the device's own volume) (T33). There is no in-app volume slider: the device volume applies. The master **Sound on / off** sits on the dashboard's scoreboard (T33), not here.
  - **ON THIS PHONE** — **Currency: None · € · $ · £** (default None; every amount in the app follows it; the symbol is only for reading amounts) (T1) · Language (English; more later).
  - **HOSTING DEFAULTS** (seed a new game; never change a posted one) — Ante: **Always suggest ON · Auto (recommended) · Always suggest OFF** (a bias on the recommendation, never a rule) · Default buy-in (stepper, step 5, default 15) · Starting stack preference (**Engine pick / Small chips out**, T111) · Default format (Freeze Out / Rebuy / Re-entry / Shootout, as C1 step 1) · Default payouts (None / Standard, T35) · Max players per table (4–10, default 9; T25, T57) · Organiser contribution default (host-only, 10 %) · **Suggest an ICM deal from** (2–5 players left, default 5; T79).
  - **GAME ASSETS** — **Chip sets** (→ F4) · **Default chip set** ("Used when you create a new tournament" → pill with the set's name).
  - **DATA** — "Keep my game history to improve structures" (D9 consent; per group opt-out in B9) · Export my data · Delete account (danger, confirm: "Your results stay in the groups' history as 'Former member'.").
  - **PLAN** — "Free plan" + what's in it · **See Premium** (→ G1).
  - **Sign out** (red row with icon, bottom).
- **Acceptance.** T1, T25, T33, T57, T69, T79, T107.

### F3. Statistics

- **Board** F3 · **Mock** `mystandings` · **Route** `/stats`
- **Layout.** Back · title "Statistics" · "{name} · all-time results" · scope segmented **All groups · Friday Regulars · Office League** · six stat tiles: games played · wins · podium · avg finish ("#3.2") · knockouts · win rate (wins ÷ games played, whole percent; white, not gold). ITM % on the profile = paid finishes ÷ games played. (The mock shows only the first five tiles.) · Premium note card (crown icon): "Finishing positions over time, knockout records and exportable history are part of Premium. Your basic stats stay free."
- **Empty.** "No games yet" + **Start a game now**.
- **Rule.** Across groups this is only ever the viewer's own record — there is no global leaderboard of users (§E14).

### F4. Chip sets

- **Board** F4 · **Mock** `gamesettings` (presets list) · **Route** `/chipsets`
- **Layout.** Back · "+ New" · title "Chip sets" · one card per set: name · "5 denominations" · DEFAULT pill on the default one (red outline card) · a row of chip swatches with their values under them (25 · 100 · 500 · 1k · 5k; dashed outline for a colour without a printed value) · chevron to edit.
- **Rules.** Chip sets belong to the user (the physical chips are theirs), not to a group; groups point at one (B10). Chip sets are **free and unlimited**: D4 lists only templates/presets as limited, and anything D4 doesn't name as Premium is free.
- **Acceptance.** T121.

### F5. Edit chip set

- **Board** F5 · **Mock** `gamesettings` (chip editor) · **Route** `/chipsets/:id`
- **Layout.** Back · **Save** (top right, red) · **Set name** field · **Do your chips have printed values?** — **Numbered / No numbers**; with No numbers: **Suggest values for me** / **I'll set values myself** · **DENOMINATIONS** — one row per colour: swatch **with its colour name as text beside it** ("● White") — the name comes from a fixed palette of named chip colours (White, Red, Green, Black, Blue, Purple, Pink, Grey; no yellow or gold), each shown with its name in the palette sheet, and it is editable ("Name on your chips") for sets that differ; every "5 White · 9 Red" string in the app reads this name, never the hue (tap the swatch → a sheet with the named palette and **Remove this chip** — blocked at two denominations: "A chip set needs at least two values") · **Value** stepper that moves along the denomination ladder 1 · 2 · 5 · 10 · 20 · 25 · 50 · 100 · 200 · 250 · 500 · 1,000 · 2,000 · 2,500 · 5,000 · 10,000 · 25,000 (disabled while "Suggest values for me" is on) · count stepper (− 80 +, step 10) · **+ Add denomination** · footer card **Total chip value 58,000** (red figure) and the piece count.
- **Suggest values** — the biggest pile gets the smallest value, up the ladder 1 · 5 · 25 · 100 · 500 · 1,000 · 5,000 · 25,000 (T122).
- **Validation.** At least two values; no two colours with the same value ("Two colours are both worth 25 — give each colour its own value").
- **On save.** "Saved 'Home set': … New games use it; tonight's game keeps the chips already on the table." A running game is never changed by editing a set.
- **Acceptance.** T121, T122.

### F6. Presets (templates)

- **Board** F6 · **Mock** `templates` · **Route** `/presets`
- **Layout.** Back · "+ New" · title "Presets" · "One-tap tournament setups." · cards: name, ⋮ (rename, delete — templates only), pills (format · pace · rebuys, e.g. FREEZE OUT · REGULAR · NO REBUYS), **Use preset** (primary on the first, secondary on others). A template card adds "Used 9 times · last on Sep 19".
- **Two kinds, one list:** **starter presets** shipped with the app — the mock's four (the board's "Friday Freezeout / Sunday Deepstack" numbers are illustrations): **Freezeout** (Regular pace · one buy-in, no rebuys) · **Sprint** (Turbo pace · short levels, fast finish) · **Deep** (Deep pace · big starting stack) · **KO Bounty** (Regular pace · Fixed KO bounty 5 on top of the buy-in). Buy-in comes from the host's default; the stack is always proposed by the engine from the chip set — and **your templates** (a full value copy of a past game's settings, saved from Configure — C-cfg §12). Using one pre-fills the wizard and jumps to step 5; the structure is always re-generated for tonight's numbers, never replayed.
- **Limits.** 3 free, unlimited on Premium (D4).

---


## D-G. PREMIUM

The owner's rule (D4) is the whole list. Anything not named as Premium is free — including ICM and deals, one TV display, unlimited tournaments, sync and level editing. The board's upgrade copy ("Unlimited tournaments, TV mode, ICM deals and cloud sync") is replaced (§A5 #4).

| Free | Premium |
|---|---|
| Every public tool · the full tournament engine (structure, payouts, ICM, every deal type) · one table (up to 9 at the table size, 10 if the host raises it) · full level editing · rebuys, add-ons, busts, seating, TDA balancing · one TV display in the default layout · Fixed KO bounty · 3 saved templates · chip sets (unlimited) · basic standings · cash games | **2+ tables** · **seasons and points** · **custom TV layouts and more displays** · **Progressive and Mystery bounties** · **unlimited templates** · **graphs and exportable history** (F3) |

### G1. Upgrade

- **Board** G1 · **Mock** `premium` · **Route** `/premium` (a full-screen sheet over the current screen) · **Who** member (signed in; anonymous users are asked to create an account first, A2b)
- **Layout.** ✕ (top left) · the PNT symbol in a crimson rounded square (not the board's gold crown tile — §A5 #1) · title "Poker Night Premium" · one line: "For groups that outgrow one table." · five check rows (green check = status, allowed): **Two or more tables** · **Seasons and points** · **Your TV layouts, more screens** · **Progressive and Mystery bounties** · **Unlimited templates, graphs and export** · three plan cards, side by side on wide screens, stacked on phones: **Monthly** · **Yearly** (pill "SAVE n %", computed from the two prices; the selected card has a crimson outline, never gold) · **Host licence** ("Pay once"; no trial line under it; not part of the "SAVE n %" comparison — the board draws only Monthly and Yearly, §A5 #18) · primary button (label depends on the trial decision, O9: "Start 7-day free trial" or "Continue") · fine print "Cancel any time in your store account · Billed after the trial".
- **Prices.** Not decided (O2). Build the three products with prices read from the store (StoreKit / Play Billing / web billing), never hard-coded. The board's $5 / $36 are placeholders.
- **Where the upgrade appears (D5 — never at the door):**
  1. The RSVP that needs a second table: Home and Configure show "10 going and your tables seat 9, so this night needs a second table — that is Premium. Sort it now, days before the game." with **See Premium** and the free alternative **Seat 10 at one table** (raises the table size to 10, T81).
  2. Tapping a Premium control: season setup (B11), a second TV display, a TV layout, Progressive/Mystery bounty (C1 step 1), a 4th saved template (F6), graphs/export (F3). Each shows the control with a PREMIUM pill; the tap opens G1.
  3. Settings → Plan (F2).
  4. Never from quick start (C0): at the free one-table cap the + is simply disabled with a pointer to planning the night ahead.
  - Never on a running game's live screens; never blocking a game that has already started.
- **Acceptance.** The second-table prompt appears on the RSVP, with the free alternative (T81); the free / Premium split matches D4 (T80).

### G2. Checkout

- **Board** G2 · **Route** — (platform sheet) · **Who** member
- **Build.** Use the **store's own purchase sheet** (Apple, Google; on the web a hosted checkout). The app never sees or stores card details. The board's in-app card form is a picture of what the store sheet shows — do not build a card form.
- **After purchase.** The entitlement is written server-side from the store receipt (validated), not on the device. Toast "Premium is on — two tables, seasons, TV layouts and bounties are unlocked." Return to where G1 was opened.
- **Restore purchases** row on G1 and in Settings → Plan.
- **Entitlement scope.** Premium belongs to the **host's account** and applies to the games that account hosts (players in those games need nothing). Open question whether a group can share one Premium (O10).

---

## D-H. LEGAL, PRIVACY AND SUPPORT

Long-form pages on the dark ground, left-aligned, 15/22 body text, max 640 px wide on large screens.

### H1. Privacy policy

- **Board** H1 · **Route** `/privacy` · **Who** anyone
- **Layout.** Back · eyebrow "EFFECTIVE DATE: {date}" · title "Privacy Policy" · an OVERVIEW card · numbered sections with crimson headings.
- **Content the page must state (final wording by the lawyer, D13):**
  1. **What we collect** — name, email, profile photo; groups, games, results, chat, polls; device settings stay on the device.
  2. **How it is used** — signing in, running games, history and stats, invitations and notifications; structure learning from past nights **only with consent** (D9). No selling of personal data, no ads profiling.
  3. **Groups and sharing** — group members see the group's games, chat and standings. **Everyone in a game sees the prize pool and the payouts** (D2 — corrects the board's "prize info visible only to the admin"). A player's lifetime P&L and money history are visible only to that player (§E14). The host's organiser contribution is visible only to the host.
  4. **Game history kept to improve structures** — bust times, the level at each bust and the final big blind, per game, per group; opt-in at sign-up, opt-out per group (B9, D9).
  5. **Your choices** — edit your profile, turn notifications off, export your data (JSON), delete your account (F2). Deletion removes the account and personal data; your finishes stay in the groups' history as "Former member".
  6. **Where data is stored** — Firebase (Google Cloud), region chosen at launch (EU for EU launches — O11); processors listed, including **Firebase Analytics** (anonymous product-usage events — never chat, names or amounts; in the EU only after you allow it) and **Firebase Crashlytics** (crash and error reports: device model, OS version, the error).
  7. **How long we keep it** — game data and chat while the group exists; a group inactive for 24 months is archived and its chat deleted, after an email to the host; handled chat reports are deleted after 90 days; crash reports after 90 days (§E15).
  8. **Children** — the service is for adults (18+).
  9. **Contact** — the support address.

### H2. Terms of service

- **Board** H2 · **Route** `/terms` · **Who** anyone
- **Layout.** Back · eyebrow date · title "Terms of Service" · numbered cards: **1 Your use** (18+, keep sign-in details secure) · **2 The service** (a tool for organising home games, provided as is; the app never holds, moves or confirms money — every amount is guidance for people to settle themselves) · **3 Your data** (you own what you enter; export and delete from Settings) · **4 Acceptable use** (don't misuse the service; **you are responsible for playing only where it is lawful**) · **5 Premium and billing** (store terms; cancel in the store) · primary **I understand** only when opened from sign-up; otherwise no button.

### H3. Support

- **Board** H3 · **Route** `/support` · **Who** anyone
- **Layout.** Back · title "Need help?" · "Reach us at {support address} — we reply within one business day." · FREQUENTLY ASKED QUESTIONS (expandable cards) · bottom card "Found a bug?" + **Email us** (opens mail with the app version, platform and game ID pre-filled; nothing personal is added without the user seeing it).
- **FAQ answers corrected to the decisions:**
  - *How do I start a tournament?* — "Tap **Start a game now** for tonight, or **New tournament** to plan one: pick the date, the finish time and your chips; the app builds the blinds, the payouts and the schedule."
  - *Lost my game mid-way — recoverable?* — "Yes. The running game is saved on the phone that runs the clock and synced to your group; open the app and tap **Resume**."
  - *Can I track cash games?* — "Yes — buy-ins, top-ups and cash-outs, and the fewest payments to settle at the end."
  - *Who sees the prizes?* — "Everyone in the game sees the prize pool and the payouts. Only the host sees the organiser contribution, if one is set." (Replaces the board's "prize amounts show only to the admin" — §A5 #5.)
  - *Is this gambling?* — "Poker Night doesn't take bets or move money. It is a clock and a calculator for your own game. Check the rules where you play."
  - *How do I report an abusive message?* — "Press and hold the message and tap **Report**. The group's host is told; if nothing happens within a day, we are too. You can also **Block** someone to hide their messages."

### H4. The organiser-contribution legal gate

- **Where.** Configure → Organiser contribution (C-cfg), the first time a host switches it from None to Percent or Fixed, and again whenever the host's country setting changes. Also shown to a host who imports a template with a contribution on.
- **Default.** Off (None). The feature ships behind this gate until a gaming lawyer signs off per launch market (D13). A remote flag can hide the whole control per country.
- **Blocking dialog, exact copy** (requires the tick to enable **Enable**):

```
Organiser contribution
You are about to keep part of the buy-ins before prizes are paid.
• In Portugal, playing poker for money outside a casino is already an offence
  (DL 422/89 art. 110); keeping part of the money can be treated as running
  illegal gaming (art. 108). Similar rules apply in the UK, Spain, the
  Netherlands, Germany, Italy, France and many US states.
• Players will only see the prize pool after your contribution.
This is general information, not legal advice. You are responsible for
complying with the law where you play.
[ ] I understand          [Cancel]  [Enable]
```

- **Recorded.** The acceptance (user, time, app version, copy version) is stored on the user, never on the game.
- **Recommendation carried from the research, not a decision:** when a contribution is on, label the players' pool "after organiser costs". One word removes the concealment element regardless of what the lawyer concludes. Listed as open decision O5.

### H5. Consent and data controls (Not on board as a screen)

- **Sign-up** (A4): the D9 consent checkbox, unchecked by default.
- **Group settings** (B9): "Use this group's nights to improve structures" — per-group opt-out; when off, that group's games are not used for pace or rebuy-rate learning and bust times are not kept beyond the game's own record.
- **Settings → Data** (F2): export (JSON of profile, groups, results, chip sets, templates), delete account.

---


# PART E — ARCHITECTURE

How the app is put together. Where this part and a screen block in Part D disagree, the screen block wins for what the user sees and this part wins for how it is stored and synced; report the disagreement.

## E1. Platform

- **Client:** Flutter, one codebase for **iOS, Android and web** (D11). The web build is a first-class target, not a demo: host, player and TV views must all open from a link in a phone or TV browser with nothing installed.
- **Backend:** Firebase — Authentication (email/password, Google, **anonymous** for the first night, A2b), Cloud Firestore, Cloud Functions (receipt validation, push fan-out, code reservation, account deletion, season recompute, and **per-game time-relative reminders** — "starts in 30 min", the RSVP deadline, "rebuys closing" — as Cloud Tasks scheduled at posting and re-scheduled when the time changes; every scheduled instant is computed from the game's stored IANA time zone and wall-clock time, never a UTC offset frozen at posting, so a daylight-saving change between posting and the night keeps each reminder at the same real lead time), Cloud Messaging (push), Hosting (web build and link handling), Remote Config (per-country flags), Crashlytics (crashes and non-fatal errors).
- **Analytics:** Firebase Analytics, product events only (game created, structure generated, deal confirmed, offline recovery used). Never chat content, names or ledger amounts. In the EU, Analytics starts only after the first-run notice is accepted ("Help improve Poker Night with anonymous usage data" · **Allow** · **Not now**; changeable in Settings → Data); Crashlytics runs for everyone (crash and error reports are needed to run the service) and both are named in the privacy policy (H1). Firebase **App Check** is on for Firestore and every callable Function.
- **Environments:** dev, staging and production as separate Firebase projects (§A3).
- **Links:** one domain for web and universal/app links, so `/join/:code`, `/g/:code`, `/invite/:code` and `/tv/:code` open the app when installed and the web app otherwise.
- **TV:** either the TV opens `/tv/:code` in its browser (pairing code or QR), or the host phone casts the timer as a second screen (Chromecast / AirPlay — research open, O1). Build the browser path first; it needs nothing extra.
- **Offline:** Firestore offline persistence on; the authority phone must run a whole night with no network (§E9).
- **Locale:** English at launch; all strings in ARB files from day one. Dates and times follow the device locale, 24-hour where the locale uses it.

## E2. Layers

```
┌───────────────────────────────────────────────────────────────┐
│ SCREENS (Flutter widgets) — Part D                           │
│ public · shell · group · tournament · cash · account · tv    │
└──────────────────────────┬────────────────────────────────────┘
                           │ read state, call intents
┌──────────────────────────▼────────────────────────────────────┐
│ APP STATE (one state object, split by domain)                 │
│ auth · groups · game · players · tournament · clock · social │
│ notifications · settings · entitlement · codes · cash · sync │
└───────┬───────────────────────────────────┬───────────────────┘
        │                                   │
┌───────▼──────────────────┐   ┌────────────▼──────────────────┐
│ PURE LOGIC (no I/O)      │   │ SERVICES (I/O, platform)       │
│ structure engine (§F1)   │   │ firestore repository           │
│ payouts engine (§F2)     │   │ auth · push · voice/audio      │
│ seating §F3 · clock §F4  │   │ authority lock · recovery      │
│ permissions · projections│   │ billing · links · cast         │
│ money + formatting (E16) │   │ tv display settings            │
└──────────────────────────┘   └───────────────────────────────┘
                           │
┌──────────────────────────▼────────────────────────────────────┐
│ MODELS + ONE CODEC — the same wire format for cloud and device│
└───────────────────────────────────────────────────────────────┘
```

Three rules:

1. **One wire format.** A single codec serialises every model. The Firestore repository and the device-local recovery store both use it, so a crash snapshot and a cloud document are the same shape. No second serialiser. **Versioned:** every document and snapshot carries `_v` (codec version). A client reads any older `_v` losslessly, but refuses to become the authority for a document with a newer `_v` than it can write ("Update the app to keep running this game"). Bump `_v` only for a breaking field change; added optional fields don't need it.
2. **Pure logic is pure.** The engines, seating, permissions and projections take values and return values: no clock, no network, no randomness (the Monte-Carlo ICM takes a seed). That is what lets every device recompute the host's structure and check it (§E13), and what lets the engines be ported and tested against the JS vectors.
3. **One state object.** All mutable domain state lives in the app state layer (Provider/Riverpod — the team's choice). Screens hold only view state. This is what makes undo, authority and the single writer possible.

## E3. Domain model

```
AppUser ─┬─ profile: displayName, photoUrl, createdAt, consentHistory (D9)
         ├─ memberships → Group (role: host | coHost | member)
         ├─ results: GameResult[] (own copy per game — E14)
         ├─ chipSets: ChipSet[]          (the user owns the physical chips)
         ├─ templates: GameTemplate[]    (full value copies — F6)
         ├─ hostingDefaults: HostingDefaults?
         ├─ entitlement: {tier, source, expiresAt}   (server-written — G2)
         └─ legalAcceptances: [{kind:'organiserFee', copyVersion, at}]

Group ─┬─ name, avatar, createdBy, createdAt
       ├─ members: GroupMember[] {uid, role, joinedAt, displayName}
       ├─ joinCode (6 chars, E7)
       ├─ defaultChipSetId → one of the host's chipSets (a pointer, not a copy)
       ├─ tableSettings {maxPerTable 4–10 (default 9), seatMode}
       ├─ learningOptIn: bool (D9 per-group opt-out)
       ├─ seasons: Season[] {id, name, from, to, formula, customTable?}
       ├─ games: Tournament[] · chat · polls · notifications outbox
       └─ importedNights: ImportedNight[] (B12)

Tournament ─┬─ status (§E8) · code (game) · tvCode · _v
            ├─ hostUid (who created it) · coHostUids[] (copied from the group's co-hosts at posting; editable per game)
            ├─ settings: GameSettings (every input + every override — below)
            ├─ structure: {levels[], breaks[], colourUps[], rebuyCloseLevel,
            │               anteFromLevel, handouts, projectedEnd, explain[], meta}
            ├─ players: Player[]
            ├─ rsvps: Rsvp[] {uid|guestId, answer going|maybe|cant, plusOneOf?, at}
            ├─ waitlist: [rsvpId] (ordered)
            ├─ ledger: LedgerEntry[] {playerId, kind buyIn|rebuy|reEntry|addOn|bounty,
            │                          amount, owed|paid, at, by, idempotencyKey}
            ├─ seating: {tables[{id, seats[]}], history[]}
            ├─ clock: {currentLevel, segment, levelEndsAt (server time), status,
            │           pausedRemainingMs?, startedAt}
            ├─ payouts: {plan, fee (host-only), overrides?, deal?}
            ├─ results: finishes[{playerId, place, prize, knockouts, bustLevel, bustAt}]
            ├─ control: {revision, editorDeviceId, editorClaimedAt,
            │            audioMasterDeviceId, lastIdempotencyKey}
            ├─ dealTriggersShown: {targetTime?, bubble?, inTheMoney?, headsUp?} (each type once per game, §F2.8)
            ├─ audit: AuditRecord[] (host-only) · changeLog
            └─ actualDurationMins (written at completed; feeds pace learning)

CashSession ─┬─ stakes {sb, bb}, minBuyIn, maxBuyIn, chipSetId, chipValue
             ├─ trackSettlement: bool, status open|settled, startedAt
             └─ players: CashPlayer[] {id, name, buyIns[], topUps[], cashOut?,
                                       stack (host-tracked total), status}
```

**GameSettings** (every field nullable-override: `null` = the engine decides; a value = the host decided, and it is remembered):

| Group | Fields |
|---|---|
| Event | name, type (freezeOut · rebuy · reEntry · shootout), date, start, **finishBy**, location, expectedPlayersOverride, rsvpDeadlineHours (1–72, default 24), hardFinish {on, at, split icm/chips} (off by default, §F4) |
| Money | buyIn, bounty {on, amount, kind fixed/progressive/mystery}, payoutsMode none/standard, payoutOverrides?, fee {mode none/percent/fixed, value} (host-only; the engine also supports `perEntry`, which v1 does not offer — §F2.3), countRebuysForPlaces (default true) |
| Chips | chipSetId (+ a frozen copy at posting), earlyBonus {on, pct 2.5–25 step 2.5 (default 12.5)}, startingStackOverride, compositionOverride |
| Rebuys | rebuyMode unlimited/limited, maxRebuysPerPlayer (1–10, default 2 when limited), expectedRebuyRate (default 35 %), rebuyCloseLevelOverride, addOn {on, multiplier 1.10–1.50, price, takeUp 0–1 (default 0.7, or the learned value — §E14)}, reEntry, shootout {tables, targetMins} |
| Format | pace turbo/regular/deep (+ manual flag), noAddOn, ante {type none/bb/individual, fromLevelOverride}, maxPerTable, tables |
| Structure | levelsOverride (the edited ladder, with per-level `pinned` / `edited` / `played` flags) |

**Player:** `{id, uid? | guestId?, name, status, seat {table, seat}, rebuyCount, maxRebuysOverride?, addOnTaken, reEntryOf?, earlyBonus, checkedInAt, knockedOutBy?, knockouts, stack? (only when typed — D3), place?, bustLevel?, bustAt?}`

`Player.status`: `active | paused | out | removed | noShow`

- **paused** = out of chips and deciding; seat held, no place; resolves to `active` (rebuy) or `out` (bust); becomes `out` automatically when rebuys close (2026-09-25).
- **out** = final; place = active count before removal; asks "knocked out by".
- **removed** = a roster correction ("was never here"); no place, not undoable with the per-player undo.
- **noShow** = RSVP'd Going, not there at the start (C4 gate); no buy-in taken; can still be added as a late arrival.

**Plus-ones.** A plus-one is an `Rsvp` with `plusOneOf = the member's uid`. If a member's allowance drops or the member is removed, **unclaimed** plus-one slots are removed first; an approved guest (on the roster or checked in) is never dropped silently — the host is asked to remove them by hand.

**Pool.** The prize pool passed to the payouts engine = Σ ledger entries of kind `buyIn`, `rebuy`, `reEntry`, `addOn` (owed or paid — both count). `bounty` entries never enter it; they fund the bounty pot (§F2.4). `countRebuysForPlaces` is fixed to true in v1 (no control).

**Effective values** (never store what can be derived): `effectiveExpectedRebuys = expectedRebuyRate × players`; `effectiveAnteBias = hostingDefaults.anteBias ?? auto`; `rsvpDeadline = start − rsvpDeadlineHours` (host setting 1–72 h, default 24; O3); `rebuyCost = buyIn + (bounty.on ? bounty.amount : 0)`.

**Rule for every new input:** (a) it lives on GameSettings, (b) it goes through the codec, (c) it goes into the verification recompute (§E13). Miss (c) and every honest custom structure reports as tampered.

## E4. Storage

### Cloud (Firestore)

```
users/{uid}
  ├─ results/{gameId}         own finish record (E14)
  ├─ chipSets/{id} · templates/{id}
  ├─ notifications/{id}       inbox
  └─ private/entitlement      written by Functions only
groups/{gid}
  ├─ members/{uid}
  ├─ games/{gameId}           the full game (host + co-host read/write)
  │    ├─ players/{pid}
  │    ├─ rsvps/{id}
  │    ├─ requests/{id}       check-in and rebuy requests from players
  │    ├─ chat/{msgId}
  │    ├─ meta/undo           undo stack (30)
  │    └─ meta/private        organiser fee, gross pool, audit — host only
  ├─ chat/{msgId} · polls/{id} · seasons/{id}
  └─ notifications/{id}       outbox, fanned out by a Function
users/{uid}/soloGames/{gameId}  a quick game with no group (C0, A2b): the same Tournament shape and subcollections
groupPreviews/{gid}           name, member count, initials, games played — for the invite preview (A8)
reports/{id}                  chat reports, for the group host (§E10)
publicGames/{gameId}          projections: player · guest · tv (§E6)
codes/{CODE}                  → {kind group|game|tv, gid, gameId?}  (E7)
cashSessions/{id}             top-level; players embedded
rate_limits/{key}             server-side counters
```

**Why `publicGames` is separate.** A TV or a guest must never be able to read the full game document. The authority writes a **pre-stripped** copy, and security rules check the copy's shape (for example, `fee` absent and `ledger` absent). Rules never trust a client-side filter.

**Security rules (per collection).** Write these as Firestore rules with a rules test suite in CI; the client-side permissions of §E6 are the UX, these are the enforcement.

| Path | Read | Write |
|---|---|---|
| `users/{uid}` and its subcollections | that user | that user (`private/entitlement`: Functions only) |
| `groups/{gid}` | members | the group host |
| `groupPreviews/{gid}` | anyone holding the group code (read through the code Function) | Functions only |
| `groups/{gid}/members/{uid}` | members | create: **Functions only**, through `joinGroup(code)`, which checks the code first; update: the group host (roles); delete: the group host (removal) or the member themselves (leaving) |
| `groups/{gid}/games/{g}` and `players/*` | host, co-hosts (`hostUid`, `coHostUids`) | host, co-hosts — as a transaction that checks `control.editorDeviceId` for clock and state writes. **Co-hosts may change only** `clock`, `control`, `players`, `requests`, `ledger` and `rsvps`; `settings.*`, `hostUid` and `coHostUids` are host-only (a rule on the changed keys). **Premium fields** (`settings.tables > 1`, bounty `progressive`/`mystery`, a season, a 4th saved template) are accepted only when the host's `users/{hostUid}/private/entitlement.tier` is Premium |
| `users/{uid}/soloGames/{g}` and subcollections | that user, co-hosts they name | that user, co-hosts — same transaction rule |
| `…/games/{g}/meta/undo` | host, co-hosts | host, co-hosts — same transaction rule as the clock |
| `…/games/{g}/meta/private` (organiser fee, gross pool, audit) | `hostUid` only | `hostUid` only |
| `…/games/{g}/rsvps/{id}`, `requests/{id}` | host, co-hosts; the author | create/update: the author (own uid or guestId, own fields only); host and co-hosts |
| `…/games/{g}/chat/*`, `groups/{gid}/chat/*` | members (game chat: plus guests of that game) | members, own messages only, rate-limited; the group host may delete any message |
| `reports/{id}` | the group host of the reported message | create: any member (own uid); update: the group host |
| `publicGames/{g}` | anyone holding the game or TV code | a Function, or the host/co-host of that game (the rule reads the game's `hostUid`/`coHostUids`); the rule **allows only the projection's listed keys** (never `fee`, `gross`, `ledger` or anything added later). After `completed` the projection is deleted and the code released (§E7) |
| `codes/{CODE}` | **no client reads** — resolved only through the callable Function `resolveJoinCode` (§E7) | Functions only |
| `rate_limits/{key}` | Functions only | Functions only |
| `cashSessions/{id}` | the session host | the session host |

### Device-local

| Store | Contents | Why local |
|---|---|---|
| Recovery | the running game and cash session, `lastSavedAt` | "Resume" after a crash, refresh or closed app (T86) |
| Guest session | `{gameId, name, inviter, slot}` | A guest keeps the same approved seat across refreshes. The guest shell shows "Not {name}? Use a different name" (clears it and restarts the code step, for a phone passed round the table). If the host removes the guest, the next read shows "The host removed you from this game", clears the record and returns to A6 |
| TV display settings | text scale, panels, rotate seconds | The TV and the phone need different settings |
| Sound settings | §E11 | Per device by nature |
| Preferences | currency, keep awake, compact results, app tour | Per device |
| Pending deep link | one link, consumed after auth | §C3 step 9 |

## E5. Identity and the route guard

| Identity | Account | Sees | Can do |
|---|---|---|---|
| **Member** | yes | their groups, games, own results | RSVP, chat, vote, request check-in/rebuy |
| **Host** (per game) | yes | everything in their game | everything |
| **Co-host** (per game, D15) | yes | the game's live screens | bust, rebuy, pause, approve check-ins, run the clock |
| **Anonymous host** | anonymous auth | the quick game only | run tonight's game, share its codes (A2b) |
| **Guest** | no | one game's guest projection | claim a slot, RSVP, request check-in |
| **TV** | no | the TV projection | watch |
| **Visitor** | no | public tools | calculate |

Roles are resolved **per game**: `actor(game, uid) = uid == game.hostUid ? host : uid in game.coHostUids ? coHost : uid in group.members ? member : guest` (a TV has no uid and only ever gets the tv projection). The same person can host Tuesday and play Friday. Linking an anonymous account keeps its uid, so a game it hosts needs no rewrite when the host registers (A2b). The route guard (10 steps) and its refresh throttle are in §C3; build them exactly as written there.

## E6. Permissions and projections

Two separate mechanisms; both are required.

**Permissions — may this actor do this?** A constant table, `can(capability, actor)`. The only conditional cell: *view private financials* → host of this game only.

| Capability | Host | Co-host | Member | Guest | TV |
|---|---|---|---|---|---|
| Edit settings, structure, payouts, fee | ✓ | — | — | — | — |
| Hand over hosting, name co-hosts | ✓ | — | — | — | — |
| Take over the clock when the host's phone is gone 30 min (§E9) | ✓ | ✓ | ✓ (checked in, signed in) | — | — |
| Report a chat message · block a member | ✓ | ✓ | ✓ | — | — |
| Act on reports (delete message, remove member) | group host | — | — | — | — |
| View the structure and the level editor (read-only) | ✓ | ✓ | ✓ (C11) | ✓ (C11) | ✓ |
| Run the clock, bust, rebuy, pause, add-on, check-ins, seating | ✓ | ✓ | — | — | — |
| Record the finish order, confirm a deal | ✓ | — | — | — | — |
| See the organiser fee and the gross pool | ✓ | — | — | — | — |
| See the prize pool and payouts (D2) | ✓ | ✓ | ✓ | ✓ | ✓ |
| RSVP, request check-in/rebuy | ✓ | ✓ | ✓ | ✓ | — |
| Chat | ✓ | ✓ | ✓ | — (until they join) | — |

A guest can never be host or co-host (an organiser handles money; a guest has no verified identity and no durable session).

**Projections — which bytes leave the authority device?** `projectionFor(game, role)`:

| Field | host | co-host | player | guest | tv |
|---|---|---|---|---|---|
| Prize pool, paid places, prizes (D2) | ✓ | ✓ | ✓ | ✓ | ✓ |
| Organiser fee, gross pool | ✓ | — | — | — | — |
| Ledger (owed/paid per player) | ✓ | ✓ | own rows | own rows | — |
| Rebuys and knockouts per player | ✓ | ✓ | ✓ | ✓ | leaderboard only |
| Typed stacks (D3) | ✓ | ✓ | ✓ | ✓ | when shown |
| Audit, change log | ✓ | — | — | — | — |
| Game chat | ✓ | ✓ | ✓ | — | — |

With a fee on, the prize pool everyone sees is the **net** pool (after the fee). Open decision O5 is whether it is labelled "after organiser costs".

## E7. Codes

```
alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'   // 31 chars; no I, L, O, 0, 1
length   = 6, from a cryptographic RNG           // 31^6 = 887,503,681
kinds    = group | game | tv                    // one namespace, unique across kinds
```

- **Reservation:** a Cloud Function creates `codes/{CODE}` in a transaction; on collision it redraws.
- **Normalisation** (A7): take `?code=`, else the last path segment (strip query and fragment); upper-case; drop everything outside `[A-Z0-9]`.
- **Resolution** classifies without joining or subscribing to anything.
- **Rate limit:** 10 lookups per minute per device, sliding window, enforced on the client and again in the callable Function `resolveJoinCode`, the only way to read a code (it keeps the counter in `rate_limits/{appInstance}`, requires App Check, and returns just `{kind, gid | gameId}`). At 10/min, brute-forcing the space takes about 169 years.
- **Lifetime:** a game code and its TV code are released when the game is `completed` or `cancelled`, and the `publicGames` projection is deleted then (results stay in C9 and the players' own records). The host can **re-roll the TV code** any time (D3 settings); the old one stops working at once. The first time a TV reads a projection in a session, the host gets a toast "A TV connected to Friday Poker". A group code lives as long as the group; the group host can re-roll it (B9).
- **Joining a group** always goes through the callable Function `joinGroup(code)`: it resolves the code, checks the caller is not already a member, and writes `members/{uid}` with admin rights. No client can create a membership directly.
- A game's **TV code** is separate from its **game code**, so a TV link can never be used to RSVP or check in.

## E8. The tournament lifecycle

```
draft ──(structure confirmed, posted)──▶ scheduled ──(start reached; no-show gate)──▶ running
                                           │                                           │
                                           └──▶ cancelled                              ├──▶ paused ──▶ running
                                                                                       ├──▶ onBreak ──▶ running
                                                                                       ├──▶ rebuyPause (settlement, C6) ──▶ running
                                                                                       ├──▶ finalTable (redraw, C7) ──▶ running
                                                                                       └──▶ completed (finish order recorded)
```

- **draft** — created; the wizard or quick start is filling it. Not visible to members.
- **scheduled** — posted; invitations out; RSVPs open until the deadline (O3); the waitlist moves until the start. Check-in opens at start − 10 min.
- **No-show gate** — evaluated once at the start if anyone Going hasn't checked in: **Wait n min** or **Start without** (marks them `noShow`, no buy-in consumed).
- **rebuyPause** — the clock holds at the rebuy close; the settlement's three gated steps (C6) fix the headcount, the add-ons and the add-on chip breakdown; then **Confirm & resume**.
- **finalTable** — entered when a multi-table event gets down to one table's worth; redraw, then resume.
- **completed** — writes results, `actualDurationMins`, each player's own result copy, season points.
- **Quick games** (C0) skip `draft`/`scheduled`: they are created `running`.

**Per-field locks while running** (Configure stays reachable; each field has its own rule):

| Field | While running | Why |
|---|---|---|
| format, max re-entries | Locked | Rebuys and re-entries already recorded under the old rules |
| buy-in, rebuy price, add-on price, KO bounty | **Locked from posting** | Players answered the invitation at these prices |
| starting stack, rebuy stack, add-on multiplier, early bonus % | **Locked from the first check-in** (the first chips handed out) | Everyone plays with the same chips; verification needs a stable baseline |
| Rebuy close level | Editable until settlement step 1 submits | A timing choice until the window closes |
| Future levels, antes | Editable (level editor rules, C2) | Played levels lock; "correct the record" only |
| Chip set | Editable, forward only | Affects future colour-ups and handouts only |
| Per-player rebuy cap | Editable any time | A house-rule call on one player |
| Payout shape, fee | Editable until the first payout is shown; after that, confirm with the consequence; the fee is **locked outright once rebuys close** (§F2.3) | Changing numbers the table has seen |
| Pre-define add-on breakdown | Editable until settlement step 1 | Only changes when the breakdown is fixed |
| Hard finish (time, split) | **Locked from posting**; while running only **Play on** (+30 min, host, logged) | Players accepted it with their RSVP |

## E9. Sync, authority, undo, offline and recovery

**One writer.** Exactly one device writes the clock and the game state: the **authority**.

```
isAuthority = actor(game) in {host, coHost}
              && game.control.editorDeviceId == thisDeviceId
              && thisTabIsLeader                 // web: one tab per browser
```

- **Claiming:** no editor → claim; I am the editor → keep; the editor's heartbeat is older than **90 s** → claim (stale); otherwise do not claim. Heartbeat every 30 s.
- **Take over** (C-ops, T84): a second host/co-host device sees who runs the clock and can **Take over** or **Watch only**. Take over is always offered (not only when the heartbeat is stale): it writes `editorDeviceId = me` in a transaction and bumps the revision. There is no split brain because **every authoritative write is a transaction that first checks `editorDeviceId == thisDevice`**; the old device's next write fails, and it switches to a live view with "{name} took over the clock". **Nobody left to take over:** if the game has no co-host device online and the authority's heartbeat has been stale for **30 minutes**, every checked-in signed-in player sees "The host's phone isn't responding" with **Take over the clock** — it makes that player a co-host of this game and the authority in one transaction, is logged in the audit trail and announced on every device ("Sam took over the clock"). The host can take it back any time. **Hand over hosting** (host only, C-ops and B3): makes a co-host the host of this game (`hostUid` ↔ that co-host, the old host stays co-host) — the way to leave early without leaving the night unfinishable, and the step §E15 asks for before deleting an account.
- **Everyone else** derives the clock from `levelEndsAt` (server time) and rolls levels over **display-only** — no writes, no undo entries.
- **Server time:** write a server timestamp at local t₀, read it back at t₁, `offset = server − (t₀+t₁)/2`; every device shows `levelEndsAt − (now + offset)`. **Re-measure every 10 minutes** while a clock is running (and on app resume), so a phone whose clock jumps or drifts never shows a wrong countdown for long.
- **Revision:** every authoritative write increments `control.revision`. Each action carries an idempotency key bound to the revision it expects to produce; a retried action is a no-op. **Ledger rule:** a `buyIn` or `addOn` entry carries `idempotencyKey = gameId:playerId:kind`, so a second one for the same player is rejected (one buy-in and one add-on per player); `rebuy` and `reEntry` entries get a fresh key each time and always create a new row.
- **Targeted writes:** wherever two parties can write (RSVP, requests, chat), patch fields, never whole documents.
- **Undo:** a stack of **30** entries. Global undo pops the top; **per-player undo** removes that player's most recent rebuy, add-on or bust wherever it sits (filtered removal). "Remove player" is not undoable this way (roster correction). Every destructive action also shows an Undo toast for 5 s.
- **Offline:** the authority keeps the clock and records busts, rebuys, add-ons and check-ins locally (Firestore offline + the recovery store); the app-wide banner "Offline — the clock keeps running on this phone; changes sync when you're back" (§C1, T85). On reconnect it pushes in order; the TV and players catch up. Non-authority devices show "Reconnecting…" and keep counting from the last `levelEndsAt`. **If someone else took the clock while this device was offline**, its queued writes that target a superseded revision are **rejected, not merged**; the device shows "Someone else took over the clock while you were offline — {n} actions couldn't be applied" with the list (busts, rebuys, add-ons), so the host can redo the ones that are still right. **Limits:** offline covers a device that loaded the game before the signal dropped. A player, co-host, guest or TV opening the game for the first time needs a moment of signal to resolve the code and load it; a venue with no signal at all runs on the host's phone only (the TV and players catch up when someone gets a signal). **A bust is idempotent too:** its action carries `idempotencyKey = gameId:playerId:bust:{entryNo}`; a second bust for a player who is already `out` is a no-op — no second bounty, no second place.
- **Recovery:** the authority snapshots the game to the device after every write. Opening the app with a snapshot newer than the cloud copy offers **Resume** (T86); the clock picks up from the server time, having kept running.

## E10. Chat, polls and notifications

- **Chat scopes:** group chat (`groups/{gid}/chat`, any member) and game chat (`…/games/{id}/chat`, host and players). Guests read and post only after joining the group.
- **Moderation (Apple guideline 1.2, Google Play UGC policy):** (1) **Filter** — before a message is fanned out, a Function checks it against a word list per language (English and Portuguese at launch) and holds a match with "Your message wasn't sent — it looks like it contains offensive words. Edit it and try again."; (2) **Report** — long-press a message → **Report** (reason: offensive · spam · other) writes `reports/{id}`; the group host sees it in B9 with **Delete message** and **Remove member**, and the reporter gets "Thanks — the host has been told."; a report not handled in 24 h is emailed to support (H3); (3) **Block** — on a member's row or message: **Block {name}** hides their messages and polls for the blocker everywhere (stored on the blocker's user document) until unblocked in Settings → Blocked; (4) contact details are published in H3.
- **Rate limit:** at most **8 messages per 30 s** and **4,000 ms** between messages on the client; the server allows ~3,750 ms, so a compliant client is never silently dropped. A blocked send shows "Sending too fast — wait a moment." and keeps the text. Game chat and group chat are separate scopes with their own unread counts (B4).
- **Unread** = messages not deleted, not mine, newer than my last read; feeds the tab badge.
- **Polls:** votes stored per user (`votes: {uid: [optionIds]}`), so a change replaces the old vote and an empty vote removes it.
- **Notifications:** the device that causes an event writes one outbox document; a Function fans it out to members' inboxes and push. The originating device records the id and never re-banners its own event.
- **Types (13 — the one list; B6 shows exactly these):** game posted · RSVP deadline in 24 h · moved up from the waitlist · check-in open · "starts in 30 min" · seat confirmed · the host changed the start or finish time · rebuys closing (one level before) · final table · results posted · new poll · chat mention · someone joined the group. Each type has a per-user switch in Settings.

## E11. Sound and voice

```
SoundSettings (device-local)
  chime: true        // level-change chime
  warn5: true        // 5-minute warning
  warn1: true        // 1-minute warning + 5-4-3-2-1 countdown
  voice: true        // read the blinds aloud
  haptics: true      // vibrate on level change
  device: 'phone'    // where the room hears it: 'phone' | 'tv'
  on: true           // master Sound on/off (the switch on the scoreboard, T33)
  // no volume setting: the device's own volume applies
```

- **One voice in the room.** Only the **audio master** speaks: `audioMasterDeviceId` if set (the TV when "Plays on: The TV"), else the authority device. Chimes and haptics are per device.
- If the audio master has voice off, nobody speaks — the election never forces sound.
- **Words:** "Level four. Blinds five and ten, ante ten." · "One minute left in this level. Next: ten and twenty." · "Break. Ten minutes. Colour up the ones." · "Rebuys close after this level." Numbers read as words; no currency is spoken.
- **Test sound** plays the next level's announcement (T33). Web: audio needs a user gesture — the first tap on the dashboard unlocks it; show "Tap to turn on sound" until then. The TV page needs its own tap: when "Plays on: The TV" is chosen, D3 shows a full-screen "Tap to turn on sound" on first load; until someone taps it, the authority phone stays the audio master so no announcement is lost.
- **Keep awake:** the authority device and the TV keep the screen on while a clock runs (setting on by default).

## E12. TV display

```
TvDisplaySettings (device-local)
  textScale:       1.0   // 0.7–2.0; width-derived scaling is automatic on top
  showPayouts:     true
  showUpcoming:    true
  showLeaderboard: false
  rotateSeconds:   8     // presets 5 · 8 · 12 · 20 · 30 for rotating panels
```

- The TV reads only `publicGames/{id}` (tv projection). It never writes.
- One display in the default layout is free; custom layouts and more than one display are Premium (D4). A second display pairing shows the upgrade on the host phone, not on the TV.
- Landscape first; portrait falls back to a stacked layout. Minimum clock height 120 px on a 1080p screen.

## E13. Integrity and verification

**The question:** how does a player know the host didn't change the structure after the money was in?

- The engines are deterministic. Any device can recompute the structure from the game's own GameSettings and compare it with what was published: levels (un-edited ones must match; edited ones must be declared), breaks, rebuy close, starting stack.
- The fee is not part of what players can verify (it is host-only); verification computes against the net pool players see.
- **Trails:** `audit` (every action, actor, time, amount — host only) · `changeLog` (structural edits, shown in the level editor's history) · `revision` (monotonic) · the ledger (every entry with who recorded it).
- A mismatch shows the host a banner "This structure no longer matches its settings — republish?"; players see nothing alarming, only the edited-level marks the level list already shows.
- **What this is not.** Recomputation on an honest client, not a cryptographic guarantee: a modified client can still misreport to its own room. The money fields that matter (fee, ledger) are protected by the security rules in §E4, which don't depend on any client being honest.

## E14. Stats, history, standings, seasons and learning

- **Own record.** Each player keeps a copy of each result at `users/{uid}/results/{gameId}` `{groupId, gameId, date, place, entries, knockouts, bustLevel, prize?, buyInsPaid?}`. Stats never depend on the group document still existing. `place ≤ 0` (cancelled, unfinished) is skipped everywhere.
- **Profile stats** (F1, F3): played, wins, podiums (≤ 3), average finish, knockouts, win rate, ITM %. **Lifetime P&L** = Σ prize − Σ buy-ins paid; **visible only to its owner**.
- **Group standings** (B11): per group, games, wins, podiums, average finish, knockouts; sorted by podiums, then average finish. **No money** — no profit, no ROI, nothing derived from buy-ins or prizes. There is **no global leaderboard** across groups; the only cross-group view is a user's own record.
- **Recap** (C9): computed at `completed` — biggest comeback (lowest typed stack among the top 3; the line is omitted when no stacks were typed), fastest bust (lowest `bustLevel` among non-winners — every bust records its level), most knockouts.
- **Corrections.** The host can correct a finished game's results (C8 → History → Correct results). Standings and season points are always computed from the stored finishes, never stored, so they update by themselves.
- **Seasons (Premium):** `seasonPoints` / `seasonTable` (§F2.9) over the season's date range; formula field-size (default), 10-7-5-3-1, or custom (D14). Imported nights (B12) count.
- **Learning (with consent, D9):**
  - *Pace:* from the group's last **5** completed games, `meanOverage = mean(actualDurationMins − planned)`; if the average is at least 15 min over or under, propose `adjust = clamp(mean / planned, −20 %, +20 %)`. Shown to the host before generation with the measured average; **never applied silently**. Accepting shortens (or lengthens) the planned minutes the engine fits into.
  - *Rebuy rate:* from the last **8** completed rebuy/re-entry games, `rate = mean(confirmedRebuys / confirmedPlayers)`, clamped 0–100 %; shown in step 3 as "suggested · from your last 8 games"; accepting sets the rate. Fewer than 8 games → the plain 35 % default.
  - *Add-on take-up:* from the last **8** completed games with an add-on, `takeUp = mean(addOnsTaken / playersAliveAtTheAddOnBreak)`, clamped 0–100 %; shown in Configure §5 as "suggested · from your last 8 games"; accepting sets it. Fewer than 8 → the default 70 %. It changes only the chips-in-play estimate C (the finish target, §F1.3), never the chip bank check, which assumes every player takes the add-on.
  - *End-time estimate:* stores the final BB and the chips in play C per game to calibrate K (D8); retune after about 20 real nights.

## E15. Privacy, data and the legal gate

- **Consent (D9):** unchecked at sign-up; per-group opt-out; recorded with its copy version and time.
- **What is kept per game for learning:** bust times, bust levels, the final BB, the chips in play, actual duration, add-ons taken. Not kept when the group opted out beyond the game's own result.
- **Retention:** game data, chat and audit trails are kept while the group exists; a group with no activity for **24 months** is archived and its chat deleted, after an email to the host 30 days before. Chat reports are deleted 90 days after they are handled. Crash reports follow Crashlytics' 90-day retention.
- **Export:** JSON of profile, memberships, results, chip sets, templates, own chat messages.
- **Delete account:** a Function deletes the user's documents and auth record; in groups, results remain under "Former member"; the user's chat messages become "Deleted user". Before deleting chip sets, the Function clears every `defaultChipSetId` that points at one of them (the group's next host picks a new default). Deletion is **blocked** while the user hosts a scheduled or running game ("End or hand over your live games first"); drafts they alone host are cancelled.
- **Money is never moved.** No payment processing for games anywhere in the product; the ledger and settle-up are records and guidance only. Premium billing is the only money the app handles, through the stores.
- **Organiser fee:** off by default, behind the H4 gate, with a per-country remote flag, until a lawyer signs off per launch market (D13).
- **Minimum age:** 18, stated at sign-up (A4).

## E16. Input safety and formatting

- **Two different jobs.** *Input normalisation* runs once before a value is stored (below). *Output escaping* runs every time text is rendered into markup or a share image (never trust stored text). Build both; neither replaces the other.
- **Sanitising text** (names, chat, polls, group names): decode entities, remove dangerous tags, strip remaining HTML, collapse whitespace, trim, truncate to the field's limit (names 1–40, poll question 1–120, option 1–60, chat 1–1,000).
- **Money:** all arithmetic in integer minor units (cents); display rounds to whole units unless the amount has cents. **Never abbreviate money** (1,250, not 1.3K). Thousands separator from the locale.
- **Currency:** none by default; if the user picks €, $ or £ in Settings, every amount shows that symbol (device setting). The symbol is display only — no conversion, ever.
- **Chips and blinds:** plain integers with thousands separators; "k" is allowed only for chip values on swatches (1k, 5k) where space is tight, never for money.
- **Times:** clock times in the locale's format; durations as "4h 20m"; the level clock as mm:ss (h:mm:ss over an hour).
- **Names in lists:** "Firstname L." when two members share a first name; the initial avatar uses the first letter.

## E17. Automations — every automatic behaviour

Everything the app does or proposes without the user performing that exact action. Each row gives the trigger, the algorithm (with constants), where the result shows, how the host overrides or undoes it, the section that specifies it and the test that proves it. "none yet" means the behaviour is specified but the mock has no test; those are listed in §G2.3 and need tests in the real app.

### Before the night

| # | Automation | Trigger | Algorithm (short, precise, with constants) | Result and where it shows | Override / undo | Spec ref | Test |
|---|---|---|---|---|---|---|---|
| 1 | RSVP seating & waitlist queue | Player taps Going / Maybe / Can't / +1 | seats = maxPerTable × tables (free = 1 table); (n+1)th Going → waitlist; queue order = RSVP time; a guest queues from the moment it was added, never ahead of existing waiters | RSVP lists reorder; "Waitlist #n" label; C3 | Host can remove someone from Going (✕) | C3, D5 | T89 |
| 2 | Waitlist promotion on drop | A Going player (or you) drops | First entry beyond the seat cut is promoted automatically; notified | Toast "{name} dropped out — {promoted} is in and has been notified" | None — automatic | C3 | T89 |
| 3 | RSVP deadline lock | Wall clock reaches the RSVP deadline | `rsvpDeadline = start − rsvpDeadlineHours` (host setting 1–72, default 24, O3); after it, no new Going or +1; the waitlist still moves until the start | Buttons disabled; banner text changes | Host changes the hours in Configure §1 | §E3, C3, C-cfg | T90 |
| 4 | Second-table Premium prompt (D5) | RSVP "going" count exceeds one table's `maxPerTable` (10th on a 9-seat table) | Pure count check, no formula | Home + Configure card "that's a second table · PREMIUM"; free alt raises table max to 10 | Host taps the free alternative instead of upgrading | B1 item 7, G1 "where it appears" #1, D5 | T81 |
| 5 | "Same as last time?" repost suggestion | Group has a finished game and none currently planned/running | No formula — state check only; prefilled one week later | Home card → **Post for RSVP** (one tap) | **Change something first** opens C1 prefilled instead | B1 item 6 | T68 |
| 6 | Group / game / TV code generation | Creating a group/game, or a TV pairing request | 6 chars from `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (31 chars, no I L O 0 1); crypto RNG; server-transaction reservation, redraw on collision; one namespace across group\|game\|tv | Code pill + QR (B8, C-ops) | None — host cannot choose the code | §E7 | T112 |
| 7 | Code normalisation & resolution | User pastes/types a code, link, or scans a QR | Take `?code=` else last path segment; strip query/fragment; upper-case; drop chars outside `[A-Z0-9]`; classify without joining (group→A8, game member→C3, game non-member→A6, tv→D3, unknown→error) | Routes to the right screen, or "No game or group uses that code" | User retries | §E7, A7 | T123 |
| 8 | Code-lookup rate limit | Repeated code submissions | 10 lookups/min/device, sliding window, client **and** server | 11th attempt: "Too many tries — wait a minute" | Wait the window out | §E7, A7 | none |
| 9 | Rebuy-rate learning pre-fill | Group has ≥ **8** completed rebuy/re-entry games | `rate = mean(confirmedRebuys / confirmedPlayers)`, clamped 0–100 % | Step-3 slider pre-filled, pill "Suggested · from your last 8 games"; < 8 games → plain 35 % | Host drags the slider to override | §E14, §C-cfg item 5 | none |
| 10 | Pace-learning callout | Group has ≥ **5** completed games, \|mean overage\| ≥ **15 min** | `meanOverage = mean(actualDuration − planned)`; `adjust = clamp(mean/planned, −20%, +20%)` | Configure item 11 callout "runs long — averaged 34 min … speed up by ~14%?" | **Apply the adjustment** / **Keep standard pace** — never applied silently | §E14, §C-cfg item 11 | none |
| 11 | Template/preset pre-fill & forced regeneration | Host picks a starter preset or saved template | Pre-fills every wizard field, jumps to step 5; the structure is **always** regenerated for tonight's numbers, never replayed | Wizard step 5 shows a freshly generated structure | Host edits any field first | F6 | none direct |

### Check-in

| # | Automation | Trigger | Algorithm | Result and where it shows | Override / undo | Spec ref | Test |
|---|---|---|---|---|---|---|---|
| 12 | Check-in window auto-opens | Wall clock reaches `start − 10 min` | Pure time compare, no formula | C4p: Locked → Request state; host's stats strip updates | None | §E8, C4p | none yet (§G2.3) |
| 13 | No-show gate | Scheduled start reached and ≥ 1 "Going" player not checked in | Evaluated once; two host choices offered | Card "20:00 start — n confirmed player not checked in" → **Wait n more min** / **Start without her** (marks `noShow`, no buy-in taken, seat held) | Host can seat a late "no-show" as a normal late arrival afterwards | §E8, C4 | static card in the mock; no test yet (§G2.3) |
| 14 | Check-in confirm → auto-seat + handout + ledger | Host taps **Confirm** on a pending request | Random free seat at the shortest table (mode per seating option, §F3); `fewestChips` handout; ledger `owed += buyIn(+bounty)` | Toast "Sam is in at Table 1 · Seat 4 — hand over … , n owed to the pot" | Undo in the toast (5 s), or Remove player later (un-seats them and deletes the buy-in row) | C4, §F3, §F1.11 | T105, T32 |
| 15 | Confirm-all batch | 2+ pending check-in requests | Loops the single-confirm action over every pending request | "Confirm all" button appears at 2+ | n/a | C4 | T105 |
| 16 | Early-arrival bonus eligibility (D6) | Check-in confirmed **before** the scheduled start | `handout.earlyBonus` chips added at confirm; pct 2.5–25 % step 2.5, default 12.5 % | Bonus chips added to the stack at confirm | Toggle is off entirely at wizard step 2 (host, pre-game only) | §F1.1, §F1.11, D6, C1 step 2 | T32 |
| 17 | Late-arrival registration | Player arrives after start | Allowed while rebuys are open (rebuy formats) or until the first break (freeze-out); same seat+handout+ledger path as check-in; after the cutoff → blocked | "Late registration closed with rebuys — {name} can't enter now" | None once past cutoff | C4 | T100 |

### During play

| # | Automation | Trigger | Algorithm | Result and where it shows | Override / undo | Spec ref | Test |
|---|---|---|---|---|---|---|---|
| 18 | Clock level rollover (state machine) | Level timer hits 0 | `level` → the next level, or `onBreak`, or `rebuyPause` (the rebuy-close hold), or `end`; each transition: `revision += 1`, undo entry, announcement | Scoreboard state changes; voice; C5 clock-states table | Host: −1/+1 min, Restart, Previous, Add a level, Repeat last level | §F4, C5, §E9 | T53, T96, T116 |
| 19 | 5-/1-minute warnings + countdown | 5 min / 1 min left in a level | Chime + spoken text; 1-min triggers a 5-4-3-2-1 countdown | Audio + haptic, **and always a visual twin** whatever the sound settings: the clock's seconds pulse at 5:00 and 1:00, and the last five seconds show a large 5-4-3-2-1 on every Scoreboard (dashboard, player view, TV) | Per-device Sound Settings toggles (warn5, warn1, chime, haptics) | §E11 | T33, T107 |
| 20 | Pace recommendation | Entering wizard step 4 / Configure / quick-start | `paceOptions` runs the engine 3× (turbo/regular/deep); recommends the **slowest of Deep, then Regular** that fits + bank OK; **turbo is never recommended**; else a warning with 3 named choices | Pre-selected pace card; warning card replaces it when nothing fits | Host picks any pace or warning choice | §F1.3, C1 step 4, C-cfg item 7, C0 | T129, T130, T131 |
| 21 | Late-start refit | Game starts after `startTime` | `endBy` kept, `T` shrinks, engine re-fits; a pace that no longer fits raises the §F1.3 warning **before** the host starts; once running, no silent regeneration | Shorter finish window; possibly a new warning | Host re-picks pace pre-start; nothing changes automatically once running | §F4, §F1.3 | T130 |
| 22 | Ante-type recommendation | Entering Format step / Configure Ante section | **Auto** rule (§F1.8): players ≤ 6 and a night shorter than 3.5 h → no ante; otherwise → BB ante; never Individual. Then the host's bias: Always ON → BB ante, Always OFF → none | Pre-selected Ante segment (C1 step 4, Configure); the mock hard-codes BB ante | Host changes the segmented control | §F1.8, C1 step 4 | none yet (§G2.3) |
| 23 | Ante start-level default | Ante type chosen | Rebuy/re-entry → level after the suggested rebuy close; other formats → first level where the stack ≤ 40 BB | Stepper default | Host moves the stepper; can't start on a played/running level | §F1.8 | T6, T49, T77 |
| 24 | Individual ante amount (D7) | Ante type = individual, each hand | `10% of BB`, rounded to a chip still in play, ≥ 1 chip — verified exact in `computeAntes`, `structure_engine.js:781-786` | Ante value on level rows | n/a (a formula) | §F1.8, D7 | T77 |
| 25 | Rebuy-close suggestion | Structure generation (rebuy/re-entry) | Last level with `freshM ≥ Mmin` (turbo 10 / standard 15 / deep 20) **and** elapsed ≤ **40 %** of T | Suggested level + neighbours (ℓ−1, ℓ, ℓ+1) shown with fresh M and % of night | Host picks any level (T18/T19); never before the running level (T43); deleting it moves the marker back one (T48) | §F1.10, C-cfg item 5 | T18, T19, T43, T48, T73 |
| 26 | Rebuy-close hold ("rebuys close now") | Clock hits 0 on the rebuy-close level (rebuys open) | Clock holds; Next blocked until the host picks | Hold card "Last chance to rebuy" → **Close rebuys** / **Keep open one more level** | Host's choice each time it recurs | C5, §F4 | T53 |
| 27 | Pause → Out automatic at rebuy close (2026-09-25) | Host closes rebuys | Every currently-paused player is force-bust (`closeRebuys()` calls `bustOut` on each — verified `mockup/index.html:6250-6254`) | Toast names them "now out"; add-on window opens if applicable | None — automatic; per-player bust-undo only | §E3 `Player.status` (owner decision, 2026-09-25) | T34 |
| 28 | Add-on window open/close | Add-on break begins / Next moves past it | Break placed by the engine right after rebuy close (D1); add-on takeable once per player only during the break | Add-on control active only in the window | The window lasts the whole add-on break, including minutes added with +1 min; it closes when the break ends or Next is pressed | D1, §F1.9, C5, C-players | T53 |
| 29 | Add-on-break placement / re-solve | Rebuy format + add-on on | First break moves to right after the suggested rebuy close, same count/minutes; ladder re-solved once; kept only if the re-solve keeps the same close level | Break note "Add-on window" (+ colour-up note if coincident) | None direct | §F1.9 | worked example F1.15 |
| 30 | Colour-up plan & trigger | `raw BB ≥ 4 × next chip up` for a denomination | Retire at the **first break at or after** the trigger, never before the previous colour-up; largest chip never retired; no break left → stays in to the end — verified exact in `colourUpPlan`, `structure_engine.js:612-631` | Break note "colour up the {colour}s"; `cmin` updates from that break on | None — a structure edit (pin/insert) can shift the trigger, not a direct override | §F1.7 | T47 |
| 31 | Chip handouts (start/rebuy/add-on/bonus/late arrival) | Each of those events | `fewestChips`: DFS largest-chip-first, pruned by `n + ceil(rest/v) ≥ best`; rebuy = a fresh full stack | Exact chip breakdown in toast/handout card | Host can switch stack option (row 32) instead | §F1.11 | T31 |
| 32 | Stack-option choice (Engine pick vs Small-out) | Host taps either card, Configure item 4 | Option **A** every colour in every stack; **B** small chips shared once, rebuys/add-ons in the largest chip only, stack value adjustable S/2…3S | Re-derives stacks + blinds (`forceStack`); bank shortfall shown red if B doesn't fit | Switch back any time before locks apply (§E8) | §F1.11, C-cfg item 4 | T111 |
| 33 | Seating auto-split across tables | Check-in / start with N players | `ceil(N/maxPerTable)` tables; `base=floor(n/t)`, first `n mod t` tables get one extra | Field auto-divided into tables | Host overrides table count (≥ 2/table minimum) | §F3 | T20, T24, T55, T56 |
| 34 | TDA seat-rebalance suggestion | Largest − smallest table size ≥ **2** | Player due the big blind next (`(dealer+3) mod size`) moves to the seat posting the big blind next at the short table — verified exact in `planBalanceMove`, `mockup/index.html` | Confirm text names mover + destination seat | Host can decline the suggestion | §F3 | T65 |
| 35 | Break-a-table & redraw | `ceil(players/max) <` current table count | Every table redrawn fresh seats+dealers, each ≥ 2 players | Prompt "Break Table n and redraw?" | Host confirms/declines | §F3, C7 | T54 |
| 36 | Final-table auto-trigger | The remaining players fit on one table | Offered automatically; fresh random seat + dealer for all remaining | C7 "Redraw the seats" screen | Host taps Assign / Shuffle again | C7 | none yet (§G2.3) |
| 37 | Bubble detection | Remaining players = paid places + 1 | Pure count comparison | Bubble card/banner on dashboard, player view, TV | Informational only | C-bubble, §F3 | none isolated — see T82/T99 |
| 38 | Hand-for-hand | Host starts HFH on the bubble, 2+ tables | Pauses the clock between hands until every table marks "hand done"; ends automatically once everyone left is in the money | Banner "Hand-for-hand · hand n · waiting for …" | **Stop hand-for-hand** in the banner | §F3, C-bubble | T99 |
| 39 | Deal-suggestion triggers | `dealTrigger(state)` — see engine row 76 | Priority order `targetTime → bubble → inTheMoney → headsUp`, each fires **once per game**; the generic "Deal time?" proximity card is separately gated by the host's "Suggest an ICM deal from" setting (2–5, default 5) — verified exact in `payouts_engine.js:568-578` | Dashboard cards | Host dismisses; never auto-applies | §F2.8, C5, C-bubble | T79 |
| 40 | Bubble-save offer (D10) | Host taps **Offer a bubble save** | `bubbleSave` proRata: every paid place pays `amount × its prize / total`, whole units, 1st takes the rounding remainder | New ladder preview shown | **Record the bubble save** (confirm sheet) or **Not now** | §F2.7, C-bubble, D10 | T82 |
| 41 | Paid-places suggestion | Configure item 9 / wizard step 4, or live on entry change | `payoutPlan`: `ps15` curve → cap 6 → never > `floor(players/2)−1` → drop places while last < 1.5×buy-in or < 1 cash unit | Stepper pre-filled, **Use the suggestion** | Host overrides places or explicit shares | §F2.1, C-cfg item 9, G5#1 | T42, T74, T118 |
| 42 | Payouts live recompute | A rebuy/add-on/late entry changes entries | Re-run `payoutPlan` on the new entry count | "New entry: payouts updated. n places now paid." | n/a | C-payouts | T74 |
| 43 | Organiser-fee legal gate (H4) | Host switches contribution from None → Percent or Fixed, or country changes, or imports a template with a fee on | Blocking dialog, tick required to enable | Fee stays off until ticked+Enabled | Host can Cancel | H4, §F2.3 | none yet (§G2.3) |
| 44 | KO bounty pot & payout | Bust with bounty on | `buyIn+bounty` per entry/rebuy; bounty is a **separate pot**, never in the prize pool; paid to the eliminator(s) at the bust, split evenly on 2 picks | Bust sheet "Knocked out by"; toast credits eliminator | KO pick optional without a bounty (T29), required with one | §F2.4, C-players | T28, T29, T37, T38, T64 |
| 45 | Undo (global + per-player, toast) | Any destructive action | 30-entry stack; per-player undo removes that player's most-recent matching action regardless of what happened since (filtered removal) | Undo toast, 5 s (other toasts at least 4 s) | This **is** the override mechanism | §E9, §B4 Toast | T104, T27, T28, T51 |
| 46 | Ledger owed-money tracking | Buy-in, rebuy, add-on recorded | Entry stays `owed` until the host marks it `paid` | "Owed to the pot" card total; per-player "owes n" tag | Host taps to mark paid (with Undo) | §E3, C4 | T95 |
| 47 | Take-over of the clock | A 2nd host/co-host device opens the same running game | §E9 automatic claim: no editor→claim; I'm editor→keep; editor heartbeat > **90 s** (heartbeat every **30 s**) → claim as stale; else don't claim. C-ops UI: an unconditional **Take over** / **Watch only** choice, no staleness check named | Banner "Costa is running this clock on another phone" | **Take over** is always offered to the host and co-hosts; every authoritative write is a transaction that checks `editorDeviceId`, so the old device's next write fails and it drops to a live view (§E9) | §E9, C-ops | T84 |
| 48 | Offline / reconnect sync | Device loses/regains connectivity | Authority queues writes locally (Firestore offline + recovery store); on reconnect, pushes in order; non-authority shows "Reconnecting…" from last `levelEndsAt` | The app-wide offline banner (row 50) | None | §E9 | T85 |
| 49 | Server-time clock sync (non-authority display) | Continuous, every device | `offset = server − (t0+t1)/2`, re-measured every 10 min while a clock runs; display = `levelEndsAt − (now+offset)` | Every device shows the same countdown | None | §E9 | none direct |
| 50 | Connection banner | Device goes offline | Fixed copy, app-wide, under the top bar | "Offline — the clock keeps running on this phone; changes sync when you're back" | None | §C1 | implied by T85 |
| 51 | Haptic feedback on level change | Level-change event, host phone | Vibrate; on by default | Phone buzzes | Settings toggle | §E11 | T107 |
| 52 | Audio master election | Multiple devices in the room | `audioMasterDeviceId` if set (the TV when "Plays on: The TV") else the authority device; if that device's voice is off, nobody speaks | Exactly one device announces | Host picks "Plays on: phone/TV" | §E11 | none (single-device mock) |

### End of night

| # | Automation | Trigger | Algorithm | Result and where it shows | Override / undo | Spec ref | Test |
|---|---|---|---|---|---|---|---|
| 53 | Finish-order auto-fill from busts | Last bust leaves 1 player, or a deal is confirmed | Places = order of busts (last standing = 1st); prizes auto-fill from the payout plan/deal | C8 "Finish order" screen | Drag-to-reorder only to correct a mistake, only above the last recorded bust (A5 #14) | C8 | none yet (§G2.3) |
| 54 | Confirm results → writes + season points + history | Host taps **Confirm results** | Writes place/prize/knockouts/rebuys/bustLevel per player; `seasonPoints`; group history; `completed`; `actualDurationMins` (feeds pace learning) | Game marked complete; standings update | History → **Correct results** (host); standings and season points recompute | C8, §E14 | none direct |
| 55 | Recap "story of the night" | Game `completed` | Biggest comeback (lowest **typed** stack among the top 3, only when stacks were typed); fastest bust (lowest bust level among non-winners); most knockouts | C9, behind Why? if long | None | §E14, C9 | T93 (podium and knockouts; comeback and fastest bust need tests, §G2.3) |
| 56 | Share-card image generation | Tap **Share** on C9 | Fixed 1,080 × 1,350 canvas layout — verified exact in `shareResults()`, `mockup/index.html` | PNG via the OS share sheet | None | C9 | T93 |
| 57 | Season points computation (D14) | Game `completed`, or standings viewed | Default weighted: `10 × √(players/finish)`, 1 decimal; alt ladder 10-7-5-3-1; alt custom table | Season table updates | Host picks the formula (B11); switching it recomputes the whole season | §F2.9, B11 | T88 |
| 58 | Group standings ranking | Game `completed` and countable | All-time: sort by podiums, then average finish. Season: points, then wins, then name | B7/B11 tables update | None | §E14, B11 | T88 (partial) |
| 59 | Import past-results validation | Host submits the import text area | Per line: exactly one semicolon, valid date, ≥ 2 players, no duplicate player, no date already in the season; valid lines import even when others fail | "Imported n nights — standings and season points updated" | Host fixes and re-imports failed lines | B12 | T94 |

### Around the app

| # | Automation | Trigger | Algorithm | Result and where it shows | Override / undo | Spec ref | Test |
|---|---|---|---|---|---|---|---|
| 60 | Route guard auto-redirects | Every navigation / a 7-value state change (`authReady, isAuthenticated, hasGuestSession, isHost, gameId, gameStatus, groupId`) | 10-step ordered guard (rewrite legacy links, hold at splash, role checks, auto-follow, signed-out guard card, deep-link consumption) | Silent rewrite/redirect | System-enforced, no override | §C3 | none dedicated (§G2.3) |
| 61 | Recovery / resume snapshot | Opening the app with a local snapshot newer than the cloud copy | Authority snapshots after every write; compare timestamps; offer **Resume**; clock recomputed from server time, "having kept running" | Home hero "Resume" card | User taps to accept | §E9, §E4 | T86 |
| 62 | Guest session persistence | Page reload for a guest | `{gameId, name, inviter, slot}` kept device-local | Refresh keeps the same approved seat | None | §E4 | implied by T115, not directly tested |
| 63 | Notifications fan-out | 13 named events (game posted · RSVP deadline 24 h · waitlist promotion · check-in open · "starts in 30 min" · seat confirmed · start or finish time changed · rebuys closing one level before · final table · results posted · new poll · chat mention · someone joined the group) | Originating device writes one outbox doc; a Function fans it to inboxes + push; per-type Settings switch; originator never re-banners its own event; time-relative ones ("starts in 30 min", RSVP deadline, rebuys closing) are Cloud Tasks scheduled at posting and re-scheduled when the time changes | Notification row + tab badge | Per-type toggle in Settings | §E10, B6 | none yet (§G2.3) |
| 64 | Chat rate limit | Rapid messages | Client 8/30 s and ≥ 4,000 ms apart; server ~3,750 ms | "Sending too fast — wait a moment." (the text stays in the composer) | n/a | §E10 | none |
| 65 | Input sanitising pipeline | Any name/chat/poll/group-name entry | Decode entities, remove dangerous tags, strip remaining HTML, collapse whitespace, trim, truncate to field limit (names 1–40, poll Q 1–120, option 1–60, chat 1–1,000) | Clean stored string | None | §E16 | T63 tests display escaping only; the input pipeline needs tests (§G2.3) |
| 66 | Money / currency formatting | Any amount render | Integer cents internally; display rounds to whole units unless the amount has cents; never abbreviate; symbol None/€/$/£ display-only | Consistent number format everywhere | User picks the symbol in Settings | §E16 | T1 |
| 67 | TV rotate / text-scale auto-behaviour | TV device width; rotate timer | Width-derived scaling automatic on top of manual `textScale` (0.7–2.0); panels rotate every `rotateSeconds` (5/8/12/20/30, default 8) | TV display adjusts itself | Settings (device-local) | §E12 | none |
| 68 | Upgrade-prompt gating (never at the door) | Any Premium-only control tapped, or running-game screens | Prompt only at RSVP/second-table time, tapping a Premium control, or Settings→Plan; **never** on a live running game | Opens G1, or shows a PREMIUM pill | n/a | G1 "where it appears" | T81 |

### Engines

| # | Automation | Trigger | Algorithm (constants) | Result and where it shows | Override / undo | Spec ref | Test |
|---|---|---|---|---|---|---|---|
| 69 | Structure generation master pipeline | **Generate** tapped (wizard step 5, Configure, quick-start) | Full F1 pipeline: stack/chip proposal → blind ladder → colour-up → antes → breaks → rebuy-close → projected end → `explain[]` | Whole structure object written | Every field overridable after, per §E8's per-field lock table | §F1.1–F1.15 | T75, T117, T2; worked example F1.15 |
| 70 | Chip-set value normalisation (unnumbered chips) | Engine run with a chip set that has no printed values | Rank colours by count (most numerous = lowest value); pick the family whose adjacent ratios are closest to ×4 among 5 candidate ladders; `assumed:true` flagged | Values inferred, UI told to say "assumed" | Host sets values in F5 ("Suggest values" uses the simpler 1-5-25-100… ladder; same answer for 4–5 colours) | §F1.4 | T122 |
| 71 | Starting stack & chip composition proposal (bank-aware) | Engine run | Bank sized at the Poisson **90th percentile** of rebuys; every player assumed to take add-on + bonus; `scoreComposition` penalty formula (see §F1.5); depth is a **hard** band filter; a composition wins only by > **3** points | Proposed S + composition + `bankCheck` | Host picks stack option B instead (row 32) | §F1.5 | worked example F1.15 |
| 72 | DP blind-ladder snap | Engine run | `dpSnapLadder`: nice multiples of `2×cmin` in `[raw/1.6, raw×1.6]`; cost = Σ(ln ratio)² + growth penalty; `fallbackChain` if no chain exists | Nice, strictly-increasing, payable ladder | This **is** the generation step; host edits levels afterwards | §F1.6 | T7, T78 (fuzz) |
| 73 | Level-editor auto-resolve around pins | Host edits/inserts/deletes a level | `resolveAroundPins`: geometric interpolation between pins + DP snap; after the last pin, re-target `BB_end` over the remainder; infeasible → explicit refusal message | Unpinned levels re-solved live | Host's edit **is** the trigger; **Recalculate** reruns it | §F1.12 | T3, T4, T14, T16, T17, T44, T45, T46, T78 |
| 74 | ICM computation | Deal screen / ICM tool opened with stacks + prizes | Exact DP up to **2,000,000** states, else **200,000**-sample seeded Monte-Carlo (Park–Miller `s=s×16807 mod (2³¹−1)`) | Equity per player, `method: exact\|montecarlo` | n/a — host picks which split to use as the agreed amounts | §F2.5 | T119, T144 |
| 75 | Chip chop / equal chop / leaveForWinner | Deal screen | §F2.6 formulas | Alternate splits shown side-by-side | n/a | §F2.6 | T62, T98 |
| 76 | Deal rounding | Agreed amounts pre-filled | Floor each to the cash unit; largest-remainder distribution; order repair moves a unit to 1st if a place would exceed the one above | Amounts sum exactly to the net pool | n/a | §F2.2, §F2.7 | worked examples only |
| 77 | Cash settle-up (fewest transfers) | **Settle** tapped | Bitmask DP finds the maximum disjoint zero-sum grouping; `transfers = people−groups`; greedy pairing inside each group | Minimal transfer list + Copy as text | None — deterministic | §F2.10 | T87 |
| 78 | Cash reconciliation "Recount" gate | Settle attempted with counted stacks ≠ `onTable` | `onTable = issued − returned`; settle blocked until they match | "Recount: the stacks add up to X but Y is on the table" | Host fixes a stack and retries | §F5 | implied by T87, not isolated |

### Safety nets (added in v3.1)

| # | Automation | Trigger | Algorithm | Result and where it shows | Override / undo | Spec ref | Test |
|---|---|---|---|---|---|---|---|
| 79 | Organiser-fee clamp | Rebuys close with a fixed fee ≥ the real pool | fee := pool − one cash unit | Host sees "Your contribution was lowered to {x} — fewer entries than expected." | Host can lower it further | C-cfg §10, §F2.3 | none yet (§G2.3) |
| 80 | One buy-in and one add-on per player | A second buy-in or add-on write for the same player | Rejected by `idempotencyKey = gameId:playerId:kind` for `buyIn`/`addOn`; rebuys and re-entries always create a new row | Nothing happens on a double tap; a retried write is a no-op | — | §E3, §E9 | none yet (§G2.3) |
| 81 | Plus-one reconciliation | A member's plus-one allowance drops, or the member is removed | Unclaimed plus-one slots go first; an approved guest is never dropped silently | Host is asked to remove the guest by hand | Host decides | §E3 | none yet (§G2.3) |
| 82 | Stale offline writes | A device reconnects after someone else took the clock | Queued writes aimed at a superseded revision are rejected, not merged | "Someone else took over the clock while you were offline — {n} actions couldn't be applied" with the list | Host redoes them by hand if still right | §E9 | none yet (§G2.3) |
| 83 | App-version gate | A device opens a game document written with a newer codec version `_v` | It can read and display; it will not become the authority | "Update the app to keep running this game" | Update the app | §E2 | none yet (§G2.3) |
| 84 | Drift line | Projected finish differs from `endBy` by more than 20 min while running | §F4 drift formula | One line at the top of the Speed panel | Host acts, or ignores it | §F4, C5 | none yet (§G2.3) |
| 85 | Walk-in / late-arrival gate | Adding a paying entry | Allowed while rebuys are open (rebuy formats) or until the first break (freeze-out); hidden once the settlement showed the final pool | Button hidden, or "Late registration closed…" | — | C4, C-players | T100 |
| 86 | Same-hand busts | Two or more out in one hand | One table: the bigger starting stack finishes higher. Across tables in hand-for-hand: they tie, their places' prizes are pooled and split with `roundDeal` | Places and prizes in the finish order | Undo bust | C-players, C-bubble | none yet (§G2.3) |
| 87 | Account-deletion cascade | A user deletes their account | Clear `defaultChipSetId` pointers to their chip sets; block while they host a scheduled or running game; cancel drafts they alone host; results stay as "Former member" | Confirm sheet, then sign-out | Blocked until live games end or move | §E15 | none yet (§G2.3) |

### Added in the final review (27 September 2026)

| # | Automation | Trigger | Algorithm | Result and where it shows | Override / undo | Spec ref | Test |
|---|---|---|---|---|---|---|---|
| 88 | Chip case too small | Structure generation (wizard, Configure, quick start) | No candidate stack reaches `MIN_PLAYABLE_DEPTH` (20 BB) or fits the bank → fallback flagged `feasible: false`; `maxPlayers` found by counting down from N − 1 | Blocking card in C1 step 4 and Configure with the one-sentence note and three buttons; **Create** disabled | Host adds chips (F4), lowers the rebuy/add-on forecast or plays a freeze-out | §F1.5 point 7, C1 | engine suite (3 assertions) |
| 89 | Add-on take-up learning | Group has ≥ 8 completed games with an add-on | `takeUp = mean(addOnsTaken / playersAliveAtTheAddOnBreak)`, clamped 0–100 % | Configure §5 pill "Suggested · from your last 8 games" | Host edits the stepper | §E14 | none yet (§G2.3) |
| 90 | Hard-finish warning | `hardFinishAt − 15 min` while running | Clock check each tick | Banner on the dashboard and the TV | None (information) | §F4, C5 | none yet (§G2.3) |
| 91 | Hard finish reached | `hardFinishAt` with ≥ 2 players left | Clock holds after the hand; C-deal opens with the agreed split (ICM or chip chop) | Card "Hard finish — split the prizes by …" | **Play on** (+30 min, host, confirm, logged) | §F4, C-deal, C8 | none yet (§G2.3) |
| 92 | Chat filter | A member sends a message | Function checks a per-language word list before fan-out | Held: "Your message wasn't sent — it looks like it contains offensive words. Edit it and try again." | Member edits the message | §E10 | none yet (§G2.3) |
| 93 | Report escalation | A report still open after 24 h | Function emails support (H3) with the message and the group | Support handles it | Host handles it first (B9) | §E10 | none yet (§G2.3) |
| 94 | Host's phone gone | No co-host device online and the authority heartbeat stale for 30 min | Offer **Take over the clock** to checked-in signed-in players; transaction makes the taker co-host + authority | Card on players' phones; announcement on every device | The host takes it back any time | §E9 | none yet (§G2.3) |
| 95 | Code release | Game `completed` or `cancelled` | Delete `publicGames/{gameId}`; mark the game and TV codes expired | Old links show "This game has ended" | None | §E7 | none yet (§G2.3) |
| 96 | TV connected | First projection read by a TV in a session | Presence write → host toast | "A TV connected to Friday Poker" | **Re-roll the TV code** (D3) | §E7 | none yet (§G2.3) |
| 97 | Inactive group archive | 24 months without activity | Email the host 30 days before; then archive and delete chat | Group shows "Archived" to members | Host activity (any game or post) resets the clock | §E15 | none yet (§G2.3) |

---


# PART F — THE ENGINES

Two pure engines hold all the maths: **`structure_engine.js`** (759 test assertions) and **`payouts_engine.js`** (55). Both are ES5, no dependencies, no clock, no network; the only randomness is the seeded Monte-Carlo ICM.

**How to use this part.** Port each engine to Dart function by function, keep the same names, and run the same vectors (the HTML test pages in `research/` list every assertion; export them to JSON and run them in `flutter test`). This part explains what each function does and why, so a reviewer can follow the port. **If this text and the code disagree, the code and its tests win**, and the text is a bug to report.

Every number in the worked examples below was produced by the engines on 26 September 2026.

---

## F1. The structure engine

### F1.1 Inputs and outputs

`generateStructure(inputs)`:

| Input | Meaning | Default |
|---|---|---|
| `chipSet` | `[{colour, value, count}]`; `value: null` for unnumbered chips | required |
| `players` | expected players N | required |
| `format` | `freezeout` · `rebuy` · `reentry` · `shootout` | `freezeout` |
| `startTime`, `endBy` | "20:00", "00:30" — the night's window; `T = clockDiff(start, endBy)` (crosses midnight) | start 19:00 |
| `targetDurationMinutes` | used only when there is no `endBy` | — |
| `pace` | `turbo` · `regular` · `deep`; absent = the legacy phased mode (§F1.13) | — |
| `expectedRebuyRate` | rebuys per player | 0.35 |
| `maxRebuys` | per-player cap when rebuys are Limited | none |
| `addOn` | `{enabled, multiplier 1.10–1.50, takeUpRate}` | off; multiplier 1.25; take-up 0.7 |
| `anteType` | `none` · `bb` · `individual` | `none` |
| `earlyBonusPct` | 0.025–0.25 | 0 (off). The wizard pre-fills 12.5 % when the host turns the bonus on |
| `forceStack` | a distribution picked from `stackOptions` (§F1.11) | — |

Output: `startingStack`, `chipsPerPlayer`, `bankCheck {ok, perDenom[{value, needed, owned, ok, marginPct}], note}`, `handout {start, rebuy, addOn, earlyBonus}`, `levels [{num, sb, bb, ante, minutes, minChip}]`, `breaks [{afterLevel, minutes, colourUp[], note}]`, `rebuyClose {suggested, options[], reason}`, `projectedEnd {minutes, low, high, clockTime, clockLow, clockHigh}`, `explain [{step, text, numbers}]`, `meta {style, format, K, g, C, pace, targetMinutes, fits, depthShortfall, targetLevel, chipSetAssumedValues, icmTrigger}`. `icmTrigger(playersRemaining, currentLevel, targetLevel)` is a **function**, not a value — it returns `{shouldOfferDeal, playersRemaining, currentLevel, targetLevel, note}` and is true once `currentLevel ≥ targetLevel` with more than one player left (the engine produces the trigger only; the deal maths is §F2.5–F2.7). In Dart make it a method; note `JSON.stringify` drops it, so parity tests must check it separately.

### F1.2 Constants

| Name | Value | Meaning |
|---|---|---|
| `STYLE.turbo` | D 60 · g 1.45 · Lmin 12 · Mmin 10 | target depth in BB, growth, level floor, rebuy-close M floor |
| `STYLE.standard` | D 100 · g 1.36 · Lmin 15 · Mmin 15 | |
| `STYLE.deep` | D 160 · g 1.28 · Lmin 20 · Mmin 20 | |
| `DEPTH_BAND` | turbo [50, 70] · standard [85, 130] · deep [150, ∞) | **hard** constraint on the starting depth |
| `PACE` | turbo L 15, gMax 1.6 · regular L 20, gMax 1.5 · deep L 30, gMax 1.45 | one level length all night |
| `PACE_G_MIN` | 1.2 | slower than +20 % a level just ends early |
| `SPARE_LEVELS` | 4 | levels published past the target end |
| `MIN_PLAYABLE_DEPTH` | 20 BB | the least a starting stack may be; below it the case is too small for the field (§F1.5 point 7) |
| Fit tolerance | 5 min | a pace fits when the night needs at most 5 minutes more than its window (§F1.3) |
| `K_BASE` / `K_ANTE` | 20 / 27 | end target: BB_end = C / K |
| `NICE_M` | 1, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6, 8 (× 10ᵏ) | "nice" values |
| `MAX_PER_DENOM` | 24 | per-colour search ceiling |
| `PHASE_RATIO` | turbo 12:12:12 · standard 15:13:11 · deep 20:17:15 | legacy phased mode only |
| Breaks | 10 min each; `floor((T − 30) / 90)` of them; every ~90 min of play | |
| Rebuy pause | 10 min (rebuy and re-entry formats) | the settlement hold |

### F1.3 Pace mode — fitting a night to its finish time

The owner's model (2026-09-26): **one level length all night** — Turbo 15, Regular 20, Deep 30 min. The climb per level is whatever reaches the finishing blind by the finish time, capped at the pace's `gMax`.

```
T  = clockDiff(startTime, endBy)                       // a late start keeps endBy → T shrinks
P  = max(30, T − breaks.total − rebuyPause)            // minutes of play
C  = S × (N + Rforecast) + addOnMult × S × N × takeUp + bonusPct × S × N   // every chip that enters play
BB_end = C / K                                          // K = 27 with any ante, else 20
BB1    = niceBB(S / STYLE[style].D, cmin)               // opening big blind

solveUniformLevels(S, C, BB1, K, pace, P):
  L     = PACE[pace].L
  eFit  = max(2, floor(P / L))                          // levels that fit
  gFit  = (BB_end / BB1)^(1 / (eFit − 1))
  fits  = gFit ≤ gMax  or  levelsNeeded × L ≤ P + 5       // a fraction of a level over still fits (the same 5 min as meta.fits)
  g     = fits ? min(max(gFit, 1.2), gMax) : gMax
  e     = fits ? max(2, min(eFit, ceil(1 + ln(BB_end/BB1)/ln g)))
               : ceil(1 + ln(BB_end/BB1)/ln gMax)       // runs over; paceOptions warns
  raw[i] = BB1 × gⁱ   for i < e + 4                     // 4 spare levels
```

If the pace does not fit, the breaks are re-planned for the longer night (`planBreaks(e × L + rebuyPause)`), so a night that runs over still gets its breaks.

`meta.fits = fits && projectedEnd.minutes ≤ T + 5`.

**`paceOptions(inputs)`** runs the engine three times (turbo, regular, deep) and returns each pace's opening blind, depth, levels to the finish, finish clock, `fits`, `overBy` and bank status, plus:

- `recommended` = the **slowest of Deep, then Regular** that fits and whose bank is OK. **Turbo is never recommended.**
- If neither fits → `warning`: *"At a regular pace this field needs about {h}h{mm}; the night has {h}h{mm}."* with `choices`: **later** (keep 20-minute levels, finish at …), **noAddOn** (only when an add-on is on — re-run without it), **turbo** (15-minute levels, finish at …). The host picks; nothing is applied silently.

### F1.4 Chip set normalisation

- Numbered chips pass through (`assumed: false`).
- Unnumbered chips: rank colours by count (most numerous = lowest value) and pick the family whose adjacent ratios are closest to ×4 among `[1,5,25,100,500,1000]`, `[1,5,10,25,100]`, `[5,25,100,500,1000,5000]`, `[25,100,500,1000,5000,25000]`, `[1,2,5,10,50,100]`. Values are marked `assumed: true` and `meta.chipSetAssumedValues` tells the UI to say so.
- The chip-set editor's "Suggest values for me" (F5 screen) uses the simpler ladder 1 · 5 · 25 · 100 · 500 · 1,000 · 5,000 · 25,000 from the biggest pile up; both give the same answer for the common 4–5-colour case.

### F1.5 Starting stack and chip composition (bank-aware)

The engine **proposes** the starting stack S; the host does not type it.

1. **Bank sizing for a busy night:** `Rbank = PoissonQuantile(mean = Rforecast, 0.90)` (capped at `maxRebuys × N` when Limited); **every** player is assumed to take the add-on and the early bonus. Blind pacing still uses the expected values; only the bank check is conservative.
2. `draws = N + Rbank`; `S_max = bankValue / (draws + addOnMult × N + bonusPct × N)`.
3. Candidate S values: nice numbers ≤ S_max, deepest first; evaluate up to 20.
4. For each S, `solveChipPlanBounded`:
   - eligible chips: value ≤ S/2 (the smallest chip always eligible); the smallest must be ≤ the opening SB;
   - search counts 0–24 for up to three free denominations; the next one takes the remainder; 3–5 denominations used;
   - score with `scoreComposition` (lower is better):
     ```
     smallest chip: target count t = 12 if v1/v0 = 4 else 10
                    pen += ((c0 − t)/2)² + (c0 < 8 || c0 > 16 ? 25 : 0)
     each chip i>0: pen += 15 if the chips below it are worth < 2 × its value
     total chips n: pen += 3 × max(0, 20 − n) + 3 × max(0, n − 40) + (25 ≤ n ≤ 35 ? 0 : 2)
     each count divisible by 5 or 2: pen −= 0.5
     ```
   - then the **caller** (`solveChipPlanBounded`) adds the **soft 25 % rule**: +12 × count for every chip worth more than S/4. It lives in the caller because `scoreComposition` never receives S.
   - **hard bank check**: `count × draws ≤ owned` per colour, then the add-on and bonus handouts (`fewestChips`, §F1.11) must fit in what is left.
5. **Depth is a hard rule.** `depth = S / niceBB(S / D, smallest chip used)`. Only stacks inside `DEPTH_BAND[style]` compete; if none reaches the band, only the closest ones do, and `depthNote` tells the host the case is too small ("Your chip case supports at most n BB deep …").
6. Among the qualifying stacks, a composition wins only if it scores **more than 3 points better**; on a near tie the deeper stack wins.
7. **A playable floor.** A candidate stack counts only when its depth is at least `MIN_PLAYABLE_DEPTH` = 20 BB (below that everyone is short-stacked from the first hand). If no candidate reaches it — or no composition fits the bank at all — the case is **too small for this field**: the engine returns a single-denomination fallback flagged `bankCheck.ok = false`, `feasible = false`, `meta.fits = false`, and finds the largest field it does cover (`maxPlayers`: the same rebuy rate, add-on and bonus, counting down from N − 1). The note is one sentence: "Your chip case cannot give 22 players a playable stack (at least 20 big blinds) with the forecast rebuys and add-ons. It covers up to 20 players with rebuys and add-ons. Add chips, expect fewer rebuys or add-ons, or play a freeze-out." The wizard shows it as a blocking card (C1 step 4). Before this rule (fixed 27 September 2026) the engine dealt 1–4 chip stacks as "fits, bank OK": the 500-piece set with rebuys and add-ons from 21 players, the 390-piece demo case from 12.

### F1.6 The blind ladder

- **Nice values.** `niceValuesInRange(unit, lo, hi)` returns integers `m × 10ᵏ` (m ∈ NICE_M) that are multiples of `unit`. A big blind must be a multiple of **2 × cmin** (the smallest chip in play at that level), so its half is always payable.
- **Chips in play** are the colours actually dealt (start, rebuy, add-on, bonus) — never every colour in the case. A colour the stack search left out is never asked for by a blind, and the largest chip that is never coloured up is the largest one **dealt**. (Fixed in v3.1: the engine used to plan colour-ups from the whole case, so some realistic nights asked for a chip nobody had — e.g. 12 players with only 5s, 25s and 100s dealt got L2 = 6/12. The regression sweep of 240 nights is in `structure_engine_test.html`.)
- **Opening BB:** `niceBB(S / D, cmin)` — the nice BB nearest (in log distance) to the target depth.
- **End target:** `BB_end = C / K` — about 5 % of all chips in play (K 20), or ~3.7 % with antes (K 27, [Hypothesis], retune after ~20 nights, D8).
- **DP snap** (`dpSnapLadder`): for each level, candidates are nice multiples of 2 × cmin within [raw/1.6, raw × 1.6]; level 1 is pinned to BB1. Minimise
  ```
  cost = Σ (ln(v_i / raw_i))²  +  Σ penalty(v_i / v_{i−1})
  penalty(r) = 5 if r > 2.0;  0.3 × (r − 1.67) if 1.67 < r ≤ 2.0;  + 0.5 if r < 1.15
  v_i > v_{i−1} strictly (anything else is rejected)
  ```
  If no chain exists, `fallbackChain` takes the next nice BB above the previous level, level by level (always increasing, always payable).
- **Small blind** (`chooseSB`): `SB = round(BB/2 / cmin) × cmin`, at least cmin, below BB. At a colour-up boundary the previous SB may be **held** if it is still a multiple of the new cmin and holding tracks the ladder's growth better (the 25/75-style step).

### F1.7 Colour-up

```
chips = the dealt denominations, ascending
for each chip d except the largest (ascending), next = the chip above d:
    trigLevel = the first 1-indexed level whose RAW big blind ≥ 4 × next
    retire d at the first break whose afterLevel ≥ trigLevel − 1
        (the break right BEFORE trigLevel, or a later one)
        and ≥ the previous colour-up's break
    no such break → d and every larger chip stay in play to the end
    from that break on, cmin = next
```
Mind the indexing: the engine compares the 0-indexed position of the trigger with 1-indexed `afterLevel`, which is the same as `afterLevel ≥ trigLevel − 1`. This retires the chip at the break just **before** it stops being needed, so the trigger level already has the coarser chip. A literal port of "at or after the trigger level" (`afterLevel ≥ trigLevel`) would retire every chip one break late.

Rules (owner, 2026-09-25): colour-ups happen **only at breaks**; the **largest chip is never coloured up**; every blind after a colour-up is payable with what is left. Colour-up method at the table: round up, no chip race.

### F1.8 Antes

- **Types:** none · **BB ante** (one ante per hand, posted by the big blind, = BB) · **individual** (every active player posts **10 % of the BB**, rounded to a chip still in play, never below one chip — D7).
- **From which level:** rebuy/re-entry formats → the level after the suggested rebuy close; other formats → the first level where the starting stack is ≤ 40 BB.
- **Which type is suggested — the Auto rule** (a pre-selection the host can change; not in the JS engine — implement it as `recommendAnte(players, nightMinutes)` with the vectors below):
  ```
  players ≤ 6 and nightMinutes < 210  → no ante
  otherwise                           → BB ante
  (Individual is never suggested; the host can still pick it)
  ```
  Vectors: (6, 180) → none · (6, 240) → bb · (10, 180) → bb · (12, 270) → bb. The host's hosting default **Ante: Always suggest ON / Auto / Always suggest OFF** biases the pre-selection: Auto = the rule; Always ON = BB ante; Always OFF = none. (Changed in v3.1: the old rule suggested Individual for small tables, which the home-game research advises against, §G4.)
- Any ante switches K to 27.

### F1.9 Breaks and the add-on break

- `nBreaks = floor((T − 30) / 90)`, 10 minutes each, placed after the level where ~90, 180, … minutes of play have elapsed.
- **Add-on break** (D1): with rebuys and an add-on on, the first break moves to right after the suggested rebuy close (same number of breaks, same minutes), and the ladder is re-solved once for the new position; the move is kept only if the re-solve keeps the same close level. The break's note is exactly `Add-on window`, or `Colour up {values}`, or — when both fall on the same break — `Colour up {values}; add-on window` (colour-up first).

### F1.10 Rebuy close, projected end and the explanation

- **Rebuy close** (rebuy and re-entry formats): for each level, `freshM = S / (SB + BB + anteTotal)` with the ante total for 8 players. The suggestion is the **last** level with `freshM ≥ Mmin` **and** elapsed play ≤ **40 %** of T. The host sees that level and its neighbours (ℓ−1, ℓ, ℓ+1) with fresh-stack depth, M and % of the night. Two deliberate approximations: the SB in `freshM` is BB ÷ 2 (not a held SB), and the ante total assumes 8 players whatever the headcount, so M reads the same on nights of different sizes.
- **Bootstrap order.** `freshM` needs the ante, and the ante starts after the rebuy close — a cycle. The engine breaks it: it runs `suggestRebuyClose` once with a placeholder `anteFromLevel = floor(targetLevel × 0.5)`, then recomputes the antes from the real close level. Port both passes in this order.
- **Projected end:** minutes to the end of the target level plus the breaks before it; range `low = minutes − max(L, 15)`, `high = minutes + 2 × max(L, 15)`; converted to clock times from `startTime`.
- **`explain[]`** — one entry per decision (starting stack, bank, end, pace, rebuy close, colour-up, projected end), each with the exact host-facing text and its numbers. Screens render it behind **Why?** (§B4). In pace mode the `pace` step reads "Every level is {L} minutes (the {pace} pace). The blinds climb about {n}% a level to finish by {endBy}." (fixed in the engine in v3.1; the phased wording remains for legacy mode).

### F1.11 Handouts and stack options

- **`fewestChips(amount, values, limits)`** — exhaustive depth-first search, largest chip first, pruned by `n + ceil(rest / v) ≥ best`; returns the fewest chips that make the amount within `limits` (the bank left), preferring large chips on ties. Used for the add-on, the early bonus, a late arrival and cash top-ups. Example: 250 from {1, 5, 25, 100} → 2 × 100 + 2 × 25.
- **Rebuy = a fresh starting stack**, the same chips as the start (no chip leaves before rebuys close).
- **`stackOptions(inputs)`** returns two ways to deal the same night:
  - **A `engine`** — the engine's pick (every colour in every stack).
  - **B `smallOut`** — "small chips out once": each player gets the same small chips (as many as the case can give everyone — most chips wins), the rest in the largest chip; rebuys and add-ons paid in the largest chip only. Default stack: the round value between R/2 and 3R whose rebuy and add-on are whole largest chips, bank OK, depth in band, most small chips per player; none fits → 2R with the shortfall spelled out. R is the **reference stack**: the engine's stack S, or — when the engine's pick is short of its depth band or the case is too small — the stack the pace aims for, `D × 2 × smallest chip` (200 for a regular night with 1s). `inputs.smallOutStack` overrides.
- Picking B passes it back as `forceStack`; blinds, levels and breaks follow the new stack.

### F1.12 Editing levels — `resolveAroundPins` and the editor rules

- **Pins** are host-fixed levels `{levelNum, sb, bb, ante?, minutes?}`; they must be strictly increasing in BB.
- **Between two pins:** geometric interpolation `a.bb × gSegᵏ`, then the DP snap with both ends fixed and each level's own cmin.
- **After the last pin:** re-target `BB_end` over the remaining levels, seeded with the next nice BB above the pin.
- The small blinds inside a re-solved segment or tail are the plain BB ÷ 2 on the level's chip — the colour-up "hold" of §F1.6 applies only to a fresh solve. Keep this divergence in the port.
- The pins' own values are re-applied exactly (the host wins); if any level ends up not strictly above the previous one → `feasible: false` with "Could not fully resolve: level n …".
- **Editor rules** (the mock's `lvInsert`, `lvDelete`, `lvUnlock`; C2): insert = the nice payable blind nearest √(prev × next) (or prev × 1.4 at the end), or re-space the unpinned neighbours; "No room … unpin one first" when nothing fits. A structure keeps at least 2 levels. Deleting a break moves its colour-up to the next break (or drops it at the last). Played levels lock; "correct the record" only, never deleted. **Add a level** on the dashboard at the end of the structure uses the same insert rule (≈ ×1.4, payable), same length.

Example (demo night, §F1.15): pinning L6 at 10/20 keeps L1–L5 and re-solves the tail: 1/2 · 2/4 · 3/6 · 4/8 · 5/10 · **10/20** · 15/30 · 20/40 · 25/50 · 30/60 · 40/80 · 50/100 …

### F1.13 Legacy phased mode (no pace)

When `pace` is absent the engine uses `solvePhasedLevels`: style from T (`< 180` turbo, `≤ 240` standard, else deep), level lengths in three phases by M = S/raw BB (≥ 20 early, < 10 late), ratio 15:13:11 for standard, floored at Lmin / 8 min, and a fixed-point loop on the number of levels. **Every host-facing path in v3.1 passes a pace**, so this mode is only reached by old saved games; keep it for compatibility and verification, don't expose it.

### F1.14 No chip case — the tools

- **Quick blind** (E6): `BB = snapBB(stack / 100, cmin 1)` — the nicest payable BB near 100 BB deep; shows "SB / BB" and the reasoning.
- **Blind structure generator** (E2) with no chip case: run the engine with a synthetic 1 · 5 · 25 · 100 · 500 · 1,000 case sized so the bank never binds, or snap to the practical table:
  `5/10 · 10/20 · 20/40 · 25/50 · 50/100 · 75/150 · 100/200 · 150/300 · 200/400 · 250/500 · 300/600 · 400/800 · 500/1,000 · 600/1,200 … 1,000/2,000 · 1,200/2,400 … 2,000/4,000 · 2,200/4,400 … 3,000/6,000`.
  Either way, level length follows the chosen pace.

### F1.15 Worked example — the demo night

Inputs: White 1 × 120 · Red 5 × 150 · Green 25 × 80 · Black 100 × 40 · 10 players · rebuy · 35 % rebuy rate · add-on × 1.25 · BB ante · 20:00 → 00:30 · regular pace · early bonus 12.5 %.

| Output | Value |
|---|---|
| Starting stack | **200** = 5 × 1 · 9 × 5 · 2 × 25 · 1 × 100 (100 BB) |
| Bank check | OK — 1s 80/120 · 5s 144/150 · 25s 62/80 · 100s 36/40 |
| Handouts | rebuy = the start stack · add-on 250 = 2 × 100 + 2 × 25 · bonus 25 = 1 × 25 |
| Levels (20 min each; ante in brackets) | 1/2 · 2/4 · 3/6 · 4/8 · 5/10 (10) · 6/12 (12) · 10/20 (20) · 15/30 (30) · 25/50 (50) · 40/80 (80) · 60/120 (120) · 75/150 (150) ◄ target level 12 · 125/250 (250) · 200/400 (400) · 300/600 (600) · 400/800 (800) |
| Breaks | after L4 — add-on window · after L9 — colour up the 1s (from L10 the smallest chip is 5) |
| Rebuy close | L4 (options L3 · L4 · L5: fresh M 22.2 · 16.7 · 13.3; 22 % · 30 % · 37 % of the night) |
| End | around **00:20** (00:00–01:00) · target level 12 · T 270 · C 4,700 · K 27 · g = 1.5 · style standard · fits |

`paceOptions` for this night: **turbo** 2/4, 50 BB, 16 levels, 00:20, fits · **regular** 1/2, 100 BB, 12 levels, 00:20, fits — **recommended** · **deep** 1/2, 13 levels, 03:10, over by 160 min.

Same night with **11 players and a 00:00 finish**: no recommendation; warning "At a regular pace this field needs about 4h40; the night has 4h00." — choices **later** 00:40 · **noAddOn** 00:00 · **turbo** 23:50.

`stackOptions`: **A** engine 200 (above) · **B** small chips out 400 = 10 × 1 · 13 × 5 · 5 × 25 · 2 × 100, rebuy 4 × 100, add-on 5 × 100, bonus 2 × 25 — bank **not** OK ("needs 94 Black (100), you have 40 — short 54").

---

### F1.16 Worked trace — the demo night, step by step

Inputs (§F1.15): `chipSet` White 1×120 · Red 5×150 · Green 25×80 · Black 100×40; `players` 10; `format` rebuy; `expectedRebuyRate` 0.35; `addOn {enabled:true, multiplier:1.25}`; `anteType` 'bb'; `startTime` '20:00'; `endBy` '00:30'; `pace` 'regular'; `earlyBonusPct` 0.125.

Every number below was printed by the reference engine on these inputs (an instrumented copy logged the intermediate values). Lines starting "Trace:" are that log.

#### Step 1 — the night's clock: T and P
`T = clockDiff('20:00','00:30') = 270` minutes (crosses midnight: `00:30` is `270` min after `20:00`). `planBreaks(270, 'rebuy')`: `breakLen=10`, `nBreaks = floor((270-30)/90) = floor(2.67) = 2`, `rebuyPause = 10` (rebuy format). `P = max(30, 270 - 2×10 - 10) = max(30, 240) = 240` minutes of actual play.
Trace: `breaksInfo(pre)={"breakLen":10,"nBreaks":2,"totalMinutes":20,"rebuyPause":10} P=240`.

#### Step 2 — bank sizing: Rforecast, Rbank, draws, S_max
`Rforecast = expectedRebuyRate × N = 0.35 × 10 = 3.5`. Bank sizing is conservative: `Rbank = PoissonQuantile(mean=3.5, q=0.90)`. Hand-checked against the Poisson(3.5) CDF: cumulative probability crosses 0.9 between k=5 (0.8576) and k=6 (0.9347), so `Rbank = 6`. `draws = N + Rbank = 10 + 6 = 16`. Every player is assumed (for bank-sizing only) to take the add-on and the early bonus: `addonDraws = bonusDraws = N = 10`. `totalBankValue = 1×120 + 5×150 + 25×80 + 100×40 = 120+750+2000+4000 = 6,870`. `denom = draws + addonMult×addonDraws + bonusPct×bonusDraws = 16 + 1.25×10 + 0.125×10 = 16+12.5+1.25 = 29.75`. `S_max = 6870/29.75 = 230.92`.
Trace: `N=10 Rforecast=3.5 Rbank=6 addonDraws=10 bonusDraws=10 draws=16 totalBankValue=6870 denom=29.75 sMax=230.92436974789916`.

#### Step 3 — candidate stacks evaluated
`candidateStacks(230.92)` returns 21 "nice" values descending from 200 (the largest `m×10^k` ≤ 230.92): `200,150,120,100,80,60,50,40,30,25,20,15,12,10,8,6,5,4,3,2,1`. `solveChipPlanBounded` is run against each in that order until 20 **feasible** plans are found or the list runs out (here it runs out first — only 7 of the 21 candidates produce any feasible composition at all; the rest are silently infeasible under the bank/eligibility constraints and never reach `evaluated[]`):

| S | used | score | bb1 | depth (BB) | in standard band [85,130]? |
|---|---|---|---|---|---|
| **200** | 5×1, 9×5, 2×25, 1×100 | **83.250** | 2 | **100.00** | **yes** |
| 80 | 5×1, 5×5, 2×25 | 109.750 | 2 | 40.00 | no |
| 60 | 5×1, 6×5, 1×25 | 98.250 | 2 | 30.00 | no |
| 50 | 5×1, 4×5, 1×25 | 104.250 | 2 | 25.00 | no |
| 3 | 3×1 | 153.000 | 2 | 1.50 | no |
| 2 | 2×1 | 155.500 | 2 | 1.00 | no |
| 1 | 1×1 | 159.000 | 2 | 0.50 | no |

Only S=200 lands inside `DEPTH_BAND.standard = [85,130]`. Since depth is a **hard** filter (§F1.5 point 5), the pool of competing stacks is just `{200}` — no score tie-break against other candidates is needed here (S=200 wins by being the only depth-qualified stack, not by score). Hand-checked the winning score: `scoreComposition([1×5,5×9,25×2,100×1], 17)` = 71.25 (smallest-pair penalty `((5-10)/2)²+25=31.25`, change-coverage penalty `15+0+15=30`, chip-count penalty `3×(20-17)+2=11`, parity bonus `-1.0`) **+** the soft-25%-rule penalty applied by the caller for the one chip over S/4=50 (`100 > 50` → `+12×1`) = `71.25+12 = 83.25` — matches the traced score exactly.
Trace: `TRACE candidate S=200 ... score=83.250 bb1=2 depth=100.00 inBand=true` … `TRACE pool(inBand?true, n=1) chosen S=200 score=83.250 depth=100.00`.

#### Step 4 — C, K, BB1
`S=200`, `cminStart=1` (the smallest chip in the winning composition). `C = S×(N+Rforecast) + addonMult×S×addonDraws + bonusPct×S×N`. Here `addonDraws` inside `generateStructure` (not the bank-sizing override) is `N × takeUpRate = 10 × 0.7 = 7` (default take-up when the input doesn't set one, or the group's learned rate, §E14), and every on-time player takes the early bonus: `C = 200×13.5 + 1.25×200×7 + 0.125×200×10 = 2700 + 1750 + 250 = 4,700`. Any ante active → `K = K_ANTE = 27`. `BB1 = niceBB(S/STYLE.standard.D, cminStart) = niceBB(200/100, 1) = niceBB(2, 1) = 2`.
Trace: `style=standard T=270 N=10 Rforecast=3.5 addonDraws(raw takeUp)=7 addonMult=1.25 bonusPct=0.125 S=200 cminStart=1 C=4700 K=27 BB1=2`.

#### Step 5 — BB_end, eFit, gFit, g, e (pace = regular)
`BBend = C/K = 4700/27 = 174.074` (≈174, "about 5% of chips in play" in the explanation; exactly 3.7 %). Pace `regular`: `L=20`, `gMax=1.5`. `levelsNeeded = 1 + ln(174.074/2)/ln(1.5) = 12.015`. `eFit = max(2, floor(240/20)) = 12`. `gFit = (174.074/2)^(1/(12-1)) = 1.50085`. `gFit ≤ gMax` is false by 0.06 %, but `levelsNeeded × L = 240.3 ≤ P + 5 = 245` → **fits = true** (a fraction of a level is not reported as a whole level late). `g = min(max(gFit, PACE_G_MIN=1.2), gMax) = 1.5`. `e = max(2, min(eFit=12, ceil(1+ln(BBend/BB1)/ln(g)))) = min(12, 13) = 12` (target level; the ladder reaches 173 by level 12, 0.6 % short of 174).
Trace: `pace=regular L=20 BBend=174.074 levelsNeeded=12.015 eFit=12 gFit=1.50085 fits=true g=1.5 e=12` — matches `meta.g=1.5`, `meta.C=4700` and `meta.targetLevel=12` in the plain JSON output exactly.

#### Step 6 — the raw (pre-snap) ladder
`n = e + SPARE_LEVELS = 12+4 = 16`. `raw[i] = BB1 × g^i`:
```
2.00, 3.00, 4.50, 6.75, 10.13, 15.19, 22.78, 34.17, 51.26, 76.89, 115.33, 173.00, 259.49, 389.24, 583.86, 875.79
```

#### Step 7 — breaks (before the add-on move), colour-up trigger and event
`breakLevels()` places a break after ~90 min of play and again after ~180 min, at 20 min/level: after L5 (100 min ≥ 90) and after L9 (180 min ≥ 180) → initial `breaksAfter = [5, 9]`.
`colourUpPlan` walks chips ascending, stopping before the largest (Black/100): pair (White 1 → Red 5): `next=5`, trigger = first `raw[i] ≥ 4×5=20` → `raw[6]=22.78` (0-indexed position 6, i.e. **1-indexed level 7**). First break with `afterLevel ≥ 6` (§F1.7 explains why the comparison uses `trig` directly, not `trig + 1`) is **9** (afterLevel=5 fails, 5<6). So the White/1s retire **after level 9**, and `cmin` becomes 5 from level 10 on. Pair (Red 5 → Green 25): trigger needs `raw[i]≥100`, first reached at `raw[10]=115.33` (level 11) — but by then `lastBreak=9` and no further break exists in `[5,9]` at or after level 10, so this pair never fires (the 5s stay in play to the end). Black is the largest chip and is never a colour-up candidate.
Trace: `colourUpPlan: d=1 next=5 trig(0-idx into raw)=6 => raw[trig]=22.78 (4*next=20) => trigger is really at 1-indexed level 7 | chosen brk(afterLevel, 1-indexed)=9`.

#### Step 8 — ante bootstrap, rebuy-close candidates, then the real ante
First pass uses the **placeholder** `anteFromLevel = floor(12×0.5) = 6` (the bootstrap in §F1.10) purely to run `suggestRebuyClose`. `suggestRebuyClose` scans every level for `freshM = S/(SB+BB+anteTotal) ≥ Mmin(standard)=15` **and** cumulative elapsed ≤ 40%×270=108 min:

| Level | SB/BB | fresh stack (BB) | freshM | % of night |
|---|---|---|---|---|
| 3 | 3/6 | 33.3 | 22.2 | 22.2% |
| **4** | 4/8 | 25.0 | **16.7** | 29.6% |
| 5 | 5/10 | 20.0 | 13.3 | 37.0% |

Level 5's freshM (13.3) already drops below Mmin(15), so the **last** qualifying level is **4** → `rebuyClose.suggested = 4`, options menu = levels 3/4/5 as above (all with placeholder-ante freshM, since ante is still 0 at levels 3-5 either way — the placeholder only affects level 6+, so it doesn't actually change this particular answer). The real ante is then recomputed with `anteFromLevel = 4` (the level *after* the close, per F1.8): `ante = [0,0,0,0,10,12,20,30,50,80,120,150,250,400,600,800]` for levels 1-16.
Trace: `suggestRebuyClose (pass1, placeholder ante): suggested=4 options=[L3 freshM22.2/22.2%, L4 freshM16.7/29.6%, L5 freshM13.3/37%]` then `re-ran computeAntes with real anteFromLevel=4`.

#### Step 9 — cmin per level, DP-snapped ladder, SB ladder
`cu.cmin = [1,1,1,1,1,1,1,1,1,5,5,5,5,5,5,5]` (jumps to 5 from level 10, per Step 7). `dpSnapLadder(raw, cmin, fixedFirst=BB1=2)` produces:
```
bbLadder = [2,4,6,8,10,12,20,30,50,80,120,150,250,400,600,800]
```
`chooseSB(bbLadder, cmin, g=1.5)` produces:
```
sbLadder = [1,2,3,4,5,6,10,15,25,40,60,75,125,200,300,400]
```
At level 10 (the colour-up boundary, cmin goes 1→5), the "hold" exception was evaluated and **lost**: natural SB = round(80/2/5)×5 = 40; holding the previous SB (25) would give a level-to-level ratio of 1 (ln=0) vs. the ladder's own growth `g=1.5` (ln≈0.405) — distance 0.405. Natural's ratio is 40/25=1.6 (ln≈0.470) — distance from `ln(g)` is |0.470-0.405|=0.065. Since 0.065 < 0.405, **natural wins** — this demo night never actually exercises the "held SB" branch even though it passes through a colour-up.
Trace: `cu.cmin=[1,1,1,1,1,1,1,1,1,5,5,5,5,5,5,5] bbLadder=[2,4,6,8,10,12,20,30,50,80,120,150,250,400,600,800] sbLadder=[1,2,3,4,5,6,10,15,25,40,60,75,125,200,300,400]`.

#### Step 10 — the add-on-break move
Owner flow: rebuys close → add-on → break. `closeAt = 4`; since `breaksAfter=[5,9]` doesn't already contain 4, the first break moves: `moved=[4,9]`. The whole ladder is re-solved once against `[4,9]` instead of `[5,9]` (**re-solved**, not just relabelled — a different break position feeds a different `colourUpPlan` call). The re-solve's `rebuyClose.suggested` is checked again: still **4** → the move is **kept**. (Re-running the colour-up trigger against `[4,9]` gives the identical event — `afterLevel=9` — because the only available break ≥ the trigger position is still 9 either way.)
Trace: `breaksAfter (before add-on move)=[5,9]` → `add-on break move: closeAt=4 moved breaksAfter=[4,9]` → `move KEPT (re-solve still closes at 4)` → `breaksAfter (final)=[4,9]`.
Final breaks: **after L4** = "Add-on window"; **after L9** = "Colour up 1".

#### Step 11 — projected end
Minutes to the end of the target level (12): 12 levels × 20 min = 240, plus the two breaks before it (after L4 and after L9), 2 × 10 = 20 → **260** minutes. `low = 260 - max(20,15) = 240`; `high = 260 + 2×max(20,15) = 300`. Converted from `startTime=20:00`: **00:20** (band **00:00–01:00**).
Trace / JSON: `projectedEnd={"minutes":260,"low":240,"high":300,"clockTime":"00:20","clockLow":"00:00","clockHigh":"01:00"}`. `meta.fits = phased.fits(true) && 260 ≤ 270+5` → **true**.

Every number above matches §F1.15.

### F1.17 How each function works, in plain words

#### `scoreComposition` — what it's actually optimising for

`scoreComposition(usedList, totalChips)` scores one candidate chip breakdown for a single player's stack — **lower is better**, and it never sees money, only chip counts. It encodes five practitioner rules of thumb as penalties, ported from a hand-validated prototype (`proto/chips.py`) that reproduced a known-good canonical stack exactly:

1. **The two smallest denominations should be the "working" chips.** If the second-smallest chip is exactly 4× the smallest (a ×4 ladder, e.g. 1→5 isn't ×4, but 25→100 is — check the actual ratio), the target count for the smallest chip is 12; otherwise 10. Penalise the squared distance from that target, halved (`((count−target)/2)²`), plus a flat +25 if the smallest chip's count falls outside 8-16 — this is the "don't hand out 2 chips or 40 chips of your smallest denomination" rule.
2. **Change should be coverable.** Walking the denominations low to high, if everything below the current one doesn't add up to at least 2× the current chip's value, add +15 — you want a player to be able to make change for their bigger chips out of their smaller ones.
3. **Total chip count sanity.** Penalise 3 points per chip under 20 and 3 points per chip over 40 (too few chips feels bare, too many is a fumbling hazard), plus a flat +2 if the total isn't in the 25-35 sweet spot.
4. **Round counts are slightly preferred.** Any denomination whose count is divisible by 5 or by 2 gets a small −0.5 discount — a tie-breaker, not a strong force.
5. **(Not inside this function.)** The caller adds +12 per chip for every denomination worth more than S/4 of the stack, on top of whatever `scoreComposition` returns. This is the "soft" half of the 25%-single-chip rule; the "hard" half (nothing over S/2 is even considered) is a separate eligibility filter before scoring ever runs.

The function is deliberately blind to *which* stack size S it's scoring — that's why the S/4 rule has to live in the caller, which is the one place that still has S in scope.

## The DP snap (`dpSnapLadder`) — turning a smooth curve into real, payable chip values

The raw ladder (`BB1 × g^i`) is a smooth exponential curve with no regard for what chips exist. `dpSnapLadder` replaces it with a strictly increasing sequence of real, payable big blinds that tracks that curve as closely as possible, level by level:

1. **Per level, build a candidate list.** For level `i`, the legal candidates are "nice" values (`m×10^k`, `m` from the fixed `NICE_M` family) that are also a multiple of `2×cmin(i)` (so half of it — the small blind — is payable with the smallest chip in play at that level), restricted to the window `[raw[i]/1.6, raw[i]×1.6]`. If that window is empty, fall back to the single value `2×cmin(i)`.
2. **Pin the ends.** Level 1's candidate list is forced down to a single value — `BB1`, already decided by the depth target (this isn't up for renegotiation by the curve-fit) — and, when resolving around host pins (§F1.12), the segment's last level is pinned too. This guarantees the strictly-increasing chain has a well-defined, correct anchor at both ends instead of letting the optimiser "discover" a different level-1 value that's cheaper overall but doesn't match the depth the host was told.
3. **Score every legal transition, level by level (this is the DP).** For level `i`'s candidate `v`, and each candidate `u` at level `i−1`: reject outright if `v ≤ u` (strictly increasing is not negotiable). Otherwise, cost = (how far `v` is from the raw curve, in log space, squared) + (a transition penalty on the ratio `v/u`: +5 if it more than doubles, a small sliding penalty above ×1.67, and +0.5 if it's a barely-there step under ×1.15) + (the cheapest way to have reached `u` at all). Keep only the cheapest way to reach each `v`, and remember which `u` it came from.
4. **Walk backwards from the cheapest ending.** Once every level has been scored, pick the candidate at the last level with the lowest total cost, then follow the "came from" pointers back to level 1 to read off the whole chain.
5. **If nothing connects end to end** (can happen right after a colour-up sharply shrinks the candidate pool), fall back to `fallbackChain`: just walk forward taking the nearest payable "nice" value strictly above the previous level's chosen value. It's always correct — always increasing, always payable — just not curve-optimal.

#### `chooseSB`'s hold rule — why the small blind sometimes doesn't move

The default is simple: SB = BB/2, rounded to the nearest multiple of the smallest chip in play, never less than that chip, never equal to or above the BB. Because the DP snap (above) already guarantees every BB is a multiple of `2×cmin`, this "natural" SB is *always* payable — no exception needed for feasibility.

The one refinement is about *feel*, not payability: right at a level where the smallest chip in play just got coarser (a colour-up happened), jumping SB straight to the new BB/2 can be a much bigger percentage jump than the rest of the ladder is taking, because the coarser chip forces a coarser rounding. So at exactly those boundary levels, the engine also considers **holding** the previous level's SB unchanged — but only if that held value is *still* a legal multiple of the new, larger minimum chip (otherwise it's not payable any more and holding isn't an option at all). Between "hold" (a ratio of exactly 1 from the previous level) and "natural" (whatever BB/2 rounds to), it picks whichever one's level-to-level growth ratio is closer to the ladder's own overall growth rate `g`. In practice this means: a small, in-family jump usually wins on "natural"; a large, rounding-driven jump is where "hold" tends to win instead, smoothing the ladder for one level before it resumes tracking `g` normally next level.

#### `colourUpPlan` — retiring chips without ever leaving a level unpayable

Walk the dealt denominations from smallest to largest, **stopping before the largest one** (it's never a candidate for retirement — a hard rule, not a preference). For each denomination `d` (with `next` being the denomination directly above it):

1. **Find the trigger.** Scan the raw (pre-snap) ladder for the first level whose raw big blind reaches 4× `next`'s value — the point past which `d` is genuinely too small to matter for making change on the blinds any more.
2. **Find where to actually retire it.** Colour-ups only ever happen at a break, never mid-level, and never before some earlier colour-up's break. So look for the first break position that is at or immediately before the trigger level (§F1.7 has the exact indexing — the engine deliberately retires the chip at the break *right before* the trigger level, so the trigger level itself opens already using the coarser chip, not one level late). The engine passes this function only the colours actually dealt (start, rebuy, add-on and bonus handouts — fixed in v3.1), so a colour left in the case can never drive a retirement or a blind.
3. **No qualifying break exists?** Then `d`, and every denomination above it, simply stays in play for the rest of the night — there's nothing wrong with that, it just means the case never got a chance to shed that chip.
4. **Apply forward.** From that break onward, every level's `cmin` becomes at least `next`'s value — this happens *before* the blind ladder is snapped (§ the DP), not after, which is what guarantees every post-colour-up blind is payable by construction rather than by a later patch-up check.

#### `suggestRebuyClose` — picking the last sensible moment to close rebuys

For every level in the ladder, compute a **fresh** (just-rebought) stack's Harrington M: how many "orbits" (one SB + one BB + a fixed 8-handed ante total, if any) a brand-new full stack would last at that level's blinds. A level qualifies as a candidate close point if that fresh M is still at or above the style's floor (turbo 10 / standard 15 / deep 20 — "still meaningfully deep if someone rebuys right now") **and** the level starts within the first 40% of the planned night (rebuys shouldn't still be open two-thirds of the way through). Among every qualifying level, the suggestion is the **last** one — the latest point that still satisfies both conditions, i.e. rebuys stay open as long as they can while still meaning something. The host is shown that level plus its immediate neighbours (one level earlier, one later) as a same menu, each annotated with its fresh stack depth in BB, fresh M, and what percentage of the night has elapsed by then — so the host can see exactly what trade-off they're making by picking a different level than the suggestion.

#### `stackOptions`' "small chips out" (option B) — finding its own default stack size

Option A is simply what `generateStructure` already picked. Option B answers a different question: "what if every player got the same handful of small chips up front, with everything else — and every rebuy, every add-on — paid in the single largest denomination, so the small chips never have to be replenished mid-game?" When the host doesn't pin a specific stack value for this option, the engine searches for the best one itself:

1. **Search window.** Only "nice" stack values between half of the reference stack R and 3× it are considered (R = option A's stack, or the stack the pace aims for when option A is short of its band or too small — §F1.11) — this keeps option B recognisably "the same night," not an unrelated stack size.
2. **The method constrains the candidates first.** A value only qualifies if it's an exact whole number of the largest chip, **and** (when an add-on is on) the add-on amount is also an exact whole number of the largest chip — because both rebuys and add-ons are paid in that single largest denomination only, by design, so there's no room for a fractional-chip remainder.
3. **Build the actual small-chip handout for each surviving candidate.** Work out, per small denomination, the most of it the case can give to *every* player identically (owned count ÷ player count, rounded down — so nobody runs the case dry). Carve the early bonus out of that allowance first, then fill as much of the stack as possible using the small chips within what's left (preferring to use *more* small chips, not fewer — the opposite goal from a normal "fewest chips" handout, because the whole point of this option is chips in hand), with the remainder made up in the largest chip.
4. **Filter by feasibility and depth.** Reject any candidate whose resulting bank check fails, or whose resulting depth falls outside the style's hard depth band.
5. **Pick the winner.** Among everything left, keep the one that hands out the most small chips per player; ties go to the smaller stack value.
6. **Nothing survives at all?** Fall back to exactly double R, and report the shortfall honestly (which denomination is short, and by how much) rather than silently picking something that doesn't fit.

#### `resolveAroundPins` — recalculating around a host's manual edits

Pins are host-fixed levels the recalculation must hit exactly. First, validate: every pin must land inside the actual level range and pins must be strictly increasing in big blind value as you move down the ladder — if not, the whole operation is refused up front with a plain error, not a best-effort guess.

Then, for every pair of *consecutive* pins, treat the levels strictly between them as one segment to re-fill: interpolate geometrically from one pinned BB to the next (an even percentage step per level between the two fixed endpoints), then run the same DP snap used everywhere else in the engine over just that segment, with **both ends pinned inside the DP** — so the same strictly-increasing, always-payable guarantees that apply to a fresh solve apply to this segment too, not just to its unpinned middle.

After the *last* pin, the remaining levels to the end of the structure are re-targeted at the same `BBend` the original solve was aiming for, spread geometrically over whatever levels are left — seeded so the very first level of this tail is already guaranteed to land above the pin before the DP even runs, rather than needing a retroactive fix-up afterward.

Finally, the pins' own exact values are written back over whatever the segment fits produced (the host's number always wins over the algorithm's), and the whole ladder is re-checked end to end for strict monotonicity; if the pins force a level to be no higher than the one before it, the result comes back `feasible: false` naming the first level that broke, rather than quietly producing an invalid ladder.

**Known divergence — keep it in the port:** this recalculation never calls the small-blind "hold at a colour-up" smoothing exception** — every SB inside a re-solved segment or tail is the plain BB/2-rounded value, even where a fresh, non-edited solve of the same final ladder would have held the previous level's SB for smoothness. If a pin's segment happens to span a colour-up boundary, expect the small blind there to differ slightly from what a from-scratch generation of the same numbers would have produced.

---

### F1.18 Why these numbers — the evidence

Every constant was checked on 27 September 2026 against the owner's poker library and published home-game guidance (research notes: `research/structure-research-2026-09-27/`). What the sources say, and what we do:

| Rule | Ours | Evidence | Verdict |
|---|---|---|---|
| Starting depth | turbo 50–70 · standard 85–130 (aim 100) · deep ≥ 150 (aim 160) BB | ChipLab calculator: "Fifty is fast, 75 to 100 is the sensible default, 150 to 200 is deep". homepokertourney.org: first big blind = stack ÷ 50 to 100. Ciaffone (*Card Player*, 2006, quoted in the owner's framework): 100 BB starting stacks. | Supported [Sure] |
| Growth cap `gMax` | 1.45–1.6 a level | Blinds Are Up: about ×1.5. ChipLab presets: ×1.45 / ×1.65 / ×1.90. homepokertourney.org: never more than doubling. Two real WSOP ladders (Rounder, *Tournament Tactics*, p. 18–22): steps between ×1.2 and ×2.0. | Supported, on the slow side [Sure] |
| First steps above `gMax` | 1/2 → 2/4 is ×2 | Both WSOP ladders open with a ×2 step: at the bottom the smallest chip forces whole values. | Expected, not a bug |
| Finish target `K` | 20 (big blind = 5 % of all chips) · 27 with an ante (3.7 %) | homepokertourney.org and ChipLab: a home tournament wraps up when the big blind reaches 5–10 % of the chips in play. Neither models antes; a big-blind ante makes an orbit about 1.7× dearer (2.5 BB instead of 1.5 at nine-handed), so the same pressure arrives at a lower blind. | K 20 sits at the published floor; K 27 is an argued extrapolation — retune from real nights (D8) [Hypothesis] |
| Ante | one big-blind ante from the rebuy close; the Auto rule (§F1.8) | TDA 2024, RP-11 (pokertda.com): the big-blind ante is the single-payer standard, and antes are never reduced as play goes on. ChipLab: "Around level four or five, once rebuys have closed. One big-blind ante." | Supported [Sure]; our ante only ever rises with the big blind |
| Rebuy close | last level with a fresh stack ≥ Mmin (10 / 15 / 20) and ≤ 40 % of the night | Harrington's M zones (*Harrington on Hold'em* vol. 2, p. 128–131). homepokertourney.org's rules close rebuys at 25–33 % of the night. | Supported; the M rule binds first (the demo closes at 30 %), 40 % is only a ceiling |
| Colour-up | at breaks, once the big blind is ≥ 4 × the next chip and every later blind stays payable; rounded up, no chip race | Robert's Rules of Poker and the owner's framework: retire a chip when no blind needs it; TDA Rules 24–25: chip race, never race a player out. Both WSOP ladders colour up at the first level where BB ≥ 4 × the next chip. | Same points as the textbook rule; rounding up is a deliberate home simplification — nobody loses chips |
| Level length | 15 / 20 / 30 min, one length all night | ChipLab: 6–10 / 12–18 / 18–25 min. | Ours is slower on purpose: the owner's decision after a real night felt "very turbo" (2026-09-26) |
| Breaks | 10 min about every 90 min of play | TDA leaves breaks to the house; no source either way. | House choice |
| Late compression | none: constant growth, a deal offer at the target time, an optional hard finish (§F4) | The owner's framework suggests faster blinds late; the Ciaffone article it cites recommends slower increases near the money. | Not adopted: the hard finish gives time control without changing the levels |
| Playable floor | 20 BB (§F1.5 point 7) | Harrington: M under 10 is push-or-fold; 20 BB is M ≈ 13 at level 1. | A stack below it is not a tournament; the case is reported too small |

## F2. The payouts engine

Money is in integer cents inside the engine; results return in whole currency units (decimals only when the amount has cents). "EUR" in the code comments means "the currency unit" — the app has no currency by default (§E16).

### F2.1 Paid places and the split — `payoutPlan(entries, pool, opts)`

`pool` = the sum of the game's ledger entries of kind `buyIn`, `rebuy`, `reEntry` and `addOn` (owed or paid). `bounty` entries never enter it (§F2.4). The bounty pot and the organiser fee are the only amounts outside the split.

```
E = entries + (countRebuys ? rebuys : 0)          // entries = players + re-entries
fee, net = organiserFee(pool, cfg)                // F2.3 — the split is on the NET pool
places  = curvePlaces(E, 'ps15')                  // PokerStars Home Games curve, ≈ top 15 %
places  = min(places, maxPlaces 6, shape length)
places  = min(places, max(1, floor(players/2) − 1))   // never pay half the field
while places > 1:
    last = net × shape[places][last] / 100
    if last < 1.5 × buyIn → places −= 1            // min-cash rule
    elif last < one cash unit → places −= 1
    else break
amounts = roundShares(net, shape[places], cashUnit)
```

**Curves** (entries → places): `ps15` (default) 2–5 → 1 · 6–7 → 2 · 8–21 → 3 · 22–28 → 4 · 29–35 → 5 · 36–42 → 6, then +1 per 7 entries (capped by maxPlaces). `ps10` and `ps20` exist for a host override.

**Shapes** (% by place):

| Places | owner (default) | standard |
|---|---|---|
| 1 | 100 | 100 |
| 2 | 65 / 35 | 65 / 35 |
| 3 | **52.5 / 32.5 / 15** | 50 / 30 / 20 |
| 4 | **42.5 / 30 / 17.5 / 10** | 45 / 27 / 18 / 10 |
| 5 | 38 / 24 / 17 / 12 / 9 | same |
| 6 | 35 / 22 / 16 / 12 / 9 / 6 | same |

Host overrides: `places` (the shape still applies), or explicit `shares` (must sum to 100, each > 0, non-increasing — the engine supports it, but no v1 screen exposes custom shares). The **Configure "paid positions" suggestion must come from this function**, not from the mock's legacy 1-in-4 `suggestPaid` (§G5).

### F2.2 Cash unit and rounding

- `cashUnit(buyIn)`: < 5 → 1 · < 100 → 5 · < 500 → 10 · else 50.
- `roundShares(net, shares, unit)`: places 2…p are rounded to the nearest unit (**exact halves round down**, integer-exact via basis points); **1st takes the remainder** (so the split always adds up to the net pool, odd cents included); then an order repair moves a unit to 1st whenever a place would exceed the one above it.

### F2.3 Organiser contribution — `organiserFee(pool, cfg)`

```
mode: none (default) | percent | fixed | perEntry     // v1 UI offers percent and fixed only (C-cfg §10); perEntry stays in the engine
fee = percent  → pool × value / 100        (value < 100)
      fixed    → value
      perEntry → value × entries
fee = floor(fee / roundTo) × roundTo        // roundTo 1 — rounds DOWN, never above the setting
require fee < pool
warnings: POOL_DEDUCTION (any fee) · HIDDEN_FROM_PLAYERS (visibility 'host', the default)
```

Both warnings must be shown by the H4 gate before the fee can be enabled. **When it can change:** freely before any payout amount has been shown; after that, only with a confirm that states the consequence; **locked when rebuys close**, and a deal never recalculates it. **Never call it with a fee that reaches the pool** (it throws): if a fixed or per-entry fee would reach the real pool at the close, the app lowers it to the pool minus one cash unit first and tells the host (C-cfg §10).

### F2.4 Bounty pot

With KO bounty on, each entry and rebuy pays `buyIn + bounty`; the bounty part goes to a **separate pot** (never in `pool`), paid to the eliminator at the bust. Fixed bounty is free; Progressive and Mystery are Premium and their mechanics are open (O8).

### F2.5 ICM — `icm(stacks, prizes, opts)`

Malmuth–Harville: P(i finishes 1st) = stackᵢ / total; then recursively for the lower places among the rest.

- **Exact DP**, depth-limited to the number of paid places P: states = Σ_{k<P} C(n, k) (10 players, 3 paid → 56 states). Frontier keyed by the bitmask of players already placed, carrying probability and remaining chips.
- **Monte-Carlo** above `maxStates` 2,000,000: 200,000 stack-weighted finishing orders with the Park–Miller generator (`s = s × 16807 mod (2³¹ − 1)`), seeded — the same seed gives the same answer on every device.
- Zero stacks (busted this hand) take the bottom places, split equally.
- `prizes` = **the prizes still to pay**, 1st first (extra prizes ignored; missing places pay 0). `result.method` = `exact` | `montecarlo`.

### F2.6 The other deals

- **`chipChop(stacks, prizes)`** — everyone first gets the lowest remaining prize; the rest splits by chip share; nobody gets more than 1st (excess re-split among the uncapped until stable).
- **`equalChop(n, prizes)`** — the top-n prizes split evenly.
- **`leaveForWinner(stacks, prizes, x, method)`** — take x off 1st (0 ≤ x ≤ 1st − 2nd), chop the rest by `icm` · `chip` · `equal`, and play on winner-take-all for x; `ev_i = locked_i + x × chipShare_i`. With `icm`, ev equals plain ICM exactly.
- **`compareDeals`** — ICM, chip and equal side by side with the differences (the deal screen's data).

### F2.7 Rounding a deal and the bubble save

- **`roundDeal(amounts, unit, total, cap)`** — floor each to the unit, hand the remaining units out by largest remainder (ties to the lower index), any sub-unit residue to the largest amount that stays at or under `cap`. It refuses (throws) when `total > cap × n`. The rounded amounts always add up to `total`. (Fixed in v3.1: the residue could push the largest amount above the cap; regression test added.)
- **`bubbleSave(prizes, amount, fundFrom, unit)`** — adds one paid place worth `amount` (≤ the lowest prize). `first`: 1st pays it all. `proRata` (**D10, the app's choice**): each paid place below 1st pays `amount × its prize / total`, rounded to `unit` (whole units), 1st pays the remainder; if rounding would overdraw, shares round down instead. Fails if the new ladder would be out of order.

### F2.8 When the app suggests a deal — `dealTrigger(state)`

Types, highest priority first, each fires **once per game**, never auto-applies:

1. `targetTime` — the planned end reached with ≥ 2 players left.
2. `bubble` — remaining = paid places + 1 → offer the bubble save.
3. `inTheMoney` — first time remaining ≤ paid places.
4. `headsUp` — 2 players left (ICM and chip chop give the same numbers heads-up).

The host's setting **Suggest an ICM deal from** (2–5 players, default 5) limits when the deal card appears at all.

### F2.9 Season points — `seasonPoints`, `seasonTable`

- **Field-size (default, D14):** `10 × √(players / finish)`, one decimal. 12 players: winner 34.6, last 10 · 6 players: winner 24.5, last 10. `players` = people who played (rebuys don't count).
- **Ladder** (10 · 7 · 5 · 3 · 1) and **custom**: `points[finish − 1]`, 0 beyond the table.
- **Table:** points summed across the season's nights (one decimal), ranked by points, then wins, then name.

### F2.10 Cash settle-up — `settleUp(balances)`

The **fewest** transfers that bring every balance to zero (2026-09-25). Balances must sum to zero; up to 16 people with a non-zero balance.

**Why it's exact.** Each transfer is an edge; every connected group of people must sum to zero, and a group of k needs ≥ k − 1 edges. So minimum transfers = (people with a balance) − (the most disjoint zero-sum groups). A bitmask DP finds that maximum: `best[mask] = max_i best[mask − i] + (sum(mask) = 0 ? 1 : 0)`. Backtrack one optimal order, cut it into groups where the running sum hits zero, and inside each group let the biggest debtor pay the biggest creditor (ties by name) — exactly k − 1 transfers.

Greedy on the whole table is not optimal: **+4 +3 +3 −6 −4** takes 4 greedy transfers; the engine finds **3** (D → B 3 · D → C 3 · E → A 4).

### F2.11 Worked examples

| Case | Result |
|---|---|
| 10 entries × 15 = 150 | 3 places **80 / 50 / 20** |
| 11 entries × 15 = 165, 10 % fee | fee 16, net 149; 3rd would be 22.35 < 1.5 × 15 = 22.5 → **2 places 99 / 50** |
| 10 players × 20 + 15 rebuys = 500 | E = 25 → 4 places **215 / 150 / 85 / 50** |
| 25 × 20 = 500, 10 % fee | fee 50, net 450 → **190 / 135 / 80 / 45** |
| ICM 8,000 / 5,000 / 2,000 for 250 / 150 / 100 | **197.44 / 171.61 / 130.95** (exact); rounded to 5 → 200 / 170 / 130 |
| Chip chop, same | 206.67 / 166.67 / 126.67 |
| Leave 50 for the winner (chip) | locked 180 / 150 / 120; ev = chip chop |
| Bubble save 15 on 99 / 60 / 30, pro rata, whole units | **91 / 55 / 28 / 15** (1st-funded: 84 / 60 / 30 / 15) |
| Deal trigger, 4 left, 3 paid | `bubble` |
| Season points | 12 players 1st 34.6 · 6 players 1st 24.5 · last place 10 |
| Settle-up +4 +3 +3 −6 −4 | 3 transfers, 2 groups |

### F2.12 Worked traces, by hand

#### (a) `payoutPlan(11, 165, { buyIn: 15, organiser: { mode: 'percent', value: 10 } })` — every step

This is the exact scenario quoted in §F2.11 ("11 entries × 15 = 165, 10 % fee") and in the C-payouts host view. Verified by running the real engine.

```
Inputs: entries = 11, pool (gross) = 165, buyIn = 15, organiser = {mode:'percent', value:10}

Step 1 — organiser fee (organiserFee, §F2.3)
  poolC = 16500 cents
  feeC  = poolC * 10 / 100 = 1650 cents (= 16.50)
  stepC = toCents(1) = 100 cents (roundTo default 1)
  feeC  = floor(1650 / 100) * 100 = 1600 cents      <- rounds DOWN, never up
  fee = 16.00, net = 165.00 - 16.00 = 149.00
  netC = 14900 cents
  warnings: ['POOL_DEDUCTION', 'HIDDEN_FROM_PLAYERS']   (visibility defaults to 'host')

Step 2 — effective entries
  rebuys = 0 (none passed), countRebuys defaults true
  E = entries + 0 = 11
  unit = cashUnit(buyIn=15) = 5   (15 is in the 5..99 band -> 5 cash unit)
  unitC = 500 cents

Step 3 — curve places (placesFor, using curvePlaces + caps + min-cash loop)
  curvePlaces(11, 'ps15'): 11 falls in tier [8,21] -> 3 places
  maxPlaces cap: min(3, 6, SHAPES.owner.length-1=6) = 3
  never-half-the-field cap: floor(players=11 / 2) - 1 = 4  -> 3 stays under it
  shape 'owner', 3 places = [52.5, 32.5, 15] (%)

  min-cash loop, p = 3:
    last share = shape[3][2] = 15%
    lastC = netC * 15 / 100 = 14900 * 15 / 100 = 2235 cents (= 22.35)
    floorC = 1.5 * buyIn(15) = 22.5 -> 2250 cents
    2235 + 1e-6 < 2250  -> TRUE -> drop a place (p = 2)
    trace: "3 places: last share 15% = 22.35 < 1.5 x buy-in = 22.5 -> drop"

  p = 2, shape[2] = [65, 35]
    last share = 35%
    lastC = 14900 * 35 / 100 = 5215 cents (= 52.15)
    floorC unchanged = 2250 cents -> 5215 is NOT < 2250 -> no further drop
    lastC (5215) is not < unitC (500) either -> stop. Final places = 2.

Step 4 — roundShares(netC=14900, shares=[65,35], unitC=500)
  loop i = 1 (only non-1st place, since p=2):
    bp = round(35 * 100) = 3500 basis points
    numerator = netC * bp = 14900 * 3500 = 52,150,000
    d = den(10000) * unitC(500) = 5,000,000
    k = floor(52,150,000 / 5,000,000) = 10   (5,000,000*10 = 50,000,000)
    rem = 52,150,000 - 50,000,000 = 2,150,000
    2*rem = 4,300,000  vs d = 5,000,000  -> 2*rem < d -> no round-up, k stays 10
    a[1] = 10 * 500 = 5000 cents = 50.00
  a[0] (1st, the remainder) = netC - a[1] = 14900 - 5000 = 9900 cents = 99.00
  order repair: a[0]=9900 > a[1]=5000, already in order -> nothing to fix

Result:
  places = 2
  1st  99.00   66.44 % of net (pct)   60.00 % of gross (pctOfGross)   6.60x buy-in
  2nd  50.00   33.56 % of net                30.30 % of gross         3.33x buy-in
  total = 149.00 = net  ✓
  host sees: "Gross 165 · organiser 10% (16) · Prize pool 149"
```

#### (b) `icm([8000, 5000, 2000], [250, 150, 100])` — DP frontier and per-player, per-place probability

Stacks: A = 8,000, B = 5,000, C = 2,000 (total 15,000). Prizes 250 / 150 / 100. `icmStates(3, 3) = C(3,0) + C(3,1) + C(3,2) = 1 + 3 + 3 = 7` frontier entries across the three rounds.

```
Round 0 (deciding 1st place), frontier = { mask 0: {p=1, rem=15000} }:
  A: P = 8000/15000 = 0.53333  -> eq[A] += 0.53333 * 250 = 133.3333
  B: P = 5000/15000 = 0.33333  -> eq[B] += 0.33333 * 250 =  83.3333
  C: P = 2000/15000 = 0.13333  -> eq[C] += 0.13333 * 250 =  33.3333
  new frontier:
    mask{A}: p=0.53333, rem=7000   (15000-8000)
    mask{B}: p=0.33333, rem=10000  (15000-5000)
    mask{C}: p=0.13333, rem=13000  (15000-2000)

Round 1 (deciding 2nd place):
  from mask{A} (p=.53333, rem=7000): only B,C left
    B: p*5000/7000 = .53333*.71429 = .38095 -> eq[B] += .38095*150 = 57.1429
    C: p*2000/7000 = .53333*.28571 = .15238 -> eq[C] += .15238*150 = 22.8571
    -> mask{A,B}: p=.38095, rem=2000 ; mask{A,C}: p=.15238, rem=5000
  from mask{B} (p=.33333, rem=10000): only A,C left
    A: p*8000/10000 = .26667 -> eq[A] += .26667*150 = 40.0000
    C: p*2000/10000 = .06667 -> eq[C] += .06667*150 = 10.0000
    -> mask{A,B}: p += .26667  (total .64762, rem=2000, consistent)
    -> mask{B,C}: p=.06667, rem=8000
  from mask{C} (p=.13333, rem=13000): only A,B left
    A: p*8000/13000 = .08205 -> eq[A] += .08205*150 = 12.3077
    B: p*5000/13000 = .05128 -> eq[B] += .05128*150 =  7.6923
    -> mask{A,C}: p += .08205 (total .23443, rem=5000, consistent)
    -> mask{B,C}: p += .05128 (total .11795, rem=8000, consistent)

  frontier after round 1 (sums to 1.0):
    mask{A,B}: p=.64762, rem=2000  (only C left)
    mask{A,C}: p=.23443, rem=5000  (only B left)
    mask{B,C}: p=.11795, rem=8000  (only A left)

Round 2 (deciding 3rd place, last=true, remaining player takes it with probability 1):
  mask{A,B} -> C is last: eq[C] += .64762*100 = 64.7619
  mask{A,C} -> B is last: eq[B] += .23443*100 = 23.4432
  mask{B,C} -> A is last: eq[A] += .11795*100 = 11.7949

Totals (= engine output, r2-rounded):
  eq[A] = 133.3333+40.0000+12.3077+11.7949 = 197.4359  ≈ 197.44
  eq[B] =  83.3333+57.1429+ 7.6923+23.4432 = 171.6117  ≈ 171.61
  eq[C] =  33.3333+22.8571+10.0000+64.7619 = 130.9524  ≈ 130.95
  sum = 500.00 = pool  ✓

Per-player, per-place probability (exact fractions, /15 and /195):
                 1st        2nd        3rd
  A (8000)     8/15=.5333  68/195=.3487  23/195=.1179
  B (5000)     5/15=.3333  ~.4322        64/273=.2344  (mask{A,C} p=.23443, B is the last player left)
  C (2000)     2/15=.1333  ~.2190        .6476  (mask{A,B} p=.64762, C is the last player left)
  (each row sums to 1; verify: e.g. A: .5333+.3487+.1179=.9999≈1)
```

#### (c) `settleUp` for balances +4 +3 +3 −6 −4 (A, B, C, D, E)

```
Values in cents (all whole euros here): A=+400, B=+300, C=+300, D=-600, E=-400. Total = 0.

DP idea (§F2.10): best[mask] = max over i in mask of best[mask minus i] + (sum(mask)==0 ? 1 : 0)
                  count of transfers = (people with a balance) - best[full mask]

Key zero-sum subsets found by the DP (there are only two that matter here):
  {A, E}:    sum = +400 - 400 = 0   -> a 2-person zero-sum group
  {B, C, D}: sum = +300+300-600 = 0 -> a 3-person zero-sum group
  {A,B,C,D,E} as one group would also sum to 0, but splitting into the two
  groups above gives 2 independent zero-sum groups vs 1 for the whole table,
  and best[mask] takes the MAX number of groups -> best[full] = 2.

  (Greedy pairing on the whole table needs 4 transfers here; splitting into the most zero-sum groups is what gets it to 3.)

  count = (5 people with a balance) - (2 groups) = 3   <- matches r.count

Inside each group, "biggest debtor pays biggest creditor" (ties by name):
  Group {A, E}: A=+400, E=-400
    E (only debtor) pays A (only creditor) 400  -> E pays A 4.00   (1 transfer)
  Group {B, C, D}: B=+300, C=+300, D=-600
    debtor D(-600), creditors B(+300) and C(+300) tie -> alphabetical: B first
    D pays B 300  -> D pays B 3.00   ; D now 0-300=-300, B now 0
    debtor D(-300), creditor C(+300)
    D pays C 300  -> D pays C 3.00   ; both now 0                    (2 transfers)

Result (engine's actual order): D pays B 3, D pays C 3, E pays A 4
  count = 3, groups = 2   <- matches PNTPayouts.settleUp() output exactly
```

#### (d) `bubbleSave([99, 60, 30], 15, 'proRata', 1)` — the D10 default

This is the C-bubble worked example ("1st 91 (−8) · 2nd 55 (−5) · 3rd 28 (−2) · 4th (the bubble) 15" in C-bubble, "Bubble save"), confirmed by running the engine.

```
Inputs: prizes = [99, 60, 30] , amount = 15, fundFrom = 'proRata', unit = 1 (whole euros)

pC (cents) = [9900, 6000, 3000], totalC = sum(pC) = 18900
aC = toCents(15) = 1500
uC = toCents(1) = 100   (unit=1 means round to whole euros, not raw cents)

For each place below 1st (i = 1, 2):
  i=1 (2nd, 60): t = round(aC * pC[1] / totalC / uC) * uC
                    = round(1500 * 6000 / 18900 / 100) * 100
                    = round(9,000,000 / 18900 / 100) * 100
                    = round(476.190 / 100) * 100 = round(4.7619) * 100 = 5 * 100 = 500 cents (5.00)
  i=2 (3rd, 30): t = round(1500 * 3000 / 18900 / 100) * 100
                    = round(4,500,000 / 18900 / 100) * 100
                    = round(238.095 / 100) * 100 = round(2.38095) * 100 = 2 * 100 = 200 cents (2.00)
  shares = [500, 200], taken = 700 cents

taken(700) <= aC(1500) -> no re-floor fallback needed

Apply:
  pC[1] -= shares[0]: 6000 - 500 = 5500  (55.00)
  pC[2] -= shares[1]: 3000 - 200 = 2800  (28.00)
  pC[0] -= (aC - taken) = 1500 - 700 = 800: 9900 - 800 = 9100  (91.00)
  push aC = 1500 (15.00, the new bubble place)

Order check: 91.00 >= 55.00 >= 28.00 >= 15.00  -> valid, no RangeError

Result: [91, 55, 28, 15]
  1st  91 (was 99, -8)
  2nd  55 (was 60, -5)
  3rd  28 (was 30, -2)
  4th  15  (the bubble, gets its buy-in back)
  total = 91+55+28+15 = 189 = 99+60+30+15  ✓ money conserved
```

---

## F3. Seating

- **Table count:** `ceil(players / maxPerTable)` (max 4–10, default 9; the free plan is one table, D5). The host can override the count (at least 2 players per table; over the max is allowed with a warning).
- **Split:** `base = floor(n / t)`, the first `n mod t` tables get one extra — 19 at max 9 → 7 · 6 · 6; 11 → 6 · 5.
- **Draw:** shuffle (cryptographic RNG), deal in order into the tables; random dealer per table. Per-table and all-tables **Randomize seats** and **Random dealer**, each with a confirm that says who moves.
- **Check-in seating** (the mode chosen on C4): a confirmed player gets a seat immediately.
  - *Fully random* (default): a random free seat at the shortest table (ties → the lower table number).
  - *Guests with inviter*: a guest goes to the inviter's table if it has a free seat and is no more than one player above the shortest table; otherwise the shortest table. Seat within the table is random. At a full redraw, each guest is placed right after their inviter in the shuffled order before the deal, so they land at the same table. Guests are seated one at a time, in the order their check-ins are confirmed, against the table sizes at that moment — nothing is reserved ahead, so two guests confirmed back to back can land at different tables.
  - *Guests separate*: a guest goes to the shortest table **without** their inviter; if the inviter's table is the only one, fully random. At a full redraw, guests are dealt starting from a table other than the inviter's.
  - *Manual*: only if O6 is approved.
  - A guest whose inviter has not arrived yet is seated fully at random.
- **Balancing — TDA 11-A** (`planBalanceMove`): when the largest and smallest tables differ by **2 or more**, the player **due the big blind next** at the largest table (seat `(dealer + 3) mod size`) moves to the seat at the smallest table that **posts the big blind next** (`(dealer + 3) mod size`, at the end if that is 0). Confirm copy: "{name} (big blind next at Table X) moves to Table Y, seat N — posts the big blind there next hand." The app recommends; the host confirms; the mover finishes the current hand first.
- **Break a table and redraw:** offered when `ceil(players / max)` < current tables; redraws everyone with fresh seats and dealers; every table keeps ≥ 2 players. At one table's worth → the final-table redraw (C7).
- **Hand-for-hand:** on the bubble with 2+ tables (remaining = paid + 1), the dashboard shows "Hand-for-hand" and each table marks "hand done"; the clock pauses between hands (host toggle).
- **Manual seat moves** beyond these are open (O6).

## F4. Clock and time

- **Clock segments:** levels and breaks are separate segments; trailing breaks are dropped. The rebuy pause is a hold at the close level (status `rebuyPause`), not a timed segment.
- **Rollover:** at 0 the authority advances: a break follows → `onBreak`; this is the rebuy close → `rebuyPause` (the settlement, C6); past the last planned level → `end` (C5's "end" state) and offer "Add a level" (§F1.12) or "Repeat the last level"; otherwise the next level, announcement, undo entry, revision + 1.
- **Server time** and non-authority display: §E9.
- **Late start:** starting after `startTime` keeps `endBy`; the engine re-fits with the shorter T (a pace that no longer fits raises the §F1.3 warning before the host starts; once running, no silent re-generation).
- **Total time** on the dashboard = now − the actual start, excluding paused time.
- **Drift:** `projected = now + (time left in the current level) + Σ lengths of the levels after it up to the target level + Σ breaks still ahead before the target level (+ the 10-min rebuy pause if it hasn't happened)`; `drift = projected − endBy`. New build — neither engine nor mock implements it; write tests for it. Over +20 min → the dashboard's Speed panel suggests shortening; under −20 → lengthening. Every suggestion is a host action (−1/+1 min on the current level, add or remove a future level through the editor rules); nothing changes the ladder by itself.
- **Pause:** stores the remaining ms; resume sets `levelEndsAt = serverNow + remaining`.
- **Hard finish (optional, off by default; C-cfg §7).** The host may set a latest finish `hardFinishAt` (default the finish + 1 h; up to the finish + 3 h, 15-minute steps) and the split used if it is reached: `icm` (default) or `chips` (chip chop, §F2.7). It is fixed from posting, like the prices (§E8), and printed on the invitation ("Hard finish 01:30 — if more than one player is left, prizes are split by ICM"), so everyone accepts it with their RSVP. At `hardFinishAt − 15 min` the dashboard and the TV show "Hard finish at 01:30 — about 15 minutes left." At `hardFinishAt` the clock holds at the end of the hand in progress (the host taps **Hand finished**); the deal screen (C-deal) opens with the agreed split selected and the live stacks to type in, and confirming ends the game like any agreed deal (C8). **Play on** (host only; confirm "Everyone at the table agrees to play on?") moves `hardFinishAt` by 30 minutes, once per tap, each logged in the game history. The levels never change: time control comes from the agreed split, not a silent turbo. A game that ends before the hard finish ignores it.

## F5. Cash game maths

```
cashIn(p)        = buyIn + Σ topUps
net(p)           = cashOut − cashIn            (only once cashed out)
onTable          = Σ issued (buy-ins + top-ups) − Σ returned (cash-outs)
settle allowed   = Σ counted stacks of players still seated == onTable   // else "Recount"
BB depth shown   ≈ stack / BB
settle-up        = settleUp(nets of everyone)  (F2.10)
```

The chip **total** per player is host-tracked; the **breakdown** of any new stack is proposed with `fewestChips` from the chosen set. Settlement is guidance only; "Copy as text" produces lines like "Costa pays Alexey 12".

---


# PART G — REFERENCE

## G1. Constants

| Area | Constant | Value | Where |
|---|---|---|---|
| Paces | Turbo · Regular · Deep level length | 15 · 20 · 30 min (one length all night) | §F1.3 |
| | gMax per pace | 1.6 · 1.5 · 1.45 | §F1.3 |
| | Minimum growth | 1.2 | §F1.3 |
| | Spare levels past the target | 4 | §F1.3 |
| | Fit tolerance | 5 min | §F1.3 |
| | Hard finish (optional) | off; default finish + 1 h, up to + 3 h, 15-min steps; split ICM (default) or chips; Play on +30 min | §F4, C-cfg §7 |
| Depth | Target D | turbo 60 · standard 100 · deep 160 BB | §F1.2 |
| | Hard band | turbo 50–70 · standard 85–130 · deep ≥ 150 BB | §F1.5 |
| | Playable floor `MIN_PLAYABLE_DEPTH` | 20 BB; below it the case is too small for the field | §F1.5 |
| End target | K | 20 (no ante) · 27 (any ante) — retune after ~20 nights (D8) | §F1.6 |
| Chips | Search ceiling per colour | 24 | §F1.5 |
| | Denominations per stack | 3–5 | §F1.5 |
| | Eligible chip | ≤ S/2; penalised above S/4 | §F1.5 |
| | Bank rebuys | Poisson 90th percentile of rate × players | §F1.5 |
| | Add-on / bonus in the bank | every player | §F1.5 |
| | Add-on multiplier | 1.10–1.50 (default 1.25) | C1 step 3 |
| | Early bonus | 2.5–25 % step 2.5; the wizard pre-fills 12.5 %; the engine's default when omitted is 0 (off) | C1 step 2, §F1.1 |
| Colour-up | Trigger | raw BB ≥ 4 × next chip; at the first break after | §F1.7 |
| Antes | Individual | 10 % of BB on a chip in play, ≥ 1 chip (D7) | §F1.8 |
| | Start | after rebuy close; else first level ≤ 40 BB | §F1.8 |
| Breaks | Length · count · spacing | 10 min · floor((T−30)/90) · every ~90 min of play | §F1.9 |
| | Rebuy pause | 10 min | §F1.2 |
| Rebuy close | Fresh M floor | turbo 10 · standard 15 · deep 20 | §F1.10 |
| | Latest | 40 % of the night | §F1.10 |
| | Default rate | 35 %; learned after 8 games | §E14 |
| | Limited rebuys | 1–10 per player (default 2) | C1 step 3 |
| Payouts | Curve | ps15 (≈ top 15 % of entries, rebuys count) | §F2.1 |
| | Max places | 6 | §F2.1 |
| | Min cash | ≥ 1.5 × buy-in | §F2.1 |
| | Never pay half the field | places ≤ floor(players/2) − 1 | §F2.1 |
| | Owner shapes | 52.5/32.5/15 · 42.5/30/17.5/10 | §F2.1 |
| | Cash unit | < 5 → 1 · < 100 → 5 · < 500 → 10 · else 50 | §F2.2 |
| Fee | Modes | none · percent (0–30 % step 1, default 10 when on) · fixed (step 5, from 5 up to the expected pool − 1 cash unit; lowered at the close if it would reach the pool); `perEntry` exists in the engine only, not offered in v1 | §F2.3, C-cfg |
| | Rounding | down to 1 unit | §F2.3 |
| ICM | Exact up to | 2,000,000 states; else 200,000 Monte-Carlo samples (seeded) | §F2.5 |
| | Deal players | 2–5 (suggestion from ≤ 5 by default) | §F2.8 |
| Seasons | Default formula | 10 × √(players / finish), one decimal | §F2.9 |
| Settle-up | Max people with a balance | 16 | §F2.10 |
| Tables | Max per table | 4–10 (default 9) | §F3 |
| | Free plan | 1 table | D5 |
| | Balance trigger | difference ≥ 2 | §F3 |
| Clock | Editor stale window | 90 s (heartbeat 30 s) | §E9 |
| | Server-time recalibration | every 10 min while a clock runs | §E9 |
| | Toasts | at least 4 s; 5 s with Undo | §B3, §E9 |
| | Undo depth | 30 | §E9 |
| | Check-in opens | start − 10 min | §E8 |
| | RSVP deadline | 1–72 h before the start, default 24 (O3) | C-cfg §1 |
| Learning | Pace | last 5 games; average overrun at least 15 min either way; clamp ±20 % | §E14 |
| Codes | Alphabet · length | `ABCDEFGHJKMNPQRSTUVWXYZ23456789` · 6 (31⁶) | §E7 |
| | Lookups | 10 per minute per device | §E7 |
| Chat | Rate | 8 per 30 s; 4,000 ms apart (server ~3,750 ms) | §E10 |
| TV | Text scale · rotate | 0.7–2.0 · 5/8/12/20/30 s (default 8) | §E12 |
| Sound | Volume | no in-app setting — the device volume applies | §E11 |
| Free limits | Saved templates | 3 (chip sets are unlimited — D4 does not limit them) | D4 |
| Tools | ICM calculator | 2–9 players | E4 |
| Quick start | Players · buy-in | 2 up to one table on the free plan (9, or 10), 2–30 on Premium; default the last headcount, else 8 · 5–100 step 5 | C0 |
| Cash | Default stakes · buy-in range | 1 / 2 · 50–250 BB | D1 |

## G2. Acceptance catalogue

### G2.1 How to run the reference suites

| Suite | File | Count | Run |
|---|---|---|---|
| Structure engine | `research/structure_engine_test.html` | 759 assertions | `mockup/devtools/run_engine_tests.sh` → "RESULTS: 759 / 759 passed" |
| Payouts engine | `research/payouts_engine_test.html` | 55 assertions | `mockup/devtools/run_engine_tests.sh payouts` → "55/55 passed" |
| Mock behaviour | `mockup/tests.js` | 145 tests | `mockup/run_tests.sh` → "145/145 passed" |

All three pass at this baseline (checked 27 September 2026, after the v3.1 engine fixes). The Dart port of each engine must pass the same vectors. The mock tests describe **behaviour**; rewrite each as a widget or integration test against the real app (the DOM selectors do not carry over, the behaviour does).

### G2.2 The 145 mock tests

IDs are the tests' order in `tests.js`. Screen blocks in Part D cite them in *Acceptance*. T60, T101 and T145 check the mock's own copy, markup and scripts and have no app equivalent; T137, T139 and T140 are the design-system checks of Part B.

| ID | What it proves |
|---|---|
| T1 | currency: none by default; picked in Settings and shown on every amount |
| T2 | levels: both views render the engine-generated structure |
| T3 | with nothing pinned, unplayed levels can move both ways (running and before start) |
| T4 | a pin that makes blinds repeat or dip shows a warning with a calculator, and recalc clears it |
| T5 | the Before start preview is sandboxed: switching back restores the running game |
| T6 | while running, the ante cannot start on a played or running level |
| T7 | levels: every level has SB = BB/2 on a chip in play |
| T8 | levels: played L2 is locked in-game (lock, no delete) |
| T9 | levels: running L4 is editable but not deletable |
| T10 | levels: once running, Configure locks played levels too |
| T11 | levels: before start, Configure locks nothing |
| T12 | levels: played-level lock asks to correct the record, then opens editor |
| T13 | levels: delete L8 renumbers (old L9 becomes L8) in both views |
| T14 | levels: insert level below L9 keeps the ladder rising and payable |
| T15 | levels: insert break below L12, then delete it |
| T16 | levels: hard edit L12 to a manual anchor with a calculator button |
| T17 | levels: calculator re-solves the curve around the anchor |
| T18 | rebuy close: suggestion names a level and can be accepted |
| T19 | rebuy close: picking another level overrides and moves the marker |
| T20 | seating: 11 players at max 9 per table auto-splits 6 + 5 |
| T21 | seating: each table and "all tables" have randomize + dealer buttons |
| T22 | seating: shuffling table 1 keeps the same players |
| T23 | seating: random dealer on table 2 picks someone at table 2 |
| T24 | seating: lowering max per table to 5 re-splits into 3 tables |
| T25 | settings: Game Settings holds the default max per table |
| T26 | players: + logs a rebuy and bumps the count (no question asked) |
| T27 | players: Bust is a bust — confirm, then out completely and seat freed |
| T28 | bust asks who knocked the player out: bounty to them, the row says so, Undo reverts it all |
| T29 | without a KO bounty the knockout pick is optional |
| T30 | players show no chip counts during play (stacks are typed only for a deal) |
| T31 | chip handout: start, rebuy, add-on and early bonus are exact chips from the engine |
| T32 | early-arrival bonus: anyone checked in and approved before the scheduled start |
| T33 | sound: blinds are read as words, one speaker device, a test sound, and mute on the timer |
| T34 | players: closing rebuys blocks + and Pause, turns paused players Out; reopen works |
| T35 | setup: payouts are just None / Standard |
| T36 | setup: no buy-in presets, no paid positions (regression) |
| T37 | setup: KO bounty amount only appears after turning KO bounty on |
| T38 | setup: buy-in +/- keeps the bounty separate (€20 + €5) |
| T39 | setup: start time moves in 15-minute steps and quick picks set it |
| T40 | setup: Limited rebuys asks for the number; Unlimited hides it |
| T41 | quick blind: stack is a plain number and Calculate works |
| T42 | configure: paid positions suggestion uses players and pool |
| T43 | rebuy deadline can never be set before the running level |
| T44 | inserting below any unplayed level keeps blinds strictly rising and payable |
| T45 | a pin cannot go below the level before it, and recalc stays rising |
| T46 | the final level cannot be pinned below the one before it |
| T47 | chip rule comes from the chip set (1/5/25/100) and never colours up the biggest chip |
| T48 | deleting the rebuy-close level moves the marker to the level before it |
| T49 | ante start is driven by the Configure stepper and follows its level |
| T50 | timer reads the running level from the structure |
| T51 | pause: Rebuy is priced buy-in + bounty and brings the player back |
| T52 | a per-player cap blocks the + as well |
| T53 | timer: rebuys-closing hold, add-on break (once per player), colour-up break, end of structure |
| T54 | seating: pause → Out and a bust bring it to one table; break-table prompt redraws |
| T55 | seating: table override keeps at least 2 players per table |
| T56 | configure: tables summary is based on expected players |
| T57 | settings: Game Settings default feeds Configure and is capped at 10 |
| T58 | Freeze Out hides every rebuy control; Rebuy brings them back |
| T59 | quick blind updates on − / + too |
| T60 | no stale copy contradicting the model |
| T61 | structure never drops below 2 levels and can always be rebuilt |
| T62 | chop screen: ICM and a real chip chop (min-cash first) computed by the payouts engine |
| T63 | generated buttons survive names with quotes and apostrophes |
| T64 | KO bounty amount moves in €5 steps |
| T65 | seating: TDA move — the player due the big blind next moves to the short table's worst seat |
| T66 | organiser contribution: host-only setting in Configure with a live preview; default in Game Settings |
| T67 | start now: one screen from Groups and from an empty Game tab to a running clock |
| T68 | repeat last night: one tap reposts the same game from Groups |
| T69 | profile: top-right icon opens Profile with personal settings |
| T70 | text is left-aligned everywhere except numeric displays and controls |
| T71 | group rows are readable: names are light text on the dark background |
| T72 | configure shows the engine proposal: stack in big blinds, chips per player, projected end |
| T73 | rebuy close offers the engine options and picking one sets the deadline |
| T74 | payouts come from the payouts engine, in € and % |
| T75 | generate re-solves the structure from the Configure inputs |
| T76 | game tabs stay pinned at the top while a game screen scrolls |
| T77 | individual ante is 10% of the big blind on a chip in play; Off means no ante anywhere |
| T78 | fuzz: 400 seeded random operations keep every ladder rising and payable |
| T79 | deal suggestion appears at 5 or fewer players (setting); the ICM deal takes 2 to 5 players |
| T80 | Premium matrix (D4): ICM free, 3 free templates, 2+ tables Premium, pricing monthly / yearly / one-time |
| T81 | free tier (D5): the RSVP that needs a second table asks the host days before, never at the door |
| T82 | bubble save (D10): every paid place chips in pro rata to its prize, only if the table agrees |
| T83 | co-host (D15): runs the night, cannot touch structure, payouts or your contribution |
| T84 | take-over: a second phone opening the same game asks who runs the clock |
| T85 | offline: the clock keeps running and changes wait until the connection is back |
| T86 | restore: opening the app while a game runs offers to resume it |
| T87 | cash game: settle-up is the fewest transfers from the ledger, checks the chips, and copies as text |
| T88 | seasons (D14): field-size weighted by default, 10-7-5-3-1 ladder as the alternative, both from the engine |
| T89 | RSVP: a plus-one queues from when it was added; a full table puts it on the waitlist; a drop promotes it |
| T90 | RSVP deadline: once it passes nobody new can join, but the waitlist still moves up |
| T91 | player live view: same clock, blinds and prizes as the host, read-only, no organiser cut |
| T92 | TV mirrors the running game (D2): level, blinds, players and the real payouts |
| T93 | results card (C9): podium, knockouts and tonight's season points, shared as a real image |
| T94 | import past results (B12): one night per line, errors named by line, duplicates refused, nights join the season |
| T95 | money owed: every buy-in, rebuy and add-on is recorded as owed until the host marks it paid |
| T96 | clock: one minute more or less, and restart puts the level back to its full length |
| T97 | game page: where it is, directions, and a calendar file with the right time and place |
| T98 | deal: count a stack by chip colour instead of doing the maths by hand |
| T99 | hand-for-hand on the bubble with 2+ tables: every table finishes the hand before the next one; it ends in the money |
| T100 | late arrival: one tap seats them, hands out the chips and records the buy-in, until rebuys close |
| T101 | structure: every screen sits inside the phone frame scroll area (no stray closing tags) |
| T102 | accessibility: every text on every screen meets WCAG AA contrast against its real background |
| T103 | tap targets: every button is at least 44 × 44 px (toggles, checkboxes and chips get platform hit-slop) |
| T104 | undo in the toast: a rebuy, an add-on or a payment is one tap and can be taken back from the toast |
| T105 | check-in: the host approves arrivals one by one or all at once, and each is seated |
| T106 | configure shows what most hosts touch; advanced settings open under More options |
| T107 | haptics: level changes vibrate the host phone (setting on by default) |
| T108 | join: players and the TV get a code and a QR straight from the timer, no account needed |
| T109 | empty Game tab: start a tournament or a cash game in one tap |
| T110 | toasts are readable: they wrap instead of cutting off, and stay up long enough to read |
| T111 | stack options: engine pick vs small chips out; picking one re-deals the stacks and re-scales the blinds |
| T112 | new group: a name is enough, then a 6-character join code (no I, L, O, 0, 1) to share |
| T113 | first open: a brand-new host sees one action, no account wall, and a running clock 2 taps later |
| T114 | first open: empty screens explain themselves with one action; exiting restores the demo |
| T115 | guest link: RSVP in one tap, no account; a name is asked first |
| T116 | total time reads the real clock: 0:00:00 at the start of level 1, 0:01:00 a minute in, break time included |
| T117 | blind tool: Generate runs the structure engine on the typed players, duration and stack |
| T118 | payout tool: Calculate uses the payouts engine (owner split) and suggests the number of places |
| T119 | ICM tool: stacks plus the prizes still to pay give ICM and a min-cash-first chip chop |
| T120 | clock tool: next, previous, restart and your own levels |
| T121 | chip presets: edit, add a colour, save — new games use it; tonight's game keeps its chips |
| T122 | chips without printed values: the biggest pile gets the smallest value, up 1-5-25-100 |
| T123 | join a group: a 6-character code finds it (typos in case and dashes forgiven); a game code opens the game |
| T124 | invite: pick a group, share its own code and QR, add someone you have played with |
| T125 | cash top-up: pick an amount; chips, ledger and settle-up follow; Undo takes it back |
| T126 | confirm sheet: buttons inside the sheet body keep their labels; the real Cancel gets the cancel label |
| T127 | invite: member counts match the Groups list |
| T128 | new game date: calendar opens on the next Friday, moves month by month, past days locked; posting lists the game |
| T129 | pace: three scenarios with finish times; the slowest that finishes on time is recommended and in use |
| T130 | late start: the finish stays, the pace re-fits to the time left, and a field that no longer fits gets a warning with choices |
| T131 | quick game: pace chips with each finish time; default is the recommended pace, else Regular with a note |
| T132 | blind tool: the pace sets the level length |
| T133 | shell: top bar with the real logo, menu and avatar; five tabs Home, Games, Chat, Members, More |
| T134 | drawer: the menu opens a drawer with the group switcher and every destination; picking one navigates and closes it |
| T135 | More opens the Explore sheet; a tile navigates and closes it |
| T136 | guest screens: no tab bar and always an exit |
| T137 | restyle: every screen opens with their page header — square back button, big sentence-case title |
| T138 | restyle: long explanations sit behind a Why? link; every input stays on screen |
| T139 | restyle: their component kit — glowing primary, 18px cards, tall inputs on the dark ground, uppercase pills, grey section labels |
| T140 | restyle: players and members carry an initials avatar that never leaks into the text |
| T141 | no yellow anywhere (owner 2026-09-26: their gold money colour is not carried over) |
| T142 | dashboard (their C5): live header, scoreboard, big Pause and Next, Speed · Edit · Seats · TV |
| T143 | dashboard lists: players with table and seat and an Out button; eliminated with undo; prizes from the payouts engine |
| T144 | ICM deal: amounts must add up; confirming ends the game and writes the results |
| T145 | no JS errors during load or tests |

### G2.3 Behaviours with no mock test yet — write these in the app

Specified in this document, not covered by any of the 145 mock tests. Each needs its own widget, integration, Functions or rules test.

| # | Behaviour | Where |
|---|---|---|
| 1 | Level insert refused when pins leave no room — both messages | C2 |
| 2 | Players-in-play ±1 is a correction only (copy, bounds) | C5 |
| 3 | Check-in opens at exactly start − 10 min (9 min before: locked; 10: open) | C4p, A6 |
| 4 | No-show gate: Wait n min / Start without → `noShow`, no buy-in taken | C4 |
| 5 | Code lookups: the 11th within a minute is blocked | A7, §E7 |
| 6 | Chat: the 9th message within 30 s, or two within 4 s, is blocked with its copy; unread counts | B4, §E10 |
| 7 | Input normalisation: decode, strip tags, collapse spaces, truncate to each limit | §E16 |
| 8 | Polls: change a vote, multi-choice, un-vote deletes the entry | B5 |
| 9 | Import: names match members (trim, lower-case); unmatched become guest rows | B12 |
| 10 | Deal triggers `targetTime`, `inTheMoney`, `headsUp`, each once per game | C-bubble, §F2.8 |
| 11 | Bubble save: Record / Not now; everyone's view updates | C-bubble |
| 12 | Hand-for-hand: Stop; players out in the same hand at different tables tie and split | C-bubble |
| 13 | Same hand, one table: the bigger starting stack finishes higher | C-players |
| 14 | Walk-in gate matches late registration; hidden after the settlement | C-players |
| 15 | Last bust opens C8 automatically; End tournament; Confirm writes everything | C8 |
| 16 | Correct results later: standings and season points recompute | C8, §E14 |
| 17 | Recap: comeback line omitted without typed stacks; fastest bust uses `bustLevel` | C9 |
| 18 | Legal gate blocks enabling the fee until ticked | H4 |
| 19 | Fixed fee lowered at the close when it would reach the pool | C-cfg §10, §F2.3 |
| 20 | Ledger: a second buy-in or add-on is rejected, rebuys are not | §E9 |
| 21 | Take over: the old device's next write fails and it becomes a live view | §E9 |
| 22 | Offline writes aimed at a superseded revision are rejected and listed | §E9 |
| 23 | Server time re-measured every 10 min | §E9 |
| 24 | A newer codec version `_v` blocks becoming the authority | §E2 |
| 25 | Account deletion cascade and its block | §E15 |
| 26 | Firestore rules, per path in the §E4 table | §E4 |
| 27 | Notifications: each type fires once, the originator never re-banners, reminders move when the time changes | §E10 |
| 28 | Route guard, all 10 steps (anonymous host reaches `/home`; co-host sees levels view-only) | §C3 |
| 29 | Drift line beyond ±20 min | C5, §F4 |
| 30 | Auto ante rule — the four vectors | §F1.8 |
| 31 | Quick start: the free one-table cap, no Premium prompt | C0 |
| 32 | Seating modes: guests with inviter, guests separate | §F3 |
| 33 | RSVP deadline setting 1–72 h | C3, C-cfg §1 |
| 34 | Cash: a 17th open balance is blocked | D2 |
| 35 | Chip-set editor: the value ladder, removing a colour down to two | F5 |
| 36 | Chip case too small: the blocking card, its three buttons, Create disabled | C1 step 4, §F1.5 |
| 37 | Add-on take-up learning from the last 8 games | §E14 |
| 38 | Hard finish: warning 15 min before, the split at the time, Play on (+30 min, logged) | §F4, C5 |
| 39 | Hard finish fixed from posting and printed on the invitation | §E8, C3 |
| 40 | Security rules: a co-host can't write `settings.*`, `hostUid` or `coHostUids`; a free host can't write Premium fields; nobody can create a membership without `joinGroup` (rules test suite) | §E4 |
| 41 | `publicGames` accepts only its listed keys and only from the host, a co-host or a Function; it disappears at `completed` | §E4, §E7 |
| 42 | `resolveJoinCode`: the 11th lookup in a minute is refused server-side; App Check required | §E7 |
| 43 | Chat: filter holds offensive words; Report reaches the host (and support after 24 h); Block hides a member's messages | §E10, B4, B9 |
| 44 | Hand over hosting; take over the clock after 30 min of a silent host phone | §E9, C-ops |
| 45 | A duplicate bust (double tap or a replayed offline write) changes nothing | §E9 |
| 46 | Quick game with no group: stored under `soloGames`, listed in History as "Solo", C8 skips group writes | §E4, B7, C8 |
| 47 | Two or more no-shows: one row each, a shared Wait | C4 |
| 48 | Rebuy settlement overruns the break: add-on window overtime, pool locks only when everyone is resolved | C6 |
| 49 | Cash: Rejoin after cashing out; Preview settle-up writes nothing | D2 |
| 50 | Reminders keep their lead time across a daylight-saving change | §E1 |
| 51 | TV sound: its own tap to unlock; the phone stays audio master until then | D3, §E11 |
| 52 | Accessibility: live-region announcements, labels on icon-only controls, focus rings, the visual twin of every sound, text scaling to 200 % | §B4, §B5 |
| 53 | Analytics starts in the EU only after Allow; privacy policy lists Analytics and Crashlytics | §E1, H1 |
| 54 | Chip colour names: every "5 White · 9 Red" reads the name from F5 | F5 |

## G3. Open decisions

Each needs an owner answer. Until then, build the default in the right-hand column.

| ID | Question | Build meanwhile |
|---|---|---|
| **O1** | Casting: does the TV get the clock by Chromecast/AirPlay second screen, or only by opening a pairing code in its browser? | Browser pairing (`/tv/:code`, QR). Casting later. |
| **O2** | Prices for Monthly, Yearly and the one-time Host licence. | Store products with prices read from the store; placeholders in test builds. |
| **O3** | RSVP deadline: 24 h before the start (the mock) or 1 h (the old reference)? | 24 h, as a host setting with that default. |
| **O4** | Engine retune after ~20 real nights (K_ANTE 27, deep and turbo growth are extrapolated — D8), and whether rebuy nights get a gentler climb. | Ship the constants in §G1; log bust levels and final BBs (with consent). |
| **O5** | With an organiser contribution on, label the players' pool "after organiser costs"? | **Unresolved.** Ship without the label for now (the fee is host-only and off by default, behind H4); the research recommends the label. |
| **O6** | Manual seat moves (drag a player to any seat) beyond TDA balancing and randomise. | Not shown. |
| **O7** | A partial-deal UI ("lock most, play on for the rest") beyond the engine's `leaveForWinner`. | Not shown; the three full deals only. |
| **O8** | Progressive and Mystery bounty payout mechanics (split at each knockout; mystery draw). | Premium controls visible but "Coming soon"; Fixed KO works. |
| **O9** | A free trial for Premium, and how long? | No trial; the button reads "Continue". |
| **O10** | Can one Premium cover a whole group (any host in it)? | Premium belongs to the buying account only. |
| **O11** | Data region and processors per launch market. | EU region for an EU launch. |
| **O12** | Launch order: web first (works today from a link) or the store apps first? | Web and apps from one codebase; release web first if the stores delay. |
| **O13** | A soft shot clock (per-decision timer, 30 / 60 / 90 s)? It was in the old reference, never in the mock. | Not in v1 (§A2). |
| **O14** | Quick start with more players than one table on the free plan: cap it (built), or allow one night? | Capped at the group's max per table (9, or 10 after the free alternative); no Premium prompt. |
| **O15** | Cash-game chip value: per session (built) or saved on the chip set? | Per session, default 1. |
| **O16** | Commission board tiles for the six group screens that have none (New group, Group settings, Default chip set, Standings and seasons, Import, Invite)? | Build them from the prose with Part B's components. |
| **O17** | App-store submission: launch the first version with the organiser contribution off (remote flag), and target 17+ / Mature with truthful gambling-related answers? | Yes — §A3 "App-store readiness"; turn the contribution on per market after the lawyer (D13) and after the store has approved the app once. |

## G4. What changed

### v3.1 — the audit (27 September 2026)

Nine independent checks compared v3.0 against the engine code, the mock, the board and the old documents. Everything they found is fixed in this version. The main changes:

| Area | v3.0 said | v3.1 |
|---|---|---|
| **Engine: chips in play** | Colour-ups planned from every colour in the case | From the colours actually **dealt**. v3.0's engine produced unpayable blinds on 45 of 432 realistic nights (e.g. L2 6/12 with no 1-chips dealt); fixed, with a 240-night regression test |
| **Engine: pace explanation** | "Starts at 20 min… eases to 20 min…" in pace mode | "Every level is 20 minutes (the regular pace). The blinds climb about 50% a level to finish by 00:30." |
| **Engine: `roundDeal`** | The leftover could push an amount above its cap | The leftover goes to the largest amount under the cap; an impossible cap is refused |
| Ante pre-selection | `recommendAnte` (not in any code) suggested Individual for small tables | The **Auto** rule: no ante for ≤ 6 players and < 3.5 h, otherwise BB ante; never Individual (home-game research) — **owner can veto** |
| Locks | Prices and chip amounts both "locked from posting" | Prices lock at posting; chip amounts lock at the first check-in |
| Wizard step 1 | Asked "Expected players" (rejected in §A5) | Removed; step 5 builds for the last headcount and Configure uses the RSVPs |
| KO bounty | Progressive looked free | Progressive and Mystery are both Premium (D4) |
| Chip sets | "3 free, together with templates" | Unlimited and free (D4 limits only templates) — **owner can veto** |
| Starter presets | Board names (Friday Freezeout…) | The mock's four: Freezeout, Sprint, Deep, KO Bounty |
| Host / co-host | No per-game host field; co-host could open the level editor with full rights | `hostUid`, `coHostUids`; co-host sees the editor view-only |
| Security | Principle only | A per-path rules table (§E4) with a rules test suite |
| Sync | Server time measured once; take-over and stale writes unreconciled | Re-measured every 10 min; every authoritative write is a transaction on `editorDeviceId`; stale offline writes rejected and listed |
| Ledger | No duplicate protection | One buy-in and one add-on per player (idempotency key); rebuys unlimited |
| Organiser fee | No cap on a fixed fee; two lock rules | Capped and lowered at the close if needed; one lock rule |
| End of night | No automatic finish; no correction path | Last bust opens the finish order; results can be corrected later |
| Same-hand busts | Undefined | One table: bigger starting stack higher; across tables in hand-for-hand: tie and split |
| Deal triggers | Two of four had no copy | All four with exact copy, each once per game |
| Automations | Scattered | §E17: every automatic behaviour, 97 rows, each with trigger, algorithm, result, override and test |
| Algorithms | Described | Plus a step-by-step trace of the demo night (§F1.16), plain-word explanations of every structure function (§F1.17) and hand traces of the payout, ICM, settle-up and bubble maths (§F2.12) |
| Tests to write | Only the 145 mock tests | Plus 54 behaviours that need new tests (§G2.3) |
| Process | Order of work only | Environments, definition of done, design dependency, baseline hashes (§A3); reading paths per role (front) |

### v3.1 — the final review (27 September 2026, evening)

The owner asked for the whole app to be checked once more, "final and perfect". Five more reviews: an internal consistency read of v3.1, a first-night walkthrough of every role and failure, a security, privacy and app-store review, an accessibility and wording review, and the structure evidence from the owner's poker library and published home-game guidance (§F1.18). Every finding was checked against the text before it was applied.

| Area | Before | Now |
|---|---|---|
| **Engine: case too small** | 1–4 chip stacks dealt as "fits · bank OK" when the case could not cover the field (500-piece set with rebuys and add-ons from 21 players) | A 20 BB floor; below it the case is reported too small, with the largest field it covers and three remedies (§F1.5 point 7, C1 step 4) |
| **Engine: chips in play** | Early-bonus chips left out of C | Counted; the demo night's C is 4,700 and its levels are unchanged (§F1.16) |
| **Engine: fit** | A night needing 12.01 levels was reported a whole level (20 min) late | Fits when it needs at most 5 minutes more — the same tolerance as `meta.fits`; 8 of 240 test nights lose a false warning |
| Evidence | Constants explained | Each constant set against its sources, with a verdict (§F1.18); the end target K stays, argued in §F1.18 |
| Hard finish | Only a deal suggestion at the target time | Optional, agreed at posting, warning at −15 min, split by ICM or chips, Play on (+30 min) — **owner can veto** (§F4) |
| Add-on take-up | Fixed 70 % | Learned from the last 8 games (§E14) |
| Consistency | 16 contradictions found by the final read | Fixed: offline banner copy, one list of 13 notification types, RSVP-deadline field, fee lock at the rebuy close, medal colours, stray file references, "per entry" fee marked engine-only (the owner's v2.8.0 decision) |
| Security rules | Members could not join (or anyone could); co-hosts could write host-only settings; Premium only gated in the UI; `publicGames` checked field names, not the writer; codes readable by anyone | Joining through `joinGroup`; a changed-keys rule for co-hosts; Premium checked against the entitlement; `publicGames` from the host/co-host/Function with an allow-list; codes only through `resolveJoinCode` with App Check; codes and projections expire (§E4, §E7) |
| Chat moderation | None | Filter, Report, Block, host report inbox, 24-h escalation to support — required by Apple 1.2 and Google's UGC policy (§E10, B4, B9) |
| App stores | Not addressed | Readiness checklist: organiser contribution off at first submission, no gambling words in the listing, truthful age rating, privacy labels that match H1 (§A3, O17) |
| Privacy | Analytics and Crashlytics not in the policy; no retention | Both named in H1; EU Analytics only after Allow; retention periods (§E15, H1) |
| Night-time failures | A lone host's dead phone or early departure left the night unfinishable | **Hand over hosting**; **Take over the clock** after 30 silent minutes (§E9, C-ops) |
| Quick games | No storage path | `users/{uid}/soloGames`, listed in History as "Solo" (§E4, B7, C8) |
| Walkthrough gaps | — | Several no-shows, settlement overtime, cash Rejoin and Preview, duplicate busts, DST-safe reminders, TV sound unlock, guest removal, "Not {name}?" on a shared phone, B8's invite link |
| Accessibility | Contrast rules only | `redText` for all small red text, focus rings, screen-reader live region and labels, a visual twin for every sound, text scaling to 200 %, a Slider component, chip colours named in text (§B1, §B3, §B4, §B5, F5) |
| Wording | "admin" in 7 places | "host" everywhere; glossary rule |

### v3.0 against the old documents

This document replaces both. Changes a reader of the old documents would trip on:

| Area | Before | Now |
|---|---|---|
| Structure shape | Phased level lengths (15/13/11), duration target | **Paces** with one level length all night, fitted to a **finish time**; the phased mode is legacy only (§F1.3, §F1.13) |
| Pace choice | Silent squeeze to fit the time | Recommend Deep/Regular that fits; otherwise warn and the host picks; turbo never recommended |
| Individual ante | round(BB/4) | 10 % of BB (D7) |
| Visibility of prizes | Players saw positions only; prizes host-only | Everyone sees the pool and payouts; only the fee is hidden (D2) |
| Free vs Premium | Several conflicting lists | D4 only; ICM, one TV and level editing are free |
| Currency | € in the interface | None by default; the user picks € / $ / £ |
| Look | The mock's own styling | The board's design, no gold, crimson/black/white, green for status only |
| Tournament setup | One long Configure screen | Quick start (2 taps) + the board's 5-step wizard; Configure stays for details and live edits |
| Roles | Admin / co-admin | Host / **co-host** (D15) |
| Organiser contribution | 0–20 % | none / percent 0–30 % / fixed (per entry: engine only, not in the v1 UI), behind the legal gate |
| Payout places | Pool thresholds | Entries curve + min cash + never half the field (§F2.1) |
| Payout rounding | Multiples of 10 + a remainder | Cash unit from the buy-in; 1st takes the exact remainder |
| Running past the last level | SB = BB × 0.45 | SB = BB/2 on a chip in play; the editor's insert rule |
| Speed up / slow down | ×1.25 future blinds automatically on accept | Host actions only (±1 min, add/remove a level) |
| Cash settle-up | Greedy | Exact fewest transfers (§F2.10) |
| Rebuy cap | Per player only | Game-wide Unlimited/Limited (1–10) **and** a per-player live cap |
| TV defaults | Leaderboard on | Leaderboard off by default (the board's TV shows payouts and stats) |
| Logo | Generic spade | The PNT symbol everywhere |

## G5. Known gaps in the mock (do not copy)

The mock is the behaviour reference, but these parts of it are wrong or out of date. Build the right-hand column.

| # | In the mock | Build instead |
|---|---|---|
| 1 | Configure's paid-positions suggestion uses a legacy rule (about 1 in 4 paid, its own share table) in `suggestPaid` | `payoutPlan` (§F2.1): ps15 curve, owner shape, min cash 1.5 × buy-in, cash-unit rounding |
| 2 | The engine's `pace` explanation says "starts at 20 min … eases to 20 min … tightens to 20 min" in pace mode | "Every level is {L} minutes (the {pace} pace); the blinds climb about {n} % a level to finish by {endBy}." (§F1.10) |
| 3 | The demo seats 11 names but counts 10 in play (one player already out) | Seat and count from the same player list |
| 4 | The Explore/tools list tags the ICM Calculator "1 free / mo" | ICM is free with no limit (D4) |
| 5 | Screens not yet rebuilt in the board's layout (Home, the wizard, check-in and the rest — only the shell and the dashboard are) | Follow the board and Part D; use the mock for behaviour only |
| 6 | Payments, sign-in, push, Firestore, casting and billing are simulated | Real implementations per Part E |
| 7 | Three test names still say € (T38, T64, T74) from before the currency decision | The behaviour they test is currency-neutral; name the ported tests without a symbol |
| 8 | Configure's fee preview rounds with `Math.round` (165 × 10 % shows 17) | Use `organiserFee` everywhere (16 — it rounds down) |
| 9 | `dealTrigger` is never called; only the bubble and deal cards exist | Call `dealTrigger` on every change; all four types, once each (§F2.8) |
| 10 | "Small chips out" −/+ floors at 100 | Clamp to [S/2, 3S] (§F1.11) |
| 11 | No finish-order screen; End tournament jumps to a static recap | C8 as specified: last-bust detection, confirm, writes |
| 12 | The rebuy settlement opens only from Levels → End rebuys now, and has no resume button | Both entry points; Confirm & resume (C6) |
| 13 | No drift line; no-show and check-in window are static cards / preview buttons | As specified (C5, C4, C4p) |
| 14 | Recap's comeback and fastest-bust lines are static text; busts don't record their level | Compute them; record `bustLevel` (C9, §E14) |
| 15 | Take-over has no heartbeat; rate limits (codes, chat) are not implemented | §E9, §E7, §E10 |
| 16 | Quick start has no player cap | The free one-table cap (C0) |
| 17 | Home poll cards throw an error when an option is tapped (`selectPreset` finds no row) | B5 as specified |
| 18 | Import stores bare names, never matches members | B12 matching |
| 19 | Unknown code says "No group uses {code}…" | "No game or group uses that code. Check it with your host." (A7) |
| 20 | Table settings exist only as a personal default; Group settings has no Table settings row | Stored on the group; the personal value only pre-fills a new group (B9) |
| 21 | Chat, notifications and premium screens are static or missing | Build from B4, B6, G1 |
| 22 | The mock embeds its own copies of both engines, which predate the v3.1 engine fixes — including the 27 September ones: it still deals 1–4 chip stacks to fields its case cannot cover, leaves early-bonus chips out of C, and reports a night one level late when it needs a fraction more | Port from `research/*.js` (the fixed versions), never from the mock |
| 23 | No hard finish, no add-on take-up learning | Build from §F4, §E14 |
| 24 | Chat has no filter, Report or Block; there is no Hand over hosting or Take over after a silent host phone; a cashed-out player cannot Rejoin | Build from §E10, B4, §E9, C-ops, D2 |

---

*End of the Build Specification v3.1.*
