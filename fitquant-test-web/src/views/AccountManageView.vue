<script setup>
import { ref, reactive, computed } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { authApi } from '../api/modules'
import { appState, addAccount, setCurrentAccount, addLog } from '../stores/state'
import { runPool } from '../stores/state'

// ── 批量注册表单 ──
const regForm = reactive({
  phonePrefix: '139',
  phoneStart: 10000001,
  count: 10,
  password: '123456',
  identity: 'enthusiast',
  concurrency: 5,
  nicknameMode: 'auto', // auto / phone
})

const registering = ref(false)
const regProgress = reactive({ done: 0, total: 0 })
const regStats = reactive({ success: 0, failed: 0, duplicate: 0 })

/** 由前缀+起始序号生成 11 位手机号 */
function buildPhones(prefix, start, count) {
  const phones = []
  for (let i = 0; i < count; i++) {
    const seq = start + i
    const phone = `${prefix}${String(seq).padStart(11 - prefix.length, '0')}`
    phones.push(phone.slice(0, 11))
  }
  return phones
}

async function doRegisterBatch() {
  const { phonePrefix, phoneStart, count, password, identity, concurrency } = regForm
  if (count < 1 || count > 500) {
    ElMessage.warning('单次注册数量建议 1-500')
    return
  }
  registering.value = true
  Object.assign(regStats, { success: 0, failed: 0, duplicate: 0 })
  regProgress.total = count
  regProgress.done = 0

  const phones = buildPhones(phonePrefix, phoneStart, count)
  const tasks = phones.map((phone) => async () => {
    const r = await authApi.register({
      phone,
      password,
      identity,
      nickname: regForm.nicknameMode === 'phone' ? `用户${phone.slice(-4)}` : '',
    })
    if (r.ok && r.data?.user) {
      const user = r.data.user
      addAccount({ user_id: user.user_id, phone, nickname: user.nickname, identity: user.identity, token: r.data.token, source: '批量注册' })
      regStats.success++
      return { ok: true, phone }
    }
    if (r.raw?.code === 1003) {
      regStats.duplicate++
      return { ok: true, phone, dup: true }
    }
    regStats.failed++
    return { ok: false, phone, message: r.message }
  })

  await runPool(tasks, concurrency, (done, total) => {
    regProgress.done = done
  })

  registering.value = false
  addLog({
    type: 'batch-register',
    title: `批量注册 ${count} 个账号`,
    detail: `成功 ${regStats.success} / 重复 ${regStats.duplicate} / 失败 ${regStats.failed}`,
  })
  ElMessage.success(`批量注册完成：成功 ${regStats.success}，重复 ${regStats.duplicate}，失败 ${regStats.failed}`)
}

// ── 账号池 ──
const keyword = ref('')
const filteredAccounts = computed(() => {
  if (!keyword.value) return appState.accounts
  const k = keyword.value.toLowerCase()
  return appState.accounts.filter(
    (a) => a.phone.includes(k) || a.user_id.toLowerCase().includes(k) || (a.nickname || '').toLowerCase().includes(k),
  )
})

const deleting = ref(false)

async function deleteAccount(row) {
  try {
    await ElMessageBox.confirm(`确认删除账号 ${row.phone}（${row.user_id}）？将级联删除其全部业务数据。`, '删除账号', {
      type: 'warning', confirmButtonText: '删除', cancelButtonText: '取消',
    })
  } catch { return }
  deleting.value = true
  const r = await authApi.deleteUser(row.user_id)
  deleting.value = false
  if (r.ok) {
    appState.accounts = appState.accounts.filter((a) => a.user_id !== row.user_id)
    if (appState.currentUserId === row.user_id) { appState.currentUserId = ''; appState.currentPhone = '' }
    addLog({ type: 'delete-account', title: `删除账号 ${row.phone}`, detail: r.message })
    ElMessage.success('账号已删除')
  } else {
    ElMessage.error(`删除失败: ${r.message}`)
  }
}

