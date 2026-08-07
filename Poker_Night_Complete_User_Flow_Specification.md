POKER NIGHT  /  USER FLOW SPECIFICATION 

# ♠ 

## Poker Ni ht <u>g</u> 

#### **Complete User Flow & Experience Specification** 

_Admin • Registered Group Member • New Guest_ 

###### **DOCUMENT PURPOSE** 

This document defines the complete tournament journey from group creation to final results. It explains what each user sees, what each user can do, what the system must calculate, and how the three roles interact. It is written for product, design, development and QA teams. 

Version 1.0  |  6 August 2026 

1 

POKER NIGHT  /  USER FLOW SPECIFICATION 

### **Contents** 

1. Purpose and Product Model 

2. Roles, Terminology and Permissions 

3. Event Lifecycle and Shared Rules 

4. Admin End-to-End User Flow 

5. Registered Group Member User Flow 

6. Complete New Guest User Flow 

7. Shared Tournament Flows 

8. Screen and Navigation Specification 

9. Contextual Main Button Logic 

10. Notifications and Communication 

11. Privacy, Visibility and Data Projection 

12. Validation, Errors, Recovery and Edge Cases 

13. UX Principles and Design Guidance 

14. End-to-End Acceptance Scenarios 

Appendix A. Sample Event 

Appendix B. Glossary 

2 



CHAT + POLLS Members only 

GROUP Permanent community EVENTS TOURNAMENT EVENT LIVE TOURNAMENT RESULTS + HISTORY Upcoming poker nights RSVP, check-in, setup Timer, blinds, admin actions Paid positions, no public amounts 



POKER NIGHT  /  USER FLOW SPECIFICATION 

|**Area**|**Purpose**|
|---|---|
|Events|Upcoming and completed poker nights.|
|Polls|Group decisions such as date, time, buy-in or location.|
|History|Completed events and basic non-financial statistics.|
|Settings|Group defaults, saved chip sets and tournament presets.|



### **2. Roles, Terminology and Permissions** 

##### **2.1 Role Names** 

|**Role**|**Definition**|
|---|---|
|Admin|The person who creates the group or event and operates the tournament.<br>One admin controls each tournament in the MVP.|
|Registered Group Member|A signed-in user who belongs to the group, can use chat and polls, can<br>RSVP and can follow the live tournament.|
|New Guest|A person without an account who is invited as someone’s +1, +2, +3 or +4.<br>The guest receives limited event-only web access.|



###### **TERMINOLOGY CORRECTION** 

A signed-in person who is part of the group chat should not be called a guest. In the product and design, call this person a Registered Group Member. “Guest” should mean an unregistered event-only participant. 

##### **2.2 High-Level Permission Matrix** 

|**Capability**|**Admin**|**Registered Member**|**New Guest**|
|---|---|---|---|
|Create group|Yes|No|No|
|Create/publish event|Yes|No|No|
|See private group chat|Yes|Yes|No|
|Create/respond to polls|Yes|Yes|No|
|RSVP to event|Admin may attend|Yes|No direct RSVP|
|Invite guest slots|Yes|Yes through Going +N|No|
|Claim guest slot|Manual correction|No|Yes|
|Check in|Can check anyone in|Self check-in|Self check-in request|
|See live timer/blinds|Yes|Yes|Yes|
|Record elimination/rebuy/add-on|Yes|No|No|
|See private financial calculation|Yes|No|No|
|See chat during event|Yes|Yes|No|
|See final paid positions|Yes|Yes|Yes|
|See final payout amounts|Yes|No|No|



4 





Create group Create + publish event Manage RSVPs Open check-in 



<!-- Start of picture text -->
Generate final structure<br><!-- End of picture text -->

Rebuy + add-on break Final table + results 

POKER NIGHT  /  USER FLOW SPECIFICATION 

##### **4.3 Create a Tournament Event** 

The admin taps “Create Event”. Creation should be a short guided wizard rather than one long settings page. 

###### **Step 1 — Event Details** 

|**Field**|**Behaviour**|
|---|---|
|Tournament name|Required. Example: Friday Poker Night.|
|Date|Required.|
|Start time|Required.|
|Location|Optional. May be text, address or private note visible only to<br>confirmed participants.|
|Buy-in|Required numeric value, displayed without currency symbol.|
|Target duration|Required. Default 3.5 hours; options 3, 3.5, 4, 4.5, 5, 5.5 and 6<br>hours.|



**Step 2 — Tournament Options** 

