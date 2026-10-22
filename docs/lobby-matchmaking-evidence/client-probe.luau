-- TEST COPY ONLY. Not mapped by Rojo; never publish the instrumented place.
local P = game:GetService("Players").LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local remote = RS:WaitForChild("LobbyTestProbe")
local C = P:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("Controllers")
local W = require(C.WeaponController)
local Camera = require(C.CameraController)
local Net = require(RS.Shared.Net)
Camera.requestCursor() -- staged aiming: prevent desktop cursor warps across simultaneous test windows
W.HitConfirmed:Connect(function(results)
	for _, hit in results do
		remote:FireServer("Hit", {damage=hit.damage,headshot=hit.headshot,killed=hit.killed,pellets=hit.pellets})
		print("[LOBBY_CLIENT_HIT]",game:GetService("HttpService"):JSONEncode(hit))
	end
end)
W.Rejected:Connect(function(reason) print("[LOBBY_CLIENT_REJECT]",reason) end)
remote.OnClientEvent:Connect(function(action,data)
	if action == "Aim" then
		Camera.lookAlong(CFrame.lookAt(workspace.CurrentCamera.CFrame.Position,data))
		Camera.pitch=math.asin((data-workspace.CurrentCamera.CFrame.Position).Unit.Y)
	elseif action == "Shoot" then
		Camera.lookAlong(CFrame.lookAt(workspace.CurrentCamera.CFrame.Position,data))
		Camera.pitch=math.asin((data-workspace.CurrentCamera.CFrame.Position).Unit.Y)
		task.wait(0.3)
		W.tryFire()
	elseif action == "Swap" then W.swap()
	elseif action == "Reload" then W.reload()
	elseif action == "Vote" then Net.event("PlayerAction"):FireServer("Vote",data)
	elseif action == "Status" then
		local post=P.PlayerGui:FindFirstChild("Postgame")
		remote:FireServer("Status",{mode=P:GetAttribute("Mode"),active=W.active,ammoA=W.view(1).ammo,ammoB=W.view(2).ammo,postgame=post and post.Enabled})
	end
end)
task.spawn(function()
	while not W.active do task.wait(0.2) end
	remote:FireServer("Ready")
end)
