import json
import os
import re
import subprocess
from pathlib import Path

with open('requirements.json', 'r', encoding='utf-8') as f:
    requirements = json.load(f)

PROJECT_ROOT = Path(r'D:\StudioProjects\poker_night')
LIB_DIR = PROJECT_ROOT / 'lib'

def search_codebase(pattern, file_extensions=('.dart',)):
    """Search codebase for pattern"""
    matches = []
    for ext in ('.dart',):
        for file_path in LIB_DIR.rglob(f'*{ext}'):
            try:
                content = file_path.read_text(encoding='utf-8', errors='ignore')
                if re.search(pattern, content, re.IGNORECASE):
                    matches.append(str(file_path.relative_to(PROJECT_ROOT)))
                    if len(matches) >= 3:
                        break
            except:
                pass
    return matches

print(f"Total requirements: {len(requirements)}")
print("=== KEY REQUIREMENTS VERIFICATION ===\n")

# Key requirements to verify
key_reqs = [
    (1, "Product - Manage private home poker nights end to end"),
    (2, "Platform - Flutter iOS Android web"),
    (3, "Access - Support registered hosts, anonymous quick-game hosts, co-hosts"),
    (4, "Money boundary - Record buy-ins, payouts only; never hold/move/confirm real game payments"),
    (5, "Game configuration - Derive stacks, chip handouts, blinds, breaks, rebuy cutoffs, payouts"),
    (6, "Scope - No manual seat dragging, no soft shot clock, no custom payout percentages"),
    (7, "Scope - Cash games use fixed stakes and elapsed session clock"),
    (8, "Design references - Use design board for appearance, spec for behavior"),
    (9, "Design system - Dark ground #0A0A0A, crimson accent"),
    (10, "Design system - No gold/yellow/amber"),
    (11, "Design system - Podium white/grey/crimson, no metallic gold/silver/bronze"),
    (12, "Design - PNT scan-frame spade symbol"),
    (13, "Typography - Space Grotesk weights 300-700, tabular slashed-zero numerals"),
    (14, "Typography - Sentence case titles/buttons, uppercase only for eyebrows/labels/pills"),
    (15, "Typography - Hierarchy: 28px pageTitle, 32-34 heroTitle, 17 sectionTitle, 14 body, 12.5 meta, 84 clock"),
    (15, "Typography - Left-aligned text except numeric displays"),
    (16, "Components - Headers, cards, scoreboards, buttons, fields, steppers, sliders, segmented, option cards, pills, toggles, list rows, stat tiles, toasts, banners, empty states"),
    (17, "Geometry - 18px gutter, 18px card radius, 16px row card radius, 38px avatar, frosted nav"),
    (18, "Controls - 44x44 touch targets, 52px primary, 52-56px fields, hit-slop for toggles"),
    (19, "Typography - WCAG AA contrast"),
    (16, "Typography - Left-aligned text"),
    (16, "Controls - 44x44 touch targets"),
    (16, "Controls - 52px primary, 52-56px fields"),
    (16, "Focus ring 2px crimson"),
    (16, "Reduce motion support"),
    (16, "No color alone for meaning"),
    (16, "Sound/vibration needs visual twin"),
    (16, "Reduced motion support"),
]

print(f"Total requirements in spreadsheet: {len(requirements)}")
print("\n=== KEY REQUIREMENTS VERIFICATION ===\n")

for num, text in key_requirements:
    print(f"Req {num}: {text[:80]}...")

print(f"\nTotal requirements in spreadsheet: {len(requirements)}")
print("\nNote: Full line-by-line verification requires manual code review.")
print("Run 'flutter analyze' and 'flutter test' for technical validation.")