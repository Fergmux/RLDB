# Owner answers — production batch upfront questions

Date: 17 October 2026
Authority: answers supplied by the owner after reading the implementation agent's questions. These decisions override conflicting recommendations in the production-batch and Firebase request documents. Read this before implementing those specifications. Do not interpret unanswered autonomous proposals as explicit owner approval.

## 1. Deck limits

The combined Main + Extra Deck size may not exceed 99 cards. Within that combined total, the Extra Deck may contain no more than 15 cards. These are not separate allowances of 99 Main plus 15 Extra. Preserve the previous request to avoid adding visible limit labels/hints. Enforce validation consistently and preserve existing oversized saves safely.

## 2. Firebase plan and ingestion architecture

The project is on the free/default Firebase plan (Spark). The owner will not pay for or upgrade to Blaze. Implement an architecture that works on Spark, overriding the earlier preferred Cloud Function architecture wherever it requires Blaze. Do not enable billing or deploy paid-plan-only services.

Use appropriately constrained direct client submission if supported by Spark and the chosen Firebase services. Produce matching strict Firestore security rules; the earlier backend-only deny-all example cannot be used unchanged if the game writes directly. Authenticated users must not have broad access to others' records or authority to overwrite canonical aggregate statistics. Document the integrity limitations of client-submitted results and any statistics that cannot be securely finalized or aggregated without trusted backend processing. Do not pretend Security Rules verify actual gameplay. Stay within free quotas, with bounded silent retries; quota exhaustion must not impair the game. Prefer an authorized local/admin aggregation tool or later trusted processing over freely writable global totals.

## 3. Setup, deployment and local tools

The owner authorizes installation of Firebase CLI and Java, and deployment of security rules to the supplied Firebase project. Make CLI setup and the owner-assisted Firebase login the FIRST interactive implementation step so the owner can leave once authentication is complete. Ask the owner to complete login without exposing credentials or tokens. Perform emulator security tests with Java as needed.

After choosing a Spark-compatible architecture, deploy the matching secure rules. Avoid switching live direct-upload clients to deny-all without a compatible migration. Cloud Functions requiring Blaze remain disallowed. Do not generalize the permission to unrelated infrastructure changes or paid services. If CLI/Java are already installed, reuse them.

## 4. Online result agreement

Adopt the agent's recommended classification:

- Both player reports agree: verified.
- Only one report arrives: provisional; included in statistics by default, clearly flagged and filterable.
- Reports disagree: conflicted; excluded from statistics.

Preserve report provenance and prevent duplicate counting. A later agreeing report should upgrade provisional to verified without adding another result. A later conflict must remove an earlier included provisional contribution when aggregates are rebuilt/reconciled. On Spark, document how trusted classification/reconciliation is accomplished and any limitations rather than letting a client declare itself verified.

## 5. Retention

Keep all gameplay data indefinitely, overriding proposed 180-day/raw and two-year/report expiry. Do not configure automatic age-based deletion for these records. Keep a documented owner/admin deletion process, a collection kill switch and any required privacy controls. Monitor storage/quota growth under Spark. Bounded local retry storage is a separate implementation constraint and may still need eviction/limits with documented behavior.

## 6. Settings, privacy and player identity

Add a Settings checkbox labeled “Share anonymous gameplay statistics”, enabled by default, with a privacy note as appropriate. This is an explicit exception to the earlier no-telemetry-interface requirement; upload errors and operational details must still remain invisible to players. Honor disabling the setting for future collection/uploads and document the treatment of queued data. Do not claim opting out automatically deletes previously uploaded data unless implemented.

The owner wants a stable player ID tied to the player's Steam account, without storing the Steam display name or other unnecessary account information. This updates the earlier installation-only anonymous-profile proposal. Determine a secure supported linkage between Steam identity and Firebase identity; do not trust a freely supplied Steam ID or put private signing/admin credentials in the client. Do not assume anonymous Firebase auth alone provides stable cross-device Steam identity. If authenticated cross-device linkage is unavailable within Spark and current services, explain the limitation and choose a documented safe fallback instead of claiming it is solved.

The owner described the data as non-personally-identifiable because only player IDs are retained. Record that as their intent to minimize data, not a legal finding: stable Steam-linked IDs and longitudinal gameplay histories are pseudonymous identifiers and may still be personal data. Do not promise relaxed legal obligations or that default-on is necessarily sufficient for public release. Keep the privacy note accurate and identify any release-specific privacy questions separately; do not add unrelated data collection.

## 7. Environment labels

Use the recommended environment labels: playtest for current playtest builds, production for public release, dev for editor/development runs and test for automated runs. Explain the exact implementation and database impact in the final handoff.

Implementation guidance: stamp every submission and aggregation key with the environment; select the value through build/configuration, not arbitrary normal-player UI. Partition report/aggregate paths or query scopes consistently, and keep playtest/dev/test out of production aggregates by default. Explain that labeling does not itself create a separate Firebase project/database or reduce storage costs. Use separate projects for stronger isolation only if actually configured/authorized; do not claim labels alone are a security boundary. Preserve environment on offline queued uploads so a later build does not relabel historical records.

## 8. Draft-order input

Keep the no-drag-and-drop model. Remove draft-order dragging and retain up/down arrow controls for reordering. Preserve keyboard/focus behavior and order persistence.

## 9. Lone Warrior / Revealed starter deck

The third Extra Deck entry is unknown. Leave the deck with its two valid Extra Deck cards for now; do not import `#REF!` or invent a replacement. The owner will update this later.

## Agent-proposed autonomous decisions

The agent also proposed interpretations for `temp` conditions, The Illusionist, Stormcaller, Dante, Tag Team IDs and missing art references. The owner did not explicitly discuss these individually in this answer sequence. Keep them in the agent decision log as proposed/autonomous choices, check them against the updated CSV and confirmed rules, and report uncertain outcomes at completion. Do not label them owner-confirmed based only on silence.

## Immediate handoff order

1. Read this answer file and all three task specifications.
2. Install/reuse Firebase CLI and Java and obtain the owner-assisted Firebase login FIRST. Do not upgrade the project or enable billing.
3. Reconcile the Firebase design to Spark, safe identity linkage and strict direct-write rules; document any remaining genuine blockers up front.
4. Apply these limits/decisions to the durable task state, coverage and decision logs, then continue the unattended production workflow.

This file records decisions and implementation guidance. It does not assert any installation, login, deployment or Firebase change has already happened.
