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
  // Schema v2 (20 Oct 2026: turn times) is accepted beside v1; anything else is not.
  await assertSucceeds(setDoc(p('game_v2'), submission('alice', 'game', { schema_version: 2 })));
  await assertFails(setDoc(p('game_v3'), submission('alice', 'game', { schema_version: 3 })));
  await assertFails(setDoc(p('game_v0'), submission('alice', 'game', { schema_version: 0 })));
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
  assert.deepEqual(allows, ['allow create:', 'allow get:', 'allow list, update, delete:',
    'allow get:', 'allow create, update:', 'allow list, delete:',
    'allow get:', 'allow create:', 'allow update:', 'allow list, delete:', 'allow read, write:']);
});


// ------------------------------------------------------------------ cloud statistics (C1)
// stats_links/{uid} claims one Steam-ID hash; player_stats/{hash} is readable and writable only
// by a uid whose link names it. Unverified by design (owner decision 20 Oct 2026): any anonymous
// uid may claim any hash, so these tests prove the shape, size and claim checks, not identity.

const H1 = '0123456789abcdef0123456789abcdef';
const H2 = 'fedcba9876543210fedcba9876543210';
const carol = () => env.authenticatedContext('carol', { firebase: { sign_in_provider: 'password' } }).firestore();

function link(hash, over = {}) {
  return Object.assign({ steam_hash: hash, linked_at: serverTimestamp() }, over);
}

function stats(uid, hash, over = {}) {
  return Object.assign({
    schema_version: 1, steam_hash: hash, uid, rev: 1, enc: 'gzip64', raw_len: 120,
    updated_at: serverTimestamp(), body: 'H4sIAAAAAAAA',
  }, over);
}

async function linkAs(db, uid, hash) {
  await assertSucceeds(setDoc(doc(db, `stats_links/${uid}`), link(hash)));
}

test('stats: a uid links its own hash, reads it back, and nobody else reads its link', async () => {
  await linkAs(alice(), 'alice', H1);
  await assertSucceeds(getDoc(doc(alice(), 'stats_links/alice')));
  await assertFails(getDoc(doc(bob(), 'stats_links/alice')));
  await assertFails(getDoc(doc(anon(), 'stats_links/alice')));
  // Re-linking (another Steam account on this install) is an update, still checked.
  await assertSucceeds(setDoc(doc(alice(), 'stats_links/alice'), link(H2)));
});

test('stats: links are refused for other uids, bad hashes, extra fields and client times', async () => {
  await assertFails(setDoc(doc(bob(), 'stats_links/alice'), link(H1)));
  await assertFails(setDoc(doc(anon(), 'stats_links/alice'), link(H1)));
  await assertFails(setDoc(doc(carol(), 'stats_links/carol'), link(H1)));          // not anonymous
  await assertFails(setDoc(doc(alice(), 'stats_links/alice'), link('76561198000000042')));   // raw Steam ID
  await assertFails(setDoc(doc(alice(), 'stats_links/alice'), link(H1.toUpperCase())));
  await assertFails(setDoc(doc(alice(), 'stats_links/alice'), link(H1 + 'aa')));
  await assertFails(setDoc(doc(alice(), 'stats_links/alice'), link(H1, { verified: true })));
  await assertFails(setDoc(doc(alice(), 'stats_links/alice'), link(H1, { linked_at: new Date(0) })));
  await assertFails(setDoc(doc(alice(), 'stats_links/alice'), { steam_hash: H1 }));
  await linkAs(alice(), 'alice', H1);
  await assertFails(deleteDoc(doc(alice(), 'stats_links/alice')));
  await assertFails(getDocs(collection(alice(), 'stats_links')));
});

