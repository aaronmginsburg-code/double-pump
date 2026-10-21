-- Controlled local PvP setup uses real player characters and normal weapon validation.
local players=game:GetService("Players")
local p=players.LocalPlayer
local target=players.Player2.Character
local h=target:FindFirstChildOfClass("Humanoid")
local controllers=p.PlayerScripts.Client.Controllers
local w=require(controllers.WeaponController)
local camera=require(controllers.CameraController)
task.wait(1)
w.equip(1)
task.wait(0.3)
for i=1,3 do
	if not target.Parent or h.Health<=0 then break end
	local direction=(target.Head.Position-workspace.CurrentCamera.CFrame.Position).Unit
	camera.yaw=math.atan2(-direction.X,-direction.Z)
	camera.pitch=math.asin(direction.Y)
	task.wait(0.1)
	print("[DPTEST] PVP_TRIGGER",i,"targetHP",h.Health)
	w.tryFire()
	task.wait(1.1)
end
print("[DPTEST] PVP_DONE",h.Health)
