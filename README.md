# Number Reader – T9-tal → navn med kameraet

PWA der ligner iPhonens **Telefon-tastatur** (eller **Lommeregneren** fra Calcplus). Tilskueren tænker på en kendt person og skriver navnet med tallene på en numerisk blok (fx `Kim Larsen` → `546527736`). Magikeren peger telefonen mod tallene, appen læser dem med kameraet og afkoder dem med dansk ordbog. Ordet vises som svag peek-tekst.

Ren vanilla JS, ingen build. OCR: Tesseract.js (lagt i `vendor/`, virker offline efter første hentning), eller browserens egen `TextDetector` hvis den findes.

## Brug

| Handling | Hvordan |
|---|---|
| **Hemmeligt panel** | 5 hurtige tryk øverst til højre |
| **Scan med kameraet** | Numerisk blok: tryk over nummeret (det tomme felt øverst). Lommeregner: tryk mellem de to runde knapper. Tryk igen = stop |
| **Peek-skærm** | Tryk ✱ på den numeriske blok → sort/hvid skærm med ordet i 2 sek. (eller til tryk) |
| **Peek-tekst** | Blok: navnet står i fanernes tekst (Opkald → fornavn, Kontakter → efternavn, 3. fane → fødselsdag/mål) – eller svagt over home-baren. Lommeregner: øverst mellem ikonerne |
| **Regnemetode** | y − x = a. x = tilskuerens scannede tal, y = tvunget tal (personens fødselsdag, dato i dag, klokken eller fast tal), a = mit tal, som sættes i nummerfeltet. Tilskueren regner x + a = y på lommeregneren. Er x > y, står der − i peeket: x − a = y |
| **Skift** | Luppen på blokken = lommeregner. Hold på uret i lommeregneren = blokken |
| **Debug** | Panelet → "Debug": de sidste 15 billeder kameraet har set, med grøn boks om det læste tal, strategi, tid og sikkerhed. Swipe mellem billederne |
| **Skift mode** | Panelet → *Numerisk blok* / *Lommeregner* |
| **Vælg et andet bud** | Panelet → tryk på et af forslagene |

Tal tastet direkte på blokken dekodes også (kan slås fra).

### Dekodning
- 2 = ABC (Æ Å), 3 = DEF, 4 = GHI, 5 = JKL, 6 = MNO (Ø), 7 = PQRS, 8 = TUV, 9 = WXYZ.
- 0 og 1 = mellemrum (flere ord).
- Rækkefølge: *egne navne* → *kendte personer* (ca. 470, `data/kendte.txt`) → fornavne/efternavne → *fornavn + efternavn* → 25.000 danske ord efter hyppighed.
- Ret listerne i `data/*.txt` og kør `npm run words` (henter frekvenslisten fra hermitdave/FrequencyWords).

### Kamera
- Videoen er usynlig. *Vis søger* (panel → Kamera) viser et lille billede til træning.
- Midten af billedet læses (eller hele billedet). Samme tal skal læses 2 gange (eller 1).
- Mørk skærm med lys tekst vendes automatisk. Appen skifter mellem 5 læse-strategier fra billede til billede.
- iOS viser den grønne kamera-prik, mens der scannes. Kameraet stopper selv, når ordet er fundet, efter 30 sek. eller når appen lægges væk.

## Udvikling
```bash
npm run dev     # http://localhost:5173
npm test        # dekoder + OCR-tekst
npm run words   # byg src/words.js
node scripts/make-icons.cjs   # app-ikon (kræver Playwright/Chromium)
```
Testet i headless Chromium med falsk kamera: mørk skærm `546527736` → **Kim Larsen** (0,4 s), lys skærm skrå `62 37 64 55 35 736` → **Mads Mikkelsen** (0,6 s), små tal `82956779438` → **Taylor Swift** (0,4 s). Ikke testet på fysisk iPhone endnu.

