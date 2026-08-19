--[[
	Tests for the pma-voice export shim in compat/pma-voice.

	The thing most worth pinning down is the calling convention: FiveM's
	`exports[res]:fn(a)` desugars to `exports[res].fn(exports[res], a)`, so a
	forwarder that drops the receiver silently corrupts every argument. The stub
	proxy asserts on that.

	Run with: lua5.4 tests/compat-shim.lua   (from the repository root)
]]

package.path = 'tests/?.lua;' .. package.path
local stubs = require('fivem_stubs')
stubs.install()

local failures = 0

local function describe(name)
	print(name)
end

local function check(name, condition, detail)
	if condition then
		print(('  ok   %s'):format(name))
	else
		failures = failures + 1
		print(('  FAIL %s%s'):format(name, detail and (' — ' .. tostring(detail)) or ''))
	end
end

--- Stands in for a running I-Voice under an arbitrary folder name.
local function installVoiceResource(folderName)
	stubs.resourceList = { 'chat', folderName, 'spawnmanager' }
	stubs.resourceStates = { chat = 'started', spawnmanager = 'started', [folderName] = 'started' }
	stubs.resourceMetadata = {
		chat = { name = 'chat' },
		spawnmanager = { name = 'spawnmanager' },
		[folderName] = { name = 'I-Voice' },
	}
	stubs.remoteExports[folderName] = {
		setRadioChannel = function(channel) return ('radio:%s'):format(channel) end,
		setPlayerRadio = function(src, channel) return ('%s->%s'):format(src, channel) end,
		addChannelCheck = function(channel, cb) return cb ~= nil and channel or nil end,
		getRadioVolume = function() return 0.3 end,
	}
end

--#region Resolution

describe('resolving the I-Voice resource')

installVoiceResource('I-Voice')
dofile('compat/pma-voice/shared.lua')

check('found by manifest name, whatever the folder is called', getVoiceResource() == 'I-Voice')

-- a folder named something else entirely must still resolve
installVoiceResource('my-custom-voice')
stubs.convars.voice_resourceName = nil
-- clear the memoised result by pointing the old name at a stopped state
check('found again after the folder was renamed', getVoiceResource() == 'my-custom-voice')

describe('resolving via the convar')
stubs.convars.voice_resourceName = 'my-custom-voice'
check('the convar short-circuits the scan', getVoiceResource() == 'my-custom-voice')
stubs.convars.voice_resourceName = nil

describe('resolving when I-Voice is not running')
stubs.resourceList = { 'chat' }
stubs.resourceStates = { chat = 'started' }
stubs.resourceMetadata = { chat = { name = 'chat' } }
check('returns nil rather than throwing', getVoiceResource() == nil)

--#endregion

--#region Forwarding

describe('forwarding client exports')
installVoiceResource('I-Voice')
dofile('compat/pma-voice/client.lua')

check('setRadioChannel is exported by the shim', type(stubs.exported.setRadioChannel) == 'function')
check('every pma-voice client export is present',
	stubs.exported.setVoiceProperty and stubs.exported.SetMumbleProperty
		and stubs.exported.SetTokoProperty and stubs.exported.SetRadioChannel
		and stubs.exported.addPlayerToRadio and stubs.exported.removePlayerFromRadio
		and stubs.exported.setCallChannel and stubs.exported.SetCallChannel
		and stubs.exported.addPlayerToCall and stubs.exported.removePlayerFromCall
		and stubs.exported.setRadioVolume and stubs.exported.getRadioVolume
		and stubs.exported.setCallVolume and stubs.exported.getCallVolume
		and stubs.exported.toggleMutePlayer and stubs.exported.toggleRadioAnim
		and stubs.exported.getRadioAnimState and stubs.exported.setAllowProximityCycleState
		and stubs.exported.overrideProximityRange and stubs.exported.clearProximityOverride
		and stubs.exported.overrideProximityCheck and stubs.exported.resetProximityCheck
		and stubs.exported.setVoiceState ~= nil)

stubs.remoteCalls = {}
local result = stubs.exported.setRadioChannel(7)
check('the call reaches I-Voice', #stubs.remoteCalls == 1)
check('arguments arrive intact, not shifted by the receiver',
	stubs.remoteCalls[1].args[1] == 7, tostring(stubs.remoteCalls[1].args[1]))
check('the return value comes back', result == 'radio:7')

stubs.remoteCalls = {}
check('a getter round-trips', stubs.exported.getRadioVolume() == 0.3)

describe('forwarding server exports')
dofile('compat/pma-voice/server.lua')

check('every pma-voice server export is present',
	stubs.exported.setPlayerRadio and stubs.exported.setPlayerCall
		and stubs.exported.addChannelCheck and stubs.exported.overrideRadioNameGetter
		and stubs.exported.getPlayersInRadioChannel and stubs.exported.GetPlayersInRadioChannel
		and stubs.exported.isValidPlayer ~= nil)

stubs.remoteCalls = {}
check('multiple arguments survive', stubs.exported.setPlayerRadio(12, 34) == '12->34')
check('both arguments arrived',
	stubs.remoteCalls[1].args[1] == 12 and stubs.remoteCalls[1].args[2] == 34)

-- callbacks are what addChannelCheck and overrideRadioNameGetter take, so they
-- have to pass through untouched
stubs.remoteCalls = {}
local callback = function() return true end
check('a callback passes through', stubs.exported.addChannelCheck(5, callback) == 5)
check('the callback itself is forwarded', stubs.remoteCalls[1].args[2] == callback)

describe('forwarding when I-Voice is not running')
stubs.resourceList = { 'chat' }
stubs.resourceStates = { chat = 'started' }
stubs.resourceMetadata = { chat = { name = 'chat' } }
stubs.remoteCalls = {}

local ok, err = pcall(stubs.exported.setRadioChannel, 1)
check('the shim warns instead of erroring', ok, err)
check('nothing was forwarded', #stubs.remoteCalls == 0)

--#endregion

print('')
if failures == 0 then
	print('All compat shim checks passed.')
	os.exit(0)
else
	print(('%s check(s) failed.'):format(failures))
	os.exit(1)
end
