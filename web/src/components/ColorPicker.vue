<script setup lang="ts">
import { computed, ref, watch } from 'vue'

const model = defineModel<string>({ required: true })

const h = ref(0)
const s = ref(0)
const v = ref(0)
let lastEmitted = ''

function hexToHsv(value: string): [number, number, number] | null {
  const m = /^#?([0-9a-f]{6})$/i.exec(value.trim())
  if (!m) return null
  const n = parseInt(m[1], 16)
  const [r, g, b] = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map((c) => c / 255)
  const max = Math.max(r, g, b)
  const d = max - Math.min(r, g, b)
  let hue = 0
  if (d) hue = max === r ? (g - b) / d + (g < b ? 6 : 0) : max === g ? (b - r) / d + 2 : (r - g) / d + 4
  return [hue * 60, max ? d / max : 0, max]
}

function hsvToHex(hue: number, sat: number, val: number) {
  const f = (n: number) => {
    const k = (n + hue / 60) % 6
    return val - val * sat * Math.max(0, Math.min(k, 4 - k, 1))
  }
  return '#' + [f(5), f(3), f(1)].map((x) => Math.round(x * 255).toString(16).padStart(2, '0')).join('')
}

const draft = ref('')
const invalid = ref(false)

function syncFrom(hex: string) {
  const hsv = hexToHsv(hex)
  if (hsv) [h.value, s.value, v.value] = hsv
  draft.value = hex.replace('#', '').toUpperCase()
}

watch(
  model,
  (hex) => {
    if (hex !== lastEmitted) syncFrom(hex)
  },
  { immediate: true },
)

function emit() {
  lastEmitted = hsvToHex(h.value, s.value, v.value)
  model.value = lastEmitted
  draft.value = lastEmitted.slice(1).toUpperCase()
  invalid.value = false
}

const area = ref<HTMLElement | null>(null)
const dragging = ref(false)
const clamp = (x: number) => Math.min(1, Math.max(0, x))

function fromPointer(e: PointerEvent) {
  const r = area.value!.getBoundingClientRect()
  s.value = clamp((e.clientX - r.left) / r.width)
  v.value = 1 - clamp((e.clientY - r.top) / r.height)
  emit()
}

function onDown(e: PointerEvent) {
  e.preventDefault()
  area.value?.focus()
  area.value?.setPointerCapture(e.pointerId)
  dragging.value = true
  fromPointer(e)
}

function onMove(e: PointerEvent) {
  if (dragging.value) fromPointer(e)
}

function onUp() {
  dragging.value = false
}

function onAreaKey(e: KeyboardEvent) {
  const step = e.shiftKey ? 0.1 : 0.02
  const moves: Record<string, () => void> = {
    ArrowLeft: () => (s.value = clamp(s.value - step)),
    ArrowRight: () => (s.value = clamp(s.value + step)),
    ArrowUp: () => (v.value = clamp(v.value + step)),
    ArrowDown: () => (v.value = clamp(v.value - step)),
  }
  if (!moves[e.key]) return
  e.preventDefault()
  e.stopPropagation()
  moves[e.key]()
  emit()
}

function onHue(e: Event) {
  h.value = Number((e.target as HTMLInputElement).value)
  emit()
}

function onHexInput(e: Event) {
  const el = e.target as HTMLInputElement
  const clean = el.value.replace(/[^0-9a-f]/gi, '').slice(0, 6).toUpperCase()
  el.value = clean
  draft.value = clean
  invalid.value = clean.length !== 6
  if (!invalid.value) {
    const hsv = hexToHsv(clean)
    if (hsv) [h.value, s.value, v.value] = hsv
    lastEmitted = '#' + clean.toLowerCase()
    model.value = lastEmitted
  }
}

function commitHex() {
  if (invalid.value) {
    draft.value = model.value.replace('#', '').toUpperCase()
    invalid.value = false
  }
}

const pureHue = computed(() => `hsl(${Math.round(h.value)}, 100%, 50%)`)
</script>

