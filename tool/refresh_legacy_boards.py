#!/usr/bin/env python3
"""Refresh legacy doc/spec_mappings boards from the exact mobile captures.

Overwrites (same filenames):
  doc/spec_mappings/screens/<key>_spec_mapped.png   (46 clean cards)
  doc/spec_mappings/flows/FLOW_<A..F>_SPEC_MAP.png   (6 legacy flow boards)
  doc/spec_mappings/MASTER_APP_SPEC_MAPPING_BOARD.png
Source: spec_boards/mobile/captures/*.png (780x1688 exact widget shots).
Run: python tool/refresh_legacy_boards.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_clean_spec_boards as base
from generate_spec_maps import SPEC_MAP
from PIL import Image, ImageDraw

import glob
import shutil
import tempfile

PROJECT_ROOT = r"D:\StudioProjects\poker_night"
LEGACY = os.path.join(PROJECT_ROOT, "doc", "spec_mappings")
# The clean card builder pastes screenshots at natural size (390px design);
# scale the 780px captures down into a temp dir first.
_TMP = tempfile.mkdtemp(prefix="legacy_shots_")
for _src in glob.glob(os.path.join(
        PROJECT_ROOT, "spec_boards", "mobile", "captures", "*.png")):
    _im = Image.open(_src).convert("RGBA")
    _w = 390
    _im = _im.resize((_w, round(_im.size[1] * _w / _im.size[0])),
                     Image.LANCZOS)
    _im.save(os.path.join(_TMP, os.path.basename(_src)), "PNG")
base.SCREENS_DIR = _TMP

LEGACY_FLOWS = [
    ("A", "FLOW_A_SPEC_MAP.png"),
    ("B", "FLOW_B_SPEC_MAP.png"),
    ("C", "FLOW_C_SPEC_MAP.png"),
    ("D", "FLOW_D_SPEC_MAP.png"),
    ("E", "FLOW_E_SPEC_MAP.png"),
    ("F", "FLOW_F_SPEC_MAP.png"),
]


def main():
    print("Refreshing legacy boards from exact mobile captures...")
    cards, violations = {}, []
    for key in sorted(SPEC_MAP):
        card, v = base.build_card(key)
        cards[key] = card
        violations += v
        card.save(
            os.path.join(LEGACY, "screens", key + "_spec_mapped.png"), "PNG")
    assert len(cards) == 46, len(cards)
    print(f"  cards: {len(cards)}/46")

    flow_ids = {
        "A": [k for k in sorted(SPEC_MAP) if k.startswith("01_")],
        "B": [k for k in sorted(SPEC_MAP) if k.startswith("02_")],
        "C": [k for k in sorted(SPEC_MAP) if k.startswith("03_")],
        "D": [k for k in sorted(SPEC_MAP) if k.startswith("04_")],
        "E": [k for k in sorted(SPEC_MAP) if k.startswith("05_")],
        "F": [k for k in sorted(SPEC_MAP)
              if k.startswith("06_") or k.startswith("07_")
              or k.startswith("08_")],
    }
    titles = {f: t for f, _, t, _, _ in base.FLOW_DEFS}
    subs = {f: s for f, _, _, s, _ in base.FLOW_DEFS}
    boards = {}
    for fid, fname in LEGACY_FLOWS:
        b = base.build_flow_board(
            titles[fid], subs[fid], flow_ids[fid], cards)
        b.save(os.path.join(LEGACY, "flows", fname), "PNG")
        boards[fid] = b
        print(f"  [OK] flows/{fname} ({b.size[0]}x{b.size[1]})")
    master = base.build_master(boards)
    master.save(
        os.path.join(LEGACY, "MASTER_APP_SPEC_MAPPING_BOARD.png"), "PNG")
    print(f"  [OK] MASTER_APP_SPEC_MAPPING_BOARD.png "
          f"({master.size[0]}x{master.size[1]})")
    if violations:
        for v in violations:
            print("  !! " + v)
        raise SystemExit(f"FAILED: {len(violations)} violations")
    shutil.rmtree(_TMP, ignore_errors=True)
    print("Layout check: 0 violations.")


if __name__ == "__main__":
    main()
