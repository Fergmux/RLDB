// Trusted reconciliation of raw telemetry submissions into canonical games (schema v1).
// Pure functions: the same set of submissions always yields the same canonical set, so a rebuild
// is idempotent and can never double count. Classification (owner answers, point 4):
//   network duel, host report + agreeing client report (different uids)  -> verified
//   network duel, only one of them                                        -> provisional
//   network duel, reports disagree (or two authority reports)             -> conflicted (excluded)
//   hot-seat / bot duel (single authority by design)                      -> local
//   duel that never finished                                              -> abandoned (excluded from W/L)
// A later agreeing report turns provisional into verified on the next rebuild without adding a
// second result; a later conflict removes the game from every aggregate on the next rebuild.
'use strict';
const crypto = require('node:crypto');

const KINDS = ['profile', 'session', 'draft', 'reward', 'game', 'gclient', 'series'];
const ENVS = ['playtest', 'production', 'dev', 'test'];
const NETWORK_MODES = ['lan', 'steam'];

/** Normalises one raw submission {uid, id, data} (data = Firestore fields). Returns {ok, rec|reason}. */
function normalize(raw) {
  const d = raw.data || {};
  const base = { uid: raw.uid, id: raw.id };
  if (d.schema_version !== 1) return { ok: false, reason: 'schema_version', ...base };
  if (!KINDS.includes(d.kind)) return { ok: false, reason: 'kind', ...base };
  if (!ENVS.includes(d.env)) return { ok: false, reason: 'env', ...base };
  if (d.uid !== raw.uid) return { ok: false, reason: 'uid_mismatch', ...base };
  let body;
  try { body = JSON.parse(d.body); } catch (e) { return { ok: false, reason: 'body_json', ...base }; }
  if (!body || typeof body !== 'object') return { ok: false, reason: 'body_type', ...base };
  const rec = {
    uid: raw.uid, id: raw.id, kind: d.kind, env: d.env, mode: d.mode, build: d.build,
    content_hash: d.content_hash, created_at: Number(d.created_at), seq: Number(d.seq),
    received_at: raw.received_at != null ? Number(raw.received_at) : Number(d.created_at), body,
  };
  if (body.probe) return { ok: false, reason: 'probe', ...base };
  const need = {
    game: () => body.game && typeof body.game.game_id === 'string' && Array.isArray(body.participants) && body.participants.length === 2 && Array.isArray(body.decks),
    gclient: () => body.gclient && typeof body.gclient.game_id === 'string' && Number.isInteger(body.gclient.seat),
    draft: () => body.draft && Array.isArray(body.draft.picks) && typeof body.draft.draft_id === 'string',
    reward: () => body.reward && Array.isArray(body.reward.actions),
    series: () => body.series && typeof body.series.series_id === 'string',
    session: () => body.session && typeof body.session.session_id === 'string',
    profile: () => body.profile && typeof body.profile.participant_id === 'string',
  }[d.kind];
  if (!need()) return { ok: false, reason: `schema_${d.kind}`, ...base };
  if (d.kind === 'game' && body.game.outcome === 'in_progress') return { ok: false, reason: 'in_progress', ...base };
  return { ok: true, rec };
}

function sameArray(a, b) {
  return Array.isArray(a) && Array.isArray(b) && a.length === b.length && a.every((v, i) => Number(v) === Number(b[i]));
}

/** Which result fields of a host report and a client report disagree ([] = agreement). */
function disagreements(host, client) {
  const g = host.body.game;
  const c = client.body.gclient;
  const out = [];
  if (c.outcome !== 'completed' || g.outcome !== 'completed') out.push('outcome');
  if (Number(g.winner) !== Number(c.winner)) out.push('winner');
  if (Number(g.turns) !== Number(c.turns)) out.push('turns');
  if (!sameArray(g.final_hp, c.final_hp)) out.push('final_hp');
  if (Number(g.duel_index) !== Number(c.duel_index)) out.push('duel_index');
  if (String(g.series_id) !== String(c.series_id)) out.push('series_id');
  if (Number(g.first_player) >= 0 && Number(c.first_player) >= 0 && Number(g.first_player) !== Number(c.first_player)) out.push('first_player');
  if (Number(c.seat) !== 1) out.push('client_seat');
  return out;
}

function playerKey(part, reporterUid) {
  if (!part) return null;
  if (part.kind === 'bot') return 'bot';
  if (part.link === 'profile') return `u:${reporterUid}`;
  if (part.link === 'guest') return `g:${part.participant_id}`;
  return null;
}

