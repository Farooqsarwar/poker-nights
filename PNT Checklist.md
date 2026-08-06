**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

# **POKER NIGHT** 

## **Final Feature, Function & Release Acceptance Checklist** 

**Website • Web App • Android • iOS • TV Mode • Tournament Engine • Cash Game** 

_Extremely detailed mutual verification document for developer delivery and client acceptance_ 



<!-- Start of picture text -->
Client Developer / Company<br>Contract / Platform Agreed fixed price<br>Planned delivery date Revision rounds<br>Post-launch bug-fix  Checklist version 1.0<br>period<br><!-- End of picture text -->

#### **FINAL PAYMENT CONDITION** 

**Every in-scope item must be implemented, functional, tested and delivered. No more and no less than the mutually approved checklist is required. Missing, placeholder or non-functional items do not count as complete.** 

Prepared: 2026-07-27 

Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 1 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **How to Use This Checklist** 

1. 1. The developer performs a complete internal test and marks the Developer box only after the item works in the agreed production-like build. 

2. 2. The client independently checks the same item and marks the Client box only after seeing the result or evidence. 

3. 3. The Evidence / Notes column should contain a URL, build number, video, screenshot, test account, defect ID or short explanation. 

4. 4. A blank Client box means the item is not accepted. A failed item must be corrected and retested. 

5. 5. N/A is allowed only when both parties approve a written exception. The exception must be listed in the final sign-off section. 

6. 6. A feature is not complete merely because the screen exists. The complete user flow, database action, realtime update, permissions, recovery and error handling must work. 7. 7. The final accepted build must match the source code and production deployment delivered to the client. 

Column key: Developer = developer self-verification. Client = client acceptance. Evidence / Notes = proof, defect reference or signed exception. 

### **Checklist Sections** 

8. 1. Acceptance Rules and Scope Lock 

9. 2. Delivery Package, Ownership and Project Access 

10. 3. Public Website and Browser Entry Points 

11. 4. Cross-Platform Application Shell and Design 

12. 5. Authentication, Accounts and Roles 

13. 6. Groups, Codes and Basic Settings 

14. 7. Invitations, RSVP, Guests and Check-In 

15. 8. Chat, Polls and Notifications 

16. 9. Tournament Presets and Game Creation 

17. 10. Chip Sets, Physical Inventory and Stack Preparation 

18. 11. Tournament Structure Engine 

19. 12. Live Tournament Administration 

20. 13. Seating, Tables and Final Table 

21. 14. Prize Pool, Organizer Amount, Bounties and Visibility 

22. 15. Player View, Guest View, TV Mode and Voice 

23. 16. Group Game History and Basic Statistics 

24. 17. Minimal Cash-Game Module 

25. 18. Realtime Synchronisation, Local Recovery and Offline Behaviour 

26. 19. Security, Privacy and Data Visibility 

27. 20. Validation, Errors and Edge Cases 

28. 21. UI Quality, Responsiveness and Accessibility 

29. 22. End-to-End User Acceptance Scenarios 

30. 23. Compatibility, Performance and Reliability 

31. 24. Deployment, App Stores and Production Launch 

32. 25. Baseline Payout Style Regression Checks 

33. 26. Final Defect Closure and Sign-Off 

Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 2 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **1. Acceptance Rules and Scope Lock** 

These checks define how the developer and client decide whether the product is complete. They apply to every platform and every feature in this document. 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**1.1 Contr**|**act and acceptance principles**||||
|**01-001**|The final agreed price, delivery date, revision count and post-launch support period are written into the contract before development<br>starts.|☐|☐||
|**01-002**|This checklist is attached to, linked from or explicitly incorporated into the official project agreement.|☐|☐||
|**01-003**|Every checklist item is treated as in scope unless both parties approve a written exception before final acceptance.|☐|☐||
|**01-004**|No feature may be silently removed, replaced, postponed, reduced to a mock-up or marked “coming soon”.|☐|☐||
|**01-005**|No additional feature outside this checklist is required unless both parties approve it in writing.|☐|☐||
|**01-006**|A feature counts as complete only when its full user flow works with real saved data, not only with demo data.|☐|☐||
|**01-007**|Buttons, links, menus, forms and controls that appear in the interface perform the described action.|☐|☐||
|**01-008**|There are no dead buttons, placeholder screens, lorem ipsum text, temporary links or unfinished navigation paths.|☐|☐||
|**01-009**|All calculations use production logic and are not manually hardcoded for a single test case.|☐|☐||
|**01-010**|The developer performs a complete self-check and marks the Developer column before client testing begins.|☐|☐||
|**01-011**|The client checks the same item independently and marks the Client column only after verifying it.|☐|☐||
|**01-012**|A failed item is recorded in the defect log with steps to reproduce, severity and responsible party.|☐|☐||
|**01-013**|An item may be marked N/A only through a written, mutually approved scope exception.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 3 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**01-014**|Evidence may include a live URL, screen recording, test account, screenshot, build file, repository link or automated test result.|☐|☐||
|**01-015**|Final payment is released only after every in-scope item passes, required evidence is delivered and all blocking defects are closed.|☐|☐||
|**01-016**|The developer may not require final payment merely because code exists if the agreed feature does not work end to end.|☐|☐||
|**01-017**|Minor cosmetic defects may be accepted only when they are recorded, do not block use and have a written correction date.|☐|☐||
|**01-018**|Security, data-loss, calculation, login, deployment and store-build defects are always blocking defects.|☐|☐||
|**01-019**|The client receives enough access and documentation to continue operating the product without the original developer.|☐|☐||
|**01-020**|All third-party accounts used for production are owned by or transferred to the client before acceptance.|☐|☐||
|**1.2 Final**|**product boundaries**||||
|**01-021**|The deliverable includes a public website, full browser web application, Android application, iOS application and read-only TV browser<br>view.|☐|☐||
|**01-022**|The Android, iOS and web applications use the same backend and show consistent data for the same game.|☐|☐||
|**01-023**|There is one administrator per game in this MVP; simultaneous multi-admin control is not required.|☐|☐||
|**01-024**|The only user categories are Administrator, Registered Player and Guest.|☐|☐||
|**01-025**|Spotify integration is not included.|☐|☐||
|**01-026**|Dedicated Chromecast, AirPlay or proprietary casting integration is not included; normal browser use and screen mirroring may be<br>used.|☐|☐||
|**01-027**|Actual payment processing, card charging, bank transfers and payment-status tracking are not included.|☐|☐||
|**01-028**|Poker Night records game contributions needed for calculations, but not whether a person physically paid.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 4 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**01-029**|Advanced player financial statistics, ROI, personal profit graphs and individual rebuy/add-on history are not included in player views.|☐|☐||
|**01-030**|Friends, social feeds, achievements, seasons and advanced leaderboards are not included.|☐|☐||
|**01-031**|Voice commands are not included; English voice announcements are included.|☐|☐||
|**01-032**|Poker Night does not deal cards, evaluate hands, track pots, identify hand winners or replace the human dealer.|☐|☐||
|**01-033**|Poker Night does not track ongoing dealer-button movement after initial seating or final-table redraw.|☐|☐||
|**01-034**|The cash-game section is intentionally simpler than the tournament section.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 5 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **2. Delivery Package, Ownership and Project Access** 

The product is not accepted until the client can access, build, deploy and operate every agreed part of it. 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**2.1 Sourc**|**e code and repositories**||||
|**02-001**|The client receives the complete source code for the website, web app, Android app, iOS app, backend functions and database<br>configuration.|☐|☐||
|**02-002**|All production source code is stored in a repository owned by the client or transferred to the client before final payment.|☐|☐||
|**02-003**|The repository includes meaningful commit history or, at minimum, a clean final commit with all files required to build the product.|☐|☐||
|**02-004**|No essential production file is kept only on the developer’s computer.|☐|☐||
|**02-005**|No source file is deliberately obfuscated, encrypted or withheld.|☐|☐||
|**02-006**|The client receives a list of all frameworks, packages, plugins and exact versions used.|☐|☐||
|**02-007**|The project builds from a fresh clone by following the written setup instructions.|☐|☐||
|**02-008**|All package lockfiles and dependency manifests are included.|☐|☐||
|**02-009**|Unused secrets, personal developer credentials and test keys are removed before handover.|☐|☐||
|**02-010**|Open-source licences are compatible with commercial use and listed in the documentation.|☐|☐||
|**2.2 Acco**|**unts and credentials**||||
|**02-011**|The client owns or controls the production hosting account.|☐|☐||
|**02-012**|The client owns or controls the production database/backend account.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 6 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**02-013**|The client owns or controls the production domain and DNS settings.|☐|☐||
|**02-014**|The client owns or controls the email-sending and notification configuration used in production.|☐|☐||
|**02-015**|The client owns the Google Play Console account used for release.|☐|☐||
|**02-016**|The client owns the Apple Developer and App Store Connect accounts used for release.|☐|☐||
|**02-017**|The developer receives only the minimum temporary permissions necessary to complete deployment.|☐|☐||
|**02-018**|Temporary developer access can be revoked without breaking the production product.|☐|☐||
|**02-019**|A secure credential handover document identifies where every production secret is stored.|☐|☐||
|**02-020**|No production password or API secret is placed directly inside public source code.|☐|☐||
|**2.3 Docu**|**mentation and handover**||||
|**02-021**|A README explains local setup, required tools, environment variables and how to run each platform.|☐|☐||
|**02-022**|A deployment guide explains how to deploy the website/web app and backend.|☐|☐||
|**02-023**|An Android release guide explains signing, AAB generation and Play Console upload.|☐|☐||
|**02-024**|An iOS release guide explains certificates, bundle ID, archive creation and App Store Connect upload.|☐|☐||
|**02-025**|A database document lists the main tables/collections, important fields and relationships.|☐|☐||
|**02-026**|A backup and restore guide explains how production data is backed up and recovered.|☐|☐||
|**02-027**|An admin user guide explains how to create a group, create a game, run a tournament and complete a cash session.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 7 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**02-028**|A known-limitations section lists only genuinely approved limitations, not unfinished features.|☐|☐||
|**02-029**|The developer provides a final walkthrough or screen recording showing the major user flows.|☐|☐||
|**02-030**|The client receives all design files, app icons, logos, images and editable assets created for the project.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 8 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **3. Public Website and Browser Entry Points** 

The public website must explain the product, provide entry to the web app and allow code/QR access without exposing private data. 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**3.1 Public**|**website pages**||||
|**03-001**|The production domain opens over HTTPS without certificate warnings.|☐|☐||
|**03-002**|The homepage loads without requiring login.|☐|☐||
|**03-003**|The homepage clearly identifies the product as Poker Night.|☐|☐||
|**03-004**|The homepage briefly explains tournament and cash-game functionality in understandable language.|☐|☐||
|**03-005**|The homepage contains a clear Log In button for registered users.|☐|☐||
|**03-006**|The homepage contains a clear Create Account button for new registered users.|☐|☐||
|**03-007**|The homepage contains a clearly visible “Enter Game Code” field or equivalent join action.|☐|☐||
|**03-008**|The website includes a Privacy Policy page reachable from the footer.|☐|☐||
|**03-009**|The website includes a Terms page reachable from the footer.|☐|☐||
|**03-010**|The website includes a Contact or Support method.|☐|☐||
|**03-011**|The website displays links to the Android and iOS applications once store URLs are available.|☐|☐||
|**03-012**|The website does not display Spotify, advanced statistics or other removed features.|☐|☐||
|**03-013**|The website uses the final approved branding, colours, typography and logo consistently.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 9 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**03-014**|All public pages have valid page titles and descriptions.|☐|☐||
|**03-015**|All public navigation links lead to the correct destination.|☐|☐||
|**03-016**|The public website is usable on small mobile screens, tablets and desktop browsers.|☐|☐||
|**3.2 Web a**|**pplication entry**||||
|**03-017**|Registered users can open the full web application from the public website.|☐|☐||
|**03-018**|An authenticated user returning to the web app remains signed in according to the approved session policy.|☐|☐||
|**03-019**|An unauthenticated user opening a protected route is redirected to login and returned to the intended route after login.|☐|☐||
|**03-020**|The web app is installable as a PWA when the browser supports installation.|☐|☐||
|**03-021**|The web app has a valid manifest, icon set and application name.|☐|☐||
|**03-022**|The web app does not show browser-console errors during normal use.|☐|☐||
|**03-023**|Refreshing a normal web-app page does not produce a server 404 error.|☐|☐||
|**03-024**|Deep links to a group or game route open the intended screen after authentication.|☐|☐||
|**3.3 Code**|**and QR access**||||
|**03-025**|Every created game receives a unique human-readable access code.|☐|☐||
|**03-026**|Every created game receives a QR code representing a valid HTTPS link.|☐|☐||
|**03-027**|Scanning the QR code with an iPhone camera opens the correct game landing page.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 10 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**03-028**|Scanning the QR code with a typical Android camera opens the correct game landing page.|☐|☐||
|**03-029**|The QR code remains readable when displayed on another phone, printed or shown on a TV.|☐|☐||
|**03-030**|The manual code entry produces the same destination as the QR link.|☐|☐||
|**03-031**|Codes are case-insensitive if letters are used.|☐|☐||
|**03-032**|Ambiguous characters are avoided or handled clearly.|☐|☐||
|**03-033**|Entering an invalid code shows a clear “Game not found” message and allows another attempt.|☐|☐||
|**03-034**|Entering an expired or closed-game code shows a clear state-specific message.|☐|☐||
|**03-035**|The public code page never exposes admin controls or private organizer data.|☐|☐||
|**03-036**|A guest can use the QR/code flow without creating an account.|☐|☐||
|**03-037**|A registered user opening a code can continue in the app/web app without losing the selected game.|☐|☐||
|**03-038**|If a native app is installed, supported deep links open the correct app screen; otherwise the web fallback works.|☐|☐||
|**03-039**|The developer demonstrates at least one real QR scan on iOS and one on Android before acceptance.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 11 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **4. Cross-Platform Application Shell and Design** 

