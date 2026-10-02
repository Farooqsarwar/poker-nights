#!/usr/bin/env python3
"""
Generates POKER_NIGHT_COMPLETE_CLIENT_SPEC.html as a 100% self-contained,
single-file HTML presentation document with all flow images embedded as Base64.
Can be sent directly as a single file to clients to open in any web browser.
"""

import os
import base64

ROOT = r"D:\StudioProjects\poker_night"
OUTPUT_HTML = os.path.join(ROOT, "POKER_NIGHT_COMPLETE_CLIENT_SPEC.html")

def get_base64_img(rel_path):
    full_path = os.path.join(ROOT, rel_path)
    if not os.path.exists(full_path):
        print(f"Warning: missing {full_path}")
        return ""
    with open(full_path, "rb") as f:
        data = f.read()
    b64 = base64.b64encode(data).decode("utf-8")
    return f"data:image/png;base64,{b64}"

print("Encoding flow images to Base64...")
master_b64 = get_base64_img("spec_boards/mobile/MASTER_APP_SPEC_MAPPING_BOARD.png")
flow_a_b64 = get_base64_img("spec_boards/mobile/FLOW_A_ONBOARDING_SPEC_MAP.png")
flow_b_b64 = get_base64_img("spec_boards/mobile/FLOW_B_GROUP_HUB_SPEC_MAP.png")
flow_c_b64 = get_base64_img("spec_boards/mobile/FLOW_C_HOSTING_SPEC_MAP.png")
flow_d_b64 = get_base64_img("spec_boards/mobile/FLOW_D_CASH_TV_SPEC_MAP.png")
flow_e_b64 = get_base64_img("spec_boards/mobile/FLOW_E_TOOLS_SPEC_MAP.png")
flow_f_b64 = get_base64_img("spec_boards/mobile/FLOW_F_PROFILE_SETTINGS_SPEC_MAP.png")
print("Encoding complete. Building HTML presentation...")

