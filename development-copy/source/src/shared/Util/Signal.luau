--!strict
-- Minimal script signal for module-to-module events on one side of the network.

local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: (self: Connection) -> (), Connected: boolean }
export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

function Signal.new<T...>(): Signal<T...>
	return (setmetatable({ handlers = {} }, Signal) :: any) :: Signal<T...>
end

function Signal:Connect(fn)
	local handlers = self.handlers
	local connection
	connection = {
		Connected = true,
		Disconnect = function(c)
			if c.Connected then
				c.Connected = false
				local i = table.find(handlers, connection)
				if i then
					table.remove(handlers, i)
				end
			end
		end,
		fn = fn,
	}
	table.insert(handlers, connection)
	return connection
end

function Signal:Once(fn)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function Signal:Fire(...)
	-- Copy so handlers may disconnect while firing
	for _, connection: any in table.clone(self.handlers) do
		if connection.Connected then
			task.spawn(connection.fn, ...)
		end
	end
end

function Signal:DisconnectAll()
	for _, connection: any in self.handlers do
		connection.Connected = false
	end
	table.clear(self.handlers)
end

return Signal
