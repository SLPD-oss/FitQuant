import Foundation

// MARK: - PhysiologyCalcTool
// 本地离线生理数据计算工具类 — 所有公式硬编码，无RAG云端依赖
// 后期对接云端生理/营养数据库仅替换计算层，上层页面UI无需改动

struct PhysiologyCalcTool {

    // MARK: - 体脂率计算（男女分版海军体脂公式）

    static func navyBodyFatMale(heightCm: Double, waistCm: Double, neckCm: Double = 38) -> Double? {
        guard heightCm > 0, waistCm > neckCm else { return nil }
        let value = 86.010 * log10(waistCm - neckCm)
                  - 70.041 * log10(heightCm)
                  + 36.76
        return max(3, min(value, 50))
    }

    static func navyBodyFatFemale(heightCm: Double, waistCm: Double, hipCm: Double, neckCm: Double = 38) -> Double? {
        guard heightCm > 0, hipCm > 0, (waistCm + hipCm) > neckCm else { return nil }
        let value = 163.205 * log10(waistCm + hipCm - neckCm)
                  - 97.684 * log10(heightCm)
                  - 78.387
        return max(3, min(value, 50))
    }

    static func bmiBasedBodyFat(bmi: Double, sex: Sex, age: Int = 25) -> Double {
        let sexFactor: Double = sex == .male ? 1.0 : 0
        let value = 1.20 * bmi + 0.23 * Double(age) - 10.8 * sexFactor - 5.4
        return max(3, min(value, 50))
    }

    static func calculateBodyFat(
        sex: Sex, heightCm: Double, weightKg: Double,
        waistCm: Double?, hipCm: Double?, neckCm: Double = 38, age: Int = 25
    ) -> Double {
        let bmi = heightCm > 0 ? weightKg / ((heightCm / 100) * (heightCm / 100)) : 0
        if let waist = waistCm, waist > 0 {
            if sex == .male {
                if let navy = navyBodyFatMale(heightCm: heightCm, waistCm: waist, neckCm: neckCm) { return navy }
            } else {
                if let hip = hipCm, hip > 0,
                   let navy = navyBodyFatFemale(heightCm: heightCm, waistCm: waist, hipCm: hip, neckCm: neckCm) { return navy }
            }
        }
        return bmiBasedBodyFat(bmi: bmi, sex: sex, age: age)
    }

    // MARK: - BMR基础代谢计算（Mifflin-St Jeor公式）