html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Poker Night — Complete Specification & UI Architecture</title>
  <style>
    :root {{
      --bg: #0A0B0F;
      --card-bg: #12141D;
      --card-border: #232738;
      --accent: #E11D48;
      --accent-green: #10B981;
      --accent-cyan: #06B6D4;
      --text-white: #FFFFFF;
      --text-primary: #F1F5F9;
      --text-muted: #94A3B8;
      --font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    }}
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    html {{ scroll-behavior: smooth; }}
    body {{
      background: var(--bg);
      color: var(--text-primary);
      font-family: var(--font-family);
      line-height: 1.6;
      padding-bottom: 80px;
    }}
    header {{
      background: rgba(18, 20, 29, 0.95);
      backdrop-filter: blur(12px);
      border-bottom: 1px solid var(--card-border);
      padding: 20px 40px;
      position: sticky;
      top: 0;
      z-index: 1000;
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-wrap: wrap;
      gap: 16px;
      box-shadow: 0 4px 25px rgba(0,0,0,0.7);
    }}
    .brand-title {{ font-size: 22px; font-weight: 800; color: #FFF; letter-spacing: -0.5px; }}
    .brand-subtitle {{ color: var(--accent); font-size: 13px; font-weight: 600; margin-top: 2px; }}
    .nav-links {{ display: flex; gap: 8px; flex-wrap: wrap; }}
    .nav-link {{
      background: #181B28;
      color: var(--text-primary);
      text-decoration: none;
      font-size: 12px;
      font-weight: 700;
      padding: 6px 14px;
      border-radius: 6px;
      border: 1px solid var(--card-border);
      transition: all 0.2s ease;
    }}
    .nav-link:hover {{
      background: var(--accent);
      border-color: var(--accent);
      color: #FFF;
      transform: translateY(-1px);
    }}
    .container {{
      max-width: 1400px;
      margin: 0 auto;
      padding: 30px 24px;
    }}
    .flow-section {{
      margin-bottom: 60px;
      padding-top: 30px;
    }}
    .flow-badge {{
      background: rgba(225, 29, 72, 0.15);
      color: var(--accent);
      border: 1px solid var(--accent);
      font-size: 11px;
      padding: 4px 10px;
      border-radius: 6px;
      font-weight: 800;
      letter-spacing: 0.5px;
      display: inline-block;
      margin-bottom: 10px;
    }}
    .section-heading {{
      font-size: 26px;
      font-weight: 800;
      color: #FFF;
      margin-bottom: 6px;
    }}
    .section-desc {{
      color: var(--text-muted);
      font-size: 15px;
      margin-bottom: 24px;
      max-width: 1100px;
    }}
    .board-container {{
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 16px;
      padding: 16px;
      margin-bottom: 28px;
      box-shadow: 0 10px 35px rgba(0,0,0,0.5);
      position: relative;
    }}
    .board-container img {{
      width: 100%;
      height: auto;
      border-radius: 10px;
      display: block;
      cursor: zoom-in;
      transition: opacity 0.2s;
    }}
    .board-container img:hover {{
      opacity: 0.96;
    }}
    .zoom-hint {{
      position: absolute;
      top: 26px;
      right: 26px;
      background: rgba(10, 11, 15, 0.85);
      backdrop-filter: blur(8px);
      border: 1px solid var(--card-border);
      color: #FFF;
      font-size: 11px;
      font-weight: 700;
      padding: 6px 12px;
      border-radius: 20px;
      pointer-events: none;
    }}
    .specs-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(420px, 1fr));
      gap: 18px;
    }}
    .spec-card {{
      background: #141724;
      border: 1px solid var(--card-border);
      border-radius: 12px;
      padding: 20px;
      display: flex;
      flex-direction: column;
    }}
    .spec-card-header {{
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      margin-bottom: 10px;
      gap: 12px;
    }}
    .spec-card-title {{
      font-size: 16px;
      font-weight: 700;
      color: #FFF;
    }}
    .spec-card-route {{
      font-size: 11px;
      color: var(--accent-cyan);
      font-family: monospace;
      margin-top: 3px;
    }}
    .spec-card-ref {{
      background: #1E2235;
      color: var(--text-muted);
      font-size: 10px;
      font-weight: 800;
      padding: 3px 8px;
      border-radius: 4px;
      white-space: nowrap;
    }}
    .spec-card-body {{
      color: var(--text-muted);
      font-size: 13px;
      line-height: 1.55;
    }}
    .spec-card-body ul {{
      margin-left: 18px;
      margin-top: 8px;
    }}
    .spec-card-body li {{
      margin-bottom: 5px;
    }}
    .divider {{
      border: none;
      border-top: 1px solid var(--card-border);
      margin: 50px 0;
    }}
    .engine-table-card {{
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 14px;
      overflow: hidden;
      margin-top: 20px;
    }}
    .engine-table {{
      width: 100%;
      border-collapse: collapse;
      font-size: 13px;
      text-align: left;
    }}
    .engine-table th {{
      background: #181B29;
      color: #FFF;
      font-weight: 700;
      padding: 14px 18px;
      border-bottom: 1px solid var(--card-border);
    }}
    .engine-table td {{
      padding: 14px 18px;
      border-bottom: 1px solid #1C2030;
      color: var(--text-muted);
    }}
    .engine-table tr:last-child td {{
      border-bottom: none;
    }}
    .engine-title {{
      color: #FFF;
      font-weight: 700;
    }}

    /* Lightbox Modal */
    #lightbox {{
      display: none;
      position: fixed;
      top: 0; left: 0; width: 100%; height: 100%;
      background: rgba(0, 0, 0, 0.94);
      backdrop-filter: blur(10px);
      z-index: 9999;
      overflow: auto;
      padding: 30px;
      cursor: zoom-out;
    }}
    #lightbox-img {{
      display: block;
      margin: 0 auto;
      max-width: 95%;
      border-radius: 8px;
      box-shadow: 0 0 50px rgba(0,0,0,0.9);
    }}
    #lightbox-close {{
      position: fixed;
      top: 20px;
      right: 30px;
      color: #FFF;
      font-size: 32px;
      font-weight: bold;
      cursor: pointer;
      background: rgba(255,255,255,0.1);
      width: 44px;
      height: 44px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      line-height: 1;
    }}
  </style>
