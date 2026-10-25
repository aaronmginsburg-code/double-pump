-- Disposable Studio acceptance staging. NEVER publish.
assert(game.RunService:IsStudio())
local S=game.ServerScriptService.Server.Services
local Actors=require(S.Participants);local Bots=require(S.TrainingBotService);local CS=require(S.CharacterService)
local Combat=require(S.CombatService);local Damage=require(S.DamageService);local Context=require(S.CombatContext);local Match=require(S.MatchService)
local owner
local deadline=os.clock()+40
repeat owner=game.Players:GetPlayers()[1];task.wait(.2)until owner and #Bots.bots()==2 and Bots.bots()[2].model or os.clock()>deadline
assert(owner and owner.UserId==11808586604)
local bots=Bots.bots();assert(#bots==2)
task.wait(5)
for _,b in bots do assert(b.model.Humanoid.MaxHealth==100 and b.model.Humanoid.Health==100 and b.model:GetAttribute('BotState')=='Passive');assert(b.model:FindFirstChild('WorldShotgun'))end
assert(Match.state()=='Waiting');print('BOT_TEST_PASSIVE',#bots)
local deaths=0;local botDeaths=0;local spawns=0;local shots=0
CS.Died:Connect(function(p)if p==owner then deaths+=1;print('BOT_TEST_OWNER_DIED',deaths)elseif Actors.isBot(p)then botDeaths+=1;print('BOT_TEST_BOT_DIED',p.id)end end)
CS.Spawned:Connect(function(p)if p==owner then spawns+=1;print('BOT_TEST_OWNER_RESPAWN',spawns)end end)
Combat.ShotFired:Connect(function(p,slot,pellets,hits)if Actors.isBot(p)then shots+=1;if shots<8 then print('BOT_TEST_SHOT',p.id,slot,pellets,hits,os.clock())end end end)
local oldHealth=bots[1].model.Humanoid.Health
CS.transfer(owner,CFrame.lookAt(Vector3.new(-1255,.5,-9),Vector3.new(-1249,.5,-9)))
workspace:SetAttribute('BotsTestPhase','Provoke')
deadline=os.clock()+12
repeat task.wait(.1)until Context.trainingActive(owner)or os.clock()>deadline
assert(Context.trainingActive(owner),'legitimate client shot did not activate training')
print('BOT_TEST_PROVOKED',oldHealth,bots[1].model.Humanoid.Health)
workspace:SetAttribute('BotsTestPhase','ObserveDuel')
deadline=os.clock()+45
repeat task.wait(.2)until deaths>0 and spawns>1 or os.clock()>deadline
assert(shots>0 and deaths>0 and spawns>1,'bots must actually fire, eliminate and allow normal owner respawn')
print('BOT_TEST_DUEL_COMPLETE',shots,deaths,spawns)
Context.stopTraining(owner)
workspace:SetAttribute('BotsTestPhase','EliminateBot')
deadline=os.clock()+35
repeat task.wait(.2)until botDeaths>0 or os.clock()>deadline
assert(botDeaths>0,'player could not eliminate bot')
workspace:SetAttribute('BotsTestPhase','ObserveRespawn')
Context.stopTraining(owner);task.wait(4)
assert(#Bots.bots()==2 and bots[1].model.Humanoid.Health>0)
print('BOT_TEST_BOT_RESPAWN_COMPLETE')
Context.stopTraining(owner)
CS.transfer(owner,CFrame.new(-1252,.5,25));task.wait(1)
owner.Character.Humanoid:MoveTo(Vector3.new(-1252,3,37));workspace:SetAttribute('BotsTestPhase','QueueCancel')
deadline=os.clock()+22
repeat task.wait(1);print('BOT_TEST_QUEUE_DIAG',owner.Character.HumanoidRootPart.Position,game.ReplicatedStorage.MatchState:GetAttribute('QueueCount'));for _,b in bots do print('BOT_TEST_NAV',b.id,b.model.HumanoidRootPart.Position,b.state,b.pathSuccess or 0,b.pathFailures or 0)end until game.ReplicatedStorage.MatchState:GetAttribute('QueueCount')==3 or os.clock()>deadline
assert(game.ReplicatedStorage.MatchState:GetAttribute('QueueCount')==3,'bots failed physical navigation into queue')
print('BOT_TEST_PHYSICAL_QUEUE',bots[1].model.HumanoidRootPart.Position,bots[2].model.HumanoidRootPart.Position)
owner.Character.Humanoid:MoveTo(Vector3.new(-1252,3,20));task.wait(2)
assert(game.ReplicatedStorage.MatchState:GetAttribute('QueueCount')==0 and Match.state()=='Waiting','queue cancellation failed')
print('BOT_TEST_QUEUE_CANCELLED')
for round,mapId in {'Warehouse','DustTown','Rooftops'}do
 Context.stopTraining(owner);workspace:SetAttribute('BotsTestVote',mapId)
 owner.Character.Humanoid:MoveTo(Vector3.new(-1252,3,37));workspace:SetAttribute('BotsTestPhase','QueueMatch')
 deadline=os.clock()+65
 repeat task.wait(.2)until Match.state()=='Active' or os.clock()>deadline
 assert(Match.state()=='Active','physical match admission failed')
 assert(owner.Team.Name=='Red' and bots[1].team=='Blue' and bots[2].team=='Blue')
 assert(game.ReplicatedStorage.MatchState:GetAttribute('MapId')==mapId,'vote map mismatch')
 print('BOT_TEST_MATCH_ACTIVE',mapId)
 workspace:SetAttribute('BotsTestPhase','MatchCombat')
 local beforeShots=shots;local beforeDeaths=deaths
 task.wait(35)
 assert(shots>beforeShots,'no normal AI combat on '..mapId)
 print('BOT_TEST_MATCH_COMBAT',mapId,shots-beforeShots,deaths-beforeDeaths)
 -- Expedite only the disposable test round clock AFTER genuine combat, not admission or shots.
 Match._match.timeLeft=0
 deadline=os.clock()+75
 repeat task.wait(.2)until Match.state()=='Results' or os.clock()>deadline
 assert(Match.state()=='Results');print('BOT_TEST_RESULTS',mapId,Match._match.scores.Red,Match._match.scores.Blue)
 workspace:SetAttribute('BotsTestPhase','Results')
 deadline=os.clock()+15
 repeat task.wait(.2)until Match.state()=='Waiting' or os.clock()>deadline
 assert(Match.state()=='Waiting');task.wait(3)
 assert(owner.Character.Humanoid.Health==100 and owner:GetAttribute('Mode')=='Practice' and not owner:GetAttribute('Queued'))
 for _,b in bots do assert(b.model.Humanoid.Health==100 and b.model:GetAttribute('BotState')=='Passive')end
 print('BOT_TEST_RETURN',mapId)
end
workspace:SetAttribute('BotsTestPhase','Complete');print('BOT_TEST_SOLO_COMPLETE')
