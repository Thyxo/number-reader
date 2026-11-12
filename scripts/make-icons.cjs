// Laver icons/*.png (grønt Telefon-ikon) med den forudinstallerede Chromium.  node scripts/make-icons.cjs
const { chromium } = require('playwright');
(async () => {
const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#65f57f"/><stop offset="1" stop-color="#0bbd2b"/></linearGradient></defs>
<rect width="1024" height="1024" fill="url(#g)"/>
<g transform="translate(512 512) scale(25) translate(-12 -12)">
<path fill="#fff" d="M6.6 10.8c1.4 2.8 3.8 5.1 6.6 6.6l2.2-2.2c.3-.3.7-.4 1-.2 1.1.4 2.3.6 3.6.6.6 0 1 .4 1 1V20c0 .6-.4 1-1 1C10.6 21 3 13.4 3 4c0-.6.4-1 1-1h3.5c.6 0 1 .4 1 1 0 1.3.2 2.5.6 3.6.1.3 0 .7-.2 1z"/></g></svg>`;
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1024, height: 1024 } });
await p.setContent(`<html><body style="margin:0">${svg}</body></html>`);
await p.screenshot({ path: 'icons/src-1024.png' });
await b.close();
})();