    static func calculateBMR(sex: Sex, weightKg: Double, heightCm: Double, age: Int = 25) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return sex == .male ? base + 5 : base - 161
    }

    // MARK: - 【保守减脂热量计算逻辑】饮食营养目标分配（500~600kcal温和缺口，上限锁死600）

    /// 循证保守减脂方案：饮食基础缺口500~600kcal，强制上限600，最低1200kcal保底
    /// 保护基础代谢与内分泌激素水平，适配长期减脂需求，杜绝激进减脂参数
    /// 后期对接云端营养数据库仅替换此函数内部配比参数，上层UI无需改动
    static func calculateNutritionTargets(
        sex: Sex, weightKg: Double, heightCm: Double, age: Int = 25
    ) -> NutritionTargets {
        let bmr = calculateBMR(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age)
        // 饮食基础缺口目标600kcal，若BMR较低则自动收窄至500kcal区间，最低摄入不低于1200kcal
        let idealTarget = max(bmr - 600, 1200)
        // 实际饮食基础缺口 = BMR - 每日摄入（严格≤600）
        let baseDeficit = bmr - idealTarget
        let dailyKcal = idealTarget

        // 循证保守蛋白质配比：1.6~2.0g/kg取2.0g/kg
        let proteinG = weightKg * 2.0

        // 脂肪占每日总摄入25%，不低于0.8g/kg保底
        let fatKcal = dailyKcal * 0.25
        let fatG = max(fatKcal / 9, weightKg * 0.8)

        // 膳食纤维最低25g
        let fiberG: Double = 25

        // 碳水补剩余，不低于100g保底（保护代谢与运动表现）
        let proteinKcal = proteinG * 4
        let fiberKcal = fiberG * 2
        let carbsKcal = dailyKcal - proteinKcal - (fatG * 9) - fiberKcal
        let carbsG = max(carbsKcal / 4, 100)

        return NutritionTargets(
            dailyKcal: dailyKcal,
            proteinG: proteinG,
            fatG: fatG,
            carbsG: carbsG,
            fiberG: fiberG,
            bmr: bmr,
            baseDeficit: baseDeficit
        )
    }

    // MARK: - 【当日训练消耗汇总】自动汇总当日力量+有氧训练记录的消耗卡路里

    /// 读取本地当日全部训练记录，求和estimatedKcal得到运动总消耗
    /// 增删训练记录后重新调用即可实时更新数值
    /// 远期云端生理数据库下发权威消耗系数时可替换此函数内部参数
    static func sumTodayTrainingConsume() -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return 0 }

        let allRecords = TrainingRecordStorage.shared.loadAll()
        let todayRecords = allRecords.filter { record in
            record.createdAt >= today && record.createdAt < tomorrow
        }
        let totalKcal = todayRecords.reduce(0.0) { $0 + $1.estimatedKcal }
        return totalKcal
    }

    // MARK: - 【总热量缺口叠加计算】饮食基础缺口 + 当日运动总消耗

    /// 总热量缺口 = 饮食基础缺口 + 当日运动消耗
    /// 饮食基础缺口来自NutritionTargets内存储的baseDeficit（≤600kcal）
    static func calcTotalCalorieDeficit(baseDeficit: Double, exerciseConsume: Double) -> Double {
        return baseDeficit + exerciseConsume
    }

    // MARK: - 【总热量缺口超标阈值判断】800大卡警戒线

    /// 总缺口＞800kcal → 循证医学风险：长期过大缺口损伤基础代谢、扰乱内分泌
    /// 单纯饮食基础缺口上限600不会触发；仅叠加运动消耗后才可能超标
    /// 返回true时SupplementView唤起风险弹窗
    static func isDeficitOverWarningThreshold(_ totalDeficit: Double) -> Bool {
        return totalDeficit > 800
    }

    // MARK: - 【新增肌酸饮水目标全局联动逻辑】肌酸适配每日推荐饮水量计算（双页面统一调用）

    /// 【微调肌酸饮水分档判定逻辑】循证肌酸补水新标准：0g→2L，≤3g→2.5L，3~5g→3.5L
    /// 补剂页、饮食页统一调用此函数，保证两处页面饮水目标数值完全同步
    /// 后期对接云端营养数据库可替换此函数内部参数
    static func calcCreatineWaterTarget(dailyCreatineGrams: Double) -> Double {
        if dailyCreatineGrams == 0 {
            return 2.0       // 日常基础维持饮水量
        } else if dailyCreatineGrams <= 3 {
            return 2.5       // 少量补充肌酸，循证推荐饮水量
        } else {
            return 3.5       // 足量补充肌酸（3~5g），循证推荐饮水量
        }
    }

    /// 【修复肌酸饮水单次同步BUG｜改动业务：数据源切换至全局响应式单例，杜绝两边读取不一致】
    /// 读取当日肌酸总摄入克数（从 GlobalCreatineManager 全局单例获取，唯一数据源）
    /// 供补剂页、饮食页统一调用，保证数据源完全一致
    static func getTodayTotalCreatineGram() -> Double {
        return GlobalCreatineManager.shared.todayCreatineGrams
    }

    // MARK: - 【修复DietView饮水量卡片文案匹配错误】统一文案生成函数（双页面通用）

    /// 传入当日肌酸总量，返回饮水量卡片底部说明小字
    /// 判断顺序严格：优先0g基础档 → 再≤3g少量肌酸 → 最后3~5g足量肌酸
    /// 补剂页标题显隐逻辑也依赖此函数搭配肌酸>0判断，确保文案档位完全匹配
    static func getWaterDescText(creatineGram: Double) -> String {
        if creatineGram == 0 {
            return "日常基础维持饮水量"                         // 档位1：无肌酸
        } else if creatineGram <= 3 {
            return "少量补充肌酸，肌酸适配饮水量"                // 档位2：1~3g
        } else {
            return "足量补充肌酸，肌酸适配饮水量"                // 档位3：3~5g
        }
    }

    // MARK: - 【饮食页面新增钠摄入指标】减脂控盐保守推荐常量

    static let sodiumDailyMaxMg: Double = 2000   // 减脂期每日钠上限2000mg（2g）
    static let sodiumDailyMinMg: Double = 1200   // 最低推荐1200mg

    // MARK: - 【饮食页面新增咖啡因摄入指标】循证安全上限常量

    static let caffeineDailyMaxMg: Double = 400        // 成年人每日咖啡因安全上限400mg
    static let caffeinePer100mlCoffeeMg: Double = 95   // 每100ml美式约含95mg咖啡因

    /// 输入咖啡饮用毫升数，输出对应咖啡因毫克
    /// 后期对接云端饮品数据库可替换此换算系数
    static func convertCoffeeMlToCaffeine(ml: Double) -> Double {
        return (ml / 100.0) * caffeinePer100mlCoffeeMg
    }
}

// MARK: - NutritionTargets 营养目标数据模型

struct NutritionTargets: Codable {
    let dailyKcal: Double
    let proteinG: Double
    let fatG: Double
    let carbsG: Double
    let fiberG: Double
    let bmr: Double
    // 【保守减脂热量计算逻辑】饮食基础缺口，≤600kcal，供总缺口叠加计算使用
    let baseDeficit: Double

    static let storageKey = "nutritionTargets_v2"
}

extension NutritionTargets {
    static func loadFromStorage() -> NutritionTargets? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(NutritionTargets.self, from: data)
    }

    func saveToStorage() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

// MARK: - TrainingRecordStorage（训练记录本地读取）

/// 供PhysiologyCalcTool读取当日训练记录汇总消耗
/// 远期云端RAG训练数据库上线后，替换此适配层内部读取逻辑
final class TrainingRecordStorage {
    static let shared = TrainingRecordStorage()
    private init() {}

    func loadAll() -> [TrainingRecordModel] {
        guard let data = UserDefaults.standard.data(forKey: "trainingLog_v1"),
              let records = try? JSONDecoder().decode([TrainingRecordModel].self, from: data) else {
            return []
        }
        return records
    }

    func saveAll(_ records: [TrainingRecordModel]) {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: "trainingLog_v1")
        }
    }
}
