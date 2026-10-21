--!strict
-- Plays every sound: 2D (UI, your own gun), 3D at a position or on a part (other
-- players' guns, impacts), music and map ambience. Volumes follow Settings through
-- SoundGroups. Sound ids come from Config/AssetIds (the original sounds in
-- assets/audio, once uploaded). Missing ids fall back to a few sounds that ship with
-- the Roblox client, or stay silent, and are listed once in the output.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage.Shared
local AssetIds = require(Shared.Config.AssetIds)
local Settings = require(script.Parent.Settings)

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
	Fire = { volume = 0.9, rolloff = 160 },
	Pump = { volume = 0.55, rolloff = 50 },
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
}

local groups: { [string]: SoundGroup } = {}
local master: SoundGroup
local missing: { string } = {}
local warned = false
local musicSound: Sound? = nil
local ambientSound: Sound? = nil

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
			`[Double Pump] {#missing} sound(s) not uploaded yet, using fallbacks or silence: {table.concat(missing, ", ")}.`
				.. " Upload assets/audio (docs/ASSET_PIPELINE.md)."
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

function AudioController.play(name: string, options: PlayOptions?)
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
	if ambientSound and (not name or ambientSound.Name ~= name) then
		ambientSound:Destroy()
		ambientSound = nil
	end
	if name and not ambientSound then
		ambientSound = loop(name, "Effects", 0.35)
	end
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
end

return AudioController