</head>
<body>

  <header>
    <div>
      <div class="brand-title">POKER NIGHT · SPECIFICATION ARCHITECTURE</div>
      <div class="brand-subtitle">Reformed Client Walkthrough Mapped by User Flow</div>
    </div>
    <div class="nav-links">
      <a class="nav-link" href="#master">Master Artboard</a>
      <a class="nav-link" href="#flow-a">Flow A: Onboarding</a>
      <a class="nav-link" href="#flow-b">Flow B: Group Hub</a>
      <a class="nav-link" href="#flow-c">Flow C: Hosting & Clock</a>
      <a class="nav-link" href="#flow-d">Flow D: Cash & TV</a>
      <a class="nav-link" href="#flow-e">Flow E: Free Tools</a>
      <a class="nav-link" href="#flow-f">Flow F: Account & Legal</a>
      <a class="nav-link" href="#engines">Engines & Math</a>
    </div>
  </header>

  <div class="container">

    <!-- MASTER ARTBOARD -->
    <section class="flow-section" id="master">
      <span class="flow-badge">UNIFIED SYSTEM</span>
      <h2 class="section-heading">Master Application Architecture Board (All 46 Screens)</h2>
      <p class="section-desc">Single unified master canvas showcasing all 46 production-rendered screens across all user flows. Click the board image to expand into full-screen high-resolution zoom mode.</p>
      <div class="board-container">
        <span class="zoom-hint">🔍 Click to Zoom</span>
        <img src="{master_b64}" alt="Poker Night Master Artboard" onclick="openLightbox(this)">
      </div>
    </section>

    <hr class="divider">

    <!-- FLOW A -->
    <section class="flow-section" id="flow-a">
      <span class="flow-badge">FLOW A</span>
      <h2 class="section-heading">Onboarding, Access & Authentication (8 Screens)</h2>
      <p class="section-desc">Immediate, frictionless entry for returning club members, anonymous home hosts running a quick tournament tonight without an account ("Start a Game Now"), and invited guests scanning a table QR code.</p>

      <div class="board-container">
        <span class="zoom-hint">🔍 Click to Zoom Flow A</span>
        <img src="{flow_a_b64}" alt="Flow A Overall Flow Board" onclick="openLightbox(this)">
      </div>

      <div class="specs-grid">
        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">01_01 Splash Screen</div>
              <div class="spec-card-route">/</div>
            </div>
            <span class="spec-card-ref">§A1, §C3</span>
          </div>
          <div class="spec-card-body">
            Responsive vector spade logo with 3D card flip landing cleanly on the brand wordmark.
            <ul>
              <li><strong>Cold-Start Route Resolver:</strong> Inspects cached tokens: sends authenticated club members to Home, visitors to Landing.</li>
            </ul>
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">01_02 Public Landing</div>
              <div class="spec-card-route">/landing</div>
            </div>
            <span class="spec-card-ref">§A2, §A2b</span>
          </div>
          <div class="spec-card-body">
            Welcomes visitors with 3 clear pathways:
            <ul>
              <li><strong>Anonymous Host Mode:</strong> "Start a game now" bypasses account creation, seeding an immediate tournament setup tonight.</li>
              <li><strong>Join Table:</strong> 6-character Crockford code input and QR scanner.</li>
              <li><strong>Free Tools:</strong> Direct access to public poker calculators.</li>
            </ul>
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">01_03 User Sign In</div>
              <div class="spec-card-route">/auth?mode=signin</div>
            </div>
            <span class="spec-card-ref">§A3</span>
          </div>
          <div class="spec-card-body">
            Authentication with Google Sign-In or email/password.
            <ul>
              <li>Persistent device login token handling.</li>
              <li>Password visibility toggle and inline "Forgot Password?" trigger.</li>
            </ul>
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">01_04 Account Registration</div>
              <div class="spec-card-route">/auth?mode=register</div>
            </div>
            <span class="spec-card-ref">§A4, §E15</span>
          </div>
          <div class="spec-card-body">
            Full user profile setup (Full Name, email, passwords) with legal consent gates:
            <ul>
              <li><strong>Mandatory:</strong> "I'm 18 or older and agree to the Terms" checkbox.</li>
              <li><strong>Optional:</strong> "Keep my game history so structures and end times learn from our real nights".</li>
            </ul>
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">01_05 Password Recovery</div>
              <div class="spec-card-route">/auth?mode=reset</div>
            </div>
            <span class="spec-card-ref">§A5</span>
          </div>
          <div class="spec-card-body">
            Single email input field with anti-spam throttle limits.
            <ul>
              <li>Instant feedback message confirming secure reset link dispatch.</li>
            </ul>
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">01_06 Guest Table Flow</div>
              <div class="spec-card-route">/guest-flow</div>
            </div>
            <span class="spec-card-ref">§A6, §C4</span>
          </div>
          <div class="spec-card-body">
            Frictionless guest name entry for table players scanning host QR codes.
            <ul>
              <li><strong>Strict Guest Shell N5:</strong> Table guests see only their table, seat, stack, and personal clock. Host menus, club creation, and billing are completely hidden.</li>
            </ul>
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">01_07 Join by Code</div>
              <div class="spec-card-route">/join</div>
            </div>
            <span class="spec-card-ref">§A7, §E7</span>
          </div>
          <div class="spec-card-body">
            Instant table and club entry:
            <ul>
              <li><strong>Crockford Base-32:</strong> 6-character room codes omitting ambiguous characters (<code>I, L, O, U, 0, 1</code>) to prevent verbal confusion.</li>
              <li><strong>Camera QR Scanner:</strong> Viewfinder resolving table codes in under 1 second.</li>
            </ul>
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">01_08 Group Invitation Preview</div>
              <div class="spec-card-route">/group/join/:code</div>
            </div>
            <span class="spec-card-ref">§A8, §B13</span>
          </div>
          <div class="spec-card-body">
            Club invitation preview card:
            <ul>
              <li>Displays club name ("Friday Poker Club"), owner avatar, member count, and active game preview.</li>
              <li>One-tap confirmation adds the player directly to the club roster.</li>
            </ul>
          </div>
        </div>
      </div>
    </section>

    <hr class="divider">

    <!-- FLOW B -->
    <section class="flow-section" id="flow-b">
      <span class="flow-badge">FLOW B</span>
      <h2 class="section-heading">The Group Hub & Social Operations (7 Screens)</h2>
      <p class="section-desc">Single-layer navigation with a 5-tab floating glass bar for recurring home games. Houses scheduled tournaments, active live game banners, member administration, group chat with automated game bots, scheduling polls, and push notifications.</p>

      <div class="board-container">
        <span class="zoom-hint">🔍 Click to Zoom Flow B</span>
        <img src="{flow_b_b64}" alt="Flow B Overall Flow Board" onclick="openLightbox(this)">
      </div>

      <div class="specs-grid">
        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">02_01 Home Hub</div>
              <div class="spec-card-route">/home</div>
            </div>
            <span class="spec-card-ref">§B1, §C1</span>
          </div>
          <div class="spec-card-body">
            Club switcher dropdown, hero quick-action banner to launch tournaments or cash sessions, and floating glass bottom navigation (Home, Games, Chat, Members, More).
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">02_02 Group Games Hub</div>
              <div class="spec-card-route">/group/games</div>
            </div>
            <span class="spec-card-ref">§B2</span>
          </div>
          <div class="spec-card-body">
            Active live tables highlighted at the top with level, blinds, and timer summary, followed by scheduled upcoming dates and dedicated game creation launchers.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">02_03 Member Directory</div>
              <div class="spec-card-route">/group/members</div>
            </div>
            <span class="spec-card-ref">§B3, §E6</span>
          </div>
          <div class="spec-card-body">
            Member roster with Host, Admin, and Member role badges, player performance stats summaries, and instant invite link / QR code generator.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">02_04 Live Chat Stream</div>
              <div class="spec-card-route">/group/chat</div>
            </div>
            <span class="spec-card-ref">§B4, §E10</span>
          </div>
          <div class="spec-card-body">
            Real-time player messaging combined with automated system broadcast announcements for level increases, break reminders, rebuy closes, and player eliminations.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">02_05 Scheduling Polls</div>
              <div class="spec-card-route">/group/polls</div>
            </div>
            <span class="spec-card-ref">§B5</span>
          </div>
          <div class="spec-card-body">
            Interactive voting polls for picking game nights (e.g. "When should we play next Friday?"). Closing the poll automatically drafts a tournament for the winning date.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">02_06 Notification Center</div>
              <div class="spec-card-route">/group/notifications</div>
            </div>
            <span class="spec-card-ref">§B6</span>
          </div>
          <div class="spec-card-body">
            Activity stream showing game reminders ("Game starts in 1 hour"), RSVP deadlines, and podium announcements. Synced with OneSignal push notifications.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">02_07 History & Archives</div>
              <div class="spec-card-route">/group/history</div>
            </div>
            <span class="spec-card-ref">§B7, §E14</span>
          </div>
          <div class="spec-card-body">
            Chronological archive of past tournaments with winners, prize pools, and turnouts. Deep drill-down into elimination sequences and season leaderboard points.
          </div>
        </div>
      </div>
    </section>

    <hr class="divider">

    <!-- FLOW C -->
    <section class="flow-section" id="flow-c">
      <span class="flow-badge">FLOW C</span>
      <h2 class="section-heading">Tournament Hosting, Live Clock & Deals (11 Screens)</h2>
      <p class="section-desc">The flagship tournament engine. Supports 60-second quick play or deep 5-step custom wizards, TDA table balancing, drift-free TV clock with host pause/undo controls, dynamic rebuy expansions, Final Table circular SVG countdown ring, and mathematical Malmuth-Harville ICM chip deals.</p>

      <div class="board-container">
        <span class="zoom-hint">🔍 Click to Zoom Flow C</span>
        <img src="{flow_c_b64}" alt="Flow C Overall Flow Board" onclick="openLightbox(this)">
      </div>

      <div class="specs-grid">
        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">03_00 Quick Start</div>
              <div class="spec-card-route">/tournament/quick-start</div>
            </div>
            <span class="spec-card-ref">§C0, §F1</span>
          </div>
          <div class="spec-card-body">
            4 simple questions (Players, Target Hours, Buy-in $, Chip Set). Auto-seeds the blind ladder and launches the live clock in 60 seconds.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">03_01 Tournament Wizard</div>
              <div class="spec-card-route">/tournament/create</div>
            </div>
            <span class="spec-card-ref">§C1, §E8</span>
          </div>
          <div class="spec-card-body">
            5-step custom wizard: Basics & Venue, Chip Sets, Buy-in/Rebuys/KO Bounties, Structure Pacing, and Invitations. Buy-in and rebuy costs freeze permanently once posted.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">03_02 Structure Review</div>
              <div class="spec-card-route">/tournament/structure</div>
            </div>
            <span class="spec-card-ref">§C2, §F1</span>
          </div>
          <div class="spec-card-body">
            Visual blind ladder editor with break insertion. Changing level times or blind steps instantly recalculates the estimated finish duration.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">03_03 RSVPs & Seating</div>
              <div class="spec-card-route">/tournament/invitation</div>
            </div>
            <span class="spec-card-ref">§C3, §F3</span>
          </div>
          <div class="spec-card-body">
            RSVP roster (Going, Maybe, Can't) with automated TDA table balancing (tables never differ by more than 1 player at any time).
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">03_04 Physical Check-In</div>
              <div class="spec-card-route">/tournament/check-in</div>
            </div>
            <span class="spec-card-ref">§C4, §E8</span>
          </div>
          <div class="spec-card-body">
            Arrival check-in toggle and buy-in payment collection tracker. When the first player receives chips, starting chip stacks freeze permanently.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">03_05 Admin Dashboard Clock</div>
              <div class="spec-card-route">/tournament/live/admin</div>
            </div>
            <span class="spec-card-ref">§C5, §F4</span>
          </div>
          <div class="spec-card-body">
            Drift-free scoreboard clock showing current/next blinds, chip averages, pause/resume, +1m/-1m adjustments, and bust-out drawer with knockout bounty tracking and instant undo.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">03_06 Rebuy Settlement</div>
              <div class="spec-card-route">/tournament/live/rebuys</div>
            </div>
            <span class="spec-card-ref">§C6</span>
          </div>
          <div class="spec-card-body">
            Tracks rebuys and add-ons per player, dynamically expanding the prize pool in real time until the hard level lock.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">03_07 Final Table Mode</div>
              <div class="spec-card-route">/tournament/live/final-table</div>
            </div>
            <span class="spec-card-ref">§C7, Addendum 1</span>
          </div>
          <div class="spec-card-body">
            Glowing circular SVG countdown ring with active chip counts. "Declare Winner" is strictly disabled while >2 players remain to prevent accidental game finishes.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">03_08 Complete & ICM Deals</div>
              <div class="spec-card-route">/tournament/complete</div>
            </div>
            <span class="spec-card-ref">§C8, §F2</span>
          </div>
          <div class="spec-card-body">
            Drag-to-reorder final rankings with an integrated Malmuth-Harville ICM chip-chop deal calculator for fair prize distribution.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">03_09 Results Podium</div>
              <div class="spec-card-route">/tournament/podium</div>
            </div>
            <span class="spec-card-ref">§C9, §E14</span>
          </div>
          <div class="spec-card-body">
            1st, 2nd, and 3rd place podium celebrating winners, cash won, and KO bounties, automatically syncing points to the season leaderboard.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">03_10 Player Live Spectator</div>
              <div class="spec-card-route">/tournament/live/player</div>
            </div>
            <span class="spec-card-ref">§C10</span>
          </div>
          <div class="spec-card-body">
            Personal spectator screen showing the player their table number, seat assignment, stack size, and read-only blind schedule.
          </div>
        </div>
      </div>
    </section>

    <hr class="divider">

    <!-- FLOW D -->
    <section class="flow-section" id="flow-d">
      <span class="flow-badge">FLOW D</span>
      <h2 class="section-heading">Cash Game & Living Room TV Mode (3 Screens)</h2>
      <p class="section-desc">Reconciles cash stakes, tracks table chip balances, solves "Who Pays Whom" debt settlement with zero math arguments, and provides a 16:9 fullscreen spectator broadcast with voice alerts.</p>

      <div class="board-container">
        <span class="zoom-hint">🔍 Click to Zoom Flow D</span>
        <img src="{flow_d_b64}" alt="Flow D Overall Flow Board" onclick="openLightbox(this)">
      </div>

      <div class="specs-grid">
        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">04_01 Cash Game Setup</div>
              <div class="spec-card-route">/cash/setup</div>
            </div>
            <span class="spec-card-ref">§D1</span>
          </div>
          <div class="spec-card-body">
            Small blind, big blind, min/max buy-in limits (e.g. $1/$2 blinds, $100 min / $300 max), and automatic settlement ledger tracking.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">04_02 Live Table & Greedy Settlement</div>
              <div class="spec-card-route">/cash/live</div>
            </div>
            <span class="spec-card-ref">§D2, §F5</span>
          </div>
          <div class="spec-card-body">
            Live table chip ledger tracking buy-ins, current stacks, and cashed-out amounts. Uses an optimal Greedy Debt Minimization algorithm ("Who Pays Whom") to settle all debts with minimal payments.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">04_03 Fullscreen TV Spectator Mode</div>
              <div class="spec-card-route">/tv/:code</div>
            </div>
            <span class="spec-card-ref">§D3, §E11, §E12</span>
          </div>
          <div class="spec-card-body">
            16:9 fullscreen spectator layout for living-room TVs and projectors. Features giant high-contrast timer numbers, 1-minute warning chimes, and speech synthesis announcing upcoming blinds.
          </div>
        </div>
      </div>
    </section>

    <hr class="divider">

    <!-- FLOW E -->
    <section class="flow-section" id="flow-e">
      <span class="flow-badge">FLOW E</span>
      <h2 class="section-heading">Public Free Tools (6 Screens)</h2>
      <p class="section-desc">Five free, standalone poker calculators accessible by anyone directly on the web or in the app with zero login or account creation required.</p>

      <div class="board-container">
        <span class="zoom-hint">🔍 Click to Zoom Flow E</span>
        <img src="{flow_e_b64}" alt="Flow E Overall Flow Board" onclick="openLightbox(this)">
      </div>

      <div class="specs-grid">
        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">05_01 Public Tools Hub</div>
              <div class="spec-card-route">/tools</div>
            </div>
            <span class="spec-card-ref">§E1</span>
          </div>
          <div class="spec-card-body">
            Visual directory of the 5 free calculators with soft prompts into the full app.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">05_02 Blind Structure Generator</div>
              <div class="spec-card-route">/tools/blinds</div>
            </div>
            <span class="spec-card-ref">§E2, §F1</span>
          </div>
          <div class="spec-card-body">
            Chip-aware blind ladder generator configured for standard physical home chip sets (300 or 500-chip boxes) without requiring manual math.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">05_03 Standalone Tournament Clock</div>
              <div class="spec-card-route">/tools/clock</div>
            </div>
            <span class="spec-card-ref">§E3</span>
          </div>
          <div class="spec-card-body">
            Simple tournament timer with level adjustments, breaks, and audio alert bells for quick home games without club management.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">05_04 ICM Equity Calculator</div>
              <div class="spec-card-route">/tools/icm</div>
            </div>
            <span class="spec-card-ref">§E4, §F2</span>
          </div>
          <div class="spec-card-body">
            Computes exact monetary equity based on stack sizes and remaining prize tiers using verified Malmuth-Harville mathematics.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">05_05 Payout Calculator</div>
              <div class="spec-card-route">/tools/payouts</div>
            </div>
            <span class="spec-card-ref">§E5, §F2</span>
          </div>
          <div class="spec-card-body">
            Generates tiered tournament payout curves for fields ranging from 2 players up to 100+ players.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">05_06 Quick Blind Recommender</div>
              <div class="spec-card-route">/tools/quick-blind</div>
            </div>
            <span class="spec-card-ref">§E6</span>
          </div>
          <div class="spec-card-body">
            30-second tool giving instant starting blind and level duration recommendations for casual home games starting immediately.
          </div>
        </div>
      </div>
    </section>

    <hr class="divider">

    <!-- FLOW F -->
    <section class="flow-section" id="flow-f">
      <span class="flow-badge">FLOW F</span>
      <h2 class="section-heading">Account, Settings, Presets, Upgrade & Legal (11 Screens)</h2>
      <p class="section-desc">User identity, personal career analytics, audio and voice synthesizer preferences, physical chip inventory management, tournament templates, Pro subscription upgrades, and complete GDPR/CCPA legal compliance.</p>

      <div class="board-container">
        <span class="zoom-hint">🔍 Click to Zoom Flow F</span>
        <img src="{flow_f_b64}" alt="Flow F Overall Flow Board" onclick="openLightbox(this)">
      </div>

      <div class="specs-grid">
        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">06_01 Player Profile</div>
              <div class="spec-card-route">/profile</div>
            </div>
            <span class="spec-card-ref">§F1</span>
          </div>
          <div class="spec-card-body">
            Player career statistics (tournaments played, wins, podium finishes, and knockout count).
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">06_02 Settings (Palettes & Sound)</div>
              <div class="spec-card-route">/settings</div>
            </div>
            <span class="spec-card-ref">§F2, §B1, §E11</span>
          </div>
          <div class="spec-card-body">
            Audio master volume, voice alerts toggle, 4-color deck option, and theme palette switcher (Crimson Red, Blue, Green, Amber, Purple, Obsidian).
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">06_03 Stats Analytics</div>
              <div class="spec-card-route">/stats</div>
            </div>
            <span class="spec-card-ref">§F3, §E14</span>
          </div>
          <div class="spec-card-body">
            Deep tournament analytics: In-The-Money (ITM) percentage, average finish position (4.2), and elimination trends.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">06_04 Chip Sets Inventory</div>
              <div class="spec-card-route">/chip-sets</div>
            </div>
            <span class="spec-card-ref">§F4</span>
          </div>
          <div class="spec-card-body">
            Hardware inventory storing the user's actual physical chip boxes and total piece counts so blind structures never demand impossible chips.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">06_05 Edit Chip Set</div>
              <div class="spec-card-route">/chip-sets/edit</div>
            </div>
            <span class="spec-card-ref">§F5</span>
          </div>
          <div class="spec-card-body">
            Denomination editor for custom chip colors, numeric values (e.g. 25, 100, 500, 1000), and chip quantities.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">06_06 Tournament Presets</div>
              <div class="spec-card-route">/presets</div>
            </div>
            <span class="spec-card-ref">§F6</span>
          </div>
          <div class="spec-card-body">
            Reusable tournament configuration templates (Turbo, Deepstack, Bounty Night) for one-tap hosting.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">07_01 Pro Upgrade</div>
              <div class="spec-card-route">/upgrade</div>
            </div>
            <span class="spec-card-ref">§G1</span>
          </div>
          <div class="spec-card-body">
            Free vs. Pro comparison table highlighting multi-season archives, custom TV branding, unlimited clubs, and SMS alerts.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">07_02 Subscription Checkout</div>
              <div class="spec-card-route">/checkout</div>
            </div>
            <span class="spec-card-ref">§G2</span>
          </div>
          <div class="spec-card-body">
            Subscription checkout card detailing plan benefits, 7-day free trial terms, and cancellation policy.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">08_01 Privacy Policy</div>
              <div class="spec-card-route">/privacy</div>
            </div>
            <span class="spec-card-ref">§H2, §E15</span>
          </div>
          <div class="spec-card-body">
            GDPR and CCPA compliant privacy statement with strict data minimization commitments. Zero sale of personal data.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">08_02 Terms of Service</div>
              <div class="spec-card-route">/terms</div>
            </div>
            <span class="spec-card-ref">§H1</span>
          </div>
          <div class="spec-card-body">
            Terms of service and mandatory home-game compliance disclaimer confirming Poker Night is a tournament clock and manager, not an online gambling platform.
          </div>
        </div>

        <div class="spec-card">
          <div class="spec-card-header">
            <div>
              <div class="spec-card-title">08_03 Support & Recovery</div>
              <div class="spec-card-route">/support</div>
            </div>
            <span class="spec-card-ref">§H3, §E9</span>
          </div>
          <div class="spec-card-body">
            Help FAQ, automatic crash recovery explanation, and direct contact options.
          </div>
        </div>
      </div>
    </section>

    <hr class="divider">

    <!-- ENGINES & MATH -->
    <section class="flow-section" id="engines">
      <span class="flow-badge">MATHEMATICS & ENGINES</span>
      <h2 class="section-heading">Mathematical Verification & Acceptance Reference</h2>
      <p class="section-desc">Key algorithms and automated engines underpinning Poker Night.</p>

      <div class="engine-table-card">
        <table class="engine-table">
          <thead>
            <tr>
              <th>Engine Domain</th>
              <th>Core Formula / Mathematical Rule</th>
              <th>Test Vectors & Verification</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><span class="engine-title">Structure Engine (§F1 & Source 1)</span></td>
              <td>Opening Big Blind B₀ = X / 100; Total levels L = S / (N × B₀); Smooth progression without doubling cliffs.</td>
              <td>759 automated engine test vectors in <code>TournamentEngine</code></td>
            </tr>
            <tr>
              <td><span class="engine-title">Payouts & Deals Engine (§F2)</span></td>
              <td>Tiered tournament curves + exact Malmuth-Harville ICM chip-chop equity calculations for deals.</td>
              <td>55 test vectors + 145 mock interaction tests</td>
            </tr>
            <tr>
              <td><span class="engine-title">Seating & Table Balancing (§F3)</span></td>
              <td>TDA Table Balancing: tables never differ by &gt; 1 player at any time; automatic redraw on final table.</td>
              <td>TDA Rule 10 compliance checks</td>
            </tr>
            <tr>
              <td><span class="engine-title">Clock Authority (§F4)</span></td>
              <td>Millisecond drift-free clock math; pause, resume, +1m/-1m adjustments with instant undo.</td>
              <td>Live running timer test suite</td>
            </tr>
            <tr>
              <td><span class="engine-title">Cash Game Settlement (§F5)</span></td>
              <td>Greedy minimal transaction debt resolution (O(N log N)) settling all cash debts with minimal transfers.</td>
              <td>Verified zero-sum chip-to-currency ledger</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

  </div>

  <!-- Lightbox Modal -->
  <div id="lightbox" onclick="closeLightbox()">
    <span id="lightbox-close">&times;</span>
    <img id="lightbox-img" src="" alt="Enlarged Board">
  </div>

  <script>
    function openLightbox(el) {{
      const lb = document.getElementById('lightbox');
      const img = document.getElementById('lightbox-img');
      img.src = el.src;
      lb.style.display = 'block';
      document.body.style.overflow = 'hidden';
    }}
    function closeLightbox() {{
      const lb = document.getElementById('lightbox');
      lb.style.display = 'none';
      document.body.style.overflow = 'auto';
    }}
    document.addEventListener('keydown', function(e) {{
      if (e.key === 'Escape') closeLightbox();
    }});
  </script>

</body>
</html>
"""

with open(OUTPUT_HTML, "w", encoding="utf-8") as f:
    f.write(html_content)

print(f"[SUCCESS] Generated single self-contained HTML file: {OUTPUT_HTML}")
print(f"File size: {os.path.getsize(OUTPUT_HTML) / (1024*1024):.2f} MB")
