-- Disposable Studio-only acceptance probe. Never publish this script.
assert(game.RunService:IsStudio() and game.GameId==10772492892 and game.PlaceId==139437092998076)
local S=game.ServerScriptService.Server.Services
local Bots=require(S.TrainingBotService);local C=require(S.CombatContext);local Combat=require(S.CombatService)
local Character=require(S.CharacterService);local Match=require(S.MatchService)
local deadline=os.clock()+45;local owner
repeat task.wait(.2);owner=game.Players:GetPlayers()[1]until owner and owner.Character and #Bots.bots()==2 and Bots.bots()[2].model or os.clock()>deadline
assert(owner and owner.UserId==11808586604 and #Bots.bots()==2)
task.wait(5)
local shots=0;local dead=false
local sc=Combat.ShotFired:Connect(function(p)if require(S.Participants).isBot(p)then shots+=1 end end)
local dc=Character.Died:Connect(function(p)if p==owner then dead=true end end)
local function stage()
 Character.transfer(owner,CFrame.lookAt(Vector3.new(-1258,.5,0),Vector3.new(-1249,.5,0)))
end
stage();task.wait(2);workspace:SetAttribute('PassiveResetPhase','Provoke')
deadline=os.clock()+12;repeat task.wait(.1)until C.trainingActive(owner)or os.clock()>deadline
assert(C.trainingActive(owner),'No genuine provocation');workspace:SetAttribute('PassiveResetPhase','Hostile')
deadline=os.clock()+45;repeat task.wait(.1)until dead or os.clock()>deadline
assert(dead and shots>0,'Bots must actually eliminate the owner')
task.wait(.3);assert(not C.trainingActive(owner),'Duel survives owner death')
local afterDeath=shots
for _,b in Bots.bots()do
 assert(b.target==nil and b.lastSeen==nil and b.swapAt==nil and b.moveGoal==nil and b.goal==nil)
 if b.model.Humanoid.Health>0 then assert(b.model:GetAttribute('BotState')=='Passive')end
end
print('PASSIVE_RESET_DEATH',shots)
deadline=os.clock()+12;repeat task.wait(.1)until owner.Character and owner.Character.Humanoid.Health==100 and not owner.Character:GetAttribute('Dead')or os.clock()>deadline
assert(owner.Character.Humanoid.Health==100);workspace:SetAttribute('PassiveResetPhase','Respawned');task.wait(8)
assert(shots==afterDeath and owner.Character.Humanoid.Health==100 and not C.trainingActive(owner))
for _,b in Bots.bots()do assert(b.model:GetAttribute('BotState')=='Passive')end
print('PASSIVE_RESET_RESPAWN_SAFE',shots,owner.Character.Humanoid.Health)
stage();task.wait(2);workspace:SetAttribute('PassiveResetPhase','ProvokeAgain')
deadline=os.clock()+12;repeat task.wait(.1)until C.trainingActive(owner)or os.clock()>deadline
assert(C.trainingActive(owner),'Fresh hit must reactivate duel');workspace:SetAttribute('PassiveResetPhase','HostileAgain')
deadline=os.clock()+12;repeat task.wait(.1)until shots>afterDeath or os.clock()>deadline
assert(shots>afterDeath);print('PASSIVE_RESET_REPROVOKED',shots)
sc:Disconnect();dc:Disconnect();workspace:SetAttribute('PassiveResetPhase','Complete');print('PASSIVE_RESET_COMPLETE',Match.modeOf(owner))
