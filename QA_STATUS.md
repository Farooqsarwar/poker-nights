# QA Status — Poker Night

Traceability for **POKER NIGHT — COMPLETE QA TEST CASES** against the build at
commit `2ae37775`.

**Read this before running the plan.** Roughly 45 of its cases cannot pass, and
almost none of those are defects — they are commercial decisions nobody has
made yet, or a feature that was never specified. Running the plan cold produces
a failure report that makes the build look far worse than it is.

Automated coverage behind the claims below: **164 tests passing**,
`flutter analyze` at 37 issues / 0 errors, release web build succeeding.

---

## Summary

| Category | Cases | Meaning |
|---|---|---|
| ✅ Expected to pass | ~180 | Built and covered |
| 🔵 Needs a server | ~25 | No backend exists. Not a defect |
| 🔴 Feature does not exist | 18 | Section 12 — never specified |
| ⚠️ Contradicts a decision | 5 | Deliberate, measured, documented |
| 🟡 Partial | ~6 | Works, but not the way the case words it |

---

## 🔴 Section 12 — tests a feature that has never existed

**PN-DPAY-001 → 018, and the acceptance-checklist lines about dummy buy-ins.**

The plan tests **players paying their tournament entry through the app**:
*"Dummy buy-in payment → Player marked paid"*, plus dummy rebuy, re-entry and
add-on payments.

That feature does not exist and no specification ever asked for it. There is no
`hasPaid`, no `markPaid`, nothing. Buy-ins are **accounting entries** that feed
the prize pool — the money changes hands at the table, in cash, as it does at
every home game.

What *was* built is a dummy **Premium subscription** paywall, which is what
addendum §3 describes. Different feature entirely.

**Action:** ask the client whether he wants in-app buy-in collection. If yes it
is significant new scope, with its own refund and dispute surface. If no, this
section should be rewritten to test the Premium upgrade flow
(`/upgrade` → `/checkout`).

---

## 🔵 Needs a server that does not exist

Every one is marked Critical. None can pass.

| Cases | What they require |
|---|---|
| PN-SEC-001 → 006 | "Server rejects request", "Server ignores manipulated client flag" |
| PN-SEC-010 → 019 | Server-side financial and authorization enforcement |
| PN-PAY-015 | "Server calculation authoritative" |
| PN-NEG-001, 002, 005, 013, 014 | Server validation of client input |

Addendum §7 and acceptance criteria 12–15 require this. The app talks directly
to Firebase with no application server. Achieving it needs Cloud Functions on
the Blaze plan, or a small backend — **neither scoped nor funded**.

Worth stating precisely, because it is often overstated: **private financial
data IS already excluded server-side.** It lives in a separate admin-only
document and `firestore.rules` enforces access, and rules run on Google's
servers. So PN-SEC-010 → 014 are closer to passing than the rest. What cannot
be enforced today is **Premium tier checking** and **server-side calculation**.

---

## ⚠️ Contradicts a decision made deliberately

**PN-SS-002** (below 50 BB) · **PN-SS-009** (Turbo 40–60) · **PN-SS-010**
(Fast 60–80)

The opening-depth floor is **80 BB**. Lowering it to 40 was tried and reverted
after measurement: with Standard 300 at 9 players over 4 hours the solver
stopped targeting ~136 BB and took a **65 BB stack that was down to 16 BB by
level three**. Nothing asked for that — it merely became legal and won. Five
tests caught it.

Turbo and Fast are unreachable for a better reason: **the shortest duration the
product offers is 3 hours**, and 3 hours of play properly wants ~110 BB. Those
bands describe events this app does not schedule. The addendum itself calls
them *"style guidance, never hard constraints"*.

**PN-SS-009 → 012** also say *"Turbo selected"* / *"Deep selected"*, implying a
style **picker**. There isn't one and no specification asked for one — style is
derived from duration and inventory, and reported in plain language
(`TournamentStructure.styleNote`), which is what addendum §2 actually requires.

---

## 🟡 Partial — works, but not as worded

| Case | Reality |
|---|---|
| **PN-NEG-008** "10th player → Rejected" | It is a **notice**, not a block. Refusing to check in somebody standing at the table is worse product than telling the host the night now needs two tables; §3 keeps core operation free. One line to change if the client wants a hard block |
| **PN-PREM-001 → 016** | The Premium *tier* works and gates read correctly, but the entitlement is device-local. "Premium account recognition" passes locally and means nothing server-side |
| **PN-UI-019** horizontal timer | Not yet redesigned — Phase 10 |
| **PN-UI-006** icon family | Not chosen. No asset supplied |
| **PN-UI-008** red vertical-bar texture | No asset supplied |
| **PN-SEAT-004/005** multi-table | Works, and is *not* currently gated to Premium |

---

## ✅ Recently built — should pass

| Area | Cases | Commit |
|---|---|---|
| Breaks, incl. placement, custom duration, auto break state | PN-BRK-001 → 019 | `cbf51f1c`, `715485b8`, `2ae37775` |
| AI rebuy cutoff, manual authoritative | PN-RB-001 → 004, 014 | `715485b8` |
| Plain-language style explanation | PN-SS-005 | `715485b8` |
| Voice: 1-minute + next blinds, 5-4-3-2-1, level start | PN-VOICE-001 → 004 | `715485b8` |
| Multiple payout options | PN-PAY-012 → 014 | `cbf51f1c` |
| Organizer cost 10% default, >20% rejected | PN-SET-019/021, PN-PAY-006/009 | `c24a2e36` |
| Free 9-player limit surfaced | PN-FREE-004/005, PN-GRP-007/008 | `2ae37775` |
| Locked head-count distinct from Expected | PN-CI-003/007 | `cfd361e2` |
| Manual level edits marked and protected | PN-CH-009/010, PN-NEG-007 | `cfd361e2` |
| Every live action timestamped | PN-LA-001 → 006 | `c24a2e36` |

---

## Recommended next steps

1. **Resolve §12 with the client** — in-app buy-in payments, or rewrite the
   section against the Premium flow.
2. **Split the checklist in three** before testing: *can pass now*, *needs the
   server decision*, *feature does not exist*.
3. **Get a decision on the backend.** It gates ~25 Critical cases and five
   acceptance-checklist lines. Until then those are permanent failures.
4. **PN-NEG-008** — confirm whether the 10th player is a notice or a hard block.
5. Supply the **timer reference image** (§12 "matching reference") and choose an
   **icon family**; four UI cases cannot pass without them.
