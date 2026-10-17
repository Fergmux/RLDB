// Firestore security-rules tests for RLDB telemetry (schema v1). Run through the emulators:
//   cd firebase && npx firebase emulators:exec --only firestore,auth --project rldb-b5593 "node --test tests/"
// Covers: unauthenticated access, cross-user reads/writes, spoofed owner UIDs, schema and size
// violations, updates/deletes, canonical/aggregate writes, client-declared verification, and
// accepted valid submissions. A second suite drives the exact REST calls the Godot client makes
// (anonymous sign-up on the Auth emulator, documents:commit with a REQUEST_TIME transform and an
// exists:false precondition) so the client contract is proven, not just the JS SDK path.
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment, assertFails, assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  doc, setDoc, getDoc, getDocs, updateDoc, deleteDoc, collection, collectionGroup, serverTimestamp,
} = require('firebase/firestore');

const PROJECT = 'rldb-b5593';
const FS_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8180';
const AUTH_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9199';
const HASH = 'a'.repeat(64);

let env;

function submission(uid, kind, over = {}) {
  return Object.assign({
    schema_version: 1, kind, env: 'test', build: '0.9.0-test', content_hash: HASH, mode: 'bot',
    uid, created_at: Date.now(), seq: 1, received_at: serverTimestamp(), body: '{"x":1}',
  }, over);
}

test.before(async () => {
  const [host, port] = FS_HOST.split(':');
  env = await initializeTestEnvironment({
    projectId: PROJECT,
    firestore: {
      host, port: Number(port),
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });
});

test.after(async () => { if (env) await env.cleanup(); });
test.beforeEach(async () => { await env.clearFirestore(); });

const alice = () => env.authenticatedContext('alice', { firebase: { sign_in_provider: 'anonymous' } }).firestore();
const bob = () => env.authenticatedContext('bob', { firebase: { sign_in_provider: 'anonymous' } }).firestore();
const anon = () => env.unauthenticatedContext().firestore();

async function seed(p, data) {
  await env.withSecurityRulesDisabled(async (ctx) => { await setDoc(doc(ctx.firestore(), p), data); });
}

test('valid owner submissions of every kind are accepted', async () => {
  for (const kind of ['profile', 'session', 'draft', 'reward', 'game', 'gclient', 'series']) {
    await assertSucceeds(setDoc(doc(alice(), `users/alice/submissions/${kind}_abc123`), submission('alice', kind)));
  }
});

test('every environment label and mode is accepted', async () => {
  let i = 0;
  for (const e of ['playtest', 'production', 'dev', 'test']) {
    for (const m of ['none', 'local', 'bot', 'lan', 'steam']) {
      await assertSucceeds(setDoc(doc(alice(), `users/alice/submissions/game_e${i++}`), submission('alice', 'game', { env: e, mode: m })));
    }
  }
});

test('unauthenticated clients cannot read or write anything', async () => {
  await seed('users/alice/submissions/game_x1', { kind: 'game' });
  await assertFails(setDoc(doc(anon(), 'users/alice/submissions/game_x2'), submission('alice', 'game')));
  await assertFails(getDoc(doc(anon(), 'users/alice/submissions/game_x1')));
  await assertFails(getDocs(collection(anon(), 'users/alice/submissions')));
  await assertFails(setDoc(doc(anon(), 'canonical_games/test_g1'), { status: 'verified' }));
});

test('cross-user writes are denied, including a spoofed uid in the body', async () => {
  await assertFails(setDoc(doc(bob(), 'users/alice/submissions/game_x1'), submission('alice', 'game')));
  await assertFails(setDoc(doc(bob(), 'users/alice/submissions/game_x2'), submission('bob', 'game')));
  // Own path but the body claims another owner.
  await assertFails(setDoc(doc(bob(), 'users/bob/submissions/game_x3'), submission('alice', 'game')));
});

test('cross-user reads are denied; the owner may get but never list its own documents', async () => {
  await seed('users/alice/submissions/game_x1', { kind: 'game' });
  await assertFails(getDoc(doc(bob(), 'users/alice/submissions/game_x1')));
  await assertFails(getDocs(collection(bob(), 'users/alice/submissions')));
  await assertFails(getDocs(collectionGroup(bob(), 'submissions')));
  await assertSucceeds(getDoc(doc(alice(), 'users/alice/submissions/game_x1')));
  await assertFails(getDocs(collection(alice(), 'users/alice/submissions')));
  await assertFails(getDoc(doc(alice(), 'users/alice')));
});

test('submissions are immutable: update, overwrite and delete are denied', async () => {
  const ref = doc(alice(), 'users/alice/submissions/game_x1');
  await assertSucceeds(setDoc(ref, submission('alice', 'game')));
  await assertFails(updateDoc(ref, { body: '{"x":2}' }));
  await assertFails(setDoc(ref, submission('alice', 'game', { body: '{"x":3}' })));
  await assertFails(deleteDoc(ref));
});

test('oversized and malformed payloads are denied', async () => {
  const db = alice();
  const p = (id) => doc(db, `users/alice/submissions/${id}`);
  await assertSucceeds(setDoc(p('game_edge'), submission('alice', 'game', { body: 'x'.repeat(200000) })));
  await assertFails(setDoc(p('game_big'), submission('alice', 'game', { body: 'x'.repeat(200001) })));
  await assertFails(setDoc(p('game_v2'), submission('alice', 'game', { schema_version: 2 })));
  await assertFails(setDoc(p('game_env'), submission('alice', 'game', { env: 'staging' })));
  await assertFails(setDoc(p('game_mode'), submission('alice', 'game', { mode: 'tutorial' })));
  await assertFails(setDoc(p('game_hash'), submission('alice', 'game', { content_hash: 'XYZ' })));
  await assertFails(setDoc(p('game_build'), submission('alice', 'game', { build: 'b'.repeat(49) })));
  await assertFails(setDoc(p('game_ts'), submission('alice', 'game', { received_at: new Date(0) })));
  await assertFails(setDoc(p('game_seq'), submission('alice', 'game', { seq: '1' })));
  await assertFails(setDoc(p('game_body'), submission('alice', 'game', { body: { x: 1 } })));
  // Unknown or missing fields.
  await assertFails(setDoc(p('game_extra'), submission('alice', 'game', { verified: true })));
  const missing = submission('alice', 'game');
  delete missing.seq;
  await assertFails(setDoc(p('game_missing'), missing));
  // The document id must start with the declared kind; unknown kinds are refused.
  await assertFails(setDoc(p('series_mismatch'), submission('alice', 'game')));
  await assertFails(setDoc(p('admin_x'), submission('alice', 'admin')));
  await assertFails(setDoc(p('game_bad id'), submission('alice', 'game')));
});

test('clients cannot write canonical games, aggregates, admin data or declare verification', async () => {
  for (const db of [alice(), bob()]) {
    await assertFails(setDoc(doc(db, 'canonical_games/production_g1'), { status: 'verified' }));
    await assertFails(setDoc(doc(db, 'aggregates/production_cards'), { plays: 1 }));
    await assertFails(setDoc(doc(db, 'admin/state'), { x: 1 }));
    await assertFails(setDoc(doc(db, 'users/alice'), { verified: true }));
    await assertFails(getDoc(doc(db, 'canonical_games/production_g1')));
    await assertFails(getDoc(doc(db, 'aggregates/production_cards')));
  }
  await assertFails(setDoc(doc(alice(), 'users/alice/submissions/game_v'), submission('alice', 'game', { status: 'verified' })));
  await assertFails(setDoc(doc(alice(), 'users/alice/other/game_x'), submission('alice', 'game')));
});

// ------------------------------------------------------------------ REST contract (Godot client)

async function signUp() {
  const r = await fetch(`http://${AUTH_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`,
    { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ returnSecureToken: true }) });
  assert.equal(r.status, 200);
  return r.json();
}

