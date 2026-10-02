# Poker Night — Client Acceptance Checklist

Tick each line as you check it in the app. References: `Board` = flow PNG in
`spec_boards/<mobile|desktop>/` · `Card` = annotated card
(`spec_boards/<mobile|desktop>/cards/<ID>_spec_mapped.png`, or click in
`spec_boards/MASTER_SPEC_MAP.html` with the Mobile/Laptop toggle — screenshots are exact
widget renders) · Detail = §5 entry in `SPEC_VERIFICATION_REPORT.md` with the 30-second verification steps.

**Flows:** A Onboarding (8 screens) · B Group Hub (7) · C Hosting & Clock (11) · D Cash & TV (3) ·
E Free Tools (6) · F Account/Premium/Legal (11). Total **46 screens · 84 requirements**.

## FLOW A — Onboarding & Access (`FLOW_A_ONBOARDING_SPEC_MAP.png`)

- [ ] [01_01·1] §A1 Brand logo — real spade + wordmark on Splash (Card `01_01`)
- [ ] [01_01·2] §A1 Cold-start routing — logged-out→Landing, logged-in→Home
- [ ] [01_02·1] §A2b Anonymous Quick Play — host with no account (Card `01_02`)
- [ ] [01_02·2] §A2 Code/QR entry — 6-char box + scanner on Landing
- [ ] [01_02·3] §A2 Tools shortcut — Landing links to free calculators
- [ ] [01_03·1] §A3 Firebase + Google sign-in, persistent session (Card `01_03`)
- [ ] [01_03·2] §A3 Forgot-password link sends reset email
- [ ] [01_04·1] §A4 Profile creation — name/email/avatar/password (Card `01_04`)
- [ ] [01_04·2] §A4 Terms gate — registration blocked until Terms accepted
- [ ] [01_05·1] §A5 Reset engine — validated, throttled reset email (Card `01_05`)
- [ ] [01_06·1] §A6 Guest name-only entry (Card `01_06`)
- [ ] [01_06·2] §C4 Guest shell N5 — no host drawers/billing/groups
- [ ] [01_06·3] §A6 Seating on host approval
- [ ] [01_07·1] §E7 Crockford 6-char resolver, no I/O/0/1 (Card `01_07`)
- [ ] [01_07·2] §A7 Camera QR scanner resolves game/group/TV
- [ ] [01_08·1] §A8 Club preview — name, owner, live game (Card `01_08`)
- [ ] [01_08·2] §B13 One-tap join, appears in roster

## FLOW B — Group Hub & Social (`FLOW_B_GROUP_HUB_SPEC_MAP.png`)

- [ ] [02_01·1] §B1 Club switcher dropdown (Card `02_01`)
- [ ] [02_01·2] §C0 Quick-Start hero CTA on Home
- [ ] [02_01·3] §B1 5-tab glass navigation
- [ ] [02_02·1] §B2 Live + upcoming tables list (Card `02_02`)
- [ ] [02_02·2] §B2 Host launcher (wizard / cash)
- [ ] [02_03·1] §B3 Roles — Host/Admin/Member + stats (Card `02_03`)
- [ ] [02_03·2] §B13 Invite link + QR generator
- [ ] [02_04·1] §B4 Realtime chat stream (Card `02_04`)
- [ ] [02_04·2] §E10 Auto banners — levels, rebuys, bust-outs
- [ ] [02_05·1] §B5 Scheduling polls — dates/buy-ins (Card `02_05`)
- [ ] [02_05·2] §B5 Live tally + auto-schedule on close
- [ ] [02_06·1] §B6 Activity feed — RSVPs, starts, announcements (Card `02_06`)
- [ ] [02_06·2] §B6 OneSignal push on Android/iOS/Web
- [ ] [02_07·1] §B7 Game archive — date/winner/pot (Card `02_07`)
- [ ] [02_07·2] §B7 Elimination ledger — order, levels, prizes

## FLOW C — Hosting & Live Clock (`FLOW_C_HOSTING_SPEC_MAP.png`)

