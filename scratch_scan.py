import fitz, re, sys, os
sys.stdout.reconfigure(encoding='utf-8')

doc = fitz.open(r'D:\StudioProjects\poker_night\App redesign .pdf')
page = doc[0]
blocks = page.get_text('blocks')

flows = []
screens = []

for b in blocks:
    text = b[4].strip()
    lines = [l.strip() for l in text.split('\n') if l.strip()]
    if not lines:
        continue
    first = lines[0]
    
    # Check for flow headers like 'A | ...', 'B | ...'
    if re.match(r'^[A-Z]\s*\|\s*', first):
        flows.append({'rect': b[:4], 'header': first, 'desc': ' '.join(lines[1:])})
    # Check for screen labels like 'A1 Splash', 'B1 Dashboard'
    elif re.match(r'^[A-Z]\d{1,2}\s+[A-Za-z]', first):
        screens.append({'rect': b[:4], 'title': first})

# Sort by y, then x
flows.sort(key=lambda x: x['rect'][1])
screens.sort(key=lambda x: (round(x['rect'][1] / 50) * 50, x['rect'][0]))

print(f"Total Flows: {len(flows)}")
for f in flows:
    print(f"  {f['header']} (y={f['rect'][1]:.1f})")

print(f"\nTotal Screens: {len(screens)}")
for s in screens:
    print(f"  {s['title']:35} at ({s['rect'][0]:.1f}, {s['rect'][1]:.1f})")
