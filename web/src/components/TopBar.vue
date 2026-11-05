<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue'
import type { BroadcastKind } from '../types'
import { store } from '../store'
import Icon from './Icon.vue'

const { state } = store

const input = ref<HTMLInputElement | null>(null)

watch(
  () => state.focusSearchSignal,
  async () => {
    await nextTick()
    input.value?.focus()
    input.value?.select()
  },
)

function onFocus() {
  if (state.view !== 'search') store.setView('search')
}

function onEsc() {
  if (state.searchQuery) state.searchQuery = ''
  else input.value?.blur()
}

function clearSearch() {
  state.searchQuery = ''
  input.value?.focus()
}

const CONTEXTS: Record<BroadcastKind, { icon: string; label: string; help: string }> = {
  radiocar: { icon: 'car', label: 'Car radio', help: 'Everyone in this vehicle can control playback and the queue.' },
  dj: { icon: 'speaker', label: 'DJ booth', help: 'Anyone at the booth can control playback and add to the queue.' },
  radio: { icon: 'radio', label: 'Personal radio', help: 'Only you control this radio. Players nearby can hear it.' },
}

const context = computed(() => (state.contextKind ? CONTEXTS[state.contextKind] : null))
</script>

<template>
  <header class="topbar">
    <div class="history">
      <button class="icon-btn" aria-label="Go back" title="Back" :disabled="state.historyIndex <= 0" @click="store.goBack">
        <Icon name="chevron-left" :size="20" />
      </button>
      <button
        class="icon-btn"
        aria-label="Go forward"
        title="Forward"
        :disabled="state.historyIndex >= state.history.length - 1"
        @click="store.goForward"
      >
        <Icon name="chevron-right" :size="20" />
      </button>
    </div>

    <div class="search" role="search">
      <Icon name="search" :size="18" />
      <label class="sr-only" for="radio-search">Search songs and artists, or paste a YouTube link</label>
      <input
        id="radio-search"
        ref="input"
        v-model="state.searchQuery"
        type="text"
        autocomplete="off"
        spellcheck="false"
        placeholder="Search songs, artists or paste a link"
        @focus="onFocus"
        @keydown.esc.stop.prevent="onEsc"
      />
      <Transition name="pop" mode="out-in">
        <button v-if="state.searchQuery" class="clear" aria-label="Clear search" @click="clearSearch">
          <Icon name="x" :size="14" />
        </button>
        <kbd v-else aria-hidden="true">/</kbd>
      </Transition>
    </div>

    <div v-if="context" class="context" :title="context.help">
      <Icon :name="context.icon" :size="16" />
      <span class="ctx-label">{{ context.label }}</span>
      <span v-if="store.shared.value" class="ctx-shared"><i aria-hidden="true" />Shared</span>
      <span class="sr-only">. {{ context.help }}</span>
    </div>

    <div class="tools">
      <button class="icon-btn" aria-label="Keyboard shortcuts" title="Keyboard shortcuts (?)" @click="state.shortcutsOpen = true">
        <Icon name="keyboard" :size="19" />
      </button>
      <button class="icon-btn" aria-label="Settings" title="Settings" @click="state.settingsOpen = true">
        <Icon name="settings" :size="19" />
      </button>
      <button class="icon-btn close" aria-label="Close radio" title="Close (Esc)" @click="store.close()">
        <Icon name="x" :size="20" />
      </button>
    </div>
  </header>
</template>

<style scoped>
.topbar {
  position: relative;
  z-index: 2;
  display: flex;
  align-items: center;
  gap: 1.2rem;
  padding: 1.4rem 1.6rem 1rem;
}

.history {
  display: flex;
  gap: 0.4rem;
}

.history .icon-btn {
  background: var(--fill-2);
  color: var(--text-h);
}

.history .icon-btn:disabled {
  background: var(--fill-1);
  opacity: 0.35;
}

.search {
  flex: 1;
  max-width: 62rem;
  display: flex;
  align-items: center;
  gap: 1rem;
  height: 4.6rem;
  padding: 0 0.8rem 0 1.6rem;
  border-radius: var(--r-pill);
  background: var(--fill-2);
  border: 0.1rem solid var(--line);
  color: var(--text-dim);
  transition:
    border-color 0.18s var(--ease),
    background-color 0.18s var(--ease),
    box-shadow 0.18s var(--ease);
}

.search:hover {
  background: var(--fill-3);
}

.search:focus-within {
  background: var(--fill-3);
  border-color: var(--accent-line);
  box-shadow: 0 0 0 0.4rem var(--accent-soft);
  color: var(--text-h);
}

.search input {
  flex: 1;
  min-width: 0;
  height: 100%;
  background: transparent;
  border: none;
  outline: none;
  color: var(--text-h);
  font-size: 1.45rem;
  font-weight: 500;
}

.search input::placeholder {
  color: var(--text-faint);
}

.search kbd {
  margin-right: 0.6rem;
}

.clear {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 3rem;
  height: 3rem;
  border-radius: 50%;
  background: var(--fill-3);
  color: var(--text-h);
  transition: background-color 0.15s var(--ease);
}

.clear:hover {
  background: var(--fill-4);
}

.context {
  display: flex;
  align-items: center;
  gap: 0.7rem;
  height: 3.6rem;
  padding: 0 1.3rem;
  border-radius: var(--r-pill);
  background: var(--fill-1);
  border: 0.1rem solid var(--line);
  color: var(--text-dim);
  font-size: 1.25rem;
  font-weight: 650;
  white-space: nowrap;
  cursor: help;
}

.context svg {
  color: var(--accent);
}

.ctx-shared {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  margin-left: 0.2rem;
  padding: 0.2rem 0.8rem;
  border-radius: var(--r-pill);
  background: rgba(98, 227, 166, 0.12);
  color: var(--ok);
  font-size: 1.1rem;
  font-weight: 750;
}

.ctx-shared i {
  width: 0.6rem;
  height: 0.6rem;
  border-radius: 50%;
  background: currentColor;
  box-shadow: 0 0 0 0.3rem rgba(98, 227, 166, 0.2);
}

.tools {
  display: flex;
  gap: 0.2rem;
  margin-left: auto;
}

.close:hover:not(:disabled) {
  background: var(--danger-soft);
  color: var(--danger);
}
</style>
