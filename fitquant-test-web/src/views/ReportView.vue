<script setup>
import { computed } from 'vue'
import { ElMessage } from 'element-plus'
import { appState, clearLogs, addLog } from '../stores/state'

const logs = computed(() => appState.logs)
const accounts = computed(() => appState.accounts)

const typeStats = computed(() => {
  const map = {}
  for (const l of logs.value) {
    map[l.type] = (map[l.type] || 0) + 1
  }
  return map
})

const funcPass = computed(() => {
  const fs = logs.value.filter((l) => l.type === 'func-test')
  const pass = fs.filter((l) => l.title.includes('通过')).length
  return { total: fs.length, pass }
})

function copyLogs() {
  const text = logs.value
    .map((l) => `[${l.at}] ${l.title} — ${l.detail || ''}`)
    .join('\n')
  if (!text) { ElMessage.warning('暂无日志'); return }
  navigator.clipboard.writeText(text).then(
    () => ElMessage.success('日志已复制到剪贴板'),
    () => ElMessage.error('复制失败'),
  )
}

function exportJson() {
  const blob = new Blob([JSON.stringify({ accounts: accounts.value, logs: logs.value }, null, 2)], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `fitquant-test-report-${Date.now()}.json`
  a.click()
  URL.revokeObjectURL(url)
}

function clearAll() {
  clearLogs()
  ElMessage.success('日志已清空')
}

function buildCurl(type) {
  const tpls = {
    'batch-register': 'curl -X POST http://127.0.0.1:8000/api/auth/register -H "Content-Type: application/json" -d \'{"phone":"13900000001","password":"123456"}\'',
    'delete-account': 'curl -X DELETE http://127.0.0.1:8000/api/auth/user/<user_id>',
    'data-inject': 'curl -X POST http://127.0.0.1:8000/api/sync/batch -H "Content-Type: application/json" -d \'{"sync_mode":"full","user_id":"<user_id>","body_data":[]}\'',
    'func-test': 'curl http://127.0.0.1:8000/health',
  }
  const all = Object.entries(tpls)
    .map(([k, v]) => `# ${k}\n${v}`)
    .join('\n\n')
  if (type === 'all') return all
  return tpls[type] || '// 无对应模板'
}

const curlText = computed(() => buildCurl('all'))
</script>

<template>
  <div>
    <div class="page-card">
      <h3>测试概览</h3>
      <div class="stat-grid">
        <div class="stat-box"><div class="num">{{ accounts.length }}</div><div class="lbl">账号池</div></div>
        <div class="stat-box"><div class="num">{{ funcPass.total }}</div><div class="lbl">功能用例总数</div></div>
        <div class="stat-box"><div class="num green">{{ funcPass.pass }}</div><div class="lbl">用例通过</div></div>
        <div class="stat-box"><div class="num orange">{{ funcPass.total - funcPass.pass }}</div><div class="lbl">用例失败</div></div>
        <div class="stat-box"><div class="num">{{ logs.length }}</div><div class="lbl">日志总数</div></div>
      </div>
    </div>

    <div class="page-card">
      <h3>日志类型分布</h3>
      <div class="stat-grid">
        <div class="stat-box" v-for="(v, k) in typeStats" :key="k">
          <div class="num">{{ v }}</div>
          <div class="lbl">{{ k }}</div>
        </div>
      </div>
    </div>

    <div class="page-card">
      <div class="toolbar">
        <h3 style="margin:0">执行日志（{{ logs.length }}）</h3>
        <div style="margin-left:auto; display:flex; gap:8px">
          <el-button size="small" @click="copyLogs">复制日志</el-button>
          <el-button size="small" @click="exportJson">导出 JSON</el-button>
          <el-button size="small" type="danger" plain @click="clearAll">清空日志</el-button>
        </div>
      </div>
      <el-table :data="logs" border stripe style="margin-top:12px" max-height="420">
        <el-table-column prop="at" label="时间" width="90" />
        <el-table-column prop="type" label="类型" width="130">
          <template #default="{ row }">
            <el-tag size="small" type="info">{{ row.type }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="title" label="标题" min-width="220" show-overflow-tooltip />
        <el-table-column prop="detail" label="详情" min-width="260" show-overflow-tooltip />
      </el-table>
    </div>

    <div class="page-card">
      <h3>常用 curl 模板（复制到终端执行）</h3>
      <pre class="curl-pre">{{ curlText }}</pre>
    </div>
  </div>
</template>

<style scoped>
.toolbar { display: flex; align-items: center; gap: 12px; }
.curl-pre {
  background: #1d2129;
  color: #d6e4f5;
  border-radius: 8px;
  padding: 14px 16px;
  font-size: 12.5px;
  line-height: 1.7;
  overflow-x: auto;
  white-space: pre;
}
</style>
