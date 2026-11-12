#!/usr/bin/env python3
"""Henter fødselsdage for navnene i data/kendte.txt fra Wikidata → data/foedselsdage.txt.
Linjer med en dato i filen bevares (ret dem i hånden, hvis Wikidata tager fejl).
Kør: SSL_CERT_FILE=... python3 scripts/fetch-birthdays.py && npm run words"""
import json, os, time, urllib.parse, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'data', 'foedselsdage.txt')

def api(params):
    for i in range(5):
        try:
            req = urllib.request.Request('https://www.wikidata.org/w/api.php?' + urllib.parse.urlencode({**params, 'format': 'json'}),
                headers={'User-Agent': 'number-reader-build/1.0'})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)
        except Exception as e:
            print('  fejl:', e, flush=True); time.sleep(90 * (i + 1))
    return {}

def born(ent):
    c = ent.get('claims', {})
    if not any(x['mainsnak'].get('datavalue', {}).get('value', {}).get('id') == 'Q5' for x in c.get('P31', [])):
        return ''
    for x in c.get('P569', []):
        v = x['mainsnak'].get('datavalue', {}).get('value', {})
        if v.get('precision') == 11:
            return v['time'].lstrip('+')[:10]
    return ''

names = [l.strip() for l in open(os.path.join(ROOT, 'data', 'kendte.txt'), encoding='utf-8') if l.strip() and not l.startswith('#')]
have = {}
if os.path.exists(OUT):
    for l in open(OUT, encoding='utf-8'):
        if '|' in l and not l.startswith('#'):
            n, d = l.rstrip('\n').split('|', 1)
            if d: have[n] = d

# Slå navnene op som artikeltitler på dansk og engelsk Wikipedia (50 ad gangen)
todo = [n for n in names if n not in have]
for site in ('dawiki', 'enwiki'):
    todo = [n for n in todo if n not in have]
    for i in range(0, len(todo), 50):
        chunk = todo[i:i + 50]
        r = api({'action': 'wbgetentities', 'sites': site, 'titles': '|'.join(chunk), 'props': 'claims|sitelinks', 'sitefilter': site})
        for ent in r.get('entities', {}).values():
            t = ent.get('sitelinks', {}).get(site, {}).get('title')
            b = born(ent)
            if t and b:
                for n in chunk:
                    if n.lower() == t.lower(): have[n] = b
        print(site, f'{i + len(chunk)}/{len(todo)}', flush=True)
        time.sleep(12)

with open(OUT, 'w', encoding='utf-8') as f:
    f.write('# Fødselsdage (ÅÅÅÅ-MM-DD) til kendte personer. Hentet fra Wikidata – ret gerne i hånden. Tom = ukendt.\n')
    for n in names:
        f.write(f'{n}|{have.get(n, "")}\n')
print(sum(1 for n in names if have.get(n)), 'af', len(names), 'har dato')
