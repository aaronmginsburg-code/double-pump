--!strict
local Registry = require(script.Parent.Registry)
local C = { Schema = 2, Categories = { "movement", "aiming", "autoFire", "weapons", "audio" }, Fields = Registry }
function C.defaults(): any
	local out = {}
	for _, category in C.Categories do
		out[category] = {}
	end
	for _, field in Registry do
		out[field.category][field.key] = field.default
	end
	return out
end
function C.copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = C.copy(v)
	end
	return out
end
function C.field(category: string, key: string): any
	for _, field in Registry do
		if field.category == category and field.key == key then
			return field
		end
	end
	return nil
end
function C.value(field: any, value: any): boolean
	if not field.available then
		return value == field.default
	end
	if field.type == "boolean" then
		return type(value) == "boolean"
	end
	if field.type == "enum" then
		return table.find(field.options, value) ~= nil
	end
	return type(value) == "number"
		and value == value
		and value >= field.min
		and value <= field.max
		and (field.step ~= 1 or value % 1 == 0)
end
function C.validate(raw: any): (any, string?)
	if type(raw) ~= "table" or getmetatable(raw) ~= nil then
		return nil, "Expected plain configuration"
	end
	local clean = C.defaults()
	for category, values in raw do
		if not table.find(C.Categories, category) or type(values) ~= "table" or getmetatable(values) ~= nil then
			return nil, "Unknown category"
		end
		for key in values do
			if not C.field(category, key) then
				return nil, "Unknown setting: " .. tostring(key)
			end
		end
	end
	for _, field in Registry do
		local value = raw[field.category] and raw[field.category][field.key]
		if not C.value(field, value) then
			return nil, "Invalid " .. field.label
		end
		clean[field.category][field.key] = value
	end
	local w = clean.weapons
	if w.falloffStart >= w.falloffEnd or w.falloffEnd > w.range then
		return nil, "Require falloff start < end <= maximum range"
	end
	for _, field in Registry do
		if field.category == "audio" and field.key:sub(-4) == "_min" then
			local name = field.key:sub(1, -5)
			if clean.audio[field.key] >= clean.audio[name .. "_max"] then
				return nil, "Near distance must be below far distance"
			end
		end
	end
	return clean
end
function C.equal(a: any, b: any, scope: string?): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for _, f in Registry do
		if not scope or scope == "all" or scope == f.category then
			if not a[f.category] or not b[f.category] or a[f.category][f.key] ~= b[f.category][f.key] then
				return false
			end
		end
	end
	return true
end
function C.scope(scope: any): boolean
	return scope == "all" or table.find(C.Categories, scope) ~= nil
end
function C.name(name: any): boolean
	return type(name) == "string" and #name >= 1 and #name <= 24 and name:match("^[%w_%-]+$") ~= nil
end
function C.merge(active: any, saved: any, scope: string): any
	local out = C.copy(active)
	if scope == "all" then
		return C.validate(saved)
	end
	out[scope] = C.copy(saved[scope])
	return C.validate(out)
end
function C.legacy(values: any): any
	local out = C.defaults()
	for key, value in values do
		if out.aiming[key] ~= nil then
			out.aiming[key] = value
		end
	end
	return C.validate(out)
end
return C
