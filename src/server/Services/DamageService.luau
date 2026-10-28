--!strict
-- The only place health goes down. Tracks who damaged whom (assists), detects
-- double-pump eliminations, and announces eliminations. Server authoritative: clients
-- never report damage or kills, they only get told about them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Combatants = require(Shared.Combatants)
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local CharacterService = require(script.Parent.CharacterService)
local CombatContext = require(script.Parent.CombatContext)

local Actors = require(script.Parent.Participants)
local DamageService = {}

export type HitInfo = {
	slot: number,
	headshot: boolean,
	distance: number,
	origin: Vector3,
	pellets: number,
}

export type Elimination = {
	victim: Model,
	victimPlayer: Player?,
	killer: Player?,
	assists: { Player },
	headshot: boolean,
	doublePump: boolean,
	distance: number,
}

DamageService.Eliminated = Signal.new() :: Signal.Signal<Elimination>
DamageService.Damaged = Signal.new() :: Signal.Signal<Player?, Model, number, HitInfo>

type LogEntry = { attacker: Player, amount: number, time: number }
local damageLog: { [Model]: { LogEntry } } = {}
-- attacker -> target -> last hit (for double pump detection)
local lastHits: { [Player]: { [Model]: { slot: number, time: number } } } = {}

local combatEvent: RemoteEvent

local function teamOf(model: Model?): string?
	return model and Combatants.team(model)
end

local function nameOf(model: Model): string
	local player = Actors.fromModel(model)
	if player then
		return Actors.name(player)
	end
	return model.Name
end

-- Returns: damage actually dealt, killed?, doublePump?
function DamageService.apply(
	attacker: Player?,
	target: Model,
	amount: number,
	info: HitInfo
): (number, boolean, boolean)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or target:GetAttribute("Dead") == true then
		return 0, false, false
	end
	if attacker then
		local context = CombatContext.resolve(attacker, target)
		if context == "Blocked" then
			return 0, false, false
		elseif context == "Practice" then
			-- The caller already aggregated the authoritative pellet damage. Report
			-- its full hypothetical value, without health changes, logs or signals.
			return amount, false, false
		end
	end
	if attacker then
		CombatContext.beginTraining(attacker, target)
	end
	if CharacterService.isProtected(target) then
		return 0, false, false
	end
	local now = os.clock()
	local dealt = math.min(amount, humanoid.Health)
	humanoid.Health -= dealt
	local killed = humanoid.Health <= 0

	local doublePump = false
	if attacker then
		local log = damageLog[target]
		if not log then
			log = {}
			damageLog[target] = log
		end
		table.insert(log, { attacker = attacker, amount = dealt, time = now })

		local byTarget = lastHits[attacker]
		if not byTarget then
			byTarget = {}
			lastHits[attacker] = byTarget
		end
		local previous = byTarget[target]
		if
			killed
			and previous
			and previous.slot ~= info.slot
			and now - previous.time <= WeaponConfig.DoublePumpWindow
		then
			doublePump = true
		end
		byTarget[target] = { slot = info.slot, time = now }
	end

	DamageService.Damaged:Fire(attacker, target, dealt, info)
	local victimPlayer = Actors.fromModel(target)
	if victimPlayer and not Actors.isBot(victimPlayer) then
		combatEvent:FireClient(victimPlayer, "Damaged", {
			amount = dealt,
			from = info.origin,
			health = humanoid.Health,
		})
	end

	if killed then
		local assists = {}
		local seen: { [Player]: number } = {}
		local entries: { LogEntry } = damageLog[target] or {}
		for _, entry in entries do
			if entry.attacker ~= attacker and now - entry.time <= GameConfig.Player.AssistWindow then
				seen[entry.attacker] = (seen[entry.attacker] or 0) + entry.amount
			end
		end
		for player, total in seen do
			if total >= GameConfig.Player.AssistMinDamage and Actors.exists(player) then
				table.insert(assists, player)
			end
		end
		damageLog[target] = nil
		target:SetAttribute("Dead", true)

		local elimination: Elimination = {
			victim = target,
			victimPlayer = victimPlayer,
			killer = attacker,
			assists = assists,
			headshot = info.headshot,
			doublePump = doublePump,
			distance = info.distance,
		}
		local attackerCharacter = attacker and Actors.character(attacker)
		combatEvent:FireAllClients("Elimination", {
			killer = if attacker then Actors.name(attacker) else "",
			killerUserId = if attacker then Actors.id(attacker) else 0,
			killerTeam = teamOf(attackerCharacter),
			victim = nameOf(target),
			victimUserId = if victimPlayer then Actors.id(victimPlayer) else 0,
			victimTeam = teamOf(target),
			headshot = info.headshot,
			doublePump = doublePump,
			dummy = Combatants.isDummy(target),
		})
		DamageService.Eliminated:Fire(elimination)
	end
	return dealt, killed, doublePump
end

-- Kills without an attacker (fell out of the map, reset).
function DamageService.kill(target: Model)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		CharacterService.endProtection(target)
		DamageService.apply(nil, target, humanoid.Health, {
			slot = 0,
			headshot = false,
			distance = 0,
			origin = Vector3.zero,
			pellets = 0,
		})
	end
end

function DamageService.forget(model: Model)
	damageLog[model] = nil
	for _, byTarget in lastHits do
		byTarget[model] = nil
	end
end

function DamageService.forgetParticipant(player: any)
	lastHits[player] = nil
	for _, log in damageLog do
		for i = #log, 1, -1 do
			if log[i].attacker == player then
				table.remove(log, i)
			end
		end
	end
end

function DamageService.start()
	combatEvent = Net.event("CombatEvent")
	Players.PlayerRemoving:Connect(DamageService.forgetParticipant)
	CharacterService.Died:Connect(function(_, character)
		task.delay(1, DamageService.forget, character)
	end)
end

return DamageService
