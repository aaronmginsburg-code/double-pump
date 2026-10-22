--!strict
-- Server-owned participation, independent of client-supplied attributes/remotes.
-- Attributes only mirror this table for client raycast prediction.
local Players = game:GetService("Players")

local CombatContext = {}
type Entry = { kind: string, matchId: number }
local entries: { [Player]: Entry } = {}
local activeMatch: number? = nil

function CombatContext.set(player: Player, kind: string, matchId: number?)
	entries[player] = { kind = kind, matchId = matchId or 0 }
	local character = player.Character
	if character then
		character:SetAttribute("CombatContext", kind)
		character:SetAttribute("CombatMatchId", matchId or 0)
	end
end

function CombatContext.refresh(player: Player)
	local entry = entries[player]
	if entry then
		CombatContext.set(player, entry.kind, entry.matchId)
	end
end

function CombatContext.activate(matchId: number?)
	activeMatch = matchId
end

function CombatContext.forget(player: Player)
	entries[player] = nil
end

function CombatContext.resolve(attacker: Player, target: Model): string
	local a = entries[attacker]
	local shooter = attacker.Character
	if not a or not shooter or shooter == target then
		return "Blocked"
	end
	if target:GetAttribute("Dummy") == true then
		return if a.kind == "Lobby" then "Dummy" else "Blocked"
	end
	local victim = Players:GetPlayerFromCharacter(target)
	local b = victim and entries[victim]
	if not victim or victim.Character ~= target or not b then
		return "Blocked"
	end
	if a.kind == "Lobby" and b.kind == "Lobby" then
		return "Practice"
	end
	if a.kind == "Match" and b.kind == "Match" and a.matchId == activeMatch and b.matchId == activeMatch then
		local at, bt = attacker.Team, victim.Team
		if at and bt and at ~= bt then
			return "Match"
		end
	end
	return "Blocked"
end

return CombatContext
