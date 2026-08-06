/**
 * FitQuant 测试台 — 接口函数（按后端 router 分组）
 * 覆盖后端全部 16 个现有端点 + 测试台扩展的 4 个管理端点
 */
import { get, post, put, del } from './client'

// ── 系统 ──
export const api = {
  health: () => get('/health', { raw: true }),
}

// ── 认证 / 账号管理 ──
export const authApi = {
  login: (phone, password, deviceId = 'test-web') =>
    post('/api/auth/login', { phone, password, device_id: deviceId }),
  register: ({ phone, password, nickname, identity }) =>
    post('/api/auth/register', { phone, password, nickname, identity }),
  // 测试台扩展（需后端补充）
  registerBatch: (items) => post('/api/auth/register-batch', { items }),
  listUsers: (keyword = '') => get(`/api/auth/users?keyword=${encodeURIComponent(keyword)}`),
  deleteUser: (userId) => del(`/api/auth/user/${userId}`),
  clearUserData: (userId) => del(`/api/users/${userId}/data`),
}

// ── 身体数据 ──
export const bodyApi = {
  upload: (payload) => put('/api/body', payload),
  latest: (userId) => get(`/api/body/latest?user_id=${encodeURIComponent(userId)}`),
  history: (userId, days = 30) => get(`/api/body/history?user_id=${encodeURIComponent(userId)}&days=${days}`),
}

// ── 补剂方案 ──
export const supplementApi = {
  plan: (payload) => post('/api/supplement-plan', payload),
}

// ── 食物识别 ──
export const foodApi = {
  recognize: (payload) => post('/api/food/recognize', payload),
}

// ── 用药 ──
export const drugApi = {
  list: (userId) => get(`/api/drug/list?user_id=${encodeURIComponent(userId)}`),
  lookup: (payload) => post('/api/drug/lookup', payload),
  riskCheck: (payload) => post('/api/drug/risk-check', payload),
}

// ── 训练分类 ──
export const workoutApi = {
  classify: (payload) => post('/api/workout/classify', payload),
}

// ── 数据同步（批量写入核心）──
export const syncApi = {
  batch: (payload) => post('/api/sync/batch', payload),
}

// ── 饮食 ──
export const mealApi = {
  today: (userId, mealDate) => {
    const q = mealDate ? `&meal_date=${encodeURIComponent(mealDate)}` : ''
    return get(`/api/meal/today?user_id=${encodeURIComponent(userId)}${q}`)
  },
}

// ── 训练 ──
export const trainingApi = {
  history: (userId, days = 30) => get(`/api/training/history?user_id=${encodeURIComponent(userId)}&days=${days}`),
}

// ── 睡眠 ──
export const sleepApi = {
  upload: (payload) => post('/api/sleep/records', payload),
  latest: (userId) => get(`/api/sleep/latest?user_id=${encodeURIComponent(userId)}`),
  history: (userId, days = 30) => get(`/api/sleep/history?user_id=${encodeURIComponent(userId)}&days=${days}`),
}
