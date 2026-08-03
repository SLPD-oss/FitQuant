"""
模拟数据生成服务 — 数据库未就绪时使用
"""
import uuid
from datetime import datetime, timedelta

# ── 工具函数 ──

def _mock_token():
    """生成模拟 JWT 令牌"""
    return f"eyJmock_{uuid.uuid4().hex[:24]}"


def _bmi(weight_kg, height_cm):
    h = height_cm / 100
    return round(weight_kg / (h * h), 1)


def _bmr(sex, weight_kg, height_cm, age):
    base = 10 * weight_kg + 6.25 * height_cm - 5 * age
    return base + 5 if sex == "male" else base - 161


def _bmi_zone(bmi):
    if bmi < 18.5: return "偏瘦"
    if bmi < 24: return "正常"
    if bmi < 28: return "偏胖"
    return "肥胖"


# ── 各 API Mock 数据 ──

def mock_login(phone, password, device_id):
    return {
        "token": _mock_token(),
        "refresh_token": _mock_token(),
        "expires_in": 86400,
        "user": {
            "user_id": f"u_{uuid.uuid4().hex[:8]}",
            "phone": phone[:3] + "****" + phone[-4:],
            "nickname": "健身达人",
            "avatar_url": "https://cdn.fitquant.com/avatars/default.png",
            "identity": "enthusiast",
        }
    }


def mock_supplement_plan(weight_kg, height_cm, age, sex, body_fat_percent, activity_level, waist_cm, neck_cm):
    bmi = _bmi(weight_kg, height_cm)
    bmr = _bmr(sex, weight_kg, height_cm, age)
    tdee = round(bmr * 1.55)
    protein_target = round(weight_kg * 1.8, 1)
    daily_kcal = max(round(bmr - 600), 1200)
    fat_g = round(daily_kcal * 0.25 / 9, 1)
    protein_g = round(weight_kg * 2.0, 1)
    fiber_g = 25
    protein_kcal = protein_g * 4
    fiber_kcal = fiber_g * 2
    carbs_kcal = daily_kcal - protein_kcal - (fat_g * 9) - fiber_kcal
    carbs_g = max(round(carbs_kcal / 4), 100)

    return {
        "bmi": bmi,
        "bmi_screening_zone": _bmi_zone(bmi),
        "tdee_kcal": float(tdee),
        "bmr_kcal": round(bmr, 1),
        "protein_target_g": protein_target,
        "protein_note": "1.8g/kg 体重 · 运动人群推荐量",
        "whey_scoops_ref": round(protein_target / 30, 1),
        "creatine_mg_per_day": 5000,
        "creatine_note": "单水肌酸维持期推荐 5g/日",
        "vitamin_d3_iu_per_day": 2000,
        "fish_oil_mg_per_day": min(round(weight_kg * 30), 2000),
        "water_liters_ref": round(weight_kg * 0.033, 1),
        "body_fat_estimate_pct": body_fat_percent,
        "body_fat_note": "U.S. Navy 公式估算",
        "nutrition_targets": {
            "daily_kcal": float(daily_kcal),
            "protein_g": protein_g,
            "fat_g": fat_g,
            "carbs_g": float(carbs_g),
            "fiber_g": float(fiber_g),
            "base_deficit_kcal": round(bmr - daily_kcal, 1),
        },
        "literature_refs": [
            {"title": "ISSN 运动营养综述", "doi": "10.XXXX/xxxx1"},
            {"title": "ACSM 立场声明: 蛋白质摄入", "doi": "10.XXXX/xxxx2"},
        ]
    }


