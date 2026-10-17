-- Server side of the shotguns. The client shows its shot instantly, then
-- tells us about it; the server is the one that decides if it counts.
--
-- For each shot we check:
--   1. The gun is equipped, done equipping, and off cooldown (server clocks).
--   2. The shot starts near the shooter's head.
--   3. Each claimed pellet hit lines up with that pellet's direction, is in
--      range, and isn't behind a wall.
-- Then damage = PelletDamage x range falloff x hit-zone multiplier.
-- Aiming down sights uses a tighter spread and longer falloff (Config.Ads).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Spread = require(ReplicatedStorage.Shared.Spread)
local Health = require(script.Parent.Health)

local Remotes = ReplicatedStorage.Remotes
local WeaponConfig = Config.Weapon

local Weapons = {}

type GunState = {
	equippedSlot: number,
	equippedAt: number, -- os.clock() when the current gun was swapped to
	lastFired: { [number]: number }, -- slot -> os.clock() of its last shot
}

local states: { [Player]: GunState } = {}

local function resetState(player: Player)
	states[player] = {
		equippedSlot = 1,
		equippedAt = 0,
		lastFired = { [1] = -math.huge, [2] = -math.huge },
	}
end

-- 1.0 up close, sliding down to FalloffMinMultiplier at FalloffEnd and beyond.
-- Aiming down sights stretches both distances, so aimed shots reach farther.
local function falloff(distance: number, aiming: boolean): number
	local stretch = if aiming then Config.Ads.FalloffRangeMultiplier else 1
	local start = WeaponConfig.FalloffStart * stretch
	local finish = WeaponConfig.FalloffEnd * stretch
	local alpha = math.clamp((distance - start) / (finish - start), 0, 1)
	return 1 + (WeaponConfig.FalloffMinMultiplier - 1) * alpha
end

-- Finds the Humanoid a body part belongs to (player or dummy), if any
local function getHumanoid(part: BasePart): Humanoid?
	local model = part:FindFirstAncestorOfClass("Model")
	return model and model:FindFirstChildOfClass("Humanoid")
end

-- Everything with a Humanoid, so line-of-sight checks only look at the map
local function getAllCharacters(): { Instance }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	local dummies = workspace:FindFirstChild("Dummies")
	if dummies then
		table.insert(list, dummies)
	end
	return list
end

-- Returns the damage one pellet does, or nil if the claimed hit doesn't check out
local function checkPelletHit(
	origin: Vector3,
	direction: Vector3,
	part: BasePart,
	worldParams: RaycastParams,
	aiming: boolean
): number?
	-- How far along the pellet line the part is, and how far off to the side
	local toPart = part.Position - origin
	local distance = toPart:Dot(direction)
	if distance <= 0 or distance > WeaponConfig.MaxRange then
		return nil
	end
	local sideways = (toPart - direction * distance).Magnitude
	if sideways > part.Size.Magnitude / 2 + WeaponConfig.HitTolerance then
		return nil
	end

	-- Is there a wall between the shooter and the target along this pellet?
	local wallHit = workspace:Raycast(origin, direction * math.max(distance - 1, 0), worldParams)
	if wallHit then
		return nil
	end

	local zone = Config.PartZones[part.Name] or "Limbs"
	return WeaponConfig.PelletDamage * falloff(distance, aiming) * Config.HitZones[zone]
end

