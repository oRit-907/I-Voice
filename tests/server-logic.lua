--[[
	Logic tests for the server side radio, phone and megaphone modules.

	Run with: lua5.4 tests/server-logic.lua   (from the repository root)
]]

package.path = 'tests/?.lua;' .. package.path
local stubs = require('fivem_stubs')
stubs.install()

dofile('shared.lua')
dofile('server/main.lua')
dofile('server/module/radio.lua')
dofile('server/module/phone.lua')
dofile('server/module/megaphone.lua')
dofile('server/compat.lua')

local failures = 0
local group = ''

local function describe(name)
	group = name
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

local function countClientEvents(name, target)
	return #stubs.clientEventsNamed(name, target)
end

--#region Radio: joining

describe('radio: joining a channel')
stubs.reset()

stubs.fireNet('ivoice:setPlayerRadio', 1, 100)
check('player 1 is on channel 100', voiceData[1].radio == 100)
check('player 1 got a full sync', countClientEvents('ivoice:syncRadioData', 1) == 1)
check('channel 100 has one member', tableCount(getPlayersInRadioChannel(100)) == 1)

stubs.reset()
stubs.fireNet('ivoice:setPlayerRadio', 2, 100)
check('player 2 joined', voiceData[2].radio == 100)
check('player 1 was told about player 2', countClientEvents('ivoice:addPlayerToRadio', 1) == 1)
check('player 2 was not told about themselves', countClientEvents('ivoice:addPlayerToRadio', 2) == 0)
check('channel 100 has two members', tableCount(getPlayersInRadioChannel(100)) == 2)

local addEvent = stubs.clientEventsNamed('ivoice:addPlayerToRadio', 1)[1]
check('add carries the channel first', addEvent.args[1] == 100)
check('add carries the joining player', addEvent.args[2] == 2)
check('add carries their name', addEvent.args[3] == 'Player2')

--#endregion

--#region Radio: talking

describe('radio: transmitting')
stubs.reset()

stubs.fireNet('ivoice:setTalkingOnRadio', 1, true)
check('player 2 was told player 1 is talking', countClientEvents('ivoice:setTalkingOnRadio', 2) == 1)
check('the speaker was not told about themselves', countClientEvents('ivoice:setTalkingOnRadio', 1) == 0)
check('channel state records the talker', getPlayersInRadioChannel(100)[1] == true)

local talkEvent = stubs.clientEventsNamed('ivoice:setTalkingOnRadio', 2)[1]
check('talk event is (channel, source, talking)', talkEvent.args[1] == 100
	and talkEvent.args[2] == 1 and talkEvent.args[3] == true)

stubs.reset()
stubs.fireNet('ivoice:setTalkingOnRadio', 1, false)
check('stopping talking is broadcast', getPlayersInRadioChannel(100)[1] == false)

--#endregion

--#region Radio: monitoring a second channel

describe('radio: monitoring extra channels')
stubs.reset()

stubs.fireNet('ivoice:setPlayerRadio', 3, 200)
stubs.reset()
stubs.fireNet('ivoice:addSecondaryRadio', 3, 100)

check('player 3 still transmits on 200', voiceData[3].radio == 200)
check('player 3 monitors 100', voiceData[3].secondaryRadios[100] == true)
check('player 3 got a sync for 100', countClientEvents('ivoice:syncRadioData', 3) == 1)
check('players on 100 were told', countClientEvents('ivoice:addPlayerToRadio', 1) == 1)
check('channel 100 now has three members', tableCount(getPlayersInRadioChannel(100)) == 3)

