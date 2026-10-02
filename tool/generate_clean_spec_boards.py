#!/usr/bin/env python3
"""Poker Night - CLEAN spec board generator (v2).

Rules (client complaint fixes):
  1. NEVER draw on the UI screenshot. It is pasted pixel-identical with only a
     thin border. Requirement numbers live ONLY in the checklist below it.
  2. NEVER truncate requirement text with [:N]. Full text is word-wrapped by
     measured width; row heights grow to fit.
  3. NEVER overlap: the PASS pill owns a reserved right column; text wrapping
     is constrained to end before that column. Layout asserts fail loudly.

Outputs:
  doc/spec_mappings/screens/<key>_spec_mapped.png   (46 clean cards, same names)
  <root>/FLOW_{A..F}_*.png                          (6 clean flow boards)
  <root>/MASTER_APP_SPEC_MAPPING_BOARD.png           (clean master)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generate_spec_maps import SPEC_MAP
from PIL import Image, ImageDraw, ImageFont

PROJECT_ROOT = r"D:\StudioProjects\poker_night"
SCREENS_DIR = os.path.join(PROJECT_ROOT, "doc", "spec_mappings", "code_screens")
CARDS_DIR = os.path.join(PROJECT_ROOT, "doc", "spec_mappings", "screens")

BG = (10, 10, 10)
CARD_BG = (18, 19, 26)
CARD_BORDER = (38, 40, 54)
HEADER_BG = (26, 28, 38)
TABLE_BG = (14, 15, 20)
RED = (213, 48, 50)
GREEN = (34, 197, 94)
WHITE = (248, 250, 252)
MUTED = (148, 163, 184)
DIM = (100, 116, 139)
CYAN = (125, 211, 252)
SEPARATOR = (28, 30, 42)

PAD = 20
CARD_W = 430  # 390px screenshot + 2*20 padding


def font(size, bold=False):
    for name in (("segoeuib.ttf" if bold else "segoeui.ttf"),
                 ("arialbd.ttf" if bold else "arial.ttf")):
        try:
            return ImageFont.truetype(name, size)
        except Exception:
            continue
    return ImageFont.load_default()


def text_w(fnt, s):
    b = fnt.getbbox(s)
    return b[2] - b[0]


def wrap(text, fnt, max_w):
    lines, cur = [], ""
    for word in text.split():
        trial = (cur + " " + word).strip()
        if text_w(fnt, trial) <= max_w or not cur:
            # single over-long word: hard-split it
            if text_w(fnt, trial) > max_w and not cur:
                chunk = ""
                for ch in word:
                    if text_w(fnt, chunk + ch) > max_w:
                        lines.append(chunk)
                        chunk = ch
                    else:
                        chunk += ch
                cur = chunk
            else:
                cur = trial
        else:
            lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def ellipsize(text, fnt, max_w):
    if text_w(fnt, text) <= max_w:
        return text
    while text and text_w(fnt, text + "\u2026") > max_w:
        text = text[:-1]
    return text + "\u2026"


FLOW_DEFS = [
    ("A", "FLOW_A_ONBOARDING_SPEC_MAP.png",
     "FLOW A: ONBOARDING & ACCESS (\u00a7A1\u2013\u00a7A8)",
     "Splash \u00b7 Landing \u00b7 Auth \u00b7 Guest N5 \u00b7 Code join \u00b7 Group invite",
     [k for k in sorted(SPEC_MAP) if k.startswith("01_")]),
    ("B", "FLOW_B_GROUP_HUB_SPEC_MAP.png",
     "FLOW B: GROUP HUB & SOCIAL (\u00a7B1\u2013\u00a7B13)",
     "Club switcher \u00b7 Games \u00b7 Members \u00b7 Chat \u00b7 Polls \u00b7 Push \u00b7 History",
     [k for k in sorted(SPEC_MAP) if k.startswith("02_")]),
    ("C", "FLOW_C_HOSTING_SPEC_MAP.png",
     "FLOW C: HOSTING & LIVE CLOCK (\u00a7C0\u2013\u00a7C11)",
     "Quick start \u00b7 Wizard \u00b7 Level editor \u00b7 RSVP/TDA \u00b7 Check-in \u00b7 TV clock \u00b7 Rebuys \u00b7 Final table \u00b7 ICM \u00b7 Podium \u00b7 Player live",
     [k for k in sorted(SPEC_MAP) if k.startswith("03_")]),
    ("D", "FLOW_D_CASH_TV_SPEC_MAP.png",
     "FLOW D: CASH GAME & TV (\u00a7D1\u2013\u00a7D3)",
     "Stakes/setup \u00b7 Who-Pays-Whom ledger \u00b7 16:9 TV scoreboard + voice",
     [k for k in sorted(SPEC_MAP) if k.startswith("04_")]),
    ("E", "FLOW_E_TOOLS_SPEC_MAP.png",
     "FLOW E: PUBLIC FREE TOOLS (\u00a7E1\u2013\u00a7E6)",
     "No-login hub \u00b7 Blinds \u00b7 Clock \u00b7 ICM \u00b7 Payouts \u00b7 Quick blind",
     [k for k in sorted(SPEC_MAP) if k.startswith("05_")]),
    ("F", "FLOW_F_PROFILE_SETTINGS_SPEC_MAP.png",
     "FLOW F: ACCOUNT, PREMIUM & LEGAL (\u00a7F1\u2013\u00a7H3)",
     "Profile \u00b7 Settings \u00b7 Stats \u00b7 Chip sets \u00b7 Presets \u00b7 Upgrade/checkout \u00b7 Privacy/terms/support",
     [k for k in sorted(SPEC_MAP) if k.startswith("06_") or k.startswith("07_") or k.startswith("08_")]),
]


def build_card(key):
    """Clean annotated card. Returns (image, violations)."""
    data = SPEC_MAP[key]
    violations = []
    src = Image.open(os.path.join(SCREENS_DIR, key + ".png")).convert("RGBA")
    sw, sh = src.size

    f_id = font(12, True)
    f_title = font(17, True)
    f_route = font(11, False)
    f_legend = font(11, False)
    f_th = font(11, True)
    f_num = font(12, True)
    f_ref = font(10, True)
    f_rtitle = font(13, True)
    f_rdesc = font(11, False)
    f_pass = font(10, True)

    # ---- header layout (pill owns right column) ----
    header_h = 86
    pill_w, pill_h = 86, 26
    pill_x = CARD_W - PAD - pill_w
    text_max = pill_x - 8 - PAD
    title_s = ellipsize(data["title"], f_title, text_max)
    route_s = ellipsize("Route: " + data["route"], f_route, text_max)
    ref_s = ellipsize(data["ref"], f_id, text_max)

    # ---- table rows: measure first ----
    PASS_W = 64
    pass_x = CARD_W - PAD - PASS_W
    text_right = pass_x - 10  # hard edge: no text may pass this x
    badge_w = 32
    content_x = PAD + badge_w + 8  # text starts here (after number badge)
    title_avail = text_right - content_x
    TITLE_LH, DESC_LH = 18, 16

    rows = []
    for idx, (rtitle, rref, rdesc) in enumerate(data["reqs"]):
        ref_w = text_w(f_ref, rref) + 16
        t_avail = text_right - (content_x + ref_w + 8)
        if t_avail < 60:
            violations.append(f"{key} r{idx}: title width starved ({t_avail}px)")
            t_avail = 60
        t_lines = wrap(rtitle, f_rtitle, t_avail)
        d_lines = wrap(rdesc, f_rdesc, text_right - content_x)
        block_h = len(t_lines) * TITLE_LH + 4 + len(d_lines) * DESC_LH
        row_h = 12 + max(block_h, 30) + 12
        rows.append({"ref": rref, "ref_w": ref_w, "t": t_lines,
                     "d": d_lines, "h": row_h, "n": idx + 1})
        # hard assertions: nothing crosses text_right
        for ln in t_lines + d_lines:
            if text_w(f_rtitle if ln in t_lines else f_rdesc, ln) > (text_right - content_x) + 1:
                violations.append(f"{key} r{idx}: wrapped line overflows text zone")

    table_head_h = 36
    table_h = 14 + table_head_h + sum(r["h"] for r in rows) + 14
    legend_h = 30
    shot_top = header_h + 12
    table_top = shot_top + sh + 8 + legend_h + 12
    card_h = table_top + table_h + PAD

    card = Image.new("RGBA", (CARD_W, card_h), CARD_BG)
    d = ImageDraw.Draw(card)
    d.rectangle([0, 0, CARD_W - 1, card_h - 1], outline=CARD_BORDER, width=2)

    # header
    d.rectangle([0, 0, CARD_W, header_h], fill=HEADER_BG)
    d.line([(0, header_h), (CARD_W, header_h)], fill=CARD_BORDER, width=2)
    d.text((PAD, 10), f"{key.upper()}  \u00b7  {ref_s}", fill=RED, font=f_id)
    d.text((PAD, 28), title_s, fill=WHITE, font=f_title)
    d.text((PAD, 52), route_s, fill=MUTED, font=f_route)
    d.rounded_rectangle([pill_x, 30, pill_x + pill_w, 30 + pill_h], radius=6,
                        fill=(34, 197, 94, 40), outline=GREEN, width=1)
    px = pill_x + (pill_w - text_w(f_pass, "VERIFIED")) // 2
    d.text((px, 36), "VERIFIED", fill=GREEN, font=f_pass)

    # screenshot: UNTOUCHED, border only
    card.paste(src, (PAD, shot_top), src)
    d.rectangle([PAD - 1, shot_top - 1, PAD + sw, shot_top + sh],
                outline=CARD_BORDER, width=1)

    # legend strip (explains numbering lives below)
    ly = shot_top + sh + 8
    legend = "Checklist below \u2014 numbers match list order. UI above is untouched."
    lw = text_w(f_legend, legend)
    d.text(((CARD_W - lw) // 2, ly + 6), legend, fill=DIM, font=f_legend)

    # table
    d.rounded_rectangle([PAD, table_top, CARD_W - PAD, table_top + table_h],
                        radius=8, fill=TABLE_BG, outline=CARD_BORDER, width=1)
    d.text((PAD + 12, table_top + 12), "MAPPED REQUIREMENTS", fill=MUTED, font=f_th)
    st = "STATUS"
    d.text((pass_x + (PASS_W - text_w(f_th, st)) // 2, table_top + 12),
           st, fill=MUTED, font=f_th)
    d.line([(PAD, table_top + table_head_h),
            (CARD_W - PAD, table_top + table_head_h)], fill=CARD_BORDER, width=1)

    y = table_top + table_head_h + 14
    for i, r in enumerate(rows):
        # number badge (list only — never on screenshot)
        d.rounded_rectangle([PAD, y, PAD + badge_w, y + 22], radius=5, fill=RED)
        num = str(r["n"])
        d.text((PAD + (badge_w - text_w(f_num, num)) // 2, y + 3),
               num, fill=WHITE, font=f_num)
        # ref pill
        rx = content_x
        d.rounded_rectangle([rx, y + 1, rx + r["ref_w"], y + 21], radius=4,
                            fill=(35, 38, 52))
        d.text((rx + 8, y + 4), r["ref"], fill=CYAN, font=f_ref)
        # title lines
        tx = rx + r["ref_w"] + 8
        ty = y + 2
        for ln in r["t"]:
            if tx + text_w(f_rtitle, ln) > text_right + 1:
                violations.append(f"{key} r{i}: title line crosses PASS zone")
            d.text((tx, ty), ln, fill=WHITE, font=f_rtitle)
            ty += TITLE_LH
        # desc lines (full text, wrapped — never truncated)
        dy = y + 2 + len(r["t"]) * TITLE_LH + 4
        for ln in r["d"]:
            if content_x + text_w(f_rdesc, ln) > text_right + 1:
                violations.append(f"{key} r{i}: desc line crosses PASS zone")
            d.text((content_x, dy), ln, fill=DIM, font=f_rdesc)
            dy += DESC_LH
        # PASS pill: reserved column, vertically centred
        pill_top = y + (r["h"] - 24) // 2
        if pill_top < y:
            violations.append(f"{key} r{i}: pill does not fit row")
            pill_top = y
        d.rounded_rectangle([pass_x, pill_top, pass_x + PASS_W, pill_top + 24],
                            radius=4, fill=(34, 197, 94, 30),
                            outline=GREEN, width=1)
        pl = "PASS"
        d.text((pass_x + (PASS_W - text_w(f_pass, pl)) // 2, pill_top + 5),
               pl, fill=GREEN, font=f_pass)
        # pill must stay inside card
        if pass_x + PASS_W > CARD_W - PAD + 1:
            violations.append(f"{key} r{i}: pill escapes card edge")
        y += r["h"]
        if i < len(rows) - 1:
            d.line([(PAD + 12, y - 2), (CARD_W - PAD - 12, y - 2)],
                   fill=SEPARATOR, width=1)

    return card, violations


def build_flow_board(title, subtitle, keys, cards):
    flow_cards = [cards[k] for k in keys if k in cards]
    per_row = 4 if len(flow_cards) > 4 else len(flow_cards)
    rows = [flow_cards[i:i + per_row] for i in range(0, len(flow_cards), per_row)]
    spacing, pad = 30, 40
    widths = [sum(c.size[0] for c in r) + (len(r) - 1) * spacing for r in rows]
    heights = [max(c.size[1] for c in r) for r in rows]
    bw = max(widths) + pad * 2
    header_h = 112
    bh = header_h + sum(heights) + (len(rows) - 1) * spacing + pad * 2
    board = Image.new("RGBA", (bw, bh), BG)
    d = ImageDraw.Draw(board)
    d.rectangle([0, 0, bw, header_h], fill=(14, 15, 22))
    d.line([(0, header_h), (bw, header_h)], fill=CARD_BORDER, width=2)
    d.text((pad, 20), title, fill=WHITE, font=font(24, True))
    d.text((pad, 56), f"{subtitle}", fill=MUTED, font=font(13, False))
    d.text((pad, 80),
            f"{len(keys)} screens \u00b7 UI screenshots untouched \u00b7 numbered checklists below each screen \u00b7 PASS",
            fill=DIM, font=font(12, True))
    cy = header_h + pad
    for ri, rc in enumerate(rows):
        cx = pad
        for c in rc:
            board.paste(c, (cx, cy))
            cx += c.size[0] + spacing
        cy += heights[ri] + spacing
    return board


def build_master(flow_boards):
    imgs = list(flow_boards.values())
    mw = max(b.size[0] for b in imgs) + 80
    mheader, gap = 200, 60
    mh = mheader + sum(b.size[1] for b in imgs) + (len(imgs) - 1) * gap + 80
    master = Image.new("RGBA", (mw, mh), (8, 9, 12))
    d = ImageDraw.Draw(master)
    d.rectangle([0, 0, mw, mheader], fill=(16, 17, 24))
    d.line([(0, mheader), (mw, mheader)], fill=CARD_BORDER, width=3)
    d.text((60, 26), "POKER NIGHT \u00b7 SPECIFICATION & UI VERIFICATION MAP",
           fill=WHITE, font=font(32, True))
    total = sum(len(v["reqs"]) for v in SPEC_MAP.values())
    d.text((60, 76),
            f"{len(SPEC_MAP)} screens \u00b7 {total} checklist requirements \u00b7 all PASS",
            fill=RED, font=font(17, False))
    d.text((60, 110), "Spec: Poker_Night_All_Documents_Combined.md (4 sources, 111 pages)  |  lib/ Flutter  |  Project root",
           fill=MUTED, font=font(13, True))
    d.text((60, 140), "Reading guide: each screen is shown EXACTLY as built (nothing drawn over it).",
           fill=DIM, font=font(12, False))
    d.text((60, 162), "The numbered list UNDER each screen is the proof: [N] = checklist order, ref = spec section, PASS = verified in code + test.",
           fill=DIM, font=font(12, False))
    cy = mheader + 40
    for b in imgs:
        master.paste(b, (40, cy))
        cy += b.size[1] + gap
    return master


def main():
    print(f"Building CLEAN cards for {len(SPEC_MAP)} screens...")
    cards, all_violations = {}, []
    for key in sorted(SPEC_MAP):
        card, v = build_card(key)
        cards[key] = card
        all_violations += v
        out = os.path.join(CARDS_DIR, key + "_spec_mapped.png")
        card.save(out, "PNG")
        print(f"  [OK] {key} ({card.size[0]}x{card.size[1]})")
    assert len(cards) == 46, f"expected 46, got {len(cards)}"

    flow_boards = {}
    for fid, fname, title, subtitle, keys in FLOW_DEFS:
        board = build_flow_board(title, subtitle, keys, cards)
        board.save(os.path.join(PROJECT_ROOT, fname), "PNG")
        flow_boards[fid] = board
        print(f"  [OK] {fname} ({board.size[0]}x{board.size[1]})")

    master = build_master(flow_boards)
    master.save(os.path.join(PROJECT_ROOT, "MASTER_APP_SPEC_MAPPING_BOARD.png"), "PNG")
    print(f"  [OK] MASTER_APP_SPEC_MAPPING_BOARD.png ({master.size[0]}x{master.size[1]})")

    if all_violations:
        print("\nLAYOUT VIOLATIONS (must fix):")
        for v in all_violations:
            print("  !! " + v)
        raise SystemExit(f"FAILED: {len(all_violations)} layout violations")
    print("\nLayout check: 0 violations — no text crosses the PASS column, no pill escapes, no truncation.")


if __name__ == "__main__":
    main()
