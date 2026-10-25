--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local UIS = game:GetService("UserInputService")
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.AimAssist.Config)
local Policy = require(Shared.AimAssist.Policy)
local Camera = require(script.Parent.CameraController)
local Input = require(script.Parent.InputController)
local A = {
	values = Config.defaults(),
	revision = 0,
	authorized = false,
	focused = true,
	diagnostics = false,
	changed = Instance.new("BindableEvent"),
}
local player = Players.LocalPlayer
local targets: { [Instance]: boolean } = {}
local selected: Model? = nil
local scanTime = 0
local scale = 1
local identity: Model? = nil
local spawnRevision: any = nil
local candidates = {}
local solid = RaycastParams.new()
local query = RaycastParams.new()
solid.FilterType = Enum.RaycastFilterType.Exclude
solid.RespectCanCollide = true
solid.IgnoreWater = true
query.FilterType = Enum.RaycastFilterType.Exclude
query.IgnoreWater = true
A.stats =
	{ scans = 0, rays = 0, maxScanMs = 0, target = "none", distance = 0, slowdown = 1, rotation = false, weight = 0 }
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
local function torso(model: Model): BasePart?
	local part = model:FindFirstChild("UpperTorso")
		or model:FindFirstChild("Torso")
		or model:FindFirstChild("HumanoidRootPart")
	return if part and part:IsA("BasePart") then part else nil
end
local function visible(model: Model, from: Vector3, to: Vector3): boolean
	local delta = to - from
	A.stats.rays += 1
	local hit = workspace:Raycast(from, delta, solid)
	if hit and not hit.Instance:IsDescendantOf(model) then
		return false
	end
	if A.values.lineOfSight then
		A.stats.rays += 1
		hit = workspace:Raycast(from, delta, query)
		if hit and not hit.Instance:IsDescendantOf(model) then
			return false
		end
	end
	return true
end
local function candidate(model: Model, own: any, cf: CFrame): any
	if not model:IsDescendantOf(workspace) or not Policy.context(own, status(model)) then
		return nil
	end
	local part = torso(model)
	if not part then
		return nil
	end
	local distance = (part.Position - cf.Position).Magnitude
	if distance < 0.1 or distance > A.values.maxDistance then
		return nil
	end
	local camera = workspace.CurrentCamera
	local point, onScreen = camera:WorldToViewportPoint(part.Position)
	if not onScreen or point.Z <= 0 then
		return nil
	end
	local inside, score =
		Policy.inRadius(point.X, point.Y, camera.ViewportSize.X, camera.ViewportSize.Y, A.values.radius)
	if not inside or not visible(model, cf.Position, part.Position) then
		return nil
	end
	return { id = model, score = score, distance = distance, position = part.Position }
end
function A.clear()
	table.clear(candidates)
	selected = nil
	A.targetPosition = nil
	scale = 1
	scanTime = 0
	A.stats.target = "none"
	A.stats.distance = 0
	A.stats.slowdown = 1
	A.stats.rotation = false
	A.stats.weight = 0
end
function A.accept(state: any)
	if
		type(state) ~= "table"
		or state.schema ~= Config.Schema
		or type(state.revision) ~= "number"
		or state.revision < A.revision
	then
		return
	end
	local clean = Config.validate(state.values)
	if clean then
		A.lastState = state
		if A.consoleAccept then
			A.consoleAccept(state)
		end
		A.values = clean
		A.revision = state.revision
		A.clear()
		A.changed:Fire()
	end
