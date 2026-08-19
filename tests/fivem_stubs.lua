--[[
	Minimal stand-ins for the FiveM server natives, so the server modules can be
	loaded and driven by a plain Lua interpreter.

	Only what I-Voice actually touches is implemented.
]]

local M = {}

--- Every TriggerClientEvent the code under test made, in order.
M.clientEvents = {}
--- Every TriggerEvent the code under test made, in order.
M.serverEvents = {}
--- Handlers registered through RegisterNetEvent / AddEventHandler.
M.netEvents = {}
M.eventHandlers = {}
--- Everything exported, keyed by name.
M.exported = {}
--- Player state bags, keyed by server id.
M.playerStates = {}

M.convars = {
	voice_enableRadios = '1',
	voice_enablePhones = '1',
	voice_enableMegaphone = '1',
	voice_debugMode = '0',
	voice_syncPlayerNames = '1',
	voice_maxSecondaryChannels = '3',
	voice_defaultRadioVolume = '30',
	voice_defaultPhoneVolume = '60',
	voice_defaultMegaphoneVolume = '80',
	gamename = 'fivem',
}

function M.reset()
	M.clientEvents = {}
	M.serverEvents = {}
end

--- All client events of a given name, optionally filtered by target.
function M.clientEventsNamed(name, target)
	local found = {}
	for _, event in ipairs(M.clientEvents) do
		if event.name == name and (target == nil or event.target == target) then
			found[#found + 1] = event
		end
	end
	return found
end

function M.install()
	_G.IsDuplicityVersion = function() return true end
	_G.GetGameName = function() return 'fivem' end
	_G.GetCurrentResourceName = function() return 'i-voice' end
	_G.GetInvokingResource = function() return nil end

	_G.GetConvar = function(name, default)
		local value = M.convars[name]
		if value == nil then return default end
		return value
	end

	_G.GetConvarInt = function(name, default)
		local value = tonumber(M.convars[name])
		if value == nil then return default end
		return value
	end

	_G.SetConvarReplicated = function(name, value)
		M.convars[name] = tostring(value)
	end

	_G.GetPlayers = function() return {} end
	_G.GetPlayerName = function(src) return ('Player%s'):format(src) end

	local stateMeta = {}
	stateMeta.__index = function(tbl, key)
		return rawget(tbl, '__values')[key]
	end
	stateMeta.__newindex = function(tbl, key, value)
		rawget(tbl, '__values')[key] = value
	end

	_G.Player = function(src)
		if not M.playerStates[src] then
			local state = setmetatable({ __values = {} }, stateMeta)
			rawset(state, 'set', function(self, key, value)
				rawget(self, '__values')[key] = value
			end)
			M.playerStates[src] = { state = state }
		end
		return M.playerStates[src]
	end

	_G.Entity = function() return { state = {} } end

	_G.TriggerClientEvent = function(name, target, ...)
		M.clientEvents[#M.clientEvents + 1] = { name = name, target = target, args = { ... } }
	end

	_G.TriggerEvent = function(name, ...)
		M.serverEvents[#M.serverEvents + 1] = { name = name, args = { ... } }
		for _, handler in ipairs(M.eventHandlers[name] or {}) do
			handler(...)
		end
	end

	_G.RegisterNetEvent = function(name, cb)
		if cb then
			M.netEvents[name] = cb
		end
	end

	_G.AddEventHandler = function(name, cb)
		M.eventHandlers[name] = M.eventHandlers[name] or {}
		table.insert(M.eventHandlers[name], cb)
	end

	_G.exports = setmetatable({}, {
		__call = function(_, name, fn)
			M.exported[name] = fn
		end,
	})

	local noop = function() end
	_G.Wait = noop
	_G.CreateThread = noop
	_G.SetTimeout = noop
	_G.Citizen = { CreateThread = noop, Wait = noop, Await = noop }
	_G.promise = { new = function() return {} end }
end

--- Fires a registered net event as if `src` had sent it.
function M.fireNet(name, src, ...)
	local handler = M.netEvents[name]
	if not handler then
		error(('no net event registered for %s'):format(name))
	end
	_G.source = src
	local results = { handler(...) }
	_G.source = nil
	return table.unpack(results)
end

--- Fires every handler registered for a plain event, with `source` set.
function M.fireEvent(name, src, ...)
	_G.source = src
	for _, handler in ipairs(M.eventHandlers[name] or {}) do
		handler(...)
	end
	_G.source = nil
end

return M
