#!/usr/bin/env node
// RLDB telemetry admin tool: owner-run, trusted reconciliation and aggregation (Spark plan has no
// Cloud Functions, so this replaces a backend). Uses the Firebase Admin SDK, which bypasses the
// security rules; it must only ever run on the owner's machine.
//
// Credentials (never in the repository, never in the game):
//   gcloud auth application-default login            (owner Google account), or
//   set GOOGLE_APPLICATION_CREDENTIALS=C:\secure\rldb-admin.json   (service-account key kept outside the repo)
// Emulator: set FIRESTORE_EMULATOR_HOST=127.0.0.1:8180 (no credentials needed).
//
// Commands (from firebase/):
//   node tools/rldb-admin.js reconcile [--env=production] [--modes=lan,steam] [--statuses=verified,provisional]
//        [--write] [--out=tools/out]     classify every duel, compute metrics, print a summary and save JSON
//        --write also stores canonical_games/{env}__{game_id} (only changed docs) and
//        aggregates/{env}__default; canonical docs whose submissions disappeared are deleted.
//   node tools/rldb-admin.js health [--env=production]
//   node tools/rldb-admin.js delete-uid <uid> [--confirm]   list (or, with --confirm, delete) every
//        submission of one Firebase uid; then run "reconcile --write" for each environment.
//   node tools/rldb-admin.js --from-file=dump.json reconcile ...   offline run on exported raw docs.
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { reconcileAll } = require('./lib/reconcile');
const { computeMetrics, DEFAULT_FILTER } = require('./lib/metrics');

const PROJECT = 'rldb-b5593';
const CARDS = path.join(__dirname, '..', '..', 'rldb', 'data', 'cards.json');

function catalog() {
  const d = JSON.parse(fs.readFileSync(CARDS, 'utf8'));
  return (Array.isArray(d) ? d : d.cards).map((c) => ({ id: Number(c.id), category: c.category }));
}

function db() {
  const admin = require('firebase-admin');
  if (!admin.apps.length) admin.initializeApp({ projectId: PROJECT });
  return admin.firestore();
}

/** Every raw submission: [{uid, id, received_at, data}]. */
async function loadSubmissions(firestore) {
  const snap = await firestore.collectionGroup('submissions').get();
  return snap.docs.map((doc) => {
    const data = { ...doc.data() };
    const ra = data.received_at && data.received_at.toMillis ? data.received_at.toMillis() : null;
    delete data.received_at;
    return { uid: doc.ref.parent.parent.id, id: doc.id, received_at: ra, data };
  });
}

function parseArgs(argv) {
  const o = { _: [] };
  for (const a of argv) {
    const m = a.match(/^--([^=]+)(?:=(.*))?$/);
    if (m) o[m[1]] = m[2] === undefined ? true : m[2];
    else o._.push(a);
  }
  return o;
}

function filterFrom(o) {
  const f = { ...DEFAULT_FILTER };
  if (o.modes) f.modes = String(o.modes).split(',');
  if (o.statuses) f.statuses = String(o.statuses).split(',');
  if (o.player) f.player = String(o.player);
  if (o['content-hash']) f.content_hash = String(o['content-hash']);
  if (o.from) f.from = Date.parse(o.from);
  if (o.to) f.to = Date.parse(o.to);
  return f;
}

/** Reconciles one environment; with write=true stores canonical games and the aggregate. */
async function runReconcile(firestore, raws, { env = 'production', write = false, filter = DEFAULT_FILTER, cat = catalog() } = {}) {
  const all = reconcileAll(raws);
  const data = all.byEnv[env] || { recs: [], games: {}, health: {} };
  const metrics = computeMetrics(data, cat, filter);
  const res = { env, accepted: all.accepted, rejected: all.rejected, health: data.health, metrics, written: 0, unchanged: 0, deleted: 0 };
  if (!write) return res;
  const col = firestore.collection('canonical_games');
  const existing = await col.where('env', '==', env).get();
  const old = new Map(existing.docs.map((d) => [d.id, d.data()]));
  let batch = firestore.batch();
  let n = 0;
  const flush = async () => { if (n) { await batch.commit(); batch = firestore.batch(); n = 0; } };
  for (const g of Object.values(data.games)) {
    const id = `${env}__${g.game_id}`;
    const prev = old.get(id);
    old.delete(id);
    if (prev && prev.hash === g.hash) { res.unchanged++; continue; }
    batch.set(col.doc(id), g);
    res.written++;
    if (++n >= 400) await flush();
  }
  for (const id of old.keys()) { batch.delete(col.doc(id)); res.deleted++; if (++n >= 400) await flush(); }
  await flush();
  const key = `${env}__${filter === DEFAULT_FILTER ? 'default' : Buffer.from(JSON.stringify(filter)).toString('base64url').slice(0, 40)}`;
  await firestore.collection('aggregates').doc(key).set({
    env, filter: JSON.stringify(filter), computed_at: Date.now(), schema_version: 1,
    health: JSON.stringify(data.health), rejected: JSON.stringify(all.rejected), body: JSON.stringify(metrics),
  });
  return res;
}

