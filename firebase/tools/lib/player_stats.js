// Cloud copies of players' own statistics (owner feedback C1): decoding and a short summary for
// the owner's admin tool. These documents are written by game clients under an UNVERIFIED Steam
// link (a salted hash the client reports), so they are self-reported and never feed the
// competitive metrics; every field is type-checked here before it is used.
'use strict';
const zlib = require('node:zlib');

const HASH_RE = /^[0-9a-f]{32}$/;
const MAX_RAW = 4 * 1024 * 1024;
const isObj = (o) => o !== null && typeof o === 'object' && !Array.isArray(o);
const num = (v) => (typeof v === 'number' && Number.isFinite(v) ? v : 0);

/** The shared record {version, duels, series, devices} of a player_stats document, or null. */
function decodeStats(data) {
  if (!isObj(data) || typeof data.body !== 'string') return null;
  let text;
  try {
    if (data.enc === 'json') text = data.body;
    else if (data.enc === 'gzip64') text = zlib.gunzipSync(Buffer.from(data.body, 'base64'), { maxOutputLength: MAX_RAW }).toString('utf8');
    else return null;
  } catch (e) { return null; }
  let rec;
  try { rec = JSON.parse(text); } catch (e) { return null; }
  if (!isObj(rec)) return null;
  return {
    version: num(rec.version),
    duels: Array.isArray(rec.duels) ? rec.duels.filter(isObj) : [],
    series: Array.isArray(rec.series) ? rec.series.filter(isObj) : [],
    devices: isObj(rec.devices) ? rec.devices : {},
  };
}

/** One line of figures for a decoded record. */
function summarize(hash, data, rec) {
  const duels = rec ? rec.duels : [];
  const rated = duels.filter((d) => d.won === true || d.won === false);
  const wins = rated.filter((d) => d.won === true).length;
  const timed = duels.filter((d) => num(d.ms) > 0);
  const ms = timed.reduce((a, d) => a + num(d.ms), 0);
  const tn = duels.reduce((a, d) => a + num(d.tn), 0);
  const tms = duels.reduce((a, d) => a + num(d.tms), 0);
  return {
    steam_hash: hash, last_writer_uid: String(data.uid || ''), rev: num(data.rev),
    updated_at: data.updated_at && data.updated_at.toMillis ? data.updated_at.toMillis() : null,
    decodable: !!rec, duels: duels.length, series: rec ? rec.series.length : 0,
    win_rate: rated.length ? wins / rated.length : null, wins, losses: rated.length - wins,
    avg_duel_ms: timed.length ? ms / timed.length : null, avg_own_turn_ms: tn ? tms / tn : null,
    machines_with_drafts: rec ? Object.keys(rec.devices).length : 0,
  };
}

module.exports = { decodeStats, summarize, HASH_RE };
