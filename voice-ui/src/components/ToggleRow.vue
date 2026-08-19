<template>
	<label class="toggle-row">
		<span>{{ label }}</span>
		<span class="switch" :class="{ on: value }">
			<input
				type="checkbox"
				:checked="value"
				@change="$emit('input', $event.target.checked)"
			/>
			<span class="knob"></span>
		</span>
	</label>
</template>

<script setup>
defineProps({
	label: { type: String, required: true },
	value: { type: Boolean, default: false },
})

defineEmits(['input'])
</script>

<style scoped>
.toggle-row {
	display: flex;
	align-items: center;
	justify-content: space-between;
	gap: 10px;
	padding: 5px 0;
	cursor: pointer;
}

.switch {
	position: relative;
	flex: none;
	width: 32px;
	height: 18px;
	border-radius: 9px;
	background: rgba(255, 255, 255, 0.16);
	transition: background 140ms ease;
}

.switch.on {
	background: var(--ivoice-radio);
}

.switch input {
	position: absolute;
	opacity: 0;
	inset: 0;
	margin: 0;
	cursor: pointer;
}

.knob {
	position: absolute;
	top: 3px;
	left: 3px;
	width: 12px;
	height: 12px;
	border-radius: 50%;
	background: #fff;
	transition: transform 140ms ease;
	pointer-events: none;
}

.switch.on .knob {
	transform: translateX(14px);
}
</style>
