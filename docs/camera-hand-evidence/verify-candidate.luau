-- Evidence utility only; outside Rojo's source tree.
local fs = require("@lune/fs")
local R = require("@lune/roblox")
local place = R.deserializePlace(fs.readFile("build/DoublePump_CAMERA_HAND_REVISION.rbxl"))
local count = 0
local function normal(s)
	return s:gsub("\r\n", "\n")
end
local function check(dir, node)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			check(path, assert(node:FindFirstChild(name), "missing folder: " .. path))
		elseif name:match("%.luau$") then
			local stem = name:gsub("%.luau$", ""):gsub("%.server$", ""):gsub("%.client$", "")
			local target = if stem == "init" then node else node:FindFirstChild(stem)
			assert(target and target:IsA("LuaSourceContainer"), "missing script: " .. path)
			assert(normal(target.Source) == normal(fs.readFile(path)), "stale source: " .. path)
			count += 1
		end
	end
end
check("src/shared", place.ReplicatedStorage.Shared)
check("src/client", place.StarterPlayer.StarterPlayerScripts.Client)
check("src/server", place.ServerScriptService.Server)
check("src/character", place.StarterPlayer.StarterCharacterScripts)
local built = 0
for _, item in place:GetDescendants() do
	if item:IsA("LuaSourceContainer") then
		built += 1
	end
end
assert(built == count, "unexpected scripts in candidate")
assert(place.Players.CharacterAutoLoads == false)
assert(math.abs(place.Workspace.Gravity - 196.2) < 0.001) -- serialized float32
assert(place.Workspace.FallenPartsDestroyHeight == -120)
print("Candidate matches all " .. count .. " local script containers; no test-only scripts; place settings preserved")