|**Option**|**Rule**|
|---|---|
|Rebuys|On by default. Only after elimination. Unlimited by default.|
|Rebuy closes|End of selected level; default end of Level 6.|
|Rebuy cost|Defaults to original buy-in.|
|Add-on|Admin selects yes/no and price. Maximum one per active player.|
|KO bounty|No bounty or bounty amount. Bounty money is separate from the<br>normal Prize Pool.|
|Ante preference|Let Poker Night recommend, No ante, Big blind ante or Individual<br>ante.|
|Equipment, drinks & snacks|Private organizer percentage; never shown to players and never<br>called rake.|



###### **Step 3 — Event Preview and Publish** 

Before publishing, the admin previews the exact card that group members will see. The card should be concise, friendly and readable in the chat feed. 

**SAMPLE GROUP EVENT CARD** 

♠️ Friday Poker Night 

- 📅 Friday, 14 August 

🕗 20:00 

📍 Campo Grande 

💵 Buy-in: 15 

- 🔁 Rebuys until end of Level 6 

- ➕ Add-on available 

🎯 KO Bounty: 5 

7 

POKER NIGHT  /  USER FLOW SPECIFICATION 

⏱ Target duration: 3h 30m 

When the admin taps Publish Event, the system must: 

- Add the event to the group Events tab. 

- Post and pin the event card in the group chat. 

- Notify group members. 

- Open RSVP responses. 

##### **4.4 Monitor RSVPs** 

The admin sees a live attendance summary separated into confirmed members, guest slots, Maybe, Can’t Come and No Response. The interface must show both people and seats; one Going +2 response represents three expected players. 

|**Category**|**Meaning**|
|---|---|
|Confirmed members|Registered members who selected Going or Going +N.|
|Confirmed guest slots|All guest slots created by Going +1 through Going +4.|
|Maybe|Not counted in the confirmed player total.|
|Can’t Come|Visible but excluded from preparation.|
|No response|Members who have not yet answered.|
|Expected attendance|Confirmed registered members plus confirmed guest slots.|



##### **4.5 Configure the Physical Chip Set** 

Chip configuration may be prepared before the event or shortly before check-in closes. The admin chooses one of three paths. 

###### **Option A — Saved Chip Set** 

Select a reusable chip set already stored in the group, including colours, values and optional exact quantities. 

###### **Option B — Exact Inventory** 

- Select or create each chip colour. 

- Indicate whether the chip is printed or unnumbered. 

- Enter a unique value. 

- Enter exact quantity available. 

- System guarantees that the proposed starting stacks, rebuy reserve and add-on reserve fit the inventory. 

###### **Option C — Quick Automatic Setup** 

- Select available colours. 

- Indicate numbered or unnumbered chips. 

- Enter printed values where applicable. 

- Drag colours from most available to least available. 

- For unnumbered chips, Poker Night proposes unique values; two colours may never share a value. 

- System shows required quantities and asks the admin to confirm that enough chips exist. 

8 

POKER NIGHT  /  USER FLOW SPECIFICATION 

##### **4.6 Event-Day Preparation** 

On the day of the tournament, Home and the event page should present a preparation checklist. The admin should never have to remember the correct sequence. 

- Review event information and any recent changes. 

- Open check-in. 

- Confirm chip set and inventory. 

- Review expected late arrivals. 

- Prepare starting stacks. 

- Reserve rebuy and add-on chips. 

- Open TV Mode if required. 

- Test voice announcements. 

##### **4.7 Check-in Management** 

- **→** Admin taps Open Check-in. 

- **→** Registered members and guests see the Check In action. 

- **→** Requests appear in the admin queue. 

- **→** Admin confirms each request, or checks a person in manually. 

- **→** The system assigns a table and seat only after confirmation. 

- **→** The admin can view confirmed-but-absent people, pending guests, Maybe arrivals and expected late arrivals. 

##### **4.8 Generate the Final Tournament Structure** 

The event may have a provisional recommendation earlier, but the final structure is generated only when the admin confirms actual attendance and final chip availability. 

|**Input**|**Use**|
|---|---|
|Checked-in players|Primary player count used for the final calculation.|
|Expected late arrivals|May be included if the admin confirms they will arrive before late<br>registration closes.|
|Target duration|Selected event duration.|
|Physical chip set|Colours, values and availability.|
|Rebuys and add-ons|Expected additional chips and timing.|
|Ante preference|Recommended or admin-selected format.|



The generated result must include: 

- Starting stack and opening blinds 

- Starting depth in big blinds 

- Full blind progression 

- Level duration of 10, 15 or 20 minutes 

- Starting-stack chip recipe 

- Rebuy stack recipe, which may use larger denominations later while preserving the same total value 

- Estimated add-on recommendation 

- Ante type and activation level 

