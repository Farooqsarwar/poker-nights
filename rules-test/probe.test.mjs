import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { after, before, describe, it } from 'node:test';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, setDoc, writeBatch, serverTimestamp, Timestamp } from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const rules = readFileSync(join(here, '..', 'firestore.rules'), 'utf8');
const host = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:9199';
const [hostname, portStr] = host.split(':');

let testEnv;
before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'poker-night-rules-test',
    firestore: { rules, host: hostname, port: Number(portStr) },
  });
});
after(async () => { await testEnv?.cleanup(); });

const raw = async (p) => p.then(() => 'ok', (e) => 'DENIED: ' + String(e.message).replace(/\s+/g, ' ').slice(0, 300));

describe('probe3', () => {
  it('batch with member', async () => {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const d = ctx.firestore();
      await d.doc('groups/gB').set({ name: 'B', joinCode: 'JOIN-B', ownerId: 'boss' });
      await d.doc('groups/gB/members/boss').set({ name: 'Boss', role: 'admin' });
      await d.doc('groups/gB/members/bob').set({ name: 'Bob', role: 'member' });
    });
    const db = testEnv.authenticatedContext('bob').firestore();
    const b = writeBatch(db);
    b.set(doc(db, 'rate_limits', 'chat-bob'), { time: serverTimestamp() });
    b.set(doc(db, 'groups', 'gB', 'chat', 'm1'), { authorId: 'bob', text: 'hi' });
    console.log('E2 =', await raw(b.commit()));

    // notification
    const b2 = writeBatch(db);
    b2.set(doc(db, 'rate_limits', 'notify-bob'), { time: serverTimestamp() });
    b2.set(doc(db, 'groups', 'gB', 'notifications', 'n1'), {
      title: 't', body: 'b', type: 'game', createdAt: Timestamp.now(),
    });
    console.log('E3 =', await raw(b2.commit()));

    // poll vote
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('groups/gB/polls/p1').set({ closed: false, votes: {} });
    });
    const b3 = writeBatch(db);
    b3.set(doc(db, 'rate_limits', 'vote-bob'), { time: serverTimestamp() });
    b3.set(doc(db, 'groups', 'gB', 'polls', 'p1'), { closed: false, votes: { bob: 'yes' } });
    console.log('E4 =', await raw(b3.commit()));

    // guest claim (bob not member of gA)
    const b4 = writeBatch(db);
    b4.set(doc(db, 'rate_limits', 'guestclaim-bob'), { time: serverTimestamp() });
    b4.set(doc(db, 'requests', 'g1', 'items', 'guestCheckIn-boss-1'), {
      kind: 'guestCheckIn', gid: 'gA', ownerUid: 'bob',
    });
    console.log('E5 =', await raw(b4.commit()));

    // report: createdAt must equal request.time
    const b5 = writeBatch(db);
    b5.set(doc(db, 'groups', 'gB', 'reports', 'm1_bob'), {
      messageId: 'm1', authorId: 'boss', reporterId: 'bob',
      excerpt: 'x', createdAt: serverTimestamp(),
    });
    console.log('E6 =', await raw(b5.commit()));
  });

  it('privateData admin write + outsider denies', async () => {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const d = ctx.firestore();
      await d.doc('groups/gB').set({ name: 'B', joinCode: 'JOIN-B', ownerId: 'boss' });
      await d.doc('groups/gB/members/boss').set({ name: 'Boss', role: 'admin' });
      await d.doc('groups/gB/members/bob').set({ name: 'Bob', role: 'member' });
      await d.doc('groups/gB/games/g1').set({ structure: { grossCollected: 1000 }, settings: {} });
    });
    const boss = testEnv.authenticatedContext('boss').firestore();
    console.log('G1 privateData admin =', await raw(setDoc(doc(boss, 'groups', 'gB', 'games', 'g1', 'admin', 'privateData'), {
      organizerPct: 10, organizerAmount: 100, auditHistory: ['x'],
    })));
    const bob = testEnv.authenticatedContext('bob').firestore();
    console.log('G2 privateData member =', await raw(setDoc(doc(bob, 'groups', 'gB', 'games', 'g1', 'admin', 'privateData'), { organizerPct: 5 })));
  });
});