The same core product must work consistently on web, Android and iOS while respecting each platform’s navigation and device behaviour. 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**4.1 Share**|**d application behaviour**||||
|**04-001**|The same registered account can sign in on web, Android and iOS.|☐|☐||
|**04-002**|A game created on one platform appears on the other platforms after synchronisation.|☐|☐||
|**04-003**|Game codes, group names, player names and results are identical across platforms.|☐|☐||
|**04-004**|The main navigation exposes only features included in this checklist.|☐|☐||
|**04-005**|The application has clear loading, empty, success and error states.|☐|☐||
|**04-006**|Back navigation does not accidentally discard saved data.|☐|☐||
|**04-007**|Unsaved form changes trigger a confirmation before being lost where appropriate.|☐|☐||
|**04-008**|Destructive actions require clear confirmation.|☐|☐||
|**04-009**|The user can sign out from every platform.|☐|☐||
|**04-010**|The app returns to a safe screen after an expired session.|☐|☐||
|**04-011**|The app does not freeze after repeated navigation between screens.|☐|☐||
|**04-012**|Date and time formatting is consistent and understandable.|☐|☐||
|**04-013**|Money values in game interfaces are normally shown without a currency symbol as approved.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 12 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**04-014**|KO amounts use the approved format such as “15 + 5”.|☐|☐||
|**04-015**|All user-facing English text is grammatically correct and free of obvious spelling errors.|☐|☐||
|**4.2 Andro**|**id application**||||
|**04-016**|A release-ready Android application is produced from the final source code.|☐|☐||
|**04-017**|The Android package name is unique and owned by the client.|☐|☐||
|**04-018**|The Android app icon and splash screen use final assets.|☐|☐||
|**04-019**|The Android app launches without a white-screen or startup crash.|☐|☐||
|**04-020**|Android back-button behaviour is logical and does not unexpectedly close active forms.|☐|☐||
|**04-021**|Android notification permission is requested only when needed and handled if denied.|☐|☐||
|**04-022**|The Android app handles backgrounding and reopening an active tournament without losing admin state.|☐|☐||
|**04-023**|The Android app is tested on at least one current phone-size device and one different screen size/emulator.|☐|☐||
|**04-024**|A signed Android App Bundle is delivered and can be uploaded to Play Console.|☐|☐||
|**4.3 iOS a**|**pplication**||||
|**04-025**|A release-ready iOS application is produced from the final source code.|☐|☐||
|**04-026**|The iOS bundle identifier is unique and owned by the client.|☐|☐||
|**04-027**|The iOS app icon and launch screen use final assets.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 13 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**04-028**|The iOS app launches without a blank screen or startup crash.|☐|☐||
|**04-029**|The iOS app handles safe areas, notches and home indicators correctly.|☐|☐||
|**04-030**|iOS notification permission is requested only when needed and handled if denied.|☐|☐||
|**04-031**|The iOS app handles backgrounding and reopening an active tournament without losing admin state.|☐|☐||
|**04-032**|The iOS app is tested on at least one current iPhone size and one additional size/simulator.|☐|☐||
|**04-033**|A release archive/build is delivered and can be uploaded to App Store Connect.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 14 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **5. Authentication, Accounts and Roles** 

Only three user categories exist. Permissions must be enforced by the backend, not only hidden in the interface. 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**5.1 Regis**|**tration and login**||||
|**05-001**|A new registered user can create an account using the approved authentication method.|☐|☐||
|**05-002**|Required registration fields are clearly marked.|☐|☐||
|**05-003**|Invalid email addresses are rejected with a clear message.|☐|☐||
|**05-004**|Password requirements are displayed before submission.|☐|☐||
|**05-005**|Duplicate accounts using the same email are handled safely.|☐|☐||
|**05-006**|A registered user can log in with valid credentials.|☐|☐||
|**05-007**|Invalid credentials do not reveal whether a specific account exists.|☐|☐||
|**05-008**|A user can request a password reset.|☐|☐||
|**05-009**|Password-reset links expire and cannot be reused after success.|☐|☐||
|**05-010**|A user can log out and protected data is no longer accessible on that device.|☐|☐||
|**05-011**|Authentication tokens are stored securely for each platform.|☐|☐||
|**05-012**|An account can update its display name.|☐|☐||
|**05-013**|Player display names are validated for length and unsupported characters.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 15 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**05-014**|A deleted or disabled account cannot continue using a stale session.|☐|☐||
|**5.2 Admi**|**nistrator role**||||
|**05-015**|The user who creates a group/game becomes its administrator.|☐|☐||
|**05-016**|The administrator can create, edit, start, run and complete games.|☐|☐||
|**05-017**|The administrator can manage players, guests, rebuys, add-ons, eliminations and seating.|☐|☐||
|**05-018**|The administrator can see private prize calculations and organizer amounts.|☐|☐||
|**05-019**|The administrator can create chat messages, polls and notifications.|☐|☐||
|**05-020**|The administrator can access cash-game reconciliation.|☐|☐||
|**05-021**|Only the administrator can perform admin actions for the game.|☐|☐||
|**05-022**|A player or guest cannot call admin API actions by manually changing a URL or request.|☐|☐||
|**05-023**|There is no unfinished assistant-admin or multi-admin interface in the MVP.|☐|☐||
|**5.3 Regis**|**tered player role**||||
|**05-024**|A registered player can join a group/game through the intended flow.|☐|☐||
|**05-025**|A registered player can respond to invitations.|☐|☐||
|**05-026**|A registered player can check themselves in when check-in is open.|☐|☐||
|**05-027**|A registered player can view public game information and their assigned seat.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 16 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**05-028**|A registered player can use chat and vote in polls.|☐|☐||
|**05-029**|A registered player can receive supported notifications.|☐|☐||
|**05-030**|A registered player cannot record a rebuy, add-on, elimination or payout.|☐|☐||
|**05-031**|A registered player cannot see organizer amounts or private contribution records.|☐|☐||
|**05-032**|A registered player cannot see individual prize amounts after the game.|☐|☐||
|**05-033**|A registered player cannot see personal financial statistics, personal rebuy history or personal add-on history.|☐|☐||
|**5.4 Guest**|**role**||||
|**05-034**|A guest can enter through the website code/QR flow without an account.|☐|☐||
|**05-035**|A guest can identify their inviter and select an available guest slot.|☐|☐||
|**05-036**|A guest can enter their name and request/check in.|☐|☐||
|**05-037**|A guest can view the timer, blinds, ante, announcements, table and seat after confirmation.|☐|☐||
|**05-038**|A guest cannot use chat or polls without registering.|☐|☐||
|**05-039**|A guest cannot access permanent group history or private player data.|☐|☐||
|**05-040**|A guest cannot perform admin actions.|☐|☐||
|**05-041**|A guest session is limited to the intended game and does not expose other groups.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 17 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **6. Groups, Codes and Basic Settings** 

Groups provide the reusable home for players, presets, chat, polls and game history. 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**6.1 Grou**|**p creation and access**||||
|**06-001**|An administrator can create a group with a valid name.|☐|☐||
|**06-002**|Group-name length and invalid characters are validated.|☐|☐||
|**06-003**|A newly created group receives a permanent group code or join mechanism.|☐|☐||
|**06-004**|The group code can be copied and shared.|☐|☐||
|**06-005**|A registered player can use the group code to reach the correct group join flow.|☐|☐||
|**06-006**|An invalid group code produces a clear error.|☐|☐||
|**06-007**|The administrator can see the current member list.|☐|☐||
|**06-008**|Duplicate group membership is prevented.|☐|☐||
|**06-009**|A user can belong to more than one group if supported by the navigation.|☐|☐||
|**06-010**|The administrator can edit the group name and basic settings.|☐|☐||
|**06-011**|Group data is isolated from unrelated groups.|☐|☐||
|**6.2 Grou**|**p home**||||
|**06-012**|The group home shows upcoming games.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 18 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**06-013**|The group home shows completed group game history.|☐|☐||
|**06-014**|The group home provides access to chat.|☐|☐||
|**06-015**|The group home provides access to polls.|☐|☐||
|**06-016**|The group home provides access to saved tournament presets.|☐|☐||
|**06-017**|The group home displays a clear create-game action for the administrator.|☐|☐||
|**06-018**|Players do not see admin-only controls.|☐|☐||
|**06-019**|Empty states explain what to do when there are no games, messages, polls or presets.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 19 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **7. Invitations, RSVP, Guests and Check-In** 

Attendance must be easy for registered players and guests, while preventing duplicate guest slots or late unauthorised changes. 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**7.1 Invita**|**tions and RSVP**||||
|**07-001**|The administrator can invite registered group members to a game.|☐|☐||
|**07-002**|An invited registered player can select exactly one RSVP option.|☐|☐||
|**07-003**|The options are Going, Going +1, Going +2, Going +3, Going +4, Maybe and Cannot Come.|☐|☐||
|**07-004**|Going counts as one confirmed person.|☐|☐||
|**07-005**|Going +1 counts as the registered player plus one guest.|☐|☐||
|**07-006**|Going +2 counts as the registered player plus two guests.|☐|☐||
|**07-007**|Going +3 counts as the registered player plus three guests.|☐|☐||
|**07-008**|Going +4 counts as the registered player plus four guests.|☐|☐||
|**07-009**|Maybe does not count as a confirmed player for final setup.|☐|☐||
|**07-010**|Cannot Come does not count toward attendance.|☐|☐||
|**07-011**|The player can change the RSVP until one hour before the scheduled start time.|☐|☐||
|**07-012**|After the one-hour cutoff, the player sees that changes are closed.|☐|☐||
|**07-013**|The administrator can see each RSVP and the calculated confirmed-person total.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 20 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**07-014**|Guest slots are created according to the selected +guest RSVP.|☐|☐||
|**07-015**|Changing from Going +3 to Going +1 removes or closes the extra unused guest slots safely.|☐|☐||
|**07-016**|The game setup can use confirmed attendance and an administrator override before starting.|☐|☐||
|**7.2 Guest**|**identification and check-in**||||
|**07-017**|A guest entering the game code sees the list of people who declared guest slots.|☐|☐||
|**07-018**|The guest selects the person who invited them.|☐|☐||
|**07-019**|The guest selects one available slot such as Guest 1 or Guest 2.|☐|☐||
|**07-020**|A slot already confirmed by another guest cannot be selected again.|☐|☐||
|**07-021**|A slot temporarily selected on another device is protected from duplicate confirmation.|☐|☐||
|**07-022**|The guest enters a valid display name.|☐|☐||
|**07-023**|The guest submits the check-in request.|☐|☐||
|**07-024**|The administrator sees the pending guest with inviter and slot.|☐|☐||
|**07-025**|The administrator can approve the guest check-in.|☐|☐||
|**07-026**|The administrator can reject or correct an incorrect guest check-in.|☐|☐||
|**07-027**|A guest is not treated as fully checked in until admin confirmation.|☐|☐||
|**07-028**|After approval, the guest sees the correct game and check-in state.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 21 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**07-029**|The administrator can manually check in a guest if needed.|☐|☐||
|**07-030**|A guest who refreshes the page can recover the same approved guest session on that device.|☐|☐||
|**07-031**|A guest cannot claim a slot after late registration closes.|☐|☐||
|**7.3 Regis**|**tered-player check-in**||||
|**07-032**|A registered player can check themselves in while check-in/registration is open.|☐|☐||
|**07-033**|The administrator can check in a registered player manually.|☐|☐||
|**07-034**|Duplicate check-in does not create duplicate entries.|☐|☐||
|**07-035**|The check-in dashboard distinguishes invited, confirmed, maybe, checked-in and absent people.|☐|☐||
|**07-036**|Checked-in totals include approved guests.|☐|☐||
|**07-037**|Only checked-in players receive seats when seating is generated.|☐|☐||
|**07-038**|A checked-in player sees their table and seat after assignment.|☐|☐||
|**07-039**|Late registration remains open only until the configured closing level, normally the end of Level 6.|☐|☐||
|**07-040**|No player or guest can be added after late registration closes.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 22 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **8. Chat, Polls and Notifications** 

