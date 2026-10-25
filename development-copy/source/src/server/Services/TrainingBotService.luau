--!strict
-- Development-only NPC participants. No client remote can spawn, steer or fire these bots.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Storage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local S = script.Parent
local Shared = ReplicatedStorage.Shared
local Access = require(S.DeveloperAccess)
local Actors = require(S.Participants)
local Character = require(S.CharacterService)
local Context = require(S.CombatContext)
local Combat = require(S.CombatService)
local Damage = require(S.DamageService)
local Match = require(S.MatchService)
local Maps = require(S.MapService)
local Teams = require(S.TeamService)
local Navigation = require(S.BotNavigation)
local Config = require(Shared.Training.Beginner)
local Policy = require(Shared.Training.Policy)
local Game = require(Shared.Config.GameConfig)
local Weapon = require(Shared.Weapons.WeaponState)
local Net = require(Shared.Net)
local Service = { metrics = { steps = 0, maxStepMs = 0 } }
local owner: Player? = nil
local epoch = 0
local building = false
local connections = {}
local templates: Folder
local folder: Folder
local random = Random.new()
local function live(model: Model?): boolean
	local h = model and model:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0 and model:GetAttribute("Dead") ~= true
end
local function zone(): CFrame
	return CFrame.new(Maps.Registry.Range.origin + Game.LobbyQueue.Offset)
end
local function inside(player: Player): boolean
	local m = player.Character
	local r = m and m:FindFirstChild("HumanoidRootPart")
	return Match.modeOf(player) == "Practice"
		and live(m)
		and r ~= nil
		and require(Shared.Match.LobbyQueue).contains(zone(), Game.LobbyQueue.Size, r.Position)
end
local function state(bot: any, value: string)
	if bot.state ~= value then
		bot.state = value
		if bot.model then
			bot.model:SetAttribute("BotState", value)
		end
	end
end
local function home(bot: any): Vector3
	return Maps.Registry.Range.origin + Vector3.new(-49, 0, if bot.index == 1 then -9 else 9)
end
local function bodyLabel(bot: any, model: Model)
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "BotLabel"
	gui.Size = UDim2.fromOffset(150, 38)
	gui.StudsOffset = Vector3.new(0, 2.2, 0)
	gui.MaxDistance = 90
	gui.AlwaysOnTop = false
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = bot.name .. " · BOT"
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextColor3 = Color3.fromRGB(220, 235, 242)
	label.TextStrokeTransparency = 0.45
	label.Parent = gui
	bot.label = label
end
local function prepared(bot: any, model: Model)
	if not Actors.isBot(bot) then
		return
	end
	Navigation.clear(bot)
	bot.target = nil
	bot.lastSeen = nil
	bot.nextFire = 0
	bot.nextPerception = 0
	bot.nextDecision = 0
	bot.reloadUntil = nil
	bot.aim = Vector3.new(0, 0, -1)
	bot.gait = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and (d.Name:find("Hip") or d.Name:find("Knee") or d.Name:find("Shoulder")) then
			bot.gait[d] = d.C0
		end
	end
	bodyLabel(bot, model)
	state(bot, "Spawning")
end
local function cleanup()
	epoch += 1
	building = false
	if owner then
		Context.stopTraining(owner)
	end
	for _, bot in Actors.list() do
		state(bot, "Despawning")
		Navigation.clear(bot)
		Match.removeBot(bot)
		Damage.forgetParticipant(bot)
		if bot.model then
			Damage.forget(bot.model)
			bot.model:Destroy()
		end
		if bot.template then
			bot.template:Destroy()
		end
		Actors.remove(bot)
	end
	owner = nil
end
local function notify(message: string)
	if owner and owner.Parent == Players then
		Net.event("Notify"):FireClient(owner, message)
	end
