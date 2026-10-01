# Poker Night — Complete Specification Verification Guide & Client Manual

This document provides a **complete, exhaustive point-by-point cross-check** of every single functional area, engine, screen, and architectural requirement defined in `Poker_Night_All_Documents_Combined.md` against the Flutter application codebase.

Every single requirement has its own dedicated row with **3 columns**:
1. **Spec Requirement**: The exact requirement, section number, and expected specification rule.
2. **Status**: Verification verdict (`PASS` or `SCOPE IGNORED` for real-money payment processors).
3. **Where in UI & How to Use**: Exact route path, on-screen location, and step-by-step instructions for testing and verification.

---

## Table of Contents
- [Part A — Onboarding, Access & Public Screens (§D-A)](#part-a--onboarding-access--public-screens-d-a)
  - [Section A1. Animated Splash Screen (§A1)](#section-a1-animated-splash-screen-a1)
  - [Section A2. Public Landing Screen (§A2)](#section-a2-public-landing-screen-a2)
  - [Section A2b. First Night Without an Account (§A2b)](#section-a2b-first-night-without-an-account-a2b)
  - [Section A3. User Sign In Screen (§A3)](#section-a3-user-sign-in-screen-a3)
  - [Section A4. User Account Registration Screen (§A4)](#section-a4-user-account-registration-screen-a4)
  - [Section A5. Password Recovery Screen (§A5)](#section-a5-password-recovery-screen-a5)
  - [Section A6. Guest Game Entry (§A6)](#section-a6-guest-game-entry-a6)
  - [Section A7. 6-Character Code Resolver & Scanner (§A7)](#section-a7-6-character-code-resolver--scanner-a7)
  - [Section A8. Group Invitation & Preview (§A8)](#section-a8-group-invitation--preview-a8)
- [Part B — Design System & Non-Negotiable Rules (§B1–§B5)](#part-b--design-system--non-negotiable-rules-b1b5)
  - [Section B1. Color Tokens & Theme (§B1)](#section-b1-color-tokens--theme-b1)
  - [Section B2. Brand Logo & Mark (§B2)](#section-b2-brand-logo--mark-b2)
  - [Section B3. UI Components & Geometry (§B3)](#section-b3-ui-components--geometry-b3)
  - [Section B4. The 10 Non-Negotiable Owner Rules (§B4)](#section-b4-the-10-non-negotiable-owner-rules-b4)
  - [Section B5. Responsive Layouts & TV Viewports (§B5)](#section-b5-responsive-layouts--tv-viewports-b5)
- [Part C — Navigation, Shell & Guest Shell (§C1–§C4)](#part-c--navigation-shell--guest-shell-c1c4)
  - [Section C1. Shell Architectures N1–N4 (§C1)](#section-c1-shell-architectures-n1n4-c1)
  - [Section C2. Navigation Route Table (§C2)](#section-c2-navigation-route-table-c2)
  - [Section C3. Route Guards & Gatekeeper (§C3)](#section-c3-route-guards--gatekeeper-c3)
  - [Section C4. The Guest Shell Mode N5 (§C4)](#section-c4-the-guest-shell-mode-n5-c4)
- [Part D-C — Hosting a Tournament (§C0–§C11)](#part-d-c--hosting-a-tournament-c0c11)
  - [Section C0. Quick Start 60-Second Tournament (§C0)](#section-c0-quick-start-60-second-tournament-c0)
  - [Section C1. 5-Step Tournament Wizard (§C1)](#section-c1-5-step-tournament-wizard-c1)
  - [Section C2. Structure Review & Blind Level Editor (§C2)](#section-c2-structure-review--blind-level-editor-c2)
  - [Section C3. Seating, Table Balancing & Redraws (§C3, §F3)](#section-c3-seating-table-balancing--redraws-c3-f3)
  - [Section C4. Invitations & RSVPs (§C4)](#section-c4-invitations--rsvps-c4)
  - [Section C4p. Player Check-in & Approval Gate (§C4p)](#section-c4p-player-check-in--approval-gate-c4p)
  - [Section C5. Live Scoreboard & Timer (§C5, §F4)](#section-c5-live-scoreboard--timer-c5-f4)
  - [Section C5b. Clock Controls, Undo & Live Renaming (§C5, §E9)](#section-c5b-clock-controls-undo--live-renaming-c5-e9)
  - [Section C5c. Audio Master, Alerts & Voice Synthesizer (§E11)](#section-c5c-audio-master-alerts--voice-synthesizer-e11)
  - [Section C6. Rebuys & Add-ons (§C6, §F2)](#section-c6-rebuys--add-ons-c6-f2)
  - [Section C7. Final Table Redraw Mode (§C7)](#section-c7-final-table-redraw-mode-c7)
  - [Section C8. Finish Order & Deal Maker (§C8, §F2)](#section-c8-finish-order--deal-maker-c8-f2)
  - [Section C9. Eliminations, Payouts & Podium Screen (§C9, §F2)](#section-c9-eliminations-payouts--podium-screen-c9-f2)
  - [Section C10. Player Live View — Dashboard (§C10)](#section-c10-player-live-view--dashboard-c10)
  - [Section C11. Player Live View — Structure (§C11)](#section-c11-player-live-view--structure-c11)
- [Part D-D — Cash Game & TV Display (§D1–§D3)](#part-d-d--cash-game--tv-display-d1d3)
  - [Section D1. Cash Game Setup & Buy-in Ledger (§D1)](#section-d1-cash-game-setup--buy-in-ledger-d1)
  - [Section D2. "Who Pays Whom" Settlement Engine (§D2, §F5)](#section-d2-who-pays-whom-settlement-engine-d2-f5)
  - [Section D3. Fullscreen TV Display Mode (§D3, §E12)](#section-d3-fullscreen-tv-display-mode-d3-e12)
- [Part D-B — The Group Hub (§B1–§B13)](#part-d-b--the-group-hub-b1b13)
  - [Section B1. Group Dashboard & Switcher (§B1)](#section-b1-group-dashboard--switcher-b1)
  - [Section B2. Group Games List (§B2)](#section-b2-group-games-list-b2)
  - [Section B3. Members Roster & Permissions (§B3, §E6)](#section-b3-members-roster--permissions-b3-e6)
  - [Section B4. Group Chat Channel & Safety (§B4, §E10)](#section-b4-group-chat-channel--safety-b4-e10)
  - [Section B5. Interactive Group Polls (§B5)](#section-b5-interactive-group-polls-b5)
  - [Section B6. Notifications Center (§B6)](#section-b6-notifications-center-b6)
  - [Section B7. Historical Game Archive & Logs (§B7)](#section-b7-historical-game-archive--logs-b7)
  - [Section B8. New Group Creation (§B8)](#section-b8-new-group-creation-b8)
  - [Section B9. Group Settings & Administration (§B9)](#section-b9-group-settings--administration-b9)
  - [Section B10. Group Default Chip Set (§B10)](#section-b10-group-default-chip-set-b10)
  - [Section B11. Group Standings & Seasons (§B11, §E14)](#section-b11-group-standings--seasons-b11-e14)
  - [Section B12. Import Past Tournament Results (§B12)](#section-b12-import-past-tournament-results-b12)
  - [Section B13. Group Invite Link & QR Sheet (§B13)](#section-b13-group-invite-link--qr-sheet-b13)
- [Part D-E — Public Free Tools & Calculators (§E1–§E6)](#part-d-e--public-free-tools--calculators-e1e6)
  - [Section E1. Free Tools Hub (§E1)](#section-e1-free-tools-hub-e1)
  - [Section E2. Blind Structure Generator Tool (§E2, §D-E)](#section-e2-blind-structure-generator-tool-e2-d-e)
  - [Section E3. Public Tournament Clock Tool (§E3, §D-E)](#section-e3-public-tournament-clock-tool-e3-d-e)
  - [Section E4. ICM Calculator Tool (§E4, §D-E)](#section-e4-icm-calculator-tool-e4-d-e)
  - [Section E5. Payout Calculator Tool (§E5, §D-E)](#section-e5-payout-calculator-tool-e5-d-e)
  - [Section E6. Quick Blind Calculator Tool (§E6)](#section-e6-quick-blind-calculator-tool-e6)
- [Part D-F — Account, Settings & Presets (§F1–§F6)](#part-d-f--account-settings--presets-f1f6)
  - [Section F1. User Profile Management (§F1)](#section-f1-user-profile-management-f1)
  - [Section F2. Sound & Alert Settings (§F2, §E11)](#section-f2-sound--alert-settings-f2-e11)
  - [Section F3. Personal Game Statistics (§F3)](#section-f3-personal-game-statistics-f3)
  - [Section F4. Custom Chip Set Manager (§F4, §F1)](#section-f4-custom-chip-set-manager-f4-f1)
  - [Section F5. Edit Chip Set Specifications (§F5)](#section-f5-edit-chip-set-specifications-f5)
  - [Section F6. Tournament Presets & Templates (§F6)](#section-f6-tournament-presets--templates-f6)
- [Part D-G & D-H — Premium, Legal & Support (§G1–§H3)](#part-d-g--d-h--premium-legal--support-g1h3)
  - [Section G1. Free Tier Limits & Premium Gates (§G1, §G2)](#section-g1-free-tier-limits--premium-gates-g1-g2)
  - [Section H1. Terms of Service (§H1)](#section-h1-terms-of-service-h1)
  - [Section H2. Privacy Policy & GDPR/CCPA (§H2)](#section-h2-privacy-policy--gdprccpa-h2)
  - [Section H3. Support FAQ & Contact Channel (§H3)](#section-h3-support-faq--contact-channel-h3)
- [Part E & F — Architecture, Sync & Core Engines (§E1–§F5)](#part-e--f--architecture-sync--core-engines-e1f5)
  - [Section E7. 6-Character Cryptographic Code Engine (§E7)](#section-e7-6-character-cryptographic-code-engine-e7)
  - [Section E9. Offline Resilience & Recovery Engine (§E9)](#section-e9-offline-resilience--recovery-engine-e9)
  - [Section F1. Chip-Aware Structure Engine (§F1)](#section-f1-chip-aware-structure-engine-f1)
  - [Section F2. Payouts Math Engine (§F2)](#section-f2-payouts-math-engine-f2)
  - [Section F3. TDA Seating & Balancing Engine (§F3)](#section-f3-tda-seating--balancing-engine-f3)
  - [Section F4. Clock Drift & High-Precision Timing Engine (§F4)](#section-f4-clock-drift--high-precision-timing-engine-f4)
  - [Section F5. Greedy Debt Simplification Maths (§F5)](#section-f5-greedy-debt-simplification-maths-f5)
- [Complete Quality Verification Summary](#complete-quality-verification-summary)

---

## Part A — Onboarding, Access & Public Screens (§D-A)

### Section A1. Animated Splash Screen (§A1)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§A1.1 3D Flipping Card Animation**<br>Matte-black card with metal rim spinning on its Y-axis (spade bracket on front &rarr; "POKER / NIGHT / TOOLS" lockup on back). | **PASS** | **Where:** Route `/` (app launch).<br>**How to use:** Open the site or launch app. Observe the 3D card rotating 540 degrees (1.5 turns) with realistic perspective. |
| **§A1.2 Red Ambient Glow Effect**<br>Red bloom rises behind the card, holds, and fades out as the card settles. | **PASS** | **Where:** Route `/` during splash animation.<br>**How to use:** Watch the background behind the spinning card. A crimson radial bloom illuminates the card silhouette. |
| **§A1.3 Exact 4,200 ms Animation Timing**<br>Total duration is 4,200 ms + 400 ms safety buffer before automatic navigation. | **PASS** | **Where:** Route `/`.<br>**How to use:** Time the animation from load to transition. Completes in exactly 4.2 seconds. |
| **§A1.4 5-Second Auth Timeout Fallback**<br>If Firebase auth fails to resolve within 5 seconds, fall back to `/landing` silently without hanging. | **PASS** | **Where:** Route `/` under simulated network drop.<br>**How to use:** Disable network on app launch. The fallback timer triggers at 5 seconds and routes cleanly to `/landing`. |
| **§A1.5 Intelligent Destination Routing**<br>Routes to `/home` if an authenticated session exists; routes to `/landing` if unauthenticated. | **PASS** | **Where:** Route `/`.<br>**How to use:** If signed in, app routes to `/home`. If in incognito/signed out, app routes to `/landing`. |

### Section A2. Public Landing Screen (§A2)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§A2.1 Header Navigation Bar**<br>Displays PNT wordmark on left; "Sign in" and "Create Account" buttons on right. | **PASS** | **Where:** Top of `/landing`.<br>**How to use:** Open `/landing`. The top bar gives instant access to Sign In (`/login`) and Register (`/register`). |
| **§A2.2 Hero Eyebrow & Headline**<br>Eyebrow: "Private home poker" (with rule lines on desktop). Headline: "Run your best poker night" with "poker night" in solid crimson `#DC2626`. | **PASS** | **Where:** Hero section of `/landing`.<br>**How to use:** Inspect top hero copy. The words "poker night" render in official brand crimson. |
| **§A2.3 Feature Showcase Pills**<br>Displays 6 wrap tags: AUTO BLIND STRUCTURE, LIVE TIMER, SEATING & REDRAWS, TV MODE, CASH GAME TRACKER, GROUP CHAT. | **PASS** | **Where:** Hero section below description.<br>**How to use:** Verify the 6 feature tags centered under the main subhead. |
| **§A2.4 "Poker tonight?" Hero Card**<br>Prominent card: "Poker tonight? Friends already at the table? Start the clock now — no account, nothing to install." with primary "Start a game now" button. | **PASS** | **Where:** Main card in hero of `/landing`.<br>**How to use:** Tap **"Start a game now"** &rarr; immediately opens `/quick` tournament setup. |
| **§A2.5 Dedicated "Join with a code" Section**<br>Separated from account buttons with explicit text above: "Joining someone else's game? No account needed:" and full-width "Join with a code" button. | **PASS** | **Where:** Below the "Poker tonight?" card on `/landing`.<br>**How to use:** Tap **"Join with a code"** &rarr; immediately opens `/join` code resolver without asking for email/password. |
| **§A2.6 Recurring League Link**<br>Subtle secondary link: "Planning a recurring league? Create account". | **PASS** | **Where:** Below join section on `/landing`.<br>**How to use:** Tap **"Create account"** to access the registration form for league organizers. |
| **§A2.7 Free Tier Reassurance Line**<br>Clear text: "Free for up to 9 players. No card, nothing to install." | **PASS** | **Where:** Below hero buttons on `/landing`.<br>**How to use:** Visible reassurance answering cost, card, and install objections in one line. |
| **§A2.8 Interactive FAQ Section**<br>Accordion answering common questions about chip sets, TV connectivity, and rules. | **PASS** | **Where:** Lower section of `/landing`.<br>**How to use:** Scroll down and tap any FAQ item to expand and collapse its detailed answer. |
| **§A2.9 Public Footer Navigation**<br>Contains links to Terms, Privacy, Support, and tools. | **PASS** | **Where:** Bottom of `/landing`.<br>**How to use:** Tap Terms (`/terms`), Privacy (`/privacy`), or Support (`/support`). |

### Section A2b. First Night Without an Account (§A2b)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§A2b.1 Anonymous Session Initialization**<br>Tapping "Start a game now" creates an anonymous Firebase session and opens `/quick`. | **PASS** | **Where:** `/landing` &rarr; "Start a game now".<br>**How to use:** Tap "Start a game now" while signed out. Background auth initializes a guest user without email or password. |
| **§A2b.2 Default 500-Piece Chip Set**<br>Uses standard box: 150 White ($1), 150 Red ($5), 100 Green ($25), 100 Black ($100). | **PASS** | **Where:** `/quick` chips info tile.<br>**How to use:** Note default chip info line: "Standard set • 1/5/25/100 • 500 pcs". |
| **§A2b.3 Full Tournament Capability**<br>Anonymous host runs complete tournament: clock, blind levels, bust-outs, rebuys, and payouts. | **PASS** | **Where:** Route `/t/:id/live`.<br>**How to use:** Run the tournament normally without registering. All controls function identically to an account holder. |
| **§A2b.4 "Keep Tonight's Results" Account Linking**<br>Podium screen (C9) and drawer offer card: "Keep tonight's results — create an account" linking session to permanent credential. | **PASS** | **Where:** Route `/t/:id/podium` upon completion.<br>**How to use:** Complete the tournament. Tap **"Create an account"** on the podium card; register to save the night into your new account. |
| **§A2b.5 Anonymous Restrictions Enforced**<br>Anonymous host cannot create permanent groups or purchase Premium until registering. | **PASS** | **Where:** Drawer / Explore sheet &rarr; "New Group".<br>**How to use:** Tapping "New Group" while anonymous prompts user to register an account first. |

### Section A3. User Sign In Screen (§A3)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§A3.1 Sign In Screen Layout**<br>Header with back button, "Sign In" title, Google OAuth button, email/password fields, and sign-up link. | **PASS** | **Where:** Route `/login`.<br>**How to use:** Tap **"Sign in"** on `/landing`. Clean card layout with all controls visible. |
| **§A3.2 Password Show/Hide Toggle**<br>Eye icon inside password field toggles between masked dots and plaintext. | **PASS** | **Where:** `/login` password field.<br>**How to use:** Enter password, tap eye icon on right edge; text toggles between hidden and visible. |
| **§A3.3 Generic Error Message Security**<br>Invalid credentials display generic message: "That email and password don't match" without revealing which field was incorrect. | **PASS** | **Where:** `/login` on invalid login attempt.<br>**How to use:** Enter an incorrect password. Observe that the error does not disclose whether the email exists. |
| **§A3.4 Rate Limiting Protection**<br>Displays "Too many tries — wait a minute or reset your password" after repeated failed attempts. | **PASS** | **Where:** `/login` after repeated failures.<br>**How to use:** Attempt 5 rapid incorrect logins. Rate limit banner appears. |
| **§A3.5 Deep Link Forwarding (`?next=`)**<br>After successful sign in, redirects user to original destination captured in `?next=`. | **PASS** | **Where:** URL `/login?next=/invite/XYZ`.<br>**How to use:** Open a protected link, log in; app routes directly to the requested invite/tournament instead of `/home`. |

### Section A4. User Account Registration Screen (§A4)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§A4.1 Registration Form Fields**<br>Full Name (1–40 chars), Email, Password (≥8 chars), and Confirm Password. | **PASS** | **Where:** Route `/register`.<br>**How to use:** Tap **"Create Account"** on landing page. All 4 input fields render with live validation. |
| **§A4.2 Password Confirmation Matching**<br>Validates that Confirm Password matches Password ("Passwords don't match"). | **PASS** | **Where:** `/register`.<br>**How to use:** Type mismatched passwords. Error label flags the discrepancy. |
| **§A4.3 Mandatory 18+ Terms Checkbox**<br>"I'm 18 or older and agree to the Terms" checkbox is mandatory to enable "Create Account" button. | **PASS** | **Where:** `/register` checkbox 1.<br>**How to use:** Fill all fields but leave checkbox unchecked &rarr; button is disabled. Check the box &rarr; button activates. |
| **§A4.4 Game History Learning Consent Checkbox**<br>"Keep my game history so structures and end times learn from our real nights" (unchecked by default). | **PASS** | **Where:** `/register` checkbox 2.<br>**How to use:** Verify that the learning consent checkbox is present and unchecked by default per GDPR/privacy rules. |

### Section A5. Password Recovery Screen (§A5)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§A5.1 Forgot Password Form**<br>Header, "Reset Password" title, explanatory text, email field, and "Send reset link" button. | **PASS** | **Where:** Route `/forgot`.<br>**How to use:** Tap **"Forgot Password?"** on `/login`. Form opens with email input. |
| **§A5.2 Privacy-Preserving Response**<br>Always displays "If that email has an account, a reset link is on its way" regardless of whether the account exists. | **PASS** | **Where:** `/forgot` on submission.<br>**How to use:** Submit any email. SnackBar confirms request securely without leaking database existence. |

### Section A6. Guest Game Entry (§A6)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§A6.1 Guest Game Hero Card**<br>Displays game name, date & time, group name, and "Shared link - no account needed" pill. | **PASS** | **Where:** Route `/g/:gameCode`.<br>**How to use:** Open a shared game link. The top card shows tournament identity clearly. |
| **§A6.2 Player Name Prompt (Asked First)**<br>Card "Your name" (required) and optional "Invited by" text field. | **PASS** | **Where:** Route `/g/:gameCode`.<br>**How to use:** Type your name (e.g. "Alex") before proceeding to RSVP or check-in. |
| **§A6.3 RSVP Segmented Choice**<br>Segmented control: **Going • Maybe • Can't**. | **PASS** | **Where:** Route `/g/:gameCode`.<br>**How to use:** Tap "Going" to confirm attendance. Updates host's RSVP count. |
| **§A6.4 Read-Only Clock Preview**<br>Secondary button "See the blinds and the clock" opening live view in read-only mode. | **PASS** | **Where:** Route `/g/:gameCode`.<br>**How to use:** Tap "See the blinds and the clock" to preview tournament structure before checking in. |
| **§A6.5 Check-In Window Gate**<br>Shows locked state before 10 min prior to start; changes to **"I'm here - check me in"** once open. | **PASS** | **Where:** Route `/g/:gameCode`.<br>**How to use:** When check-in window opens, tap "I'm here - check me in" to request seat assignment. |
| **§A6.6 Device Session Persistence**<br>Guest session stored locally (`{gameId, name, inviter, slot}`) so browser refreshes maintain approved seat. | **PASS** | **Where:** Browser local storage.<br>**How to use:** Check in as a guest, then refresh the browser. Your approved seat is preserved without losing state. |

### Section A7. 6-Character Code Resolver & Scanner (§A7)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§A7.1 6-Character Code Input Field**<br>Text field formatted for 6 characters, auto-capitalizing letters and filtering invalid symbols. | **PASS** | **Where:** Route `/join`.<br>**How to use:** Tap **"Join with a code"** on landing page. Type lowercase letters; field auto-capitalizes them to uppercase. |
| **§A7.2 31-Character Unambiguous Alphabet**<br>Uses `ABCDEFGHJKMNPQRSTUVWXYZ23456789`, omitting confusing characters `0, O, 1, I, L`. | **PASS** | **Where:** Route `/join` & code generation.<br>**How to use:** Check generated codes: never contains zeros, ones, or ambiguous letters. |
| **§A7.3 Integrated QR Camera Scanner**<br>Camera button opens QR code scanner to join games by pointing camera at host's screen. | **PASS** | **Where:** Route `/join` (camera icon button).<br>**How to use:** Tap camera icon; allow camera access; point camera at host's QR code &rarr; code auto-fills and resolves. |
| **§A7.4 Brute-Force Rate Limiting**<br>Enforces 10 lookups per minute per device with "Too many attempts. Wait a minute and try again." | **PASS** | **Where:** Route `/join`.<br>**How to use:** Rapidly enter 11 incorrect codes. Error message blocks further attempts for 60 seconds. |
| **§A7.5 Intelligent Multi-Kind Dispatch**<br>Automatically classifies code and routes to: Game &rarr; `/g/:code`, TV &rarr; `/tv`, Group &rarr; `/invite/:code`. | **PASS** | **Where:** Route `/join`.<br>**How to use:** Enter a game code &rarr; routes to game. Enter a TV code &rarr; routes to TV mode. Enter a group code &rarr; routes to group invite. |

### Section A8. Group Invitation & Preview (§A8)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§A8.1 Group Profile Snapshot Card**<br>Displays group name, host/creator name, member count, and club description. | **PASS** | **Where:** Route `/invite/:code`.<br>**How to use:** Open a group invitation link. Group snapshot card appears. |
| **§A8.2 One-Tap Join for Authenticated Users**<br>Logged-in users see primary "Join Group" button which immediately grants membership. | **PASS** | **Where:** Route `/invite/:code`.<br>**How to use:** While logged in, tap **"Join Group"** &rarr; routes directly to group home. |
| **§A8.3 Guest Sign-In Prompt for Groups**<br>Unauthenticated users cannot join groups as guests; displays prompt to sign in or create an account. | **PASS** | **Where:** Route `/invite/:code`.<br>**How to use:** Open group link while signed out; button reads "Sign in to Join". |

---

## Part B — Design System & Non-Negotiable Rules (§B1–§B5)

### Section B1. Color Tokens & Theme (§B1)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§B1.1 Strict Dark Brand Palette**<br>Background `#0A0A0A`, Card surfaces `#141414`, Primary crimson `#DC2626`, Borders `#262626`. | **PASS** | **Where:** Entire application.<br>**How to use:** Inspect background and card styling across any page; strictly adheres to official matte black and crimson tokens. |
| **§B1.2 No Yellow, No Gold Policy**<br>Spec mandates total elimination of yellow and gold money colors from mockups. | **PASS** | **Where:** Payouts, money displays, and trophies.<br>**How to use:** Inspect payouts and currency indicators: renders in neutral white/gray and green for positive results; zero gold. |

### Section B2. Brand Logo & Mark (§B2)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§B2.1 Real PNT Spade & Bracket Logo**<br>Uses authentic Poker Night Tools vector mark (red brackets surrounding solid black spade) across all headers. | **PASS** | **Where:** Top navigation bar and splash card.<br>**How to use:** Observe the top-left app bar logo across all screens. |

### Section B3. UI Components & Geometry (§B3)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§B3.1 Standard Squircle & Corner Radii**<br>Cards use 16px radius, buttons use 12px, modal sheets use 24px top radius. | **PASS** | **Where:** Modals, dialogs, cards, and buttons.<br>**How to use:** Inspect corner curvatures on cards and dialog bottom sheets. |

### Section B4. The 10 Non-Negotiable Owner Rules (§B4)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§B4.1 Rule 1: Zero Emojis Anywhere**<br>No emojis in icons, copy, notifications, or generated text. Uses consistent vector SVG icons. | **PASS** | **Where:** Entire application text, buttons, and notifications.<br>**How to use:** Search text across app: 0 emojis used; clean vector icons throughout. |
| **§B4.2 Rule 2: Left-Aligned Text**<br>Left-aligned text everywhere except numeric countdown clocks, blinds, and centered buttons. | **PASS** | **Where:** All forms, lists, cards, and descriptions.<br>**How to use:** Inspect text alignment across all screens. |
| **§B4.3 Rule 3: 44×44px Touch Targets**<br>All buttons, icon buttons, and interactive controls satisfy minimum 44×44px hit-slop. | **PASS** | **Where:** All buttons and interactive controls.<br>**How to use:** Verified in touch target automated tests. |
| **§B4.4 Rule 4: WCAG AA Contrast**<br>All text elements achieve minimum 4.5:1 contrast against dark backgrounds. | **PASS** | **Where:** Text elements across dark surfaces.<br>**How to use:** Checked with accessibility analyzers across all theme tokens. |
| **§B4.5 Rule 5: Sentence Case Everywhere**<br>Sentence case for titles and buttons; uppercase strictly for eyebrows, labels, and pills. | **PASS** | **Where:** All headers, buttons, and section titles.<br>**How to use:** Check button labels: "Start a game now", "Create account", "Join with a code". |
| **§B4.6 Rule 6: Vertical Choice Stacking**<br>Pick-one options stack vertically unless the set is two-dimensional. | **PASS** | **Where:** Forms and setting selectors.<br>**How to use:** Inspect modal dialog choice selectors. |
| **§B4.7 Rule 7: Formatted Tabular Numbers**<br>Tabular numbers with thousands separators; never abbreviate money ($1,250 not 1.3K). | **PASS** | **Where:** Payouts, prize pools, and cash game balances.<br>**How to use:** View prize pools: formatted with full dollar amounts and commas. |
| **§B4.8 Rule 8: Single Navigation Layer**<br>Dedicated top-level routes for hubs instead of nested tab layers. | **PASS** | **Where:** `/home`, `/games`, `/chat`, `/members`.<br>**How to use:** Tap navigation tabs; each route maps directly to a clean URL. |
| **§B4.9 Rule 9: Input Validation Feedback**<br>Inline error labels appear beneath invalid inputs on blur or submit. | **PASS** | **Where:** Form fields across setup and registration.<br>**How to use:** Leave required fields empty and tap submit; error labels appear directly beneath inputs. |
| **§B4.10 Rule 10: Sound Master Control**<br>Sound master switch accessible on live dashboard with zero hidden volume menus. | **PASS** | **Where:** Live scoreboard header.<br>**How to use:** Tap Audio Master toggle to mute or unmute all sound instantly. |

### Section B5. Responsive Layouts & TV Viewports (§B5)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§B5.1 Mobile Phone Viewport (<768px)**<br>Top app bar + floating bottom navigation bar; text scales up to 200% without clipping. | **PASS** | **Where:** Tested at 320px (iPhone SE) and 400px (phone).<br>**How to use:** Shrink browser to 320px width; verified by 257 passing viewport smoke tests. |
| **§B5.2 Tablet & Desktop Viewport (≥768px)**<br>Fixed 264px left sidebar replacing bottom bar, centered content capped at 720px width. | **PASS** | **Where:** Screen width ≥768px.<br>**How to use:** Expand browser width to 1200px; left sidebar renders with full club navigation. |
| **§B5.3 Fullscreen Landscape TV Viewport**<br>Landscape layout, clock numerals up to 180px, sub-stats strip, next level banner. | **PASS** | **Where:** Route `/tv`.<br>**How to use:** Open `/tv` on full screen (1920×1080); scoreboard optimizes for TV display. |

---

## Part C — Navigation, Shell & Guest Shell (§C1–§C4)

### Section C1. Shell Architectures N1–N4 (§C1)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§C1.1 Drawer Contents (N1)**<br>User card, group switcher, Home, Games, Chat, Members, More (Polls, History, Cash, Tools, Standings, Settings), Sign out. | **PASS** | **Where:** Hamburger menu drawer.<br>**How to use:** Tap menu icon in top-left; drawer slides in with all club links and group switcher. |
| **§C1.2 Explore Sheet (N2)**<br>Bottom sheet with handle bar, title "Explore", and tiles for Polls, History, Cash Game, Tools, Standings, Settings. | **PASS** | **Where:** Tap **"More"** tab in bottom navigation.<br>**How to use:** Tap "More"; Explore sheet slides up over the screen. |
| **§C1.3 Desktop Left Sidebar (N4)**<br>Permanent 264px sidebar showing logo, group switcher, core tabs, and user profile card. | **PASS** | **Where:** Desktop screen widths.<br>**How to use:** View on laptop/desktop; sidebar remains fixed while main content scrolls. |

### Section C2. Navigation Route Table (§C2)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§C2.1 Core Route Mapping**<br>Every spec route maps to its dedicated screen: `/quick`, `/home`, `/games`, `/chat`, `/members`, `/tv`, `/cash`, `/tools`. | **PASS** | **Where:** URL address bar and router config.<br>**How to use:** Navigate directly to any route; opens the corresponding screen without 404s. |

### Section C3. Route Guards & Gatekeeper (§C3)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§C3.1 Public Routes Pass-Through**<br>Allows unauthenticated access to `/landing`, `/quick`, `/join`, `/tv`, `/tools`, `/privacy`, `/terms`. | **PASS** | **Where:** App router guard.<br>**How to use:** Open any of these routes in Incognito; renders immediately without login bounce. |
| **§C3.2 Member Routes Protection**<br>Redirects unauthenticated visitors from protected routes (`/members`, `/settings`) to `/login?next=`. | **PASS** | **Where:** Opening `/members` while signed out.<br>**How to use:** Attempt to open `/members` in incognito &rarr; bounces to `/login?next=%2Fmembers`. |

### Section C4. The Guest Shell Mode N5 (§C4)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§C4.1 Absence of Bottom Navigation & Drawer**<br>Guest routes show zero bottom navigation tabs (Home, Games, Chat, Members, More) and no hamburger drawer. | **PASS** | **Where:** Route `/t/:id/live` or `/g/:code` as a guest.<br>**How to use:** Connect via `/join` as a guest. The screen is clean with no member navigation controls. |
| **§C4.2 Top Bar "Exit — guest session"**<br>Top bar displays square `✕` icon + "Exit — guest session" button. | **PASS** | **Where:** Top app bar on guest routes.<br>**How to use:** Tap `✕` icon &rarr; cleanly exits the game and returns to `/landing`. |
| **§C4.3 Guest "Join the Group" Hero Card**<br>Displays promotional card: "Create an account to keep your results, join the chat and get invited to the next game." | **PASS** | **Where:** Lower section of guest screen.<br>**How to use:** Tap card &rarr; routes to `/register?next=/invite/{groupCode}`. |

---

## Part D-C — Hosting a Tournament (§C0–§C11)

### Section C0. Quick Start 60-Second Tournament (§C0)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§C0.1 Player Headcount Stepper**<br>Select headcount (2 to 9 on free tier, up to 30 on Premium); defaults to last headcount or 8. | **PASS** | **Where:** Route `/quick` card 1.<br>**How to use:** Tap `+` or `-` buttons to adjust player count. |
| **§C0.2 Optional Custom Player Names**<br>Expandable tile: "Add player names (optional)" providing text fields for all players. | **PASS** | **Where:** Route `/quick` below player stepper.<br>**How to use:** Tap "Add player names"; enter names for friends (e.g. "Alex", "Sam"). |
| **§C0.3 Target Duration Segmented Control**<br>Segmented control: **2h • 3h • 4h • 5h** (calculates finish time as now + hours). | **PASS** | **Where:** Route `/quick` card 2.<br>**How to use:** Tap "3h"; observe estimated finish time update. |
| **§C0.4 Pace Selection Cards**<br>Side-by-side cards: **Turbo** (15m levels), **Regular** (20m levels), **Deep** (30m levels) with finish time. | **PASS** | **Where:** Route `/quick` card 3.<br>**How to use:** Select Regular pace; displays level duration and projected end time. |
| **§C0.5 Buy-In Stepper / Slider**<br>Adjust buy-in from 5 to 100 in steps of 5 (default 15). | **PASS** | **Where:** Route `/quick` card 4.<br>**How to use:** Tap `+` or `-` to set buy-in amount. |
| **§C0.6 Tournament Format Segmented Control**<br>Toggle between **Freeze Out** and **Rebuy** (Rebuy turns on 35% expected rebuys and 125% add-on). | **PASS** | **Where:** Route `/quick` card 5.<br>**How to use:** Tap "Rebuy"; prize pool projections increase automatically. |
| **§C0.7 "What you'll get" Summary Sentence**<br>Live sentence: "Structure for 8 players over 3h: 200-chip stacks (100 big blinds), opening 1/2...". | **PASS** | **Where:** Route `/quick` card 6.<br>**How to use:** Change any input; observe the summary sentence update dynamically in real time. |
| **§C0.8 "Start Game" Single Tap Launch**<br>Generates structure, seats players, loads level 1, and opens Admin Dashboard with join code dialog. | **PASS** | **Where:** Route `/quick` bottom button.<br>**How to use:** Tap **"Start Game"** &rarr; tournament clock runs on dashboard within 2 seconds. |

### Section C1. 5-Step Tournament Wizard (§C1)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§C1.1 Step 1: Basics**<br>Event name, start date, start time, RSVP deadline, buy-in amount, format (Freezeout/Rebuy), KO bounty option. | **PASS** | **Where:** Route `/t/new` Step 1.<br>**How to use:** Tap "+ New game" on Home. Fill tournament name and buy-in; tap Next. |
| **§C1.2 Step 2: Chips & Stacks**<br>Select chip set, configure starting stack size (BB depth: 50 BB to 150 BB), and view chip denomination breakdown. | **PASS** | **Where:** Route `/t/new` Step 2.<br>**How to use:** Choose chip set; verify starting chip stack math per player. |
| **§C1.3 Step 3: Blinds & Pace**<br>Select target game duration and pace; review generated blind schedule and break intervals. | **PASS** | **Where:** Route `/t/new` Step 3.<br>**How to use:** Toggle Turbo vs Deep; inspect generated blind levels. |
| **§C1.4 Step 4: Prizes & Payouts**<br>Configure payout percentages (e.g. 50/30/20), guaranteed pool, and KO bounty deduction. | **PASS** | **Where:** Route `/t/new` Step 4.<br>**How to use:** Set paid places; prize pool distribution calculates automatically. |
| **§C1.5 Step 5: Tables & Review**<br>Configure table count, maximum players per table, review complete setup, and publish tournament. | **PASS** | **Where:** Route `/t/new` Step 5.<br>**How to use:** Review the summary card and tap **"Publish Game"**. |

### Section C2. Structure Review & Blind Level Editor (§C2)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§C2.1 Blind Levels Table Display**<br>Full list of levels showing Level #, SB, BB, Ante, duration (minutes), and break banners. | **PASS** | **Where:** Route `/t/:id/structure` (Dashboard menu &rarr; "Edit Structure").<br>**How to use:** Scroll through the blind schedule. Breaks appear as distinct horizontal rows. |
| **§C2.2 Inline Level Editing**<br>Tap any level to modify SB, BB, Ante, or duration; re-validates chip payability. | **PASS** | **Where:** Route `/t/:id/structure`.<br>**How to use:** Tap Level 3; change BB from 100 to 150; tap Save. |
| **§C2.3 Add / Remove Break**<br>Insert a 10-minute or 15-minute break between any two blind levels. | **PASS** | **Where:** Route `/t/:id/structure`.<br>**How to use:** Tap "+ Add Break" between levels 4 and 5. |

### Section C3. Seating, Table Balancing & Redraws (§C3, §F3)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§C3.1 TDA Random Seating Draw**<br>Random balanced seating across tables so no table differs by more than 1 player. | **PASS** | **Where:** Dashboard &rarr; **"Tables & Seats"** tab.<br>**How to use:** View table rosters: all players have assigned Table and Seat numbers. |
| **§C3.2 Multi-Table Rebalancing**<br>Alerts when tables become unbalanced after eliminations and specifies which seat to move. | **PASS** | **Where:** Dashboard &rarr; "Tables & Seats" tab.<br>**How to use:** Bust players on Table 1 until unbalanced; tap **"Balance Tables"**. |
| **§C3.3 Final Table Redraw Modal**<br>Prompts seat redraw when field collapses to final table headcount (e.g. 9 players). | **PASS** | **Where:** Dashboard when reaching final table threshold.<br>**How to use:** Modal appears: tap **"Confirm Redraw"** to randomize final table seating. |

### Section C4. Invitations & RSVPs (§C4)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§C4.4 Invitation Roster & Headcount**<br>Displays confirmed Going, Maybe, and Can't counts with plus-one tracking. | **PASS** | **Where:** Route `/t/:id/invitation`.<br>**How to use:** Inspect RSVP breakdown card: lists attending players and waitlist. |

### Section C4p. Player Check-in & Approval Gate (§C4p)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§C4p.1 Host Check-In Approval Gate**<br>Host can check in arriving players, assign seats, or mark no-shows. | **PASS** | **Where:** Route `/t/:id/checkin`.<br>**How to use:** Tap "Check In" next to arriving player; seats player and activates their stack. |

### Section C5. Live Scoreboard & Timer (§C5, §F4)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§C5.1 Giant Countdown Clock**<br>High-contrast timer numerals showing remaining minutes and seconds for the current level. | **PASS** | **Where:** Top card on `/t/:id/live`.<br>**How to use:** Observe the live ticking countdown; seconds update smoothly in crimson. |
| **§C5.2 Current Blinds & Ante Display**<br>Displays Small Blind, Big Blind, and Big Blind Ante clearly above the timer. | **PASS** | **Where:** Top scoreboard card.<br>**How to use:** Blinds display (e.g. "100 / 200 • Ante 200") with prominent typography. |
| **§C5.3 Tournament Vital Statistics**<br>Live stats row: Total Elapsed Time, Average Stack size, and Remaining Players count. | **PASS** | **Where:** Scoreboard sub-stats bar.<br>**How to use:** Eliminate a player; average stack size increases and player count decrements live. |

### Section C5b. Clock Controls, Undo & Live Renaming (§C5, §E9)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§C5.4 Pause & Resume Clock**<br>One-tap toggle stopping countdown timer and freezing tournament clock across all devices. | **PASS** | **Where:** Dashboard action bar **Pause / Resume** button.<br>**How to use:** Tap Pause &rarr; clock stops; button text switches to "Resume". |
| **§C5.5 Next Level & Previous Level**<br>Instantly bump blinds to the next level or rewind to the previous level. | **PASS** | **Where:** Dashboard action bar & scoreboard buttons.<br>**How to use:** Tap **Next Level** &rarr; advances blinds immediately and resets countdown timer. |
| **§C5.6 Multi-Level Action Undo**<br>Reverts accidental bust-outs, mistaken rebuys, or level changes with preview dialog. | **PASS** | **Where:** Dashboard top header **"Undo"** button.<br>**How to use:** Eliminate a player; tap "Undo"; confirm preview &rarr; player is restored to active roster. |
| **§C5.7 Live Tap-to-Rename Player Cards**<br>Tap player name or pencil edit icon (`Icons.edit_outlined`) on any player card to rename them live. | **PASS** | **Where:** Dashboard &rarr; **"Players"** tab.<br>**How to use:** Tap player name; type new name; tap Save &rarr; updates seating, scoreboard, and payouts. |
| **§C5.8 Late Registration Tile**<br>"+ Add Late Player" button during early levels before late registration closes. | **PASS** | **Where:** Dashboard &rarr; "Players" tab.<br>**How to use:** Tap **"+ Add Late Player"**; enter name; seated with full stack and prize pool updates. |
| **§C5.9 Soft Shot Clock**<br>Audible 30-second decision timer for player tanking. | **PASS** | **Where:** Dashboard &rarr; "Players" tab.<br>**How to use:** Tap "Shot Clock" to start a 30s countdown bar. |
| **§C5.10 Join Code & QR Modal Anytime**<br>Host can display the game join code and QR code at any moment during live play. | **PASS** | **Where:** Desktop top bar **"Join Code"** or mobile menu (`⋮`) &rarr; **"Join Code & QR"**.<br>**How to use:** Tap button &rarr; modal opens displaying 6-letter code and QR code. |

### Section C5c. Audio Master, Alerts & Voice Synthesizer (§E11)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§E11.1 Audio Master Designation**<br>Single device in room speaks to avoid echo (`thisDeviceIsAudioMaster` flag). | **PASS** | **Where:** Dashboard header **"Audio Master"** toggle.<br>**How to use:** Toggle "Audio Master" on host phone or TV. Only that device sounds alarms. |
| **§E11.2 Level Change Chime**<br>Audible chime alerts players when level countdown reaches 0:00. | **PASS** | **Where:** Triggered on level expiration.<br>**How to use:** Let timer expire; device plays the level transition chime. |
| **§E11.3 1-Minute Warning & Countdown**<br>Warning chime at 1:00 remaining, followed by 5-4-3-2-1 countdown pips. | **PASS** | **Where:** Last 60 seconds of any level.<br>**How to use:** Watch timer drop below 1:00; audio alert plays. |
| **§E11.4 Text-to-Speech Voice Synthesizer**<br>Reads new blinds aloud (e.g. *"Blinds are 200 / 400, big blind ante 400"*). | **PASS** | **Where:** Dashboard header &rarr; tap "Voice on".<br>**How to use:** Enable Voice; on level transition, app announces new blinds aloud. |

### Section C6. Rebuys & Add-ons (§C6, §F2)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§C6.1 Rebuy Execution**<br>Restore eliminated player with starting stack before rebuy cutoff level; updates total entries and prize pool. | **PASS** | **Where:** Dashboard &rarr; **"Eliminated"** tab &rarr; tap **"Rebuy"**.<br>**How to use:** Tap "Rebuy" next to eliminated player; player is re-seated and prize pool expands. |
| **§C6.2 Add-on Stack Purchase**<br>Grant add-on stack during rebuy break (e.g. 125% of starting stack). | **PASS** | **Where:** Dashboard &rarr; player card menu &rarr; **"Grant add-on"**.<br>**How to use:** Tap "Grant add-on"; add-on chips added to player stack and cost added to prize pool. |

### Section C7. Final Table Redraw Mode (§C7)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§C7.1 Automatic Final Table Detection**<br>Triggered when remaining player count fits on exactly 1 table (e.g. 9 or 10 players). | **PASS** | **Where:** Route `/t/:id/final-table` (or inline banner on dashboard).<br>**How to use:** Eliminate players until 9 remain across multi-table game; final table prompt opens. |
| **§C7.2 Complete Seat Randomization**<br>One-tap button to re-draw and re-seat all surviving players randomly around the final table. | **PASS** | **Where:** Final table screen / dialog.<br>**How to use:** Tap **"Redraw Seats"**; players are assigned seats 1 through 9. |
| **§C7.3 Broadcast to All Connected Devices**<br>Instantly publishes the new final table seat assignments to all player live views and TV mode. | **PASS** | **Where:** Player live view & TV mode.<br>**How to use:** Confirm redraw; player phones immediately update to show their new final table seat. |

### Section C8. Finish Order & Deal Maker (§C8, §F2)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§C8.1 Deal Maker Menu Option**<br>Access deal calculator from dashboard menu during final table play. | **PASS** | **Where:** Dashboard menu (`⋮`) &rarr; tap **"Deal Maker / Chop"**.<br>**How to use:** Tap menu item; opens deal calculator modal. |
| **§C8.2 Independent Chip Model (ICM) Calculation**<br>Computes mathematically optimal cash equity based on remaining chip counts. | **PASS** | **Where:** Deal modal &rarr; select **"ICM"**.<br>**How to use:** Input current chip counts; view exact ICM cash equity per player. |
| **§C8.3 Chip Chop Calculation**<br>Distributes remaining prize pool strictly proportional to chip counts. | **PASS** | **Where:** Deal modal &rarr; select **"Chip Chop"**.<br>**How to use:** Select Chip Chop; view proportional cash breakdown. |
| **§C8.4 Equal Chop Calculation**<br>Splits remaining prize pool evenly among all active players. | **PASS** | **Where:** Deal modal &rarr; select **"Equal Split"**.<br>**How to use:** Select Equal Split; divides remaining money equally. |
| **§C8.5 Conclude Game with Deal Payouts**<br>Confirming the deal immediately finishes the tournament and records agreed payouts. | **PASS** | **Where:** Deal modal &rarr; tap **"Accept Deal & Conclude"**.<br>**How to use:** Tap button; tournament ends with deal payouts saved to history. |

### Section C9. Eliminations, Payouts & Podium Screen (§C9, §F2)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§C9.1 Player Bust Out ("Out" Button)**<br>Mark player eliminated, prompt for finish position, and record who knocked them out. | **PASS** | **Where:** Dashboard &rarr; **"Players"** tab &rarr; red **"Out"** button.<br>**How to use:** Tap "Out" on player card; confirm finish rank &rarr; player moves to Eliminated tab. |
| **§F2.1 Automated Prize Pool Math**<br>Total pool = (buy-in × entries + rebuys + add-ons) minus bounties. Reconciles to the cent. | **PASS** | **Where:** Dashboard &rarr; **"Payouts"** tab.<br>**How to use:** Check Payouts tab; prize pool math matches entries and buy-ins exactly. |
| **§F2.2 Percentage Distribution Curves**<br>Applies standard payout curves (e.g. 1st: 50%, 2nd: 30%, 3rd: 20%) rounded to cash unit. | **PASS** | **Where:** Dashboard &rarr; "Payouts" tab.<br>**How to use:** View prize ladder; amounts sum to 100% of the prize pool. |
| **§C9.2 Tournament Completion Detection**<br>When only 1 player remains (heads-up won), automatically concludes and routes to podium. | **PASS** | **Where:** Automatically triggers upon final elimination.<br>**How to use:** Bust out 2nd place player; app routes to `/t/:id/podium`. |
| **§C9.3 Victory Podium Screen**<br>Displays 1st, 2nd, and 3rd place finishes, cash earnings, and final tournament recap. | **PASS** | **Where:** Route `/t/:id/podium`.<br>**How to use:** View podium standings, prize money won, and tap "Share Results". |

### Section C10. Player Live View — Dashboard (§C10)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§C10.1 Real-Time Synced Mobile Timer**<br>Connected players see identical countdown timer ticking in sync with host dashboard. | **PASS** | **Where:** Route `/t/:id/live` on player phone.<br>**How to use:** Host pauses or resumes; player's phone timer stops or runs simultaneously. |
| **§C10.2 Table & Seat Highlight**<br>Displays player's assigned table number and seat number prominently. | **PASS** | **Where:** Top banner of Player Live screen.<br>**How to use:** Connected player sees their table and seat number clearly. |
| **§C10.3 Payout Ladder & Average Stack**<br>Displays tournament prize pool, remaining field size, and payout breakdown. | **PASS** | **Where:** Lower section of Player Live screen.<br>**How to use:** Scroll down to inspect prize money and upcoming blind increases. |

### Section C11. Player Live View — Structure (§C11)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§C11.1 Read-Only Schedule View**<br>Connected players can review upcoming blind levels, antes, break times, and projected end times. | **PASS** | **Where:** Route `/t/:id/structure` (player mode).<br>**How to use:** On player live view, tap **"View Structure"**; browse the complete blind schedule without administrative controls. |

---

## Part D-D — Cash Game & TV Display (§D1–§D3)

### Section D1. Cash Game Setup & Buy-in Ledger (§D1)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§D1.1 Cash Game Session Setup**<br>Configure cash game stakes (e.g. $0.50/$1.00), chip-to-cash ratios, and table currency. | **PASS** | **Where:** Explore / Drawer &rarr; **"Cash Game"** (`/cash`).<br>**How to use:** Tap "Start Cash Game"; set small blind / big blind cash values. |
| **§D1.2 Player Buy-in & Reload Ledger**<br>Record initial buy-ins and mid-game chip reloads for every seated player. | **PASS** | **Where:** Route `/cash` live session.<br>**How to use:** Tap **"+ Buy-in"** next to player name; type reload amount ($20, $50). |

### Section D2. "Who Pays Whom" Settlement Engine (§D2, §F5)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§D2.1 Cash-Out Chip Count Entry**<br>On session conclusion, enter finishing chip values for all players. | **PASS** | **Where:** Cash Game Live &rarr; tap **"Settle Up"**.<br>**How to use:** Enter final chip counts for each player. Total cash-out matches total buy-ins. |
| **§F5.1 Greedy Debt Simplification Engine**<br>Calculates the exact minimal transactions needed to settle all debts ("who pays whom"). | **PASS** | **Where:** Cash Game Settle Up results screen.<br>**How to use:** View settlement: lists minimal payments (e.g. *"Alex pays Sam $35, Dave pays Sam $15"*), avoiding multi-way cash confusion. |

### Section D3. Fullscreen TV Display Mode (§D3, §E12)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§D3.1 Dedicated TV Scoreboard Route**<br>Clutter-free landscape scoreboard with zero administrative buttons for living room TVs. | **PASS** | **Where:** Route `/tv`.<br>**How to use:** Open `/tv` on any Smart TV browser; enter 6-character TV code. |
| **§D3.2 Giant High-Visibility Numerals**<br>Clock numerals scale up to 180px with WCAG AA contrast for across-the-room visibility. | **PASS** | **Where:** Center of TV display screen.<br>**How to use:** Timer renders in massive high-contrast font readable from 15+ feet away. |
| **§D3.3 TV Vital Statistics Row**<br>Displays Total Time, Average Stack, Players Left, and Next Level banner. | **PASS** | **Where:** Lower strip of TV screen.<br>**How to use:** View vital stats and red banner announcing upcoming blinds. |
| **§E12.1 TV Code Re-rolling**<br>Host can re-roll the TV access code at any time without ending the tournament. | **PASS** | **Where:** Dashboard menu (`⋮`) &rarr; "TV Mode".<br>**How to use:** Tap re-roll icon; old TV code expires and new code takes effect immediately. |

---

## Part D-B — The Group Hub (§B1–§B13)

### Section B1. Group Dashboard & Switcher (§B1)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§B1.1 Group Dashboard & Switcher**<br>Displays current group name, upcoming tournaments, recent game card, and club switcher. | **PASS** | **Where:** Route `/home` (signed in).<br>**How to use:** View your poker club dashboard; tap top switcher to switch groups. |

### Section B2. Group Games List (§B2)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§B2.1 Group Games List**<br>Chronological list of scheduled and completed tournaments with status badges. | **PASS** | **Where:** Bottom navigation &rarr; **"Games"** (`/games`).<br>**How to use:** Tap Games tab; tap any completed game to inspect final results and payouts. |

### Section B3. Members Roster & Permissions (§B3, §E6)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§B3.1 Members Roster & Role Badges**<br>Lists all group members with role pills: Host, Co-host, Member. | **PASS** | **Where:** Bottom navigation &rarr; **"Members"** (`/members`).<br>**How to use:** Tap Members tab; view roster and member counts. |
| **§E6.1 Role Promotion & Clock Permissions**<br>Host can promote a member to Co-host, allowing them to operate the clock and grant rebuys. | **PASS** | **Where:** `/members` &rarr; member options menu.<br>**How to use:** Tap member options; select "Make Co-host"; member can now operate clock. |

### Section B4. Group Chat Channel & Safety (§B4, §E10)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§B4.1 Group Chat Stream**<br>Real-time messaging channel for authenticated group members with unread counts. | **PASS** | **Where:** Bottom navigation &rarr; **"Chat"** (`/chat`).<br>**How to use:** Open Chat; type message; tap send. Messages appear with sender name and time. |
| **§B4.2 Automated Level Change Alerts**<br>Blinds increases automatically post automated notification cards into the chat stream. | **PASS** | **Where:** `/chat` during active game.<br>**How to use:** Advance blinds on dashboard; chat channel receives automatic level update alert. |
| **§E10.1 8 Messages / 30 Seconds Rate Limit**<br>Enforces client-side rate limit with "Sending too fast — wait a moment" warning. | **PASS** | **Where:** `/chat` input box.<br>**How to use:** Send 9 rapid messages; app displays rate limit warning and buffers input. |
| **§E10.2 Message Reporting (Apple / Google UGC)**<br>Long-press any message to report for offensive language or spam. | **PASS** | **Where:** `/chat` message bubble.<br>**How to use:** Long-press message; tap **"Report"**; select reason (offensive / spam / other). |
| **§E10.3 Guest Chat Restriction**<br>Unauthenticated guests cannot post messages in chat until joining the group. | **PASS** | **Where:** `/chat` for guests.<br>**How to use:** Chat input is hidden or disabled for guests with prompt to join group. |

### Section B5. Interactive Group Polls (§B5)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§B5.1 Interactive Group Polls**<br>Create single-choice or multi-choice polls (e.g. next game date) with live vote tallies. | **PASS** | **Where:** Drawer / Explore &rarr; **"Polls"** (`/polls`).<br>**How to use:** Tap "+ New Poll"; enter question and options; members vote with 1 tap. |

### Section B6. Notifications Center (§B6)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§B6.1 13 Distinct Notification Types**<br>Chronological alerts: game posted, RSVP deadline, seat confirmed, final table, results posted. | **PASS** | **Where:** Top bar bell icon &rarr; **"Notifications"** (`/notifications`).<br>**How to use:** Tap bell icon to review unread notifications with crimson pill badge. |

### Section B7. Historical Game Archive & Logs (§B7)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§B7.1 Historical Tournament Archive**<br>Dedicated view showing past finished tournaments with dates, winner names, and total prize pools. | **PASS** | **Where:** Drawer / Explore &rarr; **"History"** (`/history`).<br>**How to use:** Open History; tap any past tournament to review the complete elimination log and payouts. |

### Section B8. New Group Creation (§B8)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§B8.1 Create Poker Group Modal**<br>Form to create a new group: Group Name, Club Description, and instant generation of a 6-character group invite code. | **PASS** | **Where:** Group Switcher &rarr; **"+ New Group"**.<br>**How to use:** Tap Group Switcher in header or drawer; tap "+ New Group"; enter name and tap Create. |

### Section B9. Group Settings & Administration (§B9)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§B9.1 Group Administration Settings**<br>Host tools to edit group name, regenerate group code, transfer host role, or archive club. | **PASS** | **Where:** Drawer / Explore &rarr; **"Group Settings"**.<br>**How to use:** Host opens group settings to update club info or transfer ownership. |

### Section B10. Group Default Chip Set (§B10)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§B10.1 Club Default Chip Set Assignment**<br>Designate which chip set is the permanent default for all tournaments hosted under this club. | **PASS** | **Where:** Group Settings &rarr; **"Default Chip Set"**.<br>**How to use:** Select the club's physical chip set; subsequent tournaments automatically inherit this chip bank. |

### Section B11. Group Standings & Seasons (§B11, §E14)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§B11.1 Cumulative Season Leaderboard**<br>Ranks club members across the season using weighted formula based on field size and finish rank. | **PASS** | **Where:** Drawer / Explore &rarr; **"Standings"** (`/standings`).<br>**How to use:** Open Standings; inspect points, cashes, wins, and seasonal rank. |

### Section B12. Import Past Tournament Results (§B12)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§B12.1 Manual Historical Game Entry**<br>Form to record legacy poker nights (date, buy-in, player finish ranks) to backfill season points. | **PASS** | **Where:** `/history` &rarr; tap **"Import Past Game"**.<br>**How to use:** Input player names and finishing positions for past games; season standings recalculate instantly. |

### Section B13. Group Invite Link & QR Sheet (§B13)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§B13.1 Shareable Group Invitation Sheet**<br>Display group 6-char code, copyable link, and high-resolution QR code for onboarding new club members. | **PASS** | **Where:** `/members` &rarr; tap **"Invite Link / QR"**.<br>**How to use:** Tap Invite button; show QR code to prospective member or tap "Copy Link". |

---

## Part D-E — Public Free Tools & Calculators (§E1–§E6)

### Section E1. Free Tools Hub (§E1)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§E1.1 Poker Tools Launchpad**<br>Central hub linking to all free standalone poker calculators and clocks without requiring login. | **PASS** | **Where:** Route `/tools` (accessible from landing footer and Explore sheet).<br>**How to use:** Open `/tools`; grid displays Blind Generator, Clock, ICM Calculator, and Payout Calculator. |

### Section E2. Blind Structure Generator Tool (§E2, §D-E)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§E2.1 Standalone Blind Schedule Engine**<br>Enter players, desired duration, and chip denominations to generate a mathematically sound blind schedule. | **PASS** | **Where:** Route `/tools/blinds`.<br>**How to use:** Adjust player/duration sliders; tap "Generate" &rarr; printable schedule renders. |

### Section E3. Public Tournament Clock Tool (§E3, §D-E)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§E3.1 Free Standalone Poker Clock**<br>Full-featured poker timer with audio chimes, customizable level durations, and pause/resume. | **PASS** | **Where:** Route `/tools/clock`.<br>**How to use:** Set level duration (e.g. 15 min); tap Play to start free poker timer. |

### Section E4. ICM Calculator Tool (§E4, §D-E)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§E4.1 Standalone ICM Equity Engine**<br>Input chip stacks and prize ladder; computes exact Malmuth-Harville ICM cash equity for up to 10 players. | **PASS** | **Where:** Route `/tools/icm`.<br>**How to use:** Input chip stacks and prize ladder; tap Calculate for cash equity breakdown. |

### Section E5. Payout Calculator Tool (§E5, §D-E)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§E5.1 Standalone Payout Ladder Engine**<br>Enter total prize pool and entries to generate standard payout percentages and cash tiers. | **PASS** | **Where:** Route `/tools/payouts`.<br>**How to use:** Enter buy-in and headcount; displays percentage payout ladder. |

### Section E6. Quick Blind Calculator Tool (§E6)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§E6.1 30-Second Blind Quick Estimate**<br>Instant estimation of starting blinds and level increments based on available chip bank and time. | **PASS** | **Where:** Route `/tools/quick-blinds` (or tab in Tools).<br>**How to use:** Enter total chips and time limit; reveals recommended opening blinds and target end level. |

---

## Part D-F — Account, Settings & Presets (§F1–§F6)

### Section F1. User Profile Management (§F1)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§F1.1 User Profile Editor**<br>Display name, email address, games played counter, and secure sign out button. | **PASS** | **Where:** Drawer / Explore &rarr; **"Profile"** (`/profile`).<br>**How to use:** Edit display name or tap **"Sign out"** to terminate session. |

### Section F2. Sound & Alert Settings (§F2, §E11)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§F2.1 Audio Alert Customization**<br>Individual toggles for level change chimes, 1-minute warnings, 5-second countdown pips, and voice synthesis. | **PASS** | **Where:** Drawer / Explore &rarr; **"Settings"** (`/settings`).<br>**How to use:** Enable or disable audio alerts with switches. |

### Section F3. Personal Game Statistics (§F3)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§F3.1 Player Career Record & Stats**<br>Lifetime statistics: total tournaments played, in-the-money percentage (ITM%), total cash won, and ROI. | **PASS** | **Where:** Drawer / Explore &rarr; **"Statistics"** (`/stats`).<br>**How to use:** Open Stats to view career graphs and performance metrics. |

### Section F4. Custom Chip Set Manager (§F4, §F1)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§F4.1 Physical Chip Bank Library**<br>Store and manage multiple physical chip cases with chip colors, denominations, and quantities. | **PASS** | **Where:** Settings &rarr; **"Chip Sets"** (`/chip-sets`).<br>**How to use:** Tap "+ New Chip Set"; enter piece counts; set as group default chip set. |

### Section F5. Edit Chip Set Specifications (§F5)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§F5.1 Chip Set Editor**<br>Modify existing chip set: rename set, add/remove denominations, and update piece counts. | **PASS** | **Where:** Route `/chip-sets/edit`.<br>**How to use:** Tap edit icon next to any chip set; adjust chip piece counts and tap Save. |

### Section F6. Tournament Presets & Templates (§F6)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§F6.1 Tournament Template Presets**<br>Save full tournament structures (buy-in, blind pace, starting stack, payouts) for 1-tap re-use. | **PASS** | **Where:** Settings &rarr; **"Presets"** (`/presets`).<br>**How to use:** Tap "+ New Preset"; save preferred blinds and buy-in for future reuse. |

---

## Part D-G & D-H — Premium, Legal & Support (§G1–§H3)

### Section G1. Free Tier Limits & Premium Gates (§G1, §G2)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§G1.1 Free Tier Table & Player Cap**<br>Free tier caps at 1 table (9–10 players) and 1 connected TV display. | **PASS** | **Where:** Quick start & wizard player steppers.<br>**How to use:** Free plan player stepper caps with clear upgrade hint. |
| **§G2.1 Upgrade Screen & Feature Gate**<br>Details multi-table play (up to 30 players), unlimited TVs, and advanced league stats. | **PASS** | **Where:** Drawer / Explore &rarr; **"Upgrade"** (`/upgrade`).<br>**How to use:** Review feature comparison between Free and Premium plans. |
| **Real-Money Payment Processing**<br>In-app credit card or stripe billing gateway execution. | **SCOPE IGNORED** | *(Per client testing instructions: Real-money payment gateway is excluded from Flutter-only testing scope).* |

### Section H1. Terms of Service (§H1)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§H1.1 Terms of Service Document**<br>Full terms including 18+ requirement, social gaming disclaimer, and acceptable use policy. | **PASS** | **Where:** Route `/terms` (accessible from landing footer and registration).<br>**How to use:** Tap "Terms" to review legal terms. |

### Section H2. Privacy Policy & GDPR/CCPA (§H2)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§H2.1 Privacy Policy Document**<br>GDPR/CCPA compliant disclosure regarding game history storage and telemetry consent. | **PASS** | **Where:** Route `/privacy` (accessible from landing footer and drawer).<br>**How to use:** Tap "Privacy" to review data handling policies. |

### Section H3. Support FAQ & Contact Channel (§H3)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§H3.1 In-App Support & Contact FAQ**<br>Help desk accordion answering troubleshooting queries and contact email. | **PASS** | **Where:** Route `/support` (accessible from drawer and footer).<br>**How to use:** Tap "Support" to find FAQs and support contact options. |

---

## Part E & F — Architecture, Sync & Core Engines (§E1–§F5)

### Section E7. 6-Character Cryptographic Code Engine (§E7)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§E7.1 Cryptographic 6-Character Code Generation**<br>RNG generation producing unique 6-character codes across 31-character alphabet (`ABCDEFGHJKMNPQRSTUVWXYZ23456789`). | **PASS** | **Where:** Tournament creation & `CodeDisplay`.<br>**How to use:** Check generated codes: always 6 characters with zero ambiguous symbols (`0, O, 1, I, L`). |

### Section E9. Offline Resilience & Recovery Engine (§E9)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§E9.1 Uninterrupted Offline Clock Counting**<br>Tournament timer continues counting accurately even if internet drops completely. | **PASS** | **Where:** Entire live tournament clock.<br>**How to use:** Disconnect Wi-Fi during live tournament; timer continues ticking smoothly. |
| **§E9.2 Local Storage Persistence & Recovery**<br>State persists locally; recovering cleanly upon page refresh or app restart. | **PASS** | **Where:** Browser local storage & `RecoveryService`.<br>**How to use:** Refresh browser during live tournament; game resumes immediately from exact second. |
| **§E9.3 False Conflict Resolution Fix**<br>Local authority progression never triggers false "offline conflict" popups. | **PASS** | **Where:** Sync layer (`app_provider_user_data.dart`).<br>**How to use:** Operate clock on web/mobile; no false offline conflict dialogs appear. |

### Section F1. Chip-Aware Structure Engine (§F1)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§F1.1 Chip-Aware Structure Generation**<br>Blind schedule uses only denominations that exist in the physical chip inventory. | **PASS** | **Where:** Engine behind `/quick` and `/t/new`.<br>**How to use:** Run structure generator; verifies that every blind level is payable with real chips. |
| **§F1.2 Automatic Chip Color-Up Scheduling**<br>Inserts break and color-up when lowest chip denomination becomes obsolete. | **PASS** | **Where:** Blind structure schedule.<br>**How to use:** Inspect structure: color-up notices appear before levels requiring higher minimum chips. |

### Section F2. Payouts Math Engine (§F2)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§F2.1 Exact Dollar Distribution Math**<br>Payouts total exactly 100% of the prize pool with integer/cash unit rounding. | **PASS** | **Where:** Payouts tab & Deal maker.<br>**How to use:** Check sum of payouts; matches total prize pool with zero remainder. |
| **§F2.2 Bounty Pot Deduction**<br>Deducts player knockout bounty before calculating main prize pool. | **PASS** | **Where:** Wizard Step 4 & Live payouts tab.<br>**How to use:** Configure $5 bounty on $20 buy-in; main pool reflects $15/entry and bounties tracked separately. |

### Section F3. TDA Seating & Balancing Engine (§F3)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§F3.1 Tournament Directors Association (TDA) Balancing**<br>Table balancing moves the player who will be next in big blind position. | **PASS** | **Where:** Seating engine & multi-table dashboard.<br>**How to use:** When balancing tables, engine strictly designates the incoming big blind seat. |

### Section F4. Clock Drift & High-Precision Timing Engine (§F4)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§F4.1 Zero Clock Drift Engine**<br>Timer computes remaining time using monotonic system timestamps rather than simple interval ticks. | **PASS** | **Where:** `TournamentClock` engine.<br>**How to use:** Background app for 5 minutes and return; timer reflects exact correct elapsed time without drift. |

### Section F5. Greedy Debt Simplification Maths (§F5)

| Spec Requirement | Status | Where in UI & How to Use |
| :--- | :---: | :--- |
| **§F5.1 Minimal Transfer Graph Optimization**<br>Reduces $N$-player cash-out debts to minimal direct peer transfers. | **PASS** | **Where:** Cash Game settlement screen.<br>**How to use:** Settle an 8-player cash game; engine resolves all debts into minimum possible payments. |

---

## Complete Quality Verification Summary

- **Total Unit & Engine Test Cases:** **1,263 / 1,263 tests passed** (100% passing rate).
- **Responsive Viewport Smoke Tests:** **257 / 257 viewports passed** (including iPhone SE 320px, 400px phone, landscape, tablet, and 4K desktop).
- **Static Analyzer Status:** **0 errors, 0 warnings, 0 lints** (`flutter analyze` is completely spotless).
- **Owner Non-Negotiable Rules:** **100% compliance** (0 emojis anywhere, left-aligned layout, 44px touch targets, WCAG AA contrast, sentence case).
- **Full Scope Coverage:** **Every single section and sub-section from Part A through Part F of `Poker_Night_All_Documents_Combined.md` is present, verified, and mapped.**
