<script setup lang="ts">
import { computed } from 'vue'
import { store } from '../../store'
import {
  ACCENT_HUES,
  WIDGET_DEFAULT_POS,
  accentPalette,
  paletteFor,
  resetSettings,
  settings,
  type AccentChoice,
} from '../../settings'
import Modal from '../Modal.vue'
import Toggle from '../Toggle.vue'
import Icon from '../Icon.vue'
import ColorPicker from '../ColorPicker.vue'

const accents: { id: AccentChoice; label: string }[] = [
  { id: 'adaptive', label: 'Adaptive' },
  { id: 'rose', label: 'Rose' },
  { id: 'violet', label: 'Violet' },
  { id: 'sky', label: 'Sky' },
  { id: 'teal', label: 'Teal' },
  { id: 'mint', label: 'Mint' },
  { id: 'amber', label: 'Amber' },
  { id: 'custom', label: 'Custom colour' },
]

const swatch = (id: AccentChoice) => {
  if (id === 'adaptive') return 'conic-gradient(from 200deg, #ff6aa7, #b48cff, #6ab7ff, #4fe0c0, #ffc65a, #ff6aa7)'
  if (id === 'custom') return settings.customAccent
  return accentPalette(ACCENT_HUES[id])['--accent']
}

// What the custom pick actually renders as - a too-dark colour gets lifted for contrast.
const customShown = computed(() => paletteFor(settings.customAccent)['--accent'])
const customAdjusted = computed(() => customShown.value.toLowerCase() !== settings.customAccent.toLowerCase())

// Radio-group keyboard behaviour: arrows move the selection, not just focus.
function onSwatchKey(e: KeyboardEvent, i: number) {
  if (!['ArrowRight', 'ArrowDown', 'ArrowLeft', 'ArrowUp'].includes(e.key)) return
  e.preventDefault()
  const next = (i + (e.key === 'ArrowRight' || e.key === 'ArrowDown' ? 1 : -1) + accents.length) % accents.length
  settings.accent = accents[next].id
  ;((e.currentTarget as HTMLElement).parentElement?.children[next] as HTMLElement | undefined)?.focus()
}

const scalePct = computed(() => Math.round(settings.scale * 100))

function setScale(e: Event) {
  settings.scale = Number((e.target as HTMLInputElement).value) / 100
}

function nudgeScale(delta: number) {
  settings.scale = Math.round(Math.min(1.4, Math.max(0.8, settings.scale + delta)) * 100) / 100
}
</script>

