# Poker Night — Complete Specification Mapping & Visual Verification Dossier

This document indexes all **46 visual verification boards and annotated PNGs**, mapping every single client specification requirement directly onto the UI.

---

## 1. Master All-In-One Unified Canvas
A single comprehensive artboard formatted in flow rows (like `App redesign project.pdf` / `App redesign-1.png`):
- **Master Board File**: `C:\Users\farooq sarwar\Downloads\spec_mappings\MASTER_APP_SPEC_MAPPING_BOARD.png`
- **Resolution**: 2,449 × 15,750 px
- **Features**: Includes all 46 screens, 179 mapped requirements, numbered UI badge pins `[1]`, `[2]`, `[3]`, and status indicators.

---

## 2. Modular Flow Boards (For High-Resolution Reading)

For focused client discussions on specific user journeys, 6 dedicated high-resolution flow boards are generated in `C:\Users\farooq sarwar\Downloads\spec_mappings\`:

| Flow | Title & Sections | Screens | Key Requirements Mapped |
| :--- | :--- | :---: | :--- |
| **`FLOW_A_SPEC_MAP.png`** | **Flow A: Onboarding & Access (§A1–§A8)** | 8 | Themed asset logo, anonymous quick play, 6-char Crockford resolver, guest shell restriction |
| **`FLOW_B_SPEC_MAP.png`** | **Flow B: Group Hub & Social (§B1–§B13)** | 7 | Club switcher, 5-tab glass nav, real-time chat, game scheduling polls, push alerts, game archives |
| **`FLOW_C_SPEC_MAP.png`** | **Flow C: Tournament Hosting & Clock (§C0–§C11)** | 11 | 60-second quick start, 5-step wizard, TDA seating, TV clock, Rebuys, Final Table 03_07 (SVG ring & restricted Declare), ICM deal, Podium |
| **`FLOW_D_SPEC_MAP.png`** | **Flow D: Cash Game & TV Broadcast (§D1–§D3)** | 3 | Cash stakes & chip ledger, Greedy "Who Pays Whom" debt simplification, 16:9 fullscreen TV mode |
| **`FLOW_E_SPEC_MAP.png`** | **Flow E: Public Free Tools (§E1–§E6)** | 6 | Zero-login tools hub, Blind structure generator, Standalone clock, ICM calculator, Payout calculator |
| **`FLOW_F_SPEC_MAP.png`** | **Flow F: Profile, Settings & Legal (§F1–§H3)** | 11 | Sound & TTS voice controls, Theme palette switcher, Chip set editor, Presets, Pro upgrade, GDPR Privacy & Terms |

---

## 3. Individual Screen PNGs with Spec Pins

All 45 individual annotated screen cards are saved in `C:\Users\farooq sarwar\Downloads\spec_mappings\screens\`:
Each file contains the rendered screen with numbered crimson badges overlaid on the features, plus a dark spec checklist table directly underneath showing the exact requirement and `PASS` status.

### Flow A — Onboarding & Public
- `01_01_splash_spec_mapped.png`: Brand lockup, cold start route resolver (§A1)
- `01_02_landing_spec_mapped.png`: Anonymous host mode, join code/QR scanner, free tools access (§A2, §A2b)
- `01_03_sign_in_spec_mapped.png`: Firebase auth, password recovery (§A3)
- `01_04_register_spec_mapped.png`: Profile creation, mandatory terms agreement (§A4)
- `01_05_forgot_password_spec_mapped.png`: Password reset engine (§A5)
- `01_06_guest_flow_spec_mapped.png`: Guest display name, strictly restricted guest shell (§A6, §C4)
- `01_07_join_by_code_spec_mapped.png`: Crockford base-32 resolver, camera QR scanner (§A7, §E7)
- `01_08_join_group_spec_mapped.png`: Club preview card, one-tap join action (§A8, §B13)

### Flow B — The Group Hub & Social
- `02_01_home_spec_mapped.png`: Multi-group switcher, quick tournament hero CTA, glass bottom nav (§B1, §C1)
- `02_02_group_games_spec_mapped.png`: Active & scheduled tables list, host game launcher (§B2)
- `02_03_members_spec_mapped.png`: Member permissions, badges, invite link & QR generator (§B3, §E6)
- `02_04_chat_spec_mapped.png`: Real-time chat stream, automated level/rebuy broadcast alerts (§B4, §E10)
- `02_05_polls_spec_mapped.png`: Game scheduling polls, live vote tallies (§B5)
- `02_06_notifications_spec_mapped.png`: Activity feed, OneSignal push notifications (§B6)
- `02_07_history_spec_mapped.png`: Archived tournaments, detailed elimination records (§B7)

### Flow C — Tournament Hosting & Live Flow
- `03_00_quick_start_spec_mapped.png`: 4-question 60-second setup, auto-seeded chip structure, instant live clock launch (§C0)
- `03_01_create_tournament_spec_mapped.png`: 5-step wizard, chip-aware structure calculation, KO bounties (§C1)
- `03_02_structure_review_spec_mapped.png`: Level-by-level blind editor, breaks, live duration recalculation (§C2)
- `03_03_invitation_spec_mapped.png`: RSVP roster, TDA random seating and table balancing (§C3, §C4, §F3)
- `03_04_check_in_spec_mapped.png`: Physical arrival check-in, buy-in paid tracker (§C4p)
- `03_05_admin_dashboard_spec_mapped.png`: TV-style scoreboard timer, clock controls (+1m/-1m/pause), bust-out drawer (§C5, §F4)
- `03_06_rebuy_settlement_spec_mapped.png`: Dynamic prize pool expansion, rebuy counter with undo support (§C6, §F2)
- `03_07_final_table_spec_mapped.png`: SVG circular blind countdown ring, tabular chip leaderboard, restricted Declare Winner (<= 2 players), quick host action drawer (§C7, §C5b, §C8)
- `03_08_complete_tournament_spec_mapped.png`: Drag-to-reorder finish positions, Malmuth-Harville ICM chip chop engine (§C8, §F2)
- `03_09_result_podium_spec_mapped.png`: 1st/2nd/3rd animated podium, season standings sync (§C9, §B11)
- `03_10_player_list_spec_mapped.png`: Personal seat/stack card, read-only structure tab (§C10, §C11)

### Flow D — Cash Game & TV Mode
- `04_01_cash_game_setup_spec_mapped.png`: Stakes, buy-in caps, settlement tracker toggle (§D1)
- `04_02_cash_game_live_spec_mapped.png`: Table chip integrity ledger, "Who Pays Whom" greedy debt simplification (§D2, §F5)
- `04_03_tv_mode_spec_mapped.png`: 16:9 fullscreen spectator layout, audio chimes & TTS voice alerts (§D3, §E12)

### Flow E — Public Free Tools
- `05_01_tools_hub_spec_mapped.png`: No-login poker calculators grid (§E1)
- `05_02_blind_structure_spec_mapped.png`: Chip-aware blind schedule generator (§E2)
- `05_03_tournament_clock_spec_mapped.png`: Standalone timer scoreboard with chimes (§E3)
- `05_04_icm_calculator_spec_mapped.png`: Independent Chip Model equity calculator (§E4)
- `05_05_payouts_spec_mapped.png`: Standard tiered payout calculator (§E5)
- `05_06_quick_blind_spec_mapped.png`: 30-second quick blind recommendation (§E6)

### Flow F — Profile, Settings, Presets, Upgrade & Legal
- `06_01_profile_spec_mapped.png`: Player identity, career profit/loss, win stats (§F1)
- `06_02_settings_spec_mapped.png`: Audio master, voice synthesizer, theme palette switcher (§F2, §B1)
- `06_03_stats_spec_mapped.png`: In-depth performance analytics, average finish, ITM % (§F3)
- `06_04_chip_sets_spec_mapped.png`: Custom physical chip inventory (§F4)
- `06_05_edit_chip_set_spec_mapped.png`: Denominations & colors editor (§F5)
- `06_06_presets_spec_mapped.png`: One-tap tournament templates (§F6)
- `07_01_upgrade_spec_mapped.png`: Free vs Pro feature comparison matrix (§G1)
- `07_02_checkout_spec_mapped.png`: Pro subscription flow, 7-day trial (§G2)
- `08_01_privacy_spec_mapped.png`: GDPR / CCPA privacy policy (§H2)
- `08_02_terms_spec_mapped.png`: Terms of service & home-game disclaimer (§H1)
- `08_03_support_spec_mapped.png`: Support FAQ, crash recovery guide, direct contact (§H3)
