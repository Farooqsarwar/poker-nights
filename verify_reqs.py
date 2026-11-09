import json
import os
import re

with open('requirements.json', 'r', encoding='utf-8') as f:
    requirements = json.load(f)

with open('req_list.txt', 'w', encoding='utf-8') as f:
    for r in requirements:
        text = r['text'][:200]
        text = text.replace('\n', ' ').replace('\u2212', '-').replace('\u2013', '-')
        text = text.replace('\u2018', "'").replace('\u2019', "'")
        text = text.replace('\u201c', '"').replace('\u201d', '"')
        f.write(str(r['num']) + ': ' + text + '\n')

print('Done')