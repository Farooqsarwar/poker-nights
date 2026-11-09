import json

with open('requirements.json', 'r', encoding='utf-8') as f:
    reqs = json.load(f)

with open('all_reqs.txt', 'w', encoding='utf-8') as f:
    for r in reqs:
        text = r['text']
        text = text.replace('\u2212', '-').replace('\u2013', '-').replace('\u2014', '-')
        text = text.replace('\u2018', "'").replace('\u2019', "'")
        text = text.replace('\u201c', '"').replace('\u201d', '"')
        f.write(str(r['num']) + ': ' + text + '\n')

print('Done')