test('stats: the linked uid creates, reads and updates its stats with rev + 1', async () => {
  await linkAs(alice(), 'alice', H1);
  const ref = doc(alice(), `player_stats/${H1}`);
  await assertSucceeds(setDoc(ref, stats('alice', H1)));
  await assertSucceeds(getDoc(ref));
  await assertSucceeds(setDoc(ref, stats('alice', H1, { rev: 2 })));
  // A second computer (another uid) claims the same hash and continues the record.
  await linkAs(bob(), 'bob', H1);
  await assertSucceeds(getDoc(doc(bob(), `player_stats/${H1}`)));
  await assertSucceeds(setDoc(doc(bob(), `player_stats/${H1}`), stats('bob', H1, { rev: 3 })));
});

test('stats: a link and the first stats write may share one commit', async () => {
  const { writeBatch } = require('firebase/firestore');
  const db = alice();
  const b = writeBatch(db);
  b.set(doc(db, 'stats_links/alice'), link(H1));
  b.set(doc(db, `player_stats/${H1}`), stats('alice', H1));
  await assertSucceeds(b.commit());
});

test('stats: unlinked, wrongly linked and unauthenticated callers can neither read nor write', async () => {
  await linkAs(alice(), 'alice', H1);
  await assertSucceeds(setDoc(doc(alice(), `player_stats/${H1}`), stats('alice', H1)));
  // bob has no link; then a link to a different hash.
  await assertFails(getDoc(doc(bob(), `player_stats/${H1}`)));
  await assertFails(setDoc(doc(bob(), `player_stats/${H1}`), stats('bob', H1, { rev: 2 })));
  await linkAs(bob(), 'bob', H2);
  await assertFails(getDoc(doc(bob(), `player_stats/${H1}`)));
  await assertFails(setDoc(doc(bob(), `player_stats/${H1}`), stats('bob', H1, { rev: 2 })));
  await assertFails(getDoc(doc(anon(), `player_stats/${H1}`)));
  await assertFails(setDoc(doc(anon(), `player_stats/${H2}`), stats('x', H2)));
  // Non-anonymous accounts are not game installs.
  await assertFails(setDoc(doc(carol(), 'stats_links/carol'), link(H1)));
  await assertFails(getDoc(doc(carol(), `player_stats/${H1}`)));
});

test('stats: spoofed paths and fields are refused', async () => {
  await linkAs(alice(), 'alice', H1);
  const p = (h) => doc(alice(), `player_stats/${h}`);
  await assertFails(setDoc(p(H1), stats('bob', H1)));                       // uid field is not the caller
  await assertFails(setDoc(p(H1), stats('alice', H2)));                     // body hash differs from the path
  await assertFails(setDoc(p(H2), stats('alice', H2)));                     // path hash not linked
  await assertFails(setDoc(p('76561198000000042'), stats('alice', '76561198000000042')));   // raw Steam ID path
  await assertFails(setDoc(doc(alice(), `player_stats/${H1}/x/y`), stats('alice', H1)));    // nested path
  await assertFails(setDoc(doc(alice(), `users/alice/player_stats/${H1}`), stats('alice', H1)));
});

test('stats: schema, revision and size are enforced', async () => {
  await linkAs(alice(), 'alice', H1);
  const ref = doc(alice(), `player_stats/${H1}`);
  await assertFails(setDoc(ref, stats('alice', H1, { rev: 2 })));            // create must be rev 1
  await assertFails(setDoc(ref, stats('alice', H1, { schema_version: 2 })));
  await assertFails(setDoc(ref, stats('alice', H1, { enc: 'zip' })));
  await assertFails(setDoc(ref, stats('alice', H1, { raw_len: 4194305 })));
  await assertFails(setDoc(ref, stats('alice', H1, { raw_len: '120' })));
  await assertFails(setDoc(ref, stats('alice', H1, { updated_at: new Date() })));
  await assertFails(setDoc(ref, stats('alice', H1, { body: { duels: [] } })));
  await assertFails(setDoc(ref, stats('alice', H1, { admin: true })));
  const missing = stats('alice', H1);
  delete missing.raw_len;
  await assertFails(setDoc(ref, missing));
  await assertFails(setDoc(ref, stats('alice', H1, { body: 'x'.repeat(200001) })));   // oversized
  await assertSucceeds(setDoc(ref, stats('alice', H1, { body: 'x'.repeat(200000) })));
  // Updates: exactly rev + 1, same checks.
  await assertFails(setDoc(ref, stats('alice', H1, { rev: 1 })));
  await assertFails(setDoc(ref, stats('alice', H1, { rev: 3 })));
  await assertFails(updateDoc(ref, { body: 'xx' }));                          // no rev / time
  await assertFails(setDoc(ref, stats('alice', H1, { rev: 2, body: 'x'.repeat(200001) })));
  await assertSucceeds(setDoc(ref, stats('alice', H1, { rev: 2 })));
});

