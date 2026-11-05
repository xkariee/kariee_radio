<script setup lang="ts">
import { computed } from 'vue'
import { store } from '../store'
import Icon from './Icon.vue'

// On-screen guide for the DJ booth creator (client/creator.lua): which step you're on, the
// current option, live values (interior, range, lights...) and every key that does something.
const hud = computed(() => store.state.creator)

const swatch = (s: number[] | 'rainbow' | undefined) =>
  s === 'rainbow'
    ? 'conic-gradient(#ff4d6d, #ffd93d, #4dff88, #4dd2ff, #a64dff, #ff4d6d)'
    : Array.isArray(s)
      ? `rgb(${s.join(',')})`
      : undefined
</script>

<template>
  <Transition name="creator">
    <aside v-if="hud" class="creator" role="status" aria-live="polite" :aria-label="`DJ booth creator, step ${hud.step}: ${hud.title}`">
      <header class="head">
        <span class="badge" aria-hidden="true"><Icon name="speaker" :size="16" /></span>
        <span class="head-text">
          <span class="kicker">{{ hud.editing ? 'Editing DJ booth' : 'Creating DJ booth' }}</span>
          <span v-if="hud.label" class="booth truncate">{{ hud.label }}</span>
        </span>
        <span class="count">Step {{ hud.step }} of {{ hud.steps.length }}</span>
      </header>

      <ol class="stepper" :style="{ gridTemplateColumns: `repeat(${hud.steps.length}, 1fr)` }">
        <li
          v-for="(s, i) in hud.steps"
          :key="s"
          :class="{ done: i + 1 < hud.step, current: i + 1 === hud.step }"
        >
          <span class="bar" />
          <span class="step-label">
            <Icon v-if="i + 1 < hud.step" name="check" :size="11" />
            {{ s }}
          </span>
        </li>
      </ol>

      <Transition name="swap" mode="out-in">
        <div :key="hud.step" class="body">
          <h2 class="title">{{ hud.title }}</h2>
          <p v-if="hud.subtitle" class="subtitle">{{ hud.subtitle }}</p>

          <div v-if="hud.options.length" class="options">
            <span v-for="o in hud.options" :key="o.label" class="option" :class="{ active: o.active }">{{ o.label }}</span>
          </div>

          <dl v-if="hud.info.length" class="info">
            <div v-for="row in hud.info" :key="row.label" class="row">
              <dt>{{ row.label }}</dt>
              <dd>
                <i v-if="row.swatch" class="swatch" :style="{ background: swatch(row.swatch) }" aria-hidden="true" />
                {{ row.value }}
              </dd>
            </div>
          </dl>
        </div>
      </Transition>

      <p v-if="hud.warning" class="warning" role="alert"><Icon name="alert" :size="14" /> {{ hud.warning }}</p>

      <ul class="keys" aria-label="Controls">
        <li v-for="(k, i) in hud.keys" :key="k.label + i" :class="{ primary: k.keys[0] === 'Enter', quiet: k.keys[0] === 'Esc' || k.keys[0] === 'X' }">
          <span class="combo">
            <template v-for="(key, j) in k.keys" :key="key">
              <span v-if="j" class="slash" aria-hidden="true">/</span>
              <kbd :class="{ wide: key.length > 2 }">
                <Icon v-if="key === 'Scroll'" name="disc" :size="10" class="mouse" />{{ key }}
              </kbd>
            </template>
          </span>
          <span class="key-label">{{ k.label }}</span>
        </li>
      </ul>
    </aside>
  </Transition>
</template>

<style scoped>
.creator {
  position: fixed;
  top: 2.4rem;
  left: 2.4rem;
  z-index: 170;
  width: 38rem;
  max-height: calc(100vh - 4.8rem);
  overflow: hidden;
  display: flex;
  flex-direction: column;
  border-radius: var(--r-xl);
  background: rgba(18, 16, 22, 0.92);
  border: 0.1rem solid rgba(255, 255, 255, 0.1);
  box-shadow:
    0 2rem 5rem -1.4rem rgba(0, 0, 0, 0.75),
    inset 0 0.1rem 0 rgba(255, 255, 255, 0.06);
  font-family: var(--font);
  color: var(--text);
  pointer-events: none;
}

.head {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1.4rem 1.6rem 1rem;
}

.badge {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 3.4rem;
  height: 3.4rem;
  border-radius: 1rem;
  background: linear-gradient(145deg, var(--accent-strong), var(--accent));
  color: var(--on-accent);
  box-shadow: 0 0.6rem 1.6rem -0.6rem var(--accent-glow);
}

.head-text {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
}

.kicker {
  font-size: 1.1rem;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--accent);
}

.booth {
  font-size: 1.25rem;
  color: var(--text-dim);
}

