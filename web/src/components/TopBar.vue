<script setup lang="ts">
import { store } from '../store'
import Icon from './Icon.vue'

const emit = defineEmits<{ close: [] }>()
</script>

<template>
  <header class="topbar">
    <div class="brand">
      <span class="brand-badge"><Icon name="disc" :size="16" /></span>
      <span>AX <b>Radio</b></span>
    </div>

    <div class="search">
      <Icon name="search" :size="15" />
      <input
        v-model="store.state.searchQuery"
        type="text"
        placeholder="Search by song title or artist..."
        @keydown.esc="store.state.searchQuery = ''"
      />
      <Transition name="pop">
        <button v-if="store.state.searchQuery" class="clear" @click="store.state.searchQuery = ''">
          <Icon name="x" :size="13" />
        </button>
      </Transition>
    </div>

    <button class="btn-icon close" title="Close" @click="emit('close')">
      <Icon name="x" :size="16" />
    </button>
  </header>
</template>

<style scoped>
.topbar {
  display: flex;
  align-items: center;
  gap: 18px;
  padding: 12px 16px;
  border-bottom: 1px solid var(--line);
}

.brand {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 14px;
  font-weight: 500;
  color: var(--text);
  white-space: nowrap;
}

.brand-badge {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 30px;
  height: 30px;
  border-radius: var(--radius-sm);
  background: linear-gradient(155deg, var(--teal-wash), transparent);
  border: 1px solid var(--teal-line);
  color: var(--teal);
}

.brand b {
  color: var(--teal);
  font-weight: 700;
}

.search {
  flex: 1;
  max-width: 1000px;
  display: flex;
  align-items: center;
  gap: 8px;
  background: var(--surface-2);
  border: 1px solid var(--line);
  border-radius: 999px;
  padding: 8px 14px;
  color: var(--text-faint);
  margin-left: 15px;
  /* margin: 0 auto; */
  transition:
    border-color 0.15s var(--ease),
    box-shadow 0.15s var(--ease),
    background-color 0.15s var(--ease);
}

.search:focus-within {
  border-color: var(--teal-line);
  background: var(--surface-3);
  box-shadow: 0 0 0 3px var(--teal-wash);
}

.search input {
  flex: 1;
  min-width: 0;
  background: transparent;
  border: none;
  outline: none;
  color: var(--text);
  font-size: 13px;
}

.search input::placeholder {
  color: var(--text-faint);
}

.clear {
  display: flex;
  color: var(--text-faint);
  transition: color 0.15s var(--ease);
}

.clear:hover {
  color: var(--text);
}

.close {
  margin-left: auto;
}
</style>