- Number of tables and random seat assignment 

9 

POKER NIGHT  /  USER FLOW SPECIFICATION 

- Initial dealer position 

- Estimated finishing window 

- Inventory warnings and colour-up instructions 

**RECOMMENDED STRUCTURE EXAMPLE** 10 players • 3h 30m target Starting stack: 10,000 Opening blinds: 50 / 100 Starting depth: 100 BB Level duration: 15 minutes Rebuys close: end of Level 6 Big blind ante: begins Level 7 Expected finish: 23:25–23:50 

##### **4.9 Start the Tournament** 

- **→** Admin reviews and confirms the generated structure. 

- **→** Players receive table and seat assignments. 

- **→** TV Mode becomes available through its read-only URL/code. 

- **→** The initial dealer position is displayed and may be announced. 

- **→** Admin taps Start Tournament. 

- **→** The timer begins and all connected views synchronise. 

##### **4.10 Admin Live Screen** 

The live admin screen must prioritise speed and error prevention. The most-used controls remain visible; uncommon or dangerous actions are secondary. 

|**Always visible**|**Secondary menu**|**Destructive / confirmation required**|
|---|---|---|
|Large timer|Adjust time|Restart current level|
|Current blinds and ante|Make announcement|Finish tournament|
|Next blinds|Edit future structure|Cancel tournament|
|Players remaining|Rebuy/add-on management||
|Average stack|TV Mode||
|Prize Pool status|Undo recent action||
|Pause/resume|Seat management||
|Next level|||



##### **4.11 Player Actions During Play** 

The admin opens Players, selects one person and sees only actions valid for that person and tournament phase. 

- View or change seat 

- Eliminate player 

- Eliminate and rebuy, if the rebuy period is open 

- Undo elimination 

10 

POKER NIGHT  /  USER FLOW SPECIFICATION 

- Record one add-on during the settlement break 

- Mark final position 

##### **4.12 Elimination and Rebuy Flow** 

- **→** Admin selects a player and taps Eliminate. 

- **→** Before the rebuy deadline, the system asks: Leave Tournament or Rebuy? 

- **→** If Rebuy is selected, the player normally remains in the same seat. 

- **→** The player receives a rebuy stack with the same total value as the original starting stack. 

- **→** The physical rebuy stack may use larger denominations that are practical for the current level. 

- **→** After the deadline, the player is permanently eliminated and their finishing position is stored. 

- **→** Every elimination and rebuy action can be undone. 

##### **4.13 End-of-Rebuy and Add-on Break** 

This is a dedicated operational flow, not an ordinary timed break. The app guides the admin through each required task. 

- **→** The selected rebuy level ends, normally Level 6. 

- **→** The timer pauses automatically. 

- **→** Rebuys and late registration close permanently. 

- **→** No new player can be added. 

- **→** Admin records any final valid rebuy from a hand that began before the deadline. 

- **→** Poker Night calculates the recommended add-on stack from average stack, big blind, remaining players, total chips and target finish. 

- **→** Admin selects each active player who purchases the one permitted add-on. 

- **→** Poker Night displays chip-exchange and colour-up instructions. 

- **→** Admin confirms ante activation or keeps antes off. 

- **→** The final Prize Pool and private payouts are recalculated. 

- **→** Admin confirms settlement complete and manually starts the next level. 

##### **4.14 Live Structure Adjustments** 

The system may recommend changes when actual pace differs materially from the target, but it never changes the tournament automatically. 

- Future levels may change from 20 to 15 minutes, 15 to 10 minutes, 10 to 15 minutes or 15 to 20 minutes. 

- An intermediate future blind level may be inserted. 

- Future blind growth may be softened or accelerated. 

- Ante activation may be moved earlier or later. 

- Existing or completed levels are never removed. 

- The admin sees old structure, proposed structure, current predicted finish and proposed predicted finish before confirmation. 

##### **4.15 Table Balancing** 

The interface uses clear lists, not a graphical poker table. When tables become unbalanced, the system proposes a move and waits for admin confirmation. 

11 





<!-- Start of picture text -->
Open ink QR /code Craimguest io<br>REGISTERED GROUP MEMBER<br>See event RSVP Check in Receive seat Follow live game View results<br><!-- End of picture text -->

POKER NIGHT  /  USER FLOW SPECIFICATION 

- Buy-in 

- Rebuy closing level and cost 

- Add-on availability and price 

- KO bounty status and amount 

- Target duration 

- Host/admin 

- RSVP deadline 

##### **5.3 RSVP** 

- **→** Member selects one response: Going, Going +1/+2/+3/+4, Maybe or Can’t Come. 

