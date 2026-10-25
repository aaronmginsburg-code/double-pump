from pathlib import Path
import json

repo=Path(__file__).resolve().parents[3]
out=repo/'development-copy/training-bots-20261024'
expected=json.loads((out/'evidence/expected-sources.json').read_text())
header="""## Private development training bots — 2026-10-24

The current development source is `development-copy/source`, branch `feat/development-training-bots`, based on `4f70b958`. Two authorized-session beginner NPCs reuse normal weapons, physical queue admission, match scoring and respawning. The developer and both bots form an intentional 1v2 roster; independently queued humans can join within normal team capacity. Bot rounds suppress all permanent progression. Human-versus-human range practice remains nonlethal. No production source, controls, combat balance, maps, profile schemas or assets were replaced.

Read [TRAINING_BOTS_UPDATE.md](TRAINING_BOTS_UPDATE.md) for exact private deployment status, source revision, backups, tests, screenshots and acceptance limits. This is a private development feature, not a production release. The candidate has 123 permanent scripts, verified against the full-scene cloud base. 424 tests pass; Studio solo lifecycle checks covered all three arenas with shortened test clocks. Physical-device difficulty/performance acceptance remains pending. Older checkpoints below are historical.

---

"""
for name in ['AI_HANDOFF.md','PROJECT_STATUS.md','GAME_DESIGN.md','ROADMAP.md']:
 p=repo/'docs'/name
 t=p.read_text(encoding='utf-8-sig')
 if not t.startswith('## Private development training bots'):
  p.write_text(header+t,encoding='utf-8')
for name,title in [('TESTING.md','Training bot verification'),('RELEASE_RECORD.md','Private training-bot development record')]:
 p=repo/'docs'/name
 t=p.read_text(encoding='utf-8-sig')
 if title not in t:
  p.write_text(t+'\n\n## '+title+' — 2026-10-24\n\nSee [TRAINING_BOTS_UPDATE.md](TRAINING_BOTS_UPDATE.md) for the development-only source/deployment record, exact results and limitations. 424 tests pass, including26 bot regressions. This does not change the public release record above.\n',encoding='utf-8')
p=repo/'AGENTS.md'
t=p.read_text(encoding='utf-8-sig')
if '## Private training bots' not in t:
 p.write_text(t+"\n\n## Private training bots (2026-10-24)\n\nCurrent development branch is `feat/development-training-bots`; see docs/TRAINING_BOTS_UPDATE.md. The full-scene candidate contains123 permanent scripts. Exact DeveloperAccess IDs plus UserId allowlist are mandatory. NPC records are server-registered participants, never fake Players. Preserve physical FIFO/root-center queue admission, training-round progression suppression and ordinary nonlethal human lobby combat. Never copy development bot services or intentional1v2 team rules into production without separate approval. Remove every TemporaryBot probe and runtime-only negative Studio UserId grant before publishing; compare all123 sources with the archived candidate.\n",encoding='utf-8')
p=repo/'development-copy/README.md'
t=p.read_text(encoding='utf-8-sig')
if not t.startswith('# Current training-bot checkpoint'):
 p.write_text('# Current training-bot checkpoint\n\nRead [training-bot update](../docs/TRAINING_BOTS_UPDATE.md) for the current123-script private source, branch, deployment and rollback record. Previous aim-assist and audio history follows.\n\n'+t,encoding='utf-8')

# Only formatting changed after runtime testing; align editor text exactly before final archive.
keys=['ServerScriptService.Server.Services.CombatContext','StarterPlayer.StarterPlayerScripts.Client.UI.Postgame']
payload=[{'path':k,'source':expected[k]}for k in keys]
cmd="assert(not game.RunService:IsRunning());assert(game.GameId==10772492892 and game.PlaceId==139437092998076);local packet=game.HttpService:JSONDecode([====["+json.dumps(payload)+"]====]);for _,e in packet do local o=game;for _,name in string.split(e.path,'.')do o=assert(o:FindFirstChild(name),name)end o.Source=e.source end;"
cmd+="for _,o in game:GetDescendants()do if o.Name:match('^TemporaryBot')then o:Destroy()end end;"
h=0
for key,value in sorted(expected.items()):
 for b in (key+'\n'+value+'\n').encode():h=(h*31+b)%4294967296
cmd+="local sources={};local keys={}for _,o in game:GetDescendants()do if o:IsA('LuaSourceContainer')then local k=o:GetFullName();sources[k]=o.Source:gsub('\\r\\n','\\n');table.insert(keys,k)end end;table.sort(keys);local h=0;for _,k in keys do local s=k..'\\n'..sources[k]..'\\n';for i=1,#s do h=(h*31+s:byte(i))%4294967296 end end;assert(#keys==123 and h=="+str(h)+",'Final source mismatch');print('BOT_FINAL_CLEAN',#keys,h,game.GameId,game.PlaceId)"
(out/'tools/clean-final.command.luau').write_text(cmd,encoding='utf-8')
template=(repo/'development-copy/aim-assist-20261024/tools/verify-archive.luau').read_text()
template=template.replace('aim-assist-20261024','training-bots-20261024').replace('n==118','n==123')
(out/'tools/verify-archive.luau').write_text(template,encoding='utf-8')
print('Docs and final123-script verification command prepared; digest',h)