end
local function create(newOwner: Player)
	if owner or building then
		return
	end
	building = true
	epoch += 1
	local token = epoch
	owner = newOwner
	task.spawn(function()
		for i = 1, Config.Count do
			if token ~= epoch or newOwner.Parent ~= Players then
				return
			end
			local description = Instance.new("HumanoidDescription")
			description.HeadColor = Color3.fromRGB(221, 177, 139)
			description.LeftArmColor = description.HeadColor
			description.RightArmColor = description.HeadColor
			description.TorsoColor = if i == 1 then Color3.fromRGB(48, 117, 147) else Color3.fromRGB(170, 100, 45)
			description.LeftLegColor = Color3.fromRGB(36, 43, 54)
			description.RightLegColor = description.LeftLegColor
			local ok, model = pcall(function()
				return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
			end)
			description:Destroy()
			if token ~= epoch or newOwner.Parent ~= Players then
				if ok then
					model:Destroy()
				end
				return
			end
			if not ok then
				warn("[TrainingBots] avatar creation failed", model)
				notify("Training avatar unavailable; bots not enabled. Rejoin to retry.")
				cleanup()
				return
			end
			for _, d in model:GetDescendants() do
				if d:IsA("LuaSourceContainer") then
					d:Destroy()
				end
			end
			model.Name = "TrainingRig" .. i
			model.Archivable = true
			model.Parent = templates
			local bot = Actors.register(newOwner, i)
			bot.template = model
			bot.folder = folder
			bot.queueAttempt = false
			bot.queueSince = nil
			bot.returning = false
			Match.registerBot(bot)
		end
		building = false
		notify("Two beginner training bots are ready. Shoot one to start a duel; enter the queue to play a match.")
	end)
end
local function chooseOwner()
	if owner and owner.Parent == Players then
		return
	end
	local list = Players:GetPlayers()
	table.sort(list, function(a, b)
		return a.UserId < b.UserId
	end)
	for _, p in list do
		if Access.allowed(p.UserId, game.GameId, game.PlaceId) then
			create(p)
			return
		end
	end
end
local function visible(bot: any, model: Model, alerted: boolean?): (boolean, Vector3?, number)
	local head = bot.model and bot.model:FindFirstChild("Head")
	local part = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
	if not head or not part then
		return false, nil, math.huge
	end
	local delta = part.Position - head.Position
	local distance = delta.Magnitude
	if distance < 0.1 or distance > Config.AcquisitionRange then
		return false, nil, distance
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = Maps.worldRoots()
	params.RespectCanCollide = true
	local hit = workspace:Raycast(head.Position, delta, params)
	if hit then
		return false, nil, distance
	end
	local root = bot.model.HumanoidRootPart
	if not alerted and root.CFrame.LookVector:Dot(delta.Unit) < math.cos(math.rad(Config.TargetFieldOfView / 2)) then
		return false, nil, distance
	end
	return true, part.Position, distance
end
local function perceive(bot: any, now: number)
	if now < (bot.nextPerception or 0) then
		return
	end
	bot.nextPerception = now + Config.PerceptionInterval
	local selected, point, best = nil, nil, math.huge
	for _, candidate in Actors.all() do
		local model = Actors.character(candidate)
		if model and live(model) and Context.resolve(bot, model) ~= "Blocked" and not Character.isProtected(model) then
			local seen, pos, distance = visible(bot, model, candidate == bot.owner and now < (bot.alertUntil or 0))
			if Policy.canPerceive(distance, seen, true, true, Config.AcquisitionRange) and distance < best then
				selected, point, best = candidate, pos, distance
			end
		end
	end
	bot.seesTarget = selected ~= nil
	if selected then
		if bot.target ~= selected then
			bot.reactAt = now + random:NextNumber(Config.ReactionMin, Config.ReactionMax)
		end
		bot.target = selected
		bot.lastSeen = point
		bot.seenAt = now
		local m = Actors.character(selected)
		local root = m and m:FindFirstChild("HumanoidRootPart")
		bot.movingTarget = root and root.AssemblyLinearVelocity.Magnitude > 3
	elseif now - (bot.seenAt or -math.huge) > Config.TargetPersistence then
		bot.target = nil
		bot.lastSeen = nil
	end
