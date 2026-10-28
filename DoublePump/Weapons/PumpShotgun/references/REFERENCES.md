# Pump Shotgun — Reference Document

Research for the Double Pump signature weapon. Collected 2026-10-20.

## How this research was done (and its limits)

- Text sources were read through a web-fetch tool. **The build container's network
  policy blocks direct image downloads** (`static.wikia.nocookie.net`,
  `upload.wikimedia.org`, `commons.wikimedia.org`, `youtube.com`, `i.ytimg.com`,
  `web.archive.org` all returned HTTP 403 at the proxy). Because of that:
  - No reference images are stored in this folder, and the mood board
    (`MOODBOARD.md`) is a curated list of links plus the design's own renders,
    not pasted screenshots.
  - The visual analysis of the 2017–2018 Fortnite pump below combines what the
    wiki text states (marked **[source]**) with the author's recollection of the
    in-game model (marked **[recollection]**). Recollection items have **not**
    been verified against a screenshot in this environment. Before final art
    sign-off, compare the renders in `../renders/` against the links in
    `MOODBOARD.md` yourself.
- No AI-generated illustrations were used anywhere.
- No Epic Games meshes, textures, animations or logos were extracted or used.
  All geometry and textures in this asset were generated from scratch by the
  scripts in `../scripts/`.

## Sources

### Fortnite pump shotgun (2017–2018)
| # | Source | What it gave us |
|---|--------|-----------------|
| F1 | Fortnite Archive Wiki — Pump Shotgun: https://fortnite-archive.fandom.com/wiki/Pump_Shotgun | Original stats (90/95 dmg, 0.7 fire rate, 5 shells, 4.8/4.6 s reload, 2.5× headshot), "older model is based off a trench shotgun used during WW1", lower rarities "may be inspired by the Remington 870 Wingmaster ... with a laser sight on top of the barrel"; patch history |
| F2 | Fortnite Archive Wiki promo image (blocked for download): https://static.wikia.nocookie.net/fortnite_gamepedia/images/4/49/Pump_Shotgun_-_Promotional_Image.jpg | Side-profile promo render (view in a browser) |
| F3 | Fortnite Wiki — Pump Shotgun: https://fortnite.fandom.com/wiki/Pump_Shotgun | "Common, Uncommon, Rare: based on the Remington 870, with rifle sights"; Epic/Legendary based on SPAS-12; model replaced in v11.00 (so 2017–2018 look = pre-v11 model) |
| F4 | Fortnite Wiki — Shotgun class (archive): https://fortnite-archive.fandom.com/wiki/Shotgun_Class_(Battle_Royale) | Shotgun lineup context |
| F5 | Upcomer — shotgun changes: https://upcomer.com/fortnite-shotguns-are-no-longer-a-one-hit-kill-among-other-changes/ | Era context for the 2018 shotgun nerfs |
| F6 | Mein-MMO — "Players want the Double Pump back": https://mein-mmo.de/en/players-want-the-double-pump-tactic-back-this-is-what-fortnite-says,288070/ | Community framing of the double-pump mechanic |
| F7 | Reddit r/FortNiteBR, Season 5 patch notes thread (Epic reply, Jul 12 2018): https://www.reddit.com/r/FortNiteBR/comments/8y7u9e/season_5_patch_notes/ | Swap-delay history |
| F8 | IMFDB — Fortnite: https://www.imfdb.org/wiki/Fortnite | Real-firearm identification list (Remington 870, Mossberg 500 entries) |

Patch facts from F1: v3.0.0 (20 Feb 2018) required re-pumping after a quick swap;
v6.31 (27 Sep 2018) added the shotgun-to-shotgun swap delay and cut headshots to 2.0×.

### Real-world mechanical references
| # | Source | What it gave us |
|---|--------|-----------------|
| R1 | Wikipedia — Remington Model 870: https://en.wikipedia.org/wiki/Remington_Model_870 | Overall length 26.3–50.5 in, barrels 14–30 in, 7.0–8.0 lb, tube magazine 3+1…7+1, bottom-loading, side-ejecting receiver, **dual action bars**, bolt locks into barrel extension |
| R2 | Wikipedia — Winchester Model 1897: https://en.wikipedia.org/wiki/Winchester_Model_1897 | Trench-gun lineage named by F1 |
| R3 | IMFDB — Winchester Model 1897: https://www.imfdb.org/wiki/Winchester_Model_1897 | Overall length 39.25 in, 20 in trench barrel, 8 lb, 5+1 tube; perforated heat shield on trench version |
| R4 | IMFDB Remington 870 photo set: https://www.imfdb.org/wiki/File:GZW_Remington_Model_870_2.jpg (also _3, _4, _6, _7, _8, _9) | Multi-angle photos of an 870 (side, top, receiver close-ups) |
| R5 | Primary Arms — pump shotgun parts guide: https://blog.primaryarms.com/guide/pump-action-shotgun-parts-guide/ | Part names: receiver, tube, fore-end, trigger assembly, stock, safety, action lock |
| R6 | EngineerFix — How a pump action works: https://engineerfix.com/how-does-a-pump-action-mechanism-work/ | Cycle order (see "Mechanical cycle" below) |
| R7 | Gun Tests 870 review PDF: https://www.gun-tests.com/wp-content/uploads/2020/01/0708-Remington-Model-870.pdf | Additional 870 spec sheet |

### Roblox technical references
| # | Source | What it gave us |
|---|--------|-----------------|
| X1 | Roblox texture specifications: https://create.roblox.com/docs/art/modeling/texture-specifications | PBR maps up to 1024×1024; **OpenGL tangent-space normals only**; roughness/metalness single-channel 8-bit; png/jpg/tga/bmp; single UV set in 0–1 |
| X2 | Roblox export guide (Blender FBX): https://create.roblox.com/docs/avatar/character-bodies/export | Path Mode Copy + Embed Textures, Apply Scalings "FBX Unit Scale", no leaf bones, animation export without NLA/All Actions, Simplify 0 |
| X3 | Roblox SurfaceAppearance: https://create.roblox.com/docs/art/modeling/surface-appearance | ColorMap / NormalMap / RoughnessMap / MetalnessMap slots |

## Visual analysis of the 2017–2018 Fortnite pump

See `VISUAL_ANALYSIS.md`.

## Mechanical cycle (R1, R5, R6)

1. **Fired / locked**: bolt locked into barrel extension; forend fully forward.
2. **Unlock + rearward stroke**: the forend pulls the two action bars, which drag
   the bolt carrier and bolt back. Extractor pulls the spent hull; it hits the
   ejector and leaves through the **right-side ejection port**; hammer is recocked.
3. **Feed**: near the rear of travel the shell latch releases one shell from the
   tube onto the **carrier (lifter)**, which tips up toward the chamber.
4. **Forward stroke**: bolt strips the shell into the chamber, carrier drops,
   bolt locks. Forend is back at its forward stop.
5. **Loading**: shells are pushed up through the **bottom loading port**, past the
   carrier, forward into the magazine tube one at a time.

Animation implications used in this asset: forend and bolt translate together
along the bore axis by the same stroke; the carrier pivots at its rear; the spent
shell leaves the port up-and-right during the first half of the back-stroke; a
loaded shell enters from below, rotates nose-up and is thumbed forward.

## Dimensions and proportion targets

See `DIMENSIONS.md` (confirmed values vs estimates are labelled).
