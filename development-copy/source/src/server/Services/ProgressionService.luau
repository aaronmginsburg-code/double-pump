--!strict
-- XP, levels, coins, career stats, shotgun mastery and daily/weekly challenges.
-- Rewards are granted once per finished match from the server's own match stats; the
-- client never reports anything that counts toward progression.
--
-- Anti-idle: each second a player in a live match counts as active if they moved,
-- turned or fired. Completion and win rewards scale with that active time (Levels).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local RateLimiter = require(Shared.Util.RateLimiter)
local Levels = require(Shared.Progression.Levels)
local Challenges = require(Shared.Progression.Challenges)
local Cosmetics = require(Shared.Progression.Cosmetics)
local Profile = require(Shared.Progression.Profile)
local Products = require(Shared.Config.Products)

local Services = script.Parent
local DataService = require(Services.DataService)
local MatchService = require(Services.MatchService)
local CombatService = require(Services.CombatService)
local TeamService = require(Services.TeamService)

local ProgressionService = {}

-- Fired after rewards are applied (LeaderboardService listens).
ProgressionService.ProfileChanged = Signal.new() :: Signal.Signal<Player, Profile.Data>

local profileEvent: RemoteEvent
local settingsLimiter = RateLimiter.new(4, 0.5)

-- Activity tracking for the anti-idle rule
type Activity = { lastPos: Vector3?, lastPitch: number?, lastShot: number, active: number }
local activity: { [Player]: Activity } = {}
local matchStartedAt = os.clock()

local function challengeView(kind: "daily" | "weekly", set: Challenges.Set?, now: number): any
	local current = Challenges.current(kind, set, now)
	local entries = {}
	for _, entry in current.entries do
		local def = Challenges.find(entry.id)
		if def then
			table.insert(entries, {
				id = entry.id,
				text = def.text,
				progress = entry.progress,
				goal = def.goal,
				done = entry.done,
				xp = def.xp,
				coins = def.coins,
			})
		end
	end
	return { entries = entries, secondsLeft = Challenges.secondsLeft(kind, now) }
end

-- What the client sees of its own profile.
function ProgressionService.snapshot(data: Profile.Data): any
	local now = os.time()
	local info = Levels.fromXp(data.xp)
	local packs = {}
	for _, pack in Products.CoinPacks do
		table.insert(
			packs,
			{ key = pack.key, name = pack.name, coins = pack.coins, available = Products.available(pack) }
		)
	end
	return {
		xp = data.xp,
		level = info.level,
		coins = data.coins,
		stats = data.stats,
		masteryKills = data.masteryKills,
		owned = data.owned,
		equipped = data.equipped,
		daily = challengeView("daily", data.daily, now),
		weekly = challengeView("weekly", data.weekly, now),
		settings = data.settings,
		tutorialDone = data.tutorialDone,
		packs = packs,
	}
end

function ProgressionService.push(player: Player)
	local data = DataService.get(player)
	if data then
		profileEvent:FireClient(player, "Profile", ProgressionService.snapshot(data))
	end
end

-- Grants every level/mastery skin the player now qualifies for. Returns new unlocks.
local function grantEarned(data: Profile.Data): { Cosmetics.Skin }
	local unlocked = {}
	local level = Levels.fromXp(data.xp).level
	local tier = Levels.mastery(data.masteryKills).tier
	for _, skin in Cosmetics.Skins do
		if not data.owned[skin.id] and Cosmetics.earned(skin, level, tier) then
			data.owned[skin.id] = true
			table.insert(unlocked, skin)
		end
	end
	return unlocked
end

local function rollChallenges(data: Profile.Data)
	local now = os.time()
	data.daily = Challenges.current("daily", data.daily, now)
	data.weekly = Challenges.current("weekly", data.weekly, now)
end

