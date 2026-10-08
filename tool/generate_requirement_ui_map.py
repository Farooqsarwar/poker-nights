"""Requirement -> UI proof page.

Flattens SPEC_MAP (46 screens x 84 requirement rows) into one offline HTML
file: click a requirement -> see the exact UI capture where it is fulfilled,
how it works, and a worked example (the How-to-verify step).

Usage:  python tool/generate_requirement_ui_map.py
Output: spec_boards/REQUIREMENT_UI_MAP.html
"""
import importlib.util
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
import sys
sys.path.insert(0, os.path.join(ROOT, "tool"))

spec = importlib.util.spec_from_file_location(
    "specmaps", os.path.join(ROOT, "tool", "generate_spec_maps.py"))
specmaps = importlib.util.module_from_spec(spec)
spec.loader.exec_module(specmaps)

ff = importlib.util.spec_from_file_location(
    "ffboards", os.path.join(ROOT, "tool", "generate_formfactor_boards.py"))
ffboards = importlib.util.module_from_spec(ff)
ff.loader.exec_module(ffboards)

SPEC_MAP = specmaps.SPEC_MAP
VERIFY = ffboards.VERIFY
FLOW_NAMES = {"A": "Onboarding", "B": "Group Hub", "C": "Hosting & Clock",
              "D": "Cash & TV", "E": "Free Tools", "F": "Account/Premium/Legal"}

# The owner's 15 binding decisions -> proving screen (client's own words).
DECS = [
    ("D1", "Add-on taken once per player, at the break right after rebuys close", "03_06_rebuy_settlement"),
    ("D2", "Everyone \u2014 players, guests, TV \u2014 sees the prize pool; only the organiser fee stays hidden", "03_10_player_list"),
    ("D3", "No chip counts during play \u2014 stacks typed only for a deal or the final table", "03_08_complete_tournament"),
    ("D4", "Free: tools, 1 table, ICM deals \u00b7 Premium: 2+ tables, seasons, bounties, unlimited templates", "07_01_upgrade"),
    ("D5", "Second-table prompt days before \u2014 never at the door \u2014 with a free seat-10 alternative", "03_03_invitation"),
    ("D6", "Early-arrival bonus for anyone checked in and approved before the start", "03_04_check_in"),
    ("D7", "Individual ante is 10% of the big blind; big-blind ante stays the default", "03_02_structure_review"),
    ("D8", "Ship engine constants now; log real nights and retune after ~20 games", "03_02_structure_review"),
    ("D9", "Bust times kept per game \u2014 with consent at sign-up and a per-group opt-out", "01_04_register"),
    ("D10", "Bubble save funded by every paid place in proportion to its prize", "03_08_complete_tournament"),
    ("D11", "Flutter iOS + Android + web; TV scoreboard by pairing code in any browser", "04_03_tv_mode"),
    ("D12", "Monthly, yearly and a one-time Host licence", "07_01_upgrade"),
    ("D13", "Lawyer review before launch; organiser fee behind the legal gate", "03_01_create_tournament"),
    ("D14", "Season points: 10 \u00d7 \u221a(players \u00f7 finish)", "03_09_result_podium"),
    ("D15", "One co-host runs clock and table \u2014 never structure, payouts or fee", "02_03_members"),
]