def mock_food_recognition(food_name):
    """根据食物名称关键词返回模拟营养素数据"""
    name = food_name.strip()
    mapping = {
        "鸡胸": {"protein_g": 31, "fat_g": 3.6, "carbs_g": 0, "fiber_g": 0, "kcal": 165, "sodium_mg": 74, "sugar_g": 0,
                 "confidence": 0.95, "display_name": "鸡胸肉（熟）"},
        "牛肉": {"protein_g": 26, "fat_g": 15, "carbs_g": 0, "fiber_g": 0, "kcal": 239, "sodium_mg": 72, "sugar_g": 0,
                 "confidence": 0.93, "display_name": "牛肉（瘦）"},
        "米饭": {"protein_g": 2.6, "fat_g": 0.3, "carbs_g": 28, "fiber_g": 0.1, "kcal": 116, "sodium_mg": 1, "sugar_g": 0,
                 "confidence": 0.90, "display_name": "白米饭"},
        "西兰花": {"protein_g": 2.8, "fat_g": 0.4, "carbs_g": 7, "fiber_g": 2.6, "kcal": 34, "sodium_mg": 33, "sugar_g": 1.7,
                   "confidence": 0.88, "display_name": "西兰花（熟）"},
        "鸡蛋": {"protein_g": 13, "fat_g": 11, "carbs_g": 1.1, "fiber_g": 0, "kcal": 155, "sodium_mg": 62, "sugar_g": 1.1,
                 "confidence": 0.96, "display_name": "鸡蛋（煮）"},
        "牛奶": {"protein_g": 3, "fat_g": 3.2, "carbs_g": 4.8, "fiber_g": 0, "kcal": 60, "sodium_mg": 45, "sugar_g": 4.8,
                 "confidence": 0.94, "display_name": "全脂牛奶"},
        "苹果": {"protein_g": 0.3, "fat_g": 0.2, "carbs_g": 14, "fiber_g": 2.4, "kcal": 52, "sodium_mg": 1, "sugar_g": 10,
                 "confidence": 0.92, "display_name": "苹果"},
        "面包": {"protein_g": 9, "fat_g": 2.5, "carbs_g": 49, "fiber_g": 6, "kcal": 250, "sodium_mg": 400, "sugar_g": 5,
                 "confidence": 0.87, "display_name": "全麦面包"},
    }
    for keyword, data in mapping.items():
        if keyword in name:
            return {
                "food_name": data["display_name"],
                "confidence": data["confidence"],
                "serving_size_g": 100,
                "nutrition_per_100g": {
                    "protein_g": data["protein_g"],
                    "fat_g": data["fat_g"],
                    "carbs_g": data["carbs_g"],
                    "fiber_g": data["fiber_g"],
                    "kcal": data["kcal"],
                    "sodium_mg": data["sodium_mg"],
                    "sugar_g": data["sugar_g"],
                },
                "possible_alternatives": [],
                "allergen_warnings": [],
            }
    # 默认值
    return {
        "food_name": f"{name}（估算）",
        "confidence": 0.70,
        "serving_size_g": 100,
        "nutrition_per_100g": {"protein_g": 10, "fat_g": 5, "carbs_g": 20, "fiber_g": 2, "kcal": 150, "sodium_mg": 100, "sugar_g": 5},
        "possible_alternatives": [],
        "allergen_warnings": [],
    }


def mock_drug_lookup(drug_name):
    """根据药品名称返回模拟分类数据"""
    name = drug_name.strip()
    mapping = {
        "左氧氟沙星": {"category": "typeB", "display": "处方药（运动高风险）", "prescription": True, "tags": ["喹诺酮类", "肌腱损伤高风险"]},
        "布洛芬": {"category": "typeA", "display": "非处方药", "prescription": False, "tags": ["NSAIDs", "低运动风险"]},
        "六味地黄丸": {"category": "traditionalChMedicine", "display": "中药", "prescription": False, "tags": ["中药", "低运动风险"]},
        "阿托伐他汀": {"category": "typeB", "display": "处方药（运动高风险）", "prescription": True, "tags": ["他汀类", "肌肉损伤风险"]},
    }
    for keyword, data in mapping.items():
        if keyword in name:
            return {
                "drug_name": name,
                "category": data["category"],
                "category_display": data["display"],
                "aliases": [],
                "common_dosage": "",
                "common_unit": "mg",
                "is_prescription": data["prescription"],
                "risk_tags": data["tags"],
                "from_database": "国家药品监督管理局 NMPA",
            }
    return {
        "drug_name": name,
        "category": "other",
        "category_display": "其他",
        "aliases": [],
        "common_dosage": "",
        "common_unit": "mg",
        "is_prescription": False,
        "risk_tags": [],
        "from_database": "国家药品监督管理局 NMPA",
    }


def mock_drug_risk_check(drug_names):
    """模拟药物-运动风险校验"""
    high_risk_quinolones = ["左氧氟沙星", "氧氟沙星", "环丙沙星", "莫西沙星", "诺氟沙星"]
    risks = []
    for name in drug_names:
        for q in high_risk_quinolones:
            if q in name:
                risks.append({
                    "drug_name": name,
                    "risk_level": "high",
                    "risk_description": f"喹诺酮类抗生素({q})与肌腱炎、肌腱撕裂风险上升存在关联（依据 FDA 安全警告），高强度抗阻训练可能加重此类风险，建议降低大重量推拉动作负荷",
                    "affected_body_parts": ["肩袖肌腱", "跟腱"],
                    "suggestion": "建议暂时降低大重量推拉抗阻训练负荷，待药物停用后逐步恢复原有强度",
                    "literature_refs": [{"title": "FDA 喹诺酮安全警告", "url": "https://www.fda.gov/drugs/drug-safety-and-availability"}],
                })
    return {"has_risk": len(risks) > 0, "risks": risks}


