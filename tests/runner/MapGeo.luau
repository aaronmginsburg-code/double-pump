--!nocheck
-- Geometry checks for map modules, run in Lune (no Roblox physics). Every solid part is
-- treated as an oriented box (wedges and cylinders too, which is conservative). Used by
-- tests/maps.spec.luau and tools/map_report.luau.

local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3

local MapGeo = {}

-- Solid = blocks players and pellets: collidable, queryable, visible, not shot-through.
function MapGeo.solids(model)
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local parentName = d.Parent and d.Parent.Name
			local skip = parentName == "Markers"
				or parentName == "Lights"
				or not d.CanCollide
				or not d.CanQuery
				or d.Transparency >= 1
				or d:GetAttribute("ShotThrough")
				or d:GetAttribute("Barrier")
			if not skip then
				local c = d.CFrame
				local pos = c.Position
				local r, u, l = c.RightVector, c.UpVector, -c.LookVector
				local h = d.Size / 2
				-- World AABB for a fast reject
				local ex = math.abs(r.X) * h.X + math.abs(u.X) * h.Y + math.abs(l.X) * h.Z
				local ey = math.abs(r.Y) * h.X + math.abs(u.Y) * h.Y + math.abs(l.Y) * h.Z
				local ez = math.abs(r.Z) * h.X + math.abs(u.Z) * h.Y + math.abs(l.Z) * h.Z
				table.insert(list, {
					name = d.Name,
					px = pos.X,
					py = pos.Y,
					pz = pos.Z,
					ax = { r.X, r.Y, r.Z },
					ay = { u.X, u.Y, u.Z },
					az = { l.X, l.Y, l.Z },
					hx = h.X,
					hy = h.Y,
					hz = h.Z,
					minX = pos.X - ex,
					maxX = pos.X + ex,
					minY = pos.Y - ey,
					maxY = pos.Y + ey,
					minZ = pos.Z - ez,
					maxZ = pos.Z + ez,
				})
			end
		end
	end
	return list
end

-- Slab test of segment a + t*(b-a), t in [0,1], against one oriented box. Returns t or nil.
local function segmentBox(s, ax, ay, az, dx, dy, dz)
	local ox, oy, oz = ax - s.px, ay - s.py, az - s.pz
	local tmin, tmax = 0, 1
	for i = 1, 3 do
		local axis = if i == 1 then s.ax elseif i == 2 then s.ay else s.az
		local half = if i == 1 then s.hx elseif i == 2 then s.hy else s.hz
		local o = ox * axis[1] + oy * axis[2] + oz * axis[3]
		local d = dx * axis[1] + dy * axis[2] + dz * axis[3]
		if math.abs(d) < 1e-9 then
			if o < -half or o > half then
				return nil
			end
		else
			local t1 = (-half - o) / d
			local t2 = (half - o) / d
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			if t1 > tmin then
				tmin = t1
			end
			if t2 < tmax then
				tmax = t2
			end
			if tmin > tmax then
				return nil
			end
		end
	end
	return tmin
end

-- Fraction along a->b of the first solid hit, or nil if clear.
function MapGeo.cast(solids, a, b)
	local dx, dy, dz = b.X - a.X, b.Y - a.Y, b.Z - a.Z
	local loX, hiX = math.min(a.X, b.X), math.max(a.X, b.X)
	local loY, hiY = math.min(a.Y, b.Y), math.max(a.Y, b.Y)
	local loZ, hiZ = math.min(a.Z, b.Z), math.max(a.Z, b.Z)
	local best = nil
	for _, s in solids do
		if s.maxX >= loX and s.minX <= hiX and s.maxY >= loY and s.minY <= hiY and s.maxZ >= loZ and s.minZ <= hiZ then
			local t = segmentBox(s, a.X, a.Y, a.Z, dx, dy, dz)
			if t and (best == nil or t < best) then
				best = t
			end
		end
	end
	return best
end

function MapGeo.clear(solids, a, b)
	return MapGeo.cast(solids, a, b) == nil
end

function MapGeo.inside(solids, point)
	for _, s in solids do
		if
			point.X >= s.minX
			and point.X <= s.maxX
			and point.Y >= s.minY
			and point.Y <= s.maxY
			and point.Z >= s.minZ
			and point.Z <= s.maxZ
		then
			local ox, oy, oz = point.X - s.px, point.Y - s.py, point.Z - s.pz
			local lx = ox * s.ax[1] + oy * s.ax[2] + oz * s.ax[3]
			local ly = ox * s.ay[1] + oy * s.ay[2] + oz * s.ay[3]
			local lz = ox * s.az[1] + oy * s.az[2] + oz * s.az[3]
			if math.abs(lx) <= s.hx and math.abs(ly) <= s.hy and math.abs(lz) <= s.hz then
				return s
			end
		end
	end
	return nil
end

function MapGeo.markers(model, name)
	local list = {}
	local folder = model:FindFirstChild("Markers")
	for _, m in if folder then folder:GetChildren() else {} do
		if m.Name == name then
			table.insert(list, m)
		end
	end
	return list
end

