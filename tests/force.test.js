import test from 'node:test';
import assert from 'node:assert/strict';
import { solve, target, parseDate, fmtDate } from '../src/force.js';

test('y − x = a', () => {
  assert.deepEqual(solve('54652736', '99999999'), { a: '45347263', neg: false });
  assert.equal(BigInt('54652736') + BigInt(solve('54652736', '99999999').a), 99999999n);
});
test('negativ: x − a = y', () => {
  const r = solve('3662538786', '140646');
  assert.equal(r.neg, true);
  assert.equal(BigInt('3662538786') - BigInt(r.a), 140646n);
});
test('datoer', () => {
  assert.deepEqual(parseDate('14.06.1946'), { d: 14, m: 6, y: 1946 });
  assert.equal(fmtDate(parseDate('1946-06-14'), 'ddmmyy'), '140646');
  assert.equal(fmtDate(parseDate('1946-06-14'), 'ddmmyyyy'), '14061946');
  assert.equal(fmtDate(parseDate('1946-06-14'), 'yyyymmdd'), '19460614');
});
test('mål', () => {
  const now = new Date(2026, 10, 12, 9, 58);
  assert.equal(target({ src: 'today', now }).y, '121126');
  assert.equal(target({ src: 'clock', clockAdd: 5, now }).y, '1003');
  assert.equal(target({ src: 'fixed', fixed: '2100' }).y, '2100');
  assert.equal(target({ src: 'birthday', name: 'Bedstemor', custom: ['Bedstemor | 3.4.1950'], fmt: 'ddmmyyyy' }).y, '03041950');
  assert.equal(target({ src: 'birthday', name: 'Ukendt Person', fixed: '777', now }).y, '777');
});
