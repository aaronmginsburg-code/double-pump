# Developer console development publication - 2026-10-25

**Published and independently cloud-source verified: development v63.** Owner approved desktop/mobile screenshots and the bottom-left-of-Pump-A mobile launcher, then explicitly authorized this deployment. No production publication or access change occurred.

## Destination and source

- Double Pump - Development: universe **10772492892**, start place **139437092998076**.
- Play: https://www.roblox.com/games/139437092998076/
- Audience verified in Creator Dashboard: **Only available to you and your collaborators**.
- Source branch `feat/development-training-bots`, implementation commit `80a1dca7b2c29bec7503ebdb8b98a514daab367d`.
- Excluded production: universe10772275012/place82505574993280. Its published-only history still lists **v10**, dated October21. Saved draft11 is not a new public publication.
- Source match: **131** permanent source paths/texts, digest31 **2381679486**. Exact environment IDs and owner allowlist11808586604 remain enforced. No temporary probes or negative Studio UserId grants.

## Publication evidence

Studio logged Published new changes in Double Pump - Development at **2026-10-25T22:29:38.084Z** (15:29:38 Pacific). Creator Dashboard Show published only lists **63**, followed by previous stable50. Dashboard timestamps the saved version October25 at15:26; that is not the later Publish-action time.

Closed the editor, reopened Double Pump - Development from Roblox's experience list, asserted PlaceVersion63 and both IDs, and recomputed the complete source digest. It matched131/2381679486 exactly. A fresh Studio Play from that cloud copy opened the approved mobile console from the new bottom launcher; all five categories were navigable, Auto Fire was OFF, ordinary firing consumed a shell and provoked the normal training duel. The bots eliminated the owner; respawning restored 100 HP and five shells in each gun. Pump B manually equipped and fired, and reload restored its magazine to five shells. This is **Studio testing of the published cloud source**, not an independent Roblox Player/hardware acceptance claim.

The normal-browser Play button was attempted. No Roblox Player window appeared in the available window inventory. Owner live-client testing is still needed, especially new-schema cloud preset save/rejoin, simultaneous touch feel and controller behavior. Studio API access remains disabled and was not changed. Offline CAS/validation/storage-failure tests passed; they do not prove cloud DataStore persistence.

## Checks

- **463 passed,0 failed** (37 new console regression cases).
- Private source compile check passed.
- Rojo verification build passed; source-only output was not published.
- StyLua passed on20 task-changed/new Luau files.
- Luau LSP blocked by missing configured Roblox global definitions; Selene blocked obtaining the Roblox API standard library. Neither is reported as a clean pass.
- Previous actual solo tests covered live server/client movement/weapon/audio changes, auto-fire server acceptance and UI cancellation, export, respawn, existing aim response and wall exclusion.
- Previous actual two-client Studio test covered unauthorized Apply/Save/Export denial and session-wide config/reset replication. A complete new multiplayer match soak after publication was not performed.

## Backups and recovery

- Prior source/docs: `development-copy/developer-console-20261025/backup/BEFORE_DEVELOPER_CONSOLE.zip` (CRC checked).
- Prior intact stable place: `development-copy/developer-console-20261025/backup/DoublePump_STABLE_v50.rbxl`.
- Approved source snapshot: `development-copy/developer-console-20261025/publication/APPROVED_PREPUBLICATION_SOURCE.zip` (CRC checked).
- Approved intact scene: `development-copy/developer-console-20261025/publication/DoublePump_APPROVED_DEVELOPER_CONSOLE.rbxl`, 432910bytes, SHA256`626368e7b38cb6952923c9d48c3838ef18bc690274d54986ba32a83af805a63d`.
- Previous HEAD before this task:8f0f59759538f0fef91cda449a3d98c9b01df40c. Preserve unrelated dirty work rather than resetting the checkout.

Rollback only the development experience to previous published50 through version history, then open/verify/publish that restored development version with authorization. Alternatively open the intact v50 backup and use the established development destination workflow. Never restore/publish over production. Schema2 console store `DoublePump_DevConsole_v2`/scope`u10772492892` is separate from legacy aim-only data and player profiles. Reverting stops reading schema2; no store deletion or profile migration is needed. See DEVELOPER_CONSOLE_ROLLBACK.md.

## Production isolation and evidence limits

All81 public source hashes still match the preserved pre-task baseline, including the pre-existing dirty ShotgunModel file. No source/configuration from this task was copied into public src, no production DataStore operation was performed, and published-only Dashboard history shows no new production release. Production DataStore contents were not exhaustively audited; the absence of writes is based on the isolated code/deployment paths and actions performed.

No asset uploads, monetization activation, audience change, new experience or Git push occurred. Unrelated dirty work remains preserved.

Screenshots: `docs/screenshots/developer-console/publication/`. Detailed logs and manifests: `development-copy/developer-console-20261025/publication/`.

## Owner acceptance

Leave any old development session and join the link above afresh as supersnapstudios. Tap **DEV** left of the ammo HUD, or press **F6** on desktop. Select a category and adjust values; defaults remain active until you change them and Auto Fire stays OFF initially. For persistence, name a preset, LOAD the empty/existing slot, adjust, SAVE then confirm, rejoin and LOAD the same name/scope. Report any failure message rather than changing Studio security settings. Reset ALL recovers defaults without overwriting saved presets.
