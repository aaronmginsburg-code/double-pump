# Roadmap

Ordered. Steps marked **(owner)** need Aaron's action or explicit approval; Codex
prepares them but does not do them alone. Status as of 2026-10-21.

## 0. Consolidate the repository

- [ ] Merge PR #2 (`claude/full-game-build-3jb3hx`) into `main` once reviewed **(owner)**.
- [ ] Decide how the shotgun asset is kept **(owner)**: merge PR #1 as is (170 MB plain
      git), move the large binaries to Git LFS first, or keep PR #1's branch as an
      archive and only commit the imported `.rbxm` files to `main`. Never delete the
      branch until one of these is done.
- [ ] Decide public vs private repository **(owner)**.
- [ ] Add CI (GitHub Actions): `rokit install`, `lune run tests/run.luau`, `selene src`,
      `stylua --check`, `rojo build`, and a type check that fails on errors.

## 1. Get the game running in Studio

- [ ] Import the shotgun (FP, TP, spent shell) and commit the three `.rbxm` files
      (`ASSET_PIPELINE.md` step 1, `ASSET_UPLOAD_MANIFEST.md` §1–2) **(owner, Studio)**.
- [ ] Solo play check in Studio; fix anything broken.
- [ ] First private publish and Studio API access **(owner)**.
- [ ] Upload 29 sounds and 3 map images, fill `AssetIds.luau` **(owner approval)**.
      Fix the decal-ID fallback in `tools/upload_assets.py` first if using the script.

## 2. Playtest and fix

- [ ] Work through `PLAYTEST.md` in Studio (solo, then Clients and Servers with 2–4).
- [ ] Private live test with real players and devices (PC, phone, controller).
- [ ] Collect F2 performance numbers; measure map build time on a live server.
- [ ] Tune weapon timing, damage and falloff from feedback (config only).

## 3. Confirm open design decisions **(owner)**

- [ ] Shield (100 HP + 100 shield) or HP only.
- [ ] Swap/equip timing: keep 0.15 s swap / 0.4 s interval / 1.0 s cooldown, or return
      to the earlier easy baseline.
- [ ] Movement: bring back sprint/slide/prone from the prototype, or stay minimal.
- [ ] Round length and score target; shield pickups.

## 4. Release prep

- [ ] Icon (512×512), gameplay thumbnails, description, logo for `AssetIds.Images.Logo`.
- [ ] Experience Questionnaire, max players 10, R15 **(owner)**.
- [ ] All `GameConfig.Debug` flags false.
- [ ] Optional Robux coin packs (`PUBLISHING.md` step 3) **(owner, real money)**.
- [ ] Go public **(owner)**.

## Later (planned, not implemented)

- More weapon types (launch is shotguns only by decision).
- Bots / backfill for low-population servers.
- Weekly or seasonal leaderboards.
- Model-based skins (current skins are colour tints).
- More maps; revisit `StreamingEnabled` if maps grow.
