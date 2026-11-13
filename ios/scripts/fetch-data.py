#!/usr/bin/env python3
"""Henter ekstra data til iOS-appen → ios/data/*.txt (committes; køres ikke i CI).

  python3 ios/scripts/fetch-data.py

Kilder:
- Wikidata (via QLever, qlever.dev): kendte danskere og verdenskendte personer sorteret efter
  antal Wikipedia-sprog (sitelinks), deres fødselsdage, og de hyppigste for- og efternavne blandt
  danskere i Wikidata.
- Stavekontrolden.dk (LibreOffice/dictionaries da_DK, GPL/LGPL/MPL): alle ~180.000 opslagsord.
- hermitdave/FrequencyWords da_full (OpenSubtitles 2018, CC-BY-SA): ordformer efter hyppighed.
"""
import json, os, re, urllib.parse, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'ios', 'data')
UA = {'User-Agent': 'number-reader-build/1.0'}
PREFIX = ('PREFIX wdt: <http://www.wikidata.org/prop/direct/> PREFIX wd: <http://www.wikidata.org/entity/> '
          'PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#> PREFIX wikibase: <http://wikiba.se/ontology#> ')
LETTERS = re.compile(r"^[A-Za-zÆØÅæøåÉéÜüÖöÄä][A-Za-zÆØÅæøåÉéÜüÖöÄä.' -]*$")

def get(url, timeout=300):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=timeout) as r:
        return r.read()

def sparql(q):
    data = urllib.parse.urlencode({'query': PREFIX + q}).encode()
    req = urllib.request.Request('https://qlever.dev/api/wikidata', data=data, headers={**UA, 'Accept': 'application/sparql-results+json',
                                 'Content-Type': 'application/x-www-form-urlencoded'})
    with urllib.request.urlopen(req, timeout=600) as r:
        return [{k: v['value'] for k, v in b.items()} for b in json.load(r)['results']['bindings']]

def label(b):
    for k in ('da', 'mul', 'en'):
        if b.get(k): return b[k]
    return ''

def people(where, limit):
    q = f'''SELECT ?p ?sl ?da ?mul ?en ?b WHERE {{ {where} ?p wdt:P31 wd:Q5 . ?p wikibase:sitelinks ?sl .
      OPTIONAL {{ ?p rdfs:label ?da FILTER(LANG(?da)="da") }} OPTIONAL {{ ?p rdfs:label ?mul FILTER(LANG(?mul)="mul") }}
      OPTIONAL {{ ?p rdfs:label ?en FILTER(LANG(?en)="en") }} OPTIONAL {{ ?p wdt:P569 ?b }} }} ORDER BY DESC(?sl) LIMIT {limit}'''
    out, seen = [], set()
    for b in sparql(q):
        if b['p'] in seen: continue
        seen.add(b['p'])
        n = label(b).strip()
        if not n or not LETTERS.match(n) or len(n) > 40: continue
        out.append((n, b.get('b', '')[:10] if b.get('b', '').startswith(('1', '2')) else ''))
    return out

def names(prop, limit):
    q = f'''SELECT ?g ?da ?mul ?en ?n WHERE {{ {{ SELECT ?g (COUNT(DISTINCT ?p) AS ?n) WHERE {{
      {{ ?p wdt:P27 wd:Q756617 }} UNION {{ ?p wdt:P27 wd:Q35 }} ?p wdt:{prop} ?g . }} GROUP BY ?g }}
      OPTIONAL {{ ?g rdfs:label ?da FILTER(LANG(?da)="da") }} OPTIONAL {{ ?g rdfs:label ?mul FILTER(LANG(?mul)="mul") }}
      OPTIONAL {{ ?g rdfs:label ?en FILTER(LANG(?en)="en") }} }} ORDER BY DESC(?n) LIMIT {limit}'''
    out, seen = [], set()
    for b in sparql(q):
        n = label(b).strip()
        if n and ' ' not in n and LETTERS.match(n) and n.lower() not in seen:
            seen.add(n.lower()); out.append(n)
    return out

def write(name, header, lines):
    with open(os.path.join(OUT, name), 'w', encoding='utf-8') as f:
        f.write(header.rstrip() + '\n')
        for l in lines: f.write(l + '\n')
    print(f'{name}: {len(lines)}')

os.makedirs(OUT, exist_ok=True)

# ---------- kendte ----------
dk = people('{ ?p wdt:P27 wd:Q756617 } UNION { ?p wdt:P27 wd:Q35 }', 4000)
world = people('', 4000)
celebs, bdays, seen = [], {}, set()
for n, b in dk + world:
    if n.lower() in seen: continue
    seen.add(n.lower()); celebs.append(n)
    if b: bdays[n] = b
write('kendte-ekstra.txt', '# Kendte fra Wikidata: først danskere, så verdenskendte (flest Wikipedia-sprog først). Genereres af ios/scripts/fetch-data.py', celebs)

# Fødselsdage – også til data/kendte.txt (slås op på navn)
curated = [l.strip() for l in open(os.path.join(ROOT, 'data', 'kendte.txt'), encoding='utf-8') if l.strip() and not l.startswith('#')]
missing = [n for n in curated if n not in bdays]
for i in range(0, len(missing), 100):
    vals = ' '.join('"{0}"@da "{0}"@en "{0}"@mul'.format(n.replace('"', '')) for n in missing[i:i + 100])
    q = f'SELECT ?l ?b ?sl WHERE {{ VALUES ?l {{ {vals} }} ?p rdfs:label ?l . ?p wdt:P31 wd:Q5 . ?p wdt:P569 ?b . ?p wikibase:sitelinks ?sl }} ORDER BY DESC(?sl)'
    for r in sparql(q):
        if r['l'] not in bdays and r['b'][:1] in '12': bdays[r['l']] = r['b'][:10]
write('foedselsdage.txt', '# Navn|ÅÅÅÅ-MM-DD fra Wikidata. Genereres af ios/scripts/fetch-data.py', [f'{n}|{d}' for n, d in bdays.items()])

# ---------- navne ----------
write('fornavne-ekstra.txt', '# Hyppigste fornavne blandt danskere i Wikidata', names('P735', 3000))
write('efternavne-ekstra.txt', '# Hyppigste efternavne blandt danskere i Wikidata', names('P734', 3000))

# ---------- ordbog ----------
freq = []
for ln in get('https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/da/da_full.txt').decode('utf-8').splitlines():
    w, _, c = ln.partition(' ')
    if c.isdigit() and int(c) >= 5 and re.match(r'^[a-zæøåéü]{2,}$', w): freq.append(w)
dic = []
for ln in get('https://raw.githubusercontent.com/LibreOffice/dictionaries/master/da_DK/da_DK.dic').decode('utf-8').splitlines()[1:]:
    w = ln.split('/')[0].strip()
    if re.match(r'^[A-Za-zÆØÅæøåéü][a-zæøåéü-]*[a-zæøåéü]$', w) and '--' not in w: dic.append(w)
# Hunspell-ord, der også findes i frekvenslisten, er rigtige danske ord: de kommer først (efter
# hyppighed), derefter resten af frekvenslisten, til sidst resten af Stavekontrolden.
dset = {w.lower() for w in dic}
fset = set(freq)
words = [w for w in freq if w in dset] + [w for w in freq if w not in dset][:40000]
seen = set(words)
for w in dic:
    if w.lower() not in seen and w.lower() not in fset:
        seen.add(w.lower()); words.append(w)
write('ord-ekstra.txt', '# Danske ord: frekvens (OpenSubtitles) + Stavekontrolden.dk. Genereres af ios/scripts/fetch-data.py', words)
