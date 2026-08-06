<script setup>
import { ref, reactive, computed } from 'vue'
import { ElMessage } from 'element-plus'
import { authApi, bodyApi, supplementApi, foodApi, drugApi, workoutApi, mealApi, trainingApi, sleepApi, syncApi } from '../api/modules'
import { appState, addLog } from '../stores/state'

// ── 功能用例定义 ──
const useCases = [
  {
    id: 'auth_login', group: '认证', name: '登录', desc: 'POST /api/auth/login',
    fields: [{ k: 'phone', label: '手机号', ph: '13800000001', def: '13800000001' }, { k: 'password', label: '密码', ph: '666666', def: '666666' }],
    run: async (f) => {
      const r = await authApi.login(f.phone, f.password)
      return { pass: r.ok && r.data?.user?.user_id, detail: r.message, ms: r.ms }
    },
  },
  {
    id: 'auth_register', group: '认证', name: '注册', desc: 'POST /api/auth/register',
    fields: [{ k: 'phone', label: '手机号', ph: '11位', def: '' }, { k: 'password', label: '密码', ph: '≥6位', def: '123456' }, { k: 'nickname', label: '昵称', ph: '选填', def: '' }],
    run: async (f) => {
      const r = await authApi.register({ phone: f.phone, password: f.password, nickname: f.nickname })
      return { pass: r.ok && !!r.data?.user, detail: r.message, ms: r.ms }
    },
  },
  {
    id: 'body_upload', group: '身体', name: '身体数据上传', desc: 'PUT /api/body',
    fields: [
      { k: 'userId', label: 'user_id', ph: '', def: '' },
      { k: 'height', label: '身高cm', ph: '170', def: '170' }, { k: 'weight', label: '体重kg', ph: '70', def: '70' },
      { k: 'age', label: '年龄', ph: '25', def: '25' },
    ],
    run: async (f) => {
      const uid = f.userId || appState.currentUserId
      if (!uid) return { pass: false, detail: '未选择测试账号', ms: 0 }
      const r = await bodyApi.upload({ height_cm: +f.height, weight_kg: +f.weight, age: +f.age, sex: 'male', chest_cm: 92, waist_cm: 78, neck_cm: 38, hip_cm: 90, body_fat_percent: 20, activity_level: 'moderate', recorded_at: new Date().toISOString(), user_id: uid })
      return { pass: r.ok, detail: r.message, ms: r.ms }
    },
  },
  {
    id: 'body_latest', group: '身体', name: '身体数据查询', desc: 'GET /api/body/latest',
    fields: [{ k: 'userId', label: 'user_id', ph: '', def: '' }],
    run: async (f) => {
      const uid = f.userId || appState.currentUserId
      if (!uid) return { pass: false, detail: '未选择测试账号', ms: 0 }
      const r = await bodyApi.latest(uid)
      return { pass: r.ok, detail: r.message, ms: r.ms }
    },
  },
  {
    id: 'meal_today', group: '饮食', name: '今日饮食', desc: 'GET /api/meal/today',
    fields: [{ k: 'userId', label: 'user_id', ph: '', def: '' }, { k: 'date', label: '日期(可选)', ph: '2026-08-06', def: '' }],
    run: async (f) => {
      const uid = f.userId || appState.currentUserId
      if (!uid) return { pass: false, detail: '未选择测试账号', ms: 0 }
      const r = await mealApi.today(uid, f.date)
      return { pass: r.ok, detail: r.message, ms: r.ms }
    },
  },
  {
    id: 'training_history', group: '训练', name: '训练历史', desc: 'GET /api/training/history',
    fields: [{ k: 'userId', label: 'user_id', ph: '', def: '' }, { k: 'days', label: '天数', ph: '30', def: '30' }],
    run: async (f) => {
      const uid = f.userId || appState.currentUserId
      if (!uid) return { pass: false, detail: '未选择测试账号', ms: 0 }
      const r = await trainingApi.history(uid, +f.days || 30)
      return { pass: r.ok, detail: r.message, ms: r.ms }
    },
  },
  {
    id: 'drug_list', group: '用药', name: '用药列表', desc: 'GET /api/drug/list',
    fields: [{ k: 'userId', label: 'user_id', ph: '', def: '' }],
    run: async (f) => {
      const uid = f.userId || appState.currentUserId
      if (!uid) return { pass: false, detail: '未选择测试账号', ms: 0 }
      const r = await drugApi.list(uid)
      return { pass: r.ok, detail: r.message, ms: r.ms }
    },
  },
  {
    id: 'drug_lookup', group: '用药', name: '药品查询', desc: 'POST /api/drug/lookup',
    fields: [{ k: 'name', label: '药品名', ph: '布洛芬', def: '布洛芬' }],
    run: async (f) => {
      const r = await drugApi.lookup({ name: f.name })
      return { pass: r.ok, detail: r.message, ms: r.ms }
    },
  },
  {
    id: 'sleep_latest', group: '睡眠', name: '睡眠查询', desc: 'GET /api/sleep/latest',
    fields: [{ k: 'userId', label: 'user_id', ph: '', def: '' }],
    run: async (f) => {
      const uid = f.userId || appState.currentUserId
      if (!uid) return { pass: false, detail: '未选择测试账号', ms: 0 }
      const r = await sleepApi.latest(uid)
      return { pass: r.ok, detail: r.message, ms: r.ms }
    },
  },
  {
    id: 'sleep_upload', group: '睡眠', name: '睡眠上报', desc: 'POST /api/sleep/records',
    fields: [{ k: 'userId', label: 'user_id', ph: '', def: '' }, { k: 'date', label: '日期', ph: '2026-08-06', def: '' }, { k: 'hours', label: '总时长h', ph: '7.5', def: '7.5' }],
    run: async (f) => {
      const uid = f.userId || appState.currentUserId
      if (!uid) return { pass: false, detail: '未选择测试账号', ms: 0 }
      const r = await sleepApi.upload({ sleep_date: f.date || new Date().toISOString().slice(0, 10), total_sleep_hours: +f.hours, core_sleep_hours: 4, deep_sleep_hours: 1.2, rem_sleep_hours: 1.8, awake_hours: 0.5, resting_heart_rate: 60, avg_hrv: 45, user_id: uid })
      return { pass: r.ok, detail: r.message, ms: r.ms }
    },
  },
  {
    id: 'sync_batch', group: '同步', name: 'sync/batch 冒烟', desc: 'POST /api/sync/batch（空载荷）',
    fields: [{ k: 'userId', label: 'user_id', ph: '', def: '' }],
    run: async (f) => {
      const uid = f.userId || appState.currentUserId
      if (!uid) return { pass: false, detail: '未选择测试账号', ms: 0 }
      const r = await syncApi.batch({ sync_mode: 'incremental', user_id: uid, body_data: [], meal_records: [], training_records: [], drug_records: [], deleted_drug_records: [], supplement_records: [], sleep_records: [] })
      return { pass: r.ok, detail: r.message, ms: r.ms }
    },
  },
  {
    id: 'supplement_plan', group: '计算', name: '补剂方案', desc: 'POST /api/supplement-plan',
    fields: [{ k: 'height', label: '身高cm', ph: '170', def: '170' }, { k: 'weight', label: '体重kg', ph: '70', def: '70' }],
    run: async (f) => {
      const r = await supplementApi.plan({ height_cm: +f.height, weight_kg: +f.weight, age: 25, sex: 'male', activity_level: 'moderate' })
      return { pass: r.ok, detail: r.message, ms: r.ms }
    },
  },
  {
    id: 'food_recognize', group: '计算', name: '食物识别', desc: 'POST /api/food/recognize',
    fields: [{ k: 'name', label: '食物名', ph: '鸡胸肉', def: '鸡胸肉' }],
    run: async (f) => {
      const r = await foodApi.recognize({ food_name: f.name })
      return { pass: r.ok, detail: r.message, ms: r.ms }
    },
  },
  {
    id: 'workout_classify', group: '计算', name: '训练分类', desc: 'POST /api/workout/classify',
    fields: [{ k: 'name', label: '动作名', ph: '深蹲', def: '深蹲' }],
    run: async (f) => {
      const r = await workoutApi.classify({ exercise_name: f.name })
      return { pass: r.ok, detail: r.message, ms: r.ms }
    },
  },
  {
    id: 'drug_risk', group: '计算', name: '用药风险', desc: 'POST /api/drug/risk-check',
    fields: [{ k: 'drugs', label: '药物(json数组)', ph: '[{"name":"布洛芬"}]', def: '[{"name":"布洛芬"}]' }],
    run: async (f) => {
      let drugs
      try { drugs = JSON.parse(f.drugs) } catch { return { pass: false, detail: '药物参数不是合法 JSON', ms: 0 } }
      const r = await drugApi.riskCheck({ drugs })
      return { pass: r.ok, detail: r.message, ms: r.ms }
    },
  },
]

