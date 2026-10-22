-- Temporary CLIENT command-bar observer. Never included in the Rojo place.
local p = game.Players.LocalPlayer
local c = p.PlayerScripts.Client.Controllers
local w, camera = require(c.WeaponController), require(c.CameraController)
local input, settings = require(c.InputController), require(c.Settings)
local remotes = game.ReplicatedStorage.Remotes
_G.MobileProbe = { shots = {}, rejected = 0 }
w.Fired:Connect(function(info)
	local shots = _G.MobileProbe.shots
	local t = workspace:GetServerTimeNow()
	print("[REVISION] SHOT", info.slot, info.shotNumber, t, if #shots > 0 then t - shots[#shots].t else 0)
	table.insert(shots, { slot = info.slot, n = info.shotNumber, t = t })
	task.delay(0.15, function() remotes.WeaponAction:FireServer("Sync") end)
end)
w.Rejected:Connect(function(reason)
	_G.MobileProbe.rejected += 1
	print("[REVISION] REJECTED", reason)
end)
remotes.WeaponEvent.OnClientEvent:Connect(function(kind, data, reason)
	if kind == "Snapshot" then
		print("[REVISION] SNAPSHOT", data.shotCounter, data.equipped, reason)
	end
end)
w.Equipped:Connect(function(slot) print("[REVISION] EQUIP", slot) end)
w.Reset:Connect(function() print("[REVISION] RESET", w.state.shotCounter, settings.values.controlLayout) end)
local function role(pos)
	for _, obj in p.PlayerGui:GetGuiObjectsAtPosition(pos.X, pos.Y) do
		if obj:IsA("TextButton") and obj:IsDescendantOf(p.PlayerGui.MobileControls) then return obj.Name end
	end
	return "None"
end
local ownership = {}
game:GetService("UserInputService").TouchStarted:Connect(function(t)
	ownership[t] = role(t.Position)
	print("[REVISION] DOWN", ownership[t], t.Position, camera.yaw, camera.pitch)
end)
game:GetService("UserInputService").TouchEnded:Connect(function(t)
	local r = ownership[t]
	print("[REVISION] UP", r, t.Position, camera.yaw, camera.pitch)
	if r == "None" then
		local yaw = camera.yaw
		task.delay(0.4, function() print("[REVISION] LOOK_RELEASE_DRIFT", camera.yaw-yaw) end)
	end
	ownership[t] = nil
end)
print("[REVISION] OBSERVER", input.LastInputKind, settings.values.controlLayout, workspace.CurrentCamera.ViewportSize)
for _, b in p.PlayerGui.MobileControls.TouchSurface:GetChildren() do
	if b:IsA("GuiObject") then print("[REVISION] BOUNDS", b.Name, b.AbsolutePosition, b.AbsoluteSize) end
end

local probe=Instance.new("Folder");probe.Name="RevisionProbe";probe.Parent=p.PlayerGui;for _,key in {"controlLayout","weaponHand"} do probe:GetAttributeChangedSignal(key):Connect(function() settings.set(key,probe:GetAttribute(key));settings.save();print("[REVISION] PREFERENCE",key,settings.values.controlLayout,settings.values.weaponHand) end) end
print("[REVISION] NO_LOOK_GUI",p.PlayerGui.MobileControls.TouchSurface:FindFirstChild("Look")==nil)