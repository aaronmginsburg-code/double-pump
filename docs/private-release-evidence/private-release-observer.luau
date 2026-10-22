local p=game.Players.LocalPlayer
local w=require(p.PlayerScripts:WaitForChild("Client").Controllers.WeaponController)
local remote=game.ReplicatedStorage.Remotes
local predicted=w.state.shotCounter
w.Fired:Connect(function(info) predicted=info.shotNumber; print("[RELEASE] FIRED",p.Name,info.slot,predicted); task.delay(.15,function() remote.WeaponAction:FireServer("Sync") end) end)
w.Reset:Connect(function() predicted=0; print("[RELEASE] RESET",p.Name,w.state.shotCounter) end)
remote.WeaponEvent.OnClientEvent:Connect(function(kind,a,b) if kind=="Snapshot" then print("[RELEASE] COUNTERS",p.Name,"client",predicted,"server",a.shotCounter,"reason",b) end end)
local function facing(c)
 local function inspect() task.delay(.6,function()
  if c~=p.Character then return end
  local cf=c:GetAttribute("SpawnCFrame")
  if typeof(cf)~="CFrame" then return end
  local look=workspace.CurrentCamera.CFrame.LookVector
  local horizontal=Vector3.new(look.X,0,look.Z).Unit
  print("[RELEASE] FACING",p.Name,"dot",horizontal:Dot(cf.LookVector),"spawn",cf.Position,"active",w.active)
 end) end
 c:GetAttributeChangedSignal("SpawnCFrame"):Connect(inspect)
 inspect()
end
p.CharacterAdded:Connect(facing)
if p.Character then facing(p.Character) end
print("[RELEASE] OBSERVER_READY",p.Name,w.state.shotCounter)

remote.WeaponAction:FireServer("Sync")

