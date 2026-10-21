--!nocheck
-- Loads the game's ModuleScripts under Lune the way Roblox would: each module gets a
-- `script` that points at its place in the Rojo tree, `require(script.Parent.X)` and
-- `require(ReplicatedStorage.Shared.X)` work, and Roblox datatypes (Vector3, CFrame,
-- Color3, Enum, Instance, ...) come from Lune's roblox library.
-- Services other than the Rojo-mapped folders are stubs that tests can replace.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Loader = {}

local ROOTS = {
	ReplicatedStorage = { Shared = "src/shared" },
	ServerScriptService = { Server = "src/server" },
	StarterPlayer = { StarterPlayerScripts = { Client = "src/client" } },
}

-- fs calls yield, and yielding inside __index is not allowed, so index every file up front.
local isFileSet, isDirSet, dirEntries, fileContents = {}, {}, {}, {}
local function scan(dir)
	isDirSet[dir] = true
	dirEntries[dir] = fs.readDir(dir)
	for _, entry in dirEntries[dir] do
		local path = dir .. "/" .. entry
		if fs.isDir(path) then
			scan(path)
		else
			isFileSet[path] = true
			if path:match("%.luau?$") then
				fileContents[path] = fs.readFile(path)
			end
		end
	end
end
scan("src")
local fsIndex = {
	isFile = function(p)
		return isFileSet[p] == true
	end,
	isDir = function(p)
		return isDirSet[p] == true
	end,
	readDir = function(p)
		return dirEntries[p] or {}
	end,
	readFile = function(p)
		return fileContents[p] or fs.readFile(p)
	end,
}

local nodeCache = {}
local moduleCache = {}
Loader.services = {}

local Node = {}

local function makeNode(name, parent, path)
	local key = path or tostring(parent) .. "/" .. name
	if path and nodeCache[key] then
		return nodeCache[key]
	end
	local node = setmetatable({ __name = name, __parent = parent, __path = path, __virtual = {} }, Node)
	if path then
		nodeCache[key] = node
	end
	return node
end

local function childPath(dir, name)
	local candidates = { dir .. "/" .. name .. ".luau", dir .. "/" .. name .. ".lua", dir .. "/" .. name }
	for _, candidate in candidates do
		if fsIndex.isFile(candidate) or fsIndex.isDir(candidate) then
			return candidate
		end
	end
	return nil
end

local function findChild(node, name)
	local virtual = rawget(node, "__virtual")[name]
	if virtual then
		return virtual
	end
	local path = rawget(node, "__path")
	if path and fsIndex.isDir(path) then
		local found = childPath(path, name)
		if found then
			return makeNode(name, node, found)
		end
	end
	return nil
end

Node.__index = function(self, key)
	if key == "Name" then
		return rawget(self, "__name")
	elseif key == "Parent" then
		return rawget(self, "__parent")
	elseif key == "FindFirstChild" or key == "WaitForChild" then
		return function(this, name)
			return findChild(this, name)
		end
	elseif key == "GetChildren" then
		return function(this)
			local out = {}
			local path = rawget(this, "__path")
			if path and fsIndex.isDir(path) then
				for _, entry in fsIndex.readDir(path) do
					local name = entry:gsub("%.luau$", ""):gsub("%.lua$", "")
					if name ~= "init" and not name:find("%.server$") and not name:find("%.client$") then
						table.insert(out, findChild(this, name))
					end
				end
			end
			for _, child in rawget(this, "__virtual") do
				table.insert(out, child)
			end
			return out
		end
	elseif key == "IsA" then
		return function(_, className)
			return className == "ModuleScript" or className == "Instance"
		end
	elseif key == "GetFullName" then
		return function(this)
			return tostring(this)
		end
	end
	local child = findChild(self, key)
	if child == nil then
		error(`{key} is not a valid member of {tostring(self)}`, 2)
	end
	return child
end
Node.__tostring = function(self)
	local parent = rawget(self, "__parent")
	return (parent and tostring(parent) .. "." or "") .. rawget(self, "__name")
end

