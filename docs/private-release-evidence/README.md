# Private release evidence

Published source: a487de38a96261dbeac74e701e69ce31762123f9.
Previous verified checkpoint: 137a9ebe68341432ea256de1cb7281b0da613a47.
Universe 10772275012; start place 82505574993280; published place version 2.

01: solo practice after respawn; camera faces down range, stand-in gun/HUD visible.
02: Blue-team Rooftops spawn; camera direction dot 1.0 (close cover remains).
03: multiplayer first post-respawn shot client 1/server 1, no rejection.
04: match-to-practice transition; facing dot 1.0, combat active.
05: next normal round in Warehouse; facing dot 1.0 after practice/match changes.
06: Studio publish success, only owner/collaborators availability.
07: Creator Dashboard Game access Private and Audience reach Private.
08: saved maximum visitor count 10; unchanged social-slot default.
09: published-only version history shows version 2.

studio-release-observations.log contains only the measurement lines extracted from
actual Studio output; no raw authentication/network logs. Observer sources here
are reproduction aids and were NOT saved in the published game. The first observer
was destroyed during respawn; it was replaced with a persistent ScreenGui observer.
The solo 0.9406 direction reading occurred after player mouse input, not at spawn.
All recorded team/respawn/transition direction checks were 1.0 before manual aim.

124 tests pass; type analyzer exit 0; Windows-aware StyLua exit 0; Selene 0/0/0;
Rojo rebuild exit 0 with the same tested place SHA-256. Raw generic CRLF formatter
noise is retained in build/playtest and summarized in stylua.log.

Cloud source comparison: all 72 containers match the exact tested artifact after
normalizing line endings. No extra test scripts. Lune reports an unknown Terrain
serialization property but completed the comparison/destroy-height assertions.

Normal Roblox Player gameplay remains unverified. The owner URL loads correctly;
Player Home launched as supersnapstudios, but automated clicks did not enter the
game. No live gameplay/performance/network pass is implied by these Studio files.
