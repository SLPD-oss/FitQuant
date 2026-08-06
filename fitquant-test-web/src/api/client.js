/**
 * FitQuant 测试台 — API 客户端
 * 统一封装 fetch：baseURL、超时、错误处理、{code,message,data} 解包
 */
import { reactive } from 'vue'

// 全局连接状态（跨页面共享，保存在 sessionStorage 持久化）
export const connState = reactive({
  baseURL: localStorage.getItem('fq_base_url') || 'http://127.0.0.1:8000',
  useProxy: localStorage.getItem('fq_use_proxy') !== '0', // 默认走 Vite 代理
  timeoutMs: Number(localStorage.getItem('fq_timeout') || 10000),
  backendInfo: null, // /health 返回
  healthOk: false,
  lastCheckedAt: null,
})

export function setBaseURL(url) {
  connState.baseURL = url
  localStorage.setItem('fq_base_url', url)
}

export function setUseProxy(v) {
  connState.useProxy = v
  localStorage.setItem('fq_use_proxy', v ? '1' : '0')
}

export function setTimeoutMs(ms) {
  connState.timeoutMs = ms
  localStorage.setItem('fq_timeout', String(ms))
}

/** 计算实际请求基地址：走代理时用相对路径 /api，否则用后端直连地址 */
function resolveBase() {
  if (connState.useProxy) return ''
  return connState.baseURL
}

/**
 * 发起请求
 * @param {string} method GET/POST/PUT/DELETE
 * @param {string} path 形如 /api/auth/login
 * @param {object} [body] 请求体（JSON）
 * @param {object} [opts] { timeout, raw } raw=true 时不解包 {code,message,data}，返回原始 JSON
 * @returns {Promise<{ok:boolean, data:any, message:string, httpStatus:number, ms:number, raw:any}>}
 */
export async function request(method, path, body, opts = {}) {
  const timeout = opts.timeout || connState.timeoutMs
  const base = resolveBase()
  const url = `${base}${path}`
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), timeout)
  const started = performance.now()

  try {
    const resp = await fetch(url, {
      method,
      headers: body !== undefined ? { 'Content-Type': 'application/json' } : {},
      body: body !== undefined ? JSON.stringify(body) : undefined,
      signal: controller.signal,
    })
    const ms = Math.round(performance.now() - started)
    let raw = null
    try {
      raw = await resp.json()
    } catch {
      raw = { text: await resp.text().catch(() => '') }
    }

    if (opts.raw) {
      return { ok: resp.ok, data: raw, message: '', httpStatus: resp.status, ms, raw }
    }

    // 统一包装 { code, message, data }
    if (raw && typeof raw === 'object' && 'code' in raw) {
      const ok = raw.code === 0
      return {
        ok,
        code: raw.code,
        data: raw.data,
        message: raw.message || (ok ? 'ok' : '请求失败'),
        httpStatus: resp.status,
        ms,
        raw,
      }
    }
    return { ok: resp.ok, data: raw, message: resp.ok ? 'ok' : `HTTP ${resp.status}`, httpStatus: resp.status, ms, raw }
  } catch (e) {
    const ms = Math.round(performance.now() - started)
    const aborted = e.name === 'AbortError'
    return {
      ok: false,
      data: null,
      message: aborted ? `请求超时（>${timeout}ms）` : `网络错误: ${e.message}`,
      httpStatus: 0,
      ms,
      raw: null,
    }
  } finally {
    clearTimeout(timer)
  }
}

export const get = (path, opts) => request('GET', path, undefined, opts)
export const post = (path, body, opts) => request('POST', path, body, opts)
export const put = (path, body, opts) => request('PUT', path, body, opts)
export const del = (path, body, opts) => request('DELETE', path, body, opts)

/** 健康检查 */
export async function healthCheck() {
  const r = await get('/health', { raw: true })
  connState.backendInfo = r.ok ? r.data : null
  connState.healthOk = r.ok
  connState.lastCheckedAt = new Date().toLocaleTimeString('zh-CN')
  return r
}
