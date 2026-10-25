from pathlib import Path
import json
root=Path(__file__).resolve().parents[3]
out=Path(__file__).resolve().parent.parent
base=json.loads((root/'development-copy/training-bots-20261024/evidence/expected-sources.json').read_text())
expected=dict(base)
changes=[]
for key,path in {
 'ReplicatedStorage.Shared.Training.Policy':'src/shared/Training/Policy.luau',
 'ServerScriptService.Server.Services.TrainingBotService':'src/server/Services/TrainingBotService.luau',
}.items():
 text=(root/'development-copy/source'/path).read_text(encoding='utf-8-sig').replace('\r\n','\n')
 changes.append({'path':key,'source':text});expected[key]=text
def digest(src):
 h=0
 for k,v in sorted(src.items()):
  for b in (k+'\n'+v+'\n').encode():h=(h*31+b)%4294967296
 return h
guard='assert(not game.RunService:IsRunning());assert(game.GameId==10772492892 and game.PlaceId==139437092998076);'
def verify(src,label):
 return "local list={};local keys={};for _,o in game:GetDescendants()do if o:IsA('LuaSourceContainer')then local k=o:GetFullName();list[k]=o.Source:gsub('\\r\\n','\\n');table.insert(keys,k)end end;table.sort(keys);local h=0;for _,k in keys do local s=k..'\\n'..list[k]..'\\n';for i=1,#s do h=(h*31+s:byte(i))%4294967296 end end;assert(#keys==123 and h=="+str(digest(src))+");print('"+label+"',#keys,h,game.PlaceVersion)"
(out/'tools/baseline.command.luau').write_text(guard+verify(base,'PASSIVE_BASELINE_OK'))
patch=guard+"local packet=game.HttpService:JSONDecode([====["+json.dumps(changes)+"]====]);for _,e in packet do local o=game;for _,n in string.split(e.path,'.')do o=assert(o:FindFirstChild(n),n)end;o.Source=e.source end;"+verify(expected,'PASSIVE_PATCH_OK')
(out/'tools/patch.command.luau').write_text(patch)
install=guard
for name,parent,cls,file in [('TemporaryBotPassiveServer','game.ServerScriptService','Script','server-test.luau'),('TemporaryBotPassiveClient','game.StarterPlayer.StarterPlayerScripts','LocalScript','client-test.luau')]:
 install+="do local s=Instance.new('"+cls+"');s.Name='"+name+"';s.Source=game.HttpService:JSONDecode([====["+json.dumps((out/'tools'/file).read_text())+"]====]);s.Parent="+parent+" end;"
(out/'tools/install.command.luau').write_text(install+"print('PASSIVE_PROBES_READY')")
(out/'tools/clean.command.luau').write_text(guard+"for _,o in game:GetDescendants()do if o.Name:match('^TemporaryBot')then o:Destroy()end end;"+verify(expected,'PASSIVE_CLEAN_VERIFIED'))
(out/'tools/cloud-check.command.luau').write_text(guard+verify(expected,'PASSIVE_CLOUD_VERIFIED'))
(out/'evidence/expected-sources.json').write_text(json.dumps(expected,indent=2))
print('Expected123 digest',digest(expected))
