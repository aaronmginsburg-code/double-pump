-- TEST COPY ONLY. Stages real Studio clients; shortens match clocks only in this
-- instrumented copy. Weapon timings, pellet calculations and remote validation run unchanged.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local remote=RS:WaitForChild("LobbyTestProbe")
local state=RS:WaitForChild("MatchState")
local S=game:GetService("ServerScriptService").Server.Services
local Match=require(S.MatchService)
local Damage=require(S.DamageService)
local Map=require(S.MapService)
local Combat=require(S.CombatService)
local Character=require(S.CharacterService)
Character.Spawned:Connect(function(p,c)print("[LOBBY_SPAWN]",p.Name,c:GetAttribute("Dead"),c:FindFirstChildOfClass("Humanoid").Health)end)
Character.Died:Connect(function(p,c)print("[LOBBY_DIED]",p.Name,p.Character==c,c:FindFirstChildOfClass("Humanoid").Health)end)
local Data=require(S.DataService)
local ready,hits,lastAmount,statuses={},{},{},{}
local failures=0
local function record(name,pass,data)
	if not pass then failures+=1 end
	print("[LOBBY_TEST] "..Http:JSONEncode({test=name,pass=pass,data=data}))
	state:SetAttribute("ProbeLast",name)
end
local function waitFor(fn,seconds)
	local deadline=os.clock()+seconds
	repeat if fn() then return true end task.wait(0.1) until os.clock()>=deadline
	return false
end
remote.OnServerEvent:Connect(function(p,kind,data)
	if kind=="Ready" then ready[p]=true
	elseif kind=="Hit" then hits[p]=data
	elseif kind=="Status" then statuses[p]=data;print("[LOBBY_CLIENT_STATUS] "..p.Name.." "..Http:JSONEncode(data)) end
end)
local apply=Damage.apply
Damage.apply=function(attacker,target,amount,info)
	if attacker then lastAmount[attacker]={target=target.Name,amount=amount,headshot=info.headshot,pellets=info.pellets} end
	return apply(attacker,target,amount,info)
end
Combat.ShotFired:Connect(function(p,slot,_,count) print("[LOBBY_SERVER_SHOT]",p.Name,slot,count,workspace:GetServerTimeNow()) end)
local function root(p) return p.Character and p.Character:FindFirstChild("HumanoidRootPart") end
local function hum(p) return p.Character and p.Character:FindFirstChildOfClass("Humanoid") end
local function stage(p,position,look)
	local r=root(p);r.Anchored=true
	p.Character:PivotTo(CFrame.lookAt(position,look or position+Vector3.xAxis))
	r.AssemblyLinearVelocity=Vector3.zero
end
local function queue(p,i)
	stage(p,Vector3.new(-1256+i*3,3.5,36),Vector3.new(-1252,12,37))
	remote:FireClient(p,"Aim",Vector3.new(-1252,12,37))
end
local function outside(p,i) stage(p,Vector3.new(-1255,3.5,-12+i*5)) end
local function fire(p,target,zone)
	hits[p]=nil;lastAmount[p]=nil
	remote:FireClient(p,"Shoot",target:FindFirstChild(zone or "UpperTorso").Position)
	waitFor(function() return hits[p]~=nil end,4)
	return hits[p],lastAmount[p]
