# 用药模块三问题修复计划

> 范围：FitQuant iOS 用药模块（MedicineView / DrugDataManager / 后端 sync）
> 问题：① 添加药物后切页返回出现两条相同记录；② 药物搜索列表改液态玻璃样式；③ 搜索命中时自动选中药物类型

---

## 一、问题①：添加药物后切页返回出现两条相同记录

### 现象

添加一条药物 → 切到其他 Tab → 切回用药页，列表里出现两条一模一样的记录。用户感知为"后端和本地数据库同时显示"。

### 根因分析

这不是"双端同时显示"，而是**合并逻辑的幂等匹配失败，把同一条记录当成两条**。完整链路：

```
1. 添加：本地记录 id=UUID-A, createdAt=05:30:12.345（UTC，纳秒精度）
2. 同步：DrugSyncRecord 只传 recorded_at/drug_name 等，不带 id
3. 后端：幂等键 (user_id, drug_name, recorded_at) 查不到 → INSERT
         生成新 id=UUID-B，recorded_at 落库为秒精度
4. 切页返回：GET /api/drug/list 返回 { record_id=UUID-B, recorded_at="2026-08-03T05:30:12" }
5. 合并 isSameRecord(本地A, 后端B)：
   - id 不同（A≠B）→ 不命中
   - 幂等键：drugName 相同 ✓，但 createdAt 比较 ✗
```

**幂等键失败的关键在时区解析**：

- 后端返回 `recorded_at="2026-08-03T05:30:12"`（无时区的 naive 字符串，UTC 字面值）
- 前端 `parseBackendDate` 先试 `ISO8601DateFormatter`（要求带 Z，解析失败），落到 fallback `DateFormatter`
- fallback 的 `DateFormatter` **默认使用设备本地时区（+8）**，把 `05:30:12` 解释成北京时间 → 得到 `13:30:12 UTC`
- 本地记录的 `createdAt = 05:30:12.345 UTC`
- 两者相差 8 小时，`isSameRecord` 的 1 秒容差**不命中** → 走 `append` 分支 → 本地 1 条 + 后端 1 条并存

也就是说：`record_id` 前后端不一致（后端每次生成新 UUID）+ 时间戳时区偏移，导致按 id 和按幂等键两条匹配通道全部失效。

### 修复方案（两层，A 治本 + B 兜底）

**方案 A（治本）：同步上传携带 record_id，后端按客户端 id upsert**

- 前端 `DrugSyncRecord` 增加 `record_id` 字段，`syncToBackend()` 上传本地 `id.uuidString`
- 后端 `sync.py` 幂等 upsert 改造：优先按 `(user_id, id)` 查，存在则更新；不存在且带 id 则**按该 id 插入**（不再生成新 UUID）
- 效果：前后端 id 永远一致，合并直接按 id 命中，不再依赖时间戳；同时顺带修复"删除按 id 匹配不到历史记录"的隐患

**方案 B（兜底）：前端时间解析统一按 UTC**

- `parseBackendDate` 的 fallback 分支显式设置 `timeZone = TimeZone(identifier: "UTC")`，无时区字符串一律按 UTC 解释
- 兼容已有历史数据（旧的 UUID-B 记录），保证幂等键兜底也能命中

> 两层都做：A 让新数据从源头一致，B 兜住存量数据，双保险。

### 验证

- 添加药物 → 切页 → 返回：仅 1 条
- 连续两次添加同一种药：仍各 1 条（不合并、不重复）
- 数据库 `drug_records` 行数 = 前端列表条数

---

## 二、问题②：药物搜索列表改液态玻璃样式

### 现状

搜索结果是 `Form` 里的普通 `Button` 行，样式朴素（`TextField` 下方直接排列）。

### 方案

复用项目已有的 `AppleGlassStyle` 材质封装，将搜索列表改为**液态玻璃浮层卡片**，与 iOS 26 设计语言一致：

