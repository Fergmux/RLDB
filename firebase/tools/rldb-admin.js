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
//   node tools/rldb-admin.js delete-uid <uid> [--confirm]   list (or, with --confirm, erase) one uid:
//        submissions, its anonymous Auth account, filtered aggregates naming it, then a rebuild of
//        every environment's canonical games and default aggregate.
//   node tools/rldb-admin.js --from-file=dump.json reconcile ...   offline run on exported raw docs.
//   node tools/rldb-admin.js player-stats [<steam hash>] [--json]   players' own cloud statistics
//        (C1; self-reported under an unverified Steam link): one summary line per player, or one
//        player's decoded record. Reads one document per player.
//   node tools/rldb-admin.js delete-stats <steam hash> [--confirm]   erase one player's cloud stats.
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { reconcileAll } = require('./lib/reconcile');
const { computeMetrics, DEFAULT_FILTER } = require('./lib/metrics');
const { decodeStats, summarize, HASH_RE } = require('./lib/player_stats');

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

/** Summaries of every player's cloud statistics, or the decoded record of one hash. */
async function playerStats(firestore, hash = null) {
  if (hash) {
    if (!HASH_RE.test(hash)) throw new Error('not a 32-hex Steam hash');
    const d = await firestore.collection('player_stats').doc(hash).get();
    if (!d.exists) return null;
    const rec = decodeStats(d.data());
    return { summary: summarize(hash, d.data(), rec), record: rec };
  }
  const snap = await firestore.collection('player_stats').get();
  return snap.docs.map((d) => summarize(d.id, d.data(), decodeStats(d.data()))).sort((a, b) => b.duels - a.duels);
}

/** Erases one player's cloud statistics and every link that names it. Returns the counts. */
async function deleteStats(firestore, hash) {
  if (!HASH_RE.test(hash)) throw new Error('not a 32-hex Steam hash');
  const links = await firestore.collection('stats_links').where('steam_hash', '==', hash).get();
  const batch = firestore.batch();
  for (const l of links.docs) batch.delete(l.ref);
  const ref = firestore.collection('player_stats').doc(hash);
  const had = (await ref.get()).exists;
  batch.delete(ref);
  await batch.commit();
  return { stats_deleted: had, links_deleted: links.size };
}

/**
 * Complete erasure of one Firebase uid (privacy request): its submissions, its anonymous Auth
 * account (when `auth` is given), every filtered aggregate that names it, and then a rebuild of
 * every environment so canonical games and default aggregates no longer contain it.
 * Returns {submissions, auth_deleted, aggregates_deleted, rebuilt: [env]}.
 */
async function purgeUid(firestore, uid, { auth = null, cat = catalog() } = {}) {
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(uid)) throw new Error('not a Firebase uid');
  const out = { submissions: await deleteUid(firestore, uid, true), auth_deleted: false, aggregates_deleted: 0, rebuilt: [],
    stats_deleted: false, links_deleted: 0 };
  // Cloud statistics (C1): the player record this uid's link names, and every link to it.
  const link = await firestore.collection('stats_links').doc(uid).get();
  if (link.exists && HASH_RE.test(String(link.data().steam_hash))) {
    const r = await deleteStats(firestore, String(link.data().steam_hash));
    out.stats_deleted = r.stats_deleted;
    out.links_deleted = r.links_deleted;
  }
  if ((await firestore.collection('stats_links').doc(uid).get()).exists) {
    await firestore.collection('stats_links').doc(uid).delete();
    out.links_deleted++;
  }
  if (auth) {
    try { await auth.deleteUser(uid); out.auth_deleted = true; } catch (e) { if (e.code !== 'auth/user-not-found') throw e; }
  }
  const key = `u:${uid}`;
  for (const d of (await firestore.collection('aggregates').get()).docs) {
    const a = d.data();
    if (!d.id.endsWith('__default') && (String(a.filter || '').includes(uid) || String(a.body || '').includes(key))) {
      await d.ref.delete();
      out.aggregates_deleted++;
    }
  }
  const raws = await loadSubmissions(firestore);
  const envs = new Set(raws.map((r) => r.data.env));
  for (const d of (await firestore.collection('canonical_games').get()).docs) envs.add(d.data().env);
  for (const d of (await firestore.collection('aggregates').get()).docs) envs.add(d.data().env);
  for (const env of [...envs].filter(Boolean).sort()) {
    await runReconcile(firestore, raws, { env, write: true, cat });
    out.rebuilt.push(env);
  }
  return out;
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
    if (!o.confirm) { console.log(`${await deleteUid(firestore, uid, false)} submission(s) of ${uid} (add --confirm to erase everything for this uid)`); return; }
    const r = await purgeUid(firestore, uid, { auth: require('firebase-admin').auth() });
    console.log(`deleted ${r.submissions} submission(s), auth account ${r.auth_deleted ? 'deleted' : 'not found'}, ${r.aggregates_deleted} filtered aggregate(s), cloud statistics ${r.stats_deleted ? 'deleted' : 'none'} (${r.links_deleted} link(s)); rebuilt ${r.rebuilt.join(', ') || 'nothing'}. Also delete local tools/out/*.json copies.`);
  } else if (cmd === 'player-stats') {
    const r = await playerStats(firestore, o._[1] || null);
    if (o.json || o._[1]) { console.log(JSON.stringify(r, null, 1)); return; }
    const t = (ms) => (ms == null ? '-' : `${Math.floor(ms / 60000)}:${String(Math.round(ms / 1000) % 60).padStart(2, '0')}`);
    console.log(`${r.length} player(s) with cloud statistics (self-reported, unverified Steam link)`);
    for (const p of r) {
      console.log(`  ${p.steam_hash}  duels=${p.duels} W-L=${p.wins}-${p.losses} avg duel ${t(p.avg_duel_ms)} avg turn ${t(p.avg_own_turn_ms)} rev=${p.rev}${p.decodable ? '' : ' (undecodable)'}`);
    }
  } else if (cmd === 'delete-stats') {
    const hash = o._[1];
    if (!hash) throw new Error('usage: delete-stats <steam hash> [--confirm]');
    if (!o.confirm) { console.log(JSON.stringify(await playerStats(firestore, hash) && (await playerStats(firestore, hash)).summary)); console.log('add --confirm to erase it'); return; }
    console.log(JSON.stringify(await deleteStats(firestore, hash)));
  } else {
    console.log(fs.readFileSync(__filename, 'utf8').split('\n').slice(1, 27).join('\n'));
    process.exitCode = 2;
  }
}

if (require.main === module) main().catch((e) => { console.error(e.message); process.exitCode = 1; });

module.exports = { runReconcile, deleteUid, purgeUid, loadSubmissions, catalog, playerStats, deleteStats };
