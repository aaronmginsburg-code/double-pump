--!strict
-- Dependency-injected CAS persistence. Failure/conflict never modifies session settings.
local Config = require(script.Parent.Config)
local Store = {}
Store.__index = Store
function Store.new(adapter: any): any
	return setmetatable({ adapter = adapter }, Store)
end
function Store.load(self: any, key: string): (any?, string?)
	local ok, raw = pcall(function()
		return self.adapter:GetAsync(key)
	end)
	if not ok then
		return nil, "Storage unavailable; session kept"
	end
	if raw == nil then
		return { revision = 0, values = nil }, nil
	end
	local record = Config.record(raw)
	return record, if record then nil else "Unsupported or invalid saved schema; not overwritten"
end
function Store.save(self: any, key: string, expected: number, values: any): (any?, string?)
	local clean, err = Config.validate(values)
	if not clean then
		return nil, err
	end
	if type(expected) ~= "number" or expected < 0 or expected % 1 ~= 0 or expected > 1e9 then
		return nil, "Load slot first"
	end
	local proposed = { schema = Config.Schema, revision = expected + 1, values = clean }
	local conflict = false
	local ok, result = pcall(function()
		return self.adapter:UpdateAsync(key, function(raw: any)
			local old = if raw ~= nil then Config.record(raw) else nil
			if (raw ~= nil and old == nil) or (if old then old.revision else 0) ~= expected then
				conflict = true
				return nil
			end
			return proposed
		end)
	end)
	if not ok then
		return nil, "Save failed; session kept. Load before retry if outcome uncertain"
	end
	if conflict or not result then
		return nil, "Saved slot changed; load before overwriting"
	end
	return Config.record(result), nil
end
return Store
