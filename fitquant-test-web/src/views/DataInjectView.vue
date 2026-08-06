<script setup>
import { ref, reactive } from 'vue'
import { ElMessage } from 'element-plus'
import { syncApi, bodyApi, sleepApi } from '../api/modules'
import { appState, addLog } from '../stores/state'

// ── 注入配置 ──
const injectForm = reactive({
  targetUserId: appState.currentUserId,
  bodyCount: 1,
  mealCount: 5,
  trainingCount: 5,
  drugCount: 3,
  sleepCount: 3,
  useSyncBatch: true, // true=走 sync/batch，false=走单接口
})

const injecting = ref(false)
const lastResult = ref(null)

// 随机辅助
const rand = (min, max, digits = 1) => Number((min + Math.random() * (max - min)).toFixed(digits))
const iso = (d) => d.toISOString().replace('.000Z', 'Z')
const dayAgo = (n) => new Date(Date.now() - n * 86400000)

const MEALS = ['鸡胸肉', '米饭', '西兰花', '鸡蛋', '三文鱼', '燕麦', '牛奶', '香蕉', '豆腐', '红薯']
const EXERCISES = ['深蹲', '卧推', '硬拉', '引体向上', '跑步', '划船', '肩推', '卷腹']
const DRUGS = [
  { name: '布洛芬', category: 'typeA', dosage: '200', unit: 'mg', frequency: '必要时服用' },
  { name: '左氧氟沙星', category: 'typeB', dosage: '500', unit: 'mg', frequency: '每日1次' },
  { name: '维生素C', category: 'typeA', dosage: '100', unit: 'mg', frequency: '每日1次' },
]
const MEAL_TYPES = ['breakfast', 'lunch', 'dinner', 'snack']
const SLEEP_STATUS = ['good', 'mild', 'severe']

function buildPayload() {
  const uid = injectForm.targetUserId
  const payload = {
    sync_mode: 'full',
    user_id: uid,
    body_data: [],
    meal_records: [],
    training_records: [],
    drug_records: [],
    deleted_drug_records: [],
    clear_all_drugs: false,
    supplement_records: [],
    sleep_records: [],
  }

  for (let i = 0; i < injectForm.bodyCount; i++) {
    payload.body_data.push({
      recorded_at: iso(dayAgo(i)),
      weight_kg: rand(60, 85),
      body_fat_percent: rand(12, 28),
      waist_cm: rand(70, 95),
      height_cm: rand(165, 185, 0),
      age: rand(20, 45, 0),
      sex: Math.random() > 0.5 ? 'male' : 'female',
      chest_cm: rand(85, 105),
      neck_cm: rand(35, 42),
      hip_cm: rand(85, 100),
      activity_level: ['sedentary', 'light', 'moderate', 'active'][rand(0, 3, 0)],
    })
  }

  for (let i = 0; i < injectForm.mealCount; i++) {
    payload.meal_records.push({
      recorded_at: iso(dayAgo(rand(0, 6, 0))),
      meal_type: MEAL_TYPES[rand(0, MEAL_TYPES.length - 1, 0)],
      food_name: MEALS[rand(0, MEALS.length - 1, 0)],
      protein_g: rand(5, 40),
      fat_g: rand(2, 25),
      carbs_g: rand(10, 60),
      fiber_g: rand(1, 8),
      kcal: rand(100, 600, 0),
    })
  }

  for (let i = 0; i < injectForm.trainingCount; i++) {
    payload.training_records.push({
      recorded_at: iso(dayAgo(rand(0, 13, 0))),
      exercise_name: EXERCISES[rand(0, EXERCISES.length - 1, 0)],
      training_type: 'strength',
      sets: rand(3, 5, 0),
      reps: rand(8, 15, 0),
      weight_kg: rand(20, 80),
      duration_minutes: rand(30, 90, 0),
      estimated_kcal: rand(150, 500, 0),
    })
  }

  for (let i = 0; i < injectForm.drugCount; i++) {
    const d = DRUGS[i % DRUGS.length]
    payload.drug_records.push({
      record_id: `test_drug_${Date.now()}_${i}`,
      recorded_at: iso(dayAgo(rand(0, 6, 0))),
      drug_name: d.name,
      category: d.category,
      status: i === 0 ? 'viewing' : 'syncing',
      dosage: d.dosage,
      unit: d.unit,
      frequency: d.frequency,
    })
  }

  for (let i = 0; i < injectForm.sleepCount; i++) {
    const total = rand(5, 9)
    payload.sleep_records.push({
      sleep_date: dayAgo(rand(0, 6, 0)).toISOString().slice(0, 10),
      total_sleep_hours: total,
      core_sleep_hours: rand(3, 5),
      deep_sleep_hours: rand(0.5, 2),
      rem_sleep_hours: rand(1, 2.5),
      awake_hours: rand(0, 1.5),
      resting_heart_rate: rand(55, 75, 0),
      avg_hrv: rand(30, 70, 0),
      source: 'test-web',
    })
  }
  return payload
}