<template>
  <Modal title="Settings" subtitle="Saved on this computer." icon="settings" :width="520" @close="store.state.settingsOpen = false">
    <div class="settings">
      <section aria-labelledby="s-look">
        <h3 id="s-look" class="eyebrow">Appearance</h3>

        <div class="setting">
          <div class="s-label">
            <span id="accent-label">Accent colour</span>
            <span class="s-desc">Adaptive picks up the colour of whatever’s playing, or choose your own.</span>
          </div>
          <div class="swatches" role="radiogroup" aria-labelledby="accent-label">
            <button
              v-for="(a, i) in accents"
              :key="a.id"
              class="swatch"
              :class="{ custom: a.id === 'custom' }"
              role="radio"
              :aria-checked="settings.accent === a.id"
              :aria-label="a.label"
              :title="a.label"
              :tabindex="settings.accent === a.id ? 0 : -1"
              :style="{ background: swatch(a.id) }"
              @click="settings.accent = a.id"
              @keydown="onSwatchKey($event, i)"
            >
              <span v-if="settings.accent === a.id" class="mark"><Icon name="check" :size="12" /></span>
              <span v-else-if="a.id === 'custom'" class="mark"><Icon name="droplet" :size="12" /></span>
            </button>
          </div>

          <Transition name="reveal">
            <div v-if="settings.accent === 'custom'" class="custom-panel">
              <ColorPicker v-model="settings.customAccent" />
              <p v-if="customAdjusted" class="adjusted">
                <span class="mini" :style="{ background: customShown }" aria-hidden="true" />
                Shown a little lighter so text on it stays readable.
              </p>
            </div>
          </Transition>
        </div>

        <div class="setting">
          <div class="s-label">
            <label for="ui-scale">Interface size</label>
            <span class="s-desc">Scales text and controls. Already adjusted for your resolution.</span>
          </div>
          <div class="scale-row">
            <button class="icon-btn sm" aria-label="Smaller" :disabled="settings.scale <= 0.8" @click="nudgeScale(-0.05)">
              <Icon name="minus" :size="15" />
            </button>
            <input
              id="ui-scale"
              class="range"
              type="range"
              min="80"
              max="140"
              step="5"
              :value="scalePct"
              :style="{ '--pct': ((scalePct - 80) / 60) * 100 + '%' }"
              :aria-valuetext="`${scalePct}%`"
              @change="setScale"
            />
            <button class="icon-btn sm" aria-label="Larger" :disabled="settings.scale >= 1.4" @click="nudgeScale(0.05)">
              <Icon name="plus" :size="15" />
            </button>
            <output for="ui-scale" class="scale-val">{{ scalePct }}%</output>
          </div>
        </div>

        <div class="setting">
          <div class="s-label">
            <span id="density-label">List density</span>
          </div>
          <div class="segmented" role="radiogroup" aria-labelledby="density-label">
            <button
              class="chip"
              role="radio"
              :aria-checked="settings.density === 'comfortable'"
              @click="settings.density = 'comfortable'"
            >
              Comfortable
            </button>
            <button class="chip" role="radio" :aria-checked="settings.density === 'compact'" @click="settings.density = 'compact'">
              Compact
            </button>
          </div>
        </div>
      </section>

      <section aria-labelledby="s-a11y">
        <h3 id="s-a11y" class="eyebrow">Accessibility</h3>
        <Toggle
          v-model="settings.highContrast"
          icon="contrast"
          label="High contrast"
          description="Solid panels, brighter text and stronger outlines."
        />
        <Toggle
          v-model="settings.reduceMotion"
          icon="activity"
          label="Reduce motion"
          description="Turns off animations, the spinning record and colour fades."
        />
      </section>

      <section aria-labelledby="s-player">
        <h3 id="s-player" class="eyebrow">Player</h3>
        <Toggle
          v-model="settings.nowPlayingPanel"
          icon="panel-right"
          label="Now playing panel"
          description="Big artwork and what’s up next, on the right."
        />
        <Toggle
          v-model="settings.ambient"
          icon="sparkles"
          label="Ambient artwork glow"
          description="Soft blurred artwork behind the now playing panel."
        />
        <Toggle v-model="settings.showRemaining" icon="clock" label="Show time remaining" description="Instead of total song length." />
      </section>

      <section aria-labelledby="s-widget">
        <h3 id="s-widget" class="eyebrow">Nearby now playing</h3>
        <p v-if="!store.state.widgetServerEnabled" class="server-off">
          <Icon name="alert" :size="14" /> This server has turned the widget off.
        </p>
        <template v-else>
          <Toggle
            v-model="settings.widget"
            icon="widget"
            label="Show nearby now playing"
            :description="`A small card with the song when you’re near a DJ booth or inside its room. /${store.state.widgetCommand} toggles it too.`"
          />
          <div class="setting" :class="{ dim: !settings.widget }">
            <div class="widget-row">
              <span class="s-label"><span id="w-scope">Show it for</span></span>
              <div class="segmented" role="radiogroup" aria-labelledby="w-scope">
                <button class="chip" role="radio" :aria-checked="settings.widgetScope === 'dj'" :disabled="!settings.widget" @click="settings.widgetScope = 'dj'">
                  DJ booths
                </button>
                <button class="chip" role="radio" :aria-checked="settings.widgetScope === 'all'" :disabled="!settings.widget" @click="settings.widgetScope = 'all'">
                  Any radio nearby
                </button>
              </div>
            </div>
            <div class="widget-row">
              <span class="s-label"><span id="w-size">Style</span></span>
              <div class="segmented" role="radiogroup" aria-labelledby="w-size">
                <button class="chip" role="radio" :aria-checked="settings.widgetSize === 'full'" :disabled="!settings.widget" @click="settings.widgetSize = 'full'">
                  Full
                </button>
                <button class="chip" role="radio" :aria-checked="settings.widgetSize === 'compact'" :disabled="!settings.widget" @click="settings.widgetSize = 'compact'">
                  Compact
                </button>
              </div>
            </div>
            <div class="widget-row">
              <span class="s-label">Position</span>
              <div class="segmented">
                <button class="btn btn-secondary sm" :disabled="!settings.widget" @click="store.startWidgetEditing()">
                  <Icon name="move" :size="14" /> Move widget
                </button>
                <button
                  class="btn btn-quiet sm"
                  :disabled="!settings.widget"
                  @click="Object.assign(settings, { widgetX: WIDGET_DEFAULT_POS.x, widgetY: WIDGET_DEFAULT_POS.y })"
                >
                  Reset
                </button>
              </div>
            </div>
          </div>
        </template>
      </section>
    </div>

    <template #footer>
      <button class="btn btn-quiet sm reset" @click="resetSettings"><Icon name="rotate-ccw" :size="14" /> Reset to defaults</button>
      <span class="spacer" />
      <button class="btn btn-primary" @click="store.state.settingsOpen = false">Done</button>
    </template>
  </Modal>
