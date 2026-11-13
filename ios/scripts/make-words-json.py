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

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
print(f"{len(data['celebs'])} kendte, {len(data['first'])} fornavne, {len(data['last'])} efternavne, "
      f"{len(data['bdays'])} fødselsdage, {len(data['words'])} ord → {os.path.relpath(OUT, ROOT)}")
