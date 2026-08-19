import { reactive, computed } from 'vue'
import { post } from './nui.js'

/**
 * An empty Lua table serialises to `{}` rather than `[]`, so anything that is
 * meant to be a list has to be normalised on the way in.
 * @param {unknown} value
 * @returns {any[]}
 */
function toArray(value) {
	if (Array.isArray(value)) return value
	if (value && typeof value === 'object') return Object.values(value)
	return []
}

export const voice = reactive({
	// overlay
	uiEnabled: true,
	uiScale: 100,
	uiPosition: 'bottom-right',
	showTalkerList: true,

	// proximity
	voiceModes: [],
	voiceMode: 0,
	talking: false,

	// radio
	radioEnabled: true,
	radioChannel: 0,
	radioChannels: [],
	radioTalkers: [],
	usingRadio: false,

	// phone
	callInfo: 0,

	// megaphone
	megaphoneEnabled: true,
	usingMegaphone: false,

	// settings panel
	settingsOpen: false,
	micClicks: true,
	radioAnim: true,
	volumes: { radio: 30, phone: 60, megaphone: 80 },
	blocked: [],

	// transient
	notification: null,
})

/** The label of the currently selected proximity mode. */
export const voiceModeLabel = computed(() => {
	const entry = voice.voiceModes[voice.voiceMode]
	return entry ? entry[1] : ''
})

/** The channels being monitored but not transmitted on. */
export const monitoredChannels = computed(() =>
	voice.radioChannels.filter((channel) => channel !== voice.radioChannel)
)

/** True when anything at all should be drawn. */
export const hasOverlayContent = computed(
	() =>
		voice.voiceModes.length > 0 ||
		voice.callInfo !== 0 ||
		voice.radioChannel !== 0 ||
		voice.usingMegaphone
)

let notificationTimer = null

function showNotification(notification) {
	voice.notification = notification
	clearTimeout(notificationTimer)
	notificationTimer = setTimeout(() => {
		voice.notification = null
	}, 4000)
}

function playSound(id, volume) {
	const element = document.getElementById(id)
	if (!element) return

	// Discard the resulting errors: they're usually just an uncaught promise
	// from two clicks landing too close together.
	element.load()
	element.volume = Math.min(Math.max(volume ?? 0.3, 0), 1)
	element.play().catch(() => {})
}

/**
 * Applies one message from the Lua side to the store.
 * @param {Record<string, any>} data
 */
export function applyMessage(data) {
	if (data.uiEnabled !== undefined) voice.uiEnabled = data.uiEnabled
	if (data.uiScale !== undefined) voice.uiScale = data.uiScale
	if (data.uiPosition !== undefined) voice.uiPosition = data.uiPosition
	if (data.showTalkerList !== undefined) voice.showTalkerList = data.showTalkerList
	if (data.micClicks !== undefined) voice.micClicks = data.micClicks
	if (data.radioAnim !== undefined) voice.radioAnim = data.radioAnim

	if (data.voiceModes !== undefined) {
		const modes =
			typeof data.voiceModes === 'string'
				? JSON.parse(data.voiceModes)
				: data.voiceModes
		// The Lua side reports a "Custom" mode as one past the configured list,
		// so it needs an entry to resolve against.
		voice.voiceModes = [...toArray(modes), [0.0, 'Custom']]
	}

	if (data.voiceMode !== undefined) voice.voiceMode = data.voiceMode
	if (data.radioChannel !== undefined) voice.radioChannel = data.radioChannel
	if (data.radioChannels !== undefined) voice.radioChannels = toArray(data.radioChannels)
	if (data.radioTalkers !== undefined) voice.radioTalkers = toArray(data.radioTalkers)
	if (data.radioEnabled !== undefined) voice.radioEnabled = data.radioEnabled
	if (data.callInfo !== undefined) voice.callInfo = data.callInfo

	if (data.megaphoneEnabled !== undefined) voice.megaphoneEnabled = data.megaphoneEnabled
	if (data.usingMegaphone !== undefined) voice.usingMegaphone = data.usingMegaphone

	if (data.usingRadio !== undefined) voice.usingRadio = data.usingRadio

	// Radio transmission takes over the indicator, so don't let the proximity
	// talking state fight it.
	if (data.talking !== undefined && !voice.usingRadio) voice.talking = data.talking

	if (data.volumes !== undefined) voice.volumes = { ...voice.volumes, ...data.volumes }
	if (data.blocked !== undefined) voice.blocked = toArray(data.blocked)
	if (data.settingsOpen !== undefined) voice.settingsOpen = data.settingsOpen
	if (data.notification !== undefined) showNotification(data.notification)

	if (data.sound && voice.radioEnabled && voice.radioChannel !== 0) {
		playSound(data.sound, data.volume)
	}
}

/** Pushes a setting change back to Lua and updates the store optimistically. */
export function updateSetting(key, value) {
	if (key === 'radioVolume') voice.volumes.radio = value
	else if (key === 'callVolume') voice.volumes.phone = value
	else if (key === 'megaphoneVolume') voice.volumes.megaphone = value
	else if (key in voice) voice[key] = value

	post('setSetting', { key, value })
}