end
function A.step(dt: number, cf: CFrame, device: string, aiming: boolean): (number, number, number)
	local options = A.consoleValues
		or {
			touchEligible = true,
			controllerEligible = true,
			mouseEligible = false,
			touchStrength = 1,
			controllerStrength = 1,
			mouseStrength = 1,
		}
	local prefix = if device == "Touch" then "touch" elseif device == "Gamepad" then "controller" else "mouse"
	local eligible = options[prefix .. "Eligible"] and (prefix ~= "mouse" or A.authorized)
	local char = player.Character
	local revision = char and char:GetAttribute("SpawnRevision")
	if char ~= identity or revision ~= spawnRevision then
		identity = char
		spawnRevision = revision
		A.clear()
	end
	if
		not char
		or not A.focused
		or not A.values.enabled
		or not Input.combatEnabled
		or Input.tuningOpen
		or Camera.mode ~= "Combat"
		or Camera.cursorVisible()
		or GuiService.MenuIsOpen
		or UIS:GetFocusedTextBox()
		or not eligible
	then
		A.clear()
		return 1, 0, 0
	end
	local own = status(char)
	if not own.alive or own.frozen or (own.context ~= "Lobby" and own.context ~= "Match") then
		A.clear()
		return 1, 0, 0
	end
	-- Exclude the entire local camera/viewmodel and own character; never exclude opponents/walls.
	if solid.FilterDescendantsInstances[1] ~= char then
		local excluded = { char, workspace.CurrentCamera }
		solid.FilterDescendantsInstances = excluded
		query.FilterDescendantsInstances = excluded
	end
	local now = os.clock()
	if now >= scanTime then
		local started = os.clock()
		scanTime = now + 0.1
		table.clear(candidates)
		for model in targets do
			if model:IsA("Model") then
				local item = candidate(model, own, cf)
				if item then
					table.insert(candidates, item)
				end
			end
		end
		local best = Policy.choose(candidates, selected, A.values.switchThreshold)
		selected = if best then best.id else nil
		A.stats.scans += 1
		A.stats.maxScanMs = math.max(A.stats.maxScanMs, (os.clock() - started) * 1000)
	end
	-- Current target is revalidated each frame: never keep wall/death/context data for100ms.
	local item = if selected then candidate(selected, own, cf) else nil
	if not item then
		selected = nil
	end
	local yawError, pitchError = 0, 0
	if item then
		local look = (item.position - cf.Position).Unit
		local desiredYaw = math.atan2(-look.X, -look.Z)
		yawError = math.atan2(math.sin(desiredYaw - Camera.yaw), math.cos(desiredYaw - Camera.yaw))
		pitchError = math.asin(math.clamp(look.Y, -1, 1)) - Camera.pitch
	end
	local y, p
	local effective = table.clone(A.values)
	effective.slowdownStrength *= options[prefix .. "Strength"]
	effective.rotationStrength *= options[prefix .. "Strength"]
	scale, y, p = Policy.response(
		effective,
		scale,
		if item then item.score else nil,
		dt,
		if device == "Keyboard" then "Gamepad" else device,
		aiming,
		yawError,
		pitchError
	)
	A.stats.target = if item then item.id.Name else "none"
	A.stats.distance = if item then item.distance else 0
	A.stats.slowdown = scale
	A.stats.rotation = y ~= 0 or p ~= 0
	A.stats.weight = if item then (1 - item.score) ^ 2 else 0
	A.targetPosition = if item then item.position else nil
	return scale, y, p
end
function A.start()
	if game.GameId ~= 10772492892 or game.PlaceId ~= 139437092998076 then
		return
	end
	for _, model in CollectionService:GetTagged("Combatant") do
		targets[model] = true
	end
	CollectionService:GetInstanceAddedSignal("Combatant"):Connect(function(model)
		targets[model] = true
	end)
	CollectionService:GetInstanceRemovedSignal("Combatant"):Connect(function(model)
		targets[model] = nil
		if selected == model then
			A.clear()
		end
	end)
	Camera.aimAssist = A.step
	UIS.WindowFocusReleased:Connect(function()
		A.focused = false
		A.clear()
	end)
	UIS.WindowFocused:Connect(function()
		A.focused = true
		A.clear()
	end)
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild("DeveloperTuning", 15)
		if not folder then
			warn("[AimAssist] Tuning unavailable; assistance disabled")
			A.values.enabled = false
			return
		end
		A.request = folder:WaitForChild("Request")
		local stateRemote = folder:WaitForChild("State") :: RemoteEvent
		stateRemote.OnClientEvent:Connect(A.accept)
		local ok, response = pcall(function()
			return A.request:InvokeServer("Get", {})
		end)
		if ok and response.ok then
			A.authorized = response.authorized == true
			A.accept(response.state)
			A.changed:Fire()
		end
	end)
end
return A