end
local function gait(bot: any, now: number)
	local m = bot.model
	local root = m and m:FindFirstChild("HumanoidRootPart")
	local h = m and m:FindFirstChildOfClass("Humanoid")
	if not root or not h or h.Health <= 0 then
		return
	end
	local speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
	local walk = math.clamp(speed / Game.Movement.WalkSpeed, 0, 1)
	local weapon = Combat.getState(bot)
	local loading = weapon
		and weapon.slots[weapon.equipped].reloading == true
		and bot.reloadUntil ~= nil
		and now < bot.reloadUntil
	local ik = h:FindFirstChild("LeftHandIK")
	if ik then
		ik.Weight = if loading then 0 else 1
	end
	local wave = math.sin(now * 10) * 0.58 * walk
	for joint, base in bot.gait or {} do
		if joint.Parent then
			local sign = if joint.Name:find("Left") then 1 else -1
			local rotation = if joint.Name:find("Hip")
				then sign * wave
				elseif joint.Name:find("Knee") then math.abs(wave) * 0.6
				else 0
			if h.FloorMaterial == Enum.Material.Air and joint.Name:find("Hip") then
				rotation = -0.35
			end
			if
				m:GetAttribute("ReloadingAt")
				and bot.reloadUntil
				and now < bot.reloadUntil
				and joint.Name == "LeftShoulder"
			then
				rotation = -0.35 + math.sin(now * 12) * 0.13
			end
			joint.C0 = base * CFrame.Angles(rotation, 0, 0)
		end
	end
	local torso = m:FindFirstChild("UpperTorso")
	if torso and bot.team then
		torso.Color = Game.Teams[bot.team].Color
	end
	if bot.label then
		bot.label.TextColor3 = if bot.team then Game.Teams[bot.team].Color else Color3.fromRGB(220, 235, 242)
	end
