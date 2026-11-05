<script setup lang="ts">
import { computed, onMounted, onUnmounted, reactive, ref } from 'vue'
import { store } from '../store'
import type { JobInfo } from '../types'
import Modal from './Modal.vue'
import Dropdown from './Dropdown.vue'
import Icon from './Icon.vue'

const { state } = store
const jobs = state.creatorAccess?.jobs ?? []

const lowestGrade = (job: JobInfo) => job.grades[0]?.grade ?? 0

const picked = reactive<Record<string, number>>({})
for (const rule of state.creatorAccess?.access ?? []) {
  const job = jobs.find((j) => j.name === rule.job)
  if (!job) continue
  const fit = [...job.grades].reverse().find((g) => g.grade <= rule.grade)
  picked[job.name] = fit?.grade ?? lowestGrade(job)
}

const q = ref('')
const show = ref<'all' | 'picked'>(Object.keys(picked).length ? 'picked' : 'all')
const count = computed(() => Object.keys(picked).length)

const filtered = computed(() => {
  const needle = q.value.trim().toLowerCase()
  return jobs.filter(
    (j) =>
      (show.value === 'all' || j.name in picked) &&
      (!needle || j.label.toLowerCase().includes(needle) || j.name.toLowerCase().includes(needle)),
  )
})

const gradeOptions = (job: JobInfo) =>
  job.grades.length
    ? job.grades.map((g, i) => ({ value: String(g.grade), label: i === 0 ? 'Any grade' : `${g.label} and up` }))
    : [{ value: '0', label: 'Any grade' }]

function toggle(job: JobInfo) {
  if (job.name in picked) delete picked[job.name]
  else picked[job.name] = lowestGrade(job)
}

function clearAll() {
  for (const name of Object.keys(picked)) delete picked[name]
  show.value = 'all'
}

function save() {
  store.closeAccessPicker(jobs.filter((j) => j.name in picked).map((j) => ({ job: j.name, grade: picked[j.name] })))
}

function cancel() {
  store.closeAccessPicker(null)
}

function onKey(e: KeyboardEvent) {
  if (e.key !== 'Escape') return
  e.preventDefault()
  cancel()
}

onMounted(() => window.addEventListener('keydown', onKey))
onUnmounted(() => window.removeEventListener('keydown', onKey))
</script>

<template>
  <Modal
    title="Who can use the console"
    subtitle="Pick the jobs that can play music at this booth. Pick none and everyone can."
    icon="lock"
    :width="560"
    @close="cancel"
  >
    <div class="picker">
      <label class="search">
        <Icon name="search" :size="15" />
        <input v-model="q" type="text" placeholder="Search jobs" aria-label="Search jobs" autofocus />
      </label>

      <div class="bar">
        <div class="segmented" role="radiogroup" aria-label="Show">
          <button type="button" class="chip sm" role="radio" :aria-checked="show === 'all'" @click="show = 'all'">
            All jobs
          </button>
          <button type="button" class="chip sm" role="radio" :aria-checked="show === 'picked'" @click="show = 'picked'">
            Selected · {{ count }}
          </button>
        </div>
        <button v-if="count" type="button" class="btn btn-quiet sm" @click="clearAll">Clear</button>
      </div>

      <ul class="jobs" aria-label="Jobs">
        <li v-for="job in filtered" :key="job.name" class="job" :class="{ on: job.name in picked }">
          <button type="button" class="job-toggle" role="checkbox" :aria-checked="job.name in picked" @click="toggle(job)">
            <span class="box" aria-hidden="true"><Icon v-if="job.name in picked" name="check" :size="13" /></span>
            <span class="job-text">
              <b class="truncate">{{ job.label }}</b>
              <span class="truncate">{{ job.name }} · {{ job.grades.length }} {{ job.grades.length === 1 ? 'grade' : 'grades' }}</span>
            </span>
          </button>
          <Dropdown
            v-if="job.name in picked && job.grades.length > 1"
            :model-value="String(picked[job.name])"
            :options="gradeOptions(job)"
            :label="`Minimum grade for ${job.label}`"
            align="end"
            @update:model-value="(v) => (picked[job.name] = Number(v))"
          />
          <span v-else-if="job.name in picked" class="any">Any grade</span>
        </li>
        <li v-if="!filtered.length" class="none">
          {{ jobs.length ? (show === 'picked' && !q ? 'No jobs selected - everyone can use it.' : 'No jobs match.') : 'No jobs found on this server.' }}
        </li>
      </ul>

      <p class="note" :class="{ open: !count }">
        <Icon :name="count ? 'lock' : 'users'" :size="14" />
        <template v-if="count">
          Only {{ count === 1 ? 'this job' : `these ${count} jobs` }} can play music here. Radio admins always can.
        </template>
        <template v-else>No jobs picked - every player can use this console.</template>
      </p>
    </div>

    <template #footer>
      <button type="button" class="btn btn-quiet" @click="cancel">Cancel</button>
      <button type="button" class="btn btn-primary" @click="save"><Icon name="check" :size="14" /> Save access</button>
    </template>
  </Modal>
