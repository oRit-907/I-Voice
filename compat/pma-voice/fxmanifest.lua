game 'common'

fx_version 'cerulean'
name 'pma-voice'
author 'I-Voice'
description 'Compatibility shim: forwards the pma-voice export namespace to I-Voice.'
version '2.0.0'

lua54 'yes'

shared_script 'shared.lua'
client_script 'client.lua'
server_script 'server.lua'

provides {
	'mumble-voip',
	'tokovoip',
	'toko-voip',
	'tokovoip_script',
}
