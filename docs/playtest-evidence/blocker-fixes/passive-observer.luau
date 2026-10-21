-- Test-only observer inserted into the running local server, never the place source.
local Players = game:GetService("Players")
local services = game:GetService("ServerScriptService").Server.Services
local combat = require(services.CombatService)
local characters = require(services.CharacterService)
local lastShot = {}
local function position(player, label)
	local c = player.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	local h = c and c:FindFirstChildOfClass("Humanoid")
	local arena = workspace:FindFirstChild("Arena")
	local map = if player:GetAttribute("Mode") == "Practice" then workspace:FindFirstChild("Range") else arena
	local markers = map and map:FindFirstChild("Markers")
	local nearest, horizontal = math.huge, math.huge
	if root and markers then
		for _, m in markers:GetChildren() do
			if m.Name == "Spawn" and m:GetAttribute("Team") == (if player.Team then player.Team.Name else "Range") then
				local d = root.Position - m.Position
				nearest = math.min(nearest, d.Magnitude)
				horizontal = math.min(horizontal, Vector3.new(d.X, 0, d.Z).Magnitude)
			end
		end
	end
	print("[DPTEST] POSITION", label, player.Name, player:GetAttribute("Mode"), player.Team and player.Team.Name, root and root.Position, "nearest", nearest, "xz", horizontal, "hp", h and h.Health, "protected", c and c:GetAttribute("ProtectedUntil"), "now", workspace:GetServerTimeNow(), "frozen", c and c:GetAttribute("Frozen"), "map", arena and arena:GetAttribute("MapId"))
end
combat.ShotFired:Connect(function(player, slot, pellets, hits)
	local now = workspace:GetServerTimeNow()
	print("[DPTEST] ACCEPTED", player.Name, "t", now, "dt", lastShot[player] and now-lastShot[player], "slot", slot, "pellets", pellets, "hits", hits, "stats", combat.stats.accepted, combat.stats.rejected, combat.stats.hitsAccepted, combat.stats.hitsRejected)
	lastShot[player] = now
end)
characters.Spawned:Connect(function(player)
	position(player, "Spawned")
	task.delay(1, position, player, "Spawned+1s")
end)
for _,player in Players:GetPlayers() do position(player,"observer attached") end
local dummies=workspace:FindFirstChild("Dummies")
print("[DPTEST] OBSERVER_READY",combat.stats.accepted,combat.stats.rejected,"dummies",dummies and #dummies:GetChildren(),"destroyHeight",workspace.FallenPartsDestroyHeight)
if dummies then
	local function watch(dummy)
		local h=dummy:FindFirstChildOfClass("Humanoid")
		if h then h.HealthChanged:Connect(function(health) print("[DPTEST] TARGET_HP",dummy.Name,health) end) end
	end
	for _,dummy in dummies:GetChildren() do watch(dummy) end
	dummies.ChildAdded:Connect(watch)
end

