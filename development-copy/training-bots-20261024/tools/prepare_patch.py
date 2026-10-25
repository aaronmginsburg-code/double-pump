from pathlib import Path
import json
repo=Path(__file__).resolve().parents[3]
out=repo/'development-copy/training-bots-20261024'
base=json.loads((repo/'development-copy/aim-assist-20261024/evidence/expected-sources.json').read_text(encoding='utf-8-sig'))
source=repo/'development-copy/source'
mapping={}
for folder,prefix in [('src/shared','ReplicatedStorage.Shared'),('src/server','ServerScriptService.Server'),('src/client','StarterPlayer.StarterPlayerScripts.Client')]:
 for p in (source/folder).rglob('*.luau'):
  parts=list(p.relative_to(source/folder).parts); name=parts.pop().split('.')[0]
  if name!='init':parts.append(name)
  mapping[prefix+('.'+'.'.join(parts) if parts else '')]=p
items=[]
expected=dict(base)
for key,p in mapping.items():
 value=p.read_text(encoding='utf-8-sig').replace('\r\n','\n')
 if value!=base.get(key):
  cls='LocalScript' if p.name.endswith('.client.luau') else 'Script' if p.name.endswith('.server.luau') else 'ModuleScript'
  items.append({'path':key,'source':value,'class':cls})
  expected[key]=value
def digest(s):
 h=0
 for key,value in sorted(s.items()):
  for b in (key+'\n'+value+'\n').encode():h=(h*31+b)%4294967296
 return h
pre=f'''assert(not game.RunService:IsRunning()); assert(game.GameId==10772492892 and game.PlaceId==139437092998076); local list={{}} for _,v in game:GetDescendants()do if v:IsA('LuaSourceContainer')then list[v:GetFullName()]=v.Source:gsub('\\r\\n','\\n')end end local keys={{}}for k in list do table.insert(keys,k)end table.sort(keys)local h=0 for _,k in keys do local s=k..'\\n'..list[k]..'\\n' for i=1,#s do h=(h*31+s:byte(i))%4294967296 end end assert(#keys=={len(base)} and h=={digest(base)},'Cloud changed: stop'); print('BOTS_PATCH_BASELINE_OK',#keys,h)'''
(out/'tools/check-baseline.command.luau').write_text(pre,encoding='utf-8')
chunks=[];chunk=[];size=0
for item in items:
 n=len(json.dumps(item))
 if size+n>50000 and chunk:chunks.append(chunk);chunk=[];size=0
 chunk.append(item);size+=n
if chunk:chunks.append(chunk)
for i,chunk in enumerate(chunks):
 payload=json.dumps(chunk,ensure_ascii=True)
 command="assert(not game.RunService:IsRunning());assert(game.GameId==10772492892 and game.PlaceId==139437092998076);local packet=game.HttpService:JSONDecode([====["+payload+"]====]);for _,entry in packet do local parts=string.split(entry.path,'.');local obj=game;for j=1,#parts-1 do local child=obj:FindFirstChild(parts[j]);if not child and parts[j]=='Training' and obj==game.ReplicatedStorage.Shared then child=Instance.new('Folder');child.Name=parts[j];child.Parent=obj end obj=assert(child,parts[j])end local name=parts[#parts];local target=obj:FindFirstChild(name);if not target then target=Instance.new(entry.class);target.Name=name;target.Parent=obj end assert(target:IsA(entry.class));target.Source=entry.source end print('BOTS_PATCH_CHUNK',"+str(i+1)+",#packet)"
 (out/f'tools/patch-{i+1}.command.luau').write_text(command,encoding='utf-8')
(out/'evidence/expected-sources.json').write_text(json.dumps(expected,indent=2),encoding='utf-8')
(out/'evidence/changed-sources.json').write_text(json.dumps([{k:v for k,v in x.items() if k!='source'} for x in items],indent=2))
print('Changed',len(items),'chunks',len(chunks),'expected',len(expected),'digest',digest(expected))
