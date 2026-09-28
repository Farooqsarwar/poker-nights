# Provenance and accepted risks

**Recorded 28 September 2026 · Phase 0 of BUILD_PLAN.md · `HEAD = 7f6f9622`**

This file records where the project's authoritative sources are, which of them could
not be found, and the risks the owner has explicitly accepted. It exists because
Addendum 1 §1 names five source files as the package that decides look, behaviour and
maths, and two of them are missing.

---

## 1. The reference package (P0.2)

Addendum 1 §1 lists the package that ships with the specification:

| File | What it decides | Status |
| :--- | :--- | :--- |
| `Poker_Night_Build_Specification_v3.1.pdf` / `.md` | Behaviour | **Present** — `Poker_Night_Build_Specification_v3.1.md`, verified byte-identical (modulo line endings) to the owner's copy in `docs/` |
| `App redesign project.pdf` | The board — what each screen looks like | **Recovered.** See §1.1 |
| `research/structure_engine.js` + `structure_engine_test.html` | The structure maths, **759 assertions** | **NOT FOUND.** See §1.2 |
| `research/payouts_engine.js` + `payouts_engine_test.html` | The payouts maths, **55 assertions** | **NOT FOUND.** See §1.2 |
| `mockup/index.html` + `mockup/tests.js` | The feel, **145 behaviour tests** | **NOT FOUND.** See §1.2 |

### 1.1 The board — recovered

The board was deleted from the repository in commit `7f6f9622` ("updated code"), the
most recent commit. It was not replaced; only a single-page export,
`App redesign-1.png`, survived in the working tree.

Recovered on 28 September 2026 from two independent sources that agree exactly:

- `git show a9cc4d3a:"App redesign .pdf"`
- `C:\Users\o\Downloads\App redesign .pdf`

Both are 3,772,317 bytes, MD5 `56bae5a63b0d9dddd601ee033024cfd1`. Restored to the
repository root as `App redesign project.pdf`, the name Addendum 1 §1 uses.

**Action:** commit it, so a future `git clean` or a fresh clone cannot lose the source
that decides the look again.

### 1.2 The engines and the mock — not found

Searched on 28 September 2026:

- Every local and remote branch (`farooq`, `firebase`, `main`, `new-implementation`
  and their `origin/` counterparts) — `git ls-tree -r` finds nothing matching
  `research/`, `mockup/` or `*engine*.js`.
- The **entire history of every ref** — `git log --all --diff-filter=A --name-only`
  shows these paths were **never added to this repository at any point**.
