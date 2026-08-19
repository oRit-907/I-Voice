--[[
	I-Voice — shared runtime
	Loaded on both the client and the server.
]]

Cfg = {}

voiceTarget = 1

gameVersion = GetGameName()

-- these are just here to satisfy linting
if not IsDuplicityVersion() then
	LocalPlayer = LocalPlayer
	playerServerId = GetPlayerServerId(PlayerId())
end
Player = Player
Entity = Entity

--#region Voice modes

if GetConvar('voice_useNativeAudio', 'false') == 'true' then
	-- native audio distance seems to be larger then regular gta units
	Cfg.voiceModes = {
		{ 1.5, 'Whisper' },
		{ 3.0, 'Normal' },
		{ 6.0, 'Shouting' },
	}
else
	Cfg.voiceModes = {
		{ 3.0, 'Whisper' },
		{ 7.0, 'Normal' },
		{ 15.0, 'Shouting' },
	}
end

--- The range a megaphone carries, in the same units as the voice modes above.
Cfg.megaphoneRange = GetConvarInt('voice_megaphoneRange', 40) + 0.0

--#endregion

--#region Logging

local function convarInt(name, default)
	return GetConvarInt(name, default)
end

logger = {
	log = function(message, ...)
		print(select('#', ...) > 0 and (message):format(...) or message)
	end,
	info = function(message, ...)
		if convarInt('voice_debugMode', 0) >= 1 then
			print('[info] ' .. (select('#', ...) > 0 and (message):format(...) or message))
		end
	end,
	warn = function(message, ...)
		print('[^3WARNING^7] ' .. (select('#', ...) > 0 and (message):format(...) or message))
	end,
	error = function(message, ...)
		error(select('#', ...) > 0 and (message):format(...) or message)
	end,
	verbose = function(message, ...)
		if convarInt('voice_debugMode', 0) >= 4 then
			print('[verbose] ' .. (select('#', ...) > 0 and (message):format(...) or message))
		end
	end,
}

function tPrint(tbl, indent)
	indent = indent or 0
	for k, v in pairs(tbl) do
		local tblType = type(v)
		local formatting = string.rep('  ', indent) .. tostring(k) .. ': '

		if tblType == 'table' then
			print(formatting)
			tPrint(v, indent + 1)
		else
			print(formatting .. tostring(v))
		end
	end
end

--#endregion

--#region Type checking

local function types(args)
	local argType = type(args[1])
	for i = 2, #args do
		if argType == args[i] then
			return true, argType
		end
	end
	return false, argType
end

--- Validates argument types.
--- Each vararg is a table of `{ value, "type", "type", ... }`.
--- @usage type_check({channel, "number"}, {name, "string", "nil"})
function type_check(...)
	local vars = { ... }
	for i = 1, #vars do
		local var = vars[i]
		local matchesType, varType = types(var)
		if not matchesType then
			local expected = {}
			for j = 2, #var do
				expected[#expected + 1] = var[j]
			end
			error(('Invalid type sent to argument #%s, expected %s, got %s'):format(i, table.concat(expected, '|'), varType))
		end
	end
end

--#endregion

--#region Misc helpers

--- Returns true when the passed value is a Cfx function reference (a callback
--- passed over the export boundary).
function isFunctionRef(value)
	return type(value) == 'table' and value.__cfx_functionReference ~= nil
end

--- Clamps a number between two bounds.
function clamp(value, min, max)
	if value < min then return min end
	if value > max then return max end
	return value
end

--- Counts the entries of a non sequential table.
function tableCount(tbl)
	local count = 0
	for _ in pairs(tbl) do
		count = count + 1
	end
	return count
end

--#endregion