These social features are required for registered users but intentionally simple for the MVP. 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**8.1 Chat**|||||
|**08-001**|Each group has a text chat available to registered members.|☐|☐||
|**08-002**|Registered players can send plain-text messages.|☐|☐||
|**08-003**|The administrator can send plain-text messages.|☐|☐||
|**08-004**|Guests cannot access chat without registering.|☐|☐||
|**08-005**|Messages show sender name and time.|☐|☐||
|**08-006**|Messages appear in chronological order.|☐|☐||
|**08-007**|New messages synchronise to other online registered users.|☐|☐||
|**08-008**|Empty messages cannot be sent.|☐|☐||
|**08-009**|Excessively long messages are limited with a clear validation message.|☐|☐||
|**08-010**|Repeated send taps do not create duplicate messages.|☐|☐||
|**08-011**|Chat remains usable on mobile and web layouts.|☐|☐||
|**08-012**|Image, audio and file uploads are not required.|☐|☐||
|**08-013**|Deleted or disabled users do not expose private credentials through chat records.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 23 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**8.2 Polls**|||||
|**08-014**|The administrator can create a poll in a group.|☐|☐||
|**08-015**|A poll has a clear question and at least two options.|☐|☐||
|**08-016**|Empty or duplicate options are rejected.|☐|☐||
|**08-017**|Registered players can vote in an open poll.|☐|☐||
|**08-018**|Guests cannot vote through the guest website.|☐|☐||
|**08-019**|A player cannot create duplicate votes unless vote changing is intentionally enabled.|☐|☐||
|**08-020**|If vote changing is allowed, the latest selection replaces the earlier one rather than adding another vote.|☐|☐||
|**08-021**|Poll totals update for authorised users.|☐|☐||
|**08-022**|The administrator can close a poll.|☐|☐||
|**08-023**|Closed polls no longer accept votes.|☐|☐||
|**08-024**|Polls can be used for date, time, buy-in, KO option, duration, location or a custom question.|☐|☐||
|**08-025**|Attendance RSVP remains separate from ordinary polls.|☐|☐||
|**08-026**|A poll result can be used to suggest a matching tournament preset.|☐|☐||
|**8.3 Notific**|**ations**||||
|**08-027**|Registered users can receive an invitation notification.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 24 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**08-028**|Registered users can receive an RSVP reminder where configured.|☐|☐||
|**08-029**|Registered users can receive a game-start reminder.|☐|☐||
|**08-030**|Registered users can receive a check-in/open-registration notification.|☐|☐||
|**08-031**|Registered users can receive important admin announcements.|☐|☐||
|**08-032**|Registered users can receive a poll-created notification.|☐|☐||
|**08-033**|Notifications link to the correct group or game screen.|☐|☐||
|**08-034**|Denied notification permission does not break the app.|☐|☐||
|**08-035**|Notification preferences or a basic enable/disable control are available if implemented.|☐|☐||
|**08-036**|A notification is not sent multiple times for one event unless explicitly repeated by the administrator.|☐|☐||
|**08-037**|Web, Android and iOS notification behaviour is tested in supported environments.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 25 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **9. Tournament Presets and Game Creation** 

The administrator enters only the necessary event and game preferences. The engine generates the playable structure. 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**9.1 Tourn**|**ament preset management**||||
|**09-001**|The administrator can create a named tournament preset.|☐|☐||
|**09-002**|A preset can store buy-in, KO bounty setting, rebuy setting, add-on setting, duration, chip set, organizer percentage and ante<br>preference.|☐|☐||
|**09-003**|A preset does not store a permanently fixed blind structure; the structure is regenerated for actual attendance and chips.|☐|☐||
|**09-004**|The administrator can edit a preset.|☐|☐||
|**09-005**|The administrator can delete a preset after confirmation.|☐|☐||
|**09-006**|Using a preset pre-fills the creation form correctly.|☐|☐||
|**09-007**|A matching preset is suggested when poll results and expected attendance align with it.|☐|☐||
|**09-008**|When two presets match, the administrator can choose between the best candidates.|☐|☐||
|**09-009**|The administrator can ignore a suggested preset and start from scratch.|☐|☐||
|**9.2 Event**|**details**||||
|**09-010**|The administrator can enter a tournament name.|☐|☐||
|**09-011**|The tournament name is required and validated for length.|☐|☐||
|**09-012**|The administrator can select a date.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 26 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**09-013**|The administrator can select a start time.|☐|☐||
|**09-014**|The administrator can enter or select a location.|☐|☐||
|**09-015**|The administrator can enter the expected number of players or use calculated attendance.|☐|☐||
|**09-016**|Expected player count must be a positive whole number.|☐|☐||
|**09-017**|The administrator can select a target duration of 3, 3.5, 4, 4.5, 5, 5.5 or 6 hours.|☐|☐||
|**09-018**|The default target duration is 3.5 hours.|☐|☐||
|**09-019**|The application explains that duration is an estimate rather than a guaranteed finish time.|☐|☐||
|**9.3 Finan**|**cial and format inputs**||||
|**09-020**|The administrator can enter a numeric buy-in without a currency symbol.|☐|☐||
|**09-021**|Buy-in accepts only valid non-negative numeric input according to the approved format.|☐|☐||
|**09-022**|KO bounty is off by default unless a preset changes it.|☐|☐||
|**09-023**|When KO bounty is enabled, the administrator enters the bounty amount separately.|☐|☐||
|**09-024**|The combined display uses a format such as “15 + 5”.|☐|☐||
|**09-025**|Rebuy is on by default.|☐|☐||
|**09-026**|The default rebuy closing point is the end of Level 6.|☐|☐||
|**09-027**|The administrator can select another allowed rebuy closing level before the game starts.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 27 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**09-028**|Default rebuy price equals the buy-in.|☐|☐||
|**09-029**|The administrator can change the rebuy price.|☐|☐||
|**09-030**|Re-entry can be enabled as a separate, secondary option.|☐|☐||
|**09-031**|Add-on can be enabled or disabled.|☐|☐||
|**09-032**|The administrator enters only the add-on price; the engine recommends the chip amount.|☐|☐||
|**09-033**|Default add-on price equals the buy-in.|☐|☐||
|**09-034**|The administrator can enter an organizer percentage for equipment, drinks and snacks.|☐|☐||
|**09-035**|The interface never labels the organizer percentage as rake.|☐|☐||
|**09-036**|The administrator can enable or disable antes.|☐|☐||
|**09-037**|When enabled, Big Blind Ante is the default type.|☐|☐||
|**09-038**|The administrator can select Individual Ante instead.|☐|☐||
|**9.4 Creati**|**on review and generation**||||
|**09-039**|The creation form validates all required fields before generation.|☐|☐||
|**09-040**|The administrator can save progress or safely return to previous steps without losing entered values.|☐|☐||
|**09-041**|The selected chip set is shown before generation.|☐|☐||
|**09-042**|The engine receives actual expected player count, duration, chip information and tournament options.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 28 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**09-043**|A loading state is shown while the structure is generated.|☐|☐||
|**09-044**|A generation failure shows a clear retryable error without losing inputs.|☐|☐||
|**09-045**|The generated review shows starting stack, chip composition, opening blinds, all levels, break/settlement point, ante plan and<br>estimated finish.|☐|☐||
|**09-046**|The administrator can accept the generated structure.|☐|☐||
|**09-047**|The administrator can regenerate after changing inputs.|☐|☐||
|**09-048**|The administrator can edit future blind values and allowed level durations before starting.|☐|☐||
|**09-049**|The administrator cannot create an impossible structure that requires unavailable chip values without receiving a warning.|☐|☐||
|**09-050**|The final accepted structure is saved with the game and used on every platform.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 29 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **10. Chip Sets, Physical Inventory and Stack Preparation** 

The chip system must work with numbered or unnumbered home sets and produce physically usable stacks. 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**10.1 Sav**|**ed chip sets**||||
|**10-001**|The administrator can create a reusable chip-set preset.|☐|☐||
|**10-002**|A chip set has a unique name within the group or clear duplicate handling.|☐|☐||
|**10-003**|The administrator can add any number of chip colours within practical UI limits.|☐|☐||
|**10-004**|Every chip colour has exactly one tournament value after configuration.|☐|☐||
|**10-005**|Two colours are never allowed to share the same value.|☐|☐||
|**10-006**|The administrator can edit a saved chip set.|☐|☐||
|**10-007**|The administrator can delete an unused chip set after confirmation.|☐|☐||
|**10-008**|A chip set used by past games remains historically understandable after later edits.|☐|☐||
|**10.2 Exa**|**ct inventory mode**||||
|**10-009**|The administrator can select Exact Inventory mode.|☐|☐||
|**10-010**|For each colour, the administrator can choose/enter a colour label.|☐|☐||
|**10-011**|For numbered chips, the administrator enters the printed numeric value.|☐|☐||
|**10-012**|The administrator enters the exact quantity available for each colour.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 30 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**10-013**|Chip quantities accept only whole numbers of zero or more.|☐|☐||
|**10-014**|Chip values accept only valid positive numbers.|☐|☐||
|**10-015**|Duplicate values are blocked.|☐|☐||
|**10-016**|The engine does not allocate more chips than the entered inventory.|☐|☐||
|**10-017**|The review shows used and remaining quantities for each colour.|☐|☐||
|**10.3 Quic**|**k inventory mode**||||
|**10-018**|The administrator can select Quick Inventory mode.|☐|☐||
|**10-019**|The administrator can indicate whether chips are numbered or unnumbered.|☐|☐||
|**10-020**|For numbered chips, printed values are entered even when exact quantities are not entered.|☐|☐||
|**10-021**|For unnumbered chips, the administrator selects the available colours.|☐|☐||
|**10-022**|The administrator can order colours from most available to least available by drag-and-drop or equivalent control.|☐|☐||
|**10-023**|The engine recommends unique values for unnumbered colours.|☐|☐||
|**10-024**|The most available colour is assigned to the denomination expected to be used most, not automatically always the lowest value.|☐|☐||
|**10-025**|The administrator can review and change recommended values before generation.|☐|☐||
|**10-026**|The app shows the number of chips required for the generated setup.|☐|☐||
|**10-027**|Because quantities are estimated, the administrator must confirm that enough physical chips exist.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 31 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**10-028**|If the administrator reports a shortage, the app allows regeneration with a simpler allocation.|☐|☐||
|**10.4 Start**|**ing-stack generation**||||
|**10-029**|The starting stack and opening blinds are calculated together rather than using a fixed minimum stack.|☐|☐||
|**10-030**|The stack is practical for the selected tournament duration and player count.|☐|☐||
|**10-031**|The stack uses only configured chip values.|☐|☐||
|**10-032**|The stack can be assembled from the available inventory.|☐|☐||
|**10-033**|The stack contains enough small chips to post early blinds without constant change.|☐|☐||
|**10-034**|The stack avoids an unnecessarily large number of physical chips.|☐|☐||
|**10-035**|The stack is easy to count and visually practical.|☐|☐||
|**10-036**|The engine shows the exact number of each colour per player.|☐|☐||
|**10-037**|The engine shows the total number of each colour needed for all starting players.|☐|☐||
|**10-038**|The engine reserves inventory for expected/relevant rebuys and add-ons where possible.|☐|☐||
|**10-039**|The engine warns when the chip set cannot support the expected game.|☐|☐||
|**10.5 Reb**|**uy stacks and chip exchanges**||||
|**10-040**|A rebuy always has the same total chip value as the starting stack.|☐|☐||
|**10-041**|A later rebuy may use more high-value chips and fewer obsolete low-value chips.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 32 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**10-042**|A rebuy stack still contains denominations usable for the current blinds.|☐|☐||
|**10-043**|The administrator sees the exact physical chip composition for a rebuy at the current level.|☐|☐||
|**10-044**|The system provides clear colour-up/exchange instructions such as exchanging a specific number of one colour for another.|☐|☐||
|**10-045**|Exact exchanges are preferred whenever possible.|☐|☐||
|**10-046**|Small indivisible remainders can be rounded upward under the default home-game method.|☐|☐||
|**10-047**|Any upward rounding is recorded in total chips in play.|☐|☐||
|**10-048**|A formal chip race may be offered as an advanced alternative but is not required as the default.|☐|☐||
|**10-049**|The system never recommends exchanging two colours that have the same value.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 33 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **11. Tournament Structure Engine** 

