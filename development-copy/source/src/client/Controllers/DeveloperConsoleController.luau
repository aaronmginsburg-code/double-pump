--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Gui = game:GetService("GuiService")
local Collection = game:GetService("CollectionService")
local Shared = RS.Shared
local Config = require(Shared.DeveloperConsole.Config)
local Runtime = require(Shared.DeveloperConsole.Runtime)
local Trigger = require(Shared.DeveloperConsole.AutoFire)
local Policy = require(Shared.AimAssist.Policy)
local GameConfig = require(Shared.Config.GameConfig)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local WeaponState = require(Shared.Weapons.WeaponState)
local Camera = require(script.Parent.CameraController)
local Input = require(script.Parent.InputController)
local Weapon = require(script.Parent.WeaponController)
local Audio = require(script.Parent.AudioController)
local A = require(script.Parent.AimAssistController)
local C = {
	values = Config.defaults(),
	revision = 0,
	weaponRevision = 0,
	weaponValues = Config.defaults().weapons,
	changed = Instance.new("BindableEvent"),
	diagnostics = false,
	shortcut = Enum.KeyCode.F6,
}
C.auto = Trigger.new()
C.stats = { scanMs = 0, scans = 0, rays = 0, shotInterval = 0, damage = 0, pellets = 0, distance = 0, falloff = 1 }
local baseline = Config.copy(WeaponConfig)
local player = Players.LocalPlayer
local pending: any = nil
local targets: { [Model]: boolean } = {}
local selected: Model? = nil
local nextScan = 0
local lastShot = 0
function C.accept(state: any)
	if
		type(state) ~= "table"
		or state.consoleSchema ~= 2
		or type(state.revision) ~= "number"
		or state.revision < C.revision
	then
		return
	end
	local clean = Config.validate(state.console)
	if not clean then
		return
	end
	C.values = clean
	A.consoleValues = clean.aiming
	C.revision = state.revision
	Runtime.movement(clean.movement, GameConfig)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 and not char:GetAttribute("Frozen") then
		hum.WalkSpeed = if char:GetAttribute("Crouching") then clean.movement.crouch else clean.movement.walk
		hum.JumpHeight = clean.movement.jump
	end
	Camera.tuningSensitivity = {
		Keyboard = clean.aiming.mouseSensitivity,
		Touch = clean.aiming.touchSensitivity,
		Gamepad = clean.aiming.controllerSensitivity,
	}
	if state.weaponRevision >= C.weaponRevision then
		pending = { revision = state.weaponRevision, values = state.weaponValues }
	end
	Audio.applyTuning(clean.audio)
	C.changed:Fire()
end
function C.request(action: string, payload: any): any
	if not A.authorized or not A.request then
		return { ok = false, message = "Developer authorization unavailable" }
	end
	payload = payload or {}
	payload.revision = C.revision
	local ok, response = pcall(function()
		return A.request:InvokeServer(action, payload)
	end)
	if not ok or type(response) ~= "table" then
		return { ok = false, message = "Request failed; working configuration preserved" }
	end
	if response.state then
		A.accept(response.state)
	end
	return response
end
local function active(): boolean
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil
		and hum.Health > 0
		and char:GetAttribute("Dead") ~= true
		and char:GetAttribute("Frozen") ~= true
		and A.focused
		and Input.combatEnabled
		and not Input.tuningOpen
		and Camera.mode == "Combat"
		and not Camera.cursorVisible()
		and not Gui.MenuIsOpen
		and UIS:GetFocusedTextBox() == nil
end
local function status(model: Model): any
	local hum = model:FindFirstChildOfClass("Humanoid")
	return {
		id = model,
		alive = hum ~= nil and hum.Health > 0 and model:GetAttribute("Dead") ~= true,
		frozen = model:GetAttribute("Frozen") == true,
		dummy = model:GetAttribute("Dummy") == true,
		context = model:GetAttribute("CombatContext"),
		matchId = model:GetAttribute("CombatMatchId"),
		team = model:GetAttribute("Team"),
	}
