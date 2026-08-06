<script setup>
import { ref, reactive } from 'vue'
import { ElMessage } from 'element-plus'
import {
  connState, setBaseURL, setUseProxy, setTimeoutMs, healthCheck,
} from '../api/client'

const form = reactive({
  baseURL: connState.baseURL,
  useProxy: connState.useProxy,
  timeoutMs: connState.timeoutMs,
})

const checking = ref(false)

async function doCheck() {
  setBaseURL(form.baseURL.trim().replace(/\/+$/, ''))
  setUseProxy(form.useProxy)
  setTimeoutMs(Number(form.timeoutMs) || 10000)
  checking.value = true
  const r = await healthCheck()
  checking.value = false
  if (r.ok) {
    const info = r.data
    ElMessage.success(`后端连接正常（${info.service || 'FitQuant API'} v${info.version || '?'}）`)
  } else {
    ElMessage.error(`连接失败: ${r.message}`)
  }
}
</script>

<template>
  <div>
    <div class="page-card">
      <h3>后端连接配置</h3>
      <el-form label-width="110px" style="max-width: 640px">
        <el-form-item label="后端地址">
          <el-input v-model="form.baseURL" placeholder="http://127.0.0.1:8000" clearable />
          <div class="hint">开发代理关闭时直连该地址；开启代理时固定转发到 http://127.0.0.1:8000</div>
        </el-form-item>
        <el-form-item label="开发代理">
          <el-switch v-model="form.useProxy" />
          <div class="hint">开启：请求经 Vite 代理转发（推荐，规避跨域）；关闭：浏览器直连后端</div>
        </el-form-item>
        <el-form-item label="请求超时(ms)">
          <el-input-number v-model="form.timeoutMs" :min="1000" :max="120000" :step="1000" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :loading="checking" @click="doCheck">
            <el-icon style="margin-right:4px"><Connection /></el-icon>健康检查
          </el-button>
        </el-form-item>
      </el-form>
    </div>

    <div class="page-card">
      <h3>后端状态</h3>
      <div class="stat-grid">
        <div class="stat-box">
          <div class="num" :class="connState.healthOk ? 'green' : 'red'">
            {{ connState.healthOk ? '在线' : '离线' }}
          </div>
          <div class="lbl">连接状态</div>
        </div>
        <div class="stat-box">
          <div class="num">{{ connState.backendInfo?.version || '-' }}</div>
          <div class="lbl">后端版本</div>
        </div>
        <div class="stat-box">
          <div class="num">{{ connState.backendInfo?.service || '-' }}</div>
          <div class="lbl">服务名</div>
        </div>
        <div class="stat-box">
          <div class="num">{{ connState.lastCheckedAt || '-' }}</div>
          <div class="lbl">最近检查</div>
        </div>
      </div>

      <el-alert
        v-if="connState.healthOk"
        type="success"
        :closable="false"
        show-icon
        title="后端已连接，可开始测试"
        description="下一步建议：进入「账号批量管理」注册测试账号。"
        style="margin-top:8px"
      />
      <el-alert
        v-else
        type="warning"
        :closable="false"
        show-icon
        title="后端未连接"
        description="请确认后端已启动（uvicorn app.main:app --reload），并检查地址与代理配置。"
        style="margin-top:8px"
      />
    </div>
  </div>
</template>

<style scoped>
.hint { color: #909399; font-size: 12px; line-height: 1.5; margin-top: 4px; width: 100%; }
</style>