async function deleteSelected(rows) {
  if (!rows.length) { ElMessage.warning('请先勾选账号'); return }
  try {
    await ElMessageBox.confirm(`确认删除选中的 ${rows.length} 个账号？`, '批量删除', { type: 'warning', confirmButtonText: '删除', cancelButtonText: '取消' })
  } catch { return }
  deleting.value = true
  let ok = 0, fail = 0
  for (const row of rows) {
    const r = await authApi.deleteUser(row.user_id)
    if (r.ok) ok++; else fail++
  }
  deleting.value = false
  appState.accounts = appState.accounts.filter((a) => !rows.some((r) => r.user_id === a.user_id))
  addLog({ type: 'delete-accounts', title: `批量删除 ${rows.length} 个账号`, detail: `成功 ${ok} / 失败 ${fail}` })
  ElMessage.success(`批量删除完成：成功 ${ok}，失败 ${fail}`)
}

async function clearUserData(row) {
  try {
    await ElMessageBox.confirm(`确认清空账号 ${row.phone} 的全部业务数据（保留账号）？`, '清空数据', { type: 'warning' })
  } catch { return }
  const r = await authApi.clearUserData(row.user_id)
  if (r.ok) {
    addLog({ type: 'clear-data', title: `清空账号 ${row.phone} 数据`, detail: r.message })
    ElMessage.success('业务数据已清空')
  } else {
    ElMessage.error(`清空失败: ${r.message}`)
  }
}

function useAccount(row) {
  setCurrentAccount(row)
  addLog({ type: 'use-account', title: `切换测试账号 ${row.phone}`, detail: row.user_id })
  ElMessage.success(`已切换测试账号：${row.phone}`)
}

// ── 单账号注册 / 登录 ──
const singleForm = reactive({ phone: '', password: '666666' })

async function doLogin() {
  if (!/^\d{11}$/.test(singleForm.phone)) { ElMessage.warning('请输入 11 位手机号'); return }
  const r = await authApi.login(singleForm.phone, singleForm.password)
  if (r.ok && r.data?.user) {
    addAccount({ user_id: r.data.user.user_id, phone: singleForm.phone, nickname: r.data.user.nickname, identity: r.data.user.identity, token: r.data.token, source: '登录' })
    setCurrentAccount(r.data.user)
    ElMessage.success('登录成功，账号已加入池')
  } else {
    ElMessage.error(`登录失败: ${r.message}`)
  }
}

async function doRegister() {
  if (!/^\d{11}$/.test(singleForm.phone)) { ElMessage.warning('请输入 11 位手机号'); return }
  const r = await authApi.register({ phone: singleForm.phone, password: singleForm.password })
  if (r.ok && r.data?.user) {
    addAccount({ user_id: r.data.user.user_id, phone: singleForm.phone, nickname: r.data.user.nickname, identity: r.data.user.identity, token: r.data.token, source: '注册' })
    setCurrentAccount(r.data.user)
    ElMessage.success('注册成功，账号已加入池')
  } else {
    ElMessage.error(`注册失败: ${r.message}`)
  }
}

// 多选表格
const selectedRows = ref([])
const tableRef = ref()
</script>

