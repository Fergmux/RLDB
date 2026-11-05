# Owner feedback batch, 5 Nov 2026 (L1-L28)

Logged at the owner's request so the brief survives a context compact. The owner's text is copied verbatim
below (typos kept). Status, clarifications and decisions are recorded under each heading as work proceeds.

## Standing directives for this batch (owner, 2026-11-05)

> Okay i have a big list of feedback I want you to address, you should look through all the following points and
> address each one to the best of your ability, take your time think carefully and try to make all these changes as
> bug free and production level quality as yoiu possibly can, spare no expense, and whilke you're working if you see
> any other potential improvements you should action them too and make the game as good as you are able to, review all
> designs and actions and make sure everything is smooth, not strange and looks beautiful. You will be wroking
> unsupervised so make sure to inspect all the goals/mcps and if you need clarification on anything ask me up front so
> that you can go off on your own. Also you should have access to an upload skill, when the work is complete you should
> use it to upload the final builld to github. Also make sure to log these instructions to an md file so that they
> survive a contect compact.

What this means for the agent:
- Work unsupervised to production quality. "Spare no expense": ElevenLabs credits and agent time are authorised.
- Also make any other improvements you spot (log them under "Extra improvements" below).
- Clarifying questions go up front, once. After that, work without asking.
- When everything is done: export (check `Get-Process RLDB*` first), then run the `publish-release` skill to upload
  the final build to GitHub (github.com/Fergmux/RLDB, public).
- Standing rules from `production/handoff/rldb-context-2026-11-04.md` section 3 still apply. In particular: never
  `git stash`, never export over a running game, no secrets in files, copy card wording verbatim.

## The list (verbatim)

1. I want to replace all sound effects in the game, we are using a pyhthon library but they are a bit stiff, I want you to use the elevenlabs mcp to generate new soundeffects for everything, all existing ones and any other interactions buttons in-game actions etc should all have a sound effect, they should fit the fantasy vibe and be remeniscent of the existing effects but better waulity, summons/spells/effects etc should have quite fancy long sound effects, buttons/card moves etc should be quicker and cleaner, make sure to add any new sound effects you think should be included

2. sometimes when adding one of the new three cards via draft it makes the nopise but doesn't go into the draft, can you see why that might be?

3. When drafting the extra deck category, the three results should always be one fusion one ritual and one arcane, not a random mixture of the three

4. attacking with a unit again quickly after attacking with a unit cancels the first animation, we should queue them instead over cancelling/overwriting, this should be the case for all animations

5. When you click the sacrifice button and select a unit it should not give you a confirmation pop up, it should just immediately acrifice the unit, it should also stay in sacrifice 'mode' until the first bottom left button is clicked again, and maybe we can add a cool way of inidicating they are in sacrifice mode, some glowing effect onthe edge of the screen or some animation or something, or a different cursor (see later point on that)

6. The cancel button on the left panel prompt should be more obvious, currently it's just some text it should be aproper button

7. when choosing a target for an effect we show the cool targeting arrow, but once the target is selected and an animation plays, the arrow is still being shown, we should hide this arrow as soon as the target is selected

8. make status effect application more obvious, currently it just ppops up some text, each status application should have a cool animated effect and sound effect that clearly shows what has happened as well asa the text, also the status indicators on the card are a bit plain, a simple icon on black background, these should instead be representative of their effect, e/g poision should be dark green with goo and butn should be red etc, make them a bit more fancy and identifiable

9. when playing hypnotise it doesn't let you decide where to place the unit on your side of the field, it should give you the choice

10. remove all basic fonts, we should be using themed fonts on basically all text, no default arial looking font in the game please

11. shapeshifter loak and mimic should copy the artwork of the card they copy the stats of, this is a new mechanic but when they copy a unit, they should temporarily have the art of the copied unit, just while they're on the field, it should reset when they leave, and also the rest of the card should remain the same, colour name etc

12. remove the 'view lobby' button from the main game screen, just keep it in the menu popup section

13. when that menu is open clicking anywhere off it should close it

14. if you go first at the start oif a game that is not the first game, you do not get the draw cards animation for some reason

15. We want to rework sneaky snunday, it should no longer affect cost gains/losses, and instead just applies to atk/def, also it should now modify permanent changes, so if a card has been granted +10 permanently by a card previously it should now be -10, I don't think you need to track all historical permanent changes, it should basicaly be the difference between base and current atk/dev times -1

16. Can we make the 'opponent is responding' modal more obvious, but it in the middle of the screen and animate it more so that it is harder to miss

17. atk/def indicators on the card on the field are slightly too large, they just overlap the border of the card, they should just fit within the bounds of the card border, but they don't need to be reduced by much, same for the cost/type circles, nudge them inset slightly to avoid the card edge

18. the turn hourglass timer icon thing should be animated to rotate every now and then and the sand should fall/move correctly with its orientation

19. I played a fusion card that had an on summon destroy spell or tap effect, but I used fusioon ceremony from the field to summon it and it allowed me to choose that card to destroy, the fusin card should already be destroyed by the time the fusaion happens so that should not be on the field/a valid target, make sure those timings are fixed for all card interactions like that

