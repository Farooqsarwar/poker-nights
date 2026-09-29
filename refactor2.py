import re

file_path = 'lib/utils/tournament_engine.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    text = f.read()

# We need to find the start of the dead block:
start_pattern = r'\s*(?://.*?\n)*\s*static List<Prize> _calcPrizes'
match_start = re.search(start_pattern, text)

# Find the end of recalculatePrizes. 
end_pattern = r'recalculatePrizes\(\s*int grossEligible,\s*int players,\s*num organizerPct, \{\s*int\? forcePaidPlaces,\s*int roundingUnit = 10,\s*PayoutShape shape = PayoutShape\.standard,\s*\}\) \{'
match_end = re.search(end_pattern, text)

if match_start and match_end:
    idx = match_end.start()
    brace_start = text.find('{', idx)
    
    count = 1
    curr = brace_start + 1
    while count > 0 and curr < len(text):
        if text[curr] == '{':
            count += 1
        elif text[curr] == '}':
            count -= 1
        curr += 1
    
    text = text[:match_start.start()] + text[curr:]
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(text)
    print('Deleted dead block from tournament_engine.dart')
else:
    print('Could not find dead block')
