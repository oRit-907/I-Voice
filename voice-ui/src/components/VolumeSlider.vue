<template>
	<label class="slider-row">
		<span class="name">{{ label }}</span>
		<input
			type="range"
			:min="min"
			:max="max"
			step="1"
			:value="value"
			@input="$emit('input', Number($event.target.value))"
		/>
		<span class="value">{{ value }}{{ unit }}</span>
	</label>
</template>

<script setup>
defineProps({
	label: { type: String, required: true },
	value: { type: Number, default: 0 },
	min: { type: Number, default: 0 },
	max: { type: Number, default: 100 },
	unit: { type: String, default: '%' },
})

defineEmits(['input'])
</script>

<style scoped>
.slider-row {
	display: grid;
	grid-template-columns: 78px 1fr 38px;
	align-items: center;
	gap: 10px;
	padding: 5px 0;
}

.name {
	white-space: nowrap;
}

.value {
	text-align: right;
	font-variant-numeric: tabular-nums;
	color: rgba(235, 238, 242, 0.55);
}

input[type='range'] {
	-webkit-appearance: none;
	appearance: none;
	width: 100%;
	height: 4px;
	border-radius: 2px;
	background: rgba(255, 255, 255, 0.16);
	cursor: pointer;
}

input[type='range']::-webkit-slider-thumb {
	-webkit-appearance: none;
	appearance: none;
	width: 12px;
	height: 12px;
	border-radius: 50%;
	background: var(--ivoice-radio);
	border: 0;
}
</style>
