# Developer console recovery and rollback

## Preserved baseline

- Branch feat/development-training-bots, starting HEAD8f0f59759538f0fef91cda449a3d98c9b01df40c.
- Recoverable source/docs archive: development-copy/developer-console-20261025/backup/BEFORE_DEVELOPER_CONSOLE.zip.
- Intact previous development place: same folder/DoublePump_STABLE_v50.rbxl.
- Starting dirty-state and Git HEAD records are in the backup folder. Preserve unrelated dirty work when recovering; extract to a separate folder and compare rather than resetting the repository.

## Session recovery

Use RESET with scope ALL, or restart the local test server to recover defaults. Presets never autoload. DataStore failures leave the active session untouched. Old aim-only saves are unchanged.

## Place recovery after a separately authorized future publication

Restore the intact previous place using Studio and publish only after verifying development universe10772492892/place139437092998076 and receiving the required approval. Alternatively use Creator Dashboard version history to restore the verified previous development version. Production place82505574993280 is excluded.

No current rollback publication is needed: this revision is awaiting UI approval and has not been published.

The schema2 console store is a separate namespace; reverting to v50 simply stops reading it. Do not delete stores, reset player profiles or copy experimental values into production. Legacy aim store remains readable by v50. Keep schema2 preset data for subsequent compatible development builds.

## Local review candidate

Final intact place: `development-copy/developer-console-20261025/evidence/DoublePump_DEVELOPER_CONSOLE_FINAL_REVIEW.rbxl`. All131 source containers compared in Studio. SHA256`7a932eb9422a3a75df8fba87a91bcc520e19af90c62fb094b1996eb31e160562`. Source/docs snapshot: `development-copy/developer-console-20261025/backup/DEVELOPER_CONSOLE_LOCAL_REVIEW_SOURCE.zip` (CRC integrity checked). Baseline archive also CRC checked. No Git commit or deployment yet.
