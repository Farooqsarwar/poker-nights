Poker Night MVP — Technical Specification 

#### **POKER NIGHT** 

# **MVP Technical S ecification** **<u>p</u>** 

**_Implementation-ready requirements for the reduced-cost web-first product_** 

**MVP Scope v2.0** 

**_Web-first MVP • One administrator • Tournament + minimal cash mode • No Spotify_** 

1 

Poker Night MVP — Technical Specification 

## **Contents** 

**1. Document purpose and product boundaries** 

**2. Final MVP scope** 

**3. Roles and permissions** 

**4. System architecture** 

**5. Domain model and data ownership** 

**6. Tournament setup engine** 

**7. Chip inventory and stack generation** 

**8. Blind, level and ante generation** 

**9. Prize and organizer calculations** 

**10. Invitations, guests and check-in** 

**11. Live tournament operations** 

**12. Seating and final-table logic** 

**13. TV Mode and voice announcements** 

**14. Chat, polls and notifications** 

**15. Game history and basic statistics** 

**16. Minimal cash-game module** 

**17. Screen-by-screen specification** 

**18. API contract** 

**19. Realtime event contract** 

**20. Offline recovery and conflict rules** 

**21. Validation, errors and edge cases** 

**22. Security and privacy** 

**23. Testing and acceptance criteria** 

**24. Deployment and operations** 

**25. Deferred features and future phases** 

2 

Poker Night MVP — Technical Specification 

## **1. Document Purpose and Product Boundaries** 

This document is the implementation source of truth for the Poker Night MVP. It describes what must be built, what must not be built, how users move through the product, how data is stored, and how the tournament calculations behave. When a requirement appears ambiguous, the later and more specific rule in this document takes priority. 

##### **Core principle** 

The administrator chooses the event. Poker Night proposes a playable tournament from the real chips, confirmed attendance and target duration. The administrator remains in control and must confirm all changes that affect play. 

### **1.1 Product objective** 

- Provide one responsive website/PWA that works on phones, tablets, computers and TV browsers. 

- Allow a single administrator to create and operate private No Limit Texas Hold’em tournaments. 

- Allow registered players to RSVP, check in, use chat and polls, receive notifications and view the live game. 

- Allow guests to check in through a web code without creating an account. 

- Generate stacks, blinds, level length, chip composition, ante timing and payouts from practical inputs. 

- Provide a separate minimal cash-game tracker. 

- Keep the active tournament recoverable on the administrator device if the connection or browser fails. 

### **1.2 Explicit non-goals for this MVP** 

- No Spotify integration. 

- No native iOS or Android applications; the PWA is the launch client. 

- No dedicated Chromecast, AirPlay or casting SDK integration. Users may open TV Mode directly or mirror the browser themselves. 

- No multiple administrators controlling one game. 

- No complex role hierarchy or financial permission system. 

- No friends system, public social feed, achievements, advanced seasons or advanced analytics. 

- No real-money payment processing and no paid/unpaid tracking. 

- No automatic hand tracking, card recognition, dealer rotation or pot calculation. 

- No full multi-device offline operation. Only the administrator’s active game is locally recoverable. 

- No continuous high-complexity tournament simulation. Live recommendations use a lightweight recalculation at level boundaries or on request. 

## **2. Final MVP Scope** 

|**Module**|**Included in MVP**|**Not included**|
|---|---|---|
|Platform|Responsive PWA, web authentication,<br>group and game pages|Native mobile apps|
|Roles|Admin, registered player, guest|Assistant admin, moderator, financial<br>roles|
|Tournament|Adaptive setup, timer, live controls,<br>seating, rebuys, add-ons, payouts|Hand tracking or automatic rulings|
|Social|Group chat, polls, in-app/browser<br>notifications|Friends, feed, media gallery,<br>achievements|
|TV|Read-only web page opened with<br>code/link|Dedicated casting SDKs|



3 







<!-- Start of picture text -->
Admin PWA<br>Create and run games<br>Admin Local Storage<br>Active-game recovery<br>“= esyne<br>Registered Player PWA Cloud Backend Shared Poker Engine<br>RSVP, chat, polls, game view Auth, database, realtime, notifications Structure, chips, payouts, seating<br>Guest Web View<br>Code, check-in, seat, timer<br>TV Browser View<br>Read-only display<br><!-- End of picture text -->

