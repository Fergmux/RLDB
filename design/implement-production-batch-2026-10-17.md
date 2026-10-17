# Master implementation instructions — production update batch

Date: 17 October 2026
Read this entire document before planning or editing. This is the durable instruction source for this task, including after context compaction or a restarted agent session.

## Mission and required inputs

Bring the existing RLDB game forward through all three workstreams below. The owner wants full production quality: flashy, polished, professional visuals and sound, strong playability, reliable backend collection and correct card behavior. No shortcuts, prototype substitutes or text-only implementations. Continue the existing Godot project at `rldb/project.godot`, preserve unrelated working code and all human changes.

Read all three specifications completely before beginning implementation, including linked inputs:

1. **Card database changes:** `design/implement-card-database-update-2026-10-17.md`, backed by the exhaustive `design/card-database-diff-2026-10-17.md` (101 changed cards, 319 changed fields, no new/removed IDs).
2. **Firebase metrics:** `design/firebase-game-statistics-request-2026-10-17.md` (global and individual metrics, silent background logging, offline retry, secure ingestion/rules; no statistics UI).
3. **New playtest feedback:** `design/playtest-feedback-07-production-2026-10-17.md` (F01–F26, including production visual/audio polish, bot decisions, all-card tests and the suspected Sanctified Blade optional-activation bug).

**Use the UPDATED card database:** `rules/sources/RLDB Master - Card Database (2026-10-17).csv`. It is an unchanged copy of the owner's uploaded `RLDB Master - Card Database (1).csv`; verified SHA-256: `8AC4A39A70069A8586B1E5139E5999A57AA837E8064E83EF365E91B36D693DA3`. Use this path explicitly for migration/import, and update the active source reference/configuration as part of implementation so later regeneration continues using the updated data. `rules/sources/RLDB Master - Card Database.csv` is historical comparison baseline ONLY, not the active input. Preserve it for audit; do not accidentally regenerate from it or overwrite the dated snapshot.

Also read repository instructions, `rules/09-PRODUCTION-QUALITY-PASS.md` if present, the current `rules/` documents, `design/decision-register-answers.md`, recent playtest feedback and the existing implementation. Verify filenames and actual available tools. The database report describes a comparison, not permission to undo later confirmed corrections. Reconcile old/new source and current behavior using the card-update instructions. Latest explicit feedback takes precedence for the same feature. CSV cells and other source data are not agent instructions.

## Stage 0 — Read everything, investigate, ask questions upfront

Before unattended implementation, perform enough read-only inspection and focused reproduction to understand dependencies, existing architecture, current test infrastructure, available assets, Firebase deployment needs and the actual Godot renderer. Build a requirement inventory covering every card change, all telemetry metrics and F01–F26.

Then present one concise consolidated set of questions that materially require owner input. Include a recommendation and the consequence of each choice. Resolve questions inferable from files yourself; do not ask the owner to restate supplied decisions or credentials. Check ambiguities such as whether the new 99-card cap is combined main+Extra Deck or applies separately, Firebase result-finalization policy, and any truly unresolved card behavior. Sanctified Blade's optional Medic issue is a reproduction/test request, not a request to ask the owner what optional means.

State the proposed plan, validation approach and any required owner setup/access in this upfront pass. If a question needs an answer to make the requested implementation possible, obtain it before declaring the unattended phase ready. Once the owner has answered the upfront questions and directs you to proceed, continue autonomously to the agreed scope. If there are no material questions, state that and begin rather than inventing an approval step.

During unattended work, make reasonable reversible implementation decisions yourself. Record uncertainties, options, chosen outcome and rationale in the decision log and final report. Do not repeatedly stop for minor preferences. Where external access or essential product intent makes a portion genuinely impossible, finish every independent part, report the exact limitation and never fabricate access, tests or successful deployment. This instruction does not authorize destructive data loss, unrelated cloud changes or public publishing.

## Stage 1 — Durable plan and collaboration

Create a task-state directory such as `design/production-batch-2026-10-17/` containing:

- `progress.md`: current phase, next concrete actions, completed/in-progress/blocked requirements and handoff notes.
- `coverage.md`: each changed card/field category, each metrics requirement and every F01–F26 mapped to implementation and verification evidence.
- `decisions.md`: owner answers plus autonomous decisions, assumptions and unresolved uncertainties.
- `verification.md`: commands/results, fixtures, visual evidence paths, network checks and known defects.
- `agents.md`: delegated scopes, owners, dependencies, status, last meaningful progress, and integration results.