test('stats: never listed, queried or deleted by any client', async () => {
  await linkAs(alice(), 'alice', H1);
  await assertSucceeds(setDoc(doc(alice(), `player_stats/${H1}`), stats('alice', H1)));
  await assertFails(getDocs(collection(alice(), 'player_stats')));
  await assertFails(getDocs(collection(bob(), 'player_stats')));
  await assertFails(deleteDoc(doc(alice(), `player_stats/${H1}`)));
  await assertFails(getDocs(collectionGroup(alice(), 'player_stats')));
});

test('REST: the Godot sync protocol (link, read, create, precondition update, lost race)', async () => {
  const a = await signUp();
  const root = `projects/${PROJECT}/databases/(default)/documents`;
  const linkW = { writes: [{ update: { name: `${root}/stats_links/${a.localId}`, fields: { steam_hash: { stringValue: H1 } } },
    updateTransforms: [{ fieldPath: 'linked_at', setToServerValue: 'REQUEST_TIME' }] }] };
  assert.equal((await commit(a.idToken, linkW)).status, 200);
  const url = `http://${FS_HOST}/v1/${root}/player_stats/${H1}`;
  const auth = { headers: { Authorization: `Bearer ${a.idToken}` } };
  assert.equal((await fetch(url, auth)).status, 404);
  const fields = (rev) => ({ schema_version: { integerValue: '1' }, steam_hash: { stringValue: H1 }, uid: { stringValue: a.localId },
    rev: { integerValue: String(rev) }, enc: { stringValue: 'gzip64' }, raw_len: { integerValue: '50' }, body: { stringValue: 'H4sIAAAA' } });
  const write = (rev, pre) => ({ writes: [{ update: { name: `${root}/player_stats/${H1}`, fields: fields(rev) },
    updateTransforms: [{ fieldPath: 'updated_at', setToServerValue: 'REQUEST_TIME' }], currentDocument: pre }] });
  const created = await commit(a.idToken, write(1, { exists: false }));
  assert.equal(created.status, 200, JSON.stringify(created.json));
  const t1 = created.json.writeResults[0].updateTime;
  assert.ok(t1);
  const got = await fetch(url, auth);
  assert.equal(got.status, 200);
  assert.equal((await got.json()).updateTime, t1);
  const second = await commit(a.idToken, write(2, { updateTime: t1 }));
  assert.equal(second.status, 200, JSON.stringify(second.json));
  // A writer still holding the old version loses the race with a precondition failure.
  const stale = await commit(a.idToken, write(3, { updateTime: t1 }));
  assert.notEqual(stale.status, 200);
  console.log(`stale precondition status: ${stale.status} ${stale.json.error && stale.json.error.status}`);
  assert.ok(['FAILED_PRECONDITION', 'ABORTED', 'ALREADY_EXISTS'].includes(stale.json.error && stale.json.error.status) || stale.status === 409);
  // Another uid that never linked this hash is refused with 403.
  const b = await signUp();
  assert.equal((await fetch(url, { headers: { Authorization: `Bearer ${b.idToken}` } })).status, 403);
  assert.equal((await commit(b.idToken, write(3, { updateTime: second.json.writeResults[0].updateTime }))).status, 403);
});
