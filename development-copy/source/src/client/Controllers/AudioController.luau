--!strict
-- Plays every sound: 2D (UI, your own gun), 3D at a position or on a part (other
-- players' guns, impacts), music and map ambience. Volumes follow Settings through
-- SoundGroups. Sound ids come from Config/AssetIds (the original sounds in
-- assets/audio, once uploaded). Missing ids fall back to a few sounds that ship with
-- the Roblox client, or stay silent, and are listed once in the output.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local AssetIds = require(Shared.Config.AssetIds)
local Settings = require(script.Parent.Settings)
local Net = require(Shared.Net)
local LobbyCues = require(Shared.Audio.LobbyCues)
local ActionCues = require(Shared.Audio.ActionCues)
local lastLobbySerial = 0

local AudioController = {}

type Group = "Effects" | "UI" | "Music"

-- Built into the Roblox client, used only until the real sounds are uploaded.
local FALLBACKS: { [string]: string } = {
	HitBody = "rbxasset://sounds/electronicpingshort.wav",
	HitHead = "rbxasset://sounds/electronicpingshort.wav",
	UIClick = "rbxasset://sounds/clickfast.wav",
	Swap = "rbxasset://sounds/swoosh.wav",
	Equip = "rbxasset://sounds/swoosh.wav",
	Death = "rbxasset://sounds/uuhhh.mp3",
}

-- Per-sound mix (volume, and how far 3D sounds carry)
local MIX: { [string]: { volume: number, rolloff: number? } } = {
	StepConcrete = { volume = 0.13 },
	StepMetal = { volume = 0.13 },
	StepSand = { volume = 0.13 },
	StepWood = { volume = 0.13 },
	Landing = { volume = 0.65 },

	ReloadEnd = { volume = 0.3 },
	ImpactHard = { volume = 0.25, rolloff = 70 },
	ImpactMetal = { volume = 0.25, rolloff = 70 },
	ImpactWood = { volume = 0.25, rolloff = 70 },
	Overtime = { volume = 0.5 },
	TimeWarning = { volume = 0.4 },
	Error = { volume = 0.3 },
	Confirm = { volume = 0.3 },
	Unlock = { volume = 0.6 },
	Assist = { volume = 0.35 },
	Fire = { volume = 0.9, rolloff = 160 },
	Pump = { volume = 0.55, rolloff = 50 },
	PumpBack = { volume = 0.38, rolloff = 50 },
	PumpForward = { volume = 0.42, rolloff = 50 },
	Equip = { volume = 0.5 },
	Swap = { volume = 0.55, rolloff = 40 },
	ShellInsert = { volume = 0.5 },
	ReloadStart = { volume = 0.4 },
	EmptyClick = { volume = 0.6 },
	ShellBounce = { volume = 0.25, rolloff = 25 },
	HitBody = { volume = 0.55 },
	HitHead = { volume = 0.6 },
	Elimination = { volume = 0.75 },
	DoublePumpElim = { volume = 0.85 },
	DamageTaken = { volume = 0.6 },
	Death = { volume = 0.6 },
	Spawn = { volume = 0.45 },
	CountdownTick = { volume = 0.6 },
	MatchStart = { volume = 0.7 },
	MatchEnd = { volume = 0.7 },
	Victory = { volume = 0.75 },
	Defeat = { volume = 0.7 },
	UIClick = { volume = 0.45 },
	UIHover = { volume = 0.25 },
	Vote = { volume = 0.5 },
	Reward = { volume = 0.55 },
	LevelUp = { volume = 0.7 },
	MasteryMilestone = { volume = 0.7 },
	QueueJoin = { volume = 0.4 },
	QueueLeave = { volume = 0.35 },
	QueueCountdown = { volume = 0.35 },
	QueueCancel = { volume = 0.4 },
	Admitted = { volume = 0.5 },
	ReturnToRange = { volume = 0.4 },
}

local groups: { [string]: SoundGroup } = {}
local master: SoundGroup
local missing: { string } = {}
local warned = false
local musicSound: Sound? = nil
local ambientSound: Sound? = nil
local ambientName: string? = nil
local ambienceWorker = false

local function idFor(name: string): string?
	local id = (AssetIds.Sounds :: any)[name]
	if typeof(id) == "string" and id ~= "" then
		if id:match("^%d+$") then
			return "rbxassetid://" .. id
		end
		return id
	end
	if not table.find(missing, name) then
		table.insert(missing, name)
	end
	return FALLBACKS[name]
end

local function warnMissing()
	if warned or #missing == 0 then
		return
	end
	warned = true
	task.delay(5, function()
		warn(
			`[Double Pump] {#missing} sound(s) not uploaded yet, using fallbacks or silence: {table.concat(
				missing,
				", "
			)}.` .. " Upload assets/audio (docs/ASSET_PIPELINE.md)."
		)
	end)
end

local function makeSound(name: string, group: Group): Sound?
	local id = idFor(name)
	warnMissing()
	if not id then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	local mix = MIX[name]
	sound.Volume = if mix then mix.volume else 0.6
	sound.SoundGroup = groups[group]
	if mix and mix.rolloff then
		sound.RollOffMaxDistance = mix.rolloff
		sound.RollOffMinDistance = 8
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
	end
	return sound
end

export type PlayOptions = {
	parent: any,
	position: Vector3?,
	pitch: number?,
	volume: number?,
	group: Group?,
}

function AudioController.configured(name: string): boolean
	local id = (AssetIds.Sounds :: any)[name]
	return typeof(id) == "string" and id ~= ""
end

function AudioController.stop(sound: Sound?)
	if not sound or not sound.Parent then
		return
	end
	local fade = TweenService:Create(sound, TweenInfo.new(0.015), { Volume = 0 })
	fade.Completed:Once(function()
		if sound.Parent then
			sound:Stop()
			sound:Destroy()
		end
	end)
	fade:Play()
	Debris:AddItem(sound, 0.1)
end

function AudioController.play(name: string, options: PlayOptions?): Sound?
	local o = (options or {}) :: PlayOptions
	local sound = makeSound(name, o.group or (if name:sub(1, 2) == "UI" then "UI" else "Effects"))
	if not sound then
		return
	end
	if o.pitch then
		sound.PlaybackSpeed = o.pitch
	end
	if o.volume then
		sound.Volume *= o.volume
	end
	local holder: Instance
	if o.position then
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = o.position
		attachment.Parent = workspace.Terrain
		holder = attachment
		Debris:AddItem(attachment, 4)
	else
		holder = o.parent or SoundService
	end
	sound.Parent = holder
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	Debris:AddItem(sound, 6)
	return sound
end

local function loop(name: string, group: Group, volume: number): Sound?
	local sound = makeSound(name, group)
	if not sound then
		return nil
	end
	sound.Looped = true
	sound.Volume = volume
	sound.Parent = SoundService
	sound:Play()
	return sound
end

function AudioController.setMusic(name: string?)
	if musicSound and (not name or musicSound.Name ~= name) then
		musicSound:Destroy()
		musicSound = nil
	end
	if name and not musicSound then
		musicSound = loop(name, "Music", 0.5)
	end
end

function AudioController.setAmbience(name: string?)
	-- Serialize fades: destroy the outgoing bed before creating the current target.
	-- Coalescing rapid mode/map refreshes prevents overlapping or stale loops.
	local target = if name and AudioController.configured(name) then name else nil
	if target == ambientName then
		return
	end
	ambientName = target
	if ambienceWorker then
		return
	end
	ambienceWorker = true
	task.spawn(function()
		while (if ambientSound then ambientSound.Name else nil) ~= ambientName do
			if ambientSound then
				local previous = ambientSound
				TweenService:Create(previous, TweenInfo.new(0.25), { Volume = 0 }):Play()
				task.wait(0.25)
				previous:Destroy()
				ambientSound = nil
			end
			if ambientName then
				ambientSound = loop(ambientName, "Effects", 0)
				if ambientSound then
					TweenService:Create(ambientSound, TweenInfo.new(0.35), { Volume = 0.025 }):Play()
				end
			end
		end
		ambienceWorker = false
	end)
end

local function applyVolumes()
	local v = Settings.values
	master.Volume = v.masterVolume
	groups.Music.Volume = v.musicVolume
	groups.Effects.Volume = v.effectsVolume
	groups.UI.Volume = v.effectsVolume
end

function AudioController.start()
	master = Instance.new("SoundGroup")
	master.Name = "Master"
	master.Parent = SoundService
	for _, name in { "Effects", "UI", "Music" } do
		local group = Instance.new("SoundGroup")
		group.Name = name
		group.Parent = master
		groups[name] = group
	end
	applyVolumes()
	Settings.Changed:Connect(applyVolumes)
	Net.event("MatchEvent").OnClientEvent:Connect(function(kind, payload)
		if kind ~= "LobbyAudio" then
			return
		end
		local serial, cue = LobbyCues.accept(lastLobbySerial, payload)
		lastLobbySerial = serial
		if cue then
			AudioController.play(cue)
		end
	end)
	-- Only confirmed responses create UI feedback. Initial snapshots stay silent.
	local lastError, lastConfirm, previousSkin = -math.huge, -math.huge, nil
	local function confirm()
		local now = os.clock()
		if now - lastConfirm < 0.4 then
			return
		end
		lastConfirm = now
		AudioController.play("Confirm", { group = "UI" })
	end
	Net.event("Notify").OnClientEvent:Connect(function(_, kind)
		if kind == "error" then
			local now = os.clock()
			if now - lastError < 0.4 then
				return
			end
			lastError = now
			AudioController.play("Error", { group = "UI" })
		elseif kind == "good" then
			confirm()
		end
	end)
	Net.event("ProfileEvent").OnClientEvent:Connect(function(kind, snapshot)
		if kind ~= "Profile" then
			return
		end
		local changed
		previousSkin, changed = ActionCues.skinChanged(previousSkin, snapshot)
		if changed then
			confirm()
		end
	end)
	-- Readiness diagnostics never block player spawning or input.
	task.spawn(function()
		local preload = {}
		for _, name in
			{
				"StepConcrete",
				"StepMetal",
				"StepSand",
				"StepWood",
				"Landing",
				"ReloadEnd",
				"ImpactHard",
				"ImpactMetal",
				"ImpactWood",
				"Overtime",
				"TimeWarning",
				"Error",
				"Confirm",
				"Unlock",
				"Assist",
				"RangeAir",
				"AmbWarehouse",
				"AmbDustTown",
				"AmbRooftops",
				"Fire",
				"PumpBack",
				"PumpForward",
				"Swap",
				"EmptyClick",
				"HitBody",
				"HitHead",
				"DamageTaken",
				"Equip",
				"ReloadStart",
				"ShellInsert",
				"ShellBounce",
				"Elimination",
				"DoublePumpElim",
				"Death",
				"Spawn",
				"CountdownTick",
				"MatchStart",
				"MatchEnd",
				"Victory",
				"Defeat",
				"UIClick",
				"Reward",
				"QueueJoin",
				"QueueLeave",
				"QueueCountdown",
				"QueueCancel",
				"Admitted",
				"ReturnToRange",
				"LevelUp",
				"MasteryMilestone",
				"Vote",
			}
		do
			local id = idFor(name)
			if id then
				local sound = Instance.new("Sound")
				sound.SoundId = id
				table.insert(preload, sound)
			end
		end
		local loaded = 0
		local ok, message = pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(preload, function(id, status)
				if status == Enum.AssetFetchStatus.Success then
					loaded += 1
				else
					warn(`[Double Pump Audio] unavailable {id}: {status.Name}`)
				end
			end)
		end)
		for _, sound in preload do
			sound:Destroy()
		end
		if ok then
			print(`[Double Pump Audio] approved cues ready: {loaded}/{#preload}`)
		else
			warn(`[Double Pump Audio] preload failed: {message}`)
		end
	end)
end

return AudioController