end
local function run()
	assert(waitFor(function() local n=0;for _,p in Players:GetPlayers() do if ready[p] then n+=1 end end return n>=2 end,120),"two ready clients required")
	task.wait(4)
	local list=Players:GetPlayers();table.sort(list,function(a,b)return a.UserId<b.UserId end)
	local a,b,c=list[1],list[2],list[3]
	record("population does not auto-start",Match.state()=="Waiting" and Match.modeOf(a)=="Practice" and Match.modeOf(b)=="Practice",{players=#list})
	record("ten existing practice targets",#workspace.Dummies:GetChildren()==10,#workspace.Dummies:GetChildren())
	local xpA=Data.get(a) and Data.get(a).xp
	stage(a,Vector3.new(-1255,3.5,-5));stage(b,Vector3.new(-1248,3.5,-5),Vector3.new(-1255,3.5,-5))
	if c then outside(c,4) end
	task.wait(1)
	local hit,amount=fire(a,b.Character,"UpperTorso")
	record("nonlethal body feedback agrees with authoritative pellet sum",hit and amount and amount.target==b.Name and not hit.headshot and hit.damage==math.round(amount.amount) and hum(b).Health==100 and not hit.killed,{hit=hit,expected=amount,health=hum(b).Health})
	remote:FireClient(a,"Swap");task.wait(0.5)
	hit,amount=fire(a,b.Character,"Head")
	record("nonlethal headshot feedback and full health",hit and amount and amount.target==b.Name and hit.headshot and hit.damage==math.round(amount.amount) and hum(b).Health==100,{hit=hit,expected=amount,health=hum(b).Health})
	record("lobby hits grant no kills deaths score or XP",a:GetAttribute("Kills")==0 and b:GetAttribute("Deaths")==0 and a:GetAttribute("Score")==0 and (not Data.get(a) or Data.get(a).xp==xpA),{})
	remote:FireClient(a,"Reload");task.wait(3)
	remote:FireClient(a,"Status")
	queue(a,1);task.wait(0.4)
	record("one queued player waits",state:GetAttribute("QueueCount")==1 and state:GetAttribute("QueueState")=="Waiting",state:GetAttribute("QueueCount"))
	queue(b,2);task.wait(0.4)
	record("two players begin countdown",state:GetAttribute("QueueState")=="Countdown" and state:GetAttribute("QueueCount")==2,{ends=state:GetAttribute("QueueEndsAt")})
	outside(b,1);task.wait(0.4)
	record("leaving cancels countdown",state:GetAttribute("QueueState")=="Waiting" and state:GetAttribute("QueueEndsAt")==0,{count=state:GetAttribute("QueueCount")})
	queue(b,2)
	for round,mapId in {"Warehouse","DustTown","Rooftops"} do
		if round>1 then for i,p in list do queue(p,i) end end
		task.wait(0.3)
		for _,p in list do print("[LOBBY_STAGED]",round,p.Name,root(p).Position,p:GetAttribute("Queued"),p.Character:GetAttribute("Dead")) end
		local began=workspace:GetServerTimeNow()
		assert(waitFor(function()return Match.state()=="Voting"end,20),"queue admission timeout")
		record("physical queue admits roster round "..round,Match.modeOf(a)=="Match" and Match.modeOf(b)=="Match",{elapsed=workspace:GetServerTimeNow()-began,outsider=c and Match.modeOf(c)})
		if round==1 and c then
			remote:FireClient(c,"Status");queue(c,3);task.wait(0.4)
			record("waiting queue remains lobby while arena reserved",Match.modeOf(c)=="Practice" and state:GetAttribute("QueueState")=="Pending",{count=state:GetAttribute("QueueCount")})
		end
		for _,p in list do if Match.modeOf(p)=="Match" then remote:FireClient(p,"Vote",mapId) end end
		assert(waitFor(function()return Match.state()=="Active"end,23),"match activation timeout")
		record("arena loaded "..mapId,Map.currentId==mapId,{actual=Map.currentId,players=state:GetAttribute("Players")})
		if round==1 then
			local marker=Map.spawns(a.Team.Name)[1];local pos=marker.Position+Vector3.new(0,3,0)
			stage(a,pos, pos+marker.CFrame.LookVector);stage(b,pos+marker.CFrame.LookVector*6,pos)
			task.wait(2.2)
			local old=b.Character
			fire(a,b.Character,"Head")
			if hum(b).Health>0 then remote:FireClient(a,"Swap");task.wait(0.6);fire(a,b.Character,"UpperTorso") end
			record("match PvP eliminates and scores",hum(b).Health<=0 and a:GetAttribute("Kills")==1 and (Match._match.scores.Red+Match._match.scores.Blue)==1,{health=hum(b).Health,kills=a:GetAttribute("Kills"),scores=Match._match.scores})
			record("match respawn completes",waitFor(function()return b.Character~=old and hum(b) and hum(b).Health==100 and b.Character:GetAttribute("SpawnCFrame")~=nil end,8),{})
		end
		-- Expedite only the test copy's round clock; do not edit production config.
		Match._match.timeLeft=0
		waitFor(function()return Match.state()=="Results" or Match.state()=="Overtime"end,2)
		if Match.state()=="Overtime" then Match._match.timeLeft=0 end
		assert(waitFor(function()return Match.state()=="Results"end,3),"results timeout")
		assert(waitFor(function()return Match.state()=="Waiting"end,12),"return timeout")
		assert(waitFor(function()for _,p in list do if not hum(p) or not p.Character:GetAttribute("SpawnCFrame") or not root(p) or root(p).Position.X>-1200 then return false end end return true end,12),"range respawn timeout")
		task.wait(0.3)
		local all=true
		for _,p in list do
			all=all and Match.modeOf(p)=="Practice" and p.Team==nil and hum(p).Health==100
			remote:FireClient(p,"Status")
		end
		record("return to lobby round "..round,all,{queued=state:GetAttribute("QueueCount")})
	end
	task.wait(2)
	record("final lobby does not auto-requeue returning players",state:GetAttribute("QueueCount")==0 and Match.state()=="Waiting",{})
	state:SetAttribute("ProbeComplete",true)
	state:SetAttribute("ProbeFailures",failures)
	print("[LOBBY_TEST_COMPLETE] failures="..failures)
end
local ok,err=xpcall(run,debug.traceback)
if not ok then warn("[LOBBY_TEST_FATAL] "..tostring(err)) end