- **→** Going +N automatically creates N named but unclaimed guest slots. 

- **→** Member can share the event link, QR code or code with the invited guests. 

- **→** The response may be changed until one hour before the start time. 

##### **5.4 Pre-Event Experience** 

- Receive event updates and RSVP reminders. 

- Use group chat and polls. 

- See whether check-in is open. 

- Review location, start time and tournament rules. 

- See whether invited guest slots have been claimed. 

##### **5.5 Check In** 

- **→** Member arrives and opens the event. 

- **→** Taps Check In. 

- **→** The request enters the admin queue. 

- **→** After admin confirmation, the member receives table and seat. 

- **→** The main button changes to View My Seat, then Open Live Tournament. 

##### **5.6 Live Registered Member View** 

|**Visible**|**Not visible / not permitted**|
|---|---|
|Large timer|Admin controls|
|Current blinds and ante|Organizer percentage or amount|
|Next blinds|Rebuy/add-on totals|
|Players remaining|Individual payout amounts|
|Average stack|Individual chip stacks|
|Table and seat|Other players’ private actions|
|Estimated Prize Pool, then Prize Pool|Self-recording elimination/rebuy/add-on|
|Announcements||
|Chat and polls||



13 

POKER NIGHT  /  USER FLOW SPECIFICATION 

##### **5.7 After Elimination** 

An eliminated registered member remains part of the event experience. They may continue to follow the timer, players remaining, Prize Pool, announcements, chat and polls. The interface must clearly mark them as eliminated without hiding the event. 

##### **5.8 After the Tournament** 

- See the winner and every paid finishing position. 

- Do not see payout amounts. 

- See the completed event in group History. 

- See basic group-level non-financial statistics. 

### **6. Complete New Guest User Flow** 

##### **6.1 Receive Event Access** 

The new guest receives a shared event link, QR code or event code from a registered member who selected Going +1, Going +2, Going +3 or Going +4. No account is required. 

##### **6.2 Open Guest Landing Page** 

The guest sees a friendly, event-specific landing page rather than a full application dashboard. 

**SAMPLE GUEST LANDING** You’ve been invited to Friday Poker Night ♠️ Friday, 14 August • 20:00 Campo Grande Buy-in: 15 • Rebuys until Level 6 • KO 5 Primary action: Claim My Guest Place 

##### **6.3 Identify Inviter and Claim Slot** 

- **→** Guest selects “Who invited you?” 

- **→** System displays only registered members who currently have unclaimed guest slots. 

- **→** Guest selects one available slot, for example Alex’s Guest 2. 

- **→** Guest enters their name and confirms. 

- **→** The slot becomes reserved and cannot be claimed twice. 

- **→** Admin may correct or remove the reservation. 

##### **6.4 Before Arrival** 

The same event link remembers or securely resolves the claimed slot. The guest can see event details, inviter, guest name, current check-in status and the Check In button when check-in opens. 

- No access to group chat 

- No access to polls 

- No access to group History or member profiles 

- Optional prompt to create an account and join the group 

14 

POKER NIGHT  /  USER FLOW SPECIFICATION 

##### **6.5 Guest Check-in** 

- **→** Guest arrives and taps Check In. 

- **→** Admin receives the request. 

- **→** Admin confirms the guest. 

- **→** Guest receives table and seat. 

- **→** Main button changes to Open Live Tournament. 

##### **6.6 Limited Guest Live View** 

|**Guest sees**|**Guest does not see**|
|---|---|
|Timer|Group chat|
|Current blinds and ante|Polls|
|Next blinds|Group History|
|Players remaining|Admin controls|
|Average stack|Organizer information|
|Own table and seat|Rebuy/add-on totals|
|Announcements|Payout amounts|
|Estimated Prize Pool, then Prize Pool|Individual chip stacks|



##### **6.7 After the Tournament** 

- See the winner and all paid positions without money amounts. 

- Optionally create an account. 

- Optionally request to join the group. 

- After admin approval, the guest result may be linked to the new account. 

### **7. Shared Tournament Flows** 

##### **7.1 Invitation and Guest-Slot Logic** 

- Only a Going +N response creates guest slots. 

- Each guest slot has a stable identifier, inviter, position number, status and optional guest name. 

- Statuses: Unclaimed, Reserved, Check-in Requested, Checked In, Cancelled. 

- An inviter changing Going +2 to Going +1 must not silently remove a checked-in guest. The admin must resolve the conflict. 

- Duplicate slot claims are blocked server-side. 

- A guest may switch to another free slot only before check-in or with admin approval. 

##### **7.2 Contextual Main Button** 

