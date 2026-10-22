local fs = require("@lune/fs")
local R = require("@lune/roblox")
local args = require("@lune/process").args
local function sources(path)
	local place = R.deserializePlace(fs.readFile(path))
	local out = {}
	for _, item in place:GetDescendants() do
		if item:IsA("LuaSourceContainer") then out[item:GetFullName()] = item.Source:gsub("\r\n", "\n") end
	end
	return out, place
end
local expected = sources("build/DoublePump_CAMERA_HAND_REVISION.rbxl")
local actual, place = sources(args[1] or "build/DoublePump_CAMERA_HAND_STUDIO_VERIFIED.rbxl")
local count = 0
for name, source in expected do
	assert(actual[name] == source, "Source mismatch: " .. name)
	count += 1
end
for name in actual do assert(expected[name], "Unexpected script: " .. name) end
assert(place.Players.CharacterAutoLoads == false)
assert(place.Workspace.FallenPartsDestroyHeight == -120)
print("Place matches final candidate: " .. count .. " script containers; no temporary test scripts")
