# Bot opponent (user request, 16 Oct 2026)

"add an ai bot to play against … not proper AI but also not fully random … criteria like removing
most enemy statistics and increasing your own … add a menu option to play the bot, for now the bot
picks a random deck" + "make sure its moves have some delay so it's not too quick".

| Requirement | Implementation | Evidence |
| --- | --- | --- |
| Decent, not random moves | `src/ai/bot_brain.gd`: one-ply look-ahead on `MatchEngine.clone_for_sim()` copies, scored by HP difference, unit value (ATK/DEF, stance fit, buffs/debuffs), Powers, set cards, hand; own choices picked the same way (2 levels) | `tests/unit/ai/bot_brain_test.gd` (attacks an empty board, refuses a losing attack, summons, two bots finish a series with only legal commands) |
| Fair play | Only public information is scored; the human always passes on Traps in simulations; hand only counted | code review |
| Menu option | Main menu **Play vs Bot** (`main._start_bot`, also `-- --bot`); you are seat 0, the screen never switches | `production/qa/evidence/2026-10-16-bot/` |
| Random deck | `BotBrain.series_command` picks a random starter (random draft picks in draft mode); rewards: random type, strongest card offered; picks itself to go first after losing | bot driver |
| Delay between moves | `src/ai/bot_player.gd`: 0.9 s (moves), 1.3 s (attacks, Trap responses), 0.8 s (phase/choices), waits for animations; thinks on a worker thread | bot driver: min gap 1142 ms, median 1479 ms, 0 refused commands (editor and exported exe) |
