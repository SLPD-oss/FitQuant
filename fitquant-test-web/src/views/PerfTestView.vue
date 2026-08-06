<script setup>
import { ref, reactive, onMounted, onBeforeUnmount } from 'vue'
import { ElMessage } from 'element-plus'
import * as echarts from 'echarts'
import { authApi, bodyApi, mealApi, trainingApi, drugApi, sleepApi, syncApi, supplementApi } from '../api/modules'
import { appState, addLog } from '../stores/state'

// ── 压测配置 ──
const endpoints = [
  { label: '登录 POST /api/auth/login', fn: (c) => authApi.login(c.phone || '13800000001', '666666') },
  { label: '身体查询 GET /api/body/latest', fn: (c) => bodyApi.latest(c.userId) },
  { label: '身体上传 PUT /api/body', fn: (c) => bodyApi.upload({ height_cm: 170, weight_kg: 70, age: 25, sex: 'male', chest_cm: 92, waist_cm: 78, neck_cm: 38, hip_cm: 90, body_fat_percent: 20, activity_level: 'moderate', recorded_at: new Date().toISOString(), user_id: c.userId }) },
  { label: '饮食查询 GET /api/meal/today', fn: (c) => mealApi.today(c.userId) },
  { label: '训练查询 GET /api/training/history', fn: (c) => trainingApi.history(c.userId) },
  { label: '用药查询 GET /api/drug/list', fn: (c) => drugApi.list(c.userId) },
  { label: '睡眠查询 GET /api/sleep/latest', fn: (c) => sleepApi.latest(c.userId) },
  { label: '补剂方案 POST /api/supplement-plan', fn: () => supplementApi.plan({ height_cm: 170, weight_kg: 70, age: 25, sex: 'male', activity_level: 'moderate' }) },
  { label: 'sync/batch 空载荷', fn: (c) => syncApi.batch({ sync_mode: 'incremental', user_id: c.userId, body_data: [], meal_records: [], training_records: [], drug_records: [], deleted_drug_records: [], supplement_records: [], sleep_records: [] }) },
]

const form = reactive({
  endpoint: endpoints[0].label,
  concurrency: 10,
  total: 50,
  userId: appState.currentUserId,
  phone: '',
})

const running = ref(false)
const progress = reactive({ done: 0, total: 0 })
const stats = reactive({ success: 0, failed: 0, avgMs: 0, p50: 0, p95: 0, maxMs: 0 })
const timings = ref([]) // [{ms, ok}]

// ── ECharts ──
let chart = null
const chartEl = ref(null)

function renderChart() {
  if (!chartEl.value) return
  if (!chart) chart = echarts.init(chartEl.value)
  const data = timings.value.map((t, i) => [i, t.ms])
  chart.setOption({
    animation: false,
    tooltip: { trigger: 'axis', appendToBody: true },
    grid: { left: 56, right: 24, top: 24, bottom: 40 },
    xAxis: { type: 'category', name: '请求序号', nameTextStyle: { color: '#909399' }, axisLine: { lineStyle: { color: '#dcdfe6' } }, axisLabel: { color: '#606266' } },
    yAxis: { type: 'value', name: '耗时(ms)', nameTextStyle: { color: '#909399' }, splitLine: { lineStyle: { color: '#ebeef5' } }, axisLabel: { color: '#606266' } },
    series: [{
      type: 'line',
      data,
      symbol: 'circle',
      symbolSize: 4,
      lineStyle: { color: '#409eff', width: 1.5 },
      itemStyle: { color: (p) => (timings.value[p.dataIndex]?.ok ? '#67c23a' : '#f56c6c') },
    }],
  })
}

onMounted(() => {
  if (chartEl.value) {
    chart = echarts.init(chartEl.value)
    renderChart()
  }
})

onBeforeUnmount(() => { chart?.dispose() })

function percentil(list, p) {
  if (!list.length) return 0
  const sorted = [...list].sort((a, b) => a - b)
  const idx = Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1)
  return sorted[Math.max(0, idx)]
}

