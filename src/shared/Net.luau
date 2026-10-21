--!strict
-- Every RemoteEvent / RemoteFunction the game uses, created by the server at startup.
-- Weapon traffic goes through ONE ordered remote (WeaponAction) so an Equip always
-- arrives before the Fire that follows it.
--
-- Client -> server payloads are never trusted: every handler type-checks its arguments
-- and is rate limited (see Server/Services/Remotes.luau).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

Net.Events = {
	-- client -> server
	"WeaponAction", -- ("Equip", slot) | ("Fire", payload) | ("Reload") | ("CancelReload")
	"PlayerAction", -- ("Crouch", bool) | ("Look", pitch) | ("Deploy") | ("Practice") | ("Menu") | ("Vote", mapId) ...
	"ShopAction", -- ("Buy", itemId) | ("Equip", category, itemId) | ("BuyRobux", productKey)
	"SettingsAction", -- ("Save", settingsTable) | ("TutorialDone")

	-- server -> client
	"WeaponEvent", -- ("Snapshot", state) | ("Hit", results) | ("Shot", shooterCharacter, info) | ("Reset")
	"CombatEvent", -- ("Elimination", info) | ("Damaged", info) | ("Respawn", delay, killerName)
	"MatchEvent", -- ("Countdown", n) | ("Started") | ("Ended", results) | ("Voting", options) | ...
	"ProfileEvent", -- ("Profile", snapshot) | ("Reward", info) | ("Unlock", item)
	"Notify", -- (text, kind)
}

Net.Functions = {
	"GetLeaderboards",
	"GetProfile",
}

local FOLDER_NAME = "Remotes"

-- Server: create everything. Safe to call more than once.
function Net.setupServer(): Folder
	assert(RunService:IsServer(), "Net.setupServer is server-only")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME) :: Folder?
	if not folder then
		local newFolder = Instance.new("Folder")
		newFolder.Name = FOLDER_NAME
		newFolder.Parent = ReplicatedStorage
		folder = newFolder
	end
	assert(folder, "Remotes folder missing")
	for _, name in Net.Events do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in Net.Functions do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
	return folder
end

local function folder(): Folder
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

function Net.event(name: string): RemoteEvent
	return folder():WaitForChild(name) :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	return folder():WaitForChild(name) :: RemoteFunction
end

return Net
