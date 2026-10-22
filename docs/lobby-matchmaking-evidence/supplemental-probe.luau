-- Local-test-only follow-up. Real remotes; no production source edits.
local P=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local H=game:GetService("HttpService")
local remote=RS.LobbyTestProbe
local state=RS.MatchState
local D=require(game.ServerScriptService.Server.Services.DamageService)
local list=P:GetPlayers();table.sort(list,function(a,b)return a.UserId<b.UserId end)
local a,b,c=list[1],list[2],list[3]
local expected,confirmed=nil,nil
local original=D.apply
D.apply=function(attacker,target,amount,info)
	if attacker==a then expected={target=target.Name,amount=amount,head=info.headshot} end
	return original(attacker,target,amount,info)
end
remote.OnServerEvent:Connect(function(p,kind,data)if p==a and kind=="Hit" then confirmed=data end end)
local function stage(p,pos)
	p.Character.HumanoidRootPart.Anchored=true
	p.Character:PivotTo(CFrame.lookAt(pos,pos+Vector3.xAxis))
end
stage(a,Vector3.new(-1255,3.5,-5));stage(b,Vector3.new(-1248,3.5,-5));stage(c,Vector3.new(-1255,3.5,-25))
task.wait(4) -- allow throttled background-client cameras to settle after staging
for attempt=1,3 do
	expected,confirmed=nil,nil
	remote:FireClient(a,"Shoot",b.Character.UpperTorso.Position)
	task.wait(2)
	local pass=expected and confirmed and expected.target==b.Name and not confirmed.headshot and confirmed.damage==math.round(expected.amount) and b.Character.Humanoid.Health==100
	print("[LOBBY_BODY_RETEST] "..H:JSONEncode({attempt=attempt,pass=pass==true,expected=expected,hit=confirmed,health=b.Character.Humanoid.Health}))
	if pass then state:SetAttribute("ProbeBodyPassed",true);break end
	remote:FireClient(a,"Swap");task.wait(0.5)
end
stage(a,Vector3.new(-1248,3.5,24));stage(b,Vector3.new(-1252,3.5,36))
remote:FireClient(a,"Aim",Vector3.new(-1252,6,37))
state:SetAttribute("ScreenshotPhase","OneQueued")
print("[LOBBY_VISUAL] OneQueued")
task.wait(20)
stage(c,Vector3.new(-1256,3.5,38))
state:SetAttribute("ScreenshotPhase","Countdown")
print("[LOBBY_VISUAL] Countdown")
task.wait(7)
c:Kick("Isolated local queue disconnect test")
task.wait(1)
print("[LOBBY_DISCONNECT] "..H:JSONEncode({pass=state:GetAttribute("QueueCount")==1 and state:GetAttribute("QueueState")=="Waiting",count=state:GetAttribute("QueueCount"),status=state:GetAttribute("QueueState")}))
state:SetAttribute("ScreenshotPhase","DisconnectWaiting")
