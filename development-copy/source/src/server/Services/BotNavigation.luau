--!strict
-- At most one outstanding path per NPC, with stale-result cancellation and bounded replans.
local Pathfinding = game:GetService("PathfindingService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Training.Beginner)
local Policy = require(game:GetService("ReplicatedStorage").Shared.Training.Policy)
local Nav = {}
function Nav.clear(bot: any)
	bot.pathEpoch = (bot.pathEpoch or 0) + 1
	if bot.blocked then
		bot.blocked:Disconnect()
		bot.blocked = nil
	end
	if bot.path then
		bot.path:Destroy()
		bot.path = nil
	end
	bot.waypoints = nil
	bot.waypoint = 2
	bot.goal = nil
	bot.pathBusy = false
	local m = bot.model
	local h = m and m:FindFirstChildOfClass("Humanoid")
	if h then
		h:Move(Vector3.zero)
		local r = m:FindFirstChild("HumanoidRootPart")
		if r then
			h:MoveTo(r.Position)
		end
	end
end
function Nav.move(bot: any, goal: Vector3, now: number)
	local m = bot.model
	local h = m and m:FindFirstChildOfClass("Humanoid")
	local r = m and m:FindFirstChild("HumanoidRootPart")
	if not h or not r or h.Health <= 0 then
		return
	end
	if Policy.reached(goal - r.Position, 2) then
		Nav.clear(bot)
		return
	end
	if bot.waypoints then
		local wp = bot.waypoints[bot.waypoint or 2]
		if wp and Policy.reached(wp.Position - r.Position, 3) then
			bot.waypoint += 1
			bot.waypointAt = now
			wp = bot.waypoints[bot.waypoint]
		end
		if wp then
			if wp.Action == Enum.PathWaypointAction.Jump then
				h.Jump = true
			end
			h:MoveTo(wp.Position)
			if now - (bot.waypointAt or now) > Config.WaypointTimeout then
				bot.nextPath = 0
				bot.waypoints = nil
				h.Jump = true
			end
		end
	end
	local changed = not bot.goal or (bot.goal - goal).Magnitude > 5
	if bot.pathBusy or now < (bot.nextPath or 0) or (not changed and bot.waypoints) then
		return
	end
	bot.nextPath = now + Config.PathInterval
	bot.goal = goal
	bot.pathBusy = true
	bot.pathEpoch = (bot.pathEpoch or 0) + 1
	local epoch = bot.pathEpoch
	task.spawn(function()
		local path = Pathfinding:CreatePath({
			AgentRadius = 2,
			AgentHeight = 5,
			AgentCanJump = true,
			AgentCanClimb = false,
			WaypointSpacing = 4,
		})
		local ok = pcall(function()
			path:ComputeAsync(r.Position, goal)
		end)
		if epoch ~= bot.pathEpoch or bot.disposed or bot.model ~= m then
			path:Destroy()
			return
		end
		bot.pathBusy = false
		if bot.blocked then
			bot.blocked:Disconnect()
			bot.blocked = nil
		end
		if bot.path then
			bot.path:Destroy()
		end
		bot.path = path
		if ok and path.Status == Enum.PathStatus.Success then
			bot.waypoints = path:GetWaypoints()
			bot.waypoint = 2
			bot.waypointAt = os.clock()
			bot.blocked = path.Blocked:Connect(function(index)
				if index >= (bot.waypoint or 2) then
					bot.waypoints = nil
					bot.nextPath = 0
				end
			end)
			bot.pathSuccess = (bot.pathSuccess or 0) + 1
		else
			bot.waypoints = nil
			bot.pathFailures = (bot.pathFailures or 0) + 1
			-- Failed paths never cause teleports or movement through walls.
		end
	end)
end
return Nav
