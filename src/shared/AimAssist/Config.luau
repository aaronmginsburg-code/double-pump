--!strict
-- Private-development presentation tuning. No weapon or profile values belong here.
local Config = {}
Config.Schema = 1
Config.Fields = {
	{ key = "enabled", label = "Aim Assist Enabled", default = true },
	{ key = "slowdownEnabled", label = "Aim Slowdown Enabled", default = true },
	{
		key = "slowdownStrength",
		label = "Slowdown Strength",
		default = 0.40,
		min = 0,
		max = 0.80,
		step = 0.01,
		unit = "fraction",
	},
	{ key = "rotationEnabled", label = "Rotational Assist Enabled", default = true },
	{
		key = "rotationStrength",
		label = "Rotational Strength",
		default = 0.20,
		min = 0,
		max = 0.60,
		step = 0.01,
		unit = "fraction",
	},
	{
		key = "radius",
		label = "Acquisition Radius",
		default = 0.12,
		min = 0.02,
		max = 0.30,
		step = 0.01,
		unit = "short-screen fraction",
	},
	{
		key = "maxDistance",
		label = "Maximum Target Distance",
		default = 100,
		min = 5,
		max = 150,
		step = 1,
		unit = "studs",
	},
	{
		key = "trackingSpeed",
		label = "Tracking Speed",
		default = 8,
		min = 0,
		max = 30,
		step = 0.5,
		unit = "response / second",
	},
	{
		key = "switchThreshold",
		label = "Target Switching Threshold",
		default = 0.20,
		min = 0,
		max = 0.80,
		step = 0.01,
		unit = "relative improvement",
	},
	{ key = "lineOfSight", label = "Strict Queryable Line of Sight", default = true },
}
Config.Slots = { "default", "touch", "controller" }
function Config.defaults(): any
	local values = {}
	for _, field in Config.Fields do
		values[field.key] = field.default
	end
	return values
end
function Config.validate(raw: any): (any?, string?)
	if type(raw) ~= "table" or getmetatable(raw) ~= nil then
		return nil, "Expected a plain configuration"
	end
	local out, known = {}, {}
	for _, field in Config.Fields do
		local value = raw[field.key]
		known[field.key] = true
		if type(field.default) == "boolean" then
			if type(value) ~= "boolean" then
				return nil, "Invalid " .. field.key
			end
		elseif type(value) ~= "number" or value ~= value or value < field.min or value > field.max then
			return nil, "Out of range: " .. field.key
		end
		out[field.key] = value
	end
	for key in raw do
		if not known[key] then
			return nil, "Unknown setting"
		end
	end
	return out
end
function Config.equal(a: any, b: any): boolean
	if not a or not b then
		return false
	end
	for _, field in Config.Fields do
		if a[field.key] ~= b[field.key] then
			return false
		end
	end
	return true
end
function Config.record(raw: any): any?
	if
		type(raw) ~= "table"
		or raw.schema ~= Config.Schema
		or type(raw.revision) ~= "number"
		or raw.revision < 1
		or raw.revision % 1 ~= 0
		or raw.revision > 1e9
	then
		return nil
	end
	local values = Config.validate(raw.values)
	return if values then { schema = Config.Schema, revision = raw.revision, values = values } else nil
end
return Config