- **材质**：`.ultraThinMaterial`（`AppleGlassStyle.ultraThin`）做背景，配合半透明高光质感
- **容器**：`RoundedRectangle(cornerRadius: AppleGlassStyle.cornerRadiusLarge)` + 细描边 + 轻微阴影，形成浮层卡片，覆盖在输入框下方
- **列表行**：每行 = 药物名（`textPrimary`）+ 别名（`textTertiary` 小字）+ 右侧风险标签胶囊；点击整行选中
- **视觉细节**：行间用 `Divider().opacity(0.3)` 分隔；选中行高亮（`accent` 描边或背景微亮）
- **空态**：无命中时不显示浮层，保留手动输入（现有兜底不变）

实现位置：`AddDrugSheet` 中把现有 `ForEach(searchResults)` 部分整体替换为玻璃浮层卡片组件。

### 验证

- 输入"沙星" → 玻璃浮层出现 5 条喹诺酮类，材质半透明、圆角、有高光感
- 点选任意条目 → 自动填充并收起浮层
- 深色/浅色模式均正常（Material 自适应）

---

## 三、问题③：搜索命中时自动选中药物类型

### 现状

仅当输入**精确命中**目录（`entry(named:)`）时才自动填充分类；模糊命中只展示列表，必须手动点选，否则分类停留在"其他"。

### 方案

改为"**命中即选，空结果才手选**"：

- **模糊命中**（列表 ≥ 1 条）：自动应用**第一个匹配项**的分类与运动建议（不自动回填药名，避免打断用户继续输入），列表仍展示，用户可点其他项切换
- **精确命中**（名称完全一致）：保持现有行为，自动回填药名 + 分类（用户最省事）
- **无命中**（列表为空）：分类 Picker 保持可选手动兜底，并显示"目录未收录，已手动归类"轻提示
- 自动选中时若用户随后手动改了 Picker，以手动选择为准（`applyCatalogEntry` 只在校验用户未手动改过时覆盖）

实现细节：

- `AddDrugSheet` 增加 `@State userManuallyChangedCategory` 标记；用户在 Picker 上操作时置位，之后搜索命中不再自动覆盖
- 搜索命中的自动填充逻辑抽成 `applyCatalogEntry(_:preserveManual: Bool)`

### 验证

- 输入"左氧" → 分类自动变 typeB（不点列表也生效），建议卡出现
- 输入"阿托伐" → 分类自动变 typeB，显示中风险建议
- 输入"维生素D"（未收录）→ 列表为空，分类保持手动可改
- 手动改过分类后再输入其他药 → 自动填充不覆盖手动选择

---

## 四、改动清单

| 文件 | 改动 |
|------|------|
| `Services/APIModels.swift` | `DrugSyncRecord` 增加 `record_id: String` |
| `LocalDataManager/DrugDataManager.swift` | `syncToBackend()` 上传本地 id；构造 `DrugSyncRecord` 带 record_id |
| `backend/app/schemas/sync.py` | `DrugSyncRecord` 增加 `record_id: str = ""` |
| `backend/app/routers/sync.py` | upsert 改按 `(user_id, id)` 优先匹配；带 id 时按该 id 插入 |
| `MainTab/MedicineView.swift` | ① `parseBackendDate` fallback 设 UTC 时区；② 搜索列表改液态玻璃浮层；③ 命中即自动选中分类 + 手动选择保护 |
| `Services/DrugCatalog.swift` | （如需）补充匹配评分：名称前缀 > 包含 > 别名，供"第一个匹配项"更合理 |

## 五、风险与注意

- 后端 upsert 改造影响面：仅药物分支，饮食/训练/睡眠分支不动
- 历史重复数据（此前已生成的 UUID-B 记录）：方案 B 修复后，下次同步幂等键命中会收敛（后端已有"更新第一条、删除其余同键"逻辑）；存量极端重复可再单独清理
- `record_id` 新增字段为可选（默认空串），旧版本客户端不带该字段时后端行为不变，向后兼容

## 六、验证清单（回归）

1. 添加药物 → 切页 → 返回：恰好 1 条，无重复
2. 重复添加同种药：不叠加
3. 删除单条 → 切页 → 返回：不复活（既有墓碑机制回归）
4. 一键删除所有 → 后端 `drug_records` 清空（既有 clear_all_drugs 回归）
5. 搜索"沙星"：玻璃浮层展示，自动选中 typeB，建议卡显示
6. 搜索未收录药物：手动分类兜底正常
7. 深色/浅色模式下玻璃浮层显示正常