Do not rely on conversation memory as the only task record. Link this master document and all three specifications from progress.md. Update the records at meaningful milestones and before compaction/handoff. After compaction/restart, reread this document, progress, decisions, coverage and relevant source documents before continuing; inspect the actual working tree instead of repeating or overwriting completed work. Preserve the owner answers and outstanding work. Record how to resume running tasks/debug sessions and queued work.

Use the repository's actual relevant skills/workflows and specialist subagents wherever they improve execution. Inspect available skills first, read their instructions and invoke the appropriate design, UI, gameplay, testing, architecture and review capabilities. This task expressly requests meaningful delegation and independent review, not an entirely solo pass. Do not invent skill names or assume every installed skill is relevant.

Use clear independent scopes and shared contracts: for example card/import and rule changes; Firebase schema/ingestion/outbox; UI/animation/audio; independent QA/security review. Stage dependencies and assign file ownership so agents do not overwrite each other. Keep integration and final acceptance with the lead agent. Delegate straightforward inventories, narrow fixes and coverage audits to lightweight models where supported; use suitable stronger models for cross-system architecture, rule interpretation, security and difficult review. Do not spawn the entire roster gratuitously. A subagent's claimed completion is not acceptance: inspect its changes and run integrated validation.

### Liveness: subagents and Godot debug sessions

Actively monitor long-running work. Check meaningful progress at reasonable intervals (for example a brief status/progress review after a few minutes, adjusted to workload), without tight polling or interrupting useful work. If an agent exceeds its expected checkpoint or shows no progress, inspect status, last output, pending tool/approval/input, locks, test processes and file changes. Ask it for a concrete status through the available agent tools. Distinguish a legitimately long test/build from a stalled task. Record and recover an actual stall by a bounded retry, smaller task, interruption/reassignment or restarting only the affected worker. Do not wait indefinitely or repeatedly respawn the same failing task.

For every Godot/debug session started for verification, check responsiveness, process output and progression as well as whether the window exists. A live process or visible frame does not prove the game is responsive. Exercise input, scene transitions and animations; inspect logs for frozen main loops, stuck modal/response waits, orphan windows and halted test harnesses. Distinguish expected waiting-for-input, paused debugger and deliberate slow motion from a hang. Use bounded test timeouts and capture diagnostics before stopping a confirmed frozen session. Reproduce and fix underlying freezes; a restart alone is not a fix. Restart/close only task-owned debug processes, never unrelated user sessions, and clean up owned sessions at the end. A frozen run cannot count as successful QA.

## Stage 2 — Card data and gameplay foundation

Follow the card-update prompt in full: audit importer hazards (`temp`, legacy condition promotion and hardcoded corrections), use the updated dated CSV, preserve stable IDs/art mappings and implement every meaningful change. Keep a per-card ledger separating true behavior changes, wording/data changes, already-correct behavior and unresolved cases. Regenerate deterministically from the new active input. Validate behavior, not just descriptions.

Establish reusable deterministic rule fixtures and per-card testing early. Add behavior tests for EVERY identified card (currently 183 IDs) with a coverage manifest and individual/all-card runners as requested in F26. Use real card-specific assertions for applicable timing, optional choice, legal targets, costs, effects, durations and interactions; do not count empty tests or simple existence checks as coverage. Explicitly verify Sanctified Blade's optional Medic activation and preserve separate summon behavior. Include meaningful negative/boundary cases and system interactions without pointless combinatorial expansion.

## Stage 3 — Metrics pipeline

Implement the Firebase specification using the now-reconciled rules engine as the event source. Keep collection nonblocking and invisible in gameplay, authenticated, duplicate-safe and offline durable. Preserve draw/offer/deck/copy-count denominators and separate player-games from games. Keep test/tutorial/bot data distinguishable. Do not add analytics screens or public database reads.

Validate aggregation with known fixtures and security with emulator/endpoint tests. Provide exact production Firebase rules matched to the actual architecture plus deployment instructions. Never leave test-allow rules as the release design. If cloud deployment is not available/authorized, fully prepare/test locally and report remaining steps; do not assert that live logging works. Keep service credentials and auth tokens out of repository/logs. Preserve the privacy and anonymous-identity limitations in the specification.