local function buildTree(name, spec, parent)
	if typeof(spec) == "string" then
		return makeNode(name, parent, spec)
	end
	local node = makeNode(name, parent, nil)
	for childName, childSpec in spec do
		rawget(node, "__virtual")[childName] = buildTree(childName, childSpec, node)
	end
	return node
end

local game = makeNode("game", nil, nil)
for serviceName, spec in ROOTS do
	rawget(game, "__virtual")[serviceName] = buildTree(serviceName, spec, game)
end

local function getService(_, name)
	if Loader.services[name] then
		return Loader.services[name]
	end
	local node = rawget(game, "__virtual")[name]
	if node then
		return node
	end
	error(`Loader: no stub for service {name}; set Loader.services.{name} in the test`)
end
rawget(game, "__virtual").GetService = getService

-- `game` as modules see it
local gameProxy = setmetatable({}, {
	__index = function(_, key)
		if key == "GetService" then
			return getService
		end
		return getService(nil, key)
	end,
})

local function fileOf(node)
	local path = rawget(node, "__path")
	if not path then
		error(`{tostring(node)} is not a module`)
	end
	if fsIndex.isDir(path) then
		for _, init in { "/init.luau", "/init.lua" } do
			if fsIndex.isFile(path .. init) then
				return path .. init
			end
		end
		error(`{path} has no init module`)
	end
	return path
end

local baseEnv = getfenv(1)

local function robloxTypeof(value)
	return typeof(value)
end

local requireModule

local function makeEnv(scriptNode)
	return setmetatable({
		script = scriptNode,
		require = requireModule,
		game = gameProxy,
		workspace = Loader.services.Workspace,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		BrickColor = roblox.BrickColor,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Enum = roblox.Enum,
		Instance = roblox.Instance,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		Rect = roblox.Rect,
		PhysicalProperties = roblox.PhysicalProperties,
		Font = roblox.Font,
		Random = Loader.Random,
		typeof = robloxTypeof,
		task = Loader.task,
		tick = os.clock,
	}, { __index = baseEnv })
end

requireModule = function(target)
	if typeof(target) == "string" then
		return require(target)
	end
	if typeof(target) ~= "table" or getmetatable(target) ~= Node then
		if typeof(target) == "table" and target.__module ~= nil then
			return target.__module
		end
		error("Loader: require expects a module node")
	end
	local file = fileOf(target)
	if moduleCache[file] ~= nil then
		return moduleCache[file]
	end
	local source = fsIndex.readFile(file)
	local chunk = luau.load(source, { debugName = file, environment = makeEnv(target) })
	local result = chunk()
	moduleCache[file] = result
	return result
end

-- Fresh module instances (state isolation between tests).
function Loader.reset()
	moduleCache = {}
end

-- A stand-in module that `require(node)` should return, e.g. Loader.fake(Shared.Net, stub)
function Loader.inject(node, value)
	moduleCache[fileOf(node)] = value
end

Loader.require = requireModule
Loader.game = gameProxy
Loader.Shared = rawget(rawget(game, "__virtual").ReplicatedStorage, "__virtual").Shared
Loader.Server = rawget(rawget(game, "__virtual").ServerScriptService, "__virtual").Server
Loader.roblox = roblox

-- Minimal deterministic Random (Roblox's Random isn't available in Lune).
local RandomClass = {}
RandomClass.__index = RandomClass
function RandomClass.new(seed)
	local self = setmetatable({ state = ((seed or 1) * 2654435761 + 12345) % 2147483647 + 1 }, RandomClass)
	for _ = 1, 4 do
		self:NextNumber()
	end
	return self
end
function RandomClass:NextNumber(min, max)
	self.state = (self.state * 48271) % 2147483647
	local u = self.state / 2147483647
	if min then
		return min + (max - min) * u
	end
	return u
end
function RandomClass:NextInteger(min, max)
	return math.floor(self:NextNumber(min, max + 1 - 1e-9))
end
Loader.Random = RandomClass

Loader.task = {
	wait = function()
		return 0
	end,
	spawn = function(f, ...)
		return f(...)
	end,
	defer = function(f, ...)
		return f(...)
	end,
	delay = function(_, f, ...)
		return f(...)
	end,
}

return Loader
