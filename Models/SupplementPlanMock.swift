import Foundation

// MARK: - SupplementPlanMock
/// 补剂方案数据模型（本地展示用）
/// 数据来源：从后端 POST /api/supplement-plan 获取后映射为此结构
struct SupplementPlanMock: Identifiable, Codable {
    let id: UUID
    var bmi: Double
    var bmiNote: String
    var tdeeKcal: Double
    var proteinTargetGrams: Double
    var wheyScoopsReference: Double
    var creatineMgPerDay: Double
    var waterLitersReference: Double
    var bodyFat: Double
    var bodyFatNote: String?

    init(
        id: UUID = UUID(),
        bmi: Double = 22,
        bmiNote: String = "",
        tdeeKcal: Double = 2500,
        proteinTargetGrams: Double = 120,
        wheyScoopsReference: Double = 3,
        creatineMgPerDay: Double = 5000,
        waterLitersReference: Double = 2.5,
        bodyFat: Double = 18,
        bodyFatNote: String? = nil
    ) {
        self.id = id
        self.bmi = bmi
        self.bmiNote = bmiNote
        self.tdeeKcal = tdeeKcal
        self.proteinTargetGrams = proteinTargetGrams
        self.wheyScoopsReference = wheyScoopsReference
        self.creatineMgPerDay = creatineMgPerDay
        self.waterLitersReference = waterLitersReference
        self.bodyFat = bodyFat
        self.bodyFatNote = bodyFatNote
    }
}
