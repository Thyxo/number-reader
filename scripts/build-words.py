#!/usr/bin/env python3
"""Byg src/words.js ud fra data/*.txt og en dansk frekvensliste.

  python3 scripts/build-words.py [sti/til/da_50k.txt]

Frekvenslisten (hermitdave/FrequencyWords, da_50k.txt) hentes automatisk hvis
den ikke er givet. Resultatet er et ES-modul uden afhængigheder."""
import json, os, re, sys, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, 'data')
URL = 'https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/da/da_50k.txt'
MAX_WORDS = 25000
LETTERS = re.compile(r'^[a-zæøåéü]{2,}$')

def lines(name):
    with open(os.path.join(DATA, name), encoding='utf-8') as f:
        for ln in f:
            ln = ln.strip()
            if ln and not ln.startswith('#'):
                yield ln

def main():
    src = sys.argv[1] if len(sys.argv) > 1 else None
    if src:
        text = open(src, encoding='utf-8').read()
    else:
        text = urllib.request.urlopen(URL).read().decode('utf-8')
    words, seen = [], set()
    for ln in text.splitlines():
        w = ln.split(' ')[0].lower()
        if LETTERS.match(w) and w not in seen:
            seen.add(w)
            words.append(w)
        if len(words) >= MAX_WORDS:
            break
    celebs, cs = [], set()
    for c in lines('kendte.txt'):
        if c.lower() not in cs:
            cs.add(c.lower())
            celebs.append(c)
    first = []
    for ln in lines('fornavne.txt'):
        for n in ln.split():
            if n not in first:
                first.append(n)
    last = []
    for ln in lines('efternavne.txt'):
        for n in ln.split():
            if n not in last:
                last.append(n)
    out = os.path.join(ROOT, 'src', 'words.js')
    with open(out, 'w', encoding='utf-8') as f:
        f.write('// Genereret af scripts/build-words.py – ret i data/*.txt og kør scriptet igen.\n')
        f.write('export const CELEBS = ' + json.dumps('|'.join(celebs), ensure_ascii=False) + ';\n')
        f.write('export const FIRST = ' + json.dumps(' '.join(first), ensure_ascii=False) + ';\n')
        f.write('export const LAST = ' + json.dumps(' '.join(last), ensure_ascii=False) + ';\n')
        f.write('export const WORDS = ' + json.dumps(' '.join(words), ensure_ascii=False) + ';\n')
    print(f'{len(celebs)} kendte, {len(first)} fornavne, {len(last)} efternavne, {len(words)} ord → {out} ({os.path.getsize(out)//1024} KB)')

main()