async function doInject() {
  if (!injectForm.targetUserId) {
    ElMessage.warning('请先在「账号批量管理」选择测试账号（user_id 不能为空）')
    return
  }
  injecting.value = true
  lastResult.value = null
  try {
    const payload = buildPayload()
    let r
    if (injectForm.useSyncBatch) {
      r = await syncApi.batch(payload)
    } else {
      // 单接口模式：身体走 PUT /api/body，睡眠走 POST /api/sleep/records
      const b = payload.body_data[0]
      if (b) await bodyApi.upload({ ...b, user_id: injectForm.targetUserId })
      for (const s of payload.sleep_records) {
        await sleepApi.upload({ ...s, user_id: injectForm.targetUserId })
      }
      r = { ok: true, message: '单接口模式已提交（身体+睡眠）', data: null }
    }
    lastResult.value = r
    addLog({
      type: 'data-inject',
      title: `数据注入 → ${injectForm.targetUserId}`,
      detail: r.ok ? `身体${payload.body_data.length} 饮食${payload.meal_records.length} 训练${payload.training_records.length} 用药${payload.drug_records.length} 睡眠${payload.sleep_records.length}` : r.message,
    })
    if (r.ok) ElMessage.success(`注入完成：身体${payload.body_data.length} 饮食${payload.meal_records.length} 训练${payload.training_records.length} 用药${payload.drug_records.length} 睡眠${payload.sleep_records.length}`)
    else ElMessage.error(`注入失败: ${r.message}`)
  } finally {
    injecting.value = false
  }
}
</script>

<template>
  <div>
    <div class="page-card">
      <h3>目标账号</h3>
      <el-form :inline="true">
        <el-form-item label="user_id">
          <el-input v-model="injectForm.targetUserId" style="width: 380px" placeholder="当前测试账号的 user_id（未选择时请手动填写）" clearable />
        </el-form-item>
        <el-form-item label="当前账号">
          <el-tag v-if="appState.currentUserId" type="success">{{ appState.currentPhone }}</el-tag>
          <el-tag v-else type="info">未选择</el-tag>
        </el-form-item>
      </el-form>
    </div>

    <div class="page-card">
      <h3>批量生成数据</h3>
      <el-form :inline="true" label-width="100px">
        <el-form-item label="身体数据">
          <el-input-number v-model="injectForm.bodyCount" :min="0" :max="100" />
        </el-form-item>
        <el-form-item label="饮食记录">
          <el-input-number v-model="injectForm.mealCount" :min="0" :max="500" />
        </el-form-item>
        <el-form-item label="训练记录">
          <el-input-number v-model="injectForm.trainingCount" :min="0" :max="500" />
        </el-form-item>
        <el-form-item label="用药记录">
          <el-input-number v-model="injectForm.drugCount" :min="0" :max="200" />
        </el-form-item>
        <el-form-item label="睡眠记录">
          <el-input-number v-model="injectForm.sleepCount" :min="0" :max="100" />
        </el-form-item>
        <el-form-item label="提交方式">
          <el-radio-group v-model="injectForm.useSyncBatch">
            <el-radio :value="true">sync/batch（推荐）</el-radio>
            <el-radio :value="false">单接口</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :loading="injecting" @click="doInject">
            <el-icon style="margin-right:4px"><MagicStick /></el-icon>生成并注入
          </el-button>
        </el-form-item>
      </el-form>
      <div class="hint">数据为随机生成：身体（体重/体脂/围度）、饮食（4 餐随机食物）、训练（8 种动作）、用药（3 种模板药物）、睡眠（3 天记录）。</div>
    </div>

    <div class="page-card" v-if="lastResult">
      <h3>注入结果</h3>
      <el-alert
        :type="lastResult.ok ? 'success' : 'error'"
        :closable="false"
        show-icon
        :title="lastResult.ok ? '提交成功' : '提交失败'"
        :description="lastResult.message"
      />
      <template v-if="lastResult.data?.stats">
        <div class="stat-grid">
          <div class="stat-box" v-for="(v, k) in lastResult.data.stats" :key="k">
            <div class="num green">{{ v }}</div>
            <div class="lbl">{{ k }}</div>
          </div>
        </div>
      </template>
    </div>
  </div>
</template>

<style scoped>
.hint { color: #909399; font-size: 12px; margin-top: 6px; }
</style>
