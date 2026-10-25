-- Disposable local-server acceptance; no production permission bypass ships.
assert(game.RunService:IsStudio() and game.GameId==10772492892 and game.PlaceId==139437092998076)
local S=game.ServerScriptService.Server.Services
require(S.DeveloperAccess).UserIds[-1]=true -- ONLY a real Studio simulated Player, never a spoofed object.
local Actors=require(S.Participants);local Bots=require(S.TrainingBotService);local CS=require(S.CharacterService)
local Combat=require(S.CombatService);local Damage=require(S.DamageService);local Context=require(S.CombatContext);local Match=require(S.MatchService);local Data=require(S.DataService)
local deadline=os.clock()+600
repeat task.wait(.2)until #game.Players:GetPlayers()==2 or os.clock()>deadline
local owner,other
for _,p in game.Players:GetPlayers()do if p.UserId==-1 then owner=p elseif p.UserId==-2 then other=p end end
assert(owner and other)
deadline=os.clock()+30
repeat task.wait(.2)until #Bots.bots()==2 and Bots.bots()[2].model and Data.get(owner) and Data.get(other) or os.clock()>deadline
local bots=Bots.bots();assert(#bots==2);task.wait(5)
local function snapshot(p)
 local d=Data.get(p);assert(d);return {xp=d.xp,coins=d.coins,mastery=d.masteryKills,stats=table.clone(d.stats)}
end
local before={snapshot(owner),snapshot(other)}
CS.transfer(owner,CFrame.lookAt(Vector3.new(-1260,.5,0),Vector3.new(-1249,.5,0)))
workspace:SetAttribute('BotsMultiPhase','PhotoPassive');print('BOT_MULTI_PASSIVE',#workspace.TrainingBots:GetChildren());task.wait(12)
assert(Match.state()=='Waiting')
CS.transfer(owner,CFrame.lookAt(Vector3.new(-1255,.5,-9),Vector3.new(-1255,.5,-15)))
CS.transfer(other,CFrame.new(-1255,.5,-15));workspace:SetAttribute('BotsMultiPhase','HumanPractice')
local humanoid=other.Character.Humanoid;local health=humanoid.Health;local hit=false
local hitConnection=Combat.ShotFired:Connect(function(p,_,_,hits)if p==owner and hits>0 then hit=true end end)
deadline=os.clock()+8;repeat task.wait(.1)until hit or os.clock()>deadline
assert(hit and humanoid.Health==health and health==100,'nonlethal human practice changed');hitConnection:Disconnect()
print('BOT_MULTI_HUMAN_NONLETHAL',health)
CS.transfer(other,CFrame.new(-1259,.5,-9));workspace:SetAttribute('BotsMultiPhase','Provoke')
deadline=os.clock()+8;repeat task.wait(.1)until Context.trainingActive(owner)or os.clock()>deadline
assert(Context.trainingActive(owner));local shots=0
local shotConnection=Combat.ShotFired:Connect(function(p)if Actors.isBot(p)then shots+=1 end end)
workspace:SetAttribute('BotsMultiPhase','Observe');task.wait(8)
assert(shots>0 and other.Character.Humanoid.Health==100)
for _,bot in bots do assert(Context.resolve(bot,other.Character)=='Blocked')end
print('BOT_MULTI_UNINVOLVED_SAFE',shots,other.Character.Humanoid.Health)
Context.stopTraining(owner)
CS.transfer(owner,CFrame.new(-1252,.5,25));task.wait(1);owner.Character.Humanoid:MoveTo(Vector3.new(-1252,3,37))
workspace:SetAttribute('BotsMultiPhase','Queue')
deadline=os.clock()+25
repeat task.wait(.2)until game.ReplicatedStorage.MatchState:GetAttribute('QueueCount')==3 or os.clock()>deadline
assert(game.ReplicatedStorage.MatchState:GetAttribute('QueueCount')==3)
assert(Match.modeOf(other)=='Practice'and not other:GetAttribute('Queued'))
print('BOT_MULTI_OWNER_ONLY_QUEUE')
owner.Character.Humanoid:MoveTo(Vector3.new(-1252,3,20));deadline=os.clock()+8;repeat task.wait(.2)until game.ReplicatedStorage.MatchState:GetAttribute('QueueCount')==0 or os.clock()>deadline
assert(game.ReplicatedStorage.MatchState:GetAttribute('QueueCount')==0)
CS.transfer(other,CFrame.new(-1257,.5,37));owner.Character.Humanoid:MoveTo(Vector3.new(-1252,3,37))
workspace:SetAttribute('BotsMultiPhase','QueueBoth')
deadline=os.clock()+60;repeat task.wait(.2)until Match.state()=='Active'or os.clock()>deadline
assert(Match.state()=='Active'and owner.Team.Name=='Red'and other.Team.Name=='Red'and bots[1].team=='Blue'and bots[2].team=='Blue')
print('BOT_MULTI_BALANCED_2V2',game.ReplicatedStorage.MatchState:GetAttribute('MapId'))
workspace:SetAttribute('BotsMultiPhase','Match');task.wait(40)
assert(shots>2);local ended
local endedConnection=Match.MatchEnded:Connect(function(r)ended=r end)
Match._match.timeLeft=0
deadline=os.clock()+75;repeat task.wait(.2)until Match.state()=='Results'or os.clock()>deadline
assert(ended and ended.training==true);workspace:SetAttribute('BotsMultiPhase','Results')
print('BOT_MULTI_RESULTS',Match._match.scores.Red,Match._match.scores.Blue)
deadline=os.clock()+15;repeat task.wait(.2)until Match.state()=='Waiting'or os.clock()>deadline
task.wait(3)
for i,p in {owner,other}do
 assert(Match.modeOf(p)=='Practice'and p.Character.Humanoid.Health==100 and not p:GetAttribute('Queued'))
 local d=snapshot(p);assert(d.xp==before[i].xp and d.coins==before[i].coins and d.mastery==before[i].mastery)
 for k,v in before[i].stats do assert(d.stats[k]==v,'permanent stat changed '..k)end
 local w=Combat.getState(p);assert(w.slots[1].ammo==5 and w.slots[2].ammo==5)
end
print('BOT_MULTI_NO_PROFILE_REWARDS')
for _,b in bots do assert(b.model:GetAttribute('BotState')=='Passive'and not b.model:GetAttribute('Queued'))end
print('BOT_MULTI_METRICS',Bots.metrics.steps,Bots.metrics.maxStepMs,bots[1].pathSuccess,bots[2].pathSuccess,bots[1].pathFailures or 0,bots[2].pathFailures or 0)
workspace:SetAttribute('BotsMultiPhase','Returned');task.wait(8)
assert(owner.UserId<0);owner:Kick('Isolated Studio disconnect cleanup test')
task.wait(3);assert(#Bots.bots()==0 and #workspace.TrainingBots:GetChildren()==0)
assert(Match.modeOf(other)=='Practice'and other.Character.Humanoid.Health==100)
endedConnection:Disconnect();shotConnection:Disconnect();workspace:SetAttribute('BotsMultiPhase','Complete');print('BOT_MULTI_COMPLETE')