20. We want to reowrk cleanse/curse slightly, if a unit has 1 stack of cleanse and a card applies two debuffs at the same time, previously cleanse would stop one of the applications and the other would still be applied, we want it to now prevent both before decrementing, and the same for buffs and curse

21. If you select a card on the field byu clciking on it, and the click one of the piles, the card is not deselected, they both show as selected, we should ddeselect the card

22. I donj't like using the system cursor, we should add a custom cursor with a few cursor states, so normal, pointer for clickable things, a target for selecting a target, a knife for sacrificning, stuff like that - and add an option to the settings menu to disable it and use system cursor again

23. I want to add a new sort of mechanic, we wil be adding this for a few cards but foir now we will just implement it for symbiote spawn. It is an evolution mechanic, similar to a regular effect but only when a certain condition as defined on the card is met, so for symbiote spawn we should add a new bit of text that says "At the start of your turn you can Evolve this Unit." this should be treated almost like the material for a fusion summon, i.e seperate section in the preview right pane and tooltip and stuff, but it behaves like a regular action.. The new part is that the evolve action replaces that card with the evolved version so for symbiote spawn, it should evolve into symbiote larva, which means that card is replaced by the latter card permanently (even after it leavs the field), and symbiote larva has the same effect excpet it evolves into symbiote siphonophore, we should remove the symbiote larva/siphonopore cards from the draft/deck builder etc as seperate cards and they are instead contained within the original base card. We will however need some way to show what the card evoilves into, I'm thinking in the right click inspect panel it shows a preview of the card it evolves into in a special section, and then clicking on that preview brings up the ionspect modal for that card. Also we should make sure the evoltuion effect has a cool fancy animation and sound effect

24. The three new cards now have card art, you can find them in C:\Users\fergm\Documents\rldb\tools\card-art-review\accepted-art please add these to those cards

25. Also in that folder is the new table background art I want you to use instead of what we currently use
make a way for ai to automatically upload the build for us

26. Also during the game there should be shown somwhere the previous results of the series, it could live in the view lobby panel, or somewhere else but there should be somewhere to show how many games each player has one over the past series games, this should not be plain text, it should be visually appealing with well designed indicators and stuff

27. Aslo I want us to improve the bot, give it a few more things to reach toward, e.g  higer attack on the field and other smarter logic arounbd positioning stance attack targets etc, I want it to be smarter and playe better, please do a review and improve it as much as you can

28. I have updated the game background image, there are now 4 options, can you add therm to a folder then update the main menu so the top level settings is replaced with 'options' and within options we have settings, customisation, and credits, in the customisation panel it should allow you to select ebtween the 4 table backjgreounds, make sure this ui is nice and clean and looks good. We don't need to alows this change in game, bear in mind we might add more customisation options later so maybe make sure there's sections, in fact add a card back section (with no options for now)

## Follow-up from the owner (2026-11-05, verbatim)

> okay you will be working unsupervised from now, do not ask questions do not pause execution, take any executive
> decisions you see fit, do not wait for permissions, work around any blokcers until you are done, when you're finished
> output anything you had to decide/could not do, also make a note of this: I want a mac build version uploaded to the
> github releases as well

- **L29 (new): a macOS build** must be exported and uploaded to the GitHub release next to the Windows builds
  (`publish-release` / `tools/publish_github.py` need a mac asset).
- No more questions: decide, work around blockers, and list every decision and anything not done in the final report.

- **L30 (owner, 2026-11-05, verbatim):** "remove the escx button prompt from the cancel button, i don't want keyboard
  shortcuts prompts visible anywhere in the game". Standing rule: no keyboard-shortcut hints (keycaps, "Esc", "Enter",
  "(Space)", hotkey labels in tooltips or buttons) may be shown anywhere in the game. The shortcuts themselves keep
  working.

- **Final report request (owner, 2026-11-05, verbatim):** "also when you're done give me a list of sound effects you've
  added for me to review". The final message must list every sound effect cue (new and replaced), what plays it,
  and which to listen to first. Source: design/audio/sfx-design-2026-11-05.md.

## Facts found during the up-front inspection (2026-11-05)

- ElevenLabs MCP: the `sfx` flow node (model `eleven_text_to_sound_v2`, 0.5-30 s, loop option) is available, and so is
  image generation (for cursors and status icons if wanted).