The engine is the product’s core value. It must generate a coherent, physically playable structure rather than select a fixed template. 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**11.1 Inpu**|**ts and invariants**||||
|**11-001**|The engine uses player count, target duration, chip values, chip availability mode, rebuy settings, add-on settings and ante settings.|☐|☐||
|**11-002**|The engine uses a formula-based or search-based approach rather than a single hardcoded blind table.|☐|☐||
|**11-003**|The engine produces the same result for the same saved inputs and algorithm version unless randomness is intentionally<br>documented.|☐|☐||
|**11-004**|Every generated blind can be posted using active chip denominations without unreasonable change-making.|☐|☐||
|**11-005**|Level duration is always exactly 10, 15 or 20 minutes.|☐|☐||
|**11-006**|The default aim is one consistent level duration throughout the tournament.|☐|☐||
|**11-007**|A structure may use different 10/15/20-minute phases only when justified by the target duration and clearly shown.|☐|☐||
|**11-008**|No generated structure contains a 12-minute, 18-minute or other unsupported level length.|☐|☐||
|**11-009**|The engine does not assume the big blind is always exactly twice the small blind.|☐|☐||
|**11-010**|Values such as 20/50 or 1,200/2,500 are allowed when they improve physical usability and progression.|☐|☐||
|**11-011**|Blind labels are easy to read and announce.|☐|☐||
|**11-012**|The engine avoids huge early blind jumps.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 34 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**11-013**|The engine does not create a future level lower than the preceding level.|☐|☐||
|**11-014**|The full structure contains enough levels to support the expected game without requiring level removal.|☐|☐||
|**11.2 Ope**|**ning blinds and starting depth**||||
|**11-015**|Opening blinds are chosen from the configured chip set rather than fixed globally.|☐|☐||
|**11-016**|Possible openings may include 5/10, 10/20, 25/50, 50/100 or another practical pair.|☐|☐||
|**11-017**|The engine avoids openings that require denominations not available.|☐|☐||
|**11-018**|The engine balances starting depth, target duration and physical chip count.|☐|☐||
|**11-019**|A fixed 5,000 minimum is not imposed when a different stack/blind pair is mathematically better.|☐|☐||
|**11-020**|The generated starting depth avoids immediate push/fold play.|☐|☐||
|**11-021**|The generated structure aims for meaningful early play through the rebuy period.|☐|☐||
|**11-022**|The structure review displays starting stack in chips and starting depth in big blinds.|☐|☐||
|**11.3 Blind**|**progression**||||
|**11-023**|The progression increases pressure gradually in early levels.|☐|☐||
|**11-024**|The progression can accelerate later to reach the target finish.|☐|☐||
|**11-025**|Every level is ordered correctly and uniquely identified.|☐|☐||
|**11-026**|The next-level display always matches the saved structure.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 35 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**11-027**|When a new denomination becomes necessary, the structure supports a practical exchange point.|☐|☐||
|**11-028**|The engine can insert an intermediate blind level when a jump would otherwise be too large.|☐|☐||
|**11-029**|The engine never automatically removes or skips an existing approved level.|☐|☐||
|**11-030**|The engine estimates expected finish time and displays it as an estimate.|☐|☐||
|**11-031**|The engine includes the rebuy-close/settlement point in its duration model.|☐|☐||
|**11-032**|The engine accounts for ante pressure when antes are enabled.|☐|☐||
|**11.4 Level**|**timing and clock plan**||||
|**11-033**|Every level has a saved duration of 10, 15 or 20 minutes.|☐|☐||
|**11-034**|The selected target duration is 3 to 6 hours in approved half-hour steps.|☐|☐||
|**11-035**|The default target is 3.5 hours.|☐|☐||
|**11-036**|The system explains when the exact target cannot be guaranteed because poker eliminations vary.|☐|☐||
|**11-037**|The settlement break after the rebuy period has no fixed countdown duration.|☐|☐||
|**11-038**|The tournament remains paused until the administrator confirms settlement is complete.|☐|☐||
|**11-039**|Future duration changes begin from the next level, never by shortening the active level.|☐|☐||
|**11.5 Ante**|**s**||||
|**11-040**|A tournament can run with no ante.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 36 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**11-041**|Big Blind Ante is the default ante format when antes are enabled.|☐|☐||
|**11-042**|The default Big Blind Ante amount equals the current big blind unless the generated structure specifies another approved practical<br>amount.|☐|☐||
|**11-043**|Big Blind Ante remains active at the final table and heads-up by default.|☐|☐||
|**11-044**|Individual Ante is available as the second ante type.|☐|☐||
|**11-045**|Individual Ante is calculated approximately from the big blind divided by expected table size and rounded to an active denomination.|☐|☐||
|**11-046**|The engine recalculates expected pressure and finish time when an ante is enabled.|☐|☐||
|**11-047**|The engine warns if the selected ante would make the game substantially faster than the target.|☐|☐||
|**11-048**|Antes normally begin after the rebuy period, usually after Level 6, unless the approved generated structure says otherwise.|☐|☐||
|**11.6 Engi**|**ne output review**||||
|**11-049**|The review shows every level in order.|☐|☐||
|**11-050**|The review shows small blind, big blind, ante type/amount and level duration for each level.|☐|☐||
|**11-051**|The review identifies the rebuy-closing level.|☐|☐||
|**11-052**|The review identifies expected chip exchanges.|☐|☐||
|**11-053**|The review shows starting-stack composition.|☐|☐||
|**11-054**|The review shows rebuy-stack guidance.|☐|☐||
|**11-055**|The review shows the estimated finish time/range.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 37 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**11-056**|The administrator can return to inputs and regenerate.|☐|☐||
|**11-057**|The administrator can accept and lock the pre-start structure.|☐|☐||
|**11-058**|The accepted structure is identical on admin, player and TV views.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 38 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **12. Live Tournament Administration** 

The administrator must be able to run the complete game from one clear control screen and safely correct mistakes. 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**12.1 Pre-**|**start checks**||||
|**12-001**|The admin dashboard shows tournament name, start time, expected duration and current status.|☐|☐||
|**12-002**|The dashboard shows checked-in player count.|☐|☐||
|**12-003**|The dashboard shows unconfirmed guests and unresolved attendance issues.|☐|☐||
|**12-004**|The dashboard shows whether seating has been generated.|☐|☐||
|**12-005**|The dashboard shows the accepted blind structure.|☐|☐||
|**12-006**|The dashboard shows the required starting-stack preparation.|☐|☐||
|**12-007**|The Start Tournament action is disabled or warns when critical setup is incomplete.|☐|☐||
|**12-008**|Starting the tournament records a reliable server timestamp and local recovery state.|☐|☐||
|**12-009**|The admin can confirm the initial dealer position generated by the system.|☐|☐||
|**12.2 Cloc**|**k controls**||||
|**12-010**|The administrator can start the tournament clock.|☐|☐||
|**12-011**|The administrator can pause the clock.|☐|☐||
|**12-012**|The administrator can resume the clock.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 39 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**12-013**|The timer does not lose or gain material time after pause/resume cycles.|☐|☐||
|**12-014**|The timer is calculated from timestamps rather than relying only on a drifting local interval.|☐|☐||
|**12-015**|The administrator can move to the next level after confirmation where appropriate.|☐|☐||
|**12-016**|The current level number, blinds, ante and remaining time update together.|☐|☐||
|**12-017**|The next-level information updates immediately after a level change.|☐|☐||
|**12-018**|When time reaches zero, the application transitions/alerts according to the approved flow without skipping data updates.|☐|☐||
|**12-019**|The clock remains readable when the admin device is locked/unlocked or backgrounded, subject to platform limits.|☐|☐||
|**12-020**|An accidental double-tap does not advance two levels.|☐|☐||
|**12-021**|Critical clock actions are added to the audit/event history.|☐|☐||
|**12.3 Play**|**er additions and late registration**||||
|**12-022**|The administrator can add a registered player while late registration is open.|☐|☐||
|**12-023**|The administrator can approve/add a guest while late registration is open.|☐|☐||
|**12-024**|A late player receives a full fresh starting stack.|☐|☐||
|**12-025**|The late player is assigned to the recommended balanced table and an available seat after confirmation.|☐|☐||
|**12-026**|Adding a player recalculates total chips, average stack and estimated finish.|☐|☐||
|**12-027**|The system may recommend future blind or level-duration changes but never applies them automatically.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 40 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**12-028**|Late registration closes permanently at the end of the rebuy period.|☐|☐||
|**12-029**|No admin override can add another player after the closing confirmation in this MVP.|☐|☐||
|**12.4 Elim**|**ination and rebuy**||||
|**12-030**|Only the administrator can mark a player eliminated.|☐|☐||
|**12-031**|Elimination requires selecting the correct active player.|☐|☐||
|**12-032**|An eliminated player is removed from players remaining.|☐|☐||
|**12-033**|Average stack and players remaining update after elimination.|☐|☐||
|**12-034**|If rebuys are open, an eliminated player can receive a rebuy.|☐|☐||
|**12-035**|A rebuy is allowed only after elimination/zero chips.|☐|☐||
|**12-036**|Rebuys are unlimited by default unless the game setting says otherwise.|☐|☐||
|**12-037**|The rebuy stack total value equals the original starting stack.|☐|☐||
|**12-038**|The UI shows the current-level physical rebuy composition.|☐|☐||
|**12-039**|Recording a rebuy returns the player to active status.|☐|☐||
|**12-040**|The player normally keeps the same seat when available.|☐|☐||
|**12-041**|The rebuy contributes to total chips and private prize calculations.|☐|☐||
|**12-042**|The administrator can undo an incorrect elimination.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 41 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**12-043**|The administrator can undo an incorrect rebuy without corrupting later state.|☐|☐||
|**12-044**|Undo restores player status, counts, total chips and calculations consistently.|☐|☐||
|**12.5 Re-e**|**ntry**||||
|**12-045**|Re-entry is available only when enabled before the game.|☐|☐||
|**12-046**|Re-entry is treated separately from the normal rebuy record.|☐|☐||
|**12-047**|A re-entering player receives the approved entry stack.|☐|☐||
|**12-048**|A re-entering player receives an available seat according to seating rules.|☐|☐||
|**12-049**|Re-entry closes with late registration/rebuys.|☐|☐||
|**12-050**|Re-entry contributes to private prize calculations.|☐|☐||
|**12-051**|The admin can correct an incorrectly recorded re-entry.|☐|☐||
|**12.6 End-**|**of-rebuy settlement**||||
|**12-052**|When the configured final rebuy level ends, the tournament clock pauses.|☐|☐||
|**12-053**|The app clearly announces that rebuys and late registration are closing.|☐|☐||
|**12-054**|The settlement screen opens or is clearly accessible.|☐|☐||
|**12-055**|No fixed break countdown is imposed.|☐|☐||
|**12-056**|The administrator can record final eligible rebuys from hands that began before closure, according to the approved process.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 42 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**12-057**|The administrator can select add-on purchasers from active players.|☐|☐||
|**12-058**|Each active player can receive no more than one add-on.|☐|☐||
|**12-059**|Every active player is eligible for one add-on by default.|☐|☐||
|**12-060**|The system displays the recommended add-on chip value and physical composition.|☐|☐||
|**12-061**|The administrator can override the add-on amount after seeing a warning/impact summary.|☐|☐||
|**12-062**|Recorded add-ons increase total chips and private prize calculations.|☐|☐||
|**12-063**|The settlement screen displays required chip exchanges/colour-ups.|☐|☐||
|**12-064**|The settlement screen confirms the ante type and activation for the next phase.|☐|☐||
|**12-065**|Late registration, rebuys and re-entry are permanently closed after final confirmation.|☐|☐||
|**12-066**|The administrator explicitly confirms settlement completion.|☐|☐||
|**12-067**|The next level starts only when the administrator manually resumes/starts it.|☐|☐||
|**12-068**|The public “Estimated Prize Pool” changes to “Prize Pool” after settlement confirmation.|☐|☐||
|**12-069**|The administrator can correct settlement entries before final confirmation.|☐|☐||
|**12-070**|After confirmation, corrections require an explicit admin correction flow and audit record.|☐|☐||
|**12.7 Live**|**pace changes**||||
|**12-071**|The administrator can open a Speed Up control during the game.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 43 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**12-072**|The administrator can open a Slow Down control during the game.|☐|☐||
|**12-073**|The system can recommend a pace change based on current progress.|☐|☐||
|**12-074**|A recommendation explains the reason and estimated finish impact.|☐|☐||
|**12-075**|The preview compares the current future structure with the proposed future structure.|☐|☐||
|**12-076**|Speed Up may reduce future 20-minute levels to 15 or future 15-minute levels to 10.|☐|☐||
|**12-077**|Speed Up may enable an already permitted ante or increase future blind pressure.|☐|☐||
|**12-078**|Slow Down may increase future 10-minute levels to 15 or future 15-minute levels to 20.|☐|☐||
|**12-079**|Slow Down may insert an intermediate future blind level or delay an ante.|☐|☐||
|**12-080**|No live pace action changes the active level duration.|☐|☐||
|**12-081**|No live pace action removes an approved level.|☐|☐||
|**12-082**|Every pace change requires explicit admin confirmation.|☐|☐||
|**12-083**|Cancelling the preview leaves the structure unchanged.|☐|☐||
|**12-084**|Accepted changes synchronise to player and TV views.|☐|☐||
|**12-085**|The accepted change is recorded in the audit/event history.|☐|☐||
|**12.8 Com**|**pleting and correcting a tournament**||||
|**12-086**|The administrator can record final finishing positions.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 44 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**12-087**|The complete paid podium can contain more than three positions.|☐|☐||
|**12-088**|The administrator can correct a finishing position before final completion.|☐|☐||
|**12-089**|Completing the tournament stops the clock and closes live controls.|☐|☐||
|**12-090**|The completed game appears in group history.|☐|☐||
|**12-091**|Public/player completed results show paid positions without amounts.|☐|☐||
|**12-092**|The admin retains access to private calculations.|☐|☐||
|**12-093**|An accidental completion requires a clear controlled reopen/correction flow or support-safe mechanism.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 45 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **13. Seating, Tables and Final Table** 

Seating must be transparent, random when requested and easy for the admin to confirm physically. 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**13.1 Initia**|**l seating**||||
|**13-001**|The administrator can choose Fully Random seating.|☐|☐||
|**13-002**|The administrator can choose Manual seating.|☐|☐||
|**13-003**|The administrator can choose to keep guests with their inviter.|☐|☐||
|**13-004**|The administrator can choose to separate guests from their inviter.|☐|☐||
|**13-005**|Skill-balanced seating is not included.|☐|☐||
|**13-006**|The default maximum table size is 9 unless a supported setting changes it.|☐|☐||
|**13-007**|Up to 9 checked-in players can be seated at one table.|☐|☐||
|**13-008**|More than 9 checked-in players create multiple tables automatically.|☐|☐||
|**13-009**|No player is assigned twice.|☐|☐||
|**13-010**|No two players are assigned to the same seat at the same table.|☐|☐||
|**13-011**|Every checked-in active player receives exactly one seat.|☐|☐||
|**13-012**|The initial dealer position is randomly assigned and clearly shown.|☐|☐||
|**13-013**|The administrator confirms physical seating before play starts.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 46 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**13-014**|Players/guests see only their own table and seat plus allowed public information.|☐|☐||
|**13.2 Tabl**|**e balancing**||||
|**13-015**|The system detects when table sizes become meaningfully unbalanced.|☐|☐||
|**13-016**|The system recommends which player should move and the destination table/seat.|☐|☐||
|**13-017**|The recommendation is understandable to the administrator.|☐|☐||
|**13-018**|No move is applied until the administrator confirms it.|☐|☐||
|**13-019**|After confirmation, source and destination seats update consistently.|☐|☐||
|**13-020**|Cancelling a recommendation changes nothing.|☐|☐||
|**13-021**|A manually chosen move is validated to prevent duplicate seats.|☐|☐||
|**13-022**|Players affected by a confirmed move see the updated seat.|☐|☐||
|**13.3 Fina**|**l-table redraw**||||
|**13-023**|If the tournament used multiple tables, final-table redraw is triggered when 9 players remain.|☐|☐||
|**13-024**|The game pauses for the redraw.|☐|☐||
|**13-025**|All 9 remaining players are randomly assigned to final-table seats.|☐|☐||
|**13-026**|A random initial dealer-button position is assigned for the final table.|☐|☐||
|**13-027**|The admin sees the full redraw and confirms physical seating.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 47 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**13-028**|Player and guest views show updated seats after confirmation.|☐|☐||
|**13-029**|Voice may announce final-table seating and dealer if audio is enabled.|☐|☐||
|**13-030**|The game resumes only after admin confirmation.|☐|☐||
|**13-031**|If the tournament began and remained one table, an unnecessary redraw is not forced.|☐|☐||
|**13-032**|The system does not track subsequent physical dealer-button rotation.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 48 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **14. Prize Pool, Organizer Amount, Bounties and Visibility** 

