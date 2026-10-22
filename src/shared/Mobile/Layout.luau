--!strict
-- Logical GUI pixels within DeviceSafeInsets. One layout, reflected horizontally.
local Layout = {}
export type Rect = { x: number, y: number, w: number, h: number }
export type Result = { unit: number, rects: { [string]: Rect } }

Layout.Gesture = { MaxDuration = 0.30, MinDistance = 72, Dominance = 1.8, MaxUpward = 16 }

function Layout.contains(r: Rect, x: number, y: number): boolean
	return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function Layout.overlaps(a: Rect, b: Rect, gap: number?): boolean
	local g = gap or 0
	return a.x < b.x + b.w + g and a.x + a.w + g > b.x and a.y < b.y + b.h + g and a.y + a.h + g > b.y
end

function Layout.calculate(width: number, height: number, left: boolean, saved: any?): Result
	width, height = math.max(width, 320), math.max(height, 240)
	local portrait = height > width
	local u = math.clamp(math.min(width / 844, height / 390), 0.8, 1.5)
	local rects: { [string]: Rect } = {}
	local function circle(name: string, x: number, y: number, size: number)
		local d = size * u
		rects[name] =
			{ x = math.clamp(x * width - d / 2, 8 * u, width - d - 8 * u), y = y * height - d / 2, w = d, h = d }
	end
	circle("LegacyV2Constraint", 0.86, 0.62, 104)
	circle("Fire", 0.72, 0.70, 78)
	circle("Crouch", 0.86, 0.35, 56)
	circle("Reload", 0.95, 0.35, 56)
	circle("EquipA", 0.66, 0.47, 50)
	circle("EquipB", 0.75, 0.35, 50)
	circle("Move", 0.13, 0.77, 104)
	circle("Jump", 0.94, 0.87, 72)
	circle("Scoreboard", 0.56, 0.08, 42)
	circle("Menu", 0.63, 0.08, 42)
	for _, name in { "Scoreboard", "Menu" } do
		rects[name].y = math.max(height * 0.08, 116 * u) - rects[name].h / 2
	end
	rects.Swipe = { x = width * 0.24, y = height * 0.31, w = width * 0.23, h = height * 0.46 }
	rects.Ammo = { x = width * 0.72 - 105 * u, y = height - 60 * u, w = 210 * u, h = 120 * 210 / 460 * u }
	rects.Health =
		{ x = math.max(8 * u, width * 0.13 - 70 * u), y = height - 34 * u, w = 140 * u, h = 74 * 140 / 380 * u }
	if portrait then
		circle("LegacyV2Constraint", 0.84, 0.62, 104)
		circle("Fire", 0.59, 0.74, 78)
		circle("Crouch", 0.84, 0.35, 56)
		circle("Reload", 0.62, 0.35, 56)
		circle("EquipA", 0.61, 0.48, 50)
		circle("EquipB", 0.61, 0.22, 50)
		circle("Jump", 0.86, 0.82, 72)
		circle("Scoreboard", 0.45, 0.12, 42)
		circle("Menu", 0.80, 0.12, 42)
		for _, name in { "Scoreboard", "Menu" } do
			rects[name].y = math.max(height * 0.12, 116 * u) - rects[name].h / 2
		end
		rects.Swipe = { x = width * 0.06, y = height * 0.27, w = width * 0.38, h = height * 0.25 }
	end
	-- Version-2 saved positions are in canonical right-handed space. Reject unsafe
	-- overrides rather than allowing an invisible hit area to cover another control.
	if typeof(saved) == "table" then
		for _, name in
			{
				"LegacyV2Constraint",
				"Fire",
				"Crouch",
				"Reload",
				"EquipA",
				"EquipB",
				"Move",
				"Jump",
				"Scoreboard",
				"Menu",
			}
		do
			local v = saved[if name == "LegacyV2Constraint" then "Look" else name]
			if typeof(v) == "table" and typeof(v[1]) == "number" and typeof(v[2]) == "number" then
				local old = rects[name]
				local sc = if typeof(v[3]) == "number" then math.clamp(v[3], 0.8, 1.3) else 1
				local d = old.w * sc
				local candidate = { x = v[1] * width - d / 2, y = v[2] * height - d / 2, w = d, h = d }
				local valid = candidate.x >= 0
					and candidate.y >= 0
					and candidate.x + d <= width
					and candidate.y + d <= height
				for other, r in rects do
					if other ~= name and Layout.overlaps(candidate, r, 6 * u) then
						valid = false
					end
				end
				if valid then
					rects[name] = candidate
				end
			end
		end
	end
	-- Compatibility only: keep old override validation, but expose no look bounds/UI.
	local visible: { [string]: Rect } = {}
	for name, r in rects do
		if name ~= "LegacyV2Constraint" then
			visible[name] = r
		end
	end
	rects = visible
	if left then
		for _, r in rects do
			r.x = width - r.x - r.w
		end
	end
	return { unit = u, rects = rects }
end

return Layout