Each event page should present one dominant next action. This is the simplest way to make the application feel intelligent and reduce navigation errors. 

|**Role**|**State**|**Primary button**|
|---|---|---|
|Admin|Draft|Edit Event|
|Admin|Published|Review RSVPs|



15 

POKER NIGHT  /  USER FLOW SPECIFICATION 

|**Role**|**State**|**Primary button**|
|---|---|---|
|Admin|Check-in available|Open Check-in|
|Admin|Attendance confirmed|Generate Final Structure|
|Admin|Ready|Start Tournament|
|Admin|Live|Manage Tournament|
|Admin|Rebuy break|Complete Rebuy & Add-on Break|
|Admin|Finished|View Results|
|Registered Member|No RSVP|Respond to Invitation|
|Registered Member|RSVP submitted|Update RSVP|
|Registered Member|Check-in open|Check In|
|Registered Member|Check-in pending|Waiting for Confirmation|
|Registered Member|Checked in|View My Seat|
|Registered Member|Live|Open Live Tournament|
|Registered Member|Finished|View Results|
|New Guest|Unclaimed|Claim My Guest Place|
|New Guest|Slot reserved|View Invitation|
|New Guest|Check-in open|Check In|
|New Guest|Check-in pending|Waiting for Confirmation|
|New Guest|Checked in|View My Seat|
|New Guest|Live|Open Live Tournament|
|New Guest|Finished|View Results|



##### **7.3 TV Mode** 

TV Mode is a separate read-only route opened through a TV code, QR code or direct URL. It contains no controls and no private payout data. 

- Tournament name 

- Very large timer 

- Current blinds and ante 

- Next level 

- Players remaining 

- Average stack 

- Estimated Prize Pool or Prize Pool 

- Current visual announcement 

- No payout amounts, organizer information, chat or admin controls 

##### **7.4 Voice Announcements** 

Voice announcements are English-only in the initial release. The admin manually selects one Audio Master device; other devices remain silent. 

- Tournament starting 

- New level and blinds 

- Five minutes remaining 

- One minute remaining 

16 

POKER NIGHT  /  USER FLOW SPECIFICATION 

- Rebuys closed 

- Final table 

- Winner 

- Initial dealer name when generated 

##### **7.5 Chat and Polls** 

Chat and polls belong to the permanent group, not the unregistered guest experience. An event may automatically create a pinned event card in chat and may link to a related poll. Registered members remain in chat after elimination. 

### **8. Screen and Navigation Specification** 

|**Admin screen**|**Purpose**|
|---|---|
|Home|Next action, active/upcoming event, pending check-ins, recent<br>chat/poll.|
|Group Chat|Messages, pinned event cards and event links.|
|Events|Upcoming, live and completed events.|
|Create Event Wizard|Event details, options, preview and publish.|
|RSVP Dashboard|Members, guest slots, Maybe, Can’t Come and No Response.|
|Chip Set|Saved, exact inventory and quick automatic modes.|
|Check-in Queue|Pending requests, checked-in people and absences.|
|Final Structure Review|Stacks, blinds, levels, chips, tables and expected finish.|
|Live Tournament|Timer and primary admin controls.|
|Players|Check-in, seating, elimination, rebuy, add-on and undo.|
|Structure|Upcoming levels and approved future edits.|
|Rebuy/Add-on Break|Guided settlement workflow.|
|Prize Calculation|Private collected amount, organizer amount, Prize Pool and<br>payouts.|
|Final Table Redraw|Randomised nine-player seat list and dealer position.|
|Results|Final positions and private payout confirmation.|
|History|Completed events and basic statistics.|



##### **8.1 Registered Member Screens** 

|**Member screen**|**Purpose**|
|---|---|
|Group Home|Chat, events, polls and history.|
|Event Details|Rules, RSVP and updates.|
|RSVP|Single response selection including Going +N.|
|Guest Slots|Status of slots created by the member.|



17 

POKER NIGHT  /  USER FLOW SPECIFICATION 

|**Member screen**|**Purpose**|
|---|---|
|Check-in|Request, pending and confirmed states.|
|Seat|Table and seat assignment.|
|Live Tournament|Timer, blinds, average stack, Prize Pool, chat and polls.|
|Results|Paid positions without money.|



##### **8.2 New Guest Screens** 

|**Guest screen**|**Purpose**|
|---|---|
|Code / Link / QR Entry|Resolve a valid event invitation.|
|Guest Landing|Basic event information and Claim My Guest Place.|
|Choose Inviter|Only people with free guest slots.|
|Choose Slot|Available Guest 1/2/3/4 positions.|
|Guest Details|Name entry and reservation confirmation.|
|Check-in|Request, pending and confirmed states.|
|Seat|Table and seat.|
|Limited Live View|Timer, blinds, average stack, Prize Pool and announcements.|
|Results|Paid positions without money.|
|Create Account|Optional conversion to registered member.|