All monetary calculations must reconcile exactly while public/player views remain intentionally limited. 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**14.1 Cont**|**ribution calculations**||||
|**14-001**|The regular prize-pool calculation includes original buy-ins.|☐|☐||
|**14-002**|The regular prize-pool calculation includes rebuys.|☐|☐||
|**14-003**|The regular prize-pool calculation includes re-entries.|☐|☐||
|**14-004**|The regular prize-pool calculation includes add-ons.|☐|☐||
|**14-005**|KO bounty amounts are excluded from the regular prize pool.|☐|☐||
|**14-006**|KO bounty amounts are excluded from the organizer percentage calculation.|☐|☐||
|**14-007**|All contribution records required for calculation are visible only to the administrator.|☐|☐||
|**14-008**|Poker Night does not record whether cash was physically paid.|☐|☐||
|**14-009**|The displayed player count reflects unique players, not contribution count.|☐|☐||
|**14.2 Orga**|**nizer percentage and rounding**||||
|**14-010**|The admin interface calls the field “Percentage retained for equipment, drinks and snacks” or equivalent approved wording.|☐|☐||
|**14-011**|The word rake is not used in the product UI.|☐|☐||
|**14-012**|The organizer percentage applies to buy-in, rebuy, re-entry and add-on money.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 49 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**14-013**|The calculation shows total eligible contributions, requested percentage, exact amount, recommended rounded amount and resulting<br>prize pool to the admin.|☐|☐||
|**14-014**|The algorithm prefers a rounded organizer amount that leaves a clean prize pool distributable in tens.|☐|☐||
|**14-015**|For an eligible total of 165 and a target near 10%, retaining 15 and producing a prize pool of 150 is accepted.|☐|☐||
|**14-016**|If two rounded choices are equally close, the system prefers retaining less and returning more to the prize pool.|☐|☐||
|**14-017**|The admin can review the rounding adjustment before final confirmation.|☐|☐||
|**14-018**|Players and guests never see the organizer percentage or retained amount.|☐|☐||
|**14.3 Paid**|**places and payout generation**||||
|**14-019**|The number of paid places depends on a combination of unique players and final prize pool.|☐|☐||
|**14-020**|The payout structure is fair and meaningfully differentiates positions.|☐|☐||
|**14-021**|The last paid place may be below the original buy-in when required for the fairest structure.|☐|☐||
|**14-022**|Payout amounts are normally multiples of 10.|☐|☐||
|**14-023**|Payouts ending in 5 such as 55, 65 or 75 are avoided.|☐|☐||
|**14-024**|All payout amounts sum exactly to the final prize pool.|☐|☐||
|**14-025**|First place receives the largest payout.|☐|☐||
|**14-026**|No lower place receives more than a higher place.|☐|☐||
|**14-027**|The engine can produce 1, 2, 3, 4 or more paid places when appropriate.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 50 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**14-028**|The supplied baseline payout schedule from 50 to 700 is used as the intended style/reference.|☐|☐||
|**14-029**|The admin can review the full private payout calculation before completing the game.|☐|☐||
|**14-030**|The admin may manually adjust payouts while the app validates that the full prize pool still reconciles.|☐|☐||
|**14-031**|Equal split, chip-count split, ICM/custom deal or leave-something-for-first controls are included only if present in the final agreed build;<br>otherwise no inactive deal buttons appear.|☐|☐||
|**14.4 Bou**|**nties**||||
|**14-032**|A KO tournament displays the buy-in and bounty separately, such as 15 + 5.|☐|☐||
|**14-033**|The bounty amount does not increase the regular prize pool.|☐|☐||
|**14-034**|The bounty amount does not increase the organizer amount.|☐|☐||
|**14-035**|Only one killer is recorded for each eliminated player.|☐|☐||
|**14-036**|The app does not require split-bounty calculation.|☐|☐||
|**14-037**|Bounty events are visible to the administrator and reflected in allowed basic statistics such as knockouts.|☐|☐||
|**14.5 Mon**|**etary visibility**||||
|**14-038**|During the game, registered players and TV viewers can see the total Estimated Prize Pool before settlement.|☐|☐||
|**14-039**|After settlement, registered players and TV viewers can see the confirmed Prize Pool during the live game.|☐|☐||
|**14-040**|No transaction breakdown is shown publicly.|☐|☐||
|**14-041**|Rebuy count and add-on count are not shown to players or guests.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 51 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**14-042**|Individual payout amounts are never shown to players or guests.|☐|☐||
|**14-043**|After the game, the total prize-pool amount is not shown in player/public completed results.|☐|☐||
|**14-044**|After the game, all paid podium positions are shown without monetary amounts.|☐|☐||
|**14-045**|Players do not see their own investment, rebuys, add-ons, winnings, profit or ROI.|☐|☐||
|**14-046**|The administrator can see the private calculation history required to audit the game.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 52 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **15. Player View, Guest View, TV Mode and Voice** 

Every non-admin projection must show only the data approved for that audience. 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**15.1 Regi**|**stered player live view**||||
|**15-001**|A registered player can open the correct live game from the app or web app.|☐|☐||
|**15-002**|The view shows tournament name and live status.|☐|☐||
|**15-003**|The view shows the current timer.|☐|☐||
|**15-004**|The view shows current blinds.|☐|☐||
|**15-005**|The view shows current ante when active.|☐|☐||
|**15-006**|The view shows next-level blinds/ante.|☐|☐||
|**15-007**|The view shows players remaining.|☐|☐||
|**15-008**|The view shows average stack or average big blinds when calculated.|☐|☐||
|**15-009**|The view shows Estimated Prize Pool before settlement and Prize Pool during the game after settlement.|☐|☐||
|**15-010**|The view shows the player’s table and seat.|☐|☐||
|**15-011**|The view reflects admin pause, resume and level changes in realtime.|☐|☐||
|**15-012**|The view does not show admin controls.|☐|☐||
|**15-013**|The view does not show private financial details.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 53 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**15.2 Gue**|**st live view**||||
|**15-014**|An approved guest can reopen their game view through the guest web session.|☐|☐||
|**15-015**|The guest view shows timer, blinds, ante, next level and public announcements.|☐|☐||
|**15-016**|The guest view shows the guest’s table and seat.|☐|☐||
|**15-017**|The guest view shows players remaining and live prize pool where approved.|☐|☐||
|**15-018**|The guest view does not expose chat or polls.|☐|☐||
|**15-019**|The guest view does not expose admin controls or financial details.|☐|☐||
|**15-020**|An unapproved guest sees a pending-confirmation state rather than live private details.|☐|☐||
|**15.3 TV b**|**rowser mode**||||
|**15-021**|The game code/landing page offers a clear Display on TV option.|☐|☐||
|**15-022**|TV Mode opens without requiring an admin login.|☐|☐||
|**15-023**|TV Mode is strictly read-only.|☐|☐||
|**15-024**|TV Mode displays a large readable countdown timer.|☐|☐||
|**15-025**|TV Mode displays current blinds prominently.|☐|☐||
|**15-026**|TV Mode displays current ante when active.|☐|☐||
|**15-027**|TV Mode displays the next level.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 54 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**15-028**|TV Mode displays players remaining.|☐|☐||
|**15-029**|TV Mode displays average stack/average big blinds when available.|☐|☐||
|**15-030**|TV Mode displays Estimated Prize Pool before settlement and Prize Pool after settlement during the game.|☐|☐||
|**15-031**|TV Mode displays break/settlement status.|☐|☐||
|**15-032**|TV Mode displays visual announcements.|☐|☐||
|**15-033**|TV Mode displays the final-table screen when triggered.|☐|☐||
|**15-034**|TV Mode displays all paid podium positions without amounts after completion.|☐|☐||
|**15-035**|TV Mode never displays organizer percentage, contributions, individual payouts or admin actions.|☐|☐||
|**15-036**|TV Mode remains legible at common 16:9 television resolutions.|☐|☐||
|**15-037**|TV Mode can be opened directly in a smart-TV browser or by ordinary screen mirroring.|☐|☐||
|**15-038**|The MVP does not show inactive Chromecast or AirPlay integration buttons.|☐|☐||
|**15-039**|If connection is interrupted, TV Mode clearly indicates stale/disconnected status while preserving the last safe display.|☐|☐||
|**15.4 Voic**|**e announcements**||||
|**15-040**|English browser/device speech synthesis is available on supported devices.|☐|☐||
|**15-041**|The administrator manually selects which connected device is the Audio Master.|☐|☐||
|**15-042**|Only the selected Audio Master plays announcements by default.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 55 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**15-043**|Changing Audio Master prevents duplicate simultaneous speech.|☐|☐||
|**15-044**|The administrator can mute/unmute announcements.|☐|☐||
|**15-045**|A tournament-start announcement is supported.|☐|☐||
|**15-046**|A new-level announcement is supported.|☐|☐||
|**15-047**|A five-minutes-remaining announcement is supported.|☐|☐||
|**15-048**|A one-minute-remaining announcement is supported.|☐|☐||
|**15-049**|A rebuys-closed announcement is supported.|☐|☐||
|**15-050**|A final-table announcement is supported.|☐|☐||
|**15-051**|A winner announcement is supported.|☐|☐||
|**15-052**|Initial dealer and final-table dealer names may be announced.|☐|☐||
|**15-053**|Elimination-name announcements are optional and disabled by default.|☐|☐||
|**15-054**|Voice failure does not stop the timer or tournament controls.|☐|☐||
|**15-055**|Voice commands are not present in the MVP.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 56 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **16. Group Game History and Basic Statistics** 

History and statistics remain intentionally simple and group-focused. 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**16.1 Com**|**pleted game history**||||
|**16-001**|Completed tournaments appear in group history.|☐|☐||
|**16-002**|Completed cash sessions appear in the appropriate simple history.|☐|☐||
|**16-003**|A history item shows game name, date and game type.|☐|☐||
|**16-004**|A tournament history item shows the final paid podium without amounts.|☐|☐||
|**16-005**|History does not expose organizer amounts or private contribution records to players.|☐|☐||
|**16-006**|History records remain stable after app reinstall or new-device login.|☐|☐||
|**16-007**|The administrator can open the private completed-game record.|☐|☐||
|**16-008**|Registered players can view allowed group history.|☐|☐||
|**16-009**|Guests cannot access permanent group history without registering.|☐|☐||
|**16.2 Basi**|**c statistics**||||
|**16-010**|The group can display games played.|☐|☐||
|**16-011**|The group can display tournament winners.|☐|☐||
|**16-012**|The group can display podium finishes.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 57 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**16-013**|The group can display average finishing position where enough data exists.|☐|☐||
|**16-014**|The group can display knockouts when bounty/elimination records support it.|☐|☐||
|**16-015**|Statistics are recalculated after a completed result is corrected.|☐|☐||
|**16-016**|No player-facing profit, ROI, amount invested, winnings, rebuy or add-on statistic is shown.|☐|☐||
|**16-017**|No advanced graph, streak, achievement, season or complex leaderboard appears in the MVP.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 58 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **17. Minimal Cash-Game Module** 

