<template>
	<div class="scrim" @mousedown.self="close">
		<section class="panel" role="dialog" aria-label="Voice settings">
			<header>
				<h1>Voice</h1>
				<button class="icon" type="button" aria-label="Close" @click="close">&times;</button>
			</header>

			<div class="body">
				<fieldset>
					<legend>Volume</legend>
					<VolumeSlider
						label="Radio"
						:value="voice.volumes.radio"
						@input="updateSetting('radioVolume', $event)"
					/>
					<VolumeSlider
						label="Phone"
						:value="voice.volumes.phone"
						@input="updateSetting('callVolume', $event)"
					/>
					<VolumeSlider
						v-if="voice.megaphoneEnabled"
						label="Megaphone"
						:value="voice.volumes.megaphone"
						@input="updateSetting('megaphoneVolume', $event)"
					/>
				</fieldset>

				<fieldset>
					<legend>Behaviour</legend>
					<ToggleRow
						label="Radio mic clicks"
						:value="voice.micClicks"
						@input="updateSetting('micClicks', $event)"
					/>
					<ToggleRow
						label="Radio animation"
						:value="voice.radioAnim"
						@input="updateSetting('radioAnim', $event)"
					/>
					<ToggleRow
						label="Show who is talking"
						:value="voice.showTalkerList"
						@input="updateSetting('showTalkerList', $event)"
					/>
					<ToggleRow
						label="Show the overlay"
						:value="voice.uiEnabled"
						@input="updateSetting('uiEnabled', $event)"
					/>
				</fieldset>

				<fieldset>
					<legend>Overlay</legend>
					<label class="row">
						<span>Corner</span>
						<select
							:value="voice.uiPosition"
							@change="updateSetting('uiPosition', $event.target.value)"
						>
							<option value="bottom-right">Bottom right</option>
							<option value="bottom-left">Bottom left</option>
							<option value="top-right">Top right</option>
							<option value="top-left">Top left</option>
						</select>
					</label>
					<VolumeSlider
						label="Scale"
						unit="%"
						:min="75"
						:max="150"
						:value="voice.uiScale"
						@input="updateSetting('uiScale', $event)"
					/>
				</fieldset>

				<fieldset v-if="voice.radioChannels.length">
					<legend>Radio channels</legend>
					<div v-for="channel in voice.radioChannels" :key="channel" class="row list-row">
						<span>
							{{ (channel / 10).toFixed(1) }} MHz
							<em v-if="channel !== voice.radioChannel">monitoring</em>
						</span>
						<button type="button" class="ghost" @click="leaveChannel(channel)">Leave</button>
					</div>
				</fieldset>

				<fieldset>
					<legend>Blocked players</legend>
					<p v-if="!voice.blocked.length" class="empty">
						Nobody blocked. Use <code>/voiceblock [id]</code> to silence someone for
						yourself only.
					</p>
					<template v-else>
						<div v-for="id in voice.blocked" :key="id" class="row list-row">
							<span>Player {{ id }}</span>
							<button type="button" class="ghost" @click="unblock(id)">Unblock</button>
						</div>
						<button type="button" class="ghost wide" @click="clearBlocked">
							Unblock everyone
						</button>
					</template>
				</fieldset>
			</div>

			<footer>
				<button type="button" class="ghost" @click="reset">Reset to defaults</button>
				<button type="button" class="primary" @click="close">Done</button>
			</footer>
		</section>
	</div>
</template>

<script setup>
import { voice, updateSetting } from '../state.js'
import { post } from '../nui.js'
import VolumeSlider from './VolumeSlider.vue'
import ToggleRow from './ToggleRow.vue'

function close() {
	post('closeSettings')
}

function reset() {
	post('resetSettings')
}

function unblock(id) {
	post('unblockPlayer', { id })
}

function clearBlocked() {
	post('clearBlocked')
}

function leaveChannel(channel) {
	post('leaveRadioChannel', { channel })
}
</script>

<style scoped>
.scrim {
	position: fixed;
	inset: 0;
	display: grid;
	place-items: center;
	background: rgba(0, 0, 0, 0.45);
	pointer-events: auto;
	font-size: 13px;
	color: rgba(235, 238, 242, 0.92);
}

.panel {
	width: 340px;
	max-height: 78vh;
	display: flex;
	flex-direction: column;
	background: var(--ivoice-panel);
	border: 1px solid var(--ivoice-panel-border);
	border-radius: 10px;
	box-shadow: 0 18px 50px rgba(0, 0, 0, 0.55);
	overflow: hidden;
}

header {
	display: flex;
	align-items: center;
	justify-content: space-between;
	padding: 12px 14px;
	border-bottom: 1px solid var(--ivoice-panel-border);
}

h1 {
	margin: 0;
	font-size: 14px;
	font-weight: 700;
	letter-spacing: 0.04em;
	text-transform: uppercase;
}

.body {
	padding: 4px 14px 12px;
	overflow-y: auto;
}

fieldset {
	margin: 0;
	padding: 10px 0;
	border: 0;
	border-bottom: 1px solid rgba(255, 255, 255, 0.06);
}

fieldset:last-child {
	border-bottom: 0;
}

legend {
	padding: 0;
	font-size: 11px;
	font-weight: 700;
	letter-spacing: 0.06em;
	text-transform: uppercase;
	color: rgba(235, 238, 242, 0.45);
}

.row {
	display: flex;
	align-items: center;
	justify-content: space-between;
	gap: 10px;
	padding: 5px 0;
}

.list-row em {
	margin-left: 6px;
	font-style: normal;
	font-size: 11px;
	color: rgba(235, 238, 242, 0.42);
}

.empty {
	margin: 6px 0 0;
	font-size: 12px;
	color: rgba(235, 238, 242, 0.5);
}

code {
	padding: 1px 4px;
	border-radius: 3px;
	background: rgba(255, 255, 255, 0.09);
	font-size: 11px;
}

select {
	padding: 3px 6px;
	border-radius: 5px;
	border: 1px solid var(--ivoice-panel-border);
	background: rgba(255, 255, 255, 0.06);
	color: inherit;
	font: inherit;
	cursor: pointer;
}

footer {
	display: flex;
	justify-content: space-between;
	gap: 8px;
	padding: 10px 14px;
	border-top: 1px solid var(--ivoice-panel-border);
}

button {
	font: inherit;
	cursor: pointer;
	border-radius: 6px;
	transition: background 120ms ease, border-color 120ms ease;
}

.ghost {
	padding: 5px 10px;
	border: 1px solid var(--ivoice-panel-border);
	background: transparent;
	color: inherit;
}

.ghost:hover {
	background: rgba(255, 255, 255, 0.08);
}

.ghost.wide {
	width: 100%;
	margin-top: 6px;
}

.primary {
	padding: 5px 14px;
	border: 1px solid transparent;
	background: var(--ivoice-radio);
	color: #0d1211;
	font-weight: 700;
}

.primary:hover {
	filter: brightness(1.08);
}

.icon {
	width: 24px;
	height: 24px;
	border: 0;
	background: transparent;
	color: inherit;
	font-size: 20px;
	line-height: 1;
	opacity: 0.6;
}

.icon:hover {
	opacity: 1;
}
</style>
