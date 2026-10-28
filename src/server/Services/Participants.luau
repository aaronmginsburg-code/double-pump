--!strict
-- Real Players OR explicitly registered server NPC records, never spoofed Player Instances.
local Players = game:GetService("Players")
local Access = require(script.Parent.DeveloperAccess)
local P = {}
local bots: { [any]: boolean } = {}
local byModel: { [Model]: any } = {}
P.trainingRound = false
function P.isBot(p: any): boolean
	return bots[p] == true
end
function P.isHuman(p: any): boolean
	return p ~= nil and not P.isBot(p)
end
function P.character(p: any): Model?
	return if P.isBot(p) then p.model else p and p.Character
end
function P.exists(p: any): boolean
	return if P.isBot(p) then p.owner.Parent == Players and not p.disposed else p ~= nil and p.Parent ~= nil
end
function P.name(p: any): string
	return if P.isBot(p) then p.name .. " [BOT]" else p.DisplayName
end
function P.id(p: any): number
	return if P.isBot(p) then 0 else p.UserId
end
function P.sortKey(p: any): string
	return if P.isBot(p) then "z" .. p.id else string.format("h%012d", p.UserId)
end
function P.attribute(p: any, k: string, v: any)
	local object = if P.isBot(p) then p.model else p
	if object then
		object:SetAttribute(k, v)
	end
end
function P.getAttribute(p: any, k: string): any
	local o = if P.isBot(p) then p.model else p
	return o and o:GetAttribute(k)
end
function P.all(): { any }
	local list = Players:GetPlayers()
	for b in bots do
		if P.exists(b) then
			table.insert(list, b)
		end
	end
	return list
end
function P.fromModel(model: Model): any
	return byModel[model] or Players:GetPlayerFromCharacter(model)
end
function P.register(owner: Player, index: number): any
	assert(Access.allowed(owner.UserId, game.GameId, game.PlaceId), "Private developer session only")
	assert(index == 1 or index == 2)
	for b in bots do
		assert(b.id ~= "training" .. index, "Duplicate training bot")
	end
	local b = {
		kind = "TrainingBot",
		id = "training" .. index,
		name = "Training Bot " .. index,
		owner = owner,
		index = index,
		model = nil,
		team = nil,
		disposed = false,
	}
	bots[b] = true
	return b
end
function P.bind(b: any, model: Model?)
	assert(P.isBot(b))
	if b.model then
		byModel[b.model] = nil
	end
	b.model = model
	if model then
		byModel[model] = b
	end
end
function P.remove(b: any)
	if b.model then
		byModel[b.model] = nil
	end
	b.disposed = true
	bots[b] = nil
end
function P.list(): { any }
	local list = {}
	for b in bots do
		table.insert(list, b)
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list
end
function P.owner(): Player?
	local list = P.list()
	return list[1] and list[1].owner
end
return P