Cash Poker is a separate, simpler area. It records chip-value movements for reconciliation but does not process money. 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**17.1 Cash**|**-game setup**||||
|**17-001**|The administrator can create a cash-game session.|☐|☐||
|**17-002**|The administrator can enter/select small blind and big blind.|☐|☐||
|**17-003**|Cash-game blinds remain fixed throughout the session.|☐|☐||
|**17-004**|The administrator can enter minimum and maximum buy-in when included by the final UI.|☐|☐||
|**17-005**|The administrator can add players to the session.|☐|☐||
|**17-006**|The administrator can assign initial seats.|☐|☐||
|**17-007**|The session has a clear start action.|☐|☐||
|**17-008**|Cash-game setup is visually separated from tournament creation.|☐|☐||
|**17.2 Live**|**cash session**||||
|**17-009**|The live screen shows fixed blinds.|☐|☐||
|**17-010**|The live screen shows the player list and seats.|☐|☐||
|**17-011**|The live screen shows elapsed session time.|☐|☐||
|**17-012**|Only the administrator records initial buy-ins.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 59 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**17-013**|Only the administrator records top-ups.|☐|☐||
|**17-014**|Top-ups can be recorded multiple times.|☐|☐||
|**17-015**|Only the administrator records cash-outs.|☐|☐||
|**17-016**|A player can join or leave while the session is active, subject to the simple seating flow.|☐|☐||
|**17-017**|The app records chip-value amounts for reconciliation, not physical payment status or method.|☐|☐||
|**17-018**|Players do not see private profit/loss calculations during the game.|☐|☐||
|**17-019**|The app does not track hands, pots or card outcomes.|☐|☐||
|**17-020**|The admin can correct an incorrectly entered buy-in, top-up or cash-out.|☐|☐||
|**17-021**|A refresh/reopen recovers the active cash session on the admin device.|☐|☐||
|**17.3 Cash**|**reconciliation and completion**||||
|**17-022**|The admin can end the cash session.|☐|☐||
|**17-023**|The reconciliation screen lists total initial buy-ins.|☐|☐||
|**17-024**|The reconciliation screen lists total top-ups.|☐|☐||
|**17-025**|The reconciliation screen lists total cash-outs.|☐|☐||
|**17-026**|The app checks whether total cash-outs equal total buy-ins plus top-ups.|☐|☐||
|**17-027**|A mismatch produces a clear warning and difference amount.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 60 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**17-028**|The administrator can correct entries before final completion.|☐|☐||
|**17-029**|The final record retains the reconciliation result.|☐|☐||
|**17-030**|Completed cash history does not expose financial amounts to ordinary players unless expressly approved.|☐|☐||
|**17-031**|No actual payment is processed by Poker Night.|☐|☐||
|**17-032**|Advanced cash waiting lists, multiple tables, straddle automation and detailed profit statistics are not required in this reduced MVP.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 61 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **18. Realtime Synchronisation, Local Recovery and Offline Behaviour** 

One administrator is authoritative. Player and TV devices receive updates, while the admin device retains enough local state to recover. 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**18.1 Real**|**time updates**||||
|**18-001**|Admin clock start, pause and resume propagate to registered player views.|☐|☐||
|**18-002**|Admin clock start, pause and resume propagate to guest views.|☐|☐||
|**18-003**|Admin clock start, pause and resume propagate to TV Mode.|☐|☐||
|**18-004**|Level changes propagate to all online views.|☐|☐||
|**18-005**|Blind and ante changes propagate to all online views.|☐|☐||
|**18-006**|Player-count changes propagate to all online views.|☐|☐||
|**18-007**|Seating confirmations propagate to affected players/guests.|☐|☐||
|**18-008**|Settlement status and live prize-pool label/value propagate to allowed views.|☐|☐||
|**18-009**|Chat messages propagate to registered users.|☐|☐||
|**18-010**|Poll updates propagate to registered users.|☐|☐||
|**18-011**|Realtime events are idempotent or protected from duplicate application.|☐|☐||
|**18-012**|A temporarily disconnected viewer resynchronises to the current authoritative state after reconnecting.|☐|☐||
|**18.2 Auth**|**oritative admin and conflicts**||||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 62 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**18-013**|Only the designated administrator can mutate game state.|☐|☐||
|**18-014**|A player or guest request cannot overwrite admin state.|☐|☐||
|**18-015**|Repeated action submissions are protected against duplicates.|☐|☐||
|**18-016**|The backend stores a clear game status and current structure version.|☐|☐||
|**18-017**|Updates rejected due to stale state show a clear retry/reload message.|☐|☐||
|**18-018**|The MVP does not require two offline administrators to merge conflicting game histories.|☐|☐||
|**18.3 Loca**|**l admin recovery**||||
|**18-019**|The active tournament state is saved locally on the admin device at meaningful changes.|☐|☐||
|**18-020**|The active cash-session state is saved locally on the admin device at meaningful changes.|☐|☐||
|**18-021**|Refreshing the admin web page restores the active game safely.|☐|☐||
|**18-022**|Closing and reopening the app restores the active game safely.|☐|☐||
|**18-023**|Temporary internet loss does not erase the admin’s current game.|☐|☐||
|**18-024**|The clock resumes from a correct timestamp after recovery rather than restarting the level.|☐|☐||
|**18-025**|Queued admin changes synchronise when connection returns, subject to the one-admin model.|☐|☐||
|**18-026**|The admin is told when the device is offline and when synchronisation is restored.|☐|☐||
|**18-027**|Players and TV require internet for live updates and show a clear disconnected state when unavailable.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 63 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**18-028**|No stale viewer is allowed to display itself as fully live without a connection indicator.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 64 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **19. Security, Privacy and Data Visibility** 

The application holds private group and game data. Access rules must be enforced server-side. 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**19.1 Secu**|**rity baseline**||||
|**19-001**|All production traffic uses HTTPS/TLS.|☐|☐||
|**19-002**|Passwords are handled by a secure authentication provider or appropriate hashing system.|☐|☐||
|**19-003**|Backend rules verify user identity and role for every protected operation.|☐|☐||
|**19-004**|Admin-only endpoints reject player and guest requests.|☐|☐||
|**19-005**|Group data cannot be read by unrelated authenticated users.|☐|☐||
|**19-006**|Guest access tokens/cookies are scoped to the intended game.|☐|☐||
|**19-007**|Guessing sequential IDs does not expose another group or game.|☐|☐||
|**19-008**|Input is validated on the server as well as in the interface.|☐|☐||
|**19-009**|Chat and name fields are protected against script injection.|☐|☐||
|**19-010**|Rate limiting or equivalent abuse protection exists for login, code lookup and message sending.|☐|☐||
|**19-011**|Production secrets are stored in environment/secret management, not source control.|☐|☐||
|**19-012**|Database backups are configured and tested.|☐|☐||
|**19-013**|Logs do not expose passwords, auth tokens or private secrets.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 65 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**19-014**|Dependencies have no known critical unaddressed vulnerabilities at release.|☐|☐||
|**19.2 Priva**|**cy projections**||||
|**19-015**|The administrator can see private organizer and contribution calculations.|☐|☐||
|**19-016**|Registered players see only approved live public data, seat information, chat, polls and allowed history.|☐|☐||
|**19-017**|Guests see only the intended game’s limited live data and their seat.|☐|☐||
|**19-018**|TV Mode receives a dedicated read-only projection with no private fields.|☐|☐||
|**19-019**|Private fields are omitted by the backend response, not merely hidden with CSS.|☐|☐||
|**19-020**|Player/public completed results contain no monetary amounts.|☐|☐||
|**19-021**|Player-facing data contains no personal rebuy/add-on totals.|☐|☐||
|**19-022**|Cash reconciliation details are limited to the administrator.|☐|☐||
|**19-023**|The privacy policy accurately describes account, group, chat, notification and game data usage.|☐|☐||
|**19-024**|Account deletion/data-request handling is documented even if manually processed in the MVP.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 66 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **20. Validation, Errors and Edge Cases** 

The product must fail safely and clearly. Error messages should help the user recover without corrupting game state. 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**20.1 Gen**|**eral validation**||||
|**20-001**|Required fields cannot be submitted empty.|☐|☐||
|**20-002**|Numeric fields reject letters and malformed values.|☐|☐||
|**20-003**|Negative buy-ins, chip values, quantities, player counts and durations are rejected.|☐|☐||
|**20-004**|Whole-number-only fields reject decimals where decimals are not allowed.|☐|☐||
|**20-005**|Duplicate player entries are prevented or clearly resolved.|☐|☐||
|**20-006**|Duplicate chip values are rejected.|☐|☐||
|**20-007**|Form errors identify the specific field and required correction.|☐|☐||
|**20-008**|A network failure does not erase completed form input.|☐|☐||
|**20-009**|Loading states prevent accidental repeated submission.|☐|☐||
|**20.2 Tour**|**nament edge cases**||||
|**20-010**|The engine handles a very small valid tournament without crashing.|☐|☐||
|**20-011**|The engine handles more than one table.|☐|☐||
|**20-012**|The engine handles a numbered chip set with no 5-value or 25-value chip.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 67 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**20-013**|The engine handles an unnumbered chip set after values are assigned.|☐|☐||
|**20-014**|The engine rejects or explains a chip set that cannot create any playable structure.|☐|☐||
|**20-015**|The engine handles buy-in with KO bounty correctly.|☐|☐||
|**20-016**|The engine handles no rebuy, no add-on and no ante.|☐|☐||
|**20-017**|The engine handles rebuy plus add-on plus Big Blind Ante.|☐|☐||
|**20-018**|The engine handles Individual Ante with practical rounding.|☐|☐||
|**20-019**|The game can be paused for an extended settlement break without timer corruption.|☐|☐||
|**20-020**|A player eliminated exactly near the rebuy-closing boundary is handled according to the approved settlement flow.|☐|☐||
|**20-021**|A player cannot receive two add-ons.|☐|☐||
|**20-022**|A player cannot rebuy while still active.|☐|☐||
|**20-023**|No player can be added after late registration closes.|☐|☐||
|**20-024**|An undo does not produce negative counts or duplicate active players.|☐|☐||
|**20-025**|A final-table redraw triggers at 9 remaining only when multiple tables were used.|☐|☐||
|**20-026**|The app handles all players eliminated/completed without a stuck live state.|☐|☐||
|**20.3 QR,**|**guest and attendance edge cases**||||
|**20-027**|A QR link to a deleted game shows a safe message.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 68 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**20-028**|An expired guest session can restart the code flow without exposing another slot.|☐|☐||
|**20-029**|Two guests attempting the same slot cannot both be approved.|☐|☐||
|**20-030**|A player reducing guest count releases unused slots safely.|☐|☐||
|**20-031**|An inviter changing RSVP after a guest checked in is handled with an admin-visible conflict before the cutoff.|☐|☐||
|**20-032**|A guest name matching another player does not create the same record accidentally.|☐|☐||
|**20-033**|A registered player cannot check in twice through app and web.|☐|☐||
|**20-034**|A code cannot be used to access admin routes.|☐|☐||
|**20.4 Cloc**|**k and realtime edge cases**||||
|**20-035**|Refreshing during an active level preserves the correct remaining time.|☐|☐||
|**20-036**|Backgrounding the admin app and returning preserves the correct remaining time.|☐|☐||
|**20-037**|A viewer joining mid-level receives the correct current time and blinds.|☐|☐||
|**20-038**|A viewer reconnecting after several levels receives current state, not replayed stale screens.|☐|☐||
|**20-039**|Two rapid admin taps do not create duplicate rebuys, eliminations or level advances.|☐|☐||
|**20-040**|A server error during an admin action leaves a clear retry state and does not falsely show success.|☐|☐||
|**20-041**|A delayed realtime message cannot roll the client back to an older level.|☐|☐||



**20.5 Prize and cash edge cases** 

Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 69 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**20-042**|Prize calculations reconcile when the eligible total is not a multiple of 10 before organizer rounding.|☐|☐||
|**20-043**|Payout generation never creates an unexplained remainder.|☐|☐||
|**20-044**|KO bounty contributions never leak into the regular pool.|☐|☐||
|**20-045**|A manual payout edit that breaks the total is rejected.|☐|☐||
|**20-046**|Cash reconciliation detects both positive and negative differences.|☐|☐||
|**20-047**|Deleting/correcting a cash top-up recalculates totals.|☐|☐||
|**20-048**|A cash session cannot be completed with unresolved required data without a warning.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 70 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **21. UI Quality, Responsiveness and Accessibility** 

The product must look intentional and remain usable across device sizes, not merely technically render. 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**21.1 Visu**|**al consistency**||||
|**21-001**|A consistent design system is used for colours, typography, spacing, buttons, inputs and cards.|☐|☐||
|**21-002**|Primary, secondary, destructive and disabled buttons are visually distinct.|☐|☐||
|**21-003**|Admin controls are visually separated from read-only information.|☐|☐||
|**21-004**|The timer and blinds are the strongest visual elements in live/TV views.|☐|☐||
|**21-005**|Forms are grouped into understandable steps rather than one confusing wall of fields.|☐|☐||
|**21-006**|All icons have understandable labels or tooltips where meaning is not obvious.|☐|☐||
|**21-007**|Error, warning, success and offline states use consistent treatment.|☐|☐||
|**21-008**|The design is polished enough for public launch and contains no default framework demo styling.|☐|☐||
|**21.2 Resp**|**onsive layouts**||||
|**21-009**|The public website works at common mobile widths without horizontal scrolling.|☐|☐||
|**21-010**|The web app works at common mobile widths without clipped controls.|☐|☐||
|**21-011**|The web app works on tablets in portrait and landscape.|☐|☐||
|**21-012**|The web app works on common laptop and desktop widths.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 71 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**21-013**|The TV view fills the screen and remains readable at 1920×1080.|☐|☐||
|**21-014**|Long player names are truncated/wrapped safely without breaking seating layouts.|☐|☐||
|**21-015**|On-screen keyboards do not hide required mobile form controls.|☐|☐||
|**21-016**|Safe areas and status bars do not overlap content on iOS/Android.|☐|☐||
|**21.3 Acce**|**ssibility basics**||||
|**21-017**|Text contrast is sufficient for normal and large text.|☐|☐||
|**21-018**|Important information is not communicated by colour alone.|☐|☐||
|**21-019**|Chip colours are accompanied by names/values.|☐|☐||
|**21-020**|Interactive controls have accessible labels.|☐|☐||
|**21-021**|Keyboard users can navigate the web app’s essential flows.|☐|☐||
|**21-022**|Visible focus indicators appear on web controls.|☐|☐||
|**21-023**|Form fields have labels, not placeholder-only identification.|☐|☐||
|**21-024**|Error messages are associated with the affected field.|☐|☐||
|**21-025**|Touch targets are large enough for mobile use.|☐|☐||
|**21-026**|TV text remains readable from a reasonable room distance.|☐|☐||
|**21-027**|Voice announcements have equivalent visual announcements.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 72 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**21-028**|Reduced-motion preferences are respected for nonessential animation where practical.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 73 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **22. End-to-End User Acceptance Scenarios** 

