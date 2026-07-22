import Foundation

// MARK: - SupplementPlanMock
/// 补剂方案数据模型（本地展示用）
/// 数据来源：从后端 POST /api/supplement-plan 获取后映射为此结构
struct SupplementPlanMock: Identifiable {
    var id: UUID = UUID()
    var bmi: Double = 22
    var bmiNote: String = ""
    var tdeeKcal: Double = 2500
    var proteinTargetGrams: Double = 120
    var wheyScoopsReference: Double = 3
    var creatineMgPerDay: Double = 5000
    var waterLitersReference: Double = 2.5
    var bodyFat: Double = 18
    var bodyFatNote: String? = nil
    var nutritionTargets: NutritionTargetsModel? = nil
}

// MARK: - NutritionTargetsModel
/// 后端返回的精细化营养目标
struct NutritionTargetsModel: Codable {
    var dailyKcal: Double
    var proteinG: Double
    var fatG: Double
    var carbsG: Double
    var fiberG: Double
    var baseDeficitKcal: Double
}
