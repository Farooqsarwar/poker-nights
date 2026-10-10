import pandas as pd
import os
import re

df = pd.read_excel(r'C:\Users\farooq sarwar\Downloads\Poker_Night_Requirements.xlsx')
missing = df[df['client review '].notna()]

def check_codebase(req_text):
    req_lower = str(req_text).lower()
    
    keywords_map = {
        'cash': ['cash_game', 'cash_settlement', 'cash_'],
        'tv ': ['tv_mode', 'tv_'],
        'premium': ['premium', 'checkout', 'upgrade'],
        'import': ['import_results_parser'],
        'standings': ['standings', 'season'],
        'history': ['history'],
        'profile': ['profile'],
        'settings': ['settings'],
        'tools': ['tools', 'public'],
        'guest': ['guest'],
        'voice': ['voice'],
        'audio': ['audio', 'voice'],
        'offline': ['offline', 'sqlite', 'sync'],
        'export': ['export'],
        'engine': ['engine', 'tournament_engine', 'payouts_engine'],
        'privacy': ['privacy'],
        'terms': ['terms'],
        'support': ['support'],
        'code': ['model_codec', 'code'],
        'results': ['results'],
        'calculator': ['tools', 'calculator']
    }
    
    lib_files = []
    for root, dirs, files in os.walk('lib'):
        for f in files:
            if f.endswith('.dart'):
                lib_files.append(os.path.relpath(os.path.join(root, f), 'lib').replace('\\\\', '/'))
                
    matched_files = set()
    for kw, file_kws in keywords_map.items():
        if kw in req_lower:
            for f in lib_files:
                for fk in file_kws:
                    if fk in f.lower():
                        matched_files.add(f)
                        
    if matched_files:
        return 'Found: ' + ', '.join(list(matched_files)[:3])
    return 'Pending Deep Check'

with open(r'C:\Users\farooq sarwar\.gemini\antigravity-cli\brain\1ba2cd9a-0c85-4ffe-9b17-4f58ffc9f186\Line_by_Line_Audit.md', 'w', encoding='utf-8') as f:
    f.write('# Line-by-Line Requirement Audit\n\n')
    f.write('This artifact cross-references the 162 requirements marked as missing against the current codebase.\n\n')
    f.write('| Req # | Requirement Fragment | Codebase Evidence |\n')
    f.write('|---|---|---|\n')
    
    for idx, row in missing.iterrows():
        req = str(row['Requirements']).replace('\n', ' ')
        match = re.match(r'^\"?(\d+)\.', req)
        req_num = match.group(1) if match else '?'
        evidence = check_codebase(req)
        # truncate req for table
        trunc_req = (req[:150] + '...') if len(req) > 150 else req
        f.write(f'| {req_num} | {trunc_req} | {evidence} |\n')
