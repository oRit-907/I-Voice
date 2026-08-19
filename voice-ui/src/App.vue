<template>
	<audio id="audio_on" src="mic_click_on.ogg" preload="auto"></audio>
	<audio id="audio_off" src="mic_click_off.ogg" preload="auto"></audio>

	<VoiceOverlay v-if="voice.uiEnabled" />
	<SettingsPanel v-if="voice.settingsOpen" />
</template>

<script setup>
import { onMounted, onBeforeUnmount } from 'vue'
import { voice, applyMessage } from './state.js'
import { post } from './nui.js'
import VoiceOverlay from './components/VoiceOverlay.vue'
import SettingsPanel from './components/SettingsPanel.vue'

function onMessage(event) {
	if (!event.data || typeof event.data !== 'object') return
	applyMessage(event.data)
}

function onKeyDown(event) {
	if (event.key === 'Escape' && voice.settingsOpen) {
		post('closeSettings')
	}
}

onMounted(() => {
	window.addEventListener('message', onMessage)
	window.addEventListener('keydown', onKeyDown)
	post('uiReady')
})

onBeforeUnmount(() => {
	window.removeEventListener('message', onMessage)
	window.removeEventListener('keydown', onKeyDown)
})
</script>
