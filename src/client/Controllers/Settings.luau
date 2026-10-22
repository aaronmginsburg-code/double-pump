--!strict
-- The local player's settings. Defaults here; the saved copy comes from the server
-- profile (DataService persists it) and is applied when it arrives.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Signal = require(Shared.Util.Signal)
local Net = require(Shared.Net)
local Preferences = require(Shared.Preferences)

local Settings = {}

export type Values = {
	sensitivity: number,
	gamepadSensitivity: number,
	touchSensitivity: number,
	fov: number,
	masterVolume: number,
	musicVolume: number,
	effectsVolume: number,
	crouchToggle: boolean,
	wheelSwitching: boolean,
	showDamageNumbers: boolean,
	reducedEffects: boolean,
	cameraBob: boolean,
	crosshairStyle: string, -- "Cross" | "Dot" | "Circle" | "CrossDot"
	crosshairColor: string, -- key into CROSSHAIR_COLORS
	crosshairSize: number, -- 0.6 .. 1.6
	touchLayout: { [string]: { number } }, -- button -> {xScale, yScale}
	touchLayoutV2: { [string]: { number } },
	controlLayout: string,
	weaponHand: string,
	tutorialDone: boolean,
}

Settings.CROSSHAIR_COLORS = {
	White = Color3.fromRGB(255, 255, 255),
	Green = Color3.fromRGB(80, 255, 120),
	Yellow = Color3.fromRGB(255, 230, 60),
	Cyan = Color3.fromRGB(60, 230, 255),
	Pink = Color3.fromRGB(255, 90, 200),
}

local DEFAULTS: Values = {
	sensitivity = GameConfig.Camera.DefaultSensitivity,
	gamepadSensitivity = 1,
	touchSensitivity = 1,
	fov = GameConfig.Camera.DefaultFov,
	masterVolume = 0.8,
	musicVolume = 0.5,
	effectsVolume = 1,
	crouchToggle = false,
	wheelSwitching = true,
	showDamageNumbers = true,
	reducedEffects = false,
	cameraBob = true,
	crosshairStyle = "CrossDot",
	crosshairColor = "White",
	crosshairSize = 1,
	touchLayout = {},
	touchLayoutV2 = {},
	controlLayout = "right",
	weaponHand = "right",
	tutorialDone = false,
}

Settings.values = table.clone(DEFAULTS)
Settings.Changed = Signal.new() :: Signal.Signal<Values>

-- Copies known keys with the right types from a saved table.
function Settings.apply(saved: any)
	if typeof(saved) ~= "table" then
		return
	end
	for key, default in DEFAULTS do
		local value = saved[key]
		if value ~= nil and typeof(value) == typeof(default) then
			(Settings.values :: any)[key] = value
		end
	end
	local presentation = Preferences.normalize(saved)
	Settings.values.controlLayout = presentation.controlLayout
	Settings.values.weaponHand = presentation.weaponHand
	Settings.Changed:Fire(Settings.values)
end

function Settings.set(key: string, value: any)
	(Settings.values :: any)[key] = value
	Settings.Changed:Fire(Settings.values)
end

local saveQueued = false
-- Saves (debounced) to the server profile.
function Settings.save()
	if saveQueued then
		return
	end
	saveQueued = true
	task.delay(1.5, function()
		saveQueued = false
		Net.event("SettingsAction"):FireServer("Save", Settings.values)
	end)
end

function Settings.reset()
	Settings.values = table.clone(DEFAULTS)
	Settings.Changed:Fire(Settings.values)
	Settings.save()
end

Settings.DEFAULTS = DEFAULTS

return Settings
