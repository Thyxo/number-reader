# Prompt: Number Reader som native iOS-app (SideStore)

Byg en native iOS-version (Swift/SwiftUI) af min webapp **Number Reader** i repoet `Thyxo/number-reader`. Webappen er facit for alle funktioner og alt udseende. Læs `README.md`, `CLAUDE.md`, `index.html`, `pad.css`, `styles.css` og `src/*.js` grundigt, før du går i gang. Alle funktioner skal med. Der skal ikke fjernes noget, appen skal bare være native.

UI og kommentarer skal være på dansk. Jeg har ingen Mac, så alt skal bygges i GitHub Actions og installeres med SideStore.

## Mål
En sideloadet app, der ligner iPhonens Telefon-tastatur og Lommeregner. Den scanner tal, som en tilskuer har tastet T9-agtigt (et navn), med kameraet. Tallene afkodes til danske navne og ord, og resultatet vises som diskrete peeks.

Aflæsningen skal bruge Apple Vision (`VNRecognizeTextRequest`) i stedet for Tesseract, så den bliver hurtigere og bedre.

## Placering
- Læg det hele i mappen `ios/` i samme repo, på en ny branch.
- Webappen må ikke ændres.
- Brug **XcodeGen** (`ios/project.yml`), så der ikke skal committes en `.xcodeproj`.
- Minimum iOS 17. Bundle id: `dk.thyxo.numberreader`. Appnavn på hjemmeskærmen: **Telefon**.
- App-ikon: brug `icons/icon-512.png` fra repoet.

## Funktioner, der skal porteres 1:1

1. **Numerisk blok (iOS Telefon):**
   - Mål, farver og placeringer fra `pad.css`. Alle mål er i pt på en 393 pt bred skærm og skaleres med skærmbredden.
   - Taster med bogstaver, tastetoner (DTMF), hold 0 for +, og slet-knap med gentagelse, når man holder.
   - Talformatering i par.
   - Grøn opkaldsknap: brug `icons/handset.png` som ikon.
   - Fanebjælke med Opkald/Kontakter/Numerisk blok og luppen.
   - Liquid Glass-tryk: tasten skalerer 1,19, får et lyst overlay og strækker sig mod fingeren ved træk.
2. **Lommeregner:**
   - Port motoren i `src/calc/*` (calculator, format) og UI'et fra `src/calcui.js`/`styles.css`. Dansk talformat, historik og menu.
3. **Scanning:**
   - Kameraet er usynligt, med "Vis søger" som valg.
   - Start/stop: tryk over nummeret på blokken eller mellem de to runde knapper i lommeregneren.
   - Brug Vision med `recognitionLevel .accurate` og `usesLanguageCorrection = false`. Vælg den højeste/største tal-linje, så klokken i statuslinjen ignoreres (se `pickLine` i `src/ocr.js`).
   - Bekræftelse 1×/2×, mindst antal cifre, timeout og region (midten/hele).
   - Hurtig accept, hvis topkandidaten er en kendt person eller et eget navn.
   - Kort haptisk feedback, når et tal er fundet.
4. **T9-afkodning:**
   - Port `src/t9.js` præcist, inkl. pointsystemet: egne > kendte > fornavn+efternavn > 25.000 ord. 0 og 1 er mellemrum.
   - Æ og Å giver 2, Ø giver 6.
   - Data: generér en JSON-fil i bundlen fra `data/*.txt`. Det kan ske med et lille script, eller ved at konvertere `src/words.js`.
5. **Peek:**
   - På blokken står navnet i fanernes tekst: fornavn, efternavn og 3. fane = fødselsdag/mål. Alternativt kan det stå som svag tekst over home-baren.
   - I lommeregneren står det som svag tekst mellem ikonerne øverst.
   - Styrke 1–3 og alternativer.
   - Peek-skærm via ✱: sort/hvid, 2 sek. eller til tryk.
   - Vis det scannede tal i nummerfeltet.
6. **Regnemetode (`src/force.js`):**
   - Formlen er y − x = a. x er det scannede tal, y kan være fødselsdag, dato i dag, klokken + n minutter eller et fast tal, og a er mit tal.
   - Datoformater: DDMMÅÅ, DDMMÅÅÅÅ, ÅÅÅÅMMDD og DDMM.
   - a sættes i nummerfeltet eller i lommeregneren.
   - Hvis a er negativt, vises |a| og "−" i peeket. Brug store tal (Decimal eller strenge, ikke Int).
   - Fødselsdage fra `data/foedselsdage.txt`. Egne navne kan skrives som "Navn | 14.06.1946".
7. **Hurtigt skift:** luppen skifter til lommeregneren, og et hold på uret skifter tilbage til blokken.
8. **Hemmeligt panel:**
   - Åbnes med 5 hurtige tryk øverst til højre.
   - Samme sektioner som webappen: Peek, Regnemetode, Kamera, Ordbog med test-felter, og Andet med log.
   - Indstillinger gemmes i `UserDefaults`.
9. **Debug-visning:**
   - Viser de sidste 15 billeder med en grøn boks og en label om det læste tal og orange bokse om de andre linjer.
   - Titlen er "DEBUG: tal". Derunder tid, varighed og sikkerhed.
   - Knapper: scan, slet, luk. Man kan swipe mellem billederne.
10. Skjul statuslinjen ikke. Mørk tilstand. Kun portræt.

## Build (GitHub Actions) – kort og hurtigt
- Workflow `.github/workflows/ios.yml` kører på `macos-latest`, ved push til `ios/**` og manuelt.
- Trin: `brew install xcodegen` → `xcodegen` → `xcodebuild archive` med:
  - Release-konfiguration
  - `-sdk iphoneos`
  - `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""`
- Pak `.app` i `Payload/` og zip den til `NumberReader.ipa`. SideStore signerer selv.
- Ingen unit tests i buildet, eller kun én hurtig test af T9/regnemetoden. Brug cache, hvor det giver mening.
- Opret en GitHub Release med tag `v<version>` (version fra `project.yml` + `github.run_number` som build-nummer), og vedhæft IPA'en.

## SideStore source
- Læg `sidestore/apps.json` i repoet (AltStore/SideStore source-format):
  - `name`, `identifier`
  - `apps[]` med `bundleIdentifier`, `name`, `developerName`, `iconURL`, `localizationDescription`
  - `versions[]` med `version`, `date`, `downloadURL`, `size`, `minOSVersion`
- Workflowet opdaterer automatisk `apps.json` med den nye version, IPA-størrelsen og release-URL'en, og committer den.
- Source-URL: `https://raw.githubusercontent.com/Thyxo/number-reader/main/sidestore/apps.json`. Skriv den i README.

## Leverance
1. Byg det hele, push, og få workflowet til at gå grønt. Ret fejl i loggen, indtil det gør.
2. Fortæl mig:
   - source-linket til SideStore
   - hvordan jeg tilføjer det
   - hvilke funktioner der eventuelt afviger fra webappen
3. Spørg, før du merger til `main`.
