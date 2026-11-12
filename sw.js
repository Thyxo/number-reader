// Service worker: appen virker offline. Hæv VERSION ved ændringer.
// vendor/ (OCR-motor, ca. 11 MB) caches første gang den hentes – derefter offline.
const VERSION = 'numberreader-v6';
const VENDOR = 'numberreader-vendor-v1';
const ASSETS = [
  './', 'index.html', 'styles.css', 'pad.css', 'manifest.webmanifest',
  'src/app.js', 'src/calcui.js', 'src/ocr.js', 'src/t9.js', 'src/words.js', 'src/force.js',
  'src/calc/calculator.js', 'src/calc/force.js', 'src/calc/format.js', 'src/calc/settings.js',
  'icons/apple-touch-icon.png', 'icons/icon-192.png', 'icons/icon-512.png', 'icons/maskable-512.png', 'icons/favicon-32.png',
  ...['back', 'pct', 'pm', 'comma', 'div', 'mul', 'sub', 'add', 'eq', 'clock', 'calc',
    'm-check', 'm-basic', 'm-sci', 'm-notes', 'm-conv'].map((g) => `glyphs/${g}.png`),
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(VERSION).then((c) => c.addAll(ASSETS)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== VERSION && k !== VENDOR).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  const url = new URL(req.url);
  if (req.method !== 'GET' || url.origin !== location.origin) return;

  // OCR-filer ændrer sig aldrig: cache først
  if (url.pathname.includes('/vendor/')) {
    e.respondWith((async () => {
      const cache = await caches.open(VENDOR);
      const hit = await cache.match(req, { ignoreSearch: true });
      if (hit) return hit;
      const res = await fetch(req);
      if (res.ok) cache.put(req, res.clone());
      return res;
    })());
    return;
  }

  // Resten: netværk først (ny version slår igennem), cache offline eller efter 2,5 sek.
  const key = req.mode === 'navigate' ? 'index.html' : req;
  e.respondWith((async () => {
    const cache = await caches.open(VERSION);
    const network = fetch(req).then((res) => {
      if (res.ok && res.type === 'basic') cache.put(key, res.clone());
      return res;
    });
    const timeout = new Promise((r) => setTimeout(r, 2500));
    try {
      const res = await Promise.race([network, timeout]);
      if (res) return res;
    } catch { /* offline */ }
    const cached = await cache.match(key, { ignoreSearch: true });
    return cached || network;
  })());
});
