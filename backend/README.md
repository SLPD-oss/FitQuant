# FitQuant 后端服务

FastAPI 异步后端，提供认证、身体数据、补剂方案、食物识别、药品查询、训练分类、数据同步等 API。

## 技术栈

- Python 3.11+
- FastAPI + Uvicorn
- SQLAlchemy (async) + aiomysql
- MySQL 9.x

## 快速启动

```bash
# 1. 安装依赖
pip install -r requirements.txt

# 2. 初始化数据库（要先启动 MySQL 并创建 fitquant_db）
mysql -u root < ../sql/init.sql

# 3. 启动服务
uvicorn app.main:app --reload
```

启动后访问 http://127.0.0.1:8000/docs 查看 API 文档（Swagger UI）。

## 数据模型关系

```
users (user_id PK)
  ├── body_records (user_id FK)  — 身体数据历史
  ├── meal_records  (user_id FK)  — 饮食记录
  ├── training_records (user_id FK) — 训练记录
  └── drug_records  (user_id FK)  — 用药记录
```

## 测试用户

| 手机号 | 密码 | 昵称 | 身份 |
|--------|------|------|------|
| 13800000001 | 666666 | u1 | enthusiast |
| 13800000002 | 666666 | u2 | enthusiast |
| 13800000003 | 666666 | u3 | coach |
| 13800000004 | 666666 | u4 | beginner |
| 13800000005 | 666666 | u5 | enthusiast |

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `MYSQL_URL` | `mysql+aiomysql://root@127.0.0.1:3306/fitquant_db` | 数据库连接串 |

数据库默认无密码（root 空密码），如需修改请编辑 `app/database.py`。
