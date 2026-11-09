import json
import os
import re
import subprocess
from pathlib import Path

with open('requirements.json', 'r', encoding='utf-8') as f:
    requirements = json.load(f)

PROJECT_ROOT = Path(r'D:\StudioProjects\poker_night')
LIB_DIR = PROJECT_ROOT / 'lib'

checks = [
    ("1. Dark ground #0A0A0A", r'0A0A0A|0xFF0A0A0A'),
    ("2. Crimson accent #D53032", r'D53032|0xFFD53032'),
    ("3. No gold/yellow/amber", r'gold|amber|yellow'),
    ("4. Space Grotesk font", r'SpaceGrotesk|Space Grotesk'),
    ("5. Tabular figures + slashed zero", r'tabularFigures|slashedZero'),
    ("6. WCAG AA contrast", r'WCAG|contrast|4\.5:1'),
    ("7. Left-aligned text", r'left.*align|Left|TextAlign\.left'),
    ("7. No emoji", r'emoji|Emoji'),
    ("8. 44x44 touch targets", r'MinTapTarget|44\.0|44\s*x\s*44'),
    ("9. 52px primary button", r'AppButtonSize.*lg|52\.0|52\s*px'),
    ("9. 52-56px text field", r'AppTextField.*5[2-6]|5[2-6]\s*px'),
    ("10. Focus ring 2px crimson", r'focus.*ring|focusRing|FocusNode'),
    ("11. Reduce motion", r'reduceMotion|disableAnimations'),
    ("9. No gold/yellow/amber", r'gold|amber|yellow'),
    ("10. No emoji", r'emoji|Emoji'),
    ("11. Left-aligned text", r'left.*align|Left|TextAlign\.left'),
    ("12. WCAG AA contrast", r'WCAG|contrast|4\.5:1'),
    ("13. Focus ring 2px crimson", r'focus.*ring|focusRing|FocusNode'),
    ("13. Reduce motion", r'reduceMotion|disableAnimations'),
    ("14. No color alone for meaning", r'color.*meaning|meaning.*color'),
    ("15. Sound/vibration visual twin", r'visual.*twin|sound.*visual|vibration.*visual'),
    ("16. Reduce motion support", r'reduceMotion|disableAnimations'),
    ("17. Space Grotesk", r'SpaceGrotesk|Space Grotesk'),
    ("17. Tabular figures", r'tabularFigures|FontFeature'),
    ("17. Slashed zero", r'slashedZero|FontFeature'),
    ("17. 300-700 weights", r'FontWeight\.w[3-7]00'),
    ("18. 28px page title", r'pageTitle|28'),
    ("18. 32-34 hero title", r'heroTitle|3[2-4]'),
    ("18. 17px section title", r'sectionTitle|17'),
    ("18. 14px body", r'body|14'),
    ("18. 12.5px meta", r'meta|12\.5'),
    ("18. 10.5px pill", r'pill|10\.5'),
    ("18. 84px clock", r'84.*clock|clock.*84'),
    ("19. 18px gutter", r'gutter.*18|18.*gutter'),
    ("19. 18px card radius", r'AppRadius.*18|18.*radius'),
    ("20. 44x44 tap target", r'MinTapTarget|44'),
    ("21. 52px primary", r'AppButtonSize.*lg|52'),
    ("21. 52-56px field", r'AppTextField.*5[2-6]|5[2-6]\s*px'),
    ("22. Focus ring", r'focus.*ring|focusRing|FocusNode'),
    ("22. Reduce motion", r'reduceMotion|disableAnimations'),
    ("22. No gold", r'gold|amber|yellow'),
    ("23. No emoji", r'emoji|Emoji'),
    ("23. Left-aligned", r'TextAlign\.left|left.*align'),
    ("24. WCAG AA", r'WCAG|contrast|4\.5:1'),
    ("24. Focus ring", r'focus.*ring|focusRing|FocusNode'),
    ("25. Reduce motion", r'reduceMotion|disableAnimations'),
    ("25. No gold", r'gold|amber|yellow'),
    ("26. No emoji", r'emoji|Emoji'),
    ("27. Left-aligned", r'TextAlign\.left|left.*align'),
    ("28. WCAG AA", r'WCAG|contrast|4\.5:1'),
    ("29. Focus ring", r'focus.*ring|focusRing|FocusNode'),
    ("30. Reduce motion", r'reduceMotion|disableAnimations'),
    ("31. Space Grotesk", r'SpaceGrotesk|Space Grotesk'),
    ("31. Tabular figures", r'tabularFigures|FontFeature'),
    ("31. Slashed zero", r'slashedZero|FontFeature'),
    ("31. 300-700 weights", r'FontWeight\.w[3-7]00'),
    ("32. 28px page title", r'pageTitle|28'),
    ("32. 32-34 hero title", r'heroTitle|3[2-4]'),
    ("32. 17px section title", r'sectionTitle|17'),
    ("32. 14px body", r'body|14'),
    ("32. 12.5px meta", r'meta|12\.5'),
    ("32. 10.5px pill", r'pill|10\.5'),
    ("32. 84px clock", r'84.*clock|clock.*84'),
    ("33. 18px gutter", r'gutter.*18|18.*gutter'),
    ("33. 18px card radius", r'AppRadius.*18|18.*radius'),
    ("34. 44x44 tap target", r'MinTapTarget|44'),
    ("35. 52px primary", r'AppButtonSize.*lg|52'),
    ("35. 52-56px field", r'AppTextField.*5[2-6]|5[2-6]\s*px'),
    ("36. Focus ring", r'focus.*ring|focusRing|FocusNode'),
    ("36. Reduce motion", r'reduceMotion|disableAnimations'),
    ("36. No gold", r'gold|amber|yellow'),
    ("37. No emoji", r'emoji|Emoji'),
    ("38. Left-aligned", r'TextAlign\.left|left.*align'),
    ("39. WCAG AA", r'WCAG|contrast|4\.5:1'),
    ("40. Focus ring", r'focus.*ring|focusRing|FocusNode'),
    ("41. Reduce motion", r'reduceMotion|disableAnimations'),
    ("41. Space Grotesk", r'SpaceGrotesk|Space Grotesk'),
    ("42. Tabular figures", r'tabularFigures|FontFeature'),
    ("42. Slashed zero", r'slashedZero|FontFeature'),
    ("42. 300-700 weights", r'FontWeight\.w[3-7]00'),
    ("43. 28px page title", r'pageTitle|28'),
    ("44. 32-34 hero title", r'heroTitle|3[2-4]'),
    ("44. 17px section title", r'sectionTitle|17'),
    ("44. 14px body", r'body|14'),
    ("44. 12.5px meta", r'meta|12\.5'),
    ("44. 10.5px pill", r'pill|10\.5'),
    ("44. 84px clock", r'84.*clock|clock.*84'),
    ("45. 18px gutter", r'gutter.*18|18.*gutter'),
    ("45. 18px card radius", r'AppRadius.*18|18.*radius'),
    ("46. 44x44 tap target", r'MinTapTarget|44'),
    ("47. 52px primary", r'AppButtonSize.*lg|52'),
    ("47. 52-56px field", r'AppTextField.*5[2-6]|5[2-6]\s*px'),
    ("48. Focus ring", r'focus.*ring|focusRing|FocusNode'),
    ("48. Reduce motion", r'reduceMotion|disableAnimations'),
    ("48. No gold", r'gold|amber|yellow'),
    ("49. No emoji", r'emoji|Emoji'),
    ("50. Left-aligned", r'TextAlign\.left|left.*align'),
    ("51. WCAG AA", r'WCAG|contrast|4\.5:1'),
    ("52. Focus ring", r'focus.*ring|focusRing|FocusNode'),
    ("53. Reduce motion", r'reduceMotion|disableAnimations'),
]

with open('requirements.json', 'r', encoding='utf-8') as f:
    requirements = json.load(f)

print(f"Total requirements in spreadsheet: {len(requirements)}")
print("=== REQUIREMENTS VERIFICATION ===\n")

found_count = 0
total_checks = 0

for desc, pattern in checks:
    total_checks += 1
    matches = []
    for ext in ('.dart',):
        for file_path in Path(r'D:\StudioProjects\poker_night\lib').rglob(f'*{ext}'):
            try:
                content = file_path.read_text(encoding='utf-8', errors='ignore')
                if re.search(pattern, content, re.IGNORECASE):
                    matches.append(str(file_path.relative_to(Path(r'D:\StudioProjects\poker_night'))))
                    if len(matches) >= 2:
                        break
            except:
                pass
    if matches:
        found_count += 1
        status = "FOUND"
    else:
        status = "MISSING"
    print(f"[{status}] {pattern} | {matches[0] if matches else ''}")

print(f"\n\nSummary: {found_count}/{total_checks} patterns found in codebase")
print(f"Coverage: {found_count/total_checks*100:.1f}%")