function restDoc(uid, docId, over = {}) {
  const f = Object.assign({
    schema_version: { integerValue: '1' }, kind: { stringValue: docId.split('_')[0] }, env: { stringValue: 'test' },
    build: { stringValue: '0.9.0-test' }, content_hash: { stringValue: HASH }, mode: { stringValue: 'bot' },
    uid: { stringValue: uid }, created_at: { integerValue: String(Date.now()) }, seq: { integerValue: '7' },
    body: { stringValue: '{"report":"rest"}' },
  }, over);
  return {
    writes: [{
      update: { name: `projects/${PROJECT}/databases/(default)/documents/users/${uid}/submissions/${docId}`, fields: f },
      updateTransforms: [{ fieldPath: 'received_at', setToServerValue: 'REQUEST_TIME' }],
      currentDocument: { exists: false },
    }],
  };
}

async function commit(token, body) {
  const r = await fetch(`http://${FS_HOST}/v1/projects/${PROJECT}/databases/(default)/documents:commit`,
    { method: 'POST', headers: Object.assign({ 'Content-Type': 'application/json' }, token ? { Authorization: `Bearer ${token}` } : {}), body: JSON.stringify(body) });
  return { status: r.status, json: await r.json().catch(() => ({})) };
}

test('REST: the Godot client commit is accepted, and a duplicate is distinguishable', async () => {
  const a = await signUp();
  const first = await commit(a.idToken, restDoc(a.localId, 'game_rest1'));
  assert.equal(first.status, 200, JSON.stringify(first.json));
  const again = await commit(a.idToken, restDoc(a.localId, 'game_rest1'));
  assert.notEqual(again.status, 200);
  // Whatever the duplicate status, the owner GET proves the document exists (lost-ack recovery).
  const g = await fetch(`http://${FS_HOST}/v1/projects/${PROJECT}/databases/(default)/documents/users/${a.localId}/submissions/game_rest1`,
    { headers: { Authorization: `Bearer ${a.idToken}` } });
  assert.equal(g.status, 200);
  console.log(`duplicate commit status: ${again.status} ${again.json.error && again.json.error.status}`);
});