local function onFire(player: Player, slot: any, seed: any, origin: any, aim: any, hits: any, claimedAiming: any)
	-- Never trust the types of anything a client sends
	if (slot ~= 1 and slot ~= 2) or typeof(seed) ~= "number" or typeof(origin) ~= "Vector3"
		or typeof(aim) ~= "Vector3" or typeof(hits) ~= "table" then
		return
	end
	-- (x ~= x is only true for NaN, a "not a number" value a cheater could send)
	if aim.Magnitude < 0.5 or aim.Magnitude ~= aim.Magnitude or origin.Magnitude ~= origin.Magnitude then
		return
	end
	aim = aim.Unit

	local state = states[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head")
	if not state or not humanoid or humanoid.Health <= 0 or not head then
		return
	end

	-- 1. Timing: server clocks decide, with a little slack for network jitter
	local now = os.clock()
	local slack = WeaponConfig.ServerTimingTolerance
	if slot ~= state.equippedSlot then
		return
	end
	if now - state.equippedAt < WeaponConfig.EquipDelay - slack then
		return
	end
	if now - state.lastFired[slot] < WeaponConfig.FireCooldown - slack then
		return
	end
	state.lastFired[slot] = now

	-- 2. The shot must start near the shooter's head (where the camera is)
	if (origin - head.Position).Magnitude > WeaponConfig.MaxOriginOffset then
		return
	end

	-- Aiming down sights tightens the spread, so only believe it if the client
	-- also told the Movement module it's aiming (which sets this attribute).
	-- Claiming NOT to aim is never an advantage, so that's always accepted.
	local aiming = claimedAiming == true and character:GetAttribute("Aiming") == true

	-- Show the shot to everyone else
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Remotes.ShotFired:FireClient(other, character, seed, origin, aim, aiming)
		end
	end

	-- 3. Check each claimed pellet hit and add up damage per target
	local pellets = Spread.getPelletDirections(seed, aim, aiming)
	local worldParams = RaycastParams.new()
	worldParams.FilterType = Enum.RaycastFilterType.Exclude
	worldParams.FilterDescendantsInstances = getAllCharacters()

	local damageByTarget: { [Humanoid]: number } = {}
	local headshotTargets: { [Humanoid]: boolean } = {}
	local usedPellets = {}

	for _, hit in hits do
		if typeof(hit) ~= "table" then
			continue
		end
		local pelletIndex, part = hit.pellet, hit.part
		-- Each pellet can only hit once, and must be a real body part in the world
		if typeof(pelletIndex) ~= "number" or not pellets[pelletIndex] or usedPellets[pelletIndex] then
			continue
		end
		if typeof(part) ~= "Instance" or not part:IsA("BasePart") or not part:IsDescendantOf(workspace) then
			continue
		end
		local target = getHumanoid(part)
		if not target or target == humanoid or target.Health <= 0 then
			continue
		end

		local damage = checkPelletHit(origin, pellets[pelletIndex], part, worldParams, aiming)
		if damage then
			usedPellets[pelletIndex] = true
			damageByTarget[target] = (damageByTarget[target] or 0) + damage
			if Config.PartZones[part.Name] == "Head" then
				headshotTargets[target] = true
			end
		end
	end

	-- Apply damage and tell the shooter what landed (for hitmarkers/numbers)
	local results = {}
	for target, damage in damageByTarget do
		local killed = Health.damage(target, damage, humanoid)
		local targetHead = target.Parent and target.Parent:FindFirstChild("Head")
		table.insert(results, {
			position = if targetHead then targetHead.Position else origin,
			damage = math.round(damage),
			headshot = headshotTargets[target] == true,
			killed = killed,
		})
	end
	if #results > 0 then
		Remotes.HitConfirm:FireClient(player, results)
	end
end

local function onEquip(player: Player, slot: any)
	local state = states[player]
	if not state or (slot ~= 1 and slot ~= 2) or slot == state.equippedSlot then
		return
	end
	state.equippedSlot = slot
	state.equippedAt = os.clock()
end

-- Accessories (hats, hair) would block pellets and have no hit zone, so we
-- make rays pass straight through them.
local function ignoreAccessories(character: Model)
	local function check(descendant: Instance)
		if descendant:IsA("BasePart") and descendant:FindFirstAncestorOfClass("Accessory") then
			descendant.CanQuery = false
		end
	end
	for _, descendant in character:GetDescendants() do
		check(descendant)
	end
	character.DescendantAdded:Connect(check)
end

function Weapons.start()
	Remotes.Fire.OnServerEvent:Connect(onFire)
	Remotes.Equip.OnServerEvent:Connect(onEquip)

	local function onPlayerAdded(player: Player)
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		player.DevEnableMouseLock = false -- Shift is sprint, not Shift Lock
		player.CharacterAdded:Connect(function(character)
			resetState(player)
			ignoreAccessories(character)
			Health.setup(character:WaitForChild("Humanoid") :: Humanoid)
		end)
		if player.Character then
			resetState(player)
			ignoreAccessories(player.Character)
			Health.setup(player.Character:WaitForChild("Humanoid") :: Humanoid)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return Weapons