</template>

<style scoped>
.picker {
  display: flex;
  flex-direction: column;
  gap: 1.2rem;
}

.search {
  display: flex;
  align-items: center;
  gap: 0.8rem;
  height: 4rem;
  padding: 0 1.3rem;
  border-radius: var(--r-pill);
  background: var(--fill-2);
  border: 0.1rem solid var(--line-2);
  color: var(--text-faint);
}

.search:focus-within {
  border-color: var(--accent-line);
}

.search input {
  flex: 1;
  min-width: 0;
  background: transparent;
  border: none;
  outline: none;
  color: var(--text-h);
  font-size: 1.35rem;
}

.search input::placeholder {
  color: var(--text-faint);
}

.bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
}

.segmented {
  display: flex;
  gap: 0.5rem;
}

.chip.sm {
  height: 2.9rem;
  padding: 0 1.2rem;
  font-size: 1.2rem;
}

.jobs {
  list-style: none;
  margin: 0;
  padding: 0.4rem;
  max-height: 38rem;
  overflow-y: auto;
  border-radius: var(--r-md);
  background: var(--fill-1);
  border: 0.1rem solid var(--line);
}

.job {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding-right: 0.6rem;
  border-radius: var(--r-sm);
  transition: background-color 0.15s var(--ease);
}

.job:hover {
  background: var(--fill-2);
}

.job.on {
  background: var(--accent-soft);
}

.job-toggle {
  flex: 1;
  min-width: 0;
  display: flex;
  align-items: center;
  gap: 1.1rem;
  padding: 0.9rem 1rem;
  text-align: left;
}

.box {
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 2rem;
  height: 2rem;
  border-radius: 0.6rem;
  border: 0.15rem solid var(--line-2);
  background: var(--fill-2);
  color: var(--on-accent);
  transition:
    background-color 0.15s var(--ease),
    border-color 0.15s var(--ease);
}

.on .box {
  background: var(--accent);
  border-color: var(--accent);
}

.job-text {
  min-width: 0;
  display: flex;
  flex-direction: column;
}

.job-text b {
  font-size: 1.35rem;
  font-weight: 700;
  color: var(--text-h);
}

.job-text span {
  font-size: 1.15rem;
  color: var(--text-faint);
}

.any {
  flex-shrink: 0;
  padding: 0 1rem;
  font-size: 1.2rem;
  font-weight: 650;
  color: var(--text-dim);
}

.none {
  padding: 2rem 1rem;
  text-align: center;
  font-size: 1.3rem;
  color: var(--text-faint);
}

.note {
  display: flex;
  align-items: center;
  gap: 0.7rem;
  padding: 0.9rem 1.1rem;
  border-radius: var(--r-sm);
  background: var(--accent-soft);
  color: var(--text-h);
  font-size: 1.25rem;
  font-weight: 600;
}

.note.open {
  background: var(--fill-2);
  color: var(--text-dim);
}
</style>