Poker Night MVP — Technical Specification 

- Receive administrator confirmation, table and seat. 

- View timer, blinds, ante, announcements and seat information. 

- Cannot use chat, polls, notifications or permanent group features without registering. 

|**Action**|**Admin**|**Registered player**|**Guest**|
|---|---|---|---|
|Create/edit game|Yes|No|No|
|Operate timer|Yes|No|No|
|Record rebuy/add-<br>on/elimination|Yes|No|No|
|RSVP|May edit any|Own response|Guest slot only|
|Check in|Any participant|Self|Self request|
|Chat and polls|Yes|Yes|No|
|View live prize pool|Yes|Yes|Yes|
|View payout amounts|Yes|No|No|



## **4. System Architecture** 

### **4.1 Recommended implementation pattern** 

The MVP should be a responsive Progressive Web App backed by a managed cloud database with authentication, realtime subscriptions and browser push notifications. Supabase or Firebase are acceptable. The tournament engine must be implemented once as a shared, versioned module and invoked by the server and administrator client with deterministic inputs. 

|**Layer**|**Responsibility**|**Suggested technology**|
|---|---|---|
|Client|Admin, player, guest and TV responsive<br>views|React/Next.js or equivalent PWA|
|Backend|Auth, validation, data persistence,<br>notifications, realtime fan-out|Supabase/Firebase or small Node<br>backend|
|Database|Groups, games, participants, structures,<br>actions, chat, polls|PostgreSQL when using Supabase;<br>Firestore otherwise|
|Realtime|Broadcast authoritative game state to<br>online clients|Database subscriptions or WebSocket<br>channel|
|Local recovery|Persist administrator game snapshot and<br>queued actions|IndexedDB|
|Voice|Speak cached announcement text in<br>English|Browser SpeechSynthesis API|



### **4.2 Authoritative state** 

The cloud record is authoritative while the administrator is online. The administrator client also stores the latest game snapshot and every local action in IndexedDB. If the browser refreshes or temporarily loses connectivity, the clock and controls continue from the local snapshot. Player, guest and TV clients require an online connection and show a stalestate banner if updates stop. 

5 





<!-- Start of picture text -->
id<br>ce gs user_id<br>Notification -<br>di readtype at<br>User | nameemail<br>role=admin'player group_ic<br>Membership user_id<br>Status game_id<br>Structure Slarting stack<br>levels. json<br>id chip_plan_jan<br>group_id<br>Game hype<br>; statis id<br>Group a settingsms_|json game_icdi<br>none GameAction type<br>“cod payload<br>owner id id sequence<br>ChalMessage group_id/game_idauthor itt<br>body<br>idrou 4 carne:ici<br>nites| Participant1 acl user Ialauest_id<br>status. seal<br>id<br>Guest statinviter_id<br>name<br>confirmed<br><!-- End of picture text -->















Poker Night MVP — Technical Specification 

### **6.1 Required setup inputs** 

|**Field**|**Type and validation**|**Default**|
|---|---|---|
|Tournament name|1–80 characters|Poker Night + date|
|Date/time|Future local date/time|Required|
|Location|0–160 characters|Optional|
|Expected players|Integer ≥2, from RSVP or admin override|Going responses + guests|
|Target duration|3, 3.5, 4, 4.5, 5, 5.5 or 6 hours|3.5 hours|
|Buy-in|Positive number; no currency symbol in<br>game UI|Required|
|KO bounty|Off or positive amount displayed as buy-in<br>+ bounty|Off|
|Rebuys|Enabled/disabled, closing level, unlimited<br>or limit|On, end of Level 6, unlimited|
|Add-on|Enabled/disabled and price only|On, price = buy-in, max 1/player|
|Ante|Off, big blind ante, individual ante|Off; big blind ante recommended if<br>enabled|
|Organizer percentage|0–100, private|Group preset or 0|
|Chip set|Saved, exact inventory or quick inventory|Required|



### **6.2 Preset matching** 