def mock_workout_classify(action_name):
    """模拟训练动作分类"""
    name = action_name.strip()

    # 力量动作库: (主要肌群, 细分选项, 每分钟消耗kcal)
    strength_map = {
        "卧推": ("chest", ["上胸", "中胸（厚度）", "下胸"], 5.2),
        "深蹲": ("legs", ["股四头肌", "臀大肌"], 6.5),
        "硬拉": ("back", ["背阔肌", "竖脊肌", "臀大肌"], 7.0),
        "划船": ("back", ["背阔肌", "菱形肌"], 5.0),
        "推举": ("shoulders", ["前束", "中束"], 4.8),
    }
    # 有氧动作库: (主要肌群, 细分, 有氧子类型, 手腕风险)
    cardio_map = {
        "跑步机": ("全身", [], "steadyCardio", False),
        "登山跑": ("核心", ["核心"], "hiit", True),
        "平板支撑": ("核心", ["核心"], "hiit", True),
        "椭圆机": ("全身", [], "steadyCardio", False),
    }

    # 先匹配力量动作
    for keyword, (group, subs, kcal) in strength_map.items():
        if keyword in name:
            return {
                "action_name": name,
                "training_type": "strength",
                "aerobic_sub_type": None,
                "primary_muscle_group": group,
                "secondary_muscle_groups": subs,
                "sub_muscle_options": subs if subs else [],
                "is_high_risk_wrist": False,
                "estimated_kcal_per_min": kcal,
                "common_equipment": ["杠铃", "哑铃"],
                "difficulty": "intermediate",
            }

    # 再匹配有氧动作
    for keyword, (group, subs, sub_type, wrist_risk) in cardio_map.items():
        if keyword in name:
            return {
                "action_name": name,
                "training_type": "cardio",
                "aerobic_sub_type": sub_type,
                "primary_muscle_group": group,
                "secondary_muscle_groups": subs,
                "sub_muscle_options": [],
                "is_high_risk_wrist": wrist_risk,
                "estimated_kcal_per_min": 8.0 if sub_type == "hiit" else 5.0,
                "common_equipment": ["跑步机"] if sub_type == "steadyCardio" else [],
                "difficulty": "intermediate",
            }

    # 默认返回
    return {
        "action_name": name,
        "training_type": "strength",
        "aerobic_sub_type": None,
        "primary_muscle_group": "全身",
        "secondary_muscle_groups": [],
        "sub_muscle_options": [],
        "is_high_risk_wrist": False,
        "estimated_kcal_per_min": 5.0,
        "common_equipment": [],
        "difficulty": "beginner",
    }


def mock_upload_body():
    """模拟身体数据上传返回"""
    return {"record_id": f"body_rec_{uuid.uuid4().hex[:8]}", "created_at": datetime.now().isoformat()}


def mock_body_history():
    """模拟身体数据历史"""
    today = datetime.now()
    records = []
    for i in range(30, 0, -1):
        day = today - timedelta(days=i)
        records.append({
            "recorded_at": day.strftime("%Y-%m-%d"),
            "weight_kg": round(72.0 - i * 0.05, 1),
            "body_fat_percent": round(22.0 - i * 0.05, 1),
        })
    return {"records": records, "trend": {"weight_change_kg": -1.5, "body_fat_change_pct": -1.5}}


def mock_sleep_latest():
    """模拟最新一夜睡眠数据（数据库不可用降级；对齐前端"恢复良好"场景）"""
    from app.services.sleep_score import suggestion_for
    return {
        "record_id": f"sleep_rec_{uuid.uuid4().hex[:8]}",
        "sleep_date": (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d"),
        "total_sleep_hours": 7.8,
        "core_sleep_hours": 4.2,
        "deep_sleep_hours": 1.6,
        "rem_sleep_hours": 1.5,
        "awake_hours": 0.5,
        "resting_heart_rate": 52,
        "avg_hrv": 68,
        "source": "healthkit",
        "recovery_score": 86,
        "recovery_status": "good",
        "consecutive_low_score_days": 0,
        "suggestion": suggestion_for(86, 0),
    }


def mock_sleep_history():
    """模拟近 7 夜睡眠历史（数据库不可用降级）"""
    from app.services.sleep_score import compute_score, status_of, consecutive_low_days
    today = datetime.now()
    records = []
    # 近 7 天从良好逐步波动，最近一晚恢复良好
    nights = [
        (7.8, 4.2, 1.6, 1.5, 0.5, 52, 68),
        (7.5, 4.0, 1.5, 1.4, 0.6, 53, 66),
        (7.9, 4.3, 1.7, 1.4, 0.5, 51, 70),
        (7.6, 4.1, 1.5, 1.5, 0.5, 52, 67),
        (7.4, 4.0, 1.4, 1.4, 0.6, 53, 64),
        (7.2, 3.9, 1.3, 1.3, 0.7, 54, 60),
        (7.7, 4.2, 1.6, 1.4, 0.5, 52, 69),
    ]
    scores = []
    for i, (total, core, deep, rem, awake, rhr, hrv) in enumerate(nights):
        score = compute_score(total, deep, rem, awake, rhr, hrv)
        scores.append(score)
        day = today - timedelta(days=len(nights) - i)
        records.append({
            "record_id": f"sleep_rec_{uuid.uuid4().hex[:8]}",
            "sleep_date": day.strftime("%Y-%m-%d"),
            "total_sleep_hours": total,
            "core_sleep_hours": core,
            "deep_sleep_hours": deep,
            "rem_sleep_hours": rem,
            "awake_hours": awake,
            "resting_heart_rate": rhr,
            "avg_hrv": hrv,
            "source": "healthkit",
            "recovery_score": score,
            "recovery_status": status_of(score),
            "consecutive_low_score_days": 0,
        })
    return {"records": records, "total": len(records)}