- [ ] [03_00·1] §C0 4-question 60-second setup (Card `03_00`)
- [ ] [03_00·2] §C0/§F1 Auto chip structure for target hours
- [ ] [03_00·3] §C0/§C5 Instant clock launch
- [ ] [03_01·1] §C1 5-step wizard flow (Card `03_01`)
- [ ] [03_01·2] §F1 Chip-aware auto structure + duration
- [ ] [03_01·3] §C1 Bounty/ante/break toggles
- [ ] [03_02·1] §C2 Level grid — SB/BB/ante/duration/breaks (Card `03_02`)
- [ ] [03_02·2] §C2 Edit/reorder + live finish recalculation
- [ ] [03_03·1] §C4 RSVP — Going/Maybe/Declined + headcount (Card `03_03`)
- [ ] [03_03·2] §F3 TDA random seats, tables differ by ≤1
- [ ] [03_04·1] §C4p Arrival toggle (Card `03_04`)
- [ ] [03_04·2] §C4p Buy-in paid tracker
- [ ] [03_05·1] §C5 TV clock — blinds/ante/elapsed/average (Card `03_05`)
- [ ] [03_05·2] §C5b Pause/resume/next/±1m/sound
- [ ] [03_05·3] §C5 Bust-out drawer with undo
- [ ] [03_06·1] §C6 Pool grows live on rebuys/add-ons (Card `03_06`)
- [ ] [03_06·2] §C6 Counter + undo, cutoff lock enforced
- [ ] [03_07·1] §C5 SVG countdown ring + next-level preview (Card `03_07`)
- [ ] [03_07·2] §C7 Live leaderboard — stacks/ranks/BB/alive
- [ ] [03_07·3] §C8 Declare Winner DISABLED while >2 remain
- [ ] [03_07·4] §C5b Host drawer — speed/pause/mute
- [ ] [03_08·1] §C8 Drag-to-reorder finish, prizes recalc (Card `03_08`)
- [ ] [03_08·2] §F2 ICM chop (Malmuth-Harville) from stacks
- [ ] [03_09·1] §C9 1st/2nd/3rd podium + prizes (Card `03_09`)
- [ ] [03_09·2] §B11 Season sync + share card
- [ ] [03_10·1] §C10 My seat/stack/BB/rank card (Card `03_10`)
- [ ] [03_10·2] §C11 Read-only schedule tab

## FLOW D — Cash Game & TV (`FLOW_D_CASH_TV_SPEC_MAP.png`)

- [ ] [04_01·1] §D1 Stakes SB/BB + min/max buy-in (Card `04_01`)
- [ ] [04_01·2] §D1 Settlement toggle
- [ ] [04_02·1] §D2 Ledger integrity — money in play verified (Card `04_02`)
- [ ] [04_02·2] §F5 Who-Pays-Whom minimal settlement
- [ ] [04_03·1] §D3 16:9 fullscreen scoreboard, no login (Card `04_03`)
- [ ] [04_03·2] §E11 Chimes + spoken announcements (1-min/level/break)

## FLOW E — Public Free Tools, no login (`FLOW_E_TOOLS_SPEC_MAP.png`)

- [ ] [05_01·1] §E1 All 6 tools visible logged-out (Card `05_01`)
- [ ] [05_02·1] §E2 Ladder fits your physical chips (Card `05_02`)
- [ ] [05_03·1] §E3 Standalone timer + bells (Card `05_03`)
- [ ] [05_04·1] §E4 ICM $ split from stacks (Card `05_04`)
- [ ] [05_05·1] §E5 Tiered payouts for 2–100+ (Card `05_05`)
- [ ] [05_06·1] §E6 Players + hours → blinds in 30 s (Card `05_06`)

## FLOW F — Account, Premium & Legal (`FLOW_F_PROFILE_SETTINGS_SPEC_MAP.png`)

- [ ] [06_01·1] §F1 Identity + avatar + clubs (Card `06_01`)
- [ ] [06_01·2] §F1 Career P/L + podiums match History
- [ ] [06_02·1] §F2 Volume + voice toggle + chimes (Card `06_02`)
- [ ] [06_02·2] §B1 Theme / deck switcher re-skins app
- [ ] [06_03·1] §F3 Avg finish, KOs, ITM%, history (Card `06_03`)
- [ ] [06_04·1] §F4 Saved chip-box inventory (Card `06_04`)
- [ ] [06_05·1] §F5 Colour/value/quantity editor, duplicates rejected (Card `06_05`)
- [ ] [06_06·1] §F6 One-tap templates, e.g. Friday Freezeout (Card `06_06`)
- [ ] [07_01·1] §G1 Free vs Pro matrix (Card `07_01`)
- [ ] [07_02·1] §G2 Plans + 7-day trial unlock (Card `07_02`)
- [ ] [08_01·1] §H2 GDPR/CCPA privacy text (Card `08_01`)
- [ ] [08_02·1] §H1 Home-game disclaimer, no real-money gambling (Card `08_02`)
- [ ] [08_03·1] §H3 FAQ + crash-recovery guide + contact (Card `08_03`)

---

**Sign-off.** All boxes ticked except (list any): _______________________________________________

Name: ____________________ Date: __________ Signature: __________