##### **8.3 Required System States** 

- Loading and skeleton states 

- Empty group, no events and no messages 

- No RSVP yet 

- Invalid, expired or revoked code 

- Guest slot already taken 

- Check-in closed 

- Waiting for admin confirmation 

- Offline admin mode 

- Disconnected player/guest/TV view 

- Reconnected and synchronised 

- Tournament paused 

- Tournament cancelled or rescheduled 

- Action failed and safe retry 

### **9. Contextual Main Button Logic** 

The main button must be calculated from role, event state, RSVP state and check-in state. It must never offer an action that is unavailable or irrelevant. Secondary navigation remains available, but the primary button should always answer “What should I do next?” 

**<mark>DESIGN RULE</mark>** 

18 

POKER NIGHT  /  USER FLOW SPECIFICATION 

One event, one dominant next action. The app should not make users choose among several equally prominent buttons. 

##### **9.1 Priority Rules** 

- **→** Blocking states take priority: invalid invitation, event cancelled, check-in closed or action awaiting admin approval. 

- **→** Before RSVP, the member sees Respond to Invitation. 

- **→** After RSVP but before check-in, the member sees Update RSVP or View Event. 

- **→** When check-in opens, Check In overrides ordinary event actions. 

- **→** After check-in, View My Seat is shown until the tournament becomes live. 

- **→** During play, Open Live Tournament is shown. 

- **→** After finish, View Results is shown. 

### **10. Notifications and Communication** 

##### **10.1 Admin Notifications** 

- New RSVP or RSVP change 

- Guest slot claimed or released 

- Check-in request 

- Player or guest arrived 

- Event starting soon 

- Tournament ready to generate 

- Rebuy period ending 

- Rebuy/add-on settlement required 

- Final-table redraw required 

- Incomplete final results 

- Realtime or recovery warning 

##### **10.2 Registered Member Notifications** 

- New event published 

- Event details changed 

- RSVP reminder 

- RSVP closes in one hour 

- Check-in opened 

- Check-in confirmed 

- Seat assigned 

- Tournament starting 

- Rebuys closed 

- Prize Pool confirmed 

- Final table reached 

- Tournament finished 

19 

POKER NIGHT  /  USER FLOW SPECIFICATION 

##### **10.3 New Guest Updates** 

An unregistered guest does not receive permanent group notifications. Event updates are shown through the event page and may also use a browser notification only after explicit permission. 

- Guest slot confirmed 

- Check-in opened 

- Check-in confirmed 

- Seat assigned 

- Tournament starting 

- Rebuys closed 

- Final table reached 

- Tournament finished 

##### **10.4 Event Change Behaviour** 

When the admin changes date, time, location, buy-in, bounty or another visible event rule after publication, the system must: 

- Store the change in the audit timeline. 

- Notify all affected registered members. 

- Show the updated value prominently on the event page. 

- Mark important changes in the pinned chat card. 

- Require the admin to confirm whether existing RSVPs remain valid for a major date/time change. 

### **11. Privacy, Visibility and Data Projection** 

|**Information**|**Admin**|**Registered Member**|**New Guest**|**TV**|
|---|---|---|---|---|
|Event date/time/location|Yes|Yes|Yes, event only|Yes where<br>appropriate|
|Buy-in/rebuy/add-on/bounty rules|Yes|Yes|Yes|No need on<br>TV|
|Timer/blinds/ante|Yes|Yes|Yes|Yes|
|Players remaining/average stack|Yes|Yes|Yes|Yes|
|Estimated Prize Pool / Prize Pool|Yes|Yes|Yes|Yes|
|Organizer percentage/amount|Yes|No|No|No|
|Rebuy/add-on totals|Yes|No|No|No|
|Individual payout amounts|Yes|No|No|No|
|Paid finishing positions|Yes|Yes after finish|Yes after finish|Optional<br>after finish|
|Group chat/polls|Yes|Yes|No|No|
|Admin controls/audit log|Yes|No|No|No|



##### **11.1 Location Privacy** 

Location is optional. The admin may choose whether the complete address is visible immediately to all group members or only to confirmed participants. A public-facing guest landing page should reveal only the location information explicitly approved for that event. 

20 

POKER NIGHT  /  USER FLOW SPECIFICATION 

##### **11.2 No Individual Stack Tracking** 