Before starting from zero, the system searches the administrator’s presets. A matching preset is suggested when buyin, KO setting, target duration, expected attendance, rebuy/add-on settings and chip set are sufficiently close. If two presets match, show both and explain the differences. A preset supplies settings only; the engine always regenerates the structure using current attendance and chips. 

### **6.3 Generation workflow** 

**1.** Normalize chip denominations and verify that no two colours share a value. 

**2.** Estimate legal opening blind candidates from the smallest practical denominations. 

**3.** For each candidate, calculate a starting stack and target big-blind depth appropriate to duration and field size. 

**4.** Estimate total chips after expected rebuys and add-ons. 

**5.** Choose one level duration from 10, 15 or 20 minutes as the default for the whole event. 

**6.** Calculate the approximate number of levels available inside the target playing duration. 

**7.** Generate a smooth big-blind curve and snap every level to a chip-compatible amount. 

**8.** Select a simple payable small blind, usually 40–50% of the big blind but not necessarily exactly half. 

**9.** Add the approved ante from the configured level and recalculate pressure. 

**10.** Generate starting, rebuy, add-on and colour-up chip plans. 

**11.** Calculate expected finish range and payout proposal. 

**12.** Return proposal, warnings and alternatives for administrator confirmation. 

8 

Poker Night MVP — Technical Specification 

## **7. Chip Inventory and Stack Generation** 

### **7.1 Inventory modes** 

|**Mode**|**Admin input**|**Guarantee**|
|---|---|---|
|Saved|Select an existing exact or quick chip set|Same guarantee as saved mode|
|Exact|Colour, value and exact quantity for each<br>chip|Engine must not exceed inventory|
|Quick numbered|Colours, printed values, rank from most to<br>least available|Provisional; admin confirms availability|
|Quick unnumbered|Colours and availability rank; engine<br>proposes unique values|Provisional; admin confirms mapping and<br>quantities|



### **7.2 Stack objectives** 

- Starting stack value and opening blinds must be solved together; there is no unconditional 5,000 minimum. 

- Provide useful early depth without creating unnecessarily huge physical stacks. 

- Use enough low chips to post early blinds without constant change. 

- Reserve inventory for expected rebuys, one add-on per player and later colour-ups. 

- Prefer visually countable groups and few denominations per stack. 

- Never give two chip colours the same value. 

### **7.3 Constructible stack search** 

```
For each candidate total stack S:
  enumerate practical combinations of active denominations
  reject combinations that exceed per-colour inventory reserve
  score =
      early_blind_payability
    + counting_simplicity
```

```
    + stack_aesthetics
```

```
    + rebuy_reserve_health
    + colour_up_efficiency
    - excessive_chip_count
Choose the highest-scoring valid combination.
```

### **7.4 Rebuy stack** 

A rebuy is available only after elimination and has exactly the same total value as the original starting stack. Its physical composition may change. At later levels, use fewer obsolete small chips and more medium/high chips while keeping enough chips to post the current blinds easily. 

### **7.5 Chip exchanges** 

The system provides direct instructions such as “exchange 20 white chips for 2 blue chips.” Exact exchanges are preferred. When a small remainder cannot be exchanged exactly, the MVP default is to round the player upward and add the resulting small increase to total chips in play. A formal chip race is an advanced option, not the default. 

9 

Poker Night MVP — Technical Specification 

## **8. Blind, Level and Ante Generation** 

### **8.1 Level length** 

Every level is exactly 10, 15 or 20 minutes. The generated structure should normally use one duration throughout. During play the administrator may accept a recommendation that changes future levels to another allowed duration. The active level is never changed. 

### **8.2 Starting depth model** 

```
targetStartingBB = clamp(
    125
  + 28 * (targetHours - 3.5)
  - 2.5 * max(0, expectedPlayers - 8),
  80,
  240
)
candidateStartingStack = practicalRound(openingBB * targetStartingBB)
```

```
The constants are configuration values, not UI settings, and must be calibrated with test simulations.
```

### **8.3 Final blind target** 

```
expectedTotalChips = startingStack * expectedPlayers
                   + startingStack * expectedRebuyCount
                   + addOnStack * expectedAddOnCount
targetFinalBB = expectedTotalChips / (2 * targetHeadsUpAverageBB)
where targetHeadsUpAverageBB defaults to 15.
```