-- Standing spots: drop a ray at each grid point and find every floor surface with room
-- for a player above it. Returns eye positions (floor + 4.5).
function MapGeo.standingSpots(solids, minXZ, maxXZ, top, bottom, step)
	local spots = {}
	for x = minXZ.X + step / 2, maxXZ.X, step do
		for z = minXZ.Y + step / 2, maxXZ.Y, step do
			local from = Vector3.new(x, top, z)
			local cursor = top
			for _ = 1, 4 do
				local a = Vector3.new(x, cursor, z)
				local b = Vector3.new(x, bottom, z)
				local t = MapGeo.cast(solids, a, b)
				if not t then
					break
				end
				local floorY = cursor + (bottom - cursor) * t
				local feet = Vector3.new(x, floorY + 0.1, z)
				local head = Vector3.new(x, floorY + 5, z)
				if MapGeo.clear(solids, feet, head) and not MapGeo.inside(solids, Vector3.new(x, floorY + 2.5, z)) then
					table.insert(spots, Vector3.new(x, floorY + 4.5, z))
				end
				cursor = floorY - 0.6
				if cursor <= bottom then
					break
				end
			end
			local _ = from
		end
	end
	return spots
end

-- Standing spots a player can actually walk to from the spawns (step up at most 2 studs
-- per 2-stud move, i.e. stairs and ramps; any drop is fine). Jump-only perches are left
-- out on purpose so the sightline numbers describe normal play.
function MapGeo.reachable(solids, minXZ, maxXZ, top, bottom, starts)
	local step = 2
	local cells = {}
	local function cellKey(ix, iz)
		return ix * 100000 + iz
	end
	for _, eye in MapGeo.standingSpots(solids, minXZ, maxXZ, top, bottom, step) do
		local ix = math.floor((eye.X - minXZ.X) / step)
		local iz = math.floor((eye.Z - minXZ.Y) / step)
		local k = cellKey(ix, iz)
		cells[k] = cells[k] or {}
		table.insert(cells[k], { eye = eye, ix = ix, iz = iz, seen = false })
	end
	local queue = {}
	for _, start in starts do
		local ix = math.floor((start.X - minXZ.X) / step)
		local iz = math.floor((start.Z - minXZ.Y) / step)
		local best, bestD = nil, math.huge
		for _, entry in cells[cellKey(ix, iz)] or {} do
			local d = math.abs(entry.eye.Y - 4.5 - start.Y)
			if d < bestD then
				best, bestD = entry, d
			end
		end
		if best and not best.seen then
			best.seen = true
			table.insert(queue, best)
		end
	end
	local out = {}
	local head = 1
	while head <= #queue do
		local cur = queue[head]
		head += 1
		table.insert(out, cur.eye)
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			for _, nb in cells[cellKey(cur.ix + d[1], cur.iz + d[2])] or {} do
				if not nb.seen then
					local rise = nb.eye.Y - cur.eye.Y
					if rise <= 2.0 then
						local high = math.max(nb.eye.Y, cur.eye.Y)
						local a = Vector3.new(cur.eye.X, high, cur.eye.Z)
						local b = Vector3.new(nb.eye.X, high, nb.eye.Z)
						if MapGeo.clear(solids, a, b) then
							nb.seen = true
							table.insert(queue, nb)
						end
					end
				end
			end
		end
	end
	return out
end

-- For each spot, how far you can see horizontally in 16 directions, up to `range` or the
-- edge of the playable rectangle (open sky beyond the edge doesn't count as a sightline).
function MapGeo.sightlines(solids, spots, range, minXZ, maxXZ)
	local lengths = {}
	for _, eye in spots do
		for i = 0, 15 do
			local angle = i * math.pi / 8
			local dx, dz = math.cos(angle), math.sin(angle)
			local limit = range
			if minXZ then
				if dx > 1e-6 then
					limit = math.min(limit, (maxXZ.X - eye.X) / dx)
				elseif dx < -1e-6 then
					limit = math.min(limit, (minXZ.X - eye.X) / dx)
				end
				if dz > 1e-6 then
					limit = math.min(limit, (maxXZ.Y - eye.Z) / dz)
				elseif dz < -1e-6 then
					limit = math.min(limit, (minXZ.Y - eye.Z) / dz)
				end
				limit = math.max(limit, 0.1)
			end
			local dir = Vector3.new(dx, 0, dz)
			local t = MapGeo.cast(solids, eye, eye + dir * limit)
			table.insert(lengths, if t then t * limit else limit)
		end
	end
	table.sort(lengths)
	return lengths
end

function MapGeo.percentile(sorted, q)
	if #sorted == 0 then
		return 0
	end
	return sorted[math.clamp(math.ceil(#sorted * q), 1, #sorted)]
end

-- Fraction of solid parts whose 180° rotated twin (about the Y axis) exists.
function MapGeo.symmetry(solids)
	local index = {}
	local function key(x, y, z)
		return string.format("%d,%d,%d", math.round(x * 2), math.round(y * 2), math.round(z * 2))
	end
	for _, s in solids do
		index[key(s.px, s.py, s.pz)] = true
	end
	local matched = 0
	for _, s in solids do
		if index[key(-s.px, s.py, -s.pz)] then
			matched += 1
		end
	end
	return matched / math.max(1, #solids)
end

return MapGeo
