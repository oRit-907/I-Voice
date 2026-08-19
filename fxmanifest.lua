game 'common'

fx_version 'cerulean'
name 'I-Voice'
author 'AvarianKnight'
description 'VOIP built using FiveM\'s built in mumble.'
version '2.0.0'

dependencies {
	'/onesync',
}

lua54 'yes'

shared_script 'shared.lua'

client_scripts {
	'client/utils/*.lua',
	-- settings seed the volume table, so they have to land before main
	'client/init/settings.lua',
	'client/init/ui.lua',
	'client/init/proximity.lua',
	'client/init/main.lua',
	'client/init/init.lua',
	'client/module/*.lua',
	'client/*.lua',
}

server_scripts {
	'server/main.lua',
	'server/module/*.lua',
	'server/*.js',
}

files {
	'ui/*.ogg',
	-- the Vite build inlines the stylesheet into the bundle, but the glob stays
	-- so a config that splits it back out keeps working
	'ui/css/*.css',
	'ui/js/*.js',
	'ui/index.html',
}

ui_page 'ui/index.html'

provides {
	'mumble-voip',
	'tokovoip',
	'toko-voip',
	'tokovoip_script',
	'pma-voice',
}

convar_category 'I-Voice' {
	'I-Voice Configuration Options',
	{
		{ 'Use native audio', '$voice_useNativeAudio', 'CV_BOOL', 'false' },
		{ 'Use 2D audio', '$voice_use2dAudio', 'CV_BOOL', 'false' },
		{ 'Use sending range only', '$voice_useSendingRangeOnly', 'CV_BOOL', 'false' },
		{ 'Enable UI', '$voice_enableUi', 'CV_INT', '1' },
		{ 'Enable F11 proximity key', '$voice_enableProximityCycle', 'CV_INT', '1' },
		{ 'Proximity cycle key', '$voice_defaultCycle', 'CV_STRING', 'F11' },
		{ 'Default voice mode', '$voice_defaultVoiceMode', 'CV_INT', '2' },
		{ 'Voice radio volume', '$voice_defaultRadioVolume', 'CV_INT', '30' },
		{ 'Voice phone volume', '$voice_defaultPhoneVolume', 'CV_INT', '60' },
		{ 'Voice megaphone volume', '$voice_defaultMegaphoneVolume', 'CV_INT', '80' },
		{ 'Enable radios', '$voice_enableRadios', 'CV_INT', '1' },
		{ 'Enable phones', '$voice_enablePhones', 'CV_INT', '1' },
		{ 'Enable megaphones', '$voice_enableMegaphone', 'CV_INT', '1' },
		{ 'Megaphone range', '$voice_megaphoneRange', 'CV_INT', '40' },
		{ 'Megaphone key', '$voice_defaultMegaphone', 'CV_STRING', 'CAPITAL' },
		{ 'Max monitored radio channels', '$voice_maxSecondaryChannels', 'CV_INT', '3' },
		{ 'Sync player names on the radio', '$voice_syncPlayerNames', 'CV_INT', '0' },
		{ 'Enable submix', '$voice_enableSubmix', 'CV_INT', '1' },
		{ 'Enable radio animation', '$voice_enableRadioAnim', 'CV_INT', '0' },
		{ 'Disable the radio animation in vehicles', '$voice_disableVehicleRadioAnim', 'CV_INT', '0' },
		{ 'Radio key', '$voice_defaultRadio', 'CV_STRING', 'LMENU' },
		{ 'Voice settings key', '$voice_defaultSettingsKey', 'CV_STRING', '' },
		{ 'UI refresh rate', '$voice_uiRefreshRate', 'CV_INT', '200' },
		{ 'Allow players to set audio intent', '$voice_allowSetIntent', 'CV_INT', '1' },
		{ 'External mumble server address', '$voice_externalAddress', 'CV_STRING', '' },
		{ 'External mumble server port', '$voice_externalPort', 'CV_INT', '0' },
		{ 'Voice debug mode', '$voice_debugMode', 'CV_INT', '0' },
		{ 'Disable players being allowed to join', '$voice_externalDisallowJoin', 'CV_INT', '0' },
		{ 'Hide server endpoints in logs', '$voice_hideEndpoints', 'CV_INT', '1' },
	}
}
