<script setup>
import { ref, shallowRef, computed, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { healthCheck, connState, setUseProxy } from './api/client'

import ConnectionView from './views/ConnectionView.vue'
import AccountManageView from './views/AccountManageView.vue'
import DataInjectView from './views/DataInjectView.vue'
import FuncTestView from './views/FuncTestView.vue'
import PerfTestView from './views/PerfTestView.vue'
import ReportView from './views/ReportView.vue'

const views = {
  connection: { label: '连接配置', comp: ConnectionView, icon: 'Connection' },
  account: { label: '账号批量管理', comp: AccountManageView, icon: 'User' },
  inject: { label: '数据批量注入', comp: DataInjectView, icon: 'DataAnalysis' },
  functest: { label: '功能用例测试', comp: FuncTestView, icon: 'Check' },
  perf: { label: '并发压测', comp: PerfTestView, icon: 'Odometer' },
  report: { label: '测试报告', comp: ReportView, icon: 'Document' },
}

const active = ref('connection')
const currentComp = shallowRef(views.connection.comp)
const connOk = computed(() => connState.healthOk)

function switchView(key) {
  active.value = key
  currentComp.value = views[key].comp
}

onMounted(async () => {
  // 启动时自动做一次健康检查
  await healthCheck()
})
</script>

<template>
  <el-container class="layout">
    <el-aside width="220px" class="sidebar">
      <div class="logo">
        <el-icon :size="22"><Odometer /></el-icon>
        <span>FitQuant 测试台</span>
      </div>
      <el-menu :default-active="active" @select="switchView" class="menu">
        <el-menu-item v-for="(v, k) in views" :key="k" :index="k">
          <el-icon><component :is="v.icon" /></el-icon>
          <span>{{ v.label }}</span>
        </el-menu-item>
      </el-menu>
      <div class="conn-status" :class="{ ok: connOk }">
        <el-icon :size="14"><CircleCheck v-if="connOk" /><WarningFilled v-else /></el-icon>
        <span>{{ connOk ? '后端已连接' : '后端未连接' }}</span>
        <span class="sub">{{ connState.baseURL }}</span>
      </div>
    </el-aside>

    <el-main class="main">
      <component :is="currentComp" />
    </el-main>
  </el-container>
</template>

<style scoped>
.layout { height: 100vh; }
.sidebar {
  background: #1d2129;
  display: flex;
  flex-direction: column;
}
.logo {
  display: flex;
  align-items: center;
  gap: 8px;
  color: #fff;
  font-weight: 700;
  font-size: 16px;
  padding: 18px 16px;
  border-bottom: 1px solid rgba(255,255,255,0.08);
}
.menu {
  flex: 1;
  background: transparent;
  border-right: none;
  --el-menu-bg-color: transparent;
  --el-menu-text-color: #a8abb2;
  --el-menu-active-color: #409eff;
  --el-menu-hover-bg-color: rgba(255,255,255,0.06);
}
.conn-status {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 12px 16px;
  border-top: 1px solid rgba(255,255,255,0.08);
  color: #f56c6c;
  font-size: 12px;
}
.conn-status.ok { color: #67c23a; }
.conn-status .sub { color: #7a7e85; font-size: 11px; overflow: hidden; text-overflow: ellipsis; }
.main { background: #f5f7fa; padding: 20px; overflow-y: auto; }
</style>