</template>

<style scoped>
.settings {
  display: flex;
  flex-direction: column;
  gap: 2.4rem;
}

section {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}

section > .eyebrow {
  margin-bottom: 0.6rem;
}

.setting {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  padding: 1.2rem;
  border-radius: var(--r-md);
  background: var(--fill-1);
  margin-bottom: 0.6rem;
}

.s-label {
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
  font-size: 1.4rem;
  font-weight: 650;
  color: var(--text-h);
}

.s-desc {
  font-size: 1.2rem;
  font-weight: 400;
  color: var(--text-dim);
}

.swatches {
  display: flex;
  flex-wrap: wrap;
  gap: 1rem;
}

.swatch {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 3.6rem;
  height: 3.6rem;
  border-radius: 50%;
  color: #120d14;
  box-shadow: inset 0 0 0 0.1rem rgba(255, 255, 255, 0.15);
  transition: transform 0.18s var(--ease-spring);
}

.swatch:hover {
  transform: scale(1.1);
}

.swatch[aria-checked='true'] {
  box-shadow:
    0 0 0 0.3rem var(--panel-raised),
    0 0 0 0.5rem var(--text-h);
}

/* small light badge so the check/droplet reads on any colour, even a near-black custom one */
.mark {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 2rem;
  height: 2rem;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.92);
  color: #120d14;
  box-shadow: 0 0.2rem 0.6rem rgba(0, 0, 0, 0.3);
}

/* the custom swatch gets a dashed ring until chosen, so it reads as "pick your own" */
.swatch.custom[aria-checked='false'] {
  box-shadow:
    0 0 0 0.25rem var(--panel-raised),
    0 0 0 0.4rem var(--fill-4);
}

.widget-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1.2rem;
}

.setting.dim .s-label {
  opacity: 0.5;
}

.server-off {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  padding: 1rem 1.2rem;
  font-size: 1.3rem;
  color: var(--text-dim);
}

.custom-panel {
  margin-top: 0.4rem;
  padding: 1.4rem;
  border-radius: var(--r-md);
  background: var(--fill-1);
  border: 0.1rem solid var(--line);
}

.adjusted {
  display: flex;
  align-items: center;
  gap: 0.8rem;
  margin-top: 1.2rem;
  font-size: 1.2rem;
  color: var(--text-dim);
}

.mini {
  width: 1.6rem;
  height: 1.6rem;
  border-radius: 50%;
  flex-shrink: 0;
}

.reveal-enter-active,
.reveal-leave-active {
  transition:
    opacity 0.22s var(--ease),
    transform 0.28s var(--ease-out);
}

.reveal-enter-from,
.reveal-leave-to {
  opacity: 0;
  transform: translateY(-0.6rem);
}

.scale-row {
  display: flex;
  align-items: center;
  gap: 0.8rem;
}

.scale-val {
  width: 4.8rem;
  text-align: right;
  font-size: 1.35rem;
  font-weight: 750;
  color: var(--text-h);
  font-variant-numeric: tabular-nums;
}

.segmented {
  display: flex;
  gap: 0.6rem;
}

.spacer {
  flex: 1;
}
</style>
