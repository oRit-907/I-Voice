--[[
	Locates the running I-Voice resource.

	The folder can be named anything, so rather than hardcoding it we look for
	the resource whose manifest declares `name 'I-Voice'`. `voice_resourceName`
	short-circuits that if you'd rather be explicit.
]]

local resolved = nil

--- Returns the name of the running I-Voice resource, or nil when it isn't up.
function getVoiceResource()
	if resolved and GetResourceState(resolved) == 'started' then
		return resolved
	end

	local configured = GetConvar('voice_resourceName', '')
	if configured ~= '' and GetResourceState(configured) == 'started' then
		resolved = configured
		return resolved
	end

	for i = 0, GetNumResources() - 1 do
		local resource = GetResourceByFindIndex(i)
		if resource and resource ~= 'pma-voice' and GetResourceState(resource) == 'started' then
			if GetResourceMetadata(resource, 'name', 0) == 'I-Voice' then
				resolved = resource
				return resolved
			end
		end
	end

	return nil
end

--- Builds a forwarding export for every name in `names`.
--- Each shim looks the target up lazily, so start order doesn't matter.
--- @param names table list of export names to forward
function forwardExports(names)
	for i = 1, #names do
		local name = names[i]

		exports(name, function(...)
			local resource = getVoiceResource()
			if not resource then
				print(("[^3WARNING^7] [pma-voice compat] '%s' was called but I-Voice isn't running."):format(name))
				return nil
			end

			-- `exports[res]:fn(a)` desugars to `exports[res].fn(exports[res], a)`,
			-- so the proxy has to be passed through as the receiver.
			local proxy = exports[resource]
			return proxy[name](proxy, ...)
		end)
	end
end