## Filer
```
index.html, styles.css (Calcplus), pad.css (blok, peek, panel)
src/app.js       tilstand, panel, peek, kamera-styring, numerisk blok, debug-visning
src/force.js     regnemetoden (y − x = a) og fødselsdage
data/foedselsdage.txt  fødselsdage til kendte (scripts/fetch-birthdays.py henter fra Wikidata)
src/calcui.js    lommeregner-UI (fra Thyxo/Calcplus, uden force)
src/calc/        lommeregner-motor (uændret kopi fra Calcplus)
src/t9.js        T9-dekoder
src/words.js     genereret ordbog
src/ocr.js       kamera + Tesseract/TextDetector
vendor/          tesseract.js 6.0.1 + core + eng (best_int)
sw.js            offline-cache – hæv VERSION ved ændringer
```

## Udgivelse (Vercel)
Vercel-projekt **number-reader** (team *thyxo's projects*), koblet til GitHub:
- push til `main` → produktion: **https://number-reader-indol.vercel.app**
- push til andre branches → preview-link (kræver Vercel-login)

### Installér på iPhone
Åbn adressen i **Safari** → Del → **Føj til hjemmeskærm** (navnet er "Telefon"). Giv kameraadgang første gang du scanner.

## Native iOS-app (SideStore)
Mappen `ios/` er en native Swift/SwiftUI-version af appen (samme funktioner, Apple Vision i stedet for Tesseract). Den bygges i GitHub Actions (`.github/workflows/ios.yml`) uden Mac og uden signering – SideStore signerer selv.

**SideStore-source:** `https://raw.githubusercontent.com/Thyxo/number-reader/main/sidestore/apps.json`

1. Åbn SideStore på iPhonen → **Sources** → **+** → indsæt linket ovenfor.
2. Find **Telefon** i sourcen → **Free** / **Install**.
3. Opdateringer: hver build laver en GitHub Release (`v<version>-<build>`), og workflowet opdaterer `sidestore/apps.json` automatisk.

| Fil | Indhold |
|---|---|
| `ios/project.yml` | XcodeGen-projekt (iOS 17, `dk.thyxo.numberreader`, navn "Telefon"). Version = `MARKETING_VERSION` |
| `ios/NumberReader/Model/` | T9, regnemetode, lommeregner, indstillinger (ingen UIKit – testes på Linux/macOS med `swiftc`) |
| `ios/NumberReader/Scan/` | Kamera + Vision (`VNRecognizeTextRequest`, `.accurate`, ingen sprogkorrektion) |
| `ios/NumberReader/Views/` | Numerisk blok, lommeregner, hemmeligt panel, peek-skærm, debug |
| `ios/scripts/make-words-json.py` | `src/words.js` → `ios/NumberReader/Resources/words.json` (kører også i CI) |
| `ios/Tests/main.swift` | Én hurtig test af T9 + regnemetoden (kører i CI før buildet) |

**Kun i iOS-appen:**
- **Volumen op** = start scanning, **volumen ned** = stop (lydstyrken sættes straks tilbage). Kan slås fra under Kamera.
- **Flere scanninger:** på peek-skærmen (✱) swipes til højre for ældre og til venstre for nyere (op til 30).
- **Udvidet ordbog:** +7.000 kendte (Wikidata, danskere først), fødselsdage til ~6.900 af dem, +6.000 for-/efternavne (hyppigst blandt danskere i Wikidata) og +190.000 ord (Stavekontrolden.dk + OpenSubtitles-frekvens). Altid under de håndplukkede lister. Hentes med `python3 ios/scripts/fetch-data.py` → `ios/data/`.
- **Kvalificeret gæt**, når intet passer: sammensatte ord, ét fejllæst/manglende/ekstra ciffer, ord der starter med tallene og til sidst mest sandsynlige bogstaver.
- **Lommeregner → telefon:** tryk på det sorte felt nederst til venstre under knapperne (eller hold på uret).

Lokalt på en Mac: `brew install xcodegen && cd ios && xcodegen && open NumberReader.xcodeproj`.