- Art for 189 ("189 - Owlbear Druid inspired.png"), 190 ("190 - Snow Tiger Paladin inspired.png") and 191 ("191 - Do
  Not Open Box.png") is in `C:\Users\fergm\Documents\rldb\tools\card-art-review\accepted-art`. "0 - Luxury Fantasy
  Table Background.png" is in the same folder and is byte-identical in size to `rldb/assets/art/background4.png`.
- The four table backgrounds are already in `rldb/assets/art/` as `background1.jpg` (green leather), `background2.png`
  (wood parquet), `background3.png` (wood with gold dragon corners) and `background4.png` (forest ruins, the "Luxury"
  file), all 2967x2156. `rldb/assets/art/background.jpg` is deleted in the working tree (the original is in
  `rldb/assets/art/backup/`). The code still points at `res://assets/art/background.jpg` (`src/ui/ui_style.gd`).
- Item 25's second line ("make a way for ai to automatically upload the build for us") is already done: the
  `publish-release` skill and `tools/publish_github.py` (commit efb72b6).
- Themed fonts already shipped: Cinzel (variable) and Alegreya Sans (regular, bold, italic).

## Clarifications (asked up front)

Owner answers, 2026-11-05 (these are confirmed rules, follow them exactly):
- **Evolve trigger (L23):** a turn-start prompt. At the start of your turn, each evolvable Unit gets a left-panel
  prompt: "Evolve <card> into <next>?" with Evolve / Skip. It is free (no AP). The bot always evolves.
- **Evolve duration (L23):** rest of THIS GAME only. Inside the game the card stays evolved wherever it goes (Spent,
  Hand, Draw, Exhaust...). The next game in the series starts from Symbiote Spawn again.
- **Evolve carry-over (L23):** keep state, no On Summon. Same zone and stance. Statuses (e.g. Eternal), counters and
  temporary or permanent stat changes stay; base ATK/DEF/cost become the new card's. It is not a Summon, so On Summon
  effects and summon-triggered Traps do not fire.
- **Sneaky Snunday text (L15):** "Until the end of this turn: all new and ongoing ATK/DEF gains and losses are
  reversed."
- **Default table background (L25):** `background4.png`, the forest ruins "Luxury Fantasy Table Background" from
  accepted-art. The owner named it in L25, so this was not asked.

## Progress

| # | Item | Status | Commit / notes |
|---|------|--------|----------------|
| L1 | ElevenLabs sound set | merged b90c644 | 108 cues (59 replaced, 49 new), ~3,130 credits. Takes picked by measurement; alternates in production/audio-staging/. Listen first: ritual_choir, fusion_vortex, hp_low_heartbeat, boom, card_play, card_set, victory/defeat stingers. |
| L2 | New cards via draft lost | merged 7ed71c5 | Root cause in the between-games "Add a card" reward: the add command was sent at the end of a fold animation that a modal rebuild could kill. Drafting itself was fine for all cards. |
| L3 | Extra Deck offer F/R/A | merged 7ed71c5 | Also applied to the "Add a card > Extra Deck" reward. |
| L4 | Animations queue | merged 21a532e | Clicks no longer skip animations; a backlog speeds up (max 2x). |
| L5 | Sacrifice mode | merged cdcd8cd | Ember screen-edge glow, lit button, knife cursor via L22. |
| L6 | Cancel is a real button | merged cdcd8cd | |
| L7 | Arrow hides on pick | merged cdcd8cd | |
| L8 | Status FX + badges | merged ca635a3 | 15 animated looks with sounds, Cleanse/Curse ward flash, tick and expiry effects; enamelled effect-coloured badges (poison green goo, burn flames...). Hypnotise glide added for L9. |
| L9 | Hypnotise zone choice | merged 0326066 | |
| L10 | Themed fonts everywhere | merged 0e9aae7 | Project default font plus a symbols fallback subset (OFL). |
| L11 | Loak / Mimic copied art | merged d464003 | |
| L12 | View lobby only in menu | merged 7ed71c5 | |
| L13 | Click off closes menu | merged 7ed71c5 | |
| L14 | Opening deal in game 2+ | merged 7ed71c5 | |
| L15 | Sneaky Snunday rework | merged 0326066 | |
| L16 | Opponent-responding notice | merged cdcd8cd | Centred, then docks under the opponent plate after 2.2 s. |
| L17 | Badges inside the border | merged 21a532e | |
| L18 | Hourglass turns, sand falls | merged 21a532e | |
| L19 | Materials gone before On Summon | merged 0326066 | |
| L20 | Cleanse/Curse block the whole batch | merged 0326066 | |
| L21 | Pile click deselects | merged cdcd8cd | |
| L22 | Custom cursor + setting | merged 9d6b92d | 9 gilded cursors (arrow, gauntlet, reticle open/locked/barred, dagger plain/hot, forbidden, magnifier), sized by DPI; "Custom cursor" in Settings. |
| L23 | Evolve (Symbiotes) | merged d464003 | |
| L24 | Art for 189-191 | done 3251bd0 | |
| L25 | New table background | merged 0e9aae7 | Forest Ruins is the default. |
| L26 | Series results display | merged 7ed71c5 | |
| L27 | Smarter bot | merged | Fair (no hidden-info peeking), forecast-driven. Held-out seeds vs old bot: 65.8% (75.4% first, 56.3% second). Review: design/bot-review-2026-11-05.md |
| L28 | Options menu, tables, card back | merged 0e9aae7 | |
| L29 | macOS build on GitHub | merged fddc96a | Re-export at the end. |
| L30 | No keyboard hints anywhere | done 9eddfdc | Scan test ui_no_key_hints_test.gd. |
| - | Stale tests re-pinned | merged 2c34eec | 114 baseline failures fixed. |

## Extra improvements (found while working)

## Deviations for your review