/** Lists or deletes every submission of `uid`. Returns the number of documents. */
async function deleteUid(firestore, uid, confirm) {
  const snap = await firestore.collection('users').doc(uid).collection('submissions').get();
  if (confirm) {
    let batch = firestore.batch();
    let n = 0;
    for (const d of snap.docs) {
      batch.delete(d.ref);
      if (++n >= 400) { await batch.commit(); batch = firestore.batch(); n = 0; }
    }
    if (n) await batch.commit();
  }
  return snap.size;
}

function summary(res) {
  const m = res.metrics;
  const lines = [
    `env=${res.env} accepted=${res.accepted} rejected=${JSON.stringify(res.rejected)}`,
    `duels: ${JSON.stringify(res.health)}`,
    `eligible duels=${m.eligible_games} decisive=${m.decisive_games} player-games=${m.player_game_observations} (filter ${JSON.stringify(m.filter)})`,
    `first-player win rate: ${fmt(m.duel.first_player_win_rate)}; profiles with sessions: ${m.profiles_with_sessions}`,
  ];
  if (res.written || res.unchanged || res.deleted) lines.push(`canonical: written=${res.written} unchanged=${res.unchanged} deleted=${res.deleted}`);
  const cards = Object.values(m.cards).filter((c) => c.offer_opps || c.main.inclusions || c.extra.inclusions || c.plays);
  cards.sort((a, b) => b.plays - a.plays);
  for (const c of cards.slice(0, 15)) {
    lines.push(`  card ${c.id}: plays=${c.plays} pick=${fmt(c.pick_rate)} deck=${fmt(c.main.inclusion_rate)} conv=${fmt(c.draw_conversion)} win=${fmt(c.win_with)}`);
  }
  return lines.join('\n');
}

function fmt(r) { return r && r.rate !== null ? `${r.num}/${r.den} (${(100 * r.rate).toFixed(1)}%)` : `${r ? r.num : 0}/${r ? r.den : 0} (n/a)`; }

async function main() {
  const o = parseArgs(process.argv.slice(2));
  const cmd = o._[0];
  const firestore = o['from-file'] ? null : db();
  const raws = async () => (o['from-file'] ? JSON.parse(fs.readFileSync(o['from-file'], 'utf8')) : loadSubmissions(firestore));
  if (cmd === 'reconcile' || cmd === 'health') {
    if (o.write && !firestore) throw new Error('--write needs the database, not --from-file');
    const res = await runReconcile(firestore, await raws(), { env: o.env || 'production', write: !!o.write, filter: filterFrom(o) });
    if (cmd === 'health') { console.log(JSON.stringify({ env: res.env, accepted: res.accepted, rejected: res.rejected, health: res.health }, null, 2)); return; }
    console.log(summary(res));
    const out = o.out || path.join(__dirname, 'out');
    fs.mkdirSync(out, { recursive: true });
    const file = path.join(out, `metrics-${res.env}.json`);
    fs.writeFileSync(file, JSON.stringify(res, null, 1));
    console.log(`saved ${file}`);
  } else if (cmd === 'delete-uid') {
    const uid = o._[1];
    if (!uid) throw new Error('usage: delete-uid <uid> [--confirm]');
    const n = await deleteUid(firestore, uid, !!o.confirm);
    console.log(o.confirm ? `deleted ${n} submission(s) of ${uid}; now run "reconcile --write" for each environment` : `${n} submission(s) of ${uid} (add --confirm to delete)`);
  } else {
    console.log(fs.readFileSync(__filename, 'utf8').split('\n').slice(1, 22).join('\n'));
    process.exitCode = 2;
  }
}

if (require.main === module) main().catch((e) => { console.error(e.message); process.exitCode = 1; });

module.exports = { runReconcile, deleteUid, loadSubmissions, catalog };
