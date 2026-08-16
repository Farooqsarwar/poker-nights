# Poker Night — User Flow Documentation (MVP v2.0)

Client review document — cross-checked against the current source (`lib/screens/**`, `lib/widgets/**`).

Every screen and its key elements are listed as rows. Columns:

| Screen Name | Description | Current Issue | Client Description | Media |
| --- | --- | --- | --- | --- |

- **Current Issue** — blank (to be filled by the client / QA).
- **Client Description** — blank (for the client's own notes or approved copy).
- **Media** — placeholder describing which screenshot, wireframe or visual is needed.

---

## 1. Onboarding & Auth Flow

Covers first-time entry, account creation, sign-in, password recovery, and the legal/support screens an unauthenticated visitor may land on.

| Screen Name | Description | Current Issue | Client Description | Media |
| --- | --- | --- | --- | --- |
| Splash — launch | Branded launch screen on the plain black background (no felt texture): Poker Night logo, wordmark shown, size 160. | | | Screenshot needed: splash state |
| Splash — animation | Logo animates in: scale 0.8 → 1 over 500 ms (elastic ease-out) with a 400 ms fade. | | | See attached wireframe |
| Splash — auto-route | After a fixed 2-second timer the app routes to the Landing page; any saved session/game state is restored alongside. | | | See attached wireframe |
| Landing — layout | Marketing page on the felt-table background with four sections: header, hero, feature highlights and footer; padding scales between mobile and desktop breakpoints. | | | Screenshot needed: hero + feature sections |
| Landing — guest CTA | Main call-to-action reads "Join a game as guest" (routes to the Join screen); sign-in / create-account actions are also offered. | | | Screenshot needed: landing CTAs |
| Sign In — form | Card (max 420 px) titled "Sign In": Email address and Password fields (password shows an eye toggle to reveal/hide). | | | Screenshot needed: login form |
| Sign In — layout | Desktop shows the logo left of the card in two columns; mobile stacks a large logo above the same card. Back arrow (top-left) returns to Landing. | | | Screenshot needed: desktop split layout |
| Sign In — validation | Inline errors: "Enter a valid email address." (email format), "Password must be at least 8 characters.", and "Incorrect email or password." on failed sign-in. | | | Wireframe of error states |
| Sign In — submit & loading | Primary "Sign In" button; on submit the button shows a small spinner for ~600 ms, then routes to the destination (`/home` by default, or the page the user was originally trying to reach). | | | See attached wireframe |
| Sign In — secondary links | "Forgot Password?" link above the button routes to Reset Password; below the button: "Don't have an account? · Create Account". | | | See attached wireframe |
| Sign In — demo credentials | Selectable demo hint under the form: "Demo: daniel@example.com / password123" (email rendered in mono type). | | | See attached wireframe |
| Create Account — form | Card titled "Create Account": Full Name (auto-capitalized words), Email address, Password and Confirm Password (both with eye toggles). | | | Screenshot needed: registration form |
| Create Account — validation | "Name must be at least 2 characters.", "Passwords do not match.", and "An account already exists for that email." on registration conflicts. | | | Wireframe of error states |
| Create Account — submit & link | "Create Account" button with the same spinner behavior; "Already have an account? · Sign In" switch below. | | | See attached wireframe |
| Reset Password — form | Card titled "Reset Password": single Email address field. | | | Screenshot needed: forgot-password screen |
| Reset Password — outcomes | Validation "Enter a valid email address."; if no account matches: "No account found for that email."; success state "A password reset link has been sent to <email>." and button "Send reset link". Link "Back to Sign In". | | | See attached wireframe |
| Auth — shared polish | Auth card uses card surface + border + glow shadow, fade-in + upward slide animation; desktop/mobile auto-adapts. | | | See attached wireframe |
| Privacy Policy | Static legal screen titled "Privacy Policy", effective date August 1, 2026, max width 720 px; eight numbered sections (information collected, usage, groups & sharing, user controls, security, children, policy changes, contact). Data stored locally at first; results/prizes visible to the host unless published. Contact support@pokernight.app. | | | See attached wireframe |
| Terms of Service | Static legal screen titled "Terms of Service", effective date August 1, 2026, max width 720 px; eight numbered sections incl. 18+ requirement, "as is" service, data ownership (deletable from Settings), acceptable use, IP, liability cap, changes, contact. | | | See attached wireframe |
| Support — FAQ | Screen titled "Support" with "Need help?" headline, a five-question FAQ (start a tournament, restore a lost game, track cash games, result privacy, report a bug) as cards, an intro referencing support@pokernight.app, and a Back button. | | | Screenshot needed: FAQ list |

---

## 2. Join & Guest Flow

Covers how a new (unregistered) attendee joins a tournament before creating an account.

| Screen Name | Description | Current Issue | Client Description | Media |
| --- | --- | --- | --- | --- |
| Join — entry | "Join Game" card (max 400 px): subtitle "Enter code or scan QR to join." with a centered, uppercase, mono-spaced code field (max 8 chars, "CODE" hint). | | | Screenshot needed: join screen |
| Join — submit | Primary "Enter Game" button submits the code; below a divider an "OR" label precedes a secondary "Scan QR Code" button. Back arrow returns to Landing. | | | Screenshot needed: join screen states |
| Join — code routing | `enterGameCode` resolves the code: a TV/game-code routes to TV Mode; otherwise the code routes into the Guest Flow (and sets the game as current). | | | See attached wireframe |
| Join — errors | Empty code: "Please enter a game code."; unknown code: "Game not found. Check the code and try again." (errors clear as the user types). | | | Screenshot needed: code error state |
| Join — QR scan | Full-screen black scanner (mobile_scanner) titled "Scan Game QR Code" (camera/black scaffold); scans once and pulls the code out of a URL if present (`code=` query param or `/game/` path). Camera permission follows the device/browser prompt. | | | Screenshot needed: QR scan overlay + permission prompt |
| Guest Flow — steps | Multi-step wizard with a 5-step progress stepper, driven by states: enter code → choose inviter → choose slot → enter name → waiting → confirmed / rejected. | | | Wireframe of full step sequence |
| Guest Flow — enter code | Shown only when arriving with no game loaded (an already-valid code skips straight to choosing an inviter). Offers a tap-to-fill demo code (FP2608) and a "Have an account? Sign in" link. | | | See attached wireframe |
| Guest Flow — code errors | A code that opens the TV display is rejected inline: "That code opens the TV display — ask the host for the player code." | | | See attached wireframe |
| Guest Flow — choose inviter | "Who invited you?" — lists group members who have free guest slots, each with a "N free" green badge; empty state "No one has RSVP'd with guests. Please ask the host." | | | Screenshot needed: inviter list |
| Guest Flow — choose slot | "Choose your guest slot" — "{inviter} is bringing N guest(s)"; occupied slots are greyed with a red "Taken" badge, free slots selectable. | | | Screenshot needed: slot picker |
| Guest Flow — enter name | Guest enters their display name; the Continue/check-in button stays disabled while the field is empty (no inline error text). | | | Screenshot needed: name step |
| Guest Flow — waiting | Booked-in "Waiting for host" state (spinner) showing the reserved "Guest slot" card ("{inviter}'s Guest N"). | | | Screenshot needed: waiting state |
| Guest Flow — confirmed | Approval confirmation shown once the admin checks the guest in: "Your seat" card, a live-game card with timer and blinds, "Watch live game" button, and an upsell "Create an account to use chat and get notifications." with "Sign up". | | | Screenshot needed: confirmed state |
| Guest Flow — rejected | Rejection state: "Request declined" with a "Start over" action. | | | See attached wireframe |
| Guest Flow — resume session | On returning, a previously started guest session for the same game is restored (checklist 07-030) instead of restarting the wizard. | | | Screenshot needed: resumed waiting state |

---

## 3. App Shell & Navigation Flow

Covers the persistent app frame an authenticated user navigates inside, plus the route guard for visitors.

| Screen Name | Description | Current Issue | Client Description | Media |
| --- | --- | --- | --- | --- |
| Shell — desktop frame | At widths above 768 px: fixed left sidebar (224 px) + 1 px divider + page content. | | | See attached wireframe |
| Shell — mobile frame | At 768 px and below: 60 px top bar (menu, wordmark, notification bell with unread dot, avatar) + content + bottom nav + slide-in drawer. | | | Screenshot needed: mobile shell |
| Shell — route guard | Not-signed-in users (and guests) hitting a protected route see a "Signed out" gate: lock icon, "This page needs a signed-in account. Guests can only watch the live game.", "Sign in" (returns to the attempted page) and "Back to start". | | | Screenshot needed: signed-out gate |
| Shell — guest allowed routes | Guests are only permitted into the live-game view and result podium; they get a bare scaffold with no navigation chrome at all. | | | See attached wireframe |
| Sidebar — brand & nav | Top: logo row ("Poker Night"). Items: Home, Group, Alerts (unread count badge, wraps at "9+"), History. Active item = primary tint + 3 px accent border + colored icon/label. | | | Screenshot needed: sidebar |
| Sidebar — MY GROUPS | "MY GROUPS" section lists every group the user belongs to (icon + name), the current group highlighted; each row has a pin/unpin toggle (push-pin icon). | | | Screenshot needed: MY GROUPS + pins |
| Sidebar — quick actions | Pill actions: "New Group" (opens create-group dialog), admin-only "New Game" (→ Create Tournament), and "Cash Game" (→ cash game setup). | | | Screenshot needed: quick actions |
| Sidebar — user footer | Footer with avatar + name, role label ("Admin" / "Player"), plus "Settings" and "Sign out" links. | | | See attached wireframe |
| Navigation drawer — mobile | Off-canvas panel (280 px, slide-in with scrim, animated ease-out): Home, Group, Alerts (badge), History, Profile, Settings; user card; MY GROUPS (pinned rows show a pin icon), "New Group"; "Sign out" + close button. The MY GROUPS section renders only when the user has at least one group. | | | Screenshot needed: open drawer on phone |
| Bottom navigation — mobile | Four-tab phone bar: Home / Group / Alerts (badge) / History; active tab gets a 2 px primary underline above its icon; badge is a small primary dot. | | | Screenshot needed: bottom nav on phone |
| Home — dashboard | Dashboard combining a hero, "Join a group" action (modal with demo code entry) and "Create a group" action (name-only modal here — no icon picker), plus a mini personal-stats row (Games / Wins / Podiums / Avg Finish / Knockouts). If a live game is active it shows a shortcut that opens the running game (sets it as the current game first). Offline-conflict and recovery banners surface here. | | | Screenshot needed: home dashboard + active game shortcut |
| New Group dialog — shared | "New Group" modal: "Group name" field (auto-focused, submits on Enter) + "Group icon" picker of ten emoji tiles (suit/card emojis, dice, trophy, slot, beer, flame); "Create group" creates and switches to the group. | | | Screenshot needed: create-group modal |
| Group — tabs | Group detail screen with a 5-tab bar, each labeled with a count: Games, Members, Chat, Polls, History. | | | Screenshot needed: group tabs |
| Group — admin header | Admin sees header actions "Presets", "Pin" / "Unpin", and "+ New game" (→ Create Tournament). | | | See attached wireframe |
| Group — games & RSVP | Upcoming-game cards carry an RSVP pill row; the "Create tournament" action lives in the empty state ("No upcoming games — create the first one!"). | | | See attached wireframe |
| Group — create poll | "Create poll" modal: a question field plus answer options ("+ Add option" to extend); validation "Enter a question and at least two options." enforces a minimum of two options. | | | Screenshot needed: poll modal |
| Group — empty state | "No upcoming games" empty state with a "Create tournament" action. | | | See attached wireframe |

---

## 4. Create Game Flow

Covers building a new tournament (and the minimal cash-game setup).

| Screen Name | Description | Current Issue | Client Description | Media |
| --- | --- | --- | --- | --- |
| Create Tournament — wizard | Four-step wizard titled "New Game" with a segmented progress bar and "Step X of 4: <name>": Game info → Chip set → Rules → Generate; navigation via Cancel / Back / Next. Optional `preset` query param pre-fills the form from a saved preset (checklist 09-006). | | | Screenshot needed: step indicator |
| Create Tournament — game info | "Tournament name" (placeholder "e.g. Friday Poker"), "Date" (defaults today), "Start time" (default "20:00"), "Location (optional)"; step validation shows "Required" / "Must be positive" inline. "Buy-in amount" is set here. A "Keep address private" toggle reads "Guests see the address only after check-in" (11-014/11-015). | | | Screenshot needed: create tournament — game info |
| Create Tournament — poll presets | If the group has poll results, a "Matching presets from your poll results" banner offers "Use preset" / "Ignore", applying the pick as suggestions. | | | See attached wireframe |
| Create Tournament — chip set step | Chip-set selection with three modes: "Saved preset", "Quick setup", "Exact count". Helper text per mode: quick — "Select available colours and rank them from most to least available. Poker Night will suggest values."; exact — "Enter exact chip counts and values." Modes map to preset / quick / exact inventory behavior. | | | Screenshot needed: chip set step |
| Create Tournament — add custom chip | "Add Chip Color" button opens an "Add Custom Color" dialog (color picker + Color Name / Value / Quantity fields), and switching modes to exact is automatic when prompted. | | | Screenshot needed: add custom chip dialog |
| Create Tournament — chip guard | Generating with no chips shows a "Set chip colours first" modal: "Every game needs a chip set. Add chip colours and values before generating." with "Go to chip set". | | | See attached wireframe |
| Create Tournament — rules step | Buy-in fee controls: "Rebuy price", "Add-on price", "Bounty amount"; organizational-cost slider "Organizational costs (%)" with a live % readout; an "Ante" picker (4 options: Recommended / No ante / Big blind / Individual) with explanatory sub-text per option. (No separate "entry fee" field.) | | | Screenshot needed: rules step + pickers |
| Create Tournament — confirm dialog | "Confirm game details" dialog (non-dismissible): summary rows for name, when, where, players, buy-in, duration, rebuys, re-entry, add-on, bounty, ante and chip set, with "Back to edit" / "Confirm & generate". | | | See attached wireframe |
| Create Tournament — generate step | "Ready to generate" with Players / Duration / Buy-in summary cards and a badge row (e.g. "Unlimited rebuys to L6", "Re-entry", "Add-on to L6", "Ante L6 (BB)", "Chips: …", "Private Address"); copy "Poker Night will calculate starting stack, blind levels, chip composition and prize distribution. You can review and edit before confirming."; "Generate structure" button with the coin-shuffle animation during the ~6 s "Generating tournament..." state. A custom chip set is auto-saved once as "«name» set". | | | Screenshot needed: generate step + animation |
| Presets — library | "Tournament Presets" screen (max 760 px, subtitle "Save your favourite game settings and start a new game in one tap.") with a "+ New preset" header action; each preset card shows name, tag chips (Buy-in Nd, Rebuys to Lx / No rebuys, Add-on / No add-on, KO Nd / No KO, Ante Lx+ / No ante, Nd% org costs, chip-set name) and chip-color previews, with edit/delete actions and a "Use for new game" button pre-loading it. | | | Screenshot needed: presets list |
| Presets — delete confirm | "Delete preset?" dialog: "«name» will be removed. Games already created from it are not affected." with Cancel / Delete. | | | See attached wireframe |
| Presets — empty state | "No presets yet" empty state: "Save a tournament configuration to reuse it later." | | | See attached wireframe |
| Preset form — info & toggles | New/Edit preset modal (max 560 px): preset name, buy-in (default 15), target duration dropdown (3h–6h in 30-min steps, default 3.5); toggles for KO bounty (+ bounty amount, default 5), Rebuys ("Players can re-enter after elimination") with close-rebuys select (End of Level 4–8, default 6), Re-entry, Add-on ("One per active player at rebuy close"), and Ante ("Big blind ante") with activate select (After Level 4–8, default 6). | | | Screenshot needed: preset edit form |
| Preset form — chip set & org costs | Chip-set dropdown fed by the engine presets + saved sets; "Organizational costs" slider 0–20% (default 10) with live % readout; "Save preset" submits. | | | See attached wireframe |
| Preset form — validation | "Preset name must be at least 2 characters.", "Buy-in must be a positive number.", "KO bounty must be a positive number." | | | See attached wireframe |
| New Cash Game — setup step | Cash-game setup (step 1 of 2, "1. Game Setup"): "Game name", "Date" (defaults today), "Location", "Small blind" (default 1), "Big blind" (default 2), "Min buy-in" (default 20), "Max buy-in" (default 200), "Max players" (default 10), "Rake %" (default 0), and a "Currency" selector with four options: USD ($), EUR (€), GBP (£), JPY (¥). | | | Screenshot needed: cash game setup form |
| New Cash Game — players step | Step 2 ("2. Players") builds the starting player list (two starter rows) with "+ Add player" and a "Start cash game" action gated on at least two valid players. | | | Screenshot needed: player setup rows |

---

## 5. Structure Review & Start Flow

Covers the pre-start window where the AI finalizes the structure.

| Screen Name | Description | Current Issue | Client Description | Media |
| --- | --- | --- | --- | --- |
| Structure Review — preview | "Structure Review" screen: total duration and ante-start level derived from the generated levels; summary card wrap shows Players, Starting stack, Total chips, Level duration, Levels and Est. finish; starting / rebuy / add-on stack detail rows (rebuy and add-on read "Add-on stack: … — same as starting stack"). | | | Screenshot needed: structure review summary |
| Structure Review — AI banner | Banner reads "Structure preview — the AI finalizes stacks, blinds and levels 30 minutes before the scheduled start."; it hides once the real structure opens (30-minute window). | | | Screenshot needed: banner |
| Structure Review — chip plan | Chip-composition plan with the starting stack per denomination; a chip-shortage error banner per missing chip: "Chip shortage: you own N× value (color) but the plan needs <need>. Buy more, lower the buy-in, or reduce player count." | | | Screenshot needed: shortage banner |
| Structure Review — blind schedule | Full blind schedule table (columns Level / Small / Big / Ante / BB Depth), rebuy-close level with a bottom border, ante-start level row highlighted, footer notes "Rebuys close after Level X." and "Ante starts Level X."; an "Edit" button opens the structure editor. | | | Screenshot needed: schedule table |
| Structure Review — prizes & color-up | Prize distribution card: "Auto-calculate" paid-places select (1–10), "Est. prize pool", "Est. organizational costs (%)"; plus a "Color-up at rebuy close" instructions card. | | | See attached wireframe |
| Structure Review — footer actions | "Edit settings", "Recalculate", and "Confirm & Publish" (publishing routes on to the Invitation screen). "Recalculate" opens a confirm modal "Recalculate structure" warning "Recalculating regenerates the starting stack, blinds, levels and … — manual level edits will be lost" with Cancel / Recalculate; it replaces the old automatic regenerate-on-return behavior. | | | See attached wireframe |
| Structure Review — empty state | "No structure generated" empty state with a "Go back" action (returns to Create Tournament). | | | See attached wireframe |
| Structure Editor — scope | Modal titled "Edit future structure": "Adjust future levels. Active and completed levels are locked." Future levels are editable from the current level onward. | | | Screenshot needed: structure editor |
| Structure Editor — level rows | Per-level row: level number (mono, "Lv N"), SB / BB numeric fields, a duration dropdown limited to 10 / 15 / 20 minutes, and an ante checkbox labeled per style ("Ante (individual, half BB)" or "Ante (big blind ante)"). | | | Screenshot needed: level row detail |
| Structure Editor — insert/remove | Icon buttons (tooltips "Insert level" / "Remove level") per row; insert duplicates the row, remove is disabled when only one row; levels are renumbered by the provider on apply. | | | See attached wireframe |
| Structure Editor — global actions & validation | "Speed up (-5m)" and "Slow down (+5m)" buttons adjust all future levels; helper note "Durations are limited to 10 / 15 / 20 minutes and new levels can be inserted at any point."; validation "SB and BB must be positive." blocks "Apply & close" when any row is invalid. | | | See attached wireframe |

---

## 6. Invitation & RSVP Flow

Covers inviting members and tracking attendance before the game.

| Screen Name | Description | Current Issue | Client Description | Media |
| --- | --- | --- | --- | --- |
| Invitation — no-game state | Empty state "No game selected." | | | See attached wireframe |
| Invitation — share card | "Share with guests" card shows the "Game code" as a code chip, a copy-link button and a "Show QR code" button (QR appears in a "Guest link" modal). Copy writes `https://pokernight.app/game/<code>` and shows "Link copied" for ~2 s. | | | Screenshot needed: share card + copied state |
| Invitation — attendance summary | Attendance card tallies "Expected: N players", "Confirmed members", "Confirmed guest slots" ("X of Y claimed"), and RSVP counts for Maybe / Can't come / No response. | | | Screenshot needed: attendance summary |
| Invitation — responses | Per-member "Responses" list with RSVP badges: Going, Going +1 … Going +3, Maybe, "Can't Come", No response. | | | Screenshot needed: RSVP badge states |
| Invitation — guest seats | "Guest seats" card lists each slot "{inviter}'s Guest N [— guest name]" with status badges Free / Pending / Checked in / Cancelled. | | | See attached wireframe |
| Invitation — total row | "Total confirmed (incl. guests)" total line across the summary. | | | See attached wireframe |
| Invitation — event-day checklist | Admin pre-live checklist: "Open check-in", "Configure chip set", "Generate seating plan", "Start the tournament". | | | Screenshot needed: event-day checklist |
| Invitation — seat modal | Assigning a seat shows "Table X · Seat X" with table-mates under "At your table"; the current user is shown in bold. | | | Screenshot needed: seat modal |
| Invitation — your RSVP | Member sees their own "Your RSVP" chip row (Going / Going +1..+3 / Maybe / Can't Come). | | | See attached wireframe |
| Invitation — contextual action | The main button changes by state: Review RSVPs → Start Tournament / Open Check-in → View My Seat / Check In / Open Live Tournament → Manage Tournament / Complete Rebuy & Add-on Break / View Results / Tournament Cancelled. Admins also see a danger "Cancel Game" button (once the event is created, until completed/cancelled) that opens a cancel modal with a required "Reason". | | | Screenshot needed: contextual button states |
| Invitation — admin edit | "Edit Event" opens "Edit event details" (all settings + Save changes); changing the date/time raises a "Date or Time Changed" confirm with "Clear RSVPs" / "Keep RSVPs". | | | See attached wireframe |

---

## 7. Check-in & Registration Flow

Covers verifying who actually shows up (admin).

| Screen Name | Description | Current Issue | Client Description | Media |
| --- | --- | --- | --- | --- |
| Check-in — summary | Summary cards: "Checked in" shows "N / M" (checked count over total players), "Pending requests", and "Not arrived". | | | Screenshot needed: summary cards |
| Check-in — admin controls | Admin-only control card: a "Close check-in" / "Reopen check-in" toggle, a "Walk-in" action (modal asks for the walk-in player's name and adds them checked-in with a full starting stack), and "Show assignment on TV" routing to the public TV display. | | | Screenshot needed: check-in admin controls |
| Check-in — list | Player lists grouped under "Players", "Pending check-in requests", and a "Confirmed guests" card (badge "Confirmed", subtitle "Guest of <inviter>"). Un-checked non-guests each carry a "Check in" button inside the Players card; checked-in players show a "Checked in" badge. | | | Screenshot needed: check-in list states |
| Check-in — waiting banner | Warning banner "N player(s) waiting for confirmation". | | | See attached wireframe |
| Check-in — seating mode | Seating strategy selector with four options: "Fully random", "Manual", "Guests with inviter", "Guests separate" (maps to the table seating policy); default Fully random. | | | Screenshot needed: seating options |
| Check-in — seating preview | Table-by-table preview grouped "Table N — N seats" with seat cards "Seat N" / "Dealer · Seat N" and a "Guest" tag; helper "Pick a seating mode above to generate tables and seats." | | | Screenshot needed: seating preview |
| Check-in — actions | Per-player "Check in" action (disabled while check-in is closed); a not-arrived player can be checked in late. | | | See attached wireframe |
| Check-in — gating | The game can only start when at least two players are checked in AND the seating plan is confirmed. If seating is generated but not confirmed, the start button reads "Confirm seating first" alongside a card "Seating has been generated but not yet confirmed." with "Confirm physical seating". While check-in is closed a warning banner reads "Check-in is closed. Reopen to accept more players or start the tournament below." Non-admins are redirected off this screen. | | | See attached wireframe |

---

## 8. Tournament Live Play (Admin) Flow

Covers the running tournament from the organizer's side and the player/guest view.

| Screen Name | Description | Current Issue | Client Description | Media |
| --- | --- | --- | --- | --- |
| Admin Dashboard — no game | "No active game." empty state with a "Go home" action. | | | See attached wireframe |
| Admin Dashboard — tabs | Five tabs: "Players", "Eliminated", "Seating", "Prizes (private)", "Audit Log". | | | Screenshot needed: dashboard tabs |
| Admin — Players tab | Player list with per-player badges "Rebuy ×N" / "Re-entry ×N" / "Add-on" / "Guest", seat line "Table X · Seat Y", and actions "Out" (eliminate modal "Confirm elimination" / "Mark <name> as eliminated?" with a KO-recipient select), "Rebuy", "Add-on", and delete (remove player modal); "+ Add Late Player (Late Reg)" appears while late registration is open. | | | Screenshot needed: players tab |
| Admin — Eliminated tab | Eliminated players with "Position N", "No eliminations yet." empty state, and actions "Grant rebuy", "Re-entry", "Correct Result", and obscure removal. | | | See attached wireframe |
| Admin — Seating tab | Table-balance tool: "Evaluate Table Balance"; a recommendation card "Table balance recommendation: Move <name> from Table A to Table B, Seat C." with "Confirm" / "Dismiss Recommendation"; "Unseated" card. | | | Screenshot needed: balance recommendation |
| Admin — Prizes tab | "Prize amounts are private — only visible to you as admin." with paid-places override (Auto / "N paid places"), "Prize pool", "Organizational costs (%)", "Color-up instructions", and a "Record finish order" button when ≤3 players remain. | | | Screenshot needed: prizes tab |
| Admin — Audit Log tab | Chronological audit entries with type, relative time, details, and "by <actor>". | | | See attached wireframe |
| Admin — live clock | The TV display block (level header, mm:ss countdown turning warning ≤5 min / danger ≤60 s, blinds, progress, payouts) is embedded live; "Start Timer" / "Pause Timer" / "Resume Timer" (compact "Start"/"Pause"/"Resume" on mobile). | | | Screenshot needed: live clock + progress |
| Admin — level controls | "Previous" (disabled at level 1, rewinds to the prior level with its full duration), "Next level", "Restart level", "Speed Up", "Slow Down", and "Recalculate" controls; structure editing via the "Levels" entry. | | | See attached wireframe |
| Admin — settlement trigger | At the end of level 6 the timer expiry switches to the rebuy pause; a "Settlement" button routes to the settlement flow. | | | See attached wireframe |
| Admin — seating/TV/chat/voice | "Redraw table", "Seats", a "TV mode code" card ("Open on any TV browser"), plus "Chat" and "Voice" sheet toggles, and "Undo". | | | Screenshot needed: TV mode code card |
| Admin — pacing insight | Live pacing feedback: "Tournament is running late — suggest shorter future levels" / "Tournament finishing early — suggest longer future levels", each with an "Accept change" action. | | | Screenshot needed: pacing message |
| Admin — cancel & conflicts | Danger zone "Cancel tournament" card (cancel modal requires a "Reason (required)"); an "Offline Conflict Detected" modal offers "Keep Local Offline Progress" / "Discard Local & Sync Cloud". | | | See attached wireframe |
| Tournament Chat — sheet | Bottom sheet (75% height) titled "Tournament Chat": bubbles mine (right, primary) vs others (left, secondary card); admin sees a small "delete" control on other users' messages; empty state "No messages yet. Start the conversation!"; composer "Type a message…" with send (disabled when empty) and a char limit (1000); unsigned users see "Sign in to chat". | | | Screenshot needed: chat sheet open |
| Player Live — header | Player's live view under the countdown: blinds trio (SB / ANTE / BB), "Next level" preview card with "+ ante" tag once antes start. | | | Screenshot needed: player live header |
| Player Live — status & badges | "Eliminated" / "Active" / "You" badges; status text "REBUY CLOSE — BREAK" during the settlement break, plus a rebuy-break banner "Rebuy period has ended. Add-ons are available. Wait for the host to start the next level."; stat cards "Players left", "Avg stack", and prize pool ("Estimated Prize Pool" before settlement, "Prize Pool" after). "TV Mode" header button. | | | Screenshot needed: player live status |
| Player Live — your table | "Your table" card and "Your seat" / "Table X · Seat Y", plus a "{n} players remaining" grid. | | | See attached wireframe |
| Player Live — announcements | "Latest announcement" banner plus the "Announcements" list from the admin. | | | See attached wireframe |
| Player Live — guest CTA | For a guest only after the tournament is completed: "Join the Group" heading with a "Create Account" button. | | | Screenshot needed: completed-game guest prompt |
| Player Live — no game | "No active game." state with a "Go home" action. | | | See attached wireframe |

---

## 9. Rebuy / Add-on Settlement Flow

Covers the end-of-registration settlement and color-up at the close of level 6.

| Screen Name | Description | Current Issue | Client Description | Media |
| --- | --- | --- | --- | --- |
| Settlement — header | "End of Level 6 — Settlement" with subtitle "Confirm players → add-ons → color-up → continue" and a 4-segment progress indicator. Banner: "Rebuys are now closed. No new players may join after this point." | | | Screenshot needed: settlement header |
| Settlement — confirm players | Step 1: review/confirm players with counters "Final eliminations this level" and "Final valid rebuys (hands started before deadline)"; "Active players going to add-on phase: N". | | | See attached wireframe |
| Settlement — add-ons | Step 2: "AI add-on price suggestion" box with rationale ("Based on N players, blinds X and an average stack of Y — suggested price Z.") surfaced as "Use <price>"; "Current add-on price: X"; per-player "Add-on" checkboxes with "Already purchased" badges; add-on composition chip plan; "Add-ons selected" and "Extra chips entering play" figures; "Updated prize pool (est.)"; "Confirm add-ons". | | | Screenshot needed: add-on step with suggested price |
| Settlement — color up | Step 3: "Color-up instructions" from the structure, or "No color-up required at this point."; notes whether the ante starts next level and in which style (individual vs big blind ante). | | | See attached wireframe |
| Settlement — confirm | Step 4: "Ready to continue?" summary of Active players / Add-ons taken / Ante / Prize pool; "Start next level" call-out "Once you start the next level, no more rebuys or add-ons are possible." Starting commits the settlement and resumes the timer. | | | See attached wireframe |
| Settlement — effect | Confirmations add rebuy/add-on stacks into live stacks; total chips = players × starting stack + (rebuys + re-entries) × rebuy stack + add-ons × add-on stack. | | | See attached wireframe |

---

## 10. Final Table & Tournament Completion Flow

Covers the end of the tournament.

| Screen Name | Description | Current Issue | Client Description | Media |
| --- | --- | --- | --- | --- |
| Final Table — intro | "Final Table Redraw" with "N players · random seating" and copy "All remaining players draw new seats at the final table. This cannot be undone." | | | Screenshot needed: final table intro |
| Final Table — 9-seat cap | If more than 9 players remain a warning reads "More than 9 players are still in. The final table holds a maximum of 9 seats." and confirm is disabled ("Eliminate to 9 first"). | | | See attached wireframe |
| Final Table — layout | "Final Table Seating" with an oval "Table layout" seat diagram; "Redraw" re-shuffles; seat numbers 1..n with a shared random state. | | | Screenshot needed: seat diagram |
| Final Table — confirm | Confirming shows "Final Table Set!" then "Returning to dashboard…" and commits the seating. | | | See attached wireframe |
| Complete Tournament — finish order | "Record Finish Order": copy "Tap players in order of elimination (first-out first)"; already-eliminated players ordered by elimination position (descending), survivors by "Still playing (N) — tap to finish"; last player by "Last player — tap to set as winner!"; "Finish order" list with medals; "Undo last"; buttons "Record results" (when complete) or "N players left to rank"; dedupe guard per player. | | | Screenshot needed: finish order screen |
| Complete Tournament — prize spread | Admin-only prize distribution preview computed from the structure ("Prize distribution (admin only)"). | | | See attached wireframe |
| Complete Tournament — confirmation | Confirming advances into the Result Podium ("Tournament Complete!" then "Loading results…"). | | | See attached wireframe |
| Result Podium — guard | Podium only renders once the game status is completed (otherwise "Result unavailable"); a `gameId` route param falls back to the current game. | | | See attached wireframe |
| Result Podium — top three | 1st / 2nd / 3rd podium slots with a "prize pool" header pill and player identity; prize amounts render only for admins — non-admins see "—". | | | Screenshot needed: 3-slot podium |
| Result Podium — full results | "Full results" table with NR / AO / KO badges; stat cards "Players", "Total pot", "Rebuys"; "Group" / "Home" buttons. | | | See attached wireframe |
| Result Podium — your result | "Your result" card showing "Winner!" or "<N><ordinal> place" for the signed-in player. | | | See attached wireframe |

---

## 11. History & Statistics Flow

Covers past results and personal performance (the History screen gates monetary P&L to admins in code).

| Screen Name | Description | Current Issue | Client Description | Media |
| --- | --- | --- | --- | --- |
| History — header stats | Mini-stats grid at the top: Played, Wins, Podium, Rebuys, KOs, and admin-only "P&L" ("—" for non-admins). | | | Screenshot needed: header stat grid |
| History — tabs | Three tabs: "Games", "Leaderboard", "Cash games". | | | Screenshot needed: history tabs |
| History — game list | All past tournaments for the group (subtitle "<Group> · all past tournaments") with per-game results; tapping a row sets it as current game and routes to the Result Podium. | | | Screenshot needed: history list |
| History — prize visibility | Prize amounts shown only to admins; non-admins never see monetary P&L. | | | Screenshot needed: admin vs player view |
| History — empty state | "No completed games yet." | | | See attached wireframe |
| History — leaderboard | "All-time standings" ranking with "You" badge, medal / "#N" ranks, and per-player wins / podium / played stats; "No data yet." empty state. | | | Screenshot needed: leaderboard |
| History — cash games tab | Completed cash games list with "Completed" vs money lines; "No completed cash games yet." empty state. | | | See attached wireframe |
| Statistics — headline cards | "«Player name» · all-time results" page (max 720 px) with a grid of six headline stat cards: Played, Wins, Podium, Avg finish, Knockouts, Win rate; grid adapts 3 columns (phone) to 6 (wide). | | | Screenshot needed: headline stat cards |
| Statistics — rate bars | Progress bars for win rate and podium rate, plus a third "Casualty rate" bar showing "{N} KO". | | | Screenshot needed: rate bars |
| Statistics — recent results | "Recent results" list (renders signed money for all users — no admin gating; possible exception to the P&L rule worth confirming with QA) with empty state "No completed games yet. Finish a tournament and your results will show here." | | | See attached wireframe |
| Statistics — signed-out state | Users not signed in see "Sign in to see your statistics." | | | See attached wireframe |
| Profile — identity | "Profile" screen (max 720 px): large avatar + identity card (name, email), "Member of <group>", Admin badge and an "Edit" control opening an "Edit profile" dialog. A camera chip on the avatar opens a "Choose avatar colour" palette (the avatar colour is a user preference, persisted across sessions). | | | Screenshot needed: profile + edit |
| Profile — rows & stats | Row list "Statistics", "Settings", "Your group", "Delete account" (with "Delete account?" confirm); "Your stats" section with a "View all" link into Statistics; "Sign out" with a confirm dialog; "Not signed in." signed-out state. | | | See attached wireframe |

---

## 12. Notifications, Settings & Game Assets Flow

Covers communication, preferences and saved game assets.

| Screen Name | Description | Current Issue | Client Description | Media |
| --- | --- | --- | --- | --- |
| Notifications — list | Feed shown while there is at least one unread item; unread rows are tinted with a small primary dot; each row shows an icon, title, relative time and chevron; tapping marks read and opens the target. Unread count header "{N} unread". | | | Screenshot needed: notifications list (read/unread) |
| Notifications — type icons | One leading icon per type: game, invite, RSVP, chat, admin, result, system. | | | Screenshot needed: the seven icon variants |
| Notifications — deep links | Tapping a game notification picks the first non-cancelled game in the group, sets it as current, then routes to the relevant screen (admin dashboard, player live, check-in, invitation, settlement, final table, complete, podium). | | | See attached wireframe |
| Notifications — bulk action | "Mark all read" clears the unread set in one tap; all-read footer "You're all caught up." | | | See attached wireframe |
| Notifications — empty state | "No notifications yet." placeholder. | | | See attached wireframe |
| Settings — appearance | "Appearance" section with a three-option theme selector: Dark / Light / System (chips; the app ships dark by default and a light paper theme). | | | Screenshot needed: appearance theme chips |
| Settings — gameplay | "Settings" screen (max 720 px) with a Gameplay section of four toggle rows: "Voice announcements", "Push notifications", "Sound effects", "Compact results". | | | Screenshot needed: gameplay toggles |
| Settings — account | "Account" section: user card (name / email / Admin badge), title "Account", a "Sign out" danger action, an "About" divider and a "Poker Night v1.0.0" footer. | | | See attached wireframe |
| Settings — game assets | "Game Assets" section with a single row "Chip sets" routing to the chip-set library (presets live under the group header, not here). | | | See attached wireframe |
| Chip Sets — library | "Chip Sets" screen (max 720 px) listing saved sets; each card shows the set name and chip-color tokens (color name, hex, value, quantity), with edit (pencil) and delete (trash) actions; the default set is not deletable; "New Chip Set" opens the editor. | | | Screenshot needed: chip set library |
| Chip Sets — empty state | "No saved chip sets." | | | See attached wireframe |
| Chip Sets — delete confirm | "Delete chip set?" dialog: "«name» will be removed. Games already played with it stay in history unchanged." with Cancel / Delete. | | | See attached wireframe |
| Edit Chip Set — inventory modes | Editor (max 760 px) with two modes: "Exact inventory" (quantity + printed value per colour — "Enter the exact quantity and printed value for each colour") and "Quick inventory" ("Quick setup: pick colours and rank them — Poker Night suggests values") which splits into "Unnumbered" (drag-to-rank reorderable, engine-suggested values, quantities are estimates, "Re-suggest values" action) and "Numbered" (printed value per colour, quantities optional and filled at setup). | | | Screenshot needed: exact vs quick modes |
| Edit Chip Set — add & helpers | "+ Add colour" appends a chip (white default); helpers explain ranking ("Most available → least available.") and that quantities get confirmed during setup review. | | | Screenshot needed: reorder list |
| Edit Chip Set — chip row | Per-chip row: colour swatch + name (tap opens the material color picker dialog with a "Color Name" field), numeric "Value" field, "Qty" field (hidden in numbered/ranked modes) and an inline delete control; errors are inline ("inv" / "dup"). | | | Screenshot needed: chip row + color picker |
| Edit Chip Set — validation | "Enter a chip set name."; duplicate values rejected ("Two colours cannot share the same value (<values>)."); duplicate names rejected ("A chip set with this name already exists."); top Save persists and pops back. | | | See attached wireframe |

---

## 13. TV Display Flow

Covers the public big-screen display for spectators.

| Screen Name | Description | Current Issue | Client Description | Media |
| --- | --- | --- | --- | --- |
| TV Mode — connect | "TV Display" entry card: subtitle "Enter the TV code shown by the host", mono "TV CODE" field, "Connect to game" button and "Back to website"; a tappable "Demo TV code: TV-FP" hint is offered. | | | Screenshot needed: TV connect screen |
| TV Mode — code errors | Submitting an unknown code shows "Code not found — try again" (no period). | | | Screenshot needed: TV code error state |
| TV Mode — display | Once connected, a full-bleed black display (`pureBlack`) hosts the live tournament block for spectators. | | | Screenshot needed: full-screen TV tournament display |
| TV Mode — completion | When the tournament is completed with three or more finishers, the display switches to a "Tournament Complete!" podium (columns 2nd / 1st / 3rd with fixed heights 170 / 240 / 140). | | | Screenshot needed: TV completion podium |
| Tournament Display Block — header | Black shareTechMono display: "LEVEL N" (or "BREAK" during the rebuy pause) in red, then a large mm:ss countdown (digits) that turns warning (≤5 min) and danger (≤60 s); SB / ANTE / BB big stats with the ante only when active; 8 px progress bar. | | | Screenshot needed: level header + timer states |
| Tournament Display Block — stats | Five stats wrap: TOTAL TIME / PLAYERS / TOTAL CHIPS / BREAK (during the rebuy pause) or NEXT LEVEL (mm:ss countdown to the next level) / AVG STACK; then "LEVEL N+1" next-level SB/BB/ANTE mini stats (or "END" when out of levels) and PAYOUTS with the top four prize values (1ST–4TH). | | | Screenshot needed: stats + next level rows |
| TV Display — rotating side panel | On wide screens (≥900 px) the display splits into the live block plus a 340 px side panel that rotates every 8 s between Leaderboard (players by table/seat with a "T·S" tag), Payouts (first six prizes plus a prize-pool footer), and Upcoming (next four levels' SB/BB/ante). | | | Screenshot needed: rotating panel states |
| Tournament Display Block — responsiveness | All typography and spacing scale continuously with container width (smoothed 360 px → 1100 px range), no hard mobile/desktop snap point. | | | See attached wireframe |

---

## 14. Cash Game Flow

Covers the minimal cash-game mode.

| Screen Name | Description | Current Issue | Client Description | Media |
| --- | --- | --- | --- | --- |
| Cash Game Live — empty state | "No active cash game." with a "Start a cash game" action routing into the setup flow. | | | Screenshot needed: empty state |
| Cash Game Live — header | Live header: game name + "Live · Xh Ym · SB/BB" with a green live dot. | | | Screenshot needed: live header |
| Cash Game Live — stat cards | Three table-level stat cards: "Total in", "In play", "Cashed out". | | | Screenshot needed: stat cards |
| Cash Game Live — player list | "{N} Players" header; per-player rows showing current stack with actions "+ Buy", "Out", "Edit". | | | Screenshot needed: player rows + stack |
| Cash Game Live — cashed-out state | Cashed-out players render at reduced opacity with a "Cashed out" badge and signed net, plus the buy-in count line "In: {money} (N×)". | | | Screenshot needed: cashed-out row |
| Cash Game Live — add player | "+ Add player" opens the buy-in flow with a "Player name" field and "Add new player" confirm. | | | See attached wireframe |
| Cash Game Live — buy in / cash out | Action modals "Buy in / rebuy" and "Cash out" with an "Amount" field, hints "Min X · Max Y" / "Current stack: X", and quick-amount chips (min, min×2, max). | | | Screenshot needed: buy-in dialog |
| Cash Game Live — edit correction | "Edit" opens a correction form: "Correct an incorrectly entered buy-in, top-up or cash-out. Totals are recalculated from these fields." — editable "Stack in play", "Total bought", "Buy-in count", "Cashed out"; "Save corrections" commits. | | | Screenshot needed: correction form |
| Cash Game Live — reconcile | "Reconciliation" modal: "Chips in play must equal total buy-ins minus cashed out. …" with rows Total buy-ins / Cashed out / Expected in play / Actual in play / Difference, a "Rake (N%): amount" line and "Close". | | | Screenshot needed: reconcile modal |
| Cash Game Live — end game | "End cash game?" modal; "{N} players still active — they should cash out first." warning; if there is a mismatch an explanation banner plus checkbox "I understand — end with the mismatch recorded" enable an explicit force-end; concluding routes to History. | | | See attached wireframe |

---

## Notes for the client

- **Current Issue** and **Client Description** columns are intentionally left blank for you/QA to fill in.
- **Media** column lists the screenshot/wireframe still needed for the final approved doc; anything marked "See attached wireframe" can be replaced with an actual image when available.
- Scope basis: MVP v2.0 — web-first PWA, single admin, tournament mode + minimal cash mode. Spotify, native apps, casting SDKs and payment processing are out of scope.
- Existing invite links are shared via `https://pokernight.app/game/<code>`; join codes survive the URL form when scanned.
- Non-admin visibility: the History screen hides prize amounts and P&L for non-admins in code; QA should confirm the Statistics "Recent results" money display is intended to be visible to all users (it currently is).