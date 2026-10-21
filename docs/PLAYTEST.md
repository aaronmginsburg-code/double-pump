# Playtest checklist and report

**Status: not yet playtested in Roblox.** The game was built in a cloud environment
without Roblox Studio, so nobody has played it yet. Everything below is still to do. The
automated tests (`lune run tests/run.luau`) cover the rules and map layouts, not how the
game feels or performs. Fill in the Result column as you go and keep this file as the
record; don't tick a line you didn't actually see.

Press **F2** in game for the debug overlay (FPS, frame time, ping, memory, instance count,
and each gun's state) when you need numbers.

## How to test

- **Solo in Studio**: Play. You land in the practice range.
- **Match in Studio**: **Test > Clients and Servers**, 2 to 4 players, **Start**. Each
  window is a player. Studio runs every client on one machine, so its frame rate and ping
  say nothing about real devices.
- **Real devices**: publish privately (`docs/PUBLISHING.md`), invite testers.
- **Ten players**: only a real server with ten people (or ten accounts) tests a full
  match. Record how many players were actually in each session.

## Session log

| Date | Build (commit) | Where (Studio / live) | Players | Devices | Who |
|---|---|---|---|---|---|
| | | | | | |

## Checklist

### Core weapon

| Check | Result |
|---|---|
| LMB fires once per click; holding doesn't auto-fire | |
| Same gun can't fire again for 1.0 s | |
| Fire A, swap, fire B lands about 0.4 s apart and no faster | |
| Swapping never fires; firing never swaps | |
| 1 / 2 / Q / wheel switch guns; the HUD shows which is out | |
| Each gun keeps its own ammo; reload one, the other is unchanged | |
| Reload is shell-by-shell; firing or swapping interrupts it and keeps loaded shells | |
| Empty gun auto-reloads; empty click sound when firing empty | |
| Point-blank body shot about 90, headshot about 157; less with distance | |
| Hitmarker for hits, a different one for headshots | |
| Double-pump elimination callout appears for fire-swap-fire kills | |
| Shots don't go through walls | |
| Imported shotgun model shows (no stand-in warning in output) | |

### Movement and camera

| Check | Result |
|---|---|
| WASD, jump and crouch (C and Left Ctrl) work; crouch hold and toggle both work | |
| First person only; no way to zoom out | |
| Mouse, controller and touch look sensitivity sliders work | |
| FOV slider works | |

### Match

| Check | Result |
|---|---|
| Alone: practice range with dummies; dummies take damage and respawn | |
| With 2 players: intermission, countdown, then combat | |
| Teams balance on join | |
| Respawn after about 2.5 s at a safe spawn, with spawn protection that ends when you fire | |
| Falling off Rooftops kills you | |
| Match ends on time or score; overtime on a tie | |
| Results show winner, MVP and rewards | |
| Map vote works and the winning map loads | |
| Leaving mid-match doesn't break the round | |
| Full match with 10 players (write the actual count in the log) | |

### UI and settings

| Check | Result |
|---|---|
| Main menu: Play, Locker (skins and shop), Profile (stats and challenges), Leaderboards, Settings, How to Play all open and close | |
| First join suggests the tutorial; HOW TO PLAY runs it; Backspace or Y skips it | |
| Scoreboard (Tab), kill feed, timer and score update | |
| Crosshair style, colour and size apply | |
| Settings survive a rejoin | |

### Platforms

| Check | Result |
|---|---|
| Phone: buttons reachable, FIRE drag-to-aim works, layout editor saves | |
| Tablet | |
| Controller: every action, menus navigable | |
| Low-end PC or phone frame rate (from F2) | |

### Saving and economy

| Check | Result |
|---|---|
| XP, level and coins persist after rejoining (needs API access, see ASSET_PIPELINE.md) | |
| Idle player gets no completion or win reward | |
| Buying a skin with coins deducts coins and equips it | |
| Daily and weekly challenges progress and pay once | |
| Leaderboards fill in after a few minutes | |
| (Only if you turned on Robux packs) test purchase grants coins once | |

## Findings

Write anything that felt wrong, broke or needs tuning here, with the build and date.

| Date | Finding | Severity | Fixed in |
|---|---|---|---|
| | | | |
