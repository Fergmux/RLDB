// Privileged admin-tool operations against the Firestore emulator (Admin SDK bypasses rules, so
// these are tested separately from the client rules): load raw submissions, reconcile and write
// canonical games idempotently, upgrade on a later agreeing report, and delete one uid's data.
//   cd firebase && npx firebase emulators:exec --only firestore,auth --project rldb-b5593 "node --test tests/admin.test.js"
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8180';
const admin = require('firebase-admin');
const { runReconcile, deleteUid, loadSubmissions } = require('../tools/rldb-admin');
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