local info = getRadioChannelInfo(100)
check('channel info counts everyone', info.count == 3)
check('channel info flags the monitor', #info.monitoring == 1 and info.monitoring[1] == 3)

stubs.reset()
stubs.fireNet('ivoice:setTalkingOnRadio', 1, true)
check('a monitor still hears the channel', countClientEvents('ivoice:setTalkingOnRadio', 3) == 1)

stubs.reset()
stubs.fireNet('ivoice:setTalkingOnRadio', 3, true)
check('a monitor keys up on their primary, not the monitored channel',
	getPlayersInRadioChannel(200)[3] == true and getPlayersInRadioChannel(100)[3] == false)

-- the monitor limit
stubs.reset()
stubs.convars.voice_maxSecondaryChannels = '1'
stubs.fireNet('ivoice:addSecondaryRadio', 3, 300)
check('a second monitored channel over the limit is refused', voiceData[3].secondaryRadios[300] == nil)
check('the player is told why', countClientEvents('ivoice:radioDenied', 3) == 1)
stubs.convars.voice_maxSecondaryChannels = '3'

-- promoting a monitored channel to primary
stubs.reset()
stubs.fireNet('ivoice:setPlayerRadio', 3, 100)
check('promoting a monitored channel clears the monitor flag', voiceData[3].secondaryRadios[100] == nil)
check('player 3 now transmits on 100', voiceData[3].radio == 100)
check('player 3 left channel 200', tableCount(getPlayersInRadioChannel(200)) == 0)
check('player 3 is only counted once on 100', tableCount(getPlayersInRadioChannel(100)) == 3)

--#endregion

--#region Radio: leaving

describe('radio: leaving')
stubs.reset()

stubs.fireNet('ivoice:setPlayerRadio', 3, 0)
check('player 3 is off the radio', voiceData[3].radio == 0)
check('remaining members were told', countClientEvents('ivoice:removePlayerFromRadio', 1) == 1)
check('channel 100 is back to two members', tableCount(getPlayersInRadioChannel(100)) == 2)

stubs.reset()
stubs.fireEvent('playerDropped', 2)
check('dropping cleans the channel up', tableCount(getPlayersInRadioChannel(100)) == 1)
check('the dropped player has no record', voiceData[2] == nil)

stubs.reset()
stubs.fireNet('ivoice:setPlayerRadio', 1, 0)
check('an emptied channel is discarded', rawget(radioData, 100) == nil)

--#endregion

--#region Radio: access control

describe('radio: access control')
stubs.reset()

stubs.exported.addChannelCheck(500, function(src) return src == 9 end)

stubs.fireNet('ivoice:setPlayerRadio', 8, 500)
check('a failing check keeps the player off', voiceData[8].radio == 0)
check('the player is told they were denied', countClientEvents('ivoice:radioDenied', 8) == 1)
check('the client is forced back off the channel', countClientEvents('ivoice:removePlayerFromRadio', 8) == 1)

stubs.reset()
stubs.fireNet('ivoice:setPlayerRadio', 9, 500)
check('a passing check lets the player on', voiceData[9].radio == 500)

stubs.reset()
stubs.exported.setChannelLimit(600, 1)
stubs.fireNet('ivoice:setPlayerRadio', 10, 600)
stubs.fireNet('ivoice:setPlayerRadio', 11, 600)
check('the first player fits under the limit', voiceData[10].radio == 600)
check('the second is refused', voiceData[11].radio == 0)

stubs.reset()
stubs.exported.addChannelCheck(700, function() error('boom') end)
stubs.fireNet('ivoice:setPlayerRadio', 12, 700)
check('a check that errors denies rather than crashes', voiceData[12].radio == 0)

--#endregion

--#region Phone

describe('phone')
stubs.reset()

stubs.fireNet('ivoice:setPlayerCall', 20, 55)
stubs.fireNet('ivoice:setPlayerCall', 21, 55)
check('both players are on call 55', voiceData[20].call == 55 and voiceData[21].call == 55)
check('the existing member was told', countClientEvents('ivoice:addPlayerToCall', 20) == 1)

stubs.reset()
stubs.fireNet('ivoice:setTalkingOnCall', 20, true)
check('the other party hears about it', countClientEvents('ivoice:setTalkingOnCall', 21) == 1)

stubs.reset()
stubs.fireNet('ivoice:setPlayerCall', 20, 0)
check('hanging up clears the channel', voiceData[20].call == 0)
check('the other party was told', countClientEvents('ivoice:removePlayerFromCall', 21) == 1)

--#endregion

--#region Megaphone

describe('megaphone')
stubs.reset()

stubs.fireNet('ivoice:setMegaphoneState', 30, true)
check('the state is recorded', voiceData[30].megaphone == true)
check('every client is told', countClientEvents('ivoice:setMegaphoneState', -1) == 1)
check('the state bag is replicated', stubs.playerStates[30].state.megaphoneActive == true)

stubs.reset()
stubs.fireNet('ivoice:setMegaphoneState', 30, true)
check('raising it twice does not re-broadcast', countClientEvents('ivoice:setMegaphoneState', -1) == 0)

stubs.reset()
stubs.fireEvent('playerDropped', 30)
check('dropping lowers the megaphone', countClientEvents('ivoice:setMegaphoneState', -1) == 1)
check('the megaphone list is cleared', #stubs.exported.getMegaphoneUsers() == 0)

--#endregion

--#region Resync

describe('resync after a mumble reconnect')
stubs.reset()

stubs.fireNet('ivoice:setPlayerRadio', 40, 800)
stubs.fireNet('ivoice:addSecondaryRadio', 40, 801)
stubs.fireNet('ivoice:setPlayerCall', 40, 802)
stubs.reset()

stubs.fireNet('ivoice:requestSync', 40)
check('megaphones are replayed', countClientEvents('ivoice:syncMegaphones', 40) == 1)
check('both radio channels are replayed', countClientEvents('ivoice:syncRadioData', 40) == 2)
check('the call is replayed', countClientEvents('ivoice:syncCallData', 40) == 1)

--#endregion

--#region pma-voice compatibility

describe('pma-voice compatibility')
stubs.reset()

-- the legacy net events must reach the same handlers as the ivoice: ones
stubs.fireNet('pma-voice:setPlayerRadio', 50, 900)
check('legacy setPlayerRadio joins the channel', voiceData[50].radio == 900)

stubs.fireNet('pma-voice:setPlayerRadio', 51, 900)
stubs.reset()
stubs.fireNet('pma-voice:setTalkingOnRadio', 50, true)
check('legacy setTalkingOnRadio broadcasts', countClientEvents('ivoice:setTalkingOnRadio', 51) == 1)
check('legacy setTalkingOnRadio records state', getPlayersInRadioChannel(900)[50] == true)

stubs.reset()
stubs.fireNet('pma-voice:setPlayerCall', 50, 901)
stubs.fireNet('pma-voice:setPlayerCall', 51, 901)
check('legacy setPlayerCall joins the call', voiceData[50].call == 901)

stubs.reset()
stubs.fireNet('pma-voice:setTalkingOnCall', 50, true)
check('legacy setTalkingOnCall broadcasts', countClientEvents('ivoice:setTalkingOnCall', 51) == 1)

-- each legacy net event must be registered exactly once, or handlers run twice
for _, name in ipairs({
	'pma-voice:setPlayerRadio',
	'pma-voice:setPlayerCall',
	'pma-voice:setTalkingOnRadio',
	'pma-voice:setTalkingOnCall',
}) do
	check(('%s is registered'):format(name), stubs.netEvents[name] ~= nil)
end

stubs.reset()
stubs.fireNet('ivoice:setPlayerRadio', 52, 902)
check('the ivoice: name is not double-registered', voiceData[52].radio == 902
	and countClientEvents('ivoice:syncRadioData', 52) == 1)

-- events raised by I-Voice are mirrored under their old names
stubs.reset()
TriggerEvent('ivoice:playerMuted', 60, 1, true, 300)
local mirrored = 0
for _, event in ipairs(stubs.serverEvents) do
	if event.name == 'pma-voice:playerMuted' then
		mirrored = mirrored + 1
		check('the mirrored payload is unchanged', event.args[1] == 60 and event.args[2] == 1
			and event.args[3] == true and event.args[4] == 300)
	end
end
check('playerMuted is mirrored exactly once', mirrored == 1)

-- overrideRadioNameGetter has to accept both pma-voice's (channel, cb) and (cb)
stubs.reset()
stubs.exported.overrideRadioNameGetter(1, function(src) return 'Legacy' .. src end)
stubs.fireNet('ivoice:setPlayerRadio', 61, 903)
stubs.fireNet('ivoice:setPlayerRadio', 62, 903)
local named = stubs.clientEventsNamed('ivoice:addPlayerToRadio', 61)[1]
check('the legacy (channel, cb) signature is honoured', named.args[3] == 'Legacy62')

stubs.exported.overrideRadioNameGetter(function(src) return 'Modern' .. src end)
stubs.reset()
stubs.fireNet('ivoice:setPlayerRadio', 63, 903)
named = stubs.clientEventsNamed('ivoice:addPlayerToRadio', 61)[1]
check('the single-argument signature still works', named.args[3] == 'Modern63')
stubs.exported.resetRadioNameGetter()

-- the compat mode probe
describe('pma-voice compatibility: mode detection')
stubs.resourceStates = {}
check('no shim and a different name reports events-only', getPmaVoiceCompatMode() == 'events-only')

stubs.resourceStates['pma-voice'] = 'started'
check('a running shim is detected', getPmaVoiceCompatMode() == 'shim')

--#endregion

print('')
if failures == 0 then
	print('All server logic checks passed.')
	os.exit(0)
else
	print(('%s check(s) failed.'):format(failures))
	os.exit(1)
end
