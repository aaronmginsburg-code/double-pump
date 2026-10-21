
local p=game:GetService("Players").LocalPlayer
local w=require(p.PlayerScripts:WaitForChild("Client").Controllers.WeaponController)
w.Fired:Connect(function(info) print("[DPTEST] PREDICTED",p.Name,workspace:GetServerTimeNow(),info.slot,info.shotNumber) end)
w.Equipped:Connect(function(slot, previous, spawn) print("[DPTEST] EQUIP",p.Name,workspace:GetServerTimeNow(),slot,previous,spawn) end)
w.HitConfirmed:Connect(function(results) for _,r in results do print("[DPTEST] HIT",p.Name,r.damage,r.pellets,r.killed,r.protected) end end)
w.Rejected:Connect(function(reason) print("[DPTEST] REJECTED",p.Name,workspace:GetServerTimeNow(),reason) end)
w.Reset:Connect(function() print("[DPTEST] RESET",p.Name,w.state.shotCounter) end)
game.ReplicatedStorage.Remotes.WeaponEvent.OnClientEvent:Connect(function(kind,a,b)
 if kind=="Shot" then print("[DPTEST] REPLICATED",p.Name,a.Name,workspace:GetServerTimeNow(),b.slot,b.shot)
 elseif kind=="Snapshot" then print("[DPTEST] SNAPSHOT",p.Name,a.shotCounter,a.slots[1].ammo,a.slots[2].ammo,b) end
end)
print("[DPTEST] CLIENT_OBSERVER",p.Name,"counter",w.state.shotCounter,"active",w.active)

