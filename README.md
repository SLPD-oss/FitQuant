# FitQuant 量化补充

面向健身增补人群的量化记录应用。把散落在补剂、用药、训练、饮食、睡眠恢复五个场景里的行为，收敛成一套可量化、可回溯、并带风险提示的记录系统。

客户端是原生 iOS（SwiftUI），后端是异步 FastAPI + MySQL。数据本地优先存储，断网也能完整记录。

## 功能模块

| 模块 | 主要能力 |
| --- | --- |
| 补剂 | 按身份（普通减脂用户 / 健身爱好者 / 专业教练）展示 3 / 5 / 7 个知识模块；蛋白粉、肌酸、维生素 D3、鱼油打卡；热量缺口预警；肌酸摄入联动饮水目标 |
| 用药 | 本地用药记录与状态管理（在用 / 评估中 / 已停用）；药名自动检索与分类；喹诺酮类药物的肌腱损伤风险提示 |
| 训练 | 动作智能分类（力量 / 有氧、主次肌群、HIIT 子类型）；组次重量与有氧参数录入；心率区间监测；跑步机 ACSM 热量估算；TFCC 手腕风险提示；训练日历；睡眠恢复建议 |
| 饮食 | 八项营养追踪（蛋白质 / 脂肪 / 碳水 / 膳食纤维 / 钠 / 咖啡因 / 饮水量 / 添加糖）；食物识别；咖啡因换算；热量自动计算 |
| 我的 | 身体数据与围度管理；体成分统计（BMI、体脂、腰臀比、BMR）；体重趋势图与减脂报告；深色模式；账号管理 |
| 启动流程 | 中国大陆法律法规协议与 Apple 隐私协议（带版本校验）；身份选择；新手励志引导与身体数据采集 |

## 技术栈

| 端 | 技术 |
| --- | --- |
| 客户端 | SwiftUI（无第三方依赖）、URLSession、UserDefaults + Codable |
| 后端 | Python 3.11+、FastAPI、Pydantic v2、Uvicorn |
| 数据 | SQLAlchemy 2.x（async）+ aiomysql、MySQL 9.x（`fitquant_db`，utf8mb4） |

## 目录结构

```
FitQuant/
├─ 量化补充.xcodeproj        # Xcode 工程
├─ FitQuantApp.swift         # 应用入口
├─ LaunchFlow/               # 启动合规、注册预览、身份选择
├─ MainTab/                  # 补剂、用药、训练、饮食、我的五个 Tab
├─ Views/                    # 根路由、登录、身体录入、引导与动效
├─ CommonComponent/          # 设计常量、弹窗、合规文案、全局单例
├─ Services/                 # 网络、鉴权、算法工具、分类识别、Repository
├─ LocalDataManager/         # 领域模型与本地数据管理
└─ backend/
   ├─ app/routers/           # 11 组业务路由
   ├─ app/models/            # 6 张表的 ORM 模型
   ├─ app/schemas/           # 请求 / 响应模型
   ├─ app/services/          # 睡眠评分算法与模拟数据
   ├─ sql/init.sql           # 建库建表与测试数据
   └─ requirements.txt
```

## 快速开始

### 后端

```bash
cd backend
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt

# 需先启动 MySQL，并创建 fitquant_db
mysql -u root < sql/init.sql

uvicorn app.main:app --reload
```

启动后访问 http://127.0.0.1:8000/docs 查看 Swagger 接口文档。

### 客户端

用 Xcode 打开 `量化补充.xcodeproj`，选择 iOS 模拟器运行。客户端默认请求 `http://localhost:8000`，如需修改地址，调整 `Services/APIClient.swift` 中的 `baseURL`。

## 测试账号

| 手机号 | 密码 | 昵称 | 身份 |
| --- | --- | --- | --- |
| 13800000001 | 666666 | u1 | enthusiast |
| 13800000002 | 666666 | u2 | enthusiast |
| 13800000003 | 666666 | u3 | coach |
| 13800000004 | 666666 | u4 | beginner |
| 13800000005 | 666666 | u5 | enthusiast |

## 配置说明

后端数据库连接在 `backend/app/database.py` 中配置，默认 `mysql+aiomysql://root@127.0.0.1:3306/fitquant_db`（root 空密码），字符集 utf8mb4。

数据库不可用时后端仍能正常启动，补剂方案、食物识别、药品查询、训练分类等接口会返回内置模拟数据。

## 数据与同步

客户端所有业务数据按账号作用域隔离（`AccountScopedStore` 会把存储键拼接为 `{key}_{userId}`），刷新与切换账号时互不干扰。

记录遵循本地优先策略：先写本地、立即生效，再异步批量同步到后端。删除采用墓碑机制，同步时先按记录 id 删除再执行幂等 upsert，中途失败可重试。

## 已知限制

服务端尚未实现 Token 校验，接口的用户身份目前由客户端传入 `user_id` 决定，仅适合本地开发与演示，接入真实用户前需要补齐鉴权。

密码使用无盐 SHA256 存储；`/api/food/recognize` 的后端声明为 multipart 表单，与客户端的 JSON 请求格式尚未对齐。

食物识别、药品分类与药品风险校验均为关键词映射的模拟实现，非真实模型推断。

## 免责声明

应用内的体成分、营养、训练与睡眠建议均来自公开循证文献的通用参考计算，不构成任何医疗诊疗、用药或膳食医嘱建议。

## 许可证

[MIT](LICENSE)
