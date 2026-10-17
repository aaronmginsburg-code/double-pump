-- Local-only sounds (only this player hears them).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)

local Sounds = {}

local elimination: Sound? = nil
if Config.Audio.EliminationSound ~= "" then
	local sound = Instance.new("Sound")
	sound.Name = "Elimination"
	sound.SoundId = Config.Audio.EliminationSound
	sound.Volume = Config.Audio.EliminationVolume
	sound.PlaybackSpeed = Config.Audio.EliminationPitch
	sound.Parent = SoundService
	elimination = sound
end

-- Kill-confirm sound. Does nothing if Config.Audio.EliminationSound is "".
function Sounds.playElimination()
	if elimination then
		SoundService:PlayLocalSound(elimination)
	end
end

return Sounds