// ── 状态 ──
const activeGroup = ref('全部')
const groups = ['全部', ...new Set(useCases.map((c) => c.group))]
const shownCases = ref(useCases.map((c) => ({ ...c, fields: (c.fields || []).map((f) => ({ ...f, value: f.def })) })))

const results = reactive({}) // id -> {pass, detail, ms, raw}

function filterGroup(g) {
  activeGroup.value = g
  const list = g === '全部' ? useCases : useCases.filter((c) => c.group === g)
  shownCases.value = list.map((c) => ({ ...c, fields: (c.fields || []).map((f) => ({ ...f, value: f.def })) }))
}

async function runCase(c) {
  results[c.id] = { running: true }
  const fields = Object.fromEntries((c.fields || []).map((f) => [f.k, f.value]))
  try {
    const res = await c.run(fields)
    results[c.id] = { running: false, ...res }
    addLog({
      type: 'func-test',
      title: `用例「${c.name}」${res.pass ? '通过' : '失败'}`,
      detail: `${c.desc} · ${res.detail} · ${res.ms}ms`,
    })
  } catch (e) {
    results[c.id] = { running: false, pass: false, detail: e.message, ms: 0 }
    addLog({ type: 'func-test', title: `用例「${c.name}」异常`, detail: e.message })
  }
}

