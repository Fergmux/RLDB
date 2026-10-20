// End-to-end cloud statistics check (C1) on the local emulators: the real Godot client, as two
// simulated computers with their own anonymous identities, syncs one Steam account's statistics
// under the strict rules. Computer A records 2 duels, computer B records 1 and must see all 3 after
// its sync, and A must see B's duel on its next start. The admin tool then decodes the record the
// game wrote (gzip + base64 from Godot) and must find exactly 3 duels.
//   cd firebase && npx firebase emulators:exec --only firestore,auth --project rldb-b5593 "node tests/e2e_stats.js"
'use strict';
const { execFileSync } = require('node:child_process');
const path = require('node:path');
const assert = require('node:assert/strict');
const admin = require('firebase-admin');
const { playerStats } = require('../tools/rldb-admin');

const GODOT = process.env.GODOT || 'C:/Users/fergm/Downloads/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe';
const STEAM = '76561198000000777';

function machine(m, duels, wipe) {
  const args = ['--headless', '--path', path.join(__dirname, '..', '..', 'rldb'), '-s', 'res://src/dev/telemetry_tool.gd', '--',
    '--stats-sync', '--telemetry-emulator', `--machine=${m}`, `--fake-steam=${STEAM}`, `--duels=${duels}`];
  if (wipe) args.push('--wipe');
  let out;
  try { out = execFileSync(GODOT, args, { encoding: 'utf8', timeout: 120000 }); } catch (e) { out = String(e.stdout || '') + String(e.stderr || ''); }
  const line = out.split(/\r?\n/).filter((l) => /^(STATS|sync:)|SCRIPT ERROR/.test(l));
  console.log(`machine ${m}: ${line.join(' | ')}`);
  assert.ok(!/SCRIPT ERROR/.test(out), 'Godot script error');
  const mm = out.match(/STATS SYNCED duels=(\d+)/);
  assert.ok(mm, `machine ${m} did not sync`);
  return Number(mm[1]);
}

(async () => {
  assert.equal(machine('a', 2, true), 2);
  assert.equal(machine('b', 1, true), 3);       // B pulled A's two duels and merged its own
  assert.equal(machine('a', 0, false), 3);      // A sees B's duel on its next start
  admin.initializeApp({ projectId: 'rldb-b5593' });
  const db = admin.firestore();
  const list = await playerStats(db);
  assert.equal(list.length, 1);
  const one = await playerStats(db, list[0].steam_hash);
  assert.equal(one.record.duels.length, 3);
  assert.ok(!JSON.stringify(one).includes(STEAM), 'the raw Steam ID must never be stored');
  const links = await db.collection('stats_links').get();
  assert.equal(links.size, 2);                  // two computers, two anonymous uids, one hash
  console.log(`player_stats: ${JSON.stringify(one.summary)}`);
  console.log(`stored body chars: ${(await db.collection('player_stats').doc(list[0].steam_hash).get()).data().body.length}`);
  console.log('E2E STATS OK');
  await admin.app().delete();
})().catch((e) => { console.error(e.stack || e.message); process.exitCode = 1; });
