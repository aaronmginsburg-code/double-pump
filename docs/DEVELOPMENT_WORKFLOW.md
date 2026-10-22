# Sustainable Double Pump development workflow

ChatGPT Project → Codex development → GitHub repository → Testing → Roblox publication → Updated documentation → Obsidian knowledge base.

## Source-of-truth rules

Repository/GitHub: code, architecture, configuration and detailed tests/docs. Roblox: deployed version and access. ChatGPT Project: planning/prompts from uploaded snapshots. Obsidian: curated decisions/history/navigation. None synchronizes the others automatically.

## Each substantive session

1. ChatGPT reads the newest four reference documents and produces an owner-scoped Codex prompt, separating evidence from proposals.
2. Codex inspects actual repository/branch/status and Studio/cloud identity. Preserve dirty work, stable binaries and history before edits; never assume main/the original prototype is current.
3. Implement the approved bounded change, retaining server authority and desktop/mobile compatibility. Do not infer balance, monetization, upload or publication approval.
4. Run regressions and required checks. Perform scoped Studio multiplayer and physical-device/live checks; label mocks, staging, failures and unexecuted cases. Never publish probes/capture places.
5. Review diff and secrets; create a factual Git checkpoint and push only when authorized. Do not force-push, rebase or merge by inference. Draft checkpoints before full acceptance must be labeled.
6. With publication authorization, back up the previous build, build from identified source, compare Studio/cloud sources and relevant properties, publish to existing IDs, verify version/access and a fresh server. Public access requires separate final approval.
7. Update PROJECT_STATUS; AI_HANDOFF for architecture/features; GAME_DESIGN for rules; ROADMAP for priorities; RELEASE_RECORD for publication. Append CHANGELOG and significant supported decisions with dates. Preserve old reports/Git history.
8. Obsidian: read vault AGENTS/Vault Guide and manager PROJECT_MIGRATION_STANDARD, find canonical notes, list exact writes, preserve originals, use reviewed Invoke-WithVaultWriteLock for synchronous writes and immediate checks only. Update curated notes/session/navigation; do not copy huge code/logs. Validate YAML/links and unchanged unrelated notes. Backup allowlist changes and vault commit/push require their own approval.
9. Tell the owner which four ChatGPT source files to replace, plus RELEASE_RECORD if uploaded. Refresh the set together, removing ambiguity from stale duplicates. Moving chats does not sync source copies.

For minor edits update only affected canonical documents; use dated session records for substantive work. Keep one Obsidian task checklist in Known Issues and Next Actions and link to it.

## Resume and safeguards

Read handoff/status, inspect HEAD/dirty work, confirm cloud version, then choose a bounded task. Recheck account-dependent release requirements. Preserve DoublePump_Profiles_v1, prototype, asset branch and stable backups. Leave paid products off until separately approved and validated. State exact owner-only actions and never report an attempted action as success.
