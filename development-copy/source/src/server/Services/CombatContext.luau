--!strict
-- Server-owned participation, independent of client-supplied attributes/remotes.
-- Attributes only mirror this table for client raycast prediction.
local Players = game:GetService("Players")

local Actors = require(script.Parent.Participants)
local Policy = require(game:GetService("ReplicatedStorage").Shared.Training.Policy)
local training: { [Player]: boolean } = {}
local CombatContext = {}
type Entry = { kind: string, matchId: number }
local entries: { [Player]: Entry } = {}
local activeMatch: number? = nil

function CombatContext.set(player: Player, kind: string, matchId: number?)
	entries[player] = { kind = kind, matchId = matchId or 0 }
	local character = Actors.character(player)
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
	training[player] = nil
end

function CombatContext.resolve(attacker: Player, target: Model): string
	local a = entries[attacker]
	local shooter = Actors.character(attacker)
	if not a or not shooter or shooter == target then
		return "Blocked"
	end
	if target:GetAttribute("Dummy") == true then
		return if a.kind == "Lobby" then "Dummy" else "Blocked"
	end
	local victim = Actors.fromModel(target)
	local b = victim and entries[victim]
	if not victim or Actors.character(victim) ~= target or not b then
		return "Blocked"
	end
	if a.kind == "Lobby" and b.kind == "Lobby" then
		local owner = Actors.owner()
		if Actors.isBot(attacker) or Actors.isBot(victim) then
			return if owner
					and Policy.lobbyAllowed(attacker, victim, owner, Actors.list(), training[owner] == true)
				then "Training"
				else "Blocked"
		end
		return "Practice"
	end
	if a.kind == "Match" and b.kind == "Match" and a.matchId == activeMatch and b.matchId == activeMatch then
		local at = if Actors.isBot(attacker) then attacker.team else (attacker.Team and attacker.Team.Name)
		local bt = if Actors.isBot(victim) then victim.team else (victim.Team and victim.Team.Name)
		if at and bt and at ~= bt then
			return "Match"
		end
	end
	return "Blocked"
end

function CombatContext.beginTraining(attacker: any, target: Model)
	local bot = Actors.fromModel(target)
	if Actors.isBot(bot) and bot.owner == attacker and CombatContext.resolve(attacker, target) == "Training" then
		training[attacker] = true
	end
end
function CombatContext.stopTraining(owner: Player)
	training[owner] = nil
end
function CombatContext.trainingActive(owner: Player): boolean
	return training[owner] == true
end
return CombatContext
