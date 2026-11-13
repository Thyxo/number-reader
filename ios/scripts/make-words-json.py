#!/usr/bin/env python3
"""Lav ios/NumberReader/Resources/words.json ud fra src/words.js (som bygges af
scripts/build-words.py fra data/*.txt). Kører også i GitHub Actions før buildet.

  python3 ios/scripts/make-words-json.py
"""
import json, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, 'src', 'words.js')
OUT = os.path.join(ROOT, 'ios', 'NumberReader', 'Resources', 'words.json')

text = open(SRC, encoding='utf-8').read()
def get(name):
    m = re.search(r'^export const ' + name + r' = (.*);$', text, re.M)
    return json.loads(m.group(1))

data = {
    'celebs': get('CELEBS').split('|'),
    'first': get('FIRST').split(' '),
    'last': get('LAST').split(' '),
    'bdays': get('BDAYS'),
    'words': get('WORDS').split(' '),
}
# Fødselsdage direkte fra data/foedselsdage.txt, hvis filen findes (samme format som build-words.py)
bpath = os.path.join(ROOT, 'data', 'foedselsdage.txt')
if os.path.exists(bpath):
    for ln in open(bpath, encoding='utf-8'):
        if '|' in ln and not ln.startswith('#'):
            n, d = ln.strip().split('|', 1)
            if d: data['bdays'][n] = d

# Udvidet data til iOS (ios/data/*.txt, hentes med ios/scripts/fetch-data.py)
def extra(name):
    path = os.path.join(ROOT, 'ios', 'data', name)
    if not os.path.exists(path): return []
    return [l.strip() for l in open(path, encoding='utf-8') if l.strip() and not l.startswith('#')]

data['celebsExtra'] = extra('kendte-ekstra.txt')
data['firstExtra'] = extra('fornavne-ekstra.txt')
data['lastExtra'] = extra('efternavne-ekstra.txt')
data['wordsExtra'] = extra('ord-ekstra.txt')
for ln in extra('foedselsdage.txt'):
    n, _, d = ln.partition('|')
    if d and n not in data['bdays']: data['bdays'][n] = d

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
print(f"{len(data['celebs'])} kendte, {len(data['first'])} fornavne, {len(data['last'])} efternavne, "
      f"{len(data['bdays'])} fødselsdage, {len(data['words'])} ord + ekstra: {len(data['celebsExtra'])} kendte, "
      f"{len(data['firstExtra'])}/{len(data['lastExtra'])} navne, {len(data['wordsExtra'])} ord → {os.path.relpath(OUT, ROOT)} "
      f"({os.path.getsize(OUT) // 1024} KB)")