The system must not ask the admin or players to maintain every player’s current chip stack. It tracks total chips created by entries, rebuys and add-ons, then calculates average stack from total chips divided by active players. 

### **12. Validation, Errors, Recovery and Edge Cases** 

##### **12.1 Account and Group** 

- Invalid email, weak password, duplicate account and Google sign-in failure 

- Expired, revoked or already-used group invitation 

- User already belongs to the group 

- Admin attempts to delete a group with an active tournament 

##### **12.2 Event and RSVP** 

- Start time in the past 

- Missing required event name, date, time, buy-in or duration 

- RSVP submitted after the one-hour deadline 

- Member reduces guest count below the number of already claimed or checked-in guests 

- • Event cancelled or rescheduled after RSVP 

- Duplicate submission caused by repeated taps 

##### **12.3 Guest Access** 

- Invalid, expired or revoked event code 

- QR points to a non-existent or inaccessible event 

- Inviter has no free guest slots 

- Slot claimed by another guest during confirmation 

- Guest tries to access chat, polls or another event 

- Guest clears local browser storage and must safely re-identify the reservation 

##### **12.4 Chip and Structure Generation** 

- Duplicate chip values are rejected. 

- Insufficient inventory produces a shortage warning and alternative recommendations. 

- Blind values that cannot be posted practically are rejected. 

- Generated levels must never use a duration other than 10, 15 or 20 minutes. 

- The admin must be able to regenerate or edit inputs without losing event attendance. 

##### **12.5 Live Tournament** 

- Accidental double elimination or duplicate rebuy is blocked or easily undone. 

- Admin closes or refreshes the page; the active tournament recovers locally. 

- Temporary internet loss; admin continues locally while other views show connection status. 

- After reconnection, queued admin actions synchronise without duplication. 

- Timer drift is corrected from the authoritative timestamp, not by trusting every device’s local countdown. 

- A player arrives after late registration closes; the system prevents addition. 

- The tournament reaches nine players but began with one table; no unnecessary redraw occurs. 

21 

POKER NIGHT  /  USER FLOW SPECIFICATION 

##### **12.6 Safe Destructive Actions** 

- Finish Tournament requires confirmation and review of final positions. 

- Cancel Tournament requires confirmation and a reason. 

- Restart Level requires confirmation and displays its exact effect. 

- Undo shows the action that will be reversed. 

### **13. UX Principles and Design Guidance** 

##### **13.1 Product Principles** 

- One dominant next action per user and state. 

- The system does the calculation; the admin approves important decisions. 

- Registered users get social features; new guests get a simple event-only path. 

- The live admin experience prioritises speed, clarity and error prevention. 

- The player and guest experiences are simpler than the admin experience. 

- TV Mode is presentation-only. 

- No virtual poker table, cards, pot graphics or individual stack tracking. 

##### **13.2 Visual Hierarchy** 

- Timer, blinds and primary action have the strongest hierarchy during live play. 

- Gold is used selectively for primary actions and selected states, not for every border. 

- Purple may identify live/realtime states; green confirms success; red is reserved for destructive actions. 

- Use one consistent professional icon family; do not use emoji as interface icons. 

- Event cards may use restrained emojis in content because they improve readability and warmth. 

- Mobile layouts are designed independently, not as compressed desktop pages. 

##### **13.3 Mobile Live Admin** 

- Timer remains visible at the top. 

- Pause/resume and Next Level remain thumb-accessible. 

- Player actions open in bottom sheets. 

- Secondary actions remain behind Manage Tournament. 

- Dangerous actions remain visually separated. 

### **14. End-to-End Acceptance Scenarios** 

##### **14.1 Admin Happy Path** 

- **→** Admin creates Friday Night Poker group and invites members. 

- **→** Admin creates an event for Friday at 20:00, buy-in 15, rebuy close Level 6, add-on enabled, KO bounty 5, target 3.5 hours. 

- **→** Event appears in Events, is pinned in Chat and notifies members. 

- **→** Members submit RSVP responses and create guest slots. 

- **→** Admin configures an unnumbered chip set and confirms suggested values. 

- **→** On event day, admin opens check-in and confirms arrivals. 

- **→** Admin generates the final structure from actual attendance and chip availability. 

22 

POKER NIGHT  /  USER FLOW SPECIFICATION 

- **→** Admin starts the tournament and all views synchronise. 

- **→** Admin records eliminations and rebuys. 

- **→** At the end of Level 6, the system enters the settlement break and blocks new players. 

- **→** Admin records add-ons, confirms chip exchanges and confirms the final Prize Pool. 

- **→** Admin continues the tournament, confirms a final-table redraw at nine players and records final positions. 

