--!strict
-- Turns keyboard, mouse, gamepad and touch input into game actions.
-- Every action is a deliberate press: nothing here chains a fire into a swap.
--
--   Fire       LMB / R2 / touch Fire button
--   Equip A/B  1 / 2 (also mouse wheel when enabled in settings)
--   Swap       Q / R1 or L1 / touch Swap button
--   Reload     R / X (gamepad) / touch Reload button
--   Crouch     C or LeftCtrl / B (gamepad) / touch Crouch button
--   Scoreboard Tab / Select (hold)
--   Menu       M / Start

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Signal = require(Shared.Util.Signal)

local InputController = {}

-- "Fire" | "EquipA" | "EquipB" | "Swap" | "Reload" | "Crouch" | "Scoreboard" | "Menu"
export type Action = string

-- (action, pressed) — pressed=false only for hold actions (Fire, Crouch, Scoreboard)
InputController.Action = Signal.new() :: Signal.Signal<Action, boolean>
InputController.LastInputKind = "Keyboard" :: "Keyboard" | "Gamepad" | "Touch"
InputController.InputKindChanged = Signal.new() :: Signal.Signal<string>

-- When false (menus open) combat actions are ignored.
InputController.tuningOpen = false -- private panel owns combat input while open
InputController.combatEnabled = false
InputController.wheelSwitching = true

local KEYS: { [Enum.KeyCode]: Action } = {
	[Enum.KeyCode.One] = "EquipA",
	[Enum.KeyCode.KeypadOne] = "EquipA",
	[Enum.KeyCode.Two] = "EquipB",
	[Enum.KeyCode.KeypadTwo] = "EquipB",
	[Enum.KeyCode.Q] = "Swap",
	[Enum.KeyCode.R] = "Reload",
	[Enum.KeyCode.C] = "Crouch",
	[Enum.KeyCode.LeftControl] = "Crouch",
	[Enum.KeyCode.Tab] = "Scoreboard",
	[Enum.KeyCode.M] = "Menu",
	-- Gamepad
	[Enum.KeyCode.ButtonR2] = "Fire",
	[Enum.KeyCode.ButtonR1] = "Swap",
	[Enum.KeyCode.ButtonL1] = "Swap",
	[Enum.KeyCode.ButtonX] = "Reload",
	[Enum.KeyCode.ButtonB] = "Crouch",
	[Enum.KeyCode.ButtonSelect] = "Scoreboard",
	[Enum.KeyCode.ButtonStart] = "Menu",
	[Enum.KeyCode.DPadLeft] = "EquipA",
	[Enum.KeyCode.DPadRight] = "EquipB",
}

local HOLD: { [Action]: boolean } = { Fire = true, Crouch = true, Scoreboard = true }
local COMBAT: { [Action]: boolean } =
	{ Fire = true, EquipA = true, EquipB = true, Swap = true, Reload = true, Crouch = true }

local held: { [Action]: number } = {}

local function emit(action: Action, pressed: boolean)
	if COMBAT[action] and (not InputController.combatEnabled or InputController.tuningOpen) and pressed then
		return
	end
	if HOLD[action] then
		local count = (held[action] or 0) + (if pressed then 1 else -1)
		count = math.max(count, 0)
		local was = (held[action] or 0) > 0
		held[action] = count
		local now = count > 0
		if now ~= was then
			InputController.Action:Fire(action, now)
		end
	elseif pressed then
		InputController.Action:Fire(action, true)
	end
end

-- For on-screen touch buttons.
function InputController.trigger(action: Action, pressed: boolean)
	emit(action, pressed)
end

function InputController.isHeld(action: Action): boolean
	return (held[action] or 0) > 0
end

-- Release everything (e.g. when a menu opens or the character dies).
function InputController.releaseAll()
	for action, count in held do
		if count > 0 then
			held[action] = 0
			InputController.Action:Fire(action, false)
		end
	end
end

local function setKind(kind: "Keyboard" | "Gamepad" | "Touch")
	if InputController.LastInputKind ~= kind then
		InputController.LastInputKind = kind
		InputController.InputKindChanged:Fire(kind)
	end
end

local function onInputBegan(input: InputObject, processed: boolean)
	local kind = input.UserInputType
	if kind == Enum.UserInputType.Touch then
		setKind("Touch")
		return
	elseif kind.Name:find("Gamepad") then
		setKind("Gamepad")
	elseif kind == Enum.UserInputType.Keyboard or kind.Name:find("Mouse") then
		setKind("Keyboard")
	end
	if processed and input.KeyCode ~= Enum.KeyCode.Tab then
		-- Typing in chat or clicking a button
		return
	end
	if GuiService.MenuIsOpen then
		return
	end
	if kind == Enum.UserInputType.MouseButton1 then
		emit("Fire", true)
		return
	end
	local action = KEYS[input.KeyCode]
	if action then
		emit(action, true)
	end
end

local function onInputEnded(input: InputObject, _processed: boolean)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		emit("Fire", false)
		return
	end
	local action = KEYS[input.KeyCode]
	if action and HOLD[action] then
		emit(action, false)
	end
end

local function onInputChanged(input: InputObject, processed: boolean)
	if input.UserInputType == Enum.UserInputType.MouseWheel and not processed and InputController.wheelSwitching then
		if input.Position.Z > 0 then
			emit("EquipA", true)
		elseif input.Position.Z < 0 then
			emit("EquipB", true)
		end
	elseif input.UserInputType == Enum.UserInputType.MouseMovement then
		setKind("Keyboard")
	end
end

function InputController.start()
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)
	UserInputService.InputChanged:Connect(onInputChanged)
	UserInputService.WindowFocusReleased:Connect(InputController.releaseAll)
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		setKind("Touch")
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		setKind("Gamepad")
	end
end

return InputController
