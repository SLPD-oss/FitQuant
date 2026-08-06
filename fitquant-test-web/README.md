# FitQuant 后端测试台（fitquant-test-web）

面向 FitQuant FastAPI 后端的可视化批量测试工具：批量注册/删除账号、数据批量注入、功能用例测试、并发压测、测试报告，无需手写 curl。

## 技术栈

| 组件 | 版本 | 用途 |
|------|------|------|
| Vite | 8.x | 构建 / 开发服务器 |
| Vue | 3.5 | 前端框架 |
| Element Plus | 2.14 | UI 组件库（表格/表单/弹窗） |
| ECharts | 6.x | 压测耗时分布图 |

纯前端项目，无服务端依赖；通过 Vite 开发代理或后端 CORS 直连 FastAPI。

## 目录结构

```
fitquant-test-web/
├── index.html                 # 入口 HTML
├── vite.config.js             # Vite 配置（含 /api 开发代理 → 127.0.0.1:8000）
├── package.json
└── src/
    ├── main.js                # 应用入口（Element Plus + 图标注册）
    ├── App.vue                # 侧边导航 + 页面容器
    ├── style.css              # 全局样式
    ├── api/
    │   ├── client.js          # fetch 封装：baseURL/超时/统一 {code,message,data} 解包
    │   └── modules.js         # 按后端 router 分组的接口函数
    ├── stores/
    │   └── state.js           # 全局状态：账号池/当前账号/日志 + 并发池执行器
    └── views/
        ├── ConnectionView.vue     # 连接配置 + 健康检查
        ├── AccountManageView.vue  # 账号批量管理（注册/删除/账号池）
        ├── DataInjectView.vue     # 数据批量注入（sync/batch）
        ├── FuncTestView.vue       # 功能用例测试（15 用例 / 8 板块）
        ├── PerfTestView.vue       # 并发压测（成功率/耗时统计/分布图）
        └── ReportView.vue         # 测试报告（日志/统计/curl 模板）
```

## 快速开始

### 1. 安装依赖

```bash
cd fitquant-test-web
npm install
```

> 要求 Node.js ≥ 18（建议 20+）。

### 2. 启动开发服务器

```bash
npm run dev
```

默认地址：<http://localhost:5173/>

### 3. 启动后端（被测对象）

```bash
cd ../backend
pip install -r requirements.txt
# 可选：初始化数据库（需先启动 MySQL 并创建 fitquant_db）
mysql -u root < ../sql/init.sql
uvicorn app.main:app --reload
```

默认地址：<http://127.0.0.1:8000/>

### 4. 连接测试台与后端

打开测试台 → 「连接配置」页：

- **后端地址**：`http://127.0.0.1:8000`（默认）
- **开发代理**：默认开启，请求经 Vite 代理转发到后端，规避跨域；若后端部署在别的机器，可关闭代理并填写完整地址（后端已开 CORS `allow_origins=["*"]`，可直连）
- 点击 **健康检查**，显示「后端已连接」即完成。

## 功能模块说明

### 连接配置

配置后端地址、开发代理开关、请求超时，健康检查后端连通性，实时显示连接状态。

### 账号批量管理

- **批量注册**：手机号前缀 + 起始序号 + 数量 + 密码 + 身份 + 并发数。手机号 = 前缀 + 序号递增补 0 到 11 位。重复手机号返回 `code=1003` 计入"重复"，不中断批量。
- **身份取值**：`enthusiast` / `beginner` / `coach`（与后端 users 表 `identity` 枚举严格一致，传其他值会写入失败）。
- **账号池**：注册/登录成功的账号自动入池，可按手机号 / user_id / 昵称过滤。
- **设为测试账号**：功能测试、数据注入、压测默认使用该账号的 user_id。
- **清数据 / 删除**：分别调用后端扩展接口清空业务数据、删除账号（需后端已实现，见下文「后端补充接口」）。

### 数据批量注入

选择测试账号后，按身体 / 饮食 / 训练 / 用药 / 睡眠分别设置生成数量，随机生成数据并提交：