- **→** Players and guests see paid positions without money; History updates. 

##### **14.2 Registered Member Happy Path** 

- **→** User joins the group and accesses Chat, Events and Polls. 

- **→** User sees the pinned event card and chooses Going +2. 

- **→** Two guest slots are created and the user shares the link. 

- **→** User receives a check-in notification, checks in and receives a seat. 

- **→** User follows the timer, blinds, players remaining, average stack and Prize Pool. 

- **→** User uses chat and polls during the tournament. 

- **→** After elimination, user continues following the event. 

- **→** After finish, user sees all paid positions without amounts. 

##### **14.3 New Guest Happy Path** 

- **→** Guest opens the event QR/link without creating an account. 

- **→** Guest selects the inviter and an available guest slot. 

- **→** Guest enters a name and reserves the slot. 

- **→** When check-in opens, guest requests check-in. 

- **→** Admin confirms and the guest receives a table and seat. 

- **→** Guest follows the limited live view and announcements. 

- **→** After finish, guest sees paid positions without money. 

- **→** Guest may create an account and request group membership. 

##### **14.4 Critical Failure Tests** 

- Two guests attempt to claim the same slot at the same time; only one succeeds. 

- A guest tries to open group chat through a copied URL; access is denied. 

- The admin refreshes during Level 4; timer and tournament state recover correctly. 

- Internet drops during play; the admin continues locally and synchronises once reconnected. 

- A generated structure attempts an 11-minute level; validation prevents it. 

- A member attempts to self-record a rebuy; the backend denies the action. 

- A public or guest response requests organizer amount or payout amounts; the backend omits them. 

- A new player is added after the rebuy deadline; the system blocks the action. 

### **Appendix A. Sample Event** 

##### **A.1 Published Event** 

<mark>♠</mark> **<mark>FRIDAY POKER NIGHT</mark>** 

23 

POKER NIGHT  /  USER FLOW SPECIFICATION 

📅 Friday, 14 August 

🕗 20:00 

📍 Campo Grande 

💵 Buy-in: 15 

🔁 Rebuys: only after elimination, until end of Level 6 

➕ Add-on: available, maximum one per active player 

🎯 KO Bounty: 5 

⏱ Target duration: 3h 30m 

RSVP: Going • Going +1/+2/+3/+4 • Maybe • Can’t Come 

##### **A.2 Example Attendance** 

|**Person**|**Response**|
|---|---|
|Alex|Going +2|
|Sarah|Going|
|Marco|Maybe|
|Daniel|Can’t Come|
|Confirmed total|2 registered players + 2 guest slots = 4 participants|



##### **A.3 Example Final Structure** 

|**Item**|**Generated result**|
|---|---|
|Players|10|
|Target duration|3h 30m|
|Starting stack|10,000|
|Opening blinds|50 / 100|
|Starting depth|100 BB|
|Level duration|15 minutes|
|Rebuys close|End of Level 6|
|Ante|Big blind ante from Level 7|
|Expected finish|23:25–23:50|



### **Appendix B. Glossary** 

|**Term**|**Meaning**|
|---|---|
|Admin|Person who creates and runs the group/event/tournament.|
|Registered Group Member|Signed-in user with permanent access to group chat, events and<br>polls.|



24 

POKER NIGHT  /  USER FLOW SPECIFICATION 

|**Term**|**Meaning**|
|---|---|
|New Guest|Unregistered event-only participant invited through a +N slot.|
|Group|Permanent private community.|
|Event|One scheduled poker night inside a group.|
|RSVP|Attendance response.|
|Guest slot|A temporary place created by Going +1 through Going +4.|
|Check-in|Arrival confirmation required before seat assignment.|
|Tournament structure|Starting stack, blinds, level durations, antes and related chip plan.|
|Rebuy|A new stack after elimination during the rebuy period.|
|Re-entry|Separate optional entry after elimination; secondary to the normal<br>rebuy flow.|
|Add-on|One optional additional stack available to each active player at the<br>end of the rebuy period.|
|KO bounty|Separate amount paid to the player who eliminates another player.|
|Prize Pool|The amount displayed to players after the private organizer amount<br>is removed.|
|TV Mode|Read-only large-screen presentation.|
|Audio Master|Single device selected to play voice announcements.|
|Final-table redraw|Random seating of nine remaining players when the tournament<br>began with multiple tables.|



###### **FINAL PRODUCT TEST** 

At every moment, each person should see only the information and action relevant to their role and current state. The admin controls the tournament, registered members participate in the group and event, and new guests follow a minimal event-only path. Complex tournament mathematics stays behind the scenes. 

25 

