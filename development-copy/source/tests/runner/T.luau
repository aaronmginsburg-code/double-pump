--!nocheck
-- Tiny test framework: T.describe / T.it / T.expect.

local T = {}
local results = { passed = 0, failed = 0, failures = {} }
local prefix = {}

function T.describe(name, fn)
	table.insert(prefix, name)
	fn()
	table.remove(prefix)
end

function T.it(name, fn)
	local full = table.concat(prefix, " > ") .. " > " .. name
	local ok, err = xpcall(fn, debug.traceback)
	if ok then
		results.passed += 1
	else
		results.failed += 1
		table.insert(results.failures, { name = full, err = err })
	end
end

local function fmt(v)
	if typeof(v) == "string" then
		return string.format("%q", v)
	end
	return tostring(v)
end

function T.expect(actual)
	local e = {}
	function e.toBe(expected)
		if actual ~= expected then
			error(`expected {fmt(expected)}, got {fmt(actual)}`, 2)
		end
	end
	function e.toBeNear(expected, eps)
		eps = eps or 1e-6
		if math.abs(actual - expected) > eps then
			error(`expected {expected} ± {eps}, got {actual}`, 2)
		end
	end
	function e.toBeTruthy()
		if not actual then
			error(`expected truthy, got {fmt(actual)}`, 2)
		end
	end
	function e.toBeFalsy()
		if actual then
			error(`expected falsy, got {fmt(actual)}`, 2)
		end
	end
	function e.toBeGreaterThan(x)
		if not (actual > x) then
			error(`expected > {x}, got {actual}`, 2)
		end
	end
	function e.toBeLessThan(x)
		if not (actual < x) then
			error(`expected < {x}, got {actual}`, 2)
		end
	end
	function e.toBeAtLeast(x)
		if not (actual >= x) then
			error(`expected >= {x}, got {actual}`, 2)
		end
	end
	function e.toBeAtMost(x)
		if not (actual <= x) then
			error(`expected <= {x}, got {actual}`, 2)
		end
	end
	function e.toEqual(expected)
		local function deepEq(a, b)
			if typeof(a) ~= typeof(b) then
				return false
			end
			if typeof(a) ~= "table" then
				return a == b
			end
			for k, v in a do
				if not deepEq(v, b[k]) then
					return false
				end
			end
			for k in b do
				if a[k] == nil then
					return false
				end
			end
			return true
		end
		if not deepEq(actual, expected) then
			error("tables differ", 2)
		end
	end
	return e
end

T.results = results
return T
