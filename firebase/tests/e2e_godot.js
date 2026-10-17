// End-to-end telemetry check on the local emulators: the real Godot client plays a bot-vs-bot
// draft series through the rules engine and collector, uploads it under the strict rules, and the
// admin tool reconciles what arrived. Fails unless the series reached the database intact.
//   cd firebase && npx firebase emulators:exec --only firestore,auth --project rldb-b5593 "node tests/e2e_godot.js"
// GODOT may point at the Godot 4.6.1 editor console binary.
'use strict';
const { execFileSync } = require('node:child_process');
const path = require('node:path');
const assert = require('node:assert/strict');
const admin = require('firebase-admin');
const { runReconcile, loadSubmissions } = require('../tools/rldb-admin');

const GODOT = process.env.GODOT || 'C:/Users/fergm/Downloads/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe';

(async () => {
  const out = execFileSync(GODOT, ['--headless', '--path', path.join(__dirname, '..', '..', 'rldb'), '-s', 'res://src/dev/telemetry_tool.gd',
    '--', '--sim-series', '--telemetry-emulator'], { encoding: 'utf8', timeout: 300000 });
  const lines = out.split(/\r?\n/).filter((l) => /Simulated|uploader:|queue:|quarantined|SCRIPT ERROR/.test(l));
  console.log(lines.join('\n'));
  assert.ok(!/SCRIPT ERROR/.test(out), 'Godot script error');
  admin.initializeApp({ projectId: 'rldb-b5593' });
  const raws = await loadSubmissions(admin.firestore());
  const res = await runReconcile(null, raws, { env: 'test', filter: { modes: ['bot'], statuses: ['local'] } });
  const kinds = raws.reduce((m, r) => { m[r.data.kind] = (m[r.data.kind] || 0) + 1; return m; }, {});
  console.log(`submissions by kind: ${JSON.stringify(kinds)}`);
  console.log(`rejected: ${JSON.stringify(res.rejected)}; duels: ${JSON.stringify(res.health)}`);
  const m = res.metrics;
  const drafted = Object.values(m.cards).filter((c) => c.selections > 0).length;
  const played = Object.values(m.cards).reduce((a, c) => a + c.plays, 0);
  const conv = Object.values(m.cards).reduce((a, c) => [a[0] + c.draw_opps_played, a[1] + c.draw_opps], [0, 0]);
  console.log(`eligible duels=${m.eligible_games} decisive=${m.decisive_games} player-games=${m.player_game_observations} drafted cards=${drafted} plays=${played} draw conversion=${conv[0]}/${conv[1]}`);
  assert.ok(m.eligible_games >= 2, 'expected at least two duels');
  assert.equal(kinds.series, 1);
  assert.equal(kinds.draft, 2);
  assert.ok(played > 0 && conv[1] > 0);
  assert.equal(Object.keys(res.rejected).length, 0, 'admin tool rejected client records');
  console.log('E2E OK');
  await admin.app().delete();
})().catch((e) => { console.error(e.stack || e.message); process.exitCode = 1; });