test('REST: spoofed paths, missing auth and invalid schema are refused', async () => {
  const a = await signUp();
  const b = await signUp();
  assert.equal((await commit(b.idToken, restDoc(a.localId, 'game_spoof'))).status, 403);
  assert.equal((await commit('', restDoc(a.localId, 'game_noauth'))).status, 403);
  assert.equal((await commit(a.idToken, restDoc(a.localId, 'game_bad', { schema_version: { integerValue: '9' } }))).status, 403);
  const g = await fetch(`http://${FS_HOST}/v1/projects/${PROJECT}/databases/(default)/documents/users/${a.localId}/submissions/game_spoof`,
    { headers: { Authorization: `Bearer ${b.idToken}` } });
  assert.equal(g.status, 403);
});

// ------------------------------------------------------------------ security review additions

test('review: nested, array and wrong-typed fields are refused; body must be a string', async () => {
  const p = (id) => doc(alice(), `users/alice/submissions/${id}`);
  await assertFails(setDoc(p('game_n1'), submission('alice', 'game', { body: ['x'.repeat(10)] })));
  await assertFails(setDoc(p('game_n2'), submission('alice', 'game', { body: { nested: { deep: 1 } } })));
  await assertFails(setDoc(p('game_n3'), submission('alice', 'game', { build: { x: 1 } })));
  await assertFails(setDoc(p('game_n4'), submission('alice', 'game', { created_at: 1760000000000.5 })));
  await assertFails(setDoc(p('game_n5'), submission('alice', 'game', { uid: ['alice'] })));
  await assertFails(setDoc(p('game_n6'), submission('alice', 'game', { kind: ['game'] })));
  await assertFails(setDoc(p('game_n7'), submission('alice', 'game', { seq: -1 })));
  const noTime = submission('alice', 'game');
  delete noTime.received_at;
  await assertFails(setDoc(p('game_n8'), noTime));
  await assertFails(setDoc(p('game_n9'), submission('alice', 'game', { received_at: new Date(Date.now() + 3600e3) })));
});

test('review: document-id kind spoofing and path tricks are refused', async () => {
  const p = (id) => doc(alice(), `users/alice/submissions/${id}`);
  await assertFails(setDoc(p('gclient_x1'), submission('alice', 'game')));
  await assertFails(setDoc(p('game_x1'), submission('alice', 'gclient')));
  await assertFails(setDoc(p('xgame_x1'), submission('alice', 'game')));
  await assertFails(setDoc(p('game_'), submission('alice', 'game')));
  await assertFails(setDoc(p(`game_${'a'.repeat(121)}`), submission('alice', 'game')));
  await assertFails(setDoc(doc(alice(), 'users/alice/submissions/game_x/nested/game_y'), submission('alice', 'game')));
  await assertSucceeds(setDoc(p(`game_${'a'.repeat(120)}`), submission('alice', 'game')));
});

test('review: no client can list or query any collection, including its own', async () => {
  const { query, where } = require('firebase/firestore');
  await seed('users/alice/submissions/game_q1', submission('alice', 'game', { received_at: new Date() }));
  await assertFails(getDocs(query(collection(alice(), 'users/alice/submissions'), where('uid', '==', 'alice'))));
  await assertFails(getDocs(collectionGroup(alice(), 'submissions')));
  await assertFails(getDocs(collection(alice(), 'canonical_games')));
  await assertFails(getDocs(collection(alice(), 'aggregates')));
  await assertFails(getDocs(collection(alice(), 'users')));
});

test('review: the rules file has no unconditional allow', () => {
  const src = fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8').replace(/\/\/.*$/gm, '');
  assert.ok(!/if\s+true/.test(src));
  assert.ok(!/allow[^;]*if\s+request\.auth\s*!=\s*null\s*;/.test(src));
  const allows = src.match(/allow [^:]+:/g);
  assert.deepEqual(allows, ['allow create:', 'allow get:', 'allow list, update, delete:', 'allow read, write:']);
});
