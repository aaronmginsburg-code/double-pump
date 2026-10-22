# Double Pump private playtest guide

Experience: [Double Pump [Private Test]](https://www.roblox.com/games/82505574993280/Double-Pump)
Owner: **supersnapstudios**. Access is private; the link does not grant strangers access.
Maximum server size: **10**. No paid access or Robux products were enabled.

## Open in Roblox Player

1. Sign in to Roblox as **supersnapstudios**, or an explicitly invited tester.
2. Open the experience link in your normal browser and click the green Play button.
3. Allow the browser to open the already-installed Roblox app if prompted.
4. Confirm the **DOUBLE PUMP** main menu appears. This is the cloud game, not Studio.

The automated in-app browser reached Roblox's loading/download prompt. Player was
launched separately, but automated clicks on its Home page did not open the game.
The owner subsequently opened the private experience from another computer and
reported successful gameplay: **"Looks good."** Detailed live multiplayer and
performance checks remain outstanding. Automated live gameplay was not verified. Do not reinstall
Roblox merely because the in-app browser displays a download prompt; an installed
Player was found on this PC.

## Practice and multiplayer

- Select **PRACTICE** on the main menu for the range with 10 moving/static targets.
- Select **PLAY** to join multiplayer. With fewer than two queued players, warm up
  in the range. A real match requires **two** players; teams are assigned automatically.
- Press **M** to open the existing menu, change modes or return to play.
- Match results lead to map voting. Click Warehouse, Rooftops or Dust Town.
- All arenas share one start place; no additional place links are needed.

## Keyboard and mouse

| Input | Action |
|---|---|
| WASD / mouse | Move / aim |
| Left mouse click | Fire one shot |
| Q | Switch shotguns |
| 1 / 2 | Select Pump A / Pump B |
| R | Reload the equipped shotgun |
| Space | Jump |
| C / Left Ctrl | Crouch |
| Tab | Scoreboard |
| M | Game menu |
| Esc | Roblox menu; use Respawn to test a death/respawn |

## Test the double pump

Aim at a target, click to fire A, press **Q**, then click to fire B as it becomes
ready. Switch back and repeat. Click for each shot; automatic held firing is off.
Compare this with repeated shots from one gun. Watch each gun's ammo separately.
Reload with R, insert a shell, then switch to check reload interruption. After
respawning, repeat and check that aim, firing and ammo return normally.

The previous Studio measurement was **0.484–0.783 s** between accepted alternating
shots versus **1.116 s** in the single-gun control. These are Studio observations,
not a live-network benchmark. No timing or damage values were changed for release.

## Known limitations

- Guns use the existing parts-based stand-ins with embedded procedural/baked
  animations. The finished mesh/texture asset has not been imported.
- All 29 intended sound IDs remain empty. Some built-in fallbacks fail approval;
  firing/pumping may be silent. Map thumbnails and logo remain placeholders.
- Camera orientation now follows each server-chosen spawn direction. Close cover
  can still fill the Rooftops spawn view; navigate around it. Maps were not altered.
- Live PvP, full rounds/map cycling, latency, mobile/console, FPS and memory still
  need actual client testing. Studio validation does not establish these results.

## Record a bug

Record the map, practice/match mode, approximate time, gun/ammo, inputs, whether you
had just died or changed modes, and steps to reproduce. Capture the screen with
Roblox's Capture controls or your normal screenshot tool. Press **F9** for the
Developer Console and capture the relevant errors; owner server logs may also be
available there. Windows Player logs are normally under
`C:\Users\aaron\AppData\Local\Roblox\logs`. Share only the relevant excerpt;
remove account/session details. Report expected and actual behavior separately.

## Add authorized testers later

Open [Creator Dashboard / Manage audience](https://create.roblox.com/dashboard/creations/experiences/10772275012/manage-audience),
choose **Invite early testers**, and select only the friends you explicitly approve
(up to 10 in the current dialog). Do not use **Release publicly on Roblox**. Keep
Game access and Audience reach private. No testers were invited during this task.

## Mobile update — private version 5 (2026-10-21)

Leave old sessions and rejoin the same experience to get the mobile build.
On touch devices, **MOVE** and **LOOK** are separate sticks. **FIRE** presses once;
holding alone does not repeat. While holding FIRE, use a different finger to swipe
quickly downward in **↓ SWAP** on the movement side, outside MOVE. Each deliberate
fresh swipe switches shotguns and fires once when legally ready. Release FIRE to
cancel any pending follow-up. Use explicit A/B, reload, crouch and jump buttons.

Settings → Controls → **Control Layout** selects Right-Handed or Left-Handed.
Left-Handed mirrors the controls, ammo and first-person weapon; swipe on the right,
FIRE/LOOK on the left. Movement and aiming directions remain normal. The preference
uses existing profile saving; real-device rejoin persistence needs confirmation.

Phone/tablet checklist: aim/release, hold FIRE without repetition, hold + repeated
swipes, release before the follow-up, MOVE + LOOK + FIRE + swipe with separate
fingers, reject MOVE/horizontal/up/short/slow gestures, jump/crouch/reload, both
layouts, respawn and rejoin. Report device/model, orientation, exact steps and a
screen recording. Studio and 168 tests pass; actual hardware feel is not yet verified.
See [mobile report](MOBILE_CONTROLS_UPDATE.md) for screenshots and remaining limits.

## Camera / weapon-hand revision

Version 8 is privately published at https://www.roblox.com/games/82505574993280/Double-Pump.
Leave the old session and rejoin a fresh server: drag free screen space to aim; LOOK is removed.
Control Layout and Weapon Hand are independent settings. Try all four combinations,
then hold FIRE, drag aim and swipe in the marked SWAP region with separate fingers.
Other buttons and swap thresholds remain as in version 5. Test respawn and rejoin.