async function runGroup(g) {
  const list = g === '全部' ? useCases : useCases.filter((c) => c.group === g)
  for (const c of list) await runCase(c)
}

async function runAll() {
  for (const c of useCases) await runCase(c)
  const ok = useCases.filter((c) => results[c.id]?.pass).length
  ElMessage.success(`全部用例执行完成：${ok}/${useCases.length} 通过`)
}

// 分组汇总统计
const groupStats = computed(() => {
  const map = {}
  for (const c of useCases) {
    if (!map[c.group]) map[c.group] = { total: 0, pass: 0 }
    map[c.group].total++
    if (results[c.id]?.pass) map[c.group].pass++
  }
  return map
})
</script>

<template>
  <div>
    <div class="page-card">
      <div class="toolbar">
        <el-radio-group :model-value="activeGroup" @update:model-value="filterGroup">
          <el-radio-button v-for="g in groups" :key="g" :value="g">{{ g }}</el-radio-button>
        </el-radio-group>
        <el-button type="primary" @click="runGroup(activeGroup)">运行本组</el-button>
        <el-button type="success" @click="runAll">运行全部</el-button>
      </div>
    </div>

    <div class="case-grid">
      <div class="page-card case" v-for="c in shownCases" :key="c.id">
        <div class="case-head">
          <el-tag size="small" type="info">{{ c.group }}</el-tag>
          <span class="case-name">{{ c.name }}</span>
          <el-tag
            v-if="results[c.id]?.running"
            size="small" type="warning" effect="dark" style="margin-left:auto">运行中</el-tag>
          <el-tag
            v-else-if="results[c.id]"
            :type="results[c.id].pass ? 'success' : 'danger'"
            size="small" effect="dark" style="margin-left:auto">
            {{ results[c.id].pass ? '通过' : '失败' }}
          </el-tag>
        </div>
        <div class="case-desc mono">{{ c.desc }}</div>
        <el-form label-width="0" size="small" style="margin-top:8px">
          <el-form-item v-for="f in c.fields" :key="f.k">
            <el-input v-model="f.value" :placeholder="f.ph" clearable>
              <template #prepend>{{ f.label }}</template>
            </el-input>
          </el-form-item>
        </el-form>
        <div class="case-actions">
          <el-button size="small" type="primary" :loading="results[c.id]?.running" @click="runCase(c)">执行</el-button>
        </div>
        <div v-if="results[c.id] && !results[c.id].running" class="case-result" :class="{ pass: results[c.id].pass }">
          <div class="mono">{{ results[c.id].detail }} · {{ results[c.id].ms }}ms</div>
        </div>
      </div>
    </div>

    <div class="page-card" v-if="activeGroup === '全部'">
      <h3>分组统计</h3>
      <div class="stat-grid">
        <div class="stat-box" v-for="(v, g) in groupStats" :key="g">
          <div class="num" :class="v.pass === v.total ? 'green' : 'orange'">{{ v.pass }}/{{ v.total }}</div>
          <div class="lbl">{{ g }}</div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.toolbar { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; }
.case-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 14px; }
.case { margin-bottom: 0; }
.case-head { display: flex; align-items: center; gap: 8px; }
.case-name { font-weight: 600; font-size: 14px; }
.case-desc { color: #909399; font-size: 12px; margin-top: 6px; }
.case-actions { display: flex; justify-content: flex-end; }
.case-result { margin-top: 8px; padding: 8px 10px; border-radius: 6px; background: #fef0f0; color: #f56c6c; font-size: 12px; word-break: break-all; }
.case-result.pass { background: #f0f9eb; color: #67c23a; }
</style>
