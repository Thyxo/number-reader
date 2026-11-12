import { parseDisplay } from './format.js';

export const DEFAULTS = {
  enabled: false,        // force til/fra
  display: 'typed',      // typed = regnestykket viser præcis det tastede, kun resultatet tvinges
                         // stream = talstrøm: sidste tal udskiftes, så regnestykket passer
  targetMode: 'fixed',   // fixed | tomorrow | today | time
  target: '2100',        // bruges når targetMode = fixed
  timeOffset: 0,         // minutter lagt til ved targetMode = time
  trigger: 'nth',        // nth | afterEquals | manual
  nth: 3,                // hvilket tal i regnestykket der streames (1-baseret)
  uses: 3,               // antal ramte før force slår sig selv fra (0 = aldrig)
  lateFix: true,         // ret sidste tal ved "=" hvis talstrømmen ikke nåede at køre
  allowSwap: true,       // må motoren skifte operator, hvis det er eneste troværdige løsning
  opHighlight: true,     // markér valgt operator (hvid knap, orange tegn)
  indicator: true,       // diskret prik når force er klar
  vAdjust: 0,            // lodret finjustering af tastaturet i px (positiv = højere op)
  link: '',              // rum-kode til Noter+ (samme kode i begge apps)
  linkIn: true,          // modtag mål (navn/tal) fra Noter+
  linkOut: true,         // send resultater og egne mål til Noter+
  forceAt: 0,
  googleIn: true,        // modtag søgeord fra Fake Google (omsættes med src/cryptext.js)
  googleAt: 0,           // sidst brugte google.at – samme ord bruges aldrig to gange
  lastTarget: null,      // {digits, name, t} – til at undgå dobbelt nulstilling            // tidsstempel for sidst modtagne/sendte mål
  targetSrc: '',         // hvor målet kom fra (fx "Fra Noter+: Lise"); tom = tastet i panelet
};

const pad = (n) => String(n).padStart(2, '0');

export function ddmmyy(d) {
  return pad(d.getDate()) + pad(d.getMonth() + 1) + pad(d.getFullYear() % 100);
}

export function resolveTarget(s, now = new Date()) {
  switch (s.targetMode) {
    case 'tomorrow': {
      const d = new Date(now); d.setDate(d.getDate() + 1);
      return Number(ddmmyy(d));
    }
    case 'today': return Number(ddmmyy(now));
    case 'time': {
      const d = new Date(now.getTime() + (Number(s.timeOffset) || 0) * 60000);
      return Number(pad(d.getHours()) + pad(d.getMinutes()));
    }
    default: {
      const v = parseDisplay(s.target);
      return Number.isFinite(v) ? v : 0;
    }
  }
}

const KEY = 'cp.settings.v1';

export function loadSettings() {
  try {
    const raw = localStorage.getItem(KEY);
    return raw ? { ...DEFAULTS, ...JSON.parse(raw) } : { ...DEFAULTS };
  } catch {
    return { ...DEFAULTS };
  }
}

export function saveSettings(s) {
  try { localStorage.setItem(KEY, JSON.stringify(s)); } catch { /* privat tilstand */ }
}
