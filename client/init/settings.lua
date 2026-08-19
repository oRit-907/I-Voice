--[[
	Client settings store.

	Everything the player can tweak lives here and is persisted to the game's
	KVP store, so preferences survive a reconnect (and follow them between
	servers running I-Voice).
]]

local KVP_PREFIX = 'ivoice:'
local LEGACY_MIC_CLICK_KEY = 'pma-voice_enableMicClicks'

--- Definition of every persisted setting: its default and how to coerce the
--- stored string back into a usable value.
local schema = {
	micClicks = { default = function() return true end, kind = 'boolean' },
	radioVolume = { default = function() return GetConvarInt('voice_defaultRadioVolume', 30) end, kind = 'number' },
	callVolume = { default = function() return GetConvarInt('voice_defaultPhoneVolume', 60) end, kind = 'number' },
	megaphoneVolume = { default = function() return GetConvarInt('voice_defaultMegaphoneVolume', 80) end, kind = 'number' },
	uiEnabled = { default = function() return GetConvarInt('voice_enableUi', 1) == 1 end, kind = 'boolean' },
	uiScale = { default = function() return 100 end, kind = 'number' },
	uiPosition = { default = function() return 'bottom-right' end, kind = 'string' },
	showTalkerList = { default = function() return true end, kind = 'boolean' },
	radioAnim = { default = function() return true end, kind = 'boolean' },
}

local settings = {}
local listeners = {}

local function decode(kind, raw)
	if raw == nil then return nil end
	if kind == 'boolean' then
		if raw == 'true' then return true end
		if raw == 'false' then return false end
		return nil
	elseif kind == 'number' then
		return tonumber(raw)
	end
	return raw
end

--- Reads every setting out of KVP, falling back to the convar-driven default
--- whenever a key is missing or was corrupted by another resource.
local function load()
	local wasDefaulted = {}

	for key, def in pairs(schema) do
		local value
		local ok, raw = pcall(GetResourceKvpString, KVP_PREFIX .. key)
		if ok then
			value = decode(def.kind, raw)
		end

		if value == nil then
			value = def.default()
			wasDefaulted[key] = true
			SetResourceKvp(KVP_PREFIX .. key, tostring(value))
		end

		settings[key] = value
	end

	-- Carry over the mic click preference from pma-voice so upgrading servers
	-- don't reset their players' choice. Only do so when we haven't already got
	-- an I-Voice preference stored, otherwise the old key would win forever.
	local ok, legacy = pcall(GetResourceKvpString, LEGACY_MIC_CLICK_KEY)
	if ok and (legacy == 'true' or legacy == 'false') then
		if wasDefaulted.micClicks then
			settings.micClicks = legacy == 'true'
			SetResourceKvp(KVP_PREFIX .. 'micClicks', legacy)
			logger.info('Adopted the pma-voice mic click preference (%s)', legacy)
		end
		-- The legacy key is left in place and kept in step by client/compat.lua,
		-- so a player who goes back to a pma-voice server keeps their choice.
	end
end

load()

--- Reads a setting.
--- @param key string
function getSetting(key)
	return settings[key]
end

--- Writes a setting, persists it and notifies anything watching that key.
--- @param key string one of the keys declared in `schema`
--- @param value any the new value, coerced to the schema's declared kind
function setSetting(key, value)
	local def = schema[key]
	if not def then
		return logger.warn('Tried to set unknown setting "%s"', tostring(key))
	end

	if def.kind == 'boolean' then
		value = value == true or value == 'true'
	elseif def.kind == 'number' then
		value = tonumber(value)
		if not value then
			return logger.warn('Setting "%s" expected a number, got %s', key, type(value))
		end
	else
		value = tostring(value)
	end

	if settings[key] == value then return end

	settings[key] = value
	SetResourceKvp(KVP_PREFIX .. key, tostring(value))

	local watchers = listeners[key]
	if watchers then
		for i = 1, #watchers do
			watchers[i](value)
		end
	end

	TriggerEvent('ivoice:settingChanged', key, value)
end

--- Registers a callback fired whenever `key` changes.
--- @param key string
--- @param cb function
function onSettingChanged(key, cb)
	listeners[key] = listeners[key] or {}
	table.insert(listeners[key], cb)
end

--- Returns a shallow copy of every setting, for handing to the UI.
function getSettings()
	local copy = {}
	for key, value in pairs(settings) do
		copy[key] = value
	end
	return copy
end

--- Restores every setting to its default.
function resetSettings()
	for key, def in pairs(schema) do
		setSetting(key, def.default())
	end
end

exports('getVoiceSetting', getSetting)
exports('setVoiceSetting', setSetting)
exports('getVoiceSettings', getSettings)
