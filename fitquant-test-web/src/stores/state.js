/**
 * FitQuant 测试台 — 全局响应式状态
 * 账号池、当前选中账号、测试日志（跨页面共享）
 */
import { reactive } from 'vue'

export const appState = reactive({
  // 账号池：批量注册/登录成功的账号
  accounts: [],
  // 当前"测试目标账号"（功能测试/数据注入默认使用）
  currentUserId: '',
  currentPhone: '',
  // 全局测试日志（结果页展示）
  logs: [],
})

export function addAccount(acct) {
  // 按 user_id 去重
  if (!appState.accounts.some((a) => a.user_id === acct.user_id)) {
    appState.accounts.push(acct)
  }
  return acct
}

export function setCurrentAccount(acct) {
  appState.currentUserId = acct.user_id
  appState.currentPhone = acct.phone
}

export function clearAccounts() {
  appState.accounts = []
  appState.currentUserId = ''
  appState.currentPhone = ''
}

export function addLog(entry) {
  appState.logs.unshift({
    id: `${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
    at: new Date().toLocaleTimeString('zh-CN'),
    ...entry,
  })
  // 最多保留 500 条
  if (appState.logs.length > 500) appState.logs.length = 500
}

export function clearLogs() {
  appState.logs = []
}

/** 并发池执行器：把 tasks 按 concurrency 分批并发执行 */
export async function runPool(tasks, concurrency, onProgress) {
  const results = new Array(tasks.length)
  let idx = 0
  let done = 0
  const workers = Array.from({ length: Math.min(concurrency, tasks.length || 1) }, async () => {
    while (idx < tasks.length) {
      const i = idx++
      try {
        results[i] = await tasks[i]()
      } catch (e) {
        results[i] = { ok: false, error: e }
      }
      done++
      if (onProgress) onProgress(done, tasks.length)
    }
  })
  await Promise.all(workers)
  return results
}