end
local function fight(bot: any, now: number, dt: number)
	perceive(bot, now)
	local model = bot.model
	local root = model.HumanoidRootPart
	local hum = model.Humanoid
	if not bot.lastSeen then
		state(bot, "Repositioning")
		hum.AutoRotate = true
		if not bot.patrolGoal or now > (bot.nextPatrol or 0) then
			local markers = if bot.team
				then Maps.spawns(if bot.team == "Blue" then "Red" else "Blue")
				else Maps.rangeSpawns()
			if #markers > 0 then
				bot.patrolGoal = markers[random:NextInteger(1, #markers)].Position
				bot.nextPatrol = now + 5
			end
		end
		if bot.patrolGoal then
			Navigation.move(bot, bot.patrolGoal, now)
		end
		return
	end
	if not bot.seesTarget then
		state(bot, "Repositioning")
		hum.AutoRotate = true
		Navigation.move(bot, bot.lastSeen, now)
		return
	end
	state(bot, "Engaging")
	hum.AutoRotate = false
	local head = model.Head
	local delta = bot.lastSeen - head.Position
	if now >= (bot.nextError or 0) then
		local error = Config.AimErrorDegrees + (if bot.movingTarget then Config.MovingAimErrorDegrees else 0)
		bot.error = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-0.6, 0.6), 0)
			* math.tan(math.rad(error))
			* delta.Magnitude
		bot.nextError = now + 0.55
	end
	local desired = (delta + (bot.error or Vector3.zero)).Unit
	bot.aim = bot.aim:Lerp(desired, 1 - math.exp(-Config.AimTrackingSpeed * dt)).Unit
	local flat = Vector3.new(bot.aim.X, 0, bot.aim.Z)
	if flat.Magnitude > 0.01 then
		local target = CFrame.lookAt(root.Position, root.Position + flat)
		local angle = math.acos(math.clamp(root.CFrame.LookVector:Dot(flat.Unit), -1, 1))
		root.CFrame = root.CFrame:Lerp(target, math.min(1, Config.TurnRadiansPerSecond * dt / math.max(0.01, angle)))
	end
	model:SetAttribute("AimPitch", math.asin(math.clamp(bot.aim.Y, -1, 1)))
	if now >= (bot.nextMove or 0) then
		bot.nextMove = now + Config.MovementDecisionInterval
		local away = (root.Position - bot.lastSeen) * Vector3.new(1, 0, 1)
		if away.Magnitude > 0.1 then
			local forward = away.Unit
			local side = Vector3.new(-forward.Z, 0, forward.X) * (if random:NextNumber() < 0.5 then -1 else 1)
			bot.moveGoal = bot.lastSeen + forward * Config.PreferredDistance + side * random:NextNumber(3, 8)
			-- Bounded cover query: candidate must actually obscure the last visible opponent.
			if now >= (bot.nextCover or 0) then
				bot.nextCover = now + Config.RepositionFrequency
				if random:NextNumber() < 0.3 then
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Include
					params.FilterDescendantsInstances = Maps.worldRoots()
					params.RespectCanCollide = true
					local hit = workspace:Raycast(root.Position, forward * 12 + side * 12, params)
					if hit then
						local cover = hit.Position + hit.Normal * 3
						local obstruction = workspace:Raycast(bot.lastSeen, cover - bot.lastSeen, params)
						if obstruction then
							bot.moveGoal = cover
						end
					end
				end
			end
		end
	end
	if bot.moveGoal then
		Navigation.move(bot, bot.moveGoal, now)
	end
	if now < (bot.reactAt or math.huge) or now < (bot.nextFire or 0) then
		return
	end
	local currentTarget = bot.target and Actors.character(bot.target)
	if not currentTarget or not live(currentTarget) or Context.resolve(bot, currentTarget) == "Blocked" then
		return
	end
	local stillSeen = visible(bot, currentTarget)
	if not stillSeen or Character.isProtected(currentTarget) then
		return
	end
	local weapons = Combat.getState(bot)
	if not weapons then
		return
	end
	for i = 1, 2 do
		Weapon.syncReload(weapons, i, now)
	end
	local slot = weapons.equipped
	local current = weapons.slots[slot]
	if current.reloading then
		state(bot, "Reloading")
		return
	end
	if current.ammo <= 0 then
		local other = if slot == 1 then 2 else 1
		if weapons.slots[other].ammo > 0 then
			Combat.npcAction(bot, "Equip", other)
			bot.nextFire = now + Config.ReloadDecisionDelay
		elseif Combat.npcAction(bot, "Reload", nil) then
			state(bot, "Reloading")
			bot.reloadUntil = Weapon.reloadDoneAt(weapons, slot)
			bot.nextFire = now + Config.ReloadDecisionDelay
		end
		return
	end
	if bot.swapAt and now >= bot.swapAt then
		bot.swapAt = nil
		if random:NextNumber() > Config.InefficientSwitchChance then
			Combat.npcAction(bot, "Equip", if slot == 1 then 2 else 1)
			bot.nextFire = now + random:NextNumber(0.08, 0.25)
			return
		end
	end
	if root.CFrame.LookVector:Dot(Vector3.new(bot.aim.X, 0, bot.aim.Z).Unit) < 0.88 then
		return
	end
	if Combat.npcAction(bot, "Fire", bot.aim) then
		bot.shots = (bot.shots or 0) + 1
		bot.nextFire = now + random:NextNumber(0.12, 0.3)
		bot.swapAt = now + random:NextNumber(Config.SwitchDelayMin, Config.SwitchDelayMax)
	end