These scenarios must be demonstrated with production-like data. Passing isolated screens is not enough. 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**22.1 Acco**|**unt and group scenarios**||||
|**22-001**|UAT-001: A new user registers, logs in, creates a group and reaches the empty group home without developer intervention.|☐|☐||
|**22-002**|UAT-002: The admin shares the group code; a registered player joins the correct group and cannot see another group.|☐|☐||
|**22-003**|UAT-003: The user logs out and back in on a second platform and sees the same group.|☐|☐||
|**22.2 Tour**|**nament creation scenarios**||||
|**22-004**|UAT-010: Admin creates a tournament from scratch with 8 players, 3.5 hours, buy-in 15, unnumbered chips, rebuys and add-on.|☐|☐||
|**22-005**|UAT-011: The app recommends unique values for unnumbered chip colours and generates a physically understandable stack.|☐|☐||
|**22-006**|UAT-012: Admin creates a second game using a saved preset and actual attendance regenerates the structure.|☐|☐||
|**22-007**|UAT-013: Admin creates a numbered-chip game without a 25-value chip and the engine avoids impossible 25-based blinds.|☐|☐||
|**22-008**|UAT-014: Admin enables KO bounty and the UI/calculations separate buy-in and bounty.|☐|☐||
|**22-009**|UAT-015: Admin enables Individual Ante and the generated ante is compatible with chips and shown on all views.|☐|☐||
|**22.3 Invit**|**ation and guest scenarios**||||
|**22-010**|UAT-020: A player selects Going +2 and two guest slots appear.|☐|☐||
|**22-011**|UAT-021: Guest A scans the QR on iOS, selects inviter and Guest 1, enters a name and is approved by the admin.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 74 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**22-012**|UAT-022: Guest B enters the manual code on Android, selects Guest 2 and is approved.|☐|☐||
|**22-013**|UAT-023: A third device cannot claim the already used Guest 1 or Guest 2 slot.|☐|☐||
|**22-014**|UAT-024: A registered player checks in from the app and the admin sees the updated count.|☐|☐||
|**22-015**|UAT-025: After the one-hour RSVP cutoff, a player cannot alter the RSVP without admin handling.|☐|☐||
|**22.4 Seat**|**ing and start scenarios**||||
|**22-016**|UAT-030: Admin generates random seating for more than 9 players and receives multiple valid tables.|☐|☐||
|**22-017**|UAT-031: Every checked-in person receives exactly one unique seat.|☐|☐||
|**22-018**|UAT-032: Player and guest devices display their correct seat after admin confirmation.|☐|☐||
|**22-019**|UAT-033: TV Mode opens from the code page and shows only approved public data.|☐|☐||
|**22-020**|UAT-034: Admin starts the game and timer/blinds synchronise across web, Android, iOS and TV.|☐|☐||
|**22.5 Live**|**play scenarios**||||
|**22-021**|UAT-040: Admin pauses and resumes the clock; all online views stay consistent.|☐|☐||
|**22-022**|UAT-041: A player is eliminated, players remaining and average stack update.|☐|☐||
|**22-023**|UAT-042: The eliminated player rebuys, returns active in the same seat and receives the correct current-level chip composition.|☐|☐||
|**22-024**|UAT-043: Admin records an incorrect elimination and undo restores all affected data.|☐|☐||
|**22-025**|UAT-044: Admin adds a late player before registration closes; seat and estimates update.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 75 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**22-026**|UAT-045: Admin attempts to add a player after registration closes and the app blocks it.|☐|☐||
|**22-027**|UAT-046: Admin previews Speed Up, cancels it and confirms nothing changed.|☐|☐||
|**22-028**|UAT-047: Admin previews Slow Down, accepts an inserted future level and all views receive the new future structure.|☐|☐||
|**22.6 Settl**|**ement and prize scenarios**||||
|**22-029**|UAT-050: End of Level 6 pauses the game and opens settlement without a fixed break timer.|☐|☐||
|**22-030**|UAT-051: Admin records final rebuys and selects add-ons, with no player receiving more than one add-on.|☐|☐||
|**22-031**|UAT-052: Admin confirms ante activation and chip exchanges.|☐|☐||
|**22-032**|UAT-053: Public label changes from Estimated Prize Pool to Prize Pool after settlement.|☐|☐||
|**22-033**|UAT-054: Eligible total 165 and organizer target near 10% produces an acceptable clean result such as organizer 15 / prize pool 150.|☐|☐||
|**22-034**|UAT-055: KO bounty money remains excluded from organizer and prize-pool calculations.|☐|☐||
|**22-035**|UAT-056: Generated payouts sum exactly to the prize pool and use clean rounded values.|☐|☐||
|**22.7 Final**|**table and completion scenarios**||||
|**22-036**|UAT-060: A multi-table tournament reaches 9 players and pauses for a full random final-table redraw.|☐|☐||
|**22-037**|UAT-061: Final seats and initial dealer are confirmed and synchronised.|☐|☐||
|**22-038**|UAT-062: Admin records final paid positions and completes the game.|☐|☐||
|**22-039**|UAT-063: Player and TV completed views show all paid positions with no monetary amounts.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 76 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**22-040**|UAT-064: The completed game appears in group history and basic statistics update.|☐|☐||
|**22.8 Chat**|**, poll and notification scenarios**||||
|**22-041**|UAT-070: Admin sends a chat message and registered users receive it; guest web view does not expose chat.|☐|☐||
|**22-042**|UAT-071: Admin creates a poll, registered player votes once and totals update.|☐|☐||
|**22-043**|UAT-072: Admin closes the poll and further votes are blocked.|☐|☐||
|**22-044**|UAT-073: A game notification opens the correct game on Android, iOS or supported web environment.|☐|☐||
|**22.9 Rec**|**overy scenarios**||||
|**22-045**|UAT-080: Admin refreshes the web page during an active level and recovers the correct timer/state.|☐|☐||
|**22-046**|UAT-081: Admin backgrounds and reopens the mobile app and recovers the correct timer/state.|☐|☐||
|**22-047**|UAT-082: Internet disconnects on the admin device, local state remains available and resynchronises after reconnection.|☐|☐||
|**22-048**|UAT-083: TV/player view disconnects and clearly indicates stale/offline state before resynchronising.|☐|☐||
|**22.10 Cas**|**h-game scenarios**||||
|**22-049**|UAT-090: Admin creates a cash session with fixed blinds and seats players.|☐|☐||
|**22-050**|UAT-091: Admin records initial buy-ins, multiple top-ups and cash-outs.|☐|☐||
|**22-051**|UAT-092: The app calculates a matching reconciliation when totals balance.|☐|☐||
|**22-052**|UAT-093: The app warns and shows the difference when totals do not balance.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 77 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**<br>**Evidence / Notes**|
|---|---|---|---|
|**22-053**|UAT-094: Admin corrects an entry and completes the cash session.|☐|☐|



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 78 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **23. Compatibility, Performance and Reliability** 

The product must be usable on the agreed platforms with reasonable speed and stability. 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**23.1 Brow**|**ser and device compatibility**||||
|**23-001**|The public website and web app are tested on current Chrome.|☐|☐||
|**23-002**|The public website and web app are tested on current Safari.|☐|☐||
|**23-003**|The public website and web app are tested on current Firefox or Edge.|☐|☐||
|**23-004**|The TV view is tested in at least one common smart-TV browser or an equivalent TV-resolution browser environment.|☐|☐||
|**23-005**|Android and iOS builds use supported OS versions documented in release notes.|☐|☐||
|**23-006**|Unsupported browser/OS behaviour is documented rather than silently failing.|☐|☐||
|**23.2 Perf**|**ormance and stability**||||
|**23-007**|The homepage and login page load within a reasonable time on normal broadband/mobile data.|☐|☐||
|**23-008**|The admin live screen remains responsive during a multi-hour session.|☐|☐||
|**23-009**|Realtime updates normally appear within a reasonable short delay.|☐|☐||
|**23-010**|The application does not leak memory or become unusably slow during repeated level changes.|☐|☐||
|**23-011**|Large chat history is paginated/limited enough to avoid freezing the group screen.|☐|☐||
|**23-012**|Database queries used by live screens are indexed/structured to avoid obvious scaling issues.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 79 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**23-013**|Uncaught production errors are logged in a client-owned error-monitoring solution or documented alternative.|☐|☐||
|**23-014**|A production backup exists before major deployment changes.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 80 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **24. Deployment, App Stores and Production Launch** 

The project is not finished when it only runs on the developer’s machine. Production deployment and release-ready mobile builds are required. 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**24.1 Prod**|**uction web deployment**||||
|**24-001**|The final public website is deployed to the client’s production domain.|☐|☐||
|**24-002**|The final web app is deployed and reachable from the production website.|☐|☐||
|**24-003**|The backend/database uses production configuration, not test credentials.|☐|☐||
|**24-004**|HTTPS works on all production routes.|☐|☐||
|**24-005**|Direct links and refreshes work in production.|☐|☐||
|**24-006**|Production code does not expose debug banners, developer menus or test accounts.|☐|☐||
|**24-007**|The production environment has a documented rollback or redeploy procedure.|☐|☐||
|**24-008**|The client can deploy a future version using the written instructions.|☐|☐||
|**24.2 Andr**|**oid release**||||
|**24-009**|The final Android package name matches the client-owned Play Console application.|☐|☐||
|**24-010**|The app name, icon, screenshots and description assets required for submission are delivered or clearly assigned.|☐|☐||
|**24-011**|A signed production AAB is generated from the accepted source code.|☐|☐||
|**24-012**|The signing-key ownership and secure backup arrangement are documented.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 81 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**24-013**|The app is uploaded to the client’s Play Console or the developer assists live with upload.|☐|☐||
|**24-014**|Required data-safety/privacy declarations are supported with accurate technical information.|☐|☐||
|**24-015**|Code-related Play Console warnings/rejections are corrected by the developer.|☐|☐||
|**24-016**|The final build is published or accepted for release, except for delays caused solely by the client’s account status or platform-controlled<br>testing rules.|☐|☐||
|**24.3 iOS**|**release**||||
|**24-017**|The final bundle identifier matches the client-owned App Store Connect application.|☐|☐||
|**24-018**|The app name, icon, screenshots and description assets required for submission are delivered or clearly assigned.|☐|☐||
|**24-019**|A production archive is generated from the accepted source code.|☐|☐||
|**24-020**|Certificates/profiles are configured through the client’s Apple account.|☐|☐||
|**24-021**|The build is uploaded to App Store Connect/TestFlight or the developer assists live with upload.|☐|☐||
|**24-022**|Required privacy labels are supported with accurate technical information.|☐|☐||
|**24-023**|Code-related App Store validation errors/rejections are corrected by the developer.|☐|☐||
|**24-024**|The final build is published or accepted for release, except for delays caused solely by the client’s account status or independent<br>Apple review decisions not caused by code.|☐|☐||
|**24.4 Laun**|**ch verification**||||
|**24-025**|The live production website loads from a device not used during development.|☐|☐||
|**24-026**|A new production account can register and log in.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 82 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**24-027**|A production group and test game can be created.|☐|☐||
|**24-028**|A production QR code can be scanned and used successfully.|☐|☐||
|**24-029**|Production realtime updates work across at least two devices.|☐|☐||
|**24-030**|Production voice announcements work on a supported selected device.|☐|☐||
|**24-031**|Production local recovery works after refresh/reopen.|☐|☐||
|**24-032**|Production privacy/terms/support links work.|☐|☐||
|**24-033**|No critical or high-severity defects remain open at launch.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 83 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **25. Baseline Payout Style Regression Checks** 