### **8.4 Blind curve** 

```
rawBB(level i) = openingBB * growthFactor^i
```

```
growthFactor = (targetFinalBB / openingBB)^(1 / max(1, plannedLevels - 1))
For each raw value:
  snap to a legal, easy-to-post amount
  enforce monotonic increase
  avoid unreasonable jumps
  choose a practical small blind near 40–50% of BB
  allow values such as 20/50 or 1200/2500 when easier with the chips.
```

### **8.5 Ante** 

- Default when enabled: big blind ante equal to the current big blind. 

- Default activation: after the rebuy period, normally the first level after Level 6. 

- Big blind ante remains active short-handed and heads-up by default. 

- Individual ante candidate = big blind divided by expected table size, snapped to a practical chip value. 

- Enabling an ante triggers a full remaining-duration recalculation before confirmation. 

### **8.6 Live speed-up and slow-down** 

At a level boundary or when the administrator requests recalculation, compare actual players remaining with the expected curve and estimate the new finish. When the difference exceeds 20 minutes, offer a recommendation. Nothing changes automatically. 

**Action** 

**Permitted changes Restriction** 

10 

|||Poker Night MVP — Technical Specification|
|---|---|---|
|Speed up|20→15, 15→10, activate approved ante,<br>increase future blinds|Starts next level only|
|Slow down|10→15, 15→20, insert intermediate future<br>level, soften growth, delay ante|Never remove a level|
|Manual edit|Edit a future blind or duration and preview<br>finish impact|Cannot edit completed/active level|



## **9. Prize and Organizer Calculations** 

### **9.1 Contribution rules** 

- Regular buy-in component, rebuys, re-entries and add-ons contribute to the calculation. 

- KO bounty money is excluded. In 15 + 5, only 15 contributes to the regular prize pool. 

- Poker Night records game contributions for calculation but does not record whether cash was paid. 

- During play, players may see the total Estimated Prize Pool and then Prize Pool after settlement. 

- After the game, players see paid positions/podium but no money amounts. 

### **9.2 Organizer amount rounding** 

```
grossEligible = sum(regular entry + rebuy + re-entry + add-on components)
targetOrganizer = grossEligible * organizerPercentage
Select organizerAmount nearest to targetOrganizer such that:
  prizePool = grossEligible - organizerAmount
  prizePool is divisible by 10
If equally near, choose the lower organizerAmount.
```

```
Example: gross 165, target 16.5 -> choose 15, prize pool 150.
```

### **9.3 Paid places** 

The number of paid places is a combination of unique players and prize pool. The engine should generally pay around 15–25% of unique players, subject to a meaningful lowest prize. It may pay two places for small fields/pools, three for medium games and four or more for larger games. The administrator may override. 

### **9.4 Payout weights and rounding** 

```
Create descending raw weights:
  weight_i = exp(-lambda * i), i starting at 0
Normalize weights to the prize pool.
Use lambda calibrated to approximate:
  2 places: ~73/27
  3 places: ~57/30/13
  4 places: ~56/30/10/4
Round every displayed payout to a multiple of 10.
Protect the lowest paid place, then second/third balance.
First place absorbs the final 10-unit reconciliation.
Never generate a payout ending in 5.
```

## **10. Invitations, Guests and Check-in** 

### **10.1 RSVP choices** 

- Going 

- Maybe 

11 



