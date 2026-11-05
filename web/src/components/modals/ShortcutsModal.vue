<script setup lang="ts">
import { store } from '../../store'
import Modal from '../Modal.vue'

const groups = [
  {
    title: 'Playback',
    rows: [
      { keys: ['Space'], label: 'Play / pause' },
      { keys: ['Shift', '→'], label: 'Next song' },
      { keys: ['Shift', '←'], label: 'Previous song' },
      { keys: ['→'], label: 'Forward 5 seconds' },
      { keys: ['←'], label: 'Back 5 seconds' },
      { keys: ['↑'], label: 'Volume up' },
      { keys: ['↓'], label: 'Volume down' },
      { keys: ['M'], label: 'Mute / unmute' },
      { keys: ['S'], label: 'Shuffle' },
      { keys: ['R'], label: 'Repeat: off, all, one' },
      { keys: ['L'], label: 'Like the current song' },
      { keys: ['T'], label: 'Tap the beat for the disco lights (DJ booths)' },
    ],
  },
  {
    title: 'Navigation',
    rows: [
      { keys: ['/'], label: 'Search' },
      { keys: ['Ctrl', 'K'], label: 'Search (from anywhere)' },
      { keys: ['H'], label: 'Home' },
      { keys: ['Q'], label: 'Queue' },
      { keys: ['N'], label: 'Now playing panel' },
      { keys: ['?'], label: 'This list' },
      { keys: ['Esc'], label: 'Close menu, dialog or radio' },
    ],
  },
  {
    title: 'On a focused song',
    rows: [
      { keys: ['Enter'], label: 'Play it' },
      { keys: ['↑', '↓'], label: 'Move between songs' },
      { keys: ['Shift', 'F10'], label: 'More options (like, queue, add…)' },
      { keys: ['Alt', '↑ ↓'], label: 'Reorder (in Queue)' },
      { keys: ['Del'], label: 'Remove (in Queue)' },
    ],
  },
]
</script>

<template>
  <Modal title="Keyboard shortcuts" icon="keyboard" :width="680" @close="store.state.shortcutsOpen = false">
    <div class="groups">
      <section v-for="g in groups" :key="g.title" :aria-label="g.title">
        <h3 class="eyebrow">{{ g.title }}</h3>
        <dl>
          <div v-for="r in g.rows" :key="r.label" class="row">
            <dt>
              <template v-for="(k, i) in r.keys" :key="k">
                <span v-if="i" class="plus" aria-hidden="true">+</span><kbd>{{ k }}</kbd>
              </template>
            </dt>
            <dd>{{ r.label }}</dd>
          </div>
        </dl>
      </section>
    </div>
  </Modal>
</template>

<style scoped>
.groups {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 2rem 3.2rem;
}

.groups section:first-child {
  grid-row: span 2;
}

h3 {
  margin-bottom: 0.8rem;
}

dl {
  margin: 0;
  display: flex;
  flex-direction: column;
}

.row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1.2rem;
  min-height: 3.4rem;
  border-bottom: 0.1rem solid var(--line);
}

.row:last-child {
  border-bottom: none;
}

dt {
  order: 2;
  display: flex;
  align-items: center;
  gap: 0.4rem;
  flex-shrink: 0;
}

dd {
  margin: 0;
  font-size: 1.35rem;
  color: var(--text);
}

.plus {
  font-size: 1.1rem;
  color: var(--text-faint);
}
</style>