end
local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Exclude
ray.IgnoreWater = true
ray.RespectCanCollide = true
local query = RaycastParams.new()
query.FilterType = Enum.RaycastFilterType.Exclude
query.IgnoreWater = true
local function candidate(model: Model): any
	local char = player.Character
	if not char or not model:IsDescendantOf(workspace) or not Policy.context(status(char), status(model)) then
		return nil
	end
	local p = model:FindFirstChild("UpperTorso")
		or model:FindFirstChild("Torso")
		or model:FindFirstChild("HumanoidRootPart")
	if not p or not p:IsA("BasePart") then
		return nil
	end
	local cf = Camera.aimCFrame()
	local distance = (p.Position - cf.Position).Magnitude
	if distance < 0.1 or distance > math.min(C.values.autoFire.maxDistance, WeaponConfig.Damage.MaxRange) then
		return nil
	end
	local cam = workspace.CurrentCamera
	local point, onScreen = cam:WorldToViewportPoint(p.Position)
	if not onScreen or point.Z <= 0 then
		return nil
	end
	local inside, score =
		Policy.inRadius(point.X, point.Y, cam.ViewportSize.X, cam.ViewportSize.Y, C.values.autoFire.radius)
	if not inside then
		return nil
	end
	ray.FilterDescendantsInstances = { char, cam }
	query.FilterDescendantsInstances = ray.FilterDescendantsInstances
	C.stats.rays += 1
	local hit = workspace:Raycast(cf.Position, p.Position - cf.Position, ray)
	if hit and not hit.Instance:IsDescendantOf(model) then
		return nil
	end
	if C.values.autoFire.lineOfSight then
		C.stats.rays += 1
		hit = workspace:Raycast(cf.Position, p.Position - cf.Position, query)
		if hit and not hit.Instance:IsDescendantOf(model) then
			return nil
		end
	end
	return { id = model, score = score, position = p.Position, distance = distance }
end
function C.start()
	if game.GameId ~= 10772492892 or game.PlaceId ~= 139437092998076 then
		return
	end
	A.consoleAccept = C.accept
	if A.lastState then
		C.accept(A.lastState)
	end
	for _, model in Collection:GetTagged("Combatant") do
		if model:IsA("Model") then
			targets[model] = true
		end
	end
	Collection:GetInstanceAddedSignal("Combatant"):Connect(function(model)
		if model:IsA("Model") then
			targets[model] = true
		end
	end)
	Collection:GetInstanceRemovedSignal("Combatant"):Connect(function(model)
		targets[model] = nil
		if selected == model then
			selected = nil
		end
	end)
	Weapon.Fired:Connect(function()
		local now = os.clock()
		C.stats.shotInterval = if lastShot > 0 then now - lastShot else 0
		lastShot = now
	end)
	Weapon.HitConfirmed:Connect(function(results)
		local damage, pellets = 0, 0
		for _, hit in results do
			damage += hit.damage or 0
			pellets += hit.pellets or 0
			C.stats.distance = hit.distance or 0
			C.stats.falloff = hit.falloff or 1
		end
		C.stats.damage = damage
		C.stats.pellets = pellets
	end)
	Weapon.Rejected:Connect(function(reason)
		C.auto.reason = "Server: " .. tostring(reason)
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		local state = Weapon.state
		if pending and Runtime.safe({ state }, os.clock(), WeaponState) then
			Runtime.weapons(pending.values, WeaponConfig, baseline)
			Runtime.state(state, pending.values.capacity)
			C.weaponRevision = pending.revision
			C.weaponValues = Config.copy(pending.values)
			Weapon.tuningRevision = C.weaponRevision
			pending = nil
			C.changed:Fire()
		end
		elapsed += dt
		if elapsed < 0.05 then
			return
		end
		elapsed = 0
		local now = os.clock()
		local usable = active()
		local device = if UIS:GetLastInputType().Name:find("Gamepad")
			then "Gamepad"
			elseif Camera.touchInputEnabled then "Touch"
			else "Keyboard"
		local config = C.values.autoFire
		local enabled = config.enabled and (device ~= "Keyboard" or A.authorized)
		local item = nil
		if enabled and usable then
			if now >= nextScan then
				nextScan = now + 0.1
				local started = os.clock()
				local list = {}
				for model in targets do
					local c = candidate(model)
					if c then
						table.insert(list, c)
					end
				end
				local best = Policy.choose(list, selected, 0.2)
				selected = if best then best.id else nil
				C.stats.scanMs = math.max(C.stats.scanMs, (os.clock() - started) * 1000)
				C.stats.scans += 1
			end
			item = if selected then candidate(selected) else nil
		else
			selected = nil
		end
		C.autoPosition = if item then item.position else nil
		C.autoTarget = if item then item.id.Name else "none"
		local ready = Weapon.mobileReady()
		local reloading = state.slots[state.equipped].reloading
		if
			Trigger.step(
				C.auto,
				config,
				now,
				if item then item.id else nil,
				device,
				usable and enabled,
				ready,
				reloading
			)
		then
			Weapon.fireMobile()
		end
	end)
end
return C