<!-- Start of picture text -->
Pause<br>Paused<br>rebuy level ends RebuyBreak<br>S remain / multi-table FinalTable.<br>podium recorded<br>star<br>Completed<br>open check. (oman<br>=| Cancelled<br>Published<br>publish,<br><!-- End of picture text -->

Poker Night MVP — Technical Specification 

### **11.1 Admin control screen** 

- Large clock with Start, Pause, Resume and Next Level. 

- Current blinds/ante, next level and current player count. 

- Participant list with Check in, Eliminate, Rebuy, Add-on and Undo actions. 

- Tables and seats with pending move recommendations. 

- Estimated finish and Recalculate button. 

- Speed Up, Slow Down and Edit Future Structure buttons. 

- Announcements panel and TV link/code. 

- Persistent offline/recovery indicator. 

### **11.2 Rebuy-period closing flow** 

**1.** When the last rebuy level reaches zero, the clock pauses automatically. 

**2.** Rebuys and late registration close. 

**3.** No fixed break countdown is used. 

**4.** Show final eligible rebuy actions, recommended add-on value, add-on selection for each active player, chip exchanges and ante confirmation. 

**5.** Administrator records final rebuys and up to one add-on per active player. 

**6.** Recalculate total chips, prize pool and future finish estimate. 

**7.** Administrator confirms settlement and manually starts the next level. 

### **11.3 Elimination and undo** 

Only the administrator records an elimination. The action marks the player eliminated, captures the position and optional single knockout recipient, and updates remaining players. Before another dependent action makes reversal unsafe, the administrator can Undo. Otherwise use Correct Result, which appends a compensating audit action; never delete audit history. 

### **11.4 Lightweight live recommendations** 

At every level end, calculate actual remaining players, average stack, average big blinds and estimated finish. If estimated finish differs from target by more than 20 minutes, show a non-blocking recommendation. The administrator may ignore it. The app never silently changes blinds, duration or ante. 

## **12. Seating and Final-table Logic** 

### **12.1 Initial seating** 

The administrator chooses Fully Random, Manual, Keep Guests with Inviter, or Separate Guests from Inviter. Default table capacity is nine. Ten or more checked-in participants create multiple tables automatically. 

### **12.2 Table balancing** 

When tables differ by more than one active player, recommend a move. The administrator sees the source player, target table and target seat, physically completes the move, then confirms. Only after confirmation does the system update the seat map. 

### **12.3 Final table** 

When nine players remain and the game previously used multiple tables, pause and create a complete random redraw for all nine seats plus a random initial dealer-button position. The administrator confirms seating, then resumes. If the game began on one table, no redraw is required. The app does not track dealer movement afterward. 

13 

Poker Night MVP — Technical Specification 

## **13. TV Mode and Voice Announcements** 

### **13.1 TV Mode** 

TV Mode is a read-only web page opened with the tournament code or direct link. It may be opened on several displays. The MVP does not implement casting SDKs; users can open it on a TV browser or mirror the page manually. 

- Tournament name and state 

- Large timer 

- Current blinds and ante 

- Next level 

- Players remaining 

- Average stack and average BB 

- Estimated Prize Pool before settlement and Prize Pool afterward 

- Break/settlement messages 

- Visual announcements 

- Final-table redraw and completed podium 

Never show organizer percentage, organizer amount, individual payouts, rebuy/add-on counts, transaction identities, admin controls or private statistics. 

### **13.2 Voice** 

The administrator manually selects the one browser/device that plays announcements. Use the browser’s standard English speech voice. Other connected screens remain silent. 

- Tournament starts 

- New level 

- Five minutes remaining 

- One minute remaining 

- Rebuys closed 

- Add-ons available 

- Final table 

- Initial/final-table dealer assignment 

- Winner 

Elimination names are optional per tournament and disabled by default. Voice commands are deferred. 

## **14. Chat, Polls and Notifications** 

### **14.1 Chat** 

- One group chat and optional tournament-specific chat thread. 

- Registered members only; guests cannot read or write chat. 

- Plain text only in the MVP, maximum 1,000 characters. 

- Admin can delete a message; deleted messages remain in audit metadata but are hidden from users. 

- Realtime delivery, unread count and basic spam rate limit. 

### **14.2 Polls** 

- Admin creates single-choice or multi-choice polls with 2–10 options. 

- Use for date, time, buy-in, KO setting, duration, location or custom questions. 

- Registered members vote; guests cannot vote. 

- Admin closes a poll manually. Results may suggest a matching tournament preset. 

14 



<!-- Start of picture text -->
Create session Add and Start session Record buy-ins Record Reconcile Save session<br>and fixed blinds seal players timer and top-ups cash-outs totals summary<br><!-- End of picture text -->

Poker Night MVP — Technical Specification 

- Start a session-duration counter; there are no levels or blind increases. 

- Admin records each player’s initial buy-in chip value and later top-ups. 

- Admin records final cash-out chip value when the player leaves or at session end. 

- Reconcile total bought chip value against total cashed-out chip value. 

- Save a private admin session summary and a non-financial group history item. 

### **16.2 Excluded** 

- No waiting list, multiple cash tables, straddles, bomb pots, run-it-twice controls or cash voice announcements. 

- No long-term cash profit/loss statistics for players. 

- No payment tracking. Values represent chips issued and returned, not confirmation that money changed hands. 

### **16.3 Reconciliation** 

```
totalIssued = sum(initial buy-ins + top-ups)
totalReturned = sum(cash-outs)
difference = totalReturned - totalIssued
```

```
If difference != 0:
  block final confirmation until admin either corrects records
  or saves an explicit unresolved-difference note.
```

## **17. Screen-by-screen Specification** 

|**Screen**|**Required behaviour**|
|---|---|
|Welcome / authentication|Sign in, register, enter group code, enter tournament code.<br>Preserve intended destination after authentication.|
|Home|Upcoming games, groups, notifications, create button for admin,<br>current active game shortcut.|
|Group|Upcoming/past games, members, chat, polls, presets, group<br>code.|
|Create tournament|Preset suggestion, basic inputs, chip set, optional rules,<br>generate button.|
|Structure review|Starting stack, chip breakdown, level table, ante, predicted<br>finish, warnings, Regenerate, Edit, Confirm.|
|Invitation / RSVP|Single RSVP option, guest count embedded, deadline, share<br>code/link/QR.|
|Check-in|Going/guest list, pending guest requests, confirm, assign<br>seating.|
|Admin live dashboard|Clock, levels, participant actions, settlement, structure change,<br>seating, announcements, recovery state.|
|Player live view|Timer, blinds, next level, players remaining, average stack, prize<br>pool during game, seat, announcements.|
|Guest live view|Same limited live information plus own seat; no<br>chat/polls/notifications.|
|TV Mode|Large read-only display, no navigation or controls.|
|Rebuy/add-on settlement|Final rebuys, add-on value, one checkbox per active player,|



16 

Poker Night MVP — Technical Specification 

||exchanges, ante, prize pool, Confirm and Continue.|
|---|---|
|Final-table redraw|Nine seats, dealer position, Confirm Seating.|
|Complete tournament|Enter finishing order, verify podium, admin private payout<br>summary, publish result.|
|Cash session|Fixed blinds, seated players, timer, buy-in/top-up/cash-out<br>controls, reconciliation.|
|History / stats|Group history and five basic aggregate statistics.|



## **18. API Contract** 

The exact transport can be REST or framework server actions, but these logical operations and role checks are required. Use idempotency keys for game actions that could be double-submitted. 

|**Endpoint**|**Purpose**|**Permission**|
|---|---|---|
|POST /auth/register|Create account|Public|
|POST /groups|Create group and join code|Authenticated admin|
|POST /groups/{id}/join|Join by code|Authenticated player|
|GET /groups/{id}|Role-specific group projection|Member|
|POST /groups/{id}/chat|Send message|Registered member|
|POST /groups/{id}/polls|Create poll|Admin|
|POST /polls/{id}/votes|Vote|Registered member|
|POST /games|Create tournament/cash session|Admin|
|PATCH /games/{id}|Edit draft/published fields|Admin|
|POST /games/{id}/generate|Generate tournament proposal|Admin|
|POST /games/{id}/publish|Publish invitation|Admin|
|POST /games/{id}/rsvp|Set own RSVP|Registered player|
|POST /public/games/{code}/guests|Reserve guest slot|Public guest|
|POST<br>/games/{id}/participants/{pid}/confirm|Confirm guest/check-in|Admin|
|POST /games/{id}/actions|Append operational action|Admin|
|POST /games/{id}/structure/recalculate|Preview future changes|Admin|
|POST /games/{id}/structure/accept|Accept future structure revision|Admin|
|GET /public/games/{code}/tv|TV projection|Public with code|
|GET /public/games/{code}/guest|Guest projection|Guest session|



17 

|||Poker Night MVP — Technical Specification|
|---|---|---|
|POST /games/{id}/complete|Validate and complete|Admin|
|GET /groups/{id}/history|Group history|Member|



### **18.1 Game action payload** 

```
{
  "idempotencyKey": "uuid",
  "expectedRevision": 42,
  "type": "ELIMINATE_PLAYER",
  "payload": {
    "participantId": "...",
    "knockoutParticipantId": "... optional"
  },
  "clientOccurredAt": "ISO-8601"
}
```

Reject with HTTP 409 when expectedRevision does not match. Because only one admin exists, conflicts should be rare; nevertheless, browser retries and restored offline actions can cause duplicates. 

## **19. Realtime Event Contract** 

|**Event**|**Payload purpose**|
|---|---|
|game.snapshot|Complete role-safe state after join/reconnect|
|clock.changed|start, pause, resume, level transition|
|participant.changed|RSVP, check-in, seat, elimination|
|structure.changed|accepted future structure revision|
|prize_pool.changed|estimated/confirmed total only for public roles|
|announcement.created|visual text and optional speak flag|
|chat.created|new registered-member message|
|poll.changed|poll opened, closed or vote totals|
|notification.created|new inbox item|
|game.completed|final non-financial result projection|



Every event includes game/group ID, monotonically increasing revision/sequence, server timestamp and a projection safe for the recipient role. On missed sequence, the client requests a full snapshot. 

## **20. Offline Recovery and Conflict Rules** 

### **20.1 Local persistence** 

- Write the current admin game snapshot to IndexedDB after every accepted action. 

- Store the running clock as timestamps, not a second-by-second counter. 

- Store unsynchronised actions with idempotency keys and expected revision. 

- On reopen, offer “Restore active tournament” with last saved local time and state. 

- When connection returns, submit queued actions in order and stop on first conflict. 

18 

Poker Night MVP — Technical Specification 

### **20.2 Online viewers** 

Player, guest and TV views show the last received state plus a visible “Connection interrupted” banner. The timer may continue visually from the last trusted timestamp, but other values are frozen until reconnection. New devices cannot join while the backend is unavailable. 

### **20.3 Recovery safety** 

If the server game advanced after the local snapshot, do not overwrite it. Show a comparison and require the administrator to choose the server version or manually reapply missing actions. Never merge two different clock states automatically. 

## **21. Validation, Errors and Edge Cases** 

|**Scenario**|**Required behaviour**|
|---|---|
|No legal blind with chips|Reject proposal and show which denomination is missing or<br>propose new values for unnumbered chips.|
|Quick inventory shortage|Show required quantities; let admin choose fewer players,<br>another stack, another chip mapping or confirm more chips<br>exist.|
|Duplicate guest slot|First reservation wins temporarily; second guest must choose<br>another slot.|
|Guest no-show|Admin removes confirmation before start; seating regenerates or<br>seat remains empty until confirmed.|
|RSVP changed after deadline|Block player change; admin may edit before late registration<br>closes.|
|Player added during play|Allowed only before rebuy period closes; full fresh stack;<br>recalculate and offer future changes.|
|Rebuy requested for active player|Block; rebuy only after elimination.|
|Second add-on|Block; maximum one add-on per active player.|
|Elimination mistake|Undo if safe, otherwise compensating correction action.|
|Level reaches zero while offline|Admin client transitions locally and queues the transition.|
|Browser sleeps|Wake from timestamps; do not add sleep duration twice.|
|TV opens old code|Show invalid/expired code; never expose prior private data.|
|Prize pool not divisible by 10|Adjust private organizer amount according to nearest valid rule.|
|Payout rounding mismatch|First place absorbs final 10-unit reconciliation.|
|Nine-player final table trigger repeated|Use idempotent final-table state; create only one redraw.|
|Cash reconciliation mismatch|Require correction or explicit unresolved note before completion.|
|Notification permission denied|Use in-app notification inbox only.|
|Chat abuse|Rate limit, admin delete, sanitize text and block markup/scripts.|



19 

Poker Night MVP — Technical Specification 

## **22. Security and Privacy** 

- Use managed authentication, secure password reset and verified email where supported. 

- All authorization is enforced server-side. Never trust a role or game ID supplied only by the client. 

- Tournament codes are random, case-insensitive and exclude ambiguous characters. Rate-limit code lookup. 

- Guest sessions use scoped, expiring tokens tied to one guest record and one tournament. 

- Sanitize all chat, poll and name input. Store plain text in MVP. 

- Do not expose organizer amount, payout amounts or contribution identities in player/guest/TV responses. 

- Use HTTPS, secure cookies/token storage, CSRF protections where applicable and database row-level security. 

- Keep append-only game actions for audit and restore. Corrections create new actions. 

- Provide account deletion and group member removal. Retain anonymized completed-game integrity where legally appropriate. 

- Apply rate limits to login, code lookup, guest reservation, chat and voting. 

## **23. Testing and Acceptance Criteria** 

### **23.1 Engine tests** 

- Property test: every generated blind and ante is payable with active chip denominations. 

- Property test: starting and rebuy stack totals equal their declared value. 

- Exact-inventory test: total allocated chips never exceed configured quantities. 

- Property test: blind sequence is strictly increasing and contains no removed level after an accepted revision. 

- Property test: level duration is always 10, 15 or 20. 

- Property test: payouts total exactly the Prize Pool and all payouts are multiples of 10. 

- Property test: KO bounty money never enters regular prize pool or organizer calculation. 

- Simulation test: generated finish estimate falls within a reasonable calibrated range for representative fields. 

### **23.2 User-flow acceptance scenarios** 

|**Scenario**|**Pass condition**|
|---|---|
|Create and run standard tournament|Admin creates 8-player, 3.5-hour tournament, confirms<br>generated structure, publishes, checks in players, runs timer,<br>closes rebuys, records add-ons, finishes and publishes podium.|
|Guest check-in|Player RSVP is Going +2; both guests use code, choose distinct<br>slots, admin confirms, seats appear.|
|Live speed adjustment|At level end projected finish is 30 minutes late; admin previews<br>Speed Up, accepts 15→10 starting next level, TV and player<br>views update.|
|Offline recovery|Admin loses connection, pauses and records elimination locally,<br>reloads browser, restores game and later synchronizes without<br>duplicate actions.|
|TV privacy|TV code shows live game but response payload contains no<br>organizer, payout or participant contribution data.|
|Cash reconciliation|Admin records two buy-ins, one top-up and two cash-outs;<br>completion succeeds only when totals reconcile or note is<br>saved.|



### **23.3 Definition of done** 

- All required screens work responsively at common phone, tablet, desktop and TV widths. 

20 

Poker Night MVP — Technical Specification 

- Core flows pass automated and manual acceptance tests. 

- No private financial fields appear in player, guest or TV network responses. 

- Admin can restore an active game after browser refresh and temporary connection loss. 

- Production deployment, environment configuration, database migrations and seed/demo data are documented. 

- Source code, setup instructions and basic architecture notes are delivered. 

## **24. Deployment and Operations** 

- Separate development and production environments. 

- Environment variables for backend URL, auth keys, push credentials and error monitoring. 

- Automated database migrations or documented schema deployment. 

- HTTPS production domain and PWA manifest/service worker. 

- Basic error monitoring and structured server logs without sensitive payloads. 

- Daily managed database backups when available. 

- Seed group and demo tournament for acceptance testing. 

## **25. Deferred Features and Future Phases** 

|**Deferred feature**|**Reason**|
|---|---|
|Native iOS/Android apps|Duplicate client cost; PWA proves product first.|
|Spotify|Removed from scope.|
|Dedicated casting SDKs|TV browser/link is sufficient for MVP.|
|Multiple administrators|Requires conflict resolution and complex permissions.|
|Advanced tournament health simulation|MVP uses lightweight recalculation.|
|Premium voices and voice commands|Standard English browser voice is sufficient.|
|Friends, feed, achievements, seasons|Not core to tournament operation.|
|Advanced player financial statistics|Privacy and complexity; explicitly excluded.|
|Full offline multi-device sync|High conflict and networking complexity.|
|Advanced cash-game features|Cash mode is intentionally minimal.|
|Payment processing|Regulatory and operational complexity.|



21 

