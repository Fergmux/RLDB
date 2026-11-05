# RLDB production-quality implementation prompt

Paste the prompt below into the existing Claude Code conversation. It is a continuation of the current game, not authorization to restart it. Prepared after reviewing Claude Code Game Studios' README, configuration effects map, team UI/polish/QA skills, and Claude Code's subagent model-selection documentation on 15 October 2026.

---

Continue this existing Godot game toward a production-quality playable build. Replace the earlier proof-of-concept/minimal-rigor execution approach with the higher-quality workflow below. Preserve working code, project settings, game rules and current progress. Audit and improve what exists; do not restart setup, create a second game project, or substitute a new prototype for the game.

## 1. Read the latest user requirements first

Start at the repository root. The Godot project/resource root is `rldb/`, with `rldb/project.godot`; account for this in tools, assets and tests.

Read these before planning or changing gameplay:

- `design/decision-register-answers.md`: the user's completed answers to P-01–P-31 and the four Sneaky Snunday topics. Read the final answers and superseding corrections, not just the first historical response in each section. This is newer authority than conflicting prototype proposals in `design/decision-register.md` or older open notes.
- `design/playtest-improvements.md`: the user's current playtest feedback, particularly I-01, I-02 and I-03. Implement these as real acceptance criteria, not optional suggestions.
- `design/references/field-layout.png`: the supplied board-layout reference. Inspect the image itself.
- `rules/00-START-HERE.md`, `01-GAME-RULES.md`, `02-STATUSES.md`, `03-CARD-CATALOG.md`, `04-VIDEO-GAME-DESIGN.md`, `05-BUILD-PLAN-AND-ACCEPTANCE.md`, and `06-OPEN-DECISIONS-AND-CORRECTIONS.md`: the full specification, original acceptance examples and source reconciliation. Read relevant source CSVs when validating import semantics.
- Existing stories, support ledger, tests and implementation notes so completed work is preserved and reopened only when new evidence requires it.

The current user instruction and the decision answers override the older execution advice in `07-BUILD-AGENT-PROMPT.md` and `08-POST-SETUP-FULL-GAME-BUILD.md`. They do not authorize silently changing game mechanics. Do not re-ask questions already answered in the companion answers file. Numerical draft settings are deliberately configurable and unspecified; unrestricted custom decks are intentional for this test bed.

## 2. Enable stronger studio coverage, and verify it actually takes effect

Read the installed `.claude/skills/settings/SKILL.md`, relevant configuration guidance and team skills. Prefer the installed workflows over assumptions about an upstream version. Set the equivalent of the following through the studio's settings skill:

```text
/settings modes.rigor=full
/settings docs.density=balanced
/settings modes.review_mode=full
/settings team.size=studio
/settings qa.level=full
/settings platform.multiplayer=true
```

Full rigor is the new quality/process baseline. Balanced documentation is intentional: keep required specifications complete but concise, and reuse existing documents rather than spending the whole run rewriting them. Team size means specialists are available, not that all agents run on every change.

Inspect effective values and their sources afterward. Check `project.local.yaml`, explicit overrides and legacy settings for values that still force `solo`, `individual`, minimal QA or a lower workflow despite the rigor change. Reconcile conflicting settings with this request and report the effective result. Verify the per-type `testing.strict` settings for logic, integration, visual, UI and config/data evidence; failed required checks must block declaring affected work done. Do not use one invented global boolean or disable checks to get a green status.

Preserve the user's current automation preference. Higher rigor and review do not require asking permission for each routine implementation detail; continue authorized reversible work. Respect actual tool restrictions and ask when material unresolved game behaviour or external credentials are truly needed. Do not change permission-bypass settings as part of this instruction.

## 3. Coordinate specialists and route models deliberately

Use the installed studio hierarchy and actual skills. The lead owns architecture, interfaces, integration and the completion ledger. Give each task a clear scope, source references, file ownership, expected output and acceptance conditions. Run independent tasks in parallel; serialize edits to shared files. Bring in whatever relevant specialists the work needs, including Godot/GDScript, gameplay, UI/UX, art direction, technical art, networking, accessibility, performance and independent QA. No need to spawn unrelated narrative or marketing agents.

