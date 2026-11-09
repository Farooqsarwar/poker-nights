import { readFileSync } from 'node:fs';
import test from 'node:test';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  collection,
  doc,
  getDoc,
  getDocsFromServer,
  orderBy,
  query,
  setDoc,
  where,
} from 'firebase/firestore';

const env = await initializeTestEnvironment({
  projectId: 'poker-night-rules-audit2',
  firestore: {
    host: '127.0.0.1',
    port: 9199,
    rules: readFileSync('../firestore.rules', 'utf8'),
  },
});

const clean = (id, extra = {}) => ({
  name: id,
  rebuys: 0,
  reEntries: 0,
  hasAddOn: false,
  knockouts: 0,
  ...extra,
});

const players = (n, dirtyIndex = -1, dirty = { rebuys: 1 }) => {
  const out = {};
  for (let i = 0; i < n; i++) {
    const id = `p${String(i).padStart(2, '0')}`;
    out[id] = clean(id, i === dirtyIndex ? dirty : {});
  }
  return out;
};

const game = (fieldPlayers, extra = {}) => ({
  settings: { date: '2026-11-09' },
  players: fieldPlayers,
  playersScrubbed: true,
  payments: [],
  ...extra,
});

await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'groups/g1'), {
    name: 'G',
    ownerId: 'admin',
    joinCode: 'ABC123',
  });
  await setDoc(doc(db, 'groups/g1/members/admin'), { name: 'A', role: 'admin' });
  await setDoc(doc(db, 'groups/g1/members/member'), { name: 'M', role: 'member' });
  await setDoc(doc(db, 'groups/g1/games/good10'), game(players(10)));
  await setDoc(doc(db, 'groups/g1/games/dirty10'), game(players(10, 9)));
  await setDoc(
    doc(db, 'groups/g1/games/badpay'),
    game(players(2), { payments: [{ playerId: 'p00', amount: 15 }] }),
  );
  const missing = game(players(2));
  delete missing.payments;
  await setDoc(doc(db, 'groups/g1/games/missingpay'), missing);
});

const memberDb = env.authenticatedContext('member').firestore();
const adminDb = env.authenticatedContext('admin').firestore();

const safeQuery = () =>
  query(
    collection(memberDb, 'groups/g1/games'),
    where('playersScrubbed', '==', true),
    where('payments', '==', []),
    orderBy('settings.date', 'desc'),
  );

const unsafeQuery = () =>
  query(
    collection(memberDb, 'groups/g1/games'),
    where('playersScrubbed', '==', true),
    orderBy('settings.date', 'desc'),
  );

test('member can get a clean 10-player game', async () => {
  await assertSucceeds(getDoc(doc(memberDb, 'groups/g1/games/good10')));
});

test('member can still get a 10-player game with a dirty last player', async () => {
  await assertSucceeds(getDoc(doc(memberDb, 'groups/g1/games/dirty10')));
});

test('member cannot get a game with payments', async () => {
  await assertFails(getDoc(doc(memberDb, 'groups/g1/games/badpay')));
});

test('app query excludes payments docs and includes dirty counters', async () => {
  const snap = await getDocsFromServer(safeQuery());
  console.log('safe ids:', JSON.stringify(snap.docs.map((d) => d.id)));
});

test('unfiltered member query still returns a payments doc', async () => {
  try {
    const snap = await getDocsFromServer(unsafeQuery());
    console.log('unsafe ids:', JSON.stringify(snap.docs.map((d) => d.id)));
  } catch (e) {
    console.log('unsafe query denied:', String(e).slice(0, 120));
  }
});

test('safe query excludes a legacy doc with no payments field', async () => {
  const snap = await getDocsFromServer(safeQuery());
  if (snap.docs.some((d) => d.id === 'missingpay')) {
    throw new Error('missingpay unexpectedly included');
  }
});

test('admin can write 10 clean players', async () => {
  await assertSucceeds(
    setDoc(doc(adminDb, 'groups/g1/games/w10c'), game(players(10))),
  );
});

test('admin can write 10 players with a dirty last player', async () => {
  await assertSucceeds(
    setDoc(doc(adminDb, 'groups/g1/games/w10d'), game(players(10, 9))),
  );
});

test('admin is blocked when the first player is dirty', async () => {
  await assertFails(
    setDoc(doc(adminDb, 'groups/g1/games/w10f'), game(players(10, 0))),
  );
});

test('admin can write 30 clean players', async () => {
  await assertSucceeds(
    setDoc(doc(adminDb, 'groups/g1/games/w30c'), game(players(30))),
  );
});

test('admin can write 30 players with a dirty last player', async () => {
  await assertSucceeds(
    setDoc(doc(adminDb, 'groups/g1/games/w30d'), game(players(30, 29))),
  );
});

test.after(async () => {
  await env.cleanup();
});