<template>
  <div class="picker">
    <div
      ref="area"
      class="sv"
      :class="{ dragging }"
      :style="{ '--pure': pureHue }"
      role="slider"
      tabindex="0"
      aria-label="Colour saturation and brightness"
      aria-valuemin="0"
      aria-valuemax="100"
      :aria-valuenow="Math.round(s * 100)"
      :aria-valuetext="`Saturation ${Math.round(s * 100)}%, brightness ${Math.round(v * 100)}%`"
      @pointerdown="onDown"
      @pointermove="onMove"
      @pointerup="onUp"
      @pointercancel="onUp"
      @keydown="onAreaKey"
    >
      <span class="sv-thumb" :style="{ left: s * 100 + '%', top: (1 - v) * 100 + '%', background: model }" />
    </div>

    <input
      class="hue"
      type="range"
      min="0"
      max="359"
      step="1"
      :value="Math.round(h)"
      :style="{ '--thumb': pureHue }"
      aria-label="Hue"
      :aria-valuetext="`Hue ${Math.round(h)} degrees`"
      @input="onHue"
    />

    <div class="hex-row">
      <span class="preview" :style="{ background: model }" aria-hidden="true" />
      <label class="hex" :class="{ invalid }">
        <span class="hash" aria-hidden="true">#</span>
        <input
          :value="draft"
          type="text"
          inputmode="text"
          maxlength="7"
          spellcheck="false"
          autocomplete="off"
          aria-label="Hex colour code"
          :aria-invalid="invalid"
          @input="onHexInput"
          @blur="commitHex"
          @keydown.enter.prevent="commitHex"
        />
      </label>
      <span v-if="invalid" class="hex-hint" role="status">Use 6 characters, 0–9 and A–F</span>
    </div>
  </div>
</template>

<style scoped>
.picker {
  display: flex;
  flex-direction: column;
  gap: 1.4rem;
}

.sv {
  position: relative;
  height: 15rem;
  border-radius: var(--r-md);
  cursor: crosshair;
  touch-action: none;
  background:
    linear-gradient(to top, #000, transparent),
    linear-gradient(to right, #fff, var(--pure));
  box-shadow: inset 0 0 0 0.1rem rgba(255, 255, 255, 0.08);
}

.sv-thumb {
  position: absolute;
  width: 2.2rem;
  height: 2.2rem;
  margin: -1.1rem 0 0 -1.1rem;
  border-radius: 50%;
  border: 0.3rem solid #fff;
  box-shadow:
    0 0 0 0.1rem rgba(0, 0, 0, 0.35),
    0 0.4rem 1.2rem rgba(0, 0, 0, 0.5);
  pointer-events: none;
  transition: transform 0.15s var(--ease-spring);
}

.sv.dragging .sv-thumb {
  transform: scale(1.18);
}

.hue {
  -webkit-appearance: none;
  appearance: none;
  width: 100%;
  height: 2.2rem;
  margin: 0;
  background: transparent;
  cursor: pointer;
}

.hue::-webkit-slider-runnable-track {
  height: 1.2rem;
  border-radius: var(--r-pill);
  background: linear-gradient(to right, #f00 0%, #ff0 17%, #0f0 33%, #0ff 50%, #00f 67%, #f0f 83%, #f00 100%);
  box-shadow: inset 0 0 0 0.1rem rgba(255, 255, 255, 0.1);
}

.hue::-webkit-slider-thumb {
  -webkit-appearance: none;
  width: 2.2rem;
  height: 2.2rem;
  margin-top: -0.5rem;
  border-radius: 50%;
  background: var(--thumb);
  border: 0.3rem solid #fff;
  box-shadow:
    0 0 0 0.1rem rgba(0, 0, 0, 0.35),
    0 0.4rem 1.2rem rgba(0, 0, 0, 0.5);
}

.hue::-moz-range-track {
  height: 1.2rem;
  border-radius: var(--r-pill);
  background: linear-gradient(to right, #f00 0%, #ff0 17%, #0f0 33%, #0ff 50%, #00f 67%, #f0f 83%, #f00 100%);
}

.hue::-moz-range-thumb {
  width: 1.6rem;
  height: 1.6rem;
  border-radius: 50%;
  background: var(--thumb);
  border: 0.3rem solid #fff;
}

.hue:focus-visible {
  outline-offset: 0.3rem;
  border-radius: var(--r-pill);
}

.hex-row {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.preview {
  width: 3.8rem;
  height: 3.8rem;
  border-radius: 50%;
  flex-shrink: 0;
  box-shadow:
    inset 0 0 0 0.1rem rgba(255, 255, 255, 0.15),
    0 0.6rem 1.6rem -0.6rem rgba(0, 0, 0, 0.6);
}

.hex {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  height: 3.8rem;
  width: 13rem;
  padding: 0 1.3rem;
  border-radius: var(--r-pill);
  background: var(--fill-2);
  border: 0.1rem solid var(--line-2);
  transition:
    border-color 0.16s var(--ease),
    box-shadow 0.16s var(--ease);
}

.hex:focus-within {
  border-color: var(--accent-line);
  box-shadow: 0 0 0 0.3rem var(--accent-soft);
}

.hex.invalid {
  border-color: rgba(255, 123, 123, 0.6);
}

.hash {
  font-size: 1.4rem;
  font-weight: 700;
  color: var(--text-faint);
}

.hex input {
  flex: 1;
  min-width: 0;
  background: transparent;
  border: none;
  outline: none;
  color: var(--text-h);
  font-size: 1.4rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  font-variant-numeric: tabular-nums;
}

.hex-hint {
  font-size: 1.2rem;
  color: var(--danger);
}
</style>