Do not confuse role seniority with model cost. Many shipped agents use `inherit`, so a simple task can otherwise consume the main model's expensive context. Route each delegated task explicitly when supported:

- Use an available lightweight model, preferably the `haiku` alias, for bounded catalogue/schema audits, evidence indexing, log summaries, straightforward test execution and mechanical checks with clear expected results. Review its output and escalate uncertain findings.
- Use `sonnet` for most substantive Godot implementation, UI construction, effects, test authoring and bug fixing.
- Use `opus` or the strongest available reasoning model selectively for architecture, difficult rules/timing interactions, multiplayer privacy/reconnection, integration decisions and high-risk independent review.

Use the Agent invocation's model override where supported, which can override a subagent's declared model. Check the installed Claude Code capability and actual model availability rather than pretending a requested tier ran. Report substitutions. Do not set a global model override that accidentally sends every critical task to the lightweight model. Do not assign a complex subsystem to Haiku just because its specialist has a junior title. Record a concise task/role/model/result ledger; spend tokens on useful implementation and verification rather than duplicated analysis.

## 4. Use the studio pipelines to deliver the work

Audit the runnable build and reconcile decision answers with code before adding polish over incorrect mechanics. Turn gaps and the playtest improvements into implementation stories with measurable acceptance conditions. Use the installed `/create-stories`, `/dev-story` and `/story-done` workflow where appropriate; do not mark a story complete on code generation alone.

For presentation, use `/art-bible` and `/ux-design` to capture a concise coherent direction, then `/team-ui` to implement the board/card interaction changes. Use `/ux-review` for flow/clarity and `/team-polish` for actual feel, effects and performance. Use `/team-qa` for independent scenario testing and adversarial cases. Use `/code-review`, `/perf-profile`, `/security-audit`, `/regression-suite`, `/test-evidence-review`, `/gate-check` and release checks when relevant, using the argument syntax from each installed skill. These are tools for specific jobs, not a requirement to run every skill for every button.

Announce the resolved active team for orchestrated runs. Ensure implementation agents are actually included where a pipeline needs to change code; a polish report that merely hands off an optimization list is unfinished until those changes are implemented and reverified. Director/review depth, team composition and model selection are separate controls. Do not assume `--review full` alone enables a larger team.

## 5. Make the requested visual and interaction improvements tangible

Implement I-01's geometry from the image: aligned central two-by-three unit blocks; local Trap row beneath and opponent Trap row above; local two-by-two Power grid right and opponent Power grid left. Power zones portrait, Trap zones landscape, unit slots approximately square. Preserve responsive sizing and clickable hit areas on both clients.

Implement I-02: show legal action buttons directly on a hovered card, not as a journey to the right-hand details panel. Keep controls stable as the pointer moves onto them. Preserve full effect/modifier/status inspection separately. Legal actions must reflect turn, phase, cost, targets and pending-response locks.

Implement I-03 as a cohesive visual direction between Hearthstone's tactile, readable card presentation and The Witcher's darker fantasy atmosphere. Create original frames and UI, not copied franchise art. Improve typography, visual hierarchy, card materials, cost/stat badges, lighting, highlights and spacing. Use deliberate animation and effects for draws, plays, attacks, health changes, destruction, statuses and phase transitions. Aim for satisfying feedback and clear causality rather than busy particles or merely swapping a background colour.

Readability, smooth interaction and responsiveness are required. Keep status counts and changing stats visible. Avoid layout jumps, accidental clicks, clipped text, hover flicker and effects that obscure target selection. Separate authoritative state transitions from presentation animations so visual timing cannot duplicate actions or desynchronize clients. Provide restrained/reduced motion behaviour where appropriate without changing game timing.

