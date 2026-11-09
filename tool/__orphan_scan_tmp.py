import os
import re

ROOT = r'D:\StudioProjects\poker_night'
LIB = os.path.join(ROOT, 'lib')

files = []
for dp, _, fns in os.walk(LIB):
    for f in fns:
        if f.endswith('.dart'):
            files.append(os.path.join(dp, f))

def uri(p):
    return 'package:poker_night/' + os.path.relpath(p, LIB).replace(os.sep, '/')

urimap = {uri(f): f for f in files}
importers = {u: set() for u in urimap}
imp_re = re.compile(r"(?:import|export)\s+['\"]([^'\"]+)['\"]")
part_re = re.compile(r"part\s+['\"]([^'\"]+)['\"]")
part_of_re = re.compile(r"part\s+of\s+['\"]?[\w/\.]+['\"]?\s*;")

allf = []
for r in ['lib', 'test', 'tool']:
    rd = os.path.join(ROOT, r)
    if not os.path.isdir(rd):
        continue
    for dp, _, fns in os.walk(rd):
        for f in fns:
            if f.endswith('.dart'):
                allf.append(os.path.join(dp, f))

for f in allf:
    try:
        s = open(f, encoding='utf-8', errors='replace').read()
    except Exception:
        continue
    is_part = bool(part_of_re.search(s))
    if is_part:
        importers[uri(f)].add('<part-of>')
    for m in imp_re.findall(s):
        if m in urimap:
            if os.path.normpath(f) != os.path.normpath(urimap[m]):
                importers[m].add(os.path.relpath(f, ROOT))
        elif not m.startswith('dart:'):
            # bare or ./-relative import: resolve against the importer's dir
            tgt = os.path.normpath(os.path.join(os.path.dirname(f), m))
            for u, p in urimap.items():
                if os.path.normpath(p) == tgt and os.path.normpath(f) != os.path.normpath(p):
                    importers[u].add(os.path.relpath(f, ROOT))
    for m in part_re.findall(s):
        tgt = os.path.normpath(os.path.join(os.path.dirname(f), m))
        for u, p in urimap.items():
            if os.path.normpath(p) == tgt:
                importers[u].add(os.path.relpath(f, ROOT) + ' (part)')

orphans = sorted(u for u, im in importers.items() if not im)
print('total lib files:', len(files))
print('scanned importers:', len(allf))
print('ORPHANS:', len(orphans))
for o in orphans:
    print('  ', o)
