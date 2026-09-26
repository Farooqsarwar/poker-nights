import fitz, re, sys, json
sys.stdout.reconfigure(encoding='utf-8')

doc = fitz.open(r'D:\StudioProjects\poker_night\App redesign .pdf')
page = doc[0]
blocks = page.get_text('blocks')

headers = []
screens = []

for b in blocks:
    text = b[4].strip()
    if re.match(r'^[A-Z]\s*\|\s*', text):
        headers.append({
            'rect': [round(x, 1) for x in b[:4]],
            'text': text
        })
    elif re.match(r'^[A-Z]\d{1,2}\s+', text):
        screens.append({
            'rect': [round(x, 1) for x in b[:4]],
            'text': text.split('\n')[0]
        })

print(f"Total flow headers: {len(headers)}")
for h in headers:
    print(f"Flow: {h['text'][:80]} at {h['rect']}")

print(f"\nTotal screens: {len(screens)}")
for s in screens:
    print(f"Screen: {s['text']} at {s['rect']}")

with open('audit_structure.json', 'w', encoding='utf-8') as f:
    json.dump({'flows': headers, 'screens': screens}, f, indent=2)
