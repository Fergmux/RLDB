// Privileged admin-tool operations against the Firestore emulator (Admin SDK bypasses rules, so
// these are tested separately from the client rules): load raw submissions, reconcile and write
// canonical games idempotently, upgrade on a later agreeing report, and delete one uid's data.
//   cd firebase && npx firebase emulators:exec --only firestore,auth --project rldb-b5593 "node --test tests/admin.test.js"
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8180';
const admin = require('firebase-admin');
const { runReconcile, deleteUid, purgeUid, loadSubmissions, playerStats, deleteStats } = require('../tools/rldb-admin');
const zlib = require('node:zlib');
const fx = require('../tools/fixtures/basic');

admin.initializeApp({ projectId: 'rldb-b5593' }, 'admin-test');
const db = admin.app('admin-test').firestore();

async function clear() {
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/rldb-b5593/databases/(default)/documents`, { method: 'DELETE' });
}

async function seed(subs) {
  for (const s of subs) {
    const data = { ...s.data, received_at: admin.firestore.Timestamp.fromMillis(s.received_at || s.data.created_at) };
    await db.collection('users').doc(s.uid).collection('submissions').doc(s.id).set(data);
  }
}

test.beforeEach(clear);
test.after(async () => { await clear(); await admin.app('admin-test').delete(); });

test('reconcile --write stores canonical games once and is idempotent', async () => {
  await seed(fx.submissions);
  const raws = await loadSubmissions(db);
  assert.equal(raws.length, fx.submissions.length);
  const first = await runReconcile(db, raws, { env: 'production', write: true, cat: fx.catalog });
  assert.equal(first.written, 5);
  const g1 = (await db.collection('canonical_games').doc('production__G1').get()).data();
  assert.equal(g1.status, 'verified');
  const again = await runReconcile(db, await loadSubmissions(db), { env: 'production', write: true, cat: fx.catalog });
  assert.equal(again.written, 0);
  assert.equal(again.unchanged, 5);
  const agg = (await db.collection('aggregates').doc('production__default').get()).data();
  assert.equal(JSON.parse(agg.body).eligible_games, 2);
});

test('a later agreeing report upgrades the stored game without adding a result', async () => {
  await seed(fx.submissions);
  await runReconcile(db, await loadSubmissions(db), { env: 'production', write: true, cat: fx.catalog });
  await seed([fx.lateAgreeG3]);
  const res = await runReconcile(db, await loadSubmissions(db), { env: 'production', write: true, cat: fx.catalog });
  assert.equal(res.written, 1);
  assert.equal((await db.collection('canonical_games').doc('production__G3').get()).data().status, 'verified');
  assert.equal(res.metrics.eligible_games, 2);
});

test('delete-uid removes that uid only, and a rebuild drops its canonical games', async () => {
  await seed(fx.submissions);
  await runReconcile(db, await loadSubmissions(db), { env: 'production', write: true, cat: fx.catalog });
  assert.equal(await deleteUid(db, 'uC', false), 1);
  assert.equal((await db.collection('users').doc('uC').collection('submissions').get()).size, 1);
  assert.equal(await deleteUid(db, 'uC', true), 1);
  assert.equal((await db.collection('users').doc('uC').collection('submissions').get()).size, 0);
  assert.ok((await db.collection('users').doc('uA').collection('submissions').get()).size > 0);
  const res = await runReconcile(db, await loadSubmissions(db), { env: 'production', write: true, cat: fx.catalog });
  assert.equal(res.deleted, 1);
  assert.equal((await db.collection('canonical_games').doc('production__G3').get()).exists, false);
});

test('purge-uid erases submissions, the auth account, filtered aggregates and rebuilds every env', async () => {
  const auth = admin.app('admin-test').auth();
  await auth.createUser({ uid: 'uC' }).catch(() => {});
  await seed(fx.submissions);
  await runReconcile(db, await loadSubmissions(db), { env: 'production', write: true, cat: fx.catalog });
  await runReconcile(db, await loadSubmissions(db), { env: 'production', write: true, cat: fx.catalog,
    filter: { modes: ['lan', 'steam'], statuses: ['verified', 'provisional'], player: 'u:uC' } });
  assert.equal((await db.collection('aggregates').get()).size, 2);
  const r = await purgeUid(db, 'uC', { auth, cat: fx.catalog });
  assert.equal(r.submissions, 1);
  assert.equal(r.auth_deleted, true);
  assert.equal(r.aggregates_deleted, 1);
  assert.ok(r.rebuilt.includes('production'));
  await assert.rejects(auth.getUser('uC'));
  assert.equal((await db.collection('canonical_games').doc('production__G3').get()).exists, false);
  const agg = (await db.collection('aggregates').doc('production__default').get()).data();
  assert.ok(!agg.body.includes('u:uC'));
  assert.ok((await db.collection('users').doc('uA').collection('submissions').get()).size > 0);
  await assert.rejects(purgeUid(db, '../x', { cat: fx.catalog }));
});


// ------------------------------------------------------------------ cloud statistics (C1)

const SH = '0123456789abcdef0123456789abcdef';

async function seedStats(uid, hash, duels) {
  const rec = { version: 2, duels, series: [], devices: {} };
  const body = zlib.gzipSync(Buffer.from(JSON.stringify(rec))).toString('base64');
  await db.collection('stats_links').doc(uid).set({ steam_hash: hash, linked_at: admin.firestore.Timestamp.now() });
  await db.collection('player_stats').doc(hash).set({ schema_version: 1, steam_hash: hash, uid, rev: 1, enc: 'gzip64',
    raw_len: body.length, updated_at: admin.firestore.Timestamp.now(), body });
}

test('player-stats lists and decodes the players\' cloud statistics', async () => {
  await seedStats('uS', SH, [{ id: 'a', t: 1, won: true, ms: 600000, tms: 200000, tn: 5 }, { id: 'b', t: 2, won: false, ms: 300000 }]);
  const list = await playerStats(db);
  assert.equal(list.length, 1);
  assert.equal(list[0].duels, 2);
  assert.equal(list[0].win_rate, 0.5);
  assert.equal(list[0].avg_duel_ms, 450000);
  assert.equal(list[0].avg_own_turn_ms, 40000);
  const one = await playerStats(db, SH);
  assert.equal(one.record.duels.length, 2);
  assert.equal(await playerStats(db, 'f'.repeat(32)), null);
  await assert.rejects(playerStats(db, '../x'));
});

test('an undecodable cloud copy is reported, not thrown', async () => {
  await db.collection('player_stats').doc(SH).set({ uid: 'u', rev: 1, enc: 'gzip64', body: 'bm90IGd6aXA=' });
  const list = await playerStats(db);
  assert.equal(list[0].decodable, false);
});

test('delete-stats erases the record and every link to it; purge-uid includes them', async () => {
  await seedStats('uS', SH, [{ id: 'a', t: 1, won: true }]);
  await db.collection('stats_links').doc('uT').set({ steam_hash: SH, linked_at: admin.firestore.Timestamp.now() });
  assert.deepEqual(await deleteStats(db, SH), { stats_deleted: true, links_deleted: 2 });
  assert.equal((await db.collection('player_stats').doc(SH).get()).exists, false);
  await seedStats('uC', SH, [{ id: 'a', t: 1, won: true }]);
  await seed(fx.submissions);
  const r = await purgeUid(db, 'uC', { cat: fx.catalog });
  assert.equal(r.stats_deleted, true);
  assert.equal(r.links_deleted, 1);
  assert.equal((await db.collection('stats_links').doc('uC').get()).exists, false);
  assert.equal((await db.collection('player_stats').doc(SH).get()).exists, false);
});
