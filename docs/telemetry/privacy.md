# RLDB gameplay statistics: privacy note (draft for the release)

Status: an accurate description of what the current build does. It is NOT legal advice. The owner's
view that the data is non-personal is recorded as an intent to minimise data, not as a legal
finding: a stable pseudonymous id plus a long gameplay history may still be personal data (for
example under the UK and EU GDPR). Review this before public distribution. Release questions are
listed at the end.

## Player-facing text (Settings, under "Share anonymous gameplay statistics", on by default)

> Sends anonymous match statistics (draft picks, decks, cards played, game times and results) to
> help balance RLDB, and keeps your own statistics with a one-way code made from your Steam account
> so they follow you to other computers. No names, chat or Steam profile details are sent. Turning
> this off stops collection and syncing and deletes statistics not yet sent.

(`Telemetry.PRIVACY_NOTE`, updated 20 Oct 2026 for C1 and C2.)

## What is collected

- Gameplay only: draft offers and picks, reward choices, starting decks, cards drawn, played and
  activated, duel and series results, turn counts, HP and AP totals, and (since 20 Oct 2026) how
  long each duel and each turn took, and the name of a structure deck played (fixed game content;
  custom deck names are not sent in match statistics).
- The player's own statistics (see "Cloud statistics" below).
- Identifiers: a random Firebase anonymous id for this installation, a random profile id, random
  series/duel/session ids, and, when Steam is running, a salted one-way hash of the Steam ID.
- Technical: game build, card-data version, operating system family (for example "Windows"),
  timestamps.

Not collected: names, Steam persona names, raw Steam IDs, chat, email, friends or contacts, device
fingerprints, IP addresses (Firebase may still see them as part of any HTTPS request), pointer
movement or anything outside RLDB matches.

In network games the host's report includes both seats' gameplay, including cards the opponent
held. This goes only to the developer's database, never to the other player and never into the
multiplayer game log.

## Cloud statistics (20 Oct 2026)

- What: the record shown in Decks > Statistics: the player's finished duels (mode, result, turns,
  duel and own-turn time, deck name, starting deck card ids, cards played, summons, damage), series
  results and draft-pick counts. This includes the names the player gave their own custom decks.
- Where: one Firestore document per player, keyed by the salted Steam-ID hash; the raw Steam ID is
  never stored. Only an anonymous install that has claimed that hash can read or write it.
- Integrity: the claim is not verified (owner decision). A modified client could read or change
  another player's statistics if it knows or computes their hash (the salt ships in the game). Treat
  the hash as pseudonymous, and the document as self-reported.
- Without Steam, with the setting off, or offline, statistics stay on this computer only (the
  Statistics window says so). Turning the setting off stops syncing; the cloud copy stays until the
  owner deletes it (`delete-stats <hash>` or `delete-uid <uid>` in the admin tool).

## Player control

- The setting is on by default. Turning it off stops all collection and upload at once, and the
  local queue of statistics not yet sent is deleted from the device.
- Statistics already sent are not deleted automatically when the setting is turned off. The owner
  can delete every record of one installation with the admin tool (`delete-uid`). The player needs to
  tell the owner their installation id: the developer tool `--inspect` prints its first characters,
  and a player-facing way to read it does not exist yet (release question 3).
- Data is kept indefinitely (owner decision, 17 Oct 2026). There is no automatic age-based deletion.

## Release questions for the owner

1. Is default-on with this note enough for the release markets (GDPR and UK GDPR consent or
   legitimate-interest basis, store-page disclosure, children)? Get advice.
2. Indefinite retention needs a stated purpose and a review point in the privacy policy.
3. Deletion requests need a contact route and a way for players to find their id.
4. The Steam hash is reversible by anyone who holds both the salt (shipped in the game) and the data.
   Treat it as pseudonymous, not anonymous.
5. Firebase (Google) is a processor. Its terms and data location (Firestore `(default)`) belong
   in the privacy policy.
6. Cloud statistics include free-text custom deck names typed by the player and can be read by
   anyone who claims the player's hash (unverified link). Decide whether the privacy policy should
   name this, or whether custom deck names should be left out of the cloud copy.
7. A player-facing way to delete the cloud statistics does not exist yet (owner tool only).
