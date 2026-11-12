# CLAUDE.md

Number Reader: statisk PWA (ingen build), dansk UI. Numerisk blok (iOS Telefon) + lommeregner (fra Thyxo/Calcplus) der scanner T9-tal med kameraet og afkoder til navn. Se README.md.

- `src/calc/*` er uændrede kopier fra Calcplus – ret dér og kopiér.
- `src/words.js` genereres af `scripts/build-words.py` fra `data/*.txt`.
- `vendor/` = tesseract.js 6.0.1 (worker, core lstm/simd-lstm, eng best_int). Rør ikke.
- Hæv `VERSION` i `sw.js` ved ændringer. Test: `npm test`. Push til `main` udgiver på Vercel.
