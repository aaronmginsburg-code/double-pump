--!strict
-- Collects connections, instances and cleanup functions so they can all be released at
-- once (on death, respawn, map unload). Prevents event and instance leaks.

local Trove = {}
Trove.__index = Trove

export type Trove = typeof(setmetatable({} :: { items: { any } }, Trove))

function Trove.new(): Trove
	return setmetatable({ items = {} }, Trove)
end

function Trove.add<T>(self: Trove, item: T): T
	table.insert(self.items, item)
	return item
end

function Trove.connect(self: Trove, signal: RBXScriptSignal, fn: (...any) -> ()): RBXScriptConnection
	local connection = signal:Connect(fn)
	table.insert(self.items, connection)
	return connection
end

local function release(item: any)
	local kind = typeof(item)
	if kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		item:Destroy()
	elseif kind == "function" then
		item()
	elseif kind == "thread" then
		pcall(task.cancel, item)
	elseif kind == "table" then
		if item.Destroy then
			item:Destroy()
		elseif item.destroy then
			item:destroy()
		elseif item.Disconnect then
			item:Disconnect()
		end
	end
end

function Trove.clean(self: Trove)
	local items = self.items
	self.items = {}
	for i = #items, 1, -1 do
		release(items[i])
	end
end

Trove.Destroy = Trove.clean

return Trove