local function onMatchEnded(result: any)
	local length = math.max(1, os.clock() - matchStartedAt)
	for player, info in result.participants do
		local data = DataService.get(player)
		if not data or not player.Parent then
			continue
		end
		local s = info.stats
		local won = result.winner ~= nil and info.team == result.winner
		local act = activity[player]
		local summary: Levels.MatchSummary = {
			kills = s.kills,
			assists = s.assists,
			headshotKills = s.headshots,
			doublePumps = s.doublePumps,
			won = won,
			timePlayed = math.min(info.timePlayed, length),
			matchLength = length,
			activeTime = if act then act.active else 0,
		}
		local reward = Levels.matchReward(summary)
		local levelBefore = Levels.fromXp(data.xp).level
		local masteryBefore = Levels.mastery(data.masteryKills).tier
		local completedChallenges = {}

		DataService.update(player, function(d)
			local st = d.stats
			st.kills += s.kills
			st.deaths += s.deaths
			st.assists += s.assists
			st.headshots += s.headshots
			st.doublePumps += s.doublePumps
			st.damage += math.round(s.damage)
			st.pelletsFired += s.pelletsFired
			st.pelletsHit += s.pelletsHit
			st.timePlayed += summary.timePlayed
			if not reward.idle then
				st.matches += 1
				if won then
					st.wins += 1
				elseif result.winner ~= nil then
					st.losses += 1
				end
			end
			d.masteryKills += s.kills
			d.xp += reward.xp
			d.coins += reward.coins

			rollChallenges(d)
			local delta = {
				kills = s.kills,
				headshots = s.headshots,
				doublePumps = s.doublePumps,
				assists = s.assists,
				damage = math.round(s.damage),
				wins = if won and not reward.idle then 1 else 0,
				matches = if reward.idle then 0 else 1,
			}
			for _, set in { d.daily :: Challenges.Set, d.weekly :: Challenges.Set } do
				for _, def in Challenges.progress(set, delta) do
					d.xp += def.xp
					d.coins += def.coins
					table.insert(completedChallenges, { text = def.text, xp = def.xp, coins = def.coins })
				end
			end
		end)

		local unlocked = grantEarned(data)
		local totalXp = reward.xp
		local totalCoins = reward.coins
		for _, ch in completedChallenges do
			totalXp += ch.xp
			totalCoins += ch.coins
		end
		profileEvent:FireClient(player, "Reward", {
			xp = totalXp,
			coins = totalCoins,
			breakdown = reward.breakdown,
			challenges = completedChallenges,
			idle = reward.idle,
			levelBefore = levelBefore,
			unlocks = #unlocked,
			masteryBefore = masteryBefore,
			masteryAfter = Levels.mastery(data.masteryKills).tier,
			levelAfter = Levels.fromXp(data.xp).level,
			totalXp = data.xp,
		})
		for _, skin in unlocked do
			profileEvent:FireClient(player, "Unlock", { id = skin.id, name = skin.name })
		end
		ProgressionService.push(player)
		ProgressionService.ProfileChanged:Fire(player, data)
	end
end

-- Settings come from the client, so only known keys with sane values are kept.
local SETTING_TYPES: { [string]: string } = {
	sensitivity = "number",
	gamepadSensitivity = "number",
	touchSensitivity = "number",
	fov = "number",
	masterVolume = "number",
	musicVolume = "number",
	effectsVolume = "number",
	crouchToggle = "boolean",
	wheelSwitching = "boolean",
	showDamageNumbers = "boolean",
	reducedEffects = "boolean",
	cameraBob = "boolean",
	crosshairStyle = "string",
	crosshairColor = "string",
	crosshairSize = "number",
	touchLayout = "table",
	touchLayoutV2 = "table",
	controlLayout = "string",
	weaponHand = "string",
	tutorialDone = "boolean",
}