/** Reconciles normalised records of ONE environment into canonical games + ingestion health. */
function reconcile(recs) {
  const byGame = new Map();
  const slot = (gid) => { if (!byGame.has(gid)) byGame.set(gid, { auth: [], client: [] }); return byGame.get(gid); };
  for (const r of recs) {
    if (r.kind === 'game') slot(r.body.game.game_id).auth.push(r);
    if (r.kind === 'gclient') slot(r.body.gclient.game_id).client.push(r);
  }
  const games = {};
  const health = { games: 0, verified: 0, provisional: 0, conflicted: 0, local: 0, abandoned: 0, missing_client_report: 0, self_corroboration: 0 };
  for (const gid of [...byGame.keys()].sort()) {
    const { auth, client } = byGame.get(gid);
    auth.sort((a, b) => (a.uid < b.uid ? -1 : 1));
    client.sort((a, b) => (a.uid < b.uid ? -1 : 1));
    const host = auth[0] || null;
    const network = host ? !!(host.body.flags && host.body.flags.network) : true;
    let status;
    const notes = [];
    let clients = client.filter((c) => !host || c.uid !== host.uid);
    if (host && clients.length !== client.length) { notes.push('client report from the host uid ignored'); health.self_corroboration++; }
    if (auth.length > 1) { status = 'conflicted'; notes.push('more than one authority report'); }
    else if (host && host.body.game.outcome === 'abandoned') status = 'abandoned';
    else if (host && !network) status = 'local';
    else if (host && clients.length === 0) { status = 'provisional'; health.missing_client_report++; }
    else if (!host) status = clients.length === 1 && clients[0].body.gclient.outcome === 'completed' ? 'provisional' : (clients.length > 1 ? 'conflicted' : 'abandoned');
    else {
      const diff = clients.length > 1 ? ['multiple_client_reports'] : disagreements(host, clients[0]);
      status = diff.length === 0 ? 'verified' : 'conflicted';
      if (diff.length) notes.push(`disagree: ${diff.join(',')}`);
    }
    const src = host || clients[0];
    const g = host ? host.body.game : src.body.gclient;
    const players = [null, null];
    if (host) {
      players[0] = playerKey(host.body.participants[0], host.uid);
      players[1] = playerKey(host.body.participants[1], host.uid);
    }
    if (clients.length === 1) players[Number(clients[0].body.gclient.seat)] = `u:${clients[0].uid}`;
    const winner = Number(host ? g.winner : g.winner);
    const decisive = status !== 'abandoned' && (host ? !!g.decisive : (g.outcome === 'completed' && winner >= 0));
    const canon = {
      game_id: gid, env: src.env, mode: src.mode, status, notes,
      outcome: host ? g.outcome : g.outcome, decisive, winner, reason: host ? g.reason : (g.forfeit ? 'forfeit' : 'unknown'),
      turns: Number(g.turns), duel_index: Number(g.duel_index), series_id: String(g.series_id || ''),
      first_player: Number(g.first_player), active_ms: host ? Number(g.active_ms) : null,
      players, detail_source: host ? 'authority' : 'client',
      content_hash: src.content_hash, build: src.build,
      ended_at: Number(g.ended_at || src.created_at), received_at: Math.max(...[...auth, ...client].map((r) => r.received_at)),
      reports: [...auth, ...client].map((r) => `users/${r.uid}/submissions/${r.id}`).sort(),
    };
    canon.hash = crypto.createHash('sha256').update(JSON.stringify(canon)).digest('hex').slice(0, 24);
    games[gid] = canon;
    health.games++;
    health[status]++;
  }
  return { games, health };
}

/** Groups normalised records by environment and reconciles each. */
function reconcileAll(raws) {
  const out = { byEnv: {}, rejected: {}, accepted: 0 };
  const recsByEnv = {};
  for (const raw of raws) {
    const n = normalize(raw);
    if (!n.ok) { out.rejected[n.reason] = (out.rejected[n.reason] || 0) + 1; continue; }
    out.accepted++;
    (recsByEnv[n.rec.env] = recsByEnv[n.rec.env] || []).push(n.rec);
  }
  for (const env of Object.keys(recsByEnv)) {
    const r = reconcile(recsByEnv[env]);
    out.byEnv[env] = { recs: recsByEnv[env], games: r.games, health: r.health };
  }
  return out;
}

module.exports = { normalize, reconcile, reconcileAll, disagreements, NETWORK_MODES };