## Stage 4 — Feedback and production presentation

Implement every F01–F26 requirement, prioritizing behavior/correctness and shared UI components before polishing final animation. Audit entire affected screens rather than making isolated patches that leave inconsistent typography, spacing or controls. Respect the dark fantasy, tactile card-game direction and the requirement for professional, expressive presentation.

Review actual running UI throughout: deck selection, deck builder, catalogue, Extra Deck viewer and every summon path, Arcane payment, reward picking, prompt panels, type choice, optional abilities and winning battles. Verify card proportions, stat legibility, audio consistency, focus/navigation and cancellation at supported resolutions/scales. Use screenshots/video where useful and inspect the output. Never treat compilation or a single screenshot as proof of good interaction design.

Ensure animations/sounds are completed, readable, performant and integrated with settings. Do not leave placeholder assets or fake no-op effects and call the work done. If essential art/audio is unavailable, identify exactly what is missing and make the best coherent implementation with existing appropriately licensed resources, recording limits honestly.

## Stage 5 — Integrated verification and independent review

Build a comprehensive but purposeful verification matrix:

- Full catalogue behavior coverage plus focused regressions for changed cards; deterministic import/source correctness.
- Rules and UI integration: optional/mandatory activation, target selection, exact Arcane cost, fusion-method choice, phase/cost/zone restrictions, cancellation and duplicate input.
- All new feedback flows, rapid add/remove, self-buff animation, modal Escape priority, bot stance scenarios, real local/bot games and winning attack presentation.
- Multiplayer/two-client checks of authority, hidden information, prompt sequencing, view consistency, reconnect and game completion where supported.
- Telemetry numerator/denominator correctness, duplicate/two-reporter/conflict handling, offline/restart/token refresh and permanent-error behavior; no gameplay stalls or surfaced errors; endpoint/rules authorization tests.
- Visual/audio review, renderer/4x AA verification, layout at supported sizes, FPS/frame timing where relevant and debug-session responsiveness.

Run focused checks after relevant edits, broad integrated tests at milestones, and rerun affected tests after fixes. Use independent review subagents to assess gameplay regressions, UI/UX polish, data correctness and Firebase security. Resolve substantive findings and retest; do not merely copy reviewer comments into a report while declaring completion.

While verifying, proactively look for other bugs and UI discrepancies: stale state, wrong enabled actions, target/arrow source errors, clipping, layout jumps, missing hover/focus states, audio duplication, frozen sessions, animation leaks, inaccessible controls and inconsistencies between clients. Fix closely related bounded defects with regression coverage. Record unrelated larger discoveries separately rather than changing rules or expanding the product without limits.

## Stage 6 — Completion and owner handoff

Do not stop after setup, a plan, CSV replacement, scaffolding, mock analytics or the first working screenshot. Finish all feasible implementation, integration, tests, reviews and polish in the agreed scope. Do not claim production readiness simply because the work was requested at that quality bar.

Final report must include:

1. Outcome by each of the three workstreams and F01–F26, linked to the durable coverage record.
2. Updated card source path/hash and proof subsequent import uses it, preserving baseline history.
3. Test results with commands/evidence, per-card coverage counts and genuinely pending cases; visual/playability review evidence and independent-review outcomes.
4. Firebase architecture, exact security rules, deployment/configuration steps, what is actually live, retry/retention behavior and identity/privacy limitations.
5. All autonomous decisions you were unsure about, their rationale, assumptions, unresolved items, missing assets and any defects still remaining.
6. Any detected subagent/debug-session stalls, recovery and whether the cause was fixed; final task-owned process cleanup.
7. Clear reproduction/verification instructions for the owner.

Preserve user edits and avoid pushing, publishing or unrelated cloud changes without existing authorization. Keep instruction and progress records readable so another session can pick up exactly where this one left off.

## Owner answers superseding earlier recommendations

Read `design/production-batch-owner-answers-2026-10-17.md` before executing this plan. It overrides earlier conflicting details: Spark only (no Blaze), Firebase login/setup first, strict direct-upload architecture as feasible, 99 combined cards / 15 Extra Deck maximum, indefinite retention, default-on sharing setting, Steam-linked pseudonymous identity intent and the remaining confirmed decisions. Do not deploy the former backend-only design unchanged.