The user will provide card artwork separately. Make substantial progress with polished frames, typography, shaders, procedural effects and placeholders. If specific external imagery is needed, provide a short asset request listing purpose, dimensions/aspect ratio, transparency and style. Do not pretend filenames mean image assets exist or block all implementation while awaiting art.

## 6. Preserve the complete game, not just its appearance

Keep all 183 cards and their corrected behaviours on an explicit support/verification ledger. Correct the user-approved decisions, including Burn after uncanceled battle, on-summon before summon traps, Nimble main-phases-only, stacked Mastery/Options, card-specific Chains/Yamata wording, Magic Cylinder's unit-target column condition, and depth-first per-card Plan B resolution with ordered target selection and healing last.

Complete button-driven legal choices, automatic rules calculations, all special summons, live stats/statuses, log, two-player networking, Steam matchmaking/invitations, reconnect handling, custom decks/drafting, both-player rewards, configurable series and between-game save/resume. Remember the one-minute optional host victory is for the current game only. Pending legal trap responses wait indefinitely; do not add dummy prompts where no legal response exists.

Protect hidden card identities and Draw order in UI, prompts, logs and network payloads. Owner's Draw inspection may show contents in randomized display order without changing actual Draw order. An effect may expose a hidden selection pool only as specified. Multiplayer game state is authoritative; client-side animation or buttons must not decide legality.

Keep the action history useful: actual event order, calculations and effect explanations, without revealing private information. A pretty local demo is not a substitute for correct two-client play and the series flow.

## 7. Prove quality and continue until the gaps are closed

Start with a reproducible baseline and representative before screenshots. Choose/document suitable performance targets rather than claiming unspecified numerical budgets were user-approved. For each increment run the appropriate rules/regression tests, launch the game, inspect the changed screens and exercise actual interactions. Retain meaningful screenshots or recordings under `production/qa/evidence/`.

Test with two clients through a full match and configurable series, including attack/effect selections, multiple/nested Trap prompts, optional triggers, hidden piles, ordered destruction, card details, log inspection, reconnect during a pending choice, and between-game save/resume. Test the UI at its intended window sizes and scaling. Use independent QA to find failures rather than simply confirm the implementer's claims. Fix and rerun failed cases. Run human-visible visual checks on an interactive desktop; if the screen is locked or capture is unavailable, mark visual evidence blocked and continue other checks without claiming a visual pass.

Verify Steam functionality in a suitable real environment. Identify missing credentials/integration setup concretely, isolate external blockers, and continue work that does not depend on them. Do not call untested Steam or reconnect code verified. Never weaken acceptance criteria merely to mark work complete.

Continue in runnable, integrated milestones. Do not stop after setup, a design report, a mockup, one polished screen or a partial card subset. At completion, reconcile every confirmed requirement and playtest improvement against working behaviour and evidence. Report what is playable, which acceptance tests passed, remaining defects/blockers, asset needs and how to run the result. Call it production-ready only to the extent the checks support that claim; a framework setting or agent verdict is not proof by itself.

Begin by reading the latest decision answers and playtest feedback, inspecting the current game, resolving the effective studio settings and presenting a short prioritized implementation plan. Then carry out the plan.

---

## References used to prepare this prompt

- [Studio README and configuration](https://github.com/Donchitos/Claude-Code-Game-Studios#configuration)
- [Configuration effects map: rigor, teams, QA and overrides](https://github.com/Donchitos/Claude-Code-Game-Studios/blob/main/.claude/docs/effects-map.md)
- [Team UI workflow](https://github.com/Donchitos/Claude-Code-Game-Studios/blob/main/.claude/skills/team-ui/SKILL.md)
- [Team polish workflow](https://github.com/Donchitos/Claude-Code-Game-Studios/blob/main/.claude/skills/team-polish/SKILL.md)
- [Team QA workflow](https://github.com/Donchitos/Claude-Code-Game-Studios/blob/main/.claude/skills/team-qa/SKILL.md)
- [Claude Code subagent model selection](https://code.claude.com/docs/en/sub-agents#choose-a-model)
