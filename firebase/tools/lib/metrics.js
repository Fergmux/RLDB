// Metrics over canonical games and raw detail (schema v1). Every rate is reported as
// {num, den, rate} with rate = null when den = 0, so sample sizes are always visible.
// Definitions (design/firebase-game-statistics-request-2026-10-17.md, "Exact metrics"):
//   win/loss          per player: W and L among eligible decisive duels; rate W/(W+L)
//   draft pick rate   selections / offer opportunities (a card counts once per offer it appears in)
//   deck inclusion    player-game snapshots containing the card / eligible snapshots (main, extra)
//   plays             committed plays by kind, unique duels played in, activations separately
//   draw conversion   draw opportunities played from that hand stay / draw opportunities
//   card win rate     wins / decisive player-games whose starting deck had >= 1 copy
//   by copy count     wins / decisive player-games with exactly n copies (n = 0 included)
// A duel gives two player-game observations that are NOT independent (shared duel, maybe the
// same card in both decks); these are associations, not causal effects.
'use strict';

const rate = (num, den) => ({ num, den, rate: den > 0 ? num / den : null });

const DEFAULT_FILTER = { modes: ['lan', 'steam'], statuses: ['verified', 'provisional'] };

function eligibleGames(games, f) {
  return Object.values(games).filter((g) => {
    const st = g.status === 'local' ? 'local' : g.status;
    if (!f.statuses.includes(st)) return false;
    if (!f.modes.includes(g.mode)) return false;
    if (f.content_hash && g.content_hash !== f.content_hash) return false;
    if (f.from && g.ended_at < f.from) return false;
    if (f.to && g.ended_at > f.to) return false;
    if (f.player && !g.players.includes(f.player)) return false;
    return true;
  }).sort((a, b) => (a.game_id < b.game_id ? -1 : 1));
}

function sumCounts(...ms) {
  const out = {};
  for (const m of ms) for (const k of Object.keys(m || {})) out[k] = (out[k] || 0) + Number(m[k]);
  return out;
}

/** Player-game observations: [{game_id, seat, player, deck: {id: copies}, main, extra, decisive, win}]. */
function playerGames(games, detailById, f) {
  const obs = [];
  for (const g of games) {
    const det = detailById[g.game_id];
    for (const seat of [0, 1]) {
      if (f.player && g.players[seat] !== f.player) continue;
      let main = null; let extra = null;
      if (det && det.kind === 'game') { main = det.body.decks[seat].main; extra = det.body.decks[seat].extra; }
      else if (det && det.kind === 'gclient' && Number(det.body.gclient.seat) === seat) { main = det.body.gclient.deck.main; extra = det.body.gclient.deck.extra; }
      obs.push({ game_id: g.game_id, seat, player: g.players[seat], main, extra, deck: main ? sumCounts(main, extra) : null,
        decisive: g.decisive, win: g.decisive && g.winner === seat });
    }
  }
  return obs;
}

/**
 * computeMetrics({games, recs}, catalog, filter) -> metrics object.
 * games: canonical games of one environment; recs: normalised records of that environment;
 * catalog: [{id, category}] (every card, so never-used cards appear with zero counts).
 */