- The git stash — empty.
- `C:\Users\o` to depth 6, and a full sweep of `E:\` and `C:\Users`, excluding
  `node_modules`. No `structure_engine*`, no `payouts_engine*.js`, no
  `*_engine_test.html`.
- `C:\Users\o\Downloads`, where the board and the specifications were found.

**Conclusion: the files are not on this machine and never were in this repository.**

### 1.3 What that costs, stated plainly

1. **The spec's own verification gate cannot be run.** 759 structure vectors, 55 payout
   vectors and 145 mock behaviour tests, all with SHA-256 baselines in §A3, are
   unavailable. Addendum 1 makes milestone 1 "all 759 + 55 vectors passing".
2. **The Dart ports' provenance is unverifiable.** It cannot be shown where
   `tournament_engine.dart`, `payouts_engine.dart` or `icm.dart` were ported *from*.
   The previous build plan asserted "the Dart ports came from `research/*.js` —
   correct"; **that claim has no evidence and is withdrawn.**
3. **§G5 row 22's warning cannot be discharged.** The specification warns specifically
   against porting the mock's own stale copies of the engines. Without the files there
   is no way to prove that did not happen. The Dart engines may well be correct — the
   structure work shows real care — but correctness is **asserted, not proven**.
4. **Which source wins for the maths is unresolvable in practice.** Addendum 1 §1 says
   the engines decide the maths and the specification's prose merely explains them
   ("if the prose and the code ever disagree, the code and its tests win"). With no
   code, the prose is all there is — the exact inversion the specification warns about.

### 1.4 Decision C — the owner's answer

**"Try recovery first."** Recovery has now been attempted and has failed for the engines
and the mock. Per BUILD_PLAN §3, a substitute acceptance gate for milestone 1 must
therefore be **agreed in writing with the owner before Phase 2 ends**. Payment is per
milestone on acceptance, so this is a commercial matter, not only a technical one.

The substitute proposed in BUILD_PLAN P2.8 / P3.1 is vectors rebuilt from:

- the worked example in §F1.15 and the step-by-step trace in §F1.16;
- the payout traces in §F2.12;
- the identities in the General Poker Tournament Structuring Framework, which are
  independent of the missing JS and therefore genuinely checkable — notably
  `C / X = N(1 + r + Aq)` (§4 and Appendix), `D0 = X / B0`,
  `T = finish − start − breaks`, and `average live stack = C / (live × BB)`.

This is a **weaker** gate than the original and should be recorded as such.

---

## 2. Accepted risks

### 2.1 OneSignal REST key in the public bundle (decision D — deferred)

`deploy.ps1` passes the OneSignal REST API key as `--dart-define`. Dart defines are
compiled into the JavaScript bundle, so the key is present in `build/web/main.dart.js`,
which is served publicly at `https://poker-night-tools.web.app`.
`lib/services/onesignal_sender.dart` uses it directly as an HTTP auth header.

**Anyone who reads the deployed bundle can send arbitrary push notifications to this
app's entire subscriber base.** `deploy.ps1` is gitignored (`.gitignore:92`), which
protects the repository and does nothing at all about the key in the bundle.

**The owner's decision, 28 September 2026: defer until a server exists.** Not rotating,
not re-architecting. Rotation alone would not help — the next deploy bakes the new key
into the bundle exactly as before — and the trusted relay that would fix it properly
needs a server, which the no-Cloud-Functions constraint rules out.

**Operating constraint while deferred:** ship nothing new that depends on this key, so
the blast radius does not grow. Revisit the moment the no-Cloud-Functions constraint
lifts.

Detection, so the exposure stays visible rather than forgotten:

```powershell
Select-String -Path build\web\main.dart.js -Pattern 'os_v2_app_'
```

### 2.2 Premium cannot be granted server-side

`firestore.rules:1025-1028` has `entitlements/{uid}` as `allow write: if false`, while
the free seat cap at `firestore.rules:631-667` requires `isPremiumUser()` to exceed nine
players. Nothing can write the entitlement document, so **Premium can only be granted by
hand in the Firebase console, and a paying host is hard-capped at nine seats.**

This stays true through Phases 1–5 and is fixed in Phase 6 (P6.3), which moves the gate
to the client and drops the server cap. Recorded here so it is not rediscovered as a bug.

### 2.3 Seat cap becomes client-only in Phase 6

Once the server cap is dropped, a modified client can host unlimited players. Accepted
for a private home-poker product with no real payment. The counter is already documented
as walk-down-able in the rules file itself (`firestore.rules:619-630`).

---

## 3. Test baseline (P0.1)

Recorded after Phase 0's fixes, so every later phase has something to regress against.

**Before Phase 0:** `flutter test` did not complete meaningfully — **the app did not
compile.** `lib/screens/shell/edit_chip_set_screen.dart` called a named parameter
`onReorderItem` that does not exist on `ReorderableListView.builder` in Flutter 3.38.9,
so `flow_f_d_test.dart` and `screen_smoke_test.dart` failed to load and roughly 250
tests never ran. The visible result was 410 passing, 6 failing.

**After Phase 0:** 659 passing, 4 failing.
**After Phase 1 (as re-scoped):** **660 passing, 3 failing** — and all three are the
structure-engine defects listed in §3.1, i.e. everything still red is already assigned
to Phase 2.

Fixed in Phase 0:

| Test | Diagnosis |
| :--- | :--- |
| *(compile)* `edit_chip_set_screen.dart:494` | `onReorderItem` is not a Flutter API. The author invented it while fixing a real off-by-one; the correct fix is `onReorder` plus the standard `newIndex > oldIndex ? newIndex - 1 : newIndex` adjustment, which was missing |
| `icm_test.dart` — every stack is zero | **Stale test, correct engine.** With no live chips there is nothing to weigh anyone's chance by, so `icm.dart`'s `m == 0` branch splits the pool evenly. The old expectation of `0` came from an earlier engine and was worse: it told a host the pot was worth nothing while the money was on the table. Now pinned to `[50.0, 50.0]` |
| `no_real_money_test.dart` — demo grant switchable | **Brittle test, correct code.** The guard exists at `app_provider.dart:326`; `dart format` wrapped the call across two lines and broke a literal substring match. Assertion is now whitespace-tolerant |

### 3.1 Known-red, deferred to Phase 2 with diagnosis

These three are **structure-engine defects, not stale tests**. They live in the code
Phase 2 rewrites (P2.2 fixes the chip-supply equation, P2.3 replaces the growth
derivation), so fixing them now would mean fixing them twice. Left red deliberately, and
listed here so they are not mistaken for new breakage.

| Test | Failure | Phase 2 owner |
| :--- | :--- | :--- |
| `chip_payability_test.dart` — Standard 300 / 9 players is not a bucket of chips | chip count **31**, budget **30** (`maxChipsPerPlayer + 5`). Off by one chip | P2.2 |
| `chip_payability_test.dart` — a level-9 rebuy still contains change | `chipPlanAtLevel` totals **1500** against a `rebuyStack` of **1490**; a rebuy must be worth exactly a starting stack (23-002) | P2.2 |
| `engine_properties_test.dart` — freeze-out output is unchanged when there is no real premium | final BB **3000** against an expected **2400 ± 120**. The risk premium is changing a freeze-out ladder it should leave alone | P2.3 |

### 3.2 Resolved by Phase 1

| Test | Reason |
| :--- | :--- |
| `flow_f_d_test.dart` — F2 SettingsScreen renders sections | Expected a row reading "Admin app tour". P1.6 removed the hosting tour per Addendum 2 correction 5. The assertion is now inverted — it asserts the row is *absent* — and the §F2 DATA rows are asserted alongside it. **Passing** |

---

## 4. Design scheme — frozen 28 September 2026

**Owner's decision, refined 28 September 2026 — the standing rule for all later work:**

| | |
| :--- | :--- |
| **Allowed** | **Layout and flow.** What is on a screen, how it is arranged and ordered, which screens exist, what a flow does, copy, icons, and adding or removing rows, sections and cards — as the documents' flows require |
| **Frozen** | **Theme and component styling.** Palettes, colour tokens, hex values, button styles, and the look of shared components |

So a screen may be rebuilt to match a documented flow; it must be rebuilt **using the
components and colours that already exist**. New screens use the design scheme already
in the codebase and the board (`App redesign project.pdf`); Phase 2's new UI reuses the
existing tokens rather than introducing §B1's.

This reverses BUILD_PLAN decision E ("remove the Appearance picker"), taken earlier the
same day. The reversal is deliberate.

Phase 1 delivered the items that fall on the layout-and-flow side: P1.6 (hosting tour
removal), P1.7 (Settings DATA section), P1.8 (emoji → icons), P1.9 (privacy claim).
P1.1, P1.2, P1.3, P1.4 and P1.5 are theme changes and are **not done**; they are listed
below as known deviations.

### 4.1 Design changes the documents require, and are not implemented

Recorded so the decision can be revisited with the full cost visible. The **Side** column
applies the standing rule above — *theme* items stay frozen, *layout* items are
actionable now.

| # | Source | Required | Today | Side |
| :--- | :--- | :--- | :--- | :--- |
| 1 | §B1 opening line | "**Exactly one look**: black ground, crimson accent, white ink" | Four palettes, user-selectable via Settings → Appearance (`settings_screen.dart`, `_ThemeGrid`) | **Theme** — frozen |
| 2 | §B1 token table | 13 named tokens at exact hex: `bg` `#0A0A0A`, `surface` `#141414`, `surface2` `#1C1C1C`, `border` `rgba(255,255,255,.08)`, `borderStrong` `rgba(255,255,255,.16)`, `red` `#D53032`, `redText` `#F2555A`, `redDim` `rgba(213,48,50,.16)`, `redDanger` `#B23430`, `white`, `muted` `#A6A6AA`, `muted2` `#939399`, `green` `#3FBF6B` | A different 27-field vocabulary (`primary`, `card`, `secondary`, `destructive`, `warning`, …) with different values | **Theme** — frozen |
| 3 | §B1 line 275 | `redText` `#F2555A` for **all red text below 24 px** — eyebrows, LEVEL/ANTE labels, antes in tables, link rows, legal headings. Never `red` at that size | Neither `redText` nor `redDanger` exists. Text reds are derived: `Color.lerp(base, white, 0.40)` | **Theme** — frozen |
| 4 | §B1 | `redDanger` `#B23430`, **fill only** (fails as text/outline at 3.23 : 1) | `destructive` is `#E53935`, used as both fill and text | **Theme** — frozen |
| 5 | §B1, §B4.9, T141 | "**No gold, yellow, amber or second accent anywhere.** A test fails on any yellow pixel" | **The default `red` palette ships `warning: #E65100`** — deep amber — used in 42 places across 17 files. Plus the `darkOrange` palette (`#FF6D00`, `#FFAB40`, `#FFCC80`) and `Colors.yellow[700]` in `coin_shuffle_animation.dart:18` and `coin_animation_widget.dart:128` | **Theme** — frozen. **T141 cannot pass** |
| 6 | §B4 rule 1, §A5 #6 | "No emoji anywhere — not as icons, not in copy" | ~~🏆 🔥 💰 in `profile_screen.dart`~~ | **Layout — DONE.** Replaced with `Icons.emoji_events_outlined` / `local_fire_department_outlined` / `payments_outlined`, each taking the pill's existing colour. Emoji also stripped from the earned-badge strings. `lib/` swept: none remain |
| 7 | Addendum 1 §2 row 2 | F5 chip swatches use ten named colours incl. **Yellow** — the one place yellow is legal, because a swatch shows a real chip | No fixed named palette | **Mixed** — the swatch colours depict real chips rather than app theme, but the change is a new palette constant. Needs a call before it is built |
| 8 | Addendum 2 row 3 | Level change **pulses** the level label and new blinds 2 × 300 ms on every Scoreboard; with reduce-motion, a 3-second `redText` outline instead | Not implemented | **Mixed** — the pulse is behaviour and can be built in Phase 4; the reduce-motion outline needs `redText`, so it will use the existing red until the theme reopens |
| 9 | Addendum 2 row 6 | `Delete account` and `Sign out` use **`redText`** for icon and label; the destructive button in the confirm sheet uses **`redDanger` fill** | Both use `destructiveText` (the derived lift of `#E53935`) | **Theme** — frozen. The rows themselves exist and are correct |
| 10 | §B1 | `green` `#3FBF6B`, and **only** for the LIVE dot, GOING / CHECKED IN / ACTIVE pills and positive P&L | `success` is `#2E7D32` | **Theme** — frozen |
| 11 | §B1 closing line, T102 | Every text node meets WCAG AA against its real background; CI measures it | No contrast gate in CI | **Theme** — frozen |
| 12 | §B3 `AppBottomNav` (N3) | Active item: `redText` icon and label plus a 24 × 2 px crimson bar with a soft glow | Not verified against the board | **Mixed** — the bar's geometry is layout; its colour is theme |

**Consequence for milestone 2.** Addendum 1 makes milestone 2 "Design system components
(Part B) and the shell (Part C)", and BUILD_PLAN §15 gates it on T141/T102 passing. Row 5
alone means **T141 cannot pass while the design is frozen**, so milestone 2 cannot be
accepted on its stated gate. This is a commercial consequence of a design decision, not a
technical blocker, and it needs the owner's acknowledgement in the same way decision C does.

---

## 5. Precedence in force

From Addendum 1 §1, adjusted for what actually exists:

| Question | Decides | Available? |
| :--- | :--- | :--- |
| What a screen **looks like** | `App redesign project.pdf` | **Yes** — recovered, §1.1 |
| What a screen **does** | Build Specification v3.1 + Addenda 1 and 2 | Yes |
| The **maths** | The two reference engines and their vectors | **No** — §1.2. Falls back to Part F's prose, against the specification's own instruction |
| How a flow **feels** | The interactive mock | **No** — §1.2 |
| How the **structure** is created | General Poker Tournament Structuring Framework (owner-supplied, 28 Sep 2026) | Yes. Methodology only; §F1's calibrated constants win where both speak |