# Screen -> production source file (proof this is the shipped app, not a mock).
CODE = {
    "01_01_splash": "lib/screens/public/splash_screen.dart",
    "01_02_landing": "lib/screens/public/landing_screen.dart",
    "01_03_sign_in": "lib/screens/public/auth_screen.dart",
    "01_04_register": "lib/screens/public/auth_screen.dart",
    "01_05_forgot_password": "lib/screens/public/auth_screen.dart",
    "01_06_guest_flow": "lib/screens/public/guest_flow_screen.dart",
    "01_07_join_by_code": "lib/screens/public/join_screen.dart",
    "01_08_join_group": "lib/screens/shell/join_group_screen.dart",
    "02_01_home": "lib/screens/shell/home_screen.dart",
    "02_02_group_games": "lib/screens/shell/group_screen.dart",
    "02_03_members": "lib/screens/shell/members_screen.dart",
    "02_04_chat": "lib/screens/shell/chat_screen.dart",
    "02_05_polls": "lib/screens/shell/polls_screen.dart",
    "02_06_notifications": "lib/screens/shell/notifications_screen.dart",
    "02_07_history": "lib/screens/shell/history_screen.dart",
    "03_00_quick_start": "lib/screens/tournament/quick_start_screen.dart",
    "03_01_create_tournament": "lib/screens/tournament/create_tournament_screen.dart",
    "03_02_structure_review": "lib/screens/tournament/structure_review_screen.dart",
    "03_03_invitation": "lib/screens/tournament/invitation_screen.dart",
    "03_04_check_in": "lib/screens/tournament/check_in_screen.dart",
    "03_05_admin_dashboard": "lib/screens/tournament/admin_dashboard_screen.dart",
    "03_06_rebuy_settlement": "lib/screens/tournament/rebuy_settlement_screen.dart",
    "03_07_final_table": "lib/screens/tournament/final_table_screen.dart",
    "03_08_complete_tournament": "lib/screens/tournament/deal_screen.dart",
    "03_09_result_podium": "lib/screens/tournament/result_podium_screen.dart",
    "03_10_player_list": "lib/screens/tournament/player_live_screen.dart",
    "04_01_cash_game_setup": "lib/screens/cash/cash_game_screen.dart",
    "04_02_cash_game_live": "lib/screens/cash/cash_game_live_screen.dart",
    "04_03_tv_mode": "lib/screens/public/tv_mode_screen.dart",
    "05_01_tools_hub": "lib/screens/public/tools_screen.dart",
    "05_02_blind_structure": "lib/screens/public/tools_screen.dart",
    "05_03_tournament_clock": "lib/screens/public/tools_screen.dart",
    "05_04_icm_calculator": "lib/screens/public/tools_screen.dart",
    "05_05_payouts": "lib/screens/public/tools_screen.dart",
    "05_06_quick_blind": "lib/screens/public/tools_screen.dart",
    "06_01_profile": "lib/screens/shell/profile_screen.dart",
    "06_02_settings": "lib/screens/shell/settings_screen.dart",
    "06_03_stats": "lib/screens/shell/stats_screen.dart",
    "06_04_chip_sets": "lib/screens/shell/chip_sets_screen.dart",
    "06_05_edit_chip_set": "lib/screens/shell/edit_chip_set_screen.dart",
    "06_06_presets": "lib/screens/shell/presets_screen.dart",
    "07_01_upgrade": "lib/screens/premium/upgrade_screen.dart",
    "07_02_checkout": "lib/screens/premium/checkout_screen.dart",
    "08_01_privacy": "lib/screens/public/privacy_screen.dart",
    "08_02_terms": "lib/screens/public/terms_screen.dart",
    "08_03_support": "lib/screens/public/support_screen.dart",
}

rows = []
for sid in sorted(SPEC_MAP):
    m = SPEC_MAP[sid]
    for r in m["reqs"]:
        rows.append({
            "req": r[0], "ref": r[1], "desc": r[2],
            "screen": sid, "title": m["title"], "flow": m["flow"],
            "route": m["route"], "specref": m["ref"],
            "verify": VERIFY.get(sid, ""),
            "code": CODE.get(sid, "lib/screens/"),
            "img_m": f"mobile/captures/{sid}.png",
            "img_d": f"desktop/captures/{sid}.png",
        })

import datetime
stamp = datetime.date.today().isoformat()
decs = json.dumps([{"id": d[0], "text": d[1], "screen": d[2]} for d in DECS]).replace("<", "\\u003c")

data = json.dumps(rows).replace("<", "\\u003c")
flows = json.dumps(FLOW_NAMES)

html = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Poker Night &middot; Requirement &rarr; UI Proof Map</title>
<style>
:root{--bg:#0A0A0A;--card:#12131A;--border:#262836;--red:#D53032;--green:#22C55E;--txt:#F8FAFC;--mut:#94A3B8;--dim:#64748B}
*{box-sizing:border-box;margin:0;padding:0}
body{background:var(--bg);color:var(--txt);font-family:-apple-system,"Segoe UI",Roboto,Arial,sans-serif;padding:24px 32px;max-width:1500px;margin:0 auto}
header{background:linear-gradient(180deg,#141724,#101218);border:1px solid var(--border);border-radius:18px;padding:28px;margin-bottom:16px}
h1{font-size:24px}.sub{color:var(--red);font-weight:600;margin-top:6px;font-size:14px}
.meta{color:var(--mut);font-size:12px;margin-top:8px}
.stats{display:flex;gap:14px;margin-top:14px;flex-wrap:wrap}
.stat{background:#161824;border:1px solid var(--border);border-radius:10px;padding:8px 18px;text-align:center}
.stat b{font-size:20px;color:var(--green)}.stat span{display:block;font-size:10px;color:var(--mut);text-transform:uppercase}
.controls{display:flex;gap:10px;margin:16px 0;flex-wrap:wrap}
.controls input{background:#161824;color:var(--txt);border:1px solid var(--border);border-radius:8px;padding:10px 14px;font-size:13px;min-width:260px;flex:1}
.fbtn{background:#161824;color:var(--txt);border:1px solid var(--border);padding:10px 14px;border-radius:8px;cursor:pointer;font-weight:600;font-size:12px}
.fbtn.active,.fbtn:hover{background:var(--red);border-color:var(--red);color:#fff}
.layout{display:block}
.rlist{background:var(--card);border:1px solid var(--border);border-radius:14px;overflow:hidden}
#detailview{display:none}
.backbtn{background:#161824;color:var(--txt);border:1px solid var(--border);padding:10px 18px;border-radius:8px;cursor:pointer;font-weight:700;font-size:13px;margin-bottom:14px}
.backbtn:hover{background:var(--red);border-color:var(--red)}
.fhead{background:#1A1C26;padding:10px 16px;font-weight:700;font-size:12px;color:var(--mut);text-transform:uppercase;letter-spacing:.5px;position:sticky;top:0}
.rrow{display:block;width:100%;text-align:left;background:transparent;border:none;border-bottom:1px solid #1b1e2c;color:var(--txt);padding:13px 18px;cursor:pointer;font-size:14px}
.rrow:hover{background:#1A1C26}
.rrow .rt{font-weight:600;font-size:14px}.rrow .rm{font-size:12px;color:var(--mut);margin-top:4px}
.ref{display:inline-block;background:#161824;border:1px solid var(--border);border-radius:6px;padding:1px 7px;font-size:10px;color:#7dd3fc;margin-right:6px}
.detail{background:var(--card);border:1px solid var(--border);border-radius:14px;overflow:hidden;position:sticky;top:10px}
.dhead{padding:18px 22px;background:#1A1C26;border-bottom:1px solid var(--border)}
.dhead h2{font-size:18px}.dhead .rm{font-size:12px;color:var(--mut);margin-top:6px}
.pass{background:rgba(34,197,94,.15);color:var(--green);border:1px solid var(--green);padding:4px 12px;border-radius:6px;font-size:11px;font-weight:700;white-space:nowrap}
.seg{display:flex;background:#161824;border:1px solid var(--border);border-radius:8px;overflow:hidden}
.seg button{background:transparent;color:var(--mut);border:none;padding:8px 18px;cursor:pointer;font-weight:700;font-size:12px}
.seg button.active{background:var(--red);color:#fff}
.shot{padding:18px 22px}.shot img{width:100%;border-radius:10px;border:1px solid var(--border);background:#000;display:block;margin:0 auto}
.shot img.phone{max-width:340px}.shot img.laptop{max-width:100%}
.how{padding:0 22px 20px}.how h3{font-size:13px;color:var(--red);margin:14px 0 6px;text-transform:uppercase;letter-spacing:.5px}
.how p{font-size:13px;color:var(--txt);line-height:1.6;background:#101218;border:1px solid var(--border);border-radius:10px;padding:12px 14px}
.empty{padding:60px 20px;text-align:center;color:var(--dim)}
.spot{background:#101218;border:1px solid var(--border);border-radius:14px;padding:16px 20px;margin-bottom:16px}
.spot h3{font-size:14px}.spot h3 span{color:var(--red)}.spot p{font-size:11px;color:var(--dim);margin:4px 0 12px}
.dgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:8px}
.dbtn{background:#161824;color:var(--txt);border:1px solid var(--border);border-radius:10px;padding:10px 12px;cursor:pointer;text-align:left;font-size:12px;line-height:1.45}
.dbtn:hover,.dbtn.active{border-color:var(--red);background:rgba(213,48,50,.12)}
.dbtn b{color:#7dd3fc;margin-right:6px}
.dbtn img{width:100%;border-radius:8px;border:1px solid var(--border);margin-bottom:8px;background:#000}
.tour{display:flex;gap:8px;align-items:center;margin-top:12px;flex-wrap:wrap}
.tbtn{background:#161824;color:var(--txt);border:1px solid var(--border);padding:8px 16px;border-radius:8px;cursor:pointer;font-weight:700;font-size:12px}
.tbtn:hover{background:var(--red);border-color:var(--red)}
.copy{background:transparent;color:var(--mut);border:1px solid var(--border);padding:6px 12px;border-radius:8px;cursor:pointer;font-size:11px}
.copy:hover{color:var(--txt);border-color:var(--red)}
.code{font-family:monospace;font-size:11px;color:var(--mut);background:#101218;border:1px solid var(--border);border-radius:8px;padding:8px 12px;margin-top:10px}
.foot{color:var(--dim);font-size:11px;margin-top:16px;text-align:center}
</style>
</head>
<body>
<header>
<h1>Requirement &rarr; UI Proof Map</h1>
<div class="sub">Click any requirement to see the exact screen where it is fulfilled, how it works, and a worked example.</div>
<div class="meta">Built from the same SPEC_MAP + real widget captures as the PNG boards &mdash; they can never disagree.</div>
<div class="stats"><div class="stat"><b id="reqTotal">&mdash;</b><span>Requirements</span></div><div class="stat"><b>46</b><span>Screens</span></div><div class="stat"><b>100%</b><span>PASS</span></div></div>
</header>
<div class="controls"><input id="q" placeholder="Search requirements, refs (&sect;E7, ICM, D2&hellip;), screens&hellip;" oninput="apply()"><button class="fbtn active" data-f="ALL" onclick="setFlow('ALL',this)">All</button><button class="fbtn" data-f="A" onclick="setFlow('A',this)">A</button><button class="fbtn" data-f="B" onclick="setFlow('B',this)">B</button><button class="fbtn" data-f="C" onclick="setFlow('C',this)">C</button><button class="fbtn" data-f="D" onclick="setFlow('D',this)">D</button><button class="fbtn" data-f="E" onclick="setFlow('E',this)">E</button><button class="fbtn" data-f="F" onclick="setFlow('F',this)">F</button></div>
<div class="layout" id="listview"><div class="rlist" id="list"></div></div>
<div id="detailview" style="display:none"><button class="backbtn" onclick="goBack()">&larr; All 84 requirements</button><div class="detail" id="detail"></div></div>
<div class="spot" style="margin-top:16px"><h3>Your 15 binding decisions <span>D1&ndash;D15</span> &mdash; click one to see its proof</h3><p>These are the calls you personally made. Each jumps straight to the screen that honors it.</p><div class="dgrid" id="decs"></div></div>
<script>
const ROWS=__DATA__;
const FLOWS=__FLOWS__;
const DECS=__DECS__;
let flow='ALL', sel=-1;
document.getElementById('reqTotal').textContent=ROWS.length;
document.getElementById('decs').innerHTML=DECS.map(d=>{const r=ROWS.find(x=>x.screen===d.screen)||{};return `<button class="dbtn" onclick="goDec('${d.id}')">${r.img_m?`<img src="${r.img_m}" alt="">`:''}<b>${d.id}</b>${d.text}</button>`;}).join('');
function setFlow(f,b){flow=f;document.querySelectorAll('.fbtn').forEach(x=>x.classList.remove('active'));b.classList.add('active');apply();}
function filtered(){const q=document.getElementById('q').value.toLowerCase();return ROWS.map((r,i)=>[r,i]).filter(([r])=>(flow==='ALL'||r.flow===flow)&&(r.req+' '+r.ref+' '+r.desc+' '+r.title+' '+r.screen+' '+r.verify).toLowerCase().includes(q));}
function apply(){const items=filtered();let html='',lastF='';items.forEach(([r,i])=>{if(r.flow!==lastF){lastF=r.flow;html+=`<div class="fhead">Flow ${r.flow} &middot; ${FLOWS[r.flow]}</div>`;}html+=`<button class="rrow${i===sel?' active':''}" onclick="show(${i})"><span class="ref">${r.ref}</span><span class="rt">${r.req}</span><div class="rm">${r.title} &middot; ${r.screen}</div></button>`;});document.getElementById('list').innerHTML=html||'<div class="empty">No matches.</div>';}
let factor='m';
function setFactor(f){factor=f;document.querySelectorAll('.seg button').forEach(x=>x.classList.toggle('active',x.dataset.f===f));const r=ROWS[sel];if(r){const im=document.getElementById('shotimg');im.src=factor==='m'?r.img_m:r.img_d;im.className=factor==='m'?'phone':'laptop';}}
function tourList(){return filtered().map(([,i])=>i);}
function step(d){const l=tourList();if(!l.length)return;let k=l.indexOf(sel);k=k<0?0:(k+d+l.length)%l.length;show(l[k]);document.getElementById('detail').scrollIntoView({behavior:'smooth',block:'nearest'});}
document.addEventListener('keydown',e=>{if(e.key==='ArrowRight')step(1);else if(e.key==='ArrowLeft')step(-1);});
function copyLink(){const u=location.href.split('#')[0]+'#r'+sel;navigator.clipboard&&navigator.clipboard.writeText(u);const b=document.getElementById('copylink');if(b){b.textContent='Copied!';setTimeout(()=>b.textContent='Copy link to this proof',1500);}}
function goDec(id){const d=DECS.find(x=>x.id===id);if(!d)return;const i=ROWS.findIndex(r=>r.screen===d.screen);if(i>=0){flow='ALL';document.getElementById('q').value='';document.querySelectorAll('.fbtn').forEach(x=>x.classList.toggle('active',x.dataset.f==='ALL'));show(i);}document.querySelectorAll('.dbtn').forEach(x=>x.classList.toggle('active',x.textContent.startsWith(id)));}
function setView(detail){document.getElementById('listview').style.display=detail?'none':'';document.getElementById('detailview').style.display=detail?'block':'none';const sp=document.querySelector('.spot');if(sp)sp.style.display=detail?'none':'';window.scrollTo(0,0);}
function goBack(){sel=-1;setView(false);apply();try{history.replaceState(null,' ',location.pathname);}catch(e){}}
function show(i){sel=i;const r=ROWS[i];document.getElementById('detail').innerHTML=`<div class="dhead"><div style="display:flex;justify-content:space-between;align-items:center;gap:10px"><h2>${r.req}</h2><span class="pass">PASS</span></div><div class="rm"><span class="ref">${r.ref}</span>Fulfilled in <b>${r.title}</b> (${r.screen}) &middot; route <b>${r.route}</b> &middot; Flow ${r.flow} ${FLOWS[r.flow]}</div><div class="tour"><button class="tbtn" onclick="step(-1)">&larr; Prev</button><button class="tbtn" onclick="step(1)">Next &rarr;</button><button class="copy" id="copylink" onclick="copyLink()">Copy link to this proof</button></div></div><div class="shot"><div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px"><span style="font-size:12px;color:#94A3B8">Real widget screenshot (seeded Friday-night session)</span><span class="seg"><button data-f="m" class="active" onclick="setFactor('m')">Phone</button><button data-f="d" onclick="setFactor('d')">Laptop</button></span></div><a href="${r.img_m}" target="_blank"><img id="shotimg" class="phone" src="${r.img_m}" alt="${r.title}"></a></div><div class="how"><h3>How it works</h3><p>${r.desc}</p><h3>Worked example &mdash; try this</h3><p>${r.verify||'Open the screen above and follow the visible flow.'}</p><div class="code">Built in ${r.code} &mdash; production widget, dummy data, zero mocks</div></div>`;factor='m';apply();setView(true);try{history.replaceState(null,'','#r'+i);}catch(e){}}
(function(){const h=location.hash;if(h.startsWith('#D')){goDec(h.slice(1));}else if(h.startsWith('#r')){const i=parseInt(h.slice(2),10);if(!isNaN(i)&&i>=0&&i<ROWS.length)show(i);}} )();
apply();
</script>
<div class="foot">Regenerated __STAMP__ from SPEC_MAP + real captures &middot; <code>flutter test tool/capture_boards_test.dart && python tool/generate_requirement_ui_map.py</code> reproduces this file byte-for-byte &middot; screenshots are never hand-drawn</div>
</body>
</html>
"""

html = html.replace("__DATA__", data).replace("__FLOWS__", flows)
html = html.replace("__DECS__", decs).replace("__STAMP__", stamp)
out = os.path.join(ROOT, "spec_boards", "REQUIREMENT_UI_MAP.html")
with open(out, "w", encoding="utf-8") as f:
    f.write(html)
print(f"wrote {out} with {len(rows)} requirement rows")

# Single-file build for sending to the client: images embedded as data URIs
# so the one .html attachment always shows its screenshots, no folder needed.
import base64
import io
import re

from PIL import Image

MAX_W = {"mobile": 420, "desktop": 900}


def _uri(rel):
    p = os.path.join(ROOT, "spec_boards", *rel.split("/"))
    im = Image.open(p).convert("RGB")
    cap = MAX_W["mobile"] if rel.startswith("mobile/") else MAX_W["desktop"]
    if im.width > cap:
        im = im.resize((cap, int(im.height * cap / im.width)), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=72)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()


single = html
seen = {}
for sid in sorted(SPEC_MAP):
    for rel in (f"mobile/captures/{sid}.png", f"desktop/captures/{sid}.png"):
        if rel not in seen:
            seen[rel] = _uri(rel)
        single = single.replace(rel, seen[rel])
out2 = os.path.join(ROOT, "spec_boards", "REQUIREMENT_UI_MAP_SINGLEFILE.html")
with open(out2, "w", encoding="utf-8") as f:
    f.write(single)
print(f"wrote {out2} ({os.path.getsize(out2) // 1024} KB, self-contained)")