.count {
  font-size: 1.15rem;
  font-weight: 700;
  color: var(--text-faint);
  white-space: nowrap;
}

.stepper {
  display: grid;
  gap: 0.6rem;
  margin: 0;
  padding: 0 1.6rem;
  list-style: none;
}

.bar {
  display: block;
  height: 0.4rem;
  border-radius: var(--r-pill);
  background: var(--fill-3);
  transition: background-color 0.3s var(--ease);
}

.done .bar {
  background: var(--accent-line);
}

.current .bar {
  background: var(--accent);
  box-shadow: 0 0 1rem var(--accent-glow);
}

.step-label {
  display: flex;
  align-items: center;
  gap: 0.3rem;
  margin-top: 0.5rem;
  font-size: 1.1rem;
  font-weight: 650;
  color: var(--text-faint);
}

.current .step-label {
  color: var(--text-h);
}

.done .step-label {
  color: var(--text-dim);
}

.body {
  padding: 1.4rem 1.6rem 0.4rem;
}

.title {
  font-size: 2.1rem;
  font-weight: 800;
  letter-spacing: -0.02em;
  color: var(--text-h);
}

.subtitle {
  margin-top: 0.2rem;
  font-size: 1.3rem;
  color: var(--text-dim);
}

.options {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-top: 1.2rem;
}

.option {
  height: 2.8rem;
  padding: 0 1.2rem;
  display: inline-flex;
  align-items: center;
  border-radius: var(--r-pill);
  background: var(--fill-2);
  border: 0.1rem solid var(--line);
  font-size: 1.2rem;
  font-weight: 700;
  color: var(--text-dim);
  transition:
    background-color 0.2s var(--ease),
    color 0.2s var(--ease);
}

.option.active {
  background: var(--accent);
  border-color: var(--accent);
  color: var(--on-accent);
}

.info {
  margin: 1.2rem 0 0;
  padding: 0.4rem 1.2rem;
  border-radius: var(--r-md);
  background: var(--fill-1);
  border: 0.1rem solid var(--line);
}

.row {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 1.2rem;
  padding: 0.6rem 0;
}

.row + .row {
  border-top: 0.1rem solid var(--line);
}

.row dt {
  flex-shrink: 0;
  font-size: 1.2rem;
  color: var(--text-faint);
}

.row dd {
  margin: 0;
  display: flex;
  align-items: center;
  gap: 0.6rem;
  min-width: 0;
  font-size: 1.3rem;
  font-weight: 650;
  color: var(--text-h);
  text-align: right;
}

.swatch {
  width: 1.2rem;
  height: 1.2rem;
  border-radius: 50%;
  flex-shrink: 0;
  box-shadow: 0 0 0 0.15rem rgba(255, 255, 255, 0.2);
}

.warning {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  margin: 1rem 1.6rem 0;
  padding: 0.8rem 1rem;
  border-radius: var(--r-sm);
  background: rgba(255, 196, 92, 0.12);
  color: #ffc65c;
  font-size: 1.25rem;
  font-weight: 650;
}

.keys {
  list-style: none;
  margin: 1.2rem 0 0;
  padding: 1rem 1.6rem 1.4rem;
  border-top: 0.1rem solid var(--line);
  background: rgba(0, 0, 0, 0.18);
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.keys li {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.combo {
  display: flex;
  align-items: center;
  gap: 0.3rem;
  min-width: 11.8rem;
}

.slash {
  font-size: 1.1rem;
  color: var(--text-faint);
}

.keys kbd {
  gap: 0.3rem;
  min-width: 2.6rem;
  height: 2.4rem;
  font-size: 1.15rem;
  color: var(--text-h);
}

.keys kbd.wide {
  padding: 0 0.8rem;
}

.mouse {
  color: var(--text-dim);
}

.key-label {
  font-size: 1.3rem;
  color: var(--text);
}

.primary kbd {
  background: var(--accent);
  border-color: var(--accent-strong);
  color: var(--on-accent);
}

.primary .key-label {
  font-weight: 750;
  color: var(--text-h);
}

.quiet .key-label {
  color: var(--text-dim);
}

.creator-enter-active {
  transition:
    opacity 0.3s var(--ease),
    transform 0.4s var(--ease-out);
}

.creator-leave-active {
  transition:
    opacity 0.2s var(--ease),
    transform 0.2s var(--ease);
}

.creator-enter-from,
.creator-leave-to {
  opacity: 0;
  transform: translateX(-2rem);
}

.swap-enter-active,
.swap-leave-active {
  transition:
    opacity 0.18s var(--ease),
    transform 0.22s var(--ease-out);
}

.swap-enter-from {
  opacity: 0;
  transform: translateX(1rem);
}

.swap-leave-to {
  opacity: 0;
  transform: translateX(-1rem);
}
</style>