end
local function think(bot: any, now: number, dt: number)
	local m = bot.model
	if not live(m) then
		state(bot, "Eliminated")
		return
	end
	gait(bot, now)
	local mode = Match.modeOf(bot)
	state(
		bot,
		Policy.state(
			mode,
			true,
			m:GetAttribute("Queued") == true,
			inside(bot.owner),
			Context.trainingActive(bot.owner),
			Match.inCombat()
		)
	)
	if mode == "Match" then
		bot.queueAttempt = false
		bot.queueSince = nil
		if Match.modeOf(bot.owner) ~= "Match" then
			Match.setMode(bot, "Practice")
			Context.stopTraining(bot.owner)
			return
		end
		if Match.inCombat() then
			state(bot, "MatchCombat")
			fight(bot, now, dt)
		else
			state(bot, "MatchPreparation")
			Navigation.clear(bot)
		end
		return
	end
	local queuing = inside(bot.owner)
	if queuing and bot.queueAttempt ~= false then
		Context.stopTraining(bot.owner)
		bot.target = nil
		bot.lastSeen = nil
		if not bot.queueSince then
			bot.queueSince = now
		end
		local goal = zone().Position + Vector3.new(if bot.index == 1 then -3 else 3, -Game.LobbyQueue.Offset.Y, 0)
		m.Humanoid.AutoRotate = true
		if m:GetAttribute("Queued") then
			state(bot, "Queued")
			Navigation.clear(bot)
		elseif now - bot.queueSince > Config.QueueNavigationTimeout then
			bot.queueAttempt = false
			state(bot, "ReturningToRange")
			notify("Training bot could not reach the queue. Leave the zone and reenter to retry.")
		else
			state(bot, "QueueFollowing")
			Navigation.move(bot, goal, now)
		end
	elseif queuing and bot.queueSince == nil then
		bot.queueAttempt = true
		bot.queueSince = now
		Context.stopTraining(bot.owner)
	else
		if not queuing then
			if bot.queueSince then
				bot.returning = true
				Navigation.clear(bot)
			end
			bot.queueAttempt = true
			bot.queueSince = nil
		end
		if Context.trainingActive(bot.owner) then
			fight(bot, now, dt)
		elseif bot.returning then
			state(bot, "ReturningToRange")
			m.Humanoid.AutoRotate = true
			Navigation.move(bot, home(bot), now)
			if (m.HumanoidRootPart.Position - home(bot)).Magnitude < 4 then
				bot.returning = false
				state(bot, "Passive")
				Navigation.clear(bot)
			end
		else
			state(bot, "Passive")
			Navigation.clear(bot)
		end
	end
end
function Service.start()
	if not Access.environment(game.GameId, game.PlaceId) then
		return
	end
	folder = Instance.new("Folder")
	folder.Name = "TrainingBots"
	folder.Parent = workspace
	templates = Instance.new("Folder")
	templates.Name = "TrainingBotTemplates"
	templates.Parent = Storage
	table.insert(connections, Character.Spawned:Connect(prepared))
	table.insert(
		connections,
		Character.Died:Connect(function(player)
			-- A range duel ends with this life. Match opponents remain hostile through respawns.
			if player ~= owner or Match.modeOf(player) ~= "Practice" then
				return
			end
			Context.stopTraining(player)
			for _, bot in Actors.list() do
				Navigation.clear(bot)
				Policy.resetRangeCombat(bot)
				if live(bot.model) then
					bot.model.Humanoid.AutoRotate = true
					bot.model:SetAttribute("AimPitch", 0)
					state(bot, "Passive")
				end
			end
		end)
	)
	table.insert(
		connections,
		Damage.Damaged:Connect(function(attacker, target)
			local hit = Actors.fromModel(target)
			if
				Actors.isBot(hit)
				and attacker == owner
				and Match.modeOf(hit) == "Practice"
				and Context.trainingActive(attacker)
			then
				local character = attacker.Character
				local head = character and character:FindFirstChild("Head")
				if head then
					for _, bot in Actors.list() do
						bot.target = attacker
						bot.lastSeen = head.Position
						bot.seenAt = os.clock()
						bot.alertUntil = os.clock() + Config.TargetPersistence
						bot.reactAt = os.clock() + random:NextNumber(Config.ReactionMin, Config.ReactionMax)
					end
				end
			end
		end)
	)
	table.insert(
		connections,
		Players.PlayerAdded:Connect(function()
			task.defer(chooseOwner)
		end)
	)
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player)
			if player == owner then
				cleanup()
				task.defer(chooseOwner)
			end
		end)
	)
	local accumulated = 0
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt)
			accumulated += dt
			if accumulated < Config.ThinkInterval then
				return
			end
			local step = math.min(accumulated, 0.25)
			accumulated = 0
			local now = os.clock()
			for _, bot in Actors.list() do
				think(bot, now, step)
			end
			Service.metrics.steps += 1
			Service.metrics.maxStepMs = math.max(Service.metrics.maxStepMs, (os.clock() - now) * 1000)
		end)
	)
	game:BindToClose(function()
		cleanup()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		folder:Destroy()
		templates:Destroy()
	end)
	chooseOwner()
	print("[TrainingBots] private authorized-session controller ready")
end
Service.bots = Actors.list
return Service