The engine need not hardcode this table, but its output should preserve this approved style unless the algorithm’s documented player-count logic justifies a different paid-place count. Each sample must still reconcile and use clean amounts. 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**25.1 Refe**|**rence payout samples**||||
|**25-001**|For a final prize pool of 50, the engine output is checked against the approved reference style 40 / 10; any material deviation is<br>documented and justified.|☐|☐||
|**25-002**|For a final prize pool of 60, the engine output is checked against the approved reference style 40 / 20; any material deviation is<br>documented and justified.|☐|☐||
|**25-003**|For a final prize pool of 70, the engine output is checked against the approved reference style 50 / 20; any material deviation is<br>documented and justified.|☐|☐||
|**25-004**|For a final prize pool of 80, the engine output is checked against the approved reference style 50 / 30; any material deviation is<br>documented and justified.|☐|☐||
|**25-005**|For a final prize pool of 90, the engine output is checked against the approved reference style 60 / 30; any material deviation is<br>documented and justified.|☐|☐||
|**25-006**|For a final prize pool of 100, the engine output is checked against the approved reference style 60 / 30 / 10; any material deviation is<br>documented and justified.|☐|☐||
|**25-007**|For a final prize pool of 110, the engine output is checked against the approved reference style 70 / 30 / 10; any material deviation is<br>documented and justified.|☐|☐||
|**25-008**|For a final prize pool of 120, the engine output is checked against the approved reference style 70 / 40 / 10; any material deviation is<br>documented and justified.|☐|☐||
|**25-009**|For a final prize pool of 130, the engine output is checked against the approved reference style 80 / 40 / 10; any material deviation is<br>documented and justified.|☐|☐||
|**25-010**|For a final prize pool of 140, the engine output is checked against the approved reference style 80 / 40 / 20; any material deviation is<br>documented and justified.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 84 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**25-011**|For a final prize pool of 150, the engine output is checked against the approved reference style 90 / 40 / 20; any material deviation is<br>documented and justified.|☐|☐||
|**25-012**|For a final prize pool of 160, the engine output is checked against the approved reference style 90 / 50 / 20; any material deviation is<br>documented and justified.|☐|☐||
|**25-013**|For a final prize pool of 170, the engine output is checked against the approved reference style 100 / 50 / 20; any material deviation is<br>documented and justified.|☐|☐||
|**25-014**|For a final prize pool of 180, the engine output is checked against the approved reference style 110 / 50 / 20; any material deviation is<br>documented and justified.|☐|☐||
|**25-015**|For a final prize pool of 190, the engine output is checked against the approved reference style 110 / 60 / 20; any material deviation is<br>documented and justified.|☐|☐||
|**25-016**|For a final prize pool of 200, the engine output is checked against the approved reference style 110 / 60 / 30; any material deviation is<br>documented and justified.|☐|☐||
|**25-017**|For a final prize pool of 210, the engine output is checked against the approved reference style 120 / 60 / 30; any material deviation is<br>documented and justified.|☐|☐||
|**25-018**|For a final prize pool of 220, the engine output is checked against the approved reference style 130 / 60 / 30; any material deviation is<br>documented and justified.|☐|☐||
|**25-019**|For a final prize pool of 230, the engine output is checked against the approved reference style 130 / 70 / 30; any material deviation is<br>documented and justified.|☐|☐||
|**25-020**|For a final prize pool of 240, the engine output is checked against the approved reference style 140 / 70 / 30; any material deviation is<br>documented and justified.|☐|☐||
|**25-021**|For a final prize pool of 250, the engine output is checked against the approved reference style 140 / 80 / 30; any material deviation is<br>documented and justified.|☐|☐||
|**25-022**|For a final prize pool of 260, the engine output is checked against the approved reference style 150 / 80 / 30; any material deviation is<br>documented and justified.|☐|☐||
|**25-023**|For a final prize pool of 270, the engine output is checked against the approved reference style 150 / 80 / 40; any material deviation is<br>documented and justified.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 85 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**25-024**|For a final prize pool of 280, the engine output is checked against the approved reference style 160 / 80 / 40; any material deviation is<br>documented and justified.|☐|☐||
|**25-025**|For a final prize pool of 290, the engine output is checked against the approved reference style 160 / 90 / 40; any material deviation is<br>documented and justified.|☐|☐||
|**25-026**|For a final prize pool of 300, the engine output is checked against the approved reference style 170 / 90 / 40; any material deviation is<br>documented and justified.|☐|☐||
|**25-027**|For a final prize pool of 310, the engine output is checked against the approved reference style 180 / 90 / 40; any material deviation is<br>documented and justified.|☐|☐||
|**25-028**|For a final prize pool of 320, the engine output is checked against the approved reference style 180 / 100 / 40; any material deviation is<br>documented and justified.|☐|☐||
|**25-029**|For a final prize pool of 330, the engine output is checked against the approved reference style 190 / 100 / 40; any material deviation is<br>documented and justified.|☐|☐||
|**25-030**|For a final prize pool of 340, the engine output is checked against the approved reference style 190 / 100 / 50; any material deviation is<br>documented and justified.|☐|☐||
|**25-031**|For a final prize pool of 350, the engine output is checked against the approved reference style 200 / 100 / 50; any material deviation is<br>documented and justified.|☐|☐||
|**25-032**|For a final prize pool of 360, the engine output is checked against the approved reference style 200 / 110 / 50; any material deviation is<br>documented and justified.|☐|☐||
|**25-033**|For a final prize pool of 370, the engine output is checked against the approved reference style 210 / 110 / 50; any material deviation is<br>documented and justified.|☐|☐||
|**25-034**|For a final prize pool of 380, the engine output is checked against the approved reference style 210 / 120 / 50; any material deviation is<br>documented and justified.|☐|☐||
|**25-035**|For a final prize pool of 390, the engine output is checked against the approved reference style 220 / 120 / 50; any material deviation is<br>documented and justified.|☐|☐||
|**25-036**|For a final prize pool of 400, the engine output is checked against the approved reference style 220 / 120 / 40 / 20; any material<br>deviation is documented and justified.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 86 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**25-037**|For a final prize pool of 410, the engine output is checked against the approved reference style 230 / 120 / 40 / 20; any material<br>deviation is documented and justified.|☐|☐||
|**25-038**|For a final prize pool of 420, the engine output is checked against the approved reference style 240 / 120 / 40 / 20; any material<br>deviation is documented and justified.|☐|☐||
|**25-039**|For a final prize pool of 430, the engine output is checked against the approved reference style 240 / 130 / 40 / 20; any material<br>deviation is documented and justified.|☐|☐||
|**25-040**|For a final prize pool of 440, the engine output is checked against the approved reference style 250 / 130 / 40 / 20; any material<br>deviation is documented and justified.|☐|☐||
|**25-041**|For a final prize pool of 450, the engine output is checked against the approved reference style 250 / 140 / 40 / 20; any material<br>deviation is documented and justified.|☐|☐||
|**25-042**|For a final prize pool of 460, the engine output is checked against the approved reference style 260 / 140 / 40 / 20; any material<br>deviation is documented and justified.|☐|☐||
|**25-043**|For a final prize pool of 470, the engine output is checked against the approved reference style 260 / 140 / 50 / 20; any material<br>deviation is documented and justified.|☐|☐||
|**25-044**|For a final prize pool of 480, the engine output is checked against the approved reference style 270 / 140 / 50 / 20; any material<br>deviation is documented and justified.|☐|☐||
|**25-045**|For a final prize pool of 490, the engine output is checked against the approved reference style 270 / 150 / 50 / 20; any material<br>deviation is documented and justified.|☐|☐||
|**25-046**|For a final prize pool of 500, the engine output is checked against the approved reference style 280 / 150 / 50 / 20; any material<br>deviation is documented and justified.|☐|☐||
|**25-047**|For a final prize pool of 510, the engine output is checked against the approved reference style 290 / 150 / 50 / 20; any material<br>deviation is documented and justified.|☐|☐||
|**25-048**|For a final prize pool of 520, the engine output is checked against the approved reference style 290 / 160 / 50 / 20; any material<br>deviation is documented and justified.|☐|☐||
|**25-049**|For a final prize pool of 530, the engine output is checked against the approved reference style 300 / 160 / 50 / 20; any material<br>deviation is documented and justified.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 87 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**25-050**|For a final prize pool of 540, the engine output is checked against the approved reference style 300 / 160 / 60 / 20; any material<br>deviation is documented and justified.|☐|☐||
|**25-051**|For a final prize pool of 550, the engine output is checked against the approved reference style 310 / 160 / 60 / 20; any material<br>deviation is documented and justified.|☐|☐||
|**25-052**|For a final prize pool of 560, the engine output is checked against the approved reference style 310 / 170 / 60 / 20; any material<br>deviation is documented and justified.|☐|☐||
|**25-053**|For a final prize pool of 570, the engine output is checked against the approved reference style 320 / 170 / 60 / 20; any material<br>deviation is documented and justified.|☐|☐||
|**25-054**|For a final prize pool of 580, the engine output is checked against the approved reference style 320 / 180 / 60 / 20; any material<br>deviation is documented and justified.|☐|☐||
|**25-055**|For a final prize pool of 590, the engine output is checked against the approved reference style 330 / 180 / 60 / 20; any material<br>deviation is documented and justified.|☐|☐||
|**25-056**|For a final prize pool of 600, the engine output is checked against the approved reference style 330 / 180 / 70 / 20; any material<br>deviation is documented and justified.|☐|☐||
|**25-057**|For a final prize pool of 610, the engine output is checked against the approved reference style 340 / 180 / 70 / 20; any material<br>deviation is documented and justified.|☐|☐||
|**25-058**|For a final prize pool of 620, the engine output is checked against the approved reference style 340 / 190 / 70 / 20; any material<br>deviation is documented and justified.|☐|☐||
|**25-059**|For a final prize pool of 630, the engine output is checked against the approved reference style 350 / 190 / 70 / 20; any material<br>deviation is documented and justified.|☐|☐||
|**25-060**|For a final prize pool of 640, the engine output is checked against the approved reference style 350 / 190 / 80 / 20; any material<br>deviation is documented and justified.|☐|☐||
|**25-061**|For a final prize pool of 650, the engine output is checked against the approved reference style 360 / 190 / 80 / 20; any material<br>deviation is documented and justified.|☐|☐||
|**25-062**|For a final prize pool of 660, the engine output is checked against the approved reference style 360 / 200 / 80 / 20; any material<br>deviation is documented and justified.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 88 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**25-063**|For a final prize pool of 670, the engine output is checked against the approved reference style 370 / 200 / 80 / 20; any material<br>deviation is documented and justified.|☐|☐||
|**25-064**|For a final prize pool of 680, the engine output is checked against the approved reference style 370 / 210 / 80 / 20; any material<br>deviation is documented and justified.|☐|☐||
|**25-065**|For a final prize pool of 690, the engine output is checked against the approved reference style 380 / 210 / 80 / 20; any material<br>deviation is documented and justified.|☐|☐||
|**25-066**|For a final prize pool of 700, the engine output is checked against the approved reference style 390 / 210 / 80 / 20; any material<br>deviation is documented and justified.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 89 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **26. Final Defect Closure and Sign-Off** 

This section is completed only after all detailed checks and UAT scenarios have been performed. 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**26.1 Defe**|**ct closure**||||
|**26-001**|Every defect found during developer testing has a unique ID and recorded resolution.|☐|☐||
|**26-002**|Every defect found during client UAT has a unique ID and recorded resolution.|☐|☐||
|**26-003**|All critical defects are closed and retested.|☐|☐||
|**26-004**|All high-severity defects are closed and retested.|☐|☐||
|**26-005**|No medium/low defect blocks a core flow or contradicts this checklist.|☐|☐||
|**26-006**|Regression testing is completed after the final bug-fix build.|☐|☐||
|**26-007**|The final build numbers/commit hash are recorded in the sign-off section.|☐|☐||
|**26-008**|The live production deployment matches the signed-off source code/build.|☐|☐||
|**26.2 Fina**|**l acceptance package**||||
|**26-009**|Developer checklist is fully marked and signed.|☐|☐||
|**26-010**|Client checklist is fully marked and signed.|☐|☐||
|**26-011**|Evidence links/files are available for all major modules.|☐|☐||
|**26-012**|Source repository ownership is confirmed.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 90 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**ID**|**Acceptance requirement**|**Dev**|**Client**|**Evidence / Notes**|
|---|---|---|---|---|
|**26-013**|Production account ownership is confirmed.|☐|☐||
|**26-014**|Web production URL is confirmed.|☐|☐||
|**26-015**|Android release/build status is confirmed.|☐|☐||
|**26-016**|iOS release/build status is confirmed.|☐|☐||
|**26-017**|All credentials and documentation are delivered.|☐|☐||
|**26-018**|The support/bug-fix period start and end dates are written.|☐|☐||
|**26-019**|Any accepted exceptions are listed in the signed exception table.|☐|☐||
|**26-020**|Final payment release is authorised only after the client signs final acceptance.|☐|☐||



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 91 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **Defect Log** 

Record every failed item here. Use one row per distinct defect. Add pages if required. 

|**Defect ID**<br>**Checklist ID**<br>**Description / steps**<br>**Severity**<br>**Ow**|**ner**<br>**Target date**|**Retest evidence**<br>**Status**|
|---|---|---|















Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 92 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

|**Defect ID**<br>**Checklist ID**<br>**Description / steps**<br>**Severity**<br>**Ow**|**ner**<br>**Target date**|**Retest evidence**<br>**Status**|
|---|---|---|













Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 93 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **Mutually Approved Exceptions (if any)** 

An exception is valid only when both parties sign it. A verbal message or an unapproved developer assumption is not enough. 

|**Exception ID**<br>**Checklist ID(s)**<br>**Exact change / reason**|**Developer approval**<br>**Client approval**<br>**Date**|
|---|---|



Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 94 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

### **Final Release and Payment Sign-Off** 

Total acceptance checks in this document: 1019. 

The developer confirms that every in-scope item has been implemented and that the delivered source code matches the tested production build. 

The client confirms that every in-scope item has been tested and accepted, except only the signed exceptions listed above. 

Final payment may be released only after the client signs this page. 



<!-- Start of picture text -->
Final  Produ<br>source  ction<br>commit /  web<br>tag URL<br>Android  Andro<br>version /  id<br>build releas<br>e<br>status<br>iOS  iOS<br>version /  releas<br>build e<br>status<br>Backend  Datab<br>environm ase<br>ent projec<br>t<br>Support  Open<br>period  accept<br>ends ed<br>minor<br>defect<br>s<br><!-- End of picture text -->

**Developer name: _______________________________________    Date: ____________________** 

Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 95 

**POKER NIGHT  |  FINAL FEATURE, FUNCTION & RELEASE ACCEPTANCE CHECKLIST** 

**Developer signature: __________________________________________________________________** 

**Client name: ___________________________________________    Date: ____________________** 

**Client signature: _____________________________________________________________________** 

##### **FINAL CLIENT DECISION** 

☐ **ACCEPTED — release final payment** ☐ **NOT ACCEPTED — unresolved checklist items remain** 

Mutually approved scope. Final payment is conditional on completion of all in-scope items.  Page 96 

