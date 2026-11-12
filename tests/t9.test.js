import test from 'node:test';
import assert from 'node:assert/strict';
import { buildIndex, decode, toDigits } from '../src/t9.js';
import { pickDigits } from '../src/ocr.js';

const idx = buildIndex();
const top = (w) => decode(idx, toDigits(w), 3)[0]?.text;

test('bogstaver → cifre', () => {
  assert.equal(toDigits('Kim Larsen'), '546527736');
  assert.equal(toDigits('Søren'), '76736');
  assert.equal(toDigits('Æble'), '2253');
  assert.equal(toDigits('Åge'), '243');
});

test('kendte personer vinder', () => {
  for (const n of ['Kim Larsen', 'Mads Mikkelsen', 'Taylor Swift', 'Messi', 'Ronaldo', 'Mette Frederiksen', 'Elvis Presley', 'Einstein', 'Bamse', 'Michael Jackson', 'Caroline Wozniacki']) {
    assert.equal(top(n).toLowerCase(), n.toLowerCase(), n);
  }
});

test('fornavn + efternavn', () => {
  assert.equal(top('Mette Jensen'), 'Mette Jensen');
  assert.equal(top('Lars Nielsen'), 'Lars Nielsen');
});

test('0 og 1 er mellemrum', () => {
  assert.equal(decode(idx, toDigits('Kim') + '0' + toDigits('Larsen'))[0].text, 'Kim Larsen');
  assert.equal(decode(idx, toDigits('Hej') + '1' + toDigits('Mor'))[0].text, 'Hej Mor');
});

test('egne navne går forrest', () => {
  const i2 = buildIndex({ custom: ['Fido'] });
  assert.equal(decode(i2, toDigits('Fido'))[0].text, 'Fido');
});

test('almindelige ord', () => {
  for (const w of ['Hund', 'Kat', 'Hus', 'Bil', 'København']) {
    const r = decode(idx, toDigits(w), 3).map((c) => c.text.toLowerCase());
    assert.ok(r.includes(w.toLowerCase()), `${w}: ${r}`);
  }
});

test('OCR-tekst → cifre', () => {
  assert.equal(pickDigits('54 65 27 736\n'), '546527736');
  assert.equal(pickDigits('Tilføj nummer\n6237645535736'), '6237645535736');
  assert.equal(pickDigits('ab 12'), '');
  assert.equal(pickDigits('x 22673 y\n1'), '22673');
});