<template>
  <div>
    <!-- 批量注册 -->
    <div class="page-card">
      <h3>批量注册账号</h3>
      <el-form :inline="true" label-width="90px">
        <el-form-item label="手机号前缀">
          <el-input v-model="regForm.phonePrefix" style="width: 110px" placeholder="139" maxlength="3" />
        </el-form-item>
        <el-form-item label="起始序号">
          <el-input-number v-model="regForm.phoneStart" :min="1" :max="999999999" style="width: 150px" />
        </el-form-item>
        <el-form-item label="数量">
          <el-input-number v-model="regForm.count" :min="1" :max="500" style="width: 130px" />
        </el-form-item>
        <el-form-item label="密码">
          <el-input v-model="regForm.password" style="width: 130px" placeholder="至少6位" />
        </el-form-item>
        <el-form-item label="身份">
          <el-select v-model="regForm.identity" style="width: 130px">
            <el-option label="enthusiast" value="enthusiast" />
            <el-option label="beginner" value="beginner" />
            <el-option label="coach" value="coach" />
          </el-select>
        </el-form-item>
        <el-form-item label="并发数">
          <el-input-number v-model="regForm.concurrency" :min="1" :max="50" style="width: 110px" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :loading="registering" @click="doRegisterBatch">
            <el-icon style="margin-right:4px"><Plus /></el-icon>批量注册
          </el-button>
        </el-form-item>
      </el-form>

      <div v-if="registering" style="margin-top:8px">
        <el-progress :percentage="Math.round((regProgress.done / regProgress.total) * 100)" :stroke-width="10" />
        <div class="hint">
          进度 {{ regProgress.done }}/{{ regProgress.total }} · 成功 <span class="ok">{{ regStats.success }}</span> ·
          重复 <span class="warn">{{ regStats.duplicate }}</span> · 失败 <span class="bad">{{ regStats.failed }}</span>
        </div>
      </div>
      <div class="hint">手机号 = 前缀 + 起始序号递增（自动补 0 到 11 位）。重复手机号会返回 code=1003，计入"重复"。</div>
    </div>

    <!-- 单账号 -->
    <div class="page-card">
      <h3>单个账号注册 / 登录（加入账号池）</h3>
      <el-form :inline="true">
        <el-form-item label="手机号">
          <el-input v-model="singleForm.phone" style="width: 180px" maxlength="11" placeholder="11位手机号" />
        </el-form-item>
        <el-form-item label="密码">
          <el-input v-model="singleForm.password" style="width: 150px" show-password />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" plain @click="doRegister">注册</el-button>
          <el-button @click="doLogin">登录</el-button>
        </el-form-item>
      </el-form>
    </div>

    <!-- 账号池 -->
    <div class="page-card">
      <h3>账号池（{{ appState.accounts.length }}）</h3>
      <div class="toolbar">
        <el-input v-model="keyword" placeholder="按手机号 / user_id / 昵称过滤" clearable style="width: 260px" />
        <el-button type="danger" plain :loading="deleting" @click="deleteSelected(selectedRows)">
          <el-icon style="margin-right:4px"><Delete /></el-icon>批量删除选中
        </el-button>
      </div>

      <el-table :data="filteredAccounts" border stripe style="margin-top:12px" max-height="480" @selection-change="selectedRows = $event">
        <el-table-column type="selection" width="44" />
        <el-table-column prop="phone" label="手机号" width="130" />
        <el-table-column prop="user_id" label="user_id" min-width="220" show-overflow-tooltip />
        <el-table-column prop="nickname" label="昵称" width="110" />
        <el-table-column prop="identity" label="身份" width="110" />
        <el-table-column prop="source" label="来源" width="90" />
        <el-table-column label="当前" width="80" align="center">
          <template #default="{ row }">
            <el-tag v-if="appState.currentUserId === row.user_id" type="success" size="small">使用中</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="230" fixed="right">
          <template #default="{ row }">
            <el-button size="small" type="primary" plain @click="useAccount(row)">设为测试账号</el-button>
            <el-button size="small" @click="clearUserData(row)">清数据</el-button>
            <el-button size="small" type="danger" plain @click="deleteAccount(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </div>
  </div>
</template>

<style scoped>
.hint { color: #909399; font-size: 12px; margin-top: 6px; }
.hint .ok { color: #67c23a; font-weight: 600; }
.hint .warn { color: #e6a23c; font-weight: 600; }
.hint .bad { color: #f56c6c; font-weight: 600; }
.toolbar { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; }
</style>
