<script setup lang="ts">
import { ref } from 'vue'
import Icon from './Icon.vue'
import Cover from './Cover.vue'

const props = defineProps<{ modelValue: string | null; hue: number }>()
const emit = defineEmits<{ 'update:modelValue': [string | null] }>()

const urlDraft = ref('')
// const fileInput = ref<HTMLInputElement | null>(null)

// function pickFile() {
//   fileInput.value?.click()
// }

function onFile(e: Event) {
  const file = (e.target as HTMLInputElement).files?.[0]
  if (!file) return
  const reader = new FileReader()
  reader.onload = () => emit('update:modelValue', reader.result as string)
  reader.readAsDataURL(file)
}

function applyUrl() {
  if (urlDraft.value.trim()) {
    emit('update:modelValue', urlDraft.value.trim())
    urlDraft.value = ''
  }
}

// function remove() {
//   emit('update:modelValue', null)
// }
</script>

<template>
  <div class="cover-picker">
    <Cover :src="modelValue" :hue="hue" :size="72" :radius="10" icon="disc" />
    <div class="picker-actions">
      <!-- <div class="row"> -->
        <!-- <button type="button" class="btn-secondary sm" @click="pickFile">
          <Icon name="upload" :size="13" /> Upload
        </button> -->
        <!-- <button v-if="modelValue" type="button" class="btn-secondary sm" @click="remove">
          <Icon name="x" :size="13" /> Remove
        </button> -->
      <!-- </div> -->
      <div class="row">
        <input
          v-model="urlDraft"
          type="text"
          class="text-input"
          placeholder="Paste image URL..."
          @keydown.enter.prevent="applyUrl"
        />
        <button type="button" class="btn-secondary sm" @click="applyUrl">
          <Icon name="link" :size="13" />
        </button>
      </div>
      <input ref="fileInput" type="file" accept="image/*" class="hidden-input" @change="onFile" />
    </div>
  </div>
</template>

<style scoped>
.cover-picker {
  display: flex;
  gap: 14px;
  align-items: flex-start;
}

.picker-actions {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 8px;
  min-width: 0;
}

.row {
  display: flex;
  gap: 6px;
}

.row .text-input {
  flex: 1;
  min-width: 0;
  padding: 7px 10px;
  font-size: 12.5px;
}

.hidden-input {
  display: none;
}

.btn-secondary.sm {
  padding: 6px 9px;
  font-size: 12px;
}
</style>