async function doBench() {
  if (!form.userId && form.endpoint.includes('GET') && form.endpoint !== '登录') {
    // 部分 GET 需要 userId
    if (form.endpoint !== '补剂方案' && form.endpoint !== '登录') {
      ElMessage.warning('请先选择测试账号（user_id 不能为空）')
      return
    }
  }
  const ep = endpoints.find((e) => e.label === form.endpoint)
  running.value = true
  timings.value = []
  Object.assign(stats, { success: 0, failed: 0, avgMs: 0, p50: 0, p95: 0, maxMs: 0 })
  progress.total = form.total
  progress.done = 0

  const ctx = { userId: form.userId, phone: form.phone }
  const workers = []
  let next = 0
  const times = []
  const worker = async () => {
    while (next < form.total) {
      const i = next++
      const t0 = performance.now()
      const r = await ep.fn(ctx)
      const ms = Math.round(performance.now() - t0)
      times.push(ms)
      timings.value.push({ ms, ok: r.ok })
      if (r.ok) stats.success++; else stats.failed++
      progress.done++
      if (progress.done % 5 === 0 || progress.done === form.total) renderChart()
    }
  }
  for (let i = 0; i < Math.min(form.concurrency, form.total); i++) workers.push(worker())
  await Promise.all(workers)

  const list = times
  stats.avgMs = list.length ? Math.round(list.reduce((a, b) => a + b, 0) / list.length) : 0
  stats.p50 = percentil(list, 50)
  stats.p95 = percentil(list, 95)
  stats.maxMs = list.length ? Math.max(...list) : 0
  renderChart()

  addLog({
    type: 'perf-test',
    title: `压测「${form.endpoint}」${form.total} 次 · 并发 ${form.concurrency}`,
    detail: `成功 ${stats.success} / 失败 ${stats.failed} · avg ${stats.avgMs}ms · p95 ${stats.p95}ms`,
  })
  running.value = false
  ElMessage.success(`压测完成：成功 ${stats.success}/${form.total}，avg ${stats.avgMs}ms，p95 ${stats.p95}ms`)
}
</script>

<template>
  <div>
    <div class="page-card">
      <h3>并发压测配置</h3>
      <el-form :inline="true" label-width="90px">
        <el-form-item label="接口">
          <el-select v-model="form.endpoint" style="width: 340px">
            <el-option v-for="e in endpoints" :key="e.label" :label="e.label" :value="e.label" />
          </el-select>
        </el-form-item>
        <el-form-item label="并发数">
          <el-input-number v-model="form.concurrency" :min="1" :max="200" />
        </el-form-item>
        <el-form-item label="总请求数">
          <el-input-number v-model="form.total" :min="1" :max="5000" />
        </el-form-item>
        <el-form-item label="user_id">
          <el-input v-model="form.userId" style="width: 260px" placeholder="当前测试账号 user_id" clearable />
        </el-form-item>
        <el-form-item label="手机号">
          <el-input v-model="form.phone" style="width: 150px" placeholder="登录用" clearable />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :loading="running" @click="doBench">
            <el-icon style="margin-right:4px"><Lightning /></el-icon>开始压测
          </el-button>
        </el-form-item>
      </el-form>
      <div class="hint">当前测试账号：<el-tag size="small" :type="appState.currentUserId ? 'success' : 'info'">{{ appState.currentPhone || '未选择' }}</el-tag></div>
    </div>

    <div class="page-card" v-if="progress.done > 0 || running">
      <h3>执行进度</h3>
      <el-progress :percentage="Math.round((progress.done / progress.total) * 100)" :stroke-width="12" />
      <div class="hint">{{ progress.done }}/{{ progress.total }}</div>
    </div>

    <div class="page-card" v-if="stats.success + stats.failed > 0">
      <h3>结果统计</h3>
      <div class="stat-grid">
        <div class="stat-box"><div class="num green">{{ stats.success }}</div><div class="lbl">成功</div></div>
        <div class="stat-box"><div class="num red">{{ stats.failed }}</div><div class="lbl">失败</div></div>
        <div class="stat-box"><div class="num">{{ stats.avgMs }}ms</div><div class="lbl">平均耗时</div></div>
        <div class="stat-box"><div class="num">{{ stats.p50 }}ms</div><div class="lbl">P50</div></div>
        <div class="stat-box"><div class="num orange">{{ stats.p95 }}ms</div><div class="lbl">P95</div></div>
        <div class="stat-box"><div class="num">{{ stats.maxMs }}ms</div><div class="lbl">最大耗时</div></div>
      </div>
    </div>

    <div class="page-card">
      <h3>耗时分布（绿=成功，红=失败）</h3>
      <div ref="chartEl" class="chart-box tall"></div>
    </div>
  </div>
</template>

<style scoped>
.hint { color: #909399; font-size: 12px; margin-top: 6px; }
</style>
