--[[
	Server half of the shim.

	Callbacks handed to `addChannelCheck` and `overrideRadioNameGetter` pass
	straight through: the function reference still belongs to the resource that
	created it, so I-Voice's cleanup on resource stop keeps working.
]]

forwardExports({
	-- pma-voice's server surface
	'setPlayerRadio',
	'setPlayerCall',
	'addChannelCheck',
	'overrideRadioNameGetter',
	'getPlayersInRadioChannel',
	'GetPlayersInRadioChannel',
	'isValidPlayer',

	-- I-Voice additions
	'addPlayerSecondaryRadio',
	'removePlayerSecondaryRadio',
	'removeChannelCheck',
	'setChannelLimit',
	'resetRadioNameGetter',
	'getRadioChannelInfo',
	'getActiveRadioChannels',
	'getPlayersInCall',
	'setMegaphoneState',
	'isPlayerUsingMegaphone',
	'getMegaphoneUsers',
	'setPlayerMuted',
	'isPlayerMuted',
})

CreateThread(function()
	Wait(2000)

	local resource = getVoiceResource()
	if resource then
		print(("[pma-voice compat] Forwarding the pma-voice export namespace to '%s'."):format(resource))
	else
		print(
			'[^3WARNING^7] [pma-voice compat] Could not find a running I-Voice resource. '
				.. "Start it, or set 'voice_resourceName' to its folder name."
		)
	end
end)
