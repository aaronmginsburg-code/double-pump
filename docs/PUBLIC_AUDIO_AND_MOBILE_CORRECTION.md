# Public audio and Mobile preset correction — 2026-10-28

Status: public version **16 published and fresh cloud source verified**; owner confirmed all three corrections in a fresh iPhone session.

## Owner observations and clarification

The owner tested public version13 on iPhone and reported missing approved sounds, an incorrect ammunition display and auto swap behavior. They clarified an intended **ten shells per shotgun**, the maximum developer-slider value. Read-only inspection found only one developer preset key, u11808586604_all_Mobile in development tuning scope u10772492892. Its revision3 stores **six**, not ten. The original record is preserved unchanged in release-evidence-20261028/Mobile.owner-saved.json; ReleasePreset now explicitly documents the owner's ten-shell correction. No saved development preset or player profile was overwritten.

## Corrections

- Hud built exactly five shell pips regardless of real magazine capacity. It now builds the configured number with widths fitted inside the existing192px row. The card position and mobile controls do not move.
- AutoFireController required a still-eligible target to consider swapping. An automatic shot now retains one pending legal swap, so a target dying or leaving acquisition does not discard it. Another shot still requires a fresh valid visible target; normal ammo, reload, swap and firing gates remain. UI/death/reset/manual equip clear pending intent.
- AssetIds contains all51 approved custom sound IDs. Version13's automatic publication grant covered26 assets, while sound IDs existed only in scripts. Added51 non-playing Sound references under ReplicatedStorage.Assets.AudioReferences so Roblox can inspect and grant their experience dependencies during publication. This is a permission-discovery fix, not a new sound upload or mix change. The publication prompt and subsequent grant log confirmed the missing experience permissions. The owner then confirmed the custom sounds in a fresh public iPhone session.

Roblox documents restricted audio and explicit experience grants: https://create.roblox.com/docs/audio/assets and https://devforum.roblox.com/t/new-asset-privacy-and-permissions-features-for-audio-and-video/2725248 . Owner Studio playback is not proof of published-client asset access.

## Validation

399 automated tests pass. Rojo build passes. Studio simulated-touch tests confirm an ordinary100HP target is eliminated, the gun switches to slot2 after the shot, a durable target receives alternating accepted shots0.417s apart, walls and UI focus block firing, keyboard auto fire stays off, and respawn restores100HP/10shells per gun. Studio preload reports51/51. The owner subsequently confirmed sounds, ten shells and auto swapping in a fresh public iPhone session. This is owner-reported acceptance, separate from automated Studio evidence. Screenshot shows the ten-shell HUD in a Studio iPhone viewport after the automated probe returned to keyboard input.

## Preservation and deployment

Public universe10772275012/place82505574993280 only. Private development is unchanged. Pre-correction published version13 and Git6e097818 remain rollback checkpoints. Native local backup release-artifacts/v13-correction/DoublePump_v13_BEFORE.rbxl has SHA25602E21C4F2022B485673514118D7B9E6FD995FF7067164C76CA7F33148B928FCA. Remove disposable probes and verify125permanent scripts plus51audio references before publication. Asset-permission prompts are owner actions under the computer-use skill. Do not claim success until Roblox confirms publication and cloud parity.

## Publication permission confirmation

Adding the51concrete sound dependencies triggered Roblox's **Some assets need permission to load / Grant Permissions and Publish** dialog for the existing public target. This confirms additional asset grants were missing from the first promotion. Owner completed the grant. Studio logged production universe10772275012 granted access to all51 sound dependencies (batches1+50) at10:22:07Z; PublishSuccessful followed at10:23:52Z. Creator Dashboard lists version16 under Show published only, October28,2026 at03:23PDT. The sound files and IDs were present in version13; importing the gun alone did not establish permissions for script-only audio.

Clean candidate contains125scripts, source digest2411606008,51non-playing sound references; no disposable probes. Native candidate SHA25675E03BCE446AAF952C79E22D7EF31281206EF00403EAE5769DF1939AA4072DE4. Focused StyLua check passes; whole-tree check after the main checkout reports existing CRLF-vs-LF differences, not a new clean formatting result. Previous Selene/LSP tool limitations remain.


## Confirmed publication and fresh cloud verification

Production **version16**, universe10772275012/place82505574993280, is published. A separate fresh Studio cloud open at10:28:33Z returned125permanent scripts, checksum31 **2411606008**, all51non-playing audio references, capacity10 and autoSwaptrue. All script sources match the tested correction; both Blender templates and the feedback board are present; private developer/bot/skin override entrypoints are absent. The verification command was read-only. See correction-cloud-v16.txt and public-v16-cloud-verified.png.

Studio's background script-version history requests again encountered HTTP429 after PublishSuccessful. Publication is independently confirmed by Dashboard's published-only record and the fresh version16 cloud open. No repeated publication was attempted by the agent in response to those background errors.

The owner answered **yes** when asked to verify custom sounds, ten shells and automatic swapping in a fresh public iPhone session. This verifies these three reported issues through owner feedback; it is not an agent-controlled full multiplayer or physical-device certification. The earlier20assertion two-client match check remains prior evidence, with six-shell ammunition at that earlier checkpoint. No private development publication, saved developer-preset change, player-profile change, monetization or audience change occurred.

Rollback: previous public version13 remains in Creator Dashboard Version History, and its intact native binary and Git6e097818 backup are preserved. Restoring a historical version only saves a draft; deliberately publish it to the same public place if rollback is authorized. Do not revoke the sound permissions as part of code rollback.
