--!strict
local Config = require(script.Parent.Config)
local Store = {}
Store.__index = Store
function Store.new(adapter: any): any
	return setmetatable({ adapter = adapter }, Store)
end
local function record(raw: any): any
	if
		type(raw) ~= "table"
		or raw.schema ~= Config.Schema
		or type(raw.revision) ~= "number"
		or raw.revision % 1 ~= 0
		or raw.revision < 1
		or raw.revision > 1e9
		or not Config.scope(raw.scope)
		or not Config.name(raw.name)
	then
		return nil
	end
	local values = Config.validate(raw.values)
	return if values
		then { schema = 2, revision = raw.revision, values = values, scope = raw.scope, name = raw.name }
		else nil
end
function Store:load(key: string): (any, string?)
	local ok, result = pcall(function()
		return self.adapter:GetAsync(key)
	end)
	if not ok then
		return nil, "Load unavailable; active configuration preserved"
	end
	if result == nil then
		return { revision = 0, values = nil }
	end
	local clean = record(result)
	return clean, if clean then nil else "Invalid or newer preset; not overwritten"
end
function Store:save(key: string, expected: any, values: any, scope: string, name: string): (any, string?)
	local clean = Config.validate(values)
	if
		not clean
		or not Config.scope(scope)
		or not Config.name(name)
		or type(expected) ~= "number"
		or expected % 1 ~= 0
		or expected < 0
		or expected >= 1e9
	then
		return nil, "Invalid save"
	end
	local proposed = { schema = 2, revision = expected + 1, values = clean, scope = scope, name = name }
	local conflict = false
	local ok, result = pcall(function()
		return self.adapter:UpdateAsync(key, function(old)
			local previous = if old == nil then { revision = 0 } else record(old)
			if not previous or previous.revision ~= expected then
				conflict = true
				return nil
			end
			conflict = false
			return proposed
		end)
	end)
	if not ok then
		return nil, "Save unavailable; active configuration preserved"
	end
	if conflict or not result then
		return nil, "Preset changed elsewhere; reload before saving"
	end
	return record(result)
end
return Store
