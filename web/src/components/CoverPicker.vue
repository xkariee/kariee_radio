<script setup lang="ts">
import { ref } from 'vue'
import Icon from './Icon.vue'
import Cover from './Cover.vue'

defineProps<{ hue: number }>()
const model = defineModel<string | null>({ required: true })

const urlDraft = ref('')
const error = ref('')

function applyUrl() {
  const url = urlDraft.value.trim()
  if (!url) return
  if (!/^https?:\/\/\S+$/i.test(url)) {
    error.value = 'That doesn’t look like an image link (it should start with https://).'
    return
  }
  error.value = ''
  model.value = url
  urlDraft.value = ''
}
</script>

<template>
  <div class="picker">
    <div class="preview">
      <Cover :src="model" :hue="hue" :size="112" :radius="14" icon="music" />
      <button v-if="model" type="button" class="remove" aria-label="Remove cover image" @click="model = null">
        <Icon name="x" :size="13" />
      </button>
    </div>
    <div class="fields">
      <label class="field-label" for="cover-url">Cover image</label>
      <div class="row">
        <input
          id="cover-url"
          v-model="urlDraft"
          type="url"
          class="text-input"
          placeholder="Paste an image link"
          :aria-invalid="!!error"
          aria-describedby="cover-hint"
          @keydown.enter.prevent="applyUrl"
        />
        <button type="button" class="btn btn-secondary sm" :disabled="!urlDraft.trim()" @click="applyUrl">Use</button>
      </div>
      <p id="cover-hint" class="hint" :class="{ error }">
        {{ error || 'Optional. Without an image we’ll generate artwork in this playlist’s colour.' }}
      </p>
    </div>
  </div>
</template>

<style scoped>
.picker {
  display: flex;
  gap: 1.6rem;
  align-items: flex-start;
}

.preview {
  position: relative;
  border-radius: 1.4rem;
  box-shadow: 0 1.2rem 2.8rem -1rem rgba(0, 0, 0, 0.7);
}

.remove {
  position: absolute;
  top: -0.8rem;
  right: -0.8rem;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 2.6rem;
  height: 2.6rem;
  border-radius: 50%;
  background: var(--text-h);
  color: #17141b;
  box-shadow: 0 0.4rem 1rem rgba(0, 0, 0, 0.5);
}

.fields {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 0.6rem;
}

.field-label {
  font-size: 1.25rem;
  font-weight: 700;
  color: var(--text-dim);
}

.row {
  display: flex;
  gap: 0.6rem;
}

.row .btn {
  height: 4rem;
}

.hint {
  font-size: 1.2rem;
  color: var(--text-faint);
}

.hint.error {
  color: var(--danger);
}
</style>
