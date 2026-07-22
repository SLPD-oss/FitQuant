import Foundation

// MARK: - SupplementPlanMock

/// 补剂方案模拟数据模型
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

// MARK: - MockDataSource

enum MockDataSource {

    /// 根据 BodyDataModel 生成模拟补剂方案
    ///
    /// 本方法仅负责数据生成，不包含视觉样式逻辑。
    static func generateSupplementPlan(for body: BodyDataModel) -> SupplementPlanMock {
        let protein = body.weightKg * 1.8
        let tdee = body.bmrEstimate * 1.55

        return SupplementPlanMock(
            bmi: body.bmi,
            bmiNote: "BMI \(String(format: "%.1f", body.bmi)) — 筛查区间：\(body.bmiScreeningZone)",
            tdeeKcal: tdee,
            proteinTargetGrams: protein,
            wheyScoopsReference: protein / 30,
            creatineMgPerDay: 5000,
            waterLitersReference: body.weightKg * 0.033,
            bodyFat: body.bodyFatEstimate,
            bodyFatNote: "本方案基于通用运动营养指南生成，不构成医疗建议。使用前请咨询专业医师或注册营养师。所有身体数据仅用于本地方案生成，不会上传至服务器。"
        )
    }
}
