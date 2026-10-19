--!strict
-- Minimal synchronous signal. Handlers run in connection order; an erroring handler is
-- reported and does not stop the others.

export type Connection = { Disconnect: (self: Connection) -> () }
export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local handlers: { (T...) -> () } = {}
	local self = {}

	function self.Connect(_, handler: (T...) -> ()): Connection
		table.insert(handlers, handler)
		local connection = {}
		function connection.Disconnect()
			local index = table.find(handlers, handler)
			if index then
				table.remove(handlers, index)
			end
		end
		return connection :: any
	end

	function self.Fire(_, ...: T...)
		for _, handler in table.clone(handlers) do
			local ok, err = pcall(handler :: any, ...)
			if not ok then
				warn(`Signal handler error: {err}`)
			end
		end
	end

	return self :: any
end

return Signal