- **sync/batch（推荐）**：一次请求携带全部板块数据，返回各板块写入统计。
- **单接口**：身体走 `PUT /api/body`，睡眠走 `POST /api/sleep/records`。

### 功能用例测试

15 个用例覆盖 8 大板块（认证 / 身体 / 饮食 / 训练 / 用药 / 睡眠 / 同步 / 计算），可按板块分组运行或全部运行。每个用例展示原始描述、可编辑参数、执行结果（通过/失败 + 耗时）。

### 并发压测

- 可选 9 个接口（登录 / 身体查询 / 身体上传 / 饮食 / 训练 / 用药 / 睡眠 / 补剂方案 / sync/batch）。
- 可调并发数与总请求数，统计成功率、平均耗时、P50 / P95 / 最大耗时。
- 耗时分布图：绿点 = 成功，红点 = 失败。

### 测试报告

- 概览统计：账号池数量、用例通过率、日志数。
- 日志类型分布 + 执行日志表（复制 / 导出 JSON / 清空）。
- 常用 curl 模板，方便在终端复现。

## 后端补充接口

测试台部分功能依赖以下后端扩展接口（**当前后端尚未实现，调用会返回 404**），按需实现：

| 接口 | 用途 | 测试台触发位置 |
|------|------|----------------|
| `POST /api/auth/register-batch` | 服务端批量注册 | 账号批量管理（可选优化） |
| `DELETE /api/auth/user/{user_id}` | 删除账号（级联清业务表） | 账号池「删除」 |
| `GET /api/auth/users?keyword=` | 账号列表 | 账号池拉取 |
| `DELETE /api/users/{user_id}/data` | 清空单用户业务数据 | 账号池「清数据」 |

> 未实现时，批量注册仍可工作（前端并发调用单个注册接口）；「删除 / 清数据 / 账号列表」按钮会提示失败。

## 接口覆盖清单

| 板块 | 接口 | 状态 |
|------|------|------|
| 认证 | `POST /api/auth/login`、`POST /api/auth/register` | ✅ 现有 |
| 身体 | `PUT /api/body`、`GET /api/body/latest`、`GET /api/body/history` | ✅ 现有 |
| 饮食 | `GET /api/meal/today` | ✅ 现有 |
| 训练 | `GET /api/training/history` | ✅ 现有 |
| 用药 | `GET /api/drug/list`、`POST /api/drug/lookup`、`POST /api/drug/risk-check` | ✅ 现有 |
| 睡眠 | `GET/POST /api/sleep/latest\|history\|records` | ✅ 现有 |
| 同步 | `POST /api/sync/batch` | ✅ 现有 |
| 计算 | `POST /api/supplement-plan`、`/api/food/recognize`、`/api/workout/classify` | ✅ 现有（mock） |
| 管理 | `POST /api/auth/register-batch`、`DELETE /api/auth/user/{id}`、`GET /api/auth/users`、`DELETE /api/users/{id}/data` | ⚠️ 待后端补充 |

## 常见问题

**Q: 测试台显示"后端未连接"？**
检查后端是否启动、后端地址是否正确、代理开关是否与后端位置匹配，在「连接配置」点健康检查看具体报错。

**Q: 批量注册报网络错误 / 超时？**
后端未启动或并发数过高。先做健康检查，再适当调低并发数（建议 5-10）与超时时间。

**Q: 注册报 `code=1004`？**
手机号格式（非 11 位数字）或密码不足 6 位。

**Q: 身份传 `admin` 等自定义值失败？**
users 表 `identity` 是 `enum('beginner','enthusiast','coach')`，只接受这三个值。

**Q: 删除账号 / 清数据按钮失败？**
后端扩展接口未实现，见「后端补充接口」。

## 生产构建（可选）

```bash
npm run build      # 产物在 dist/
npm run preview    # 本地预览构建产物
```

构建产物为纯静态文件，可部署到任意静态服务器（Nginx / GitHub Pages 等）；此时需在「连接配置」关闭开发代理并填写后端完整地址（依赖后端 CORS）。