local function cleanSettings(raw: any): { [string]: any }?
	if typeof(raw) ~= "table" then
		return nil
	end
	local out = {}
	for key, kind in SETTING_TYPES do
		local v = raw[key]
		if typeof(v) == kind then
			if kind == "number" then
				if v == v and math.abs(v) < 1000 then
					out[key] = v
				end
			elseif kind == "string" then
				if
					#v <= 24
					and (
						(key ~= "controlLayout" and key ~= "weaponHand")
						or v == "right"
						or v == "left"
						or (key == "controlLayout" and (v == "Right-Handed" or v == "Left-Handed"))
					)
				then
					out[key] = v
				end
			elseif kind == "table" then
				-- touchLayout: { [button] = { x, y [, scale] } } with numbers in 0..1.5
				local layout = {}
				local count = 0
				for name, pos in v do
					count += 1
					if count > 16 then
						break
					end
					if typeof(name) == "string" and #name <= 16 and typeof(pos) == "table" then
						local x, y, sc = pos[1], pos[2], pos[3]
						if typeof(x) == "number" and typeof(y) == "number" and x == x and y == y then
							layout[name] = {
								math.clamp(x, 0, 1),
								math.clamp(y, 0, 1),
								if typeof(sc) == "number" and sc == sc then math.clamp(sc, 0.5, 1.6) else 1,
							}
						end
					end
				end
				out[key] = layout
			else
				out[key] = v
			end
		end
	end
	local presentation = require(Shared.Preferences).normalize(out)
	out.controlLayout = presentation.controlLayout
	out.weaponHand = presentation.weaponHand
	return out
end

local function onSettingsAction(player: Player, action: any, value: any)
	if not settingsLimiter:allow(player, os.clock()) then
		return
	end
	if action == "Save" then
		local clean = cleanSettings(value)
		if clean then
			DataService.update(player, function(d)
				d.settings = clean
			end)
		end
	elseif action == "TutorialDone" then
		DataService.update(player, function(d)
			d.tutorialDone = true
		end)
	end
end

local function trackActivity(dt: number)
	if not MatchService.inCombat() then
		return
	end
	for _, player in Players:GetPlayers() do
		if not TeamService.teamOf(player) then
			continue
		end
		local act = activity[player]
		if not act then
			act = { lastShot = -math.huge, active = 0 }
			activity[player] = act
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local pitch = character and character:GetAttribute("AimPitch")
		local moved = false
		if root then
			moved = act.lastPos ~= nil and (root.Position - (act.lastPos :: Vector3)).Magnitude > 1.5
			act.lastPos = root.Position
		end
		local turned = typeof(pitch) == "number"
			and act.lastPitch ~= nil
			and math.abs(pitch - (act.lastPitch :: number)) > 0.01
		if typeof(pitch) == "number" then
			act.lastPitch = pitch
		end
		local fired = os.clock() - act.lastShot < 2
		if moved or turned or fired then
			act.active += dt
		end
	end
end

function ProgressionService.start()
	profileEvent = Net.event("ProfileEvent")

	DataService.Loaded:Connect(function(player, data)
		rollChallenges(data)
		local unlocked = grantEarned(data)
		ProgressionService.push(player)
		for _, skin in unlocked do
			profileEvent:FireClient(player, "Unlock", { id = skin.id, name = skin.name })
		end
	end)
	Net.func("GetProfile").OnServerInvoke = function(player: Player)
		local data = DataService.get(player)
		return if data then ProgressionService.snapshot(data) else nil
	end
	Net.event("SettingsAction").OnServerEvent:Connect(onSettingsAction)

	MatchService.MatchStarted:Connect(function()
		matchStartedAt = os.clock()
		table.clear(activity)
	end)
	MatchService.MatchEnded:Connect(onMatchEnded)
	CombatService.ShotFired:Connect(function(player)
		local act = activity[player]
		if act then
			act.lastShot = os.clock()
		end
	end)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 1 then
			trackActivity(accumulator)
			accumulator = 0
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		activity[player] = nil
		settingsLimiter:forget(player)
	end)
end

return ProgressionService
