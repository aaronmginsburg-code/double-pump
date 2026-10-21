# CLAUDE.md

The rules for any AI agent working in this repo, Claude included, are in
[AGENTS.md](AGENTS.md). Follow them. The current state and remaining work are in
[docs/AI_HANDOFF.md](docs/AI_HANDOFF.md) and [docs/PROJECT_STATUS.md](docs/PROJECT_STATUS.md).

Notes specific to Claude cloud sessions:

- The Roblox API dump download used by `selene` fails in these containers; a lint result
  from a container needs a local API dump or must be marked unverified.
- `rokit` may not be available; the pinned tool versions in `rokit.toml` can be fetched
  directly from their GitHub releases.
- Shotgun asset sources also exist in the Claude project folder
  `/mnt/project-files/DoublePump/`, but the authoritative copy is the
  `claude/project-thread-lv25xu` branch on GitHub.