function computeMetrics(env, catalog, filter = {}) {
  const f = { ...DEFAULT_FILTER, ...filter };
  const games = eligibleGames(env.games, f);
  const gameIds = new Set(games.map((g) => g.game_id));
  const detailById = {};
  for (const r of env.recs) {
    if (r.kind === 'game' && gameIds.has(r.body.game.game_id) && !detailById[r.body.game.game_id]) detailById[r.body.game.game_id] = r;
  }
  for (const r of env.recs) {
    if (r.kind === 'gclient' && gameIds.has(r.body.gclient.game_id) && !detailById[r.body.gclient.game_id]) detailById[r.body.gclient.game_id] = r;
  }
  const ids = catalog.map((c) => String(c.id));
  const card = {};
  for (const c of catalog) {
    card[String(c.id)] = { id: c.id, category: c.category, main: { inclusions: 0, copies: 0 }, extra: { inclusions: 0, copies: 0 },
      plays: 0, plays_by_kind: {}, games_played_in: 0, activations: 0, activations_by_kind: {},
      draw_opps: 0, draw_opps_played: 0, hand_plays: 0, draws: 0, drawn_never_played: 0,
      offer_opps: 0, offered_copies: 0, selections: 0, selected_copies: 0, pick_positions: [],
      reward_offer_opps: 0, reward_selections: 0, win_with: { num: 0, den: 0 }, by_copies: {} };
  }
  const ensure = (k) => card[k] || (card[k] = { id: Number(k), category: 'unknown', main: { inclusions: 0, copies: 0 }, extra: { inclusions: 0, copies: 0 },
    plays: 0, plays_by_kind: {}, games_played_in: 0, activations: 0, activations_by_kind: {}, draw_opps: 0, draw_opps_played: 0,
    hand_plays: 0, draws: 0, drawn_never_played: 0, offer_opps: 0, offered_copies: 0, selections: 0, selected_copies: 0, pick_positions: [],
    reward_offer_opps: 0, reward_selections: 0, win_with: { num: 0, den: 0 }, by_copies: {} });

  // Players.
  const players = {};
  const pl = (k) => players[k] || (players[k] = { W: 0, L: 0, decisive: 0, non_decisive: 0, games: 0 });
  let unattributed = 0;
  for (const g of games) {
    for (const seat of [0, 1]) {
      const k = g.players[seat];
      if (!k) { unattributed++; continue; }
      if (k === 'bot') continue;
      if (f.player && k !== f.player) continue;
      const p = pl(k);
      p.games++;
      if (g.decisive) { p.decisive++; if (g.winner === seat) p.W++; else p.L++; } else p.non_decisive++;
    }
  }
  for (const k of Object.keys(players)) players[k].win_rate = rate(players[k].W, players[k].W + players[k].L);

  // Decks and win rates.
  const obs = playerGames(games, detailById, f).filter((o) => o.deck);
  const decisiveObs = obs.filter((o) => o.decisive);
  for (const o of obs) {
    for (const [k, n] of Object.entries(o.main)) { const c = ensure(k); c.main.inclusions++; c.main.copies += n; }
    for (const [k, n] of Object.entries(o.extra)) { const c = ensure(k); c.extra.inclusions++; c.extra.copies += n; }
  }
  for (const k of Object.keys(card)) {
    const c = card[k];
    for (const o of decisiveObs) {
      const n = o.deck[k] || 0;
      if (n >= 1) { c.win_with.den++; if (o.win) c.win_with.num++; }
      const b = c.by_copies[n] || (c.by_copies[n] = { num: 0, den: 0 });
      b.den++; if (o.win) b.num++;
    }
    c.win_with = rate(c.win_with.num, c.win_with.den);
    for (const n of Object.keys(c.by_copies)) c.by_copies[n] = rate(c.by_copies[n].num, c.by_copies[n].den);
    for (const part of ['main', 'extra']) {
      c[part].inclusion_rate = rate(c[part].inclusions, obs.length);
      c[part].avg_copies_when_included = c[part].inclusions ? c[part].copies / c[part].inclusions : null;
    }
  }

  // Plays, activations, draw conversion (authority detail only; client-only duels have none).
  let detailGames = 0;
  for (const g of games) {
    const det = detailById[g.game_id];
    if (!det || det.kind !== 'game') continue;
    detailGames++;
    const playedIn = new Set();
    det.body.counters.forEach((seatCounters, seat) => {
      if (f.player && g.players[seat] !== f.player) return;
      for (const [k, v] of Object.entries(seatCounters)) {
        const c = ensure(k);
        c.plays += v.plays; c.activations += v.activations;
        for (const [pk, n] of Object.entries(v.plays_by_kind || {})) c.plays_by_kind[pk] = (c.plays_by_kind[pk] || 0) + n;
        for (const [ak, n] of Object.entries(v.activations_by_kind || {})) c.activations_by_kind[ak] = (c.activations_by_kind[ak] || 0) + n;
        if (v.plays > 0) playedIn.add(k);
      }
    });
    for (const k of playedIn) card[k].games_played_in++;
    for (const o of det.body.opportunities) {
      const [, seat, def, , reason, , outcome] = o;
      if (f.player && g.players[seat] !== f.player) continue;
      const c = ensure(String(def));
      if (outcome === 'played') c.hand_plays++;
      if (String(reason).startsWith('draw_')) {
        c.draws++; c.draw_opps++;
        if (outcome === 'played') c.draw_opps_played++; else c.drawn_never_played++;
      }
    }
  }
  for (const k of Object.keys(card)) {
    const c = card[k];
    c.draw_conversion = rate(c.draw_opps_played, c.draw_opps);
    c.raw_hand_plays_per_draw = rate(c.hand_plays, c.draws);
    c.drawn_never_played_rate = rate(c.drawn_never_played, c.draw_opps);
    c.plays_per_detail_game = rate(c.plays, detailGames);
    const special = Object.entries(c.plays_by_kind).filter(([pk]) => pk.startsWith('special_')).reduce((s, [, n]) => s + n, 0);
    c.extra_summons_per_inclusion = rate(special, c.extra.inclusions);
  }

  // Drafts (not tied to a finished duel; abandoned drafts count too).
  for (const r of env.recs) {
    if (r.kind !== 'draft' || !f.modes.includes(r.mode)) continue;
    for (const p of r.body.draft.picks) {
      const seen = new Set(p.offered.map(String));
      for (const k of seen) { const c = ensure(k); c.offer_opps++; c.offered_copies += Number((p.offered_counts || {})[k] || 0); }
      const s = ensure(String(p.selected)); s.selections++; s.selected_copies += Number(p.selected_count || 1); s.pick_positions.push(Number(p.n));
    }
  }
  // Rewards (separate from drafts).
  for (const r of env.recs) {
    if (r.kind !== 'reward' || !f.modes.includes(r.mode)) continue;
    let offer = null;
    for (const a of r.body.reward.actions) {
      if (a.kind === 'type') { offer = a.offered.map(String); for (const k of new Set(offer)) ensure(k).reward_offer_opps++; }
      if (a.kind === 'add' && offer) { ensure(String(a.selected)).reward_selections++; offer = null; }
    }
  }
  for (const k of Object.keys(card)) {
    const c = card[k];
    c.pick_rate = rate(c.selections, c.offer_opps);
    c.avg_pick_position = c.pick_positions.length ? c.pick_positions.reduce((a, b) => a + b, 0) / c.pick_positions.length : null;
    delete c.pick_positions;
    c.reward_pick_rate = rate(c.reward_selections, c.reward_offer_opps);
  }

  // Duel-level extras.
  const decisive = games.filter((g) => g.decisive);
  const reasons = {};
  for (const g of games) reasons[g.reason] = (reasons[g.reason] || 0) + 1;
  const firstWins = decisive.filter((g) => g.first_player >= 0 && g.winner === g.first_player).length;
  const sizes = {};
  for (const o of obs) { const n = Object.values(o.deck).reduce((a, b) => a + b, 0); sizes[n] = (sizes[n] || 0) + 1; }
  const profiles = new Set(env.recs.filter((r) => r.kind === 'session').map((r) => r.uid));
  return {
    filter: f, catalog_size: catalog.length, eligible_games: games.length, decisive_games: decisive.length,
    player_game_observations: obs.length, decisive_player_game_observations: decisiveObs.length, detail_games: detailGames,
    unattributed_seats: unattributed, players, cards: card,
    duel: {
      first_player_win_rate: rate(firstWins, decisive.filter((g) => g.first_player >= 0).length),
      avg_turns: games.length ? games.reduce((a, g) => a + g.turns, 0) / games.length : null,
      avg_active_ms: (() => { const d = games.filter((g) => g.active_ms != null); return d.length ? d.reduce((a, g) => a + g.active_ms, 0) / d.length : null; })(),
      completion_reasons: reasons, deck_size_distribution: sizes,
    },
    profiles_with_sessions: profiles.size,
    statuses: Object.values(env.games).reduce((m, g) => { m[g.status] = (m[g.status] || 0) + 1; return m; }, {}),
  };
}

module.exports = { computeMetrics, rate, DEFAULT_FILTER